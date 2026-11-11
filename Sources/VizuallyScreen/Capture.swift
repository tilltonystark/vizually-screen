import AppKit
import ScreenCaptureKit
import AVFoundation
import VizuallyScreenCore

@MainActor
final class Capture: NSObject,ObservableObject,SCStreamDelegate,SCContentSharingPickerObserver {
    @Published var recording=false
    @Published var busy=false
    @Published var picking=false
    @Published var systemAudio=true
    @Published var smoothCursor=true
    @Published var automaticZoom=true
    @Published var quality: VideoQuality = VideoQuality(rawValue:UserDefaults.standard.string(forKey:"recording.quality") ?? "") ?? .efficient {
        didSet { UserDefaults.standard.set(quality.rawValue,forKey:"recording.quality") }
    }
    @Published var error: String?
    @Published var sourceSummary="No source selected"
    @Published var hasSource=false
    @Published var lastReport=""
    @Published var elapsed=0.0
    private var recordingTimer:Timer?
    private var began:Date?
    var supportsSmoothPointer:Bool { if #available(macOS 15.2,*) { return true };return false }
    var onFinish: ((CaptureResult)->Void)?
    private var filter: SCContentFilter?
    private var selectedArea:CGRect?
    private var selectedAreaDisplayID:CGDirectDisplayID?
    private let areaIndicator=RecordingAreaIndicator()
    private var activeArea:(displayID:CGDirectDisplayID,rect:CGRect)?
    func hideAreaIndicator() { guard stream == nil,!recording else { return };areaIndicator.hide() }
    func restoreAreaIndicator() {
        if stream != nil {
            if let activeArea { areaIndicator.show(displayID:activeArea.displayID,rect:activeArea.rect) }
            else { areaIndicator.hide() }
        } else if let pendingArea { areaIndicator.show(displayID:pendingArea.displayID,rect:pendingArea.rect) }
        else if let selectedArea,let selectedAreaDisplayID { areaIndicator.show(displayID:selectedAreaDisplayID,rect:selectedArea) }
        else { areaIndicator.hide() }
    }
    @Published var selectionStatus:String?
    @Published private var pendingArea:(displayID:CGDirectDisplayID,rect:CGRect)?
    @Published var areaPreview:AreaPreview?
    var areaNeedsAuthorization:Bool { pendingArea != nil }
    struct AreaPreview {
        let rect:CGRect
        let displaySize:CGSize
        let pixelScale:Double
        var dimensions:String { "\(Int((rect.width*pixelScale).rounded())) × \(Int((rect.height*pixelScale).rounded())) px" }
    }
    private let areaSelector=AreaSelector()
    var supportsArea:Bool { if #available(macOS 15.2,*) { return true };return false }
    func chooseArea() {
        guard supportsArea,!recording,!busy,!picking else { return }
        areaIndicator.hide()
        error=nil;picking=true;selectionStatus="Switch apps with ⌘Tab, then drag to select."
        areaSelector.present(on:NSScreen.screens) { [weak self] choice in
            guard let self else { return }
            guard let (screen,rect)=choice,
                  let number=screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                self.picking=false;self.selectionStatus=nil;self.restoreAreaIndicator();return
            }
            let id=number.uint32Value
            self.pendingArea=(id,rect)
            self.restoreAreaIndicator()
            self.areaPreview=AreaPreview(rect:rect,displaySize:screen.frame.size,pixelScale:screen.backingScaleFactor)
            if #available(macOS 15.2,*),let filter=self.filter,filter.style == .display,filter.includedDisplays.first?.displayID == id {
                self.acceptAreaSource(filter);return
            }
            self.picking=false
            self.selectionStatus="Area selected · Permission needed before recording"
        }
    }
    func authorizeArea() {
        guard let pendingArea,!picking,!busy,!recording else { return }
        let id=pendingArea.displayID
        picking=true;selectionStatus="In macOS, choose Share Screen to allow recording. Only the outlined area will be saved."
        Task { @MainActor in
            if CGPreflightScreenCaptureAccess(),
               let content=try? await SCShareableContent.excludingDesktopWindows(false,onScreenWindowsOnly:true),
               let display=content.displays.first(where: { $0.displayID == id }),
               self.pendingArea?.displayID == id {
                let filter=SCContentFilter(display:display,excludingApplications:content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier },exceptingWindows:[])
                self.acceptAreaSource(filter)
            } else if self.pendingArea != nil { self.chooseSource(area:true) }
        }
    }

    private func acceptAreaSource(_ candidate:SCContentFilter) {
        guard #available(macOS 15.2,*),let pendingArea,
              candidate.style == .display,candidate.includedDisplays.first?.displayID == pendingArea.displayID else {
            picking=false;selectionStatus="Area selected · Choose the matching display to continue."
            error="The shared display does not match your selected area. Choose the area again and share that display.";return
        }
        let rect=pendingArea.rect
        let displayID=pendingArea.displayID
        self.pendingArea=nil
        applySource(candidate)
        selectedArea=rect;selectedAreaDisplayID=displayID
        restoreAreaIndicator()
        areaPreview=AreaPreview(rect:rect,displaySize:sourceBounds(candidate).size,pixelScale:Double(candidate.pointPixelScale))
        let size=VideoQuality.nativeSize(points:rect.size,scale:Double(candidate.pointPixelScale))
        sourceSummary="Selected area · \(size.0) × \(size.1)"
    }
    private func captureBounds(_ filter:SCContentFilter) -> CGRect {
        guard let selectedArea else { return sourceBounds(filter) }
        return CaptureArea.globalBounds(local:selectedArea,display:sourceBounds(filter))
    }
    private var stream: SCStream?
    private var output: RecordingWriter?
    private var cursorTimer: Timer?
    private var cursorSamples: [CursorSample]=[]
    private var cursorBounds=CGRect.zero
    private var stopping=false
    private var sessionID=UUID()
    override init() {
        super.init();if #unavailable(macOS 15.2) { smoothCursor=false };SCContentSharingPicker.shared.add(self)
    }
    func chooseSource(area:Bool=false) {
        guard !recording,!busy else { return }
        error=nil;picking=true
        if !area { areaIndicator.hide();pendingArea=nil;areaPreview=nil;selectionStatus="Choose a screen or window in the macOS picker." }
        let picker=SCContentSharingPicker.shared
        var config=SCContentSharingPickerConfiguration()
        config.allowedPickerModes=area ? [.singleDisplay]:[.singleDisplay,.singleWindow]
        config.allowsChangingSelectedContent=false
        picker.defaultConfiguration=config;picker.maximumStreamCount=1;picker.isActive=true
        picker.present()
    }
    func prepareDefaultSource() async {
        // Use an already-authorized sole display without adding another choice.
        // Never request broad permission merely to skip the system picker.
        guard pendingArea == nil,!hasSource,!picking,!busy,!recording,NSScreen.screens.count == 1,CGPreflightScreenCaptureAccess() else { return }
        guard let content=try? await SCShareableContent.excludingDesktopWindows(false,onScreenWindowsOnly:true),
              content.displays.count == 1,let display=content.displays.first,
              pendingArea == nil,!hasSource,!picking,!busy,!recording else { return }
        let selected=SCContentFilter(display:display,excludingApplications:content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier },exceptingWindows:[])
        applySource(selected)
    }
    private func sourceBounds(_ filter:SCContentFilter) -> CGRect {
        if #available(macOS 15.2,*) {
            if filter.style == .window { return filter.includedWindows.first?.frame ?? filter.contentRect }
            return filter.includedDisplays.first?.frame ?? filter.contentRect
        }
        return filter.contentRect
    }
    private func applySource(_ filter:SCContentFilter) {
        guard stream == nil,!recording,!busy else { return }
        areaIndicator.hide();selectedAreaDisplayID=nil
        self.filter=filter;selectedArea=nil;areaPreview=nil;hasSource=true;picking=false;selectionStatus=nil;error=nil
        let size=VideoQuality.nativeSize(points:sourceBounds(filter).size,scale:Double(filter.pointPixelScale))
        let name:String
        if #available(macOS 15.2,*),filter.style == .window { name=filter.includedWindows.first?.title ?? "Selected window" }
        else { name=NSScreen.screens.count == 1 ? "This screen":"Selected screen" }
        sourceSummary="\(name) · \(size.0) × \(size.1)"
    }
    func start() async {
        guard !busy,!recording else { return }
        guard pendingArea == nil else { error="Authorize the selected area before recording.";return }
        guard let filter else { chooseSource();return }
        busy=true;error=nil
        if let selectedArea,let selectedAreaDisplayID { activeArea=(selectedAreaDisplayID,selectedArea) } else { activeArea=nil }
        let session=UUID();sessionID=session
        do {
            let config=SCStreamConfiguration()
            let (width,height)=VideoQuality.nativeSize(points:captureBounds(filter).size,scale:Double(filter.pointPixelScale))
            if let selectedArea { config.sourceRect=selectedArea }
            config.width=width;config.height=height;config.captureResolution = .best
            config.scalesToFit=false;config.preservesAspectRatio=true
            config.minimumFrameInterval=CMTime(value:1,timescale:60)
            config.queueDepth=6;config.pixelFormat=quality == .master ? kCVPixelFormatType_32BGRA : kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;config.colorSpaceName=CGColorSpace.sRGB
            if quality != .master { config.colorMatrix=CGDisplayStream.yCbCrMatrix_ITU_R_709_2 }
            config.showsCursor = !smoothCursor;config.capturesAudio=systemAudio;config.excludesCurrentProcessAudio=true
            config.ignoreShadowsSingleWindow=true
            let folder=FileManager.default.urls(for:.moviesDirectory,in:.userDomainMask)[0].appendingPathComponent("Vizually Screen")
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            let url=folder.appendingPathComponent("Recording-\(UUID().uuidString.prefix(8)).\(quality.fileExtension)")
            let fixedAreaBounds=selectedArea.map { CaptureArea.globalBounds(local:$0,display:sourceBounds(filter)) }
            let writer=RecordingWriter(url:url,quality:quality,audioEnabled:systemAudio,onBounds: { [weak self] rect in Task { @MainActor in guard let self,self.sessionID == session,rect.width>0,rect.height>0 else { return };self.cursorBounds=fixedAreaBounds ?? rect } }) { [weak self] size in Task { @MainActor in guard let self,self.sessionID == session,self.stream != nil else { return };self.sourceSummary="\(fixedAreaBounds != nil ? "Area":(filter.style == .window ? "Window":"Screen")) · \(Int(size.width)) × \(Int(size.height))";self.beginRecordingClock() } }
            let stream=SCStream(filter:filter,configuration:config,delegate:self)
            try stream.addStreamOutput(writer,type:.screen,sampleHandlerQueue:writer.queue)
            if systemAudio { try stream.addStreamOutput(writer,type:.audio,sampleHandlerQueue:writer.queue) }
            self.output=writer;self.stream=stream;stopping=false
            cursorSamples=[]
            cursorBounds=captureBounds(filter)
            if smoothCursor {
                cursorTimer=Timer.scheduledTimer(withTimeInterval:1/120,repeats:true) { [weak self] _ in Task { @MainActor in self?.sampleCursor() } }
                if let cursorTimer { RunLoop.main.add(cursorTimer,forMode:.common) }
            }
            try await stream.startCapture()
            Task { @MainActor [weak self,weak stream] in
                try? await Task.sleep(nanoseconds:10_000_000_000)
                guard let self,let stream,self.stream === stream,self.busy,!self.recording else { return }
                await self.stop()
            }
        } catch { fail(error) }
    }
    private func beginRecordingClock() {
        guard !stopping,stream != nil else { return }
        recording=true;busy=false;began=Date();elapsed=0
        restoreAreaIndicator()
        recordingTimer=Timer.scheduledTimer(withTimeInterval:0.1,repeats:true) { [weak self] _ in
            Task { @MainActor in guard let self,let began=self.began else { return };self.elapsed=Date().timeIntervalSince(began) }
        }
    }
    private func sampleCursor() {
        guard let p=CGEvent(source:nil)?.location,cursorBounds.width>0,cursorBounds.height>0 else { return }
        cursorSamples.append(CursorSample(time:CMClockGetTime(CMClockGetHostTimeClock()).seconds,x:min(1,max(0,(p.x-cursorBounds.minX)/cursorBounds.width)),y:min(1,max(0,(p.y-cursorBounds.minY)/cursorBounds.height)),visible:cursorBounds.contains(p)))
    }
    func stop() async {
        guard !stopping,let stream,let output else { return }
        stopping=true;busy=true;areaIndicator.hide()
        let end=CMClockGetTime(CMClockGetHostTimeClock())
        cursorTimer?.invalidate();cursorTimer=nil
        do {
            try await stream.stopCapture()
            let result=try await output.finish(cursor:smoothCursor ? cursorSamples:nil,hostEnd:end)
            lastReport="\(result.frames) captured frames · \(result.dropped) dropped"
            cleanup();onFinish?(result)
        } catch { fail(error) }
    }
    private func cleanup() { sessionID=UUID();recordingTimer?.invalidate();recordingTimer=nil;began=nil;cursorTimer?.invalidate();cursorTimer=nil;stream=nil;output=nil;recording=false;busy=false;stopping=false;filter=nil;activeArea=nil;areaIndicator.hide();selectedAreaDisplayID=nil;selectedArea=nil;pendingArea=nil;areaPreview=nil;selectionStatus=nil;areaSelector.cancel();hasSource=false;sourceSummary="Choose a source for the next recording";SCContentSharingPicker.shared.isActive=false }
    private func fail(_ error: Error) {
        output?.cancel();self.error="\(error.localizedDescription)\n\((error as NSError).domain) (\((error as NSError).code)). Select the source again with the macOS picker. If macOS still refuses, quit Vizually Screen and re-enable this build in Screen & System Audio Recording."
        cleanup()
    }
    nonisolated func contentSharingPicker(_ picker:SCContentSharingPicker,didCancelFor stream:SCStream?) { Task { @MainActor in guard self.stream == nil,!self.recording,!self.busy else { return };self.picking=false;self.selectionStatus=self.pendingArea == nil ? nil:"Area selected · Permission cancelled. Try again.";self.restoreAreaIndicator() } }
    nonisolated func contentSharingPicker(_ picker:SCContentSharingPicker,didUpdateWith filter:SCContentFilter,for stream:SCStream?) {
        Task { @MainActor in
            guard self.stream == nil,!self.recording,!self.busy else { return }
            if self.pendingArea != nil { self.acceptAreaSource(filter) } else { self.applySource(filter) }
        }
    }
    nonisolated func contentSharingPickerStartDidFailWithError(_ error:Error) { Task { @MainActor in guard self.stream == nil,!self.recording,!self.busy else { return };self.picking=false;self.fail(error) } }
    nonisolated func stream(_ stream:SCStream,didStopWithError error:Error) {
        Task { @MainActor in
            guard self.stream === stream,!self.stopping else { return }
            // A source disappearing is recoverable: finalize received media before reporting it.
            self.areaIndicator.hide()
            self.cursorTimer?.invalidate();self.cursorTimer=nil
            if let output=self.output {
                do { let result=try await output.finish(cursor:self.smoothCursor ? self.cursorSamples:nil,hostEnd:CMClockGetTime(CMClockGetHostTimeClock()));self.cleanup();self.onFinish?(result);self.error="Recording ended: \(error.localizedDescription). Received frames were saved." }
                catch { self.fail(error) }
            } else { self.fail(error) }
        }
    }
}
