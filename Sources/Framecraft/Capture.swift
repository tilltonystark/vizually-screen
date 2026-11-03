import AppKit
import ScreenCaptureKit
import AVFoundation
import FramecraftCore

@MainActor
final class Capture: NSObject,ObservableObject,SCStreamDelegate,SCContentSharingPickerObserver {
    @Published var recording=false
    @Published var busy=false
    @Published var picking=false
    @Published var systemAudio=true
    @Published var smoothCursor=true
    @Published var quality: VideoQuality = .efficient
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
    func chooseSource() {
        guard !recording,!busy else { return }
        error=nil;picking=true
        let picker=SCContentSharingPicker.shared
        var config=SCContentSharingPickerConfiguration()
        config.allowedPickerModes=[.singleDisplay,.singleWindow]
        config.allowsChangingSelectedContent=false
        picker.defaultConfiguration=config;picker.maximumStreamCount=1;picker.isActive=true
        picker.present()
    }
    func start() async {
        guard !busy,!recording else { return }
        guard let filter else { chooseSource();return }
        busy=true;error=nil
        let session=UUID();sessionID=session
        do {
            let config=SCStreamConfiguration()
            let (width,height)=VideoQuality.nativeSize(points:filter.contentRect.size,scale:Double(filter.pointPixelScale))
            config.width=width;config.height=height;config.captureResolution = .best
            config.minimumFrameInterval=CMTime(value:1,timescale:60)
            config.queueDepth=6;config.pixelFormat=quality == .master ? kCVPixelFormatType_32BGRA : kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;config.colorSpaceName=CGColorSpace.sRGB
            if quality != .master { config.colorMatrix=CGDisplayStream.yCbCrMatrix_ITU_R_709_2 }
            config.showsCursor = !smoothCursor;config.capturesAudio=systemAudio;config.excludesCurrentProcessAudio=true
            config.ignoreShadowsSingleWindow=true
            let folder=FileManager.default.urls(for:.moviesDirectory,in:.userDomainMask)[0].appendingPathComponent("Framecraft")
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            let url=folder.appendingPathComponent("Recording-\(UUID().uuidString.prefix(8)).\(quality.fileExtension)")
            let writer=try RecordingWriter(url:url,quality:quality,width:width,height:height,audioEnabled:systemAudio,onBounds: { [weak self] rect in Task { @MainActor in guard let self,self.sessionID == session,rect.width>0,rect.height>0 else { return };self.cursorBounds=rect } }) { [weak self] in Task { @MainActor in guard let self,self.sessionID == session,self.stream != nil else { return };self.beginRecordingClock() } }
            let stream=SCStream(filter:filter,configuration:config,delegate:self)
            try stream.addStreamOutput(writer,type:.screen,sampleHandlerQueue:writer.queue)
            if systemAudio { try stream.addStreamOutput(writer,type:.audio,sampleHandlerQueue:writer.queue) }
            self.output=writer;self.stream=stream;stopping=false
            cursorSamples=[]
            if #available(macOS 15.2,*) { cursorBounds=filter.includedWindows.first?.frame ?? filter.includedDisplays.first?.frame ?? filter.contentRect } else { cursorBounds=filter.contentRect }
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
        recording=true;busy=false;began=Date();elapsed=0
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
        stopping=true;busy=true
        let end=CMClockGetTime(CMClockGetHostTimeClock())
        cursorTimer?.invalidate();cursorTimer=nil
        do {
            try await stream.stopCapture()
            let result=try await output.finish(cursor:smoothCursor ? cursorSamples:nil,hostEnd:end)
            lastReport="\(result.frames) captured frames · \(result.dropped) dropped"
            cleanup();onFinish?(result)
        } catch { fail(error) }
    }
    private func cleanup() { sessionID=UUID();recordingTimer?.invalidate();recordingTimer=nil;began=nil;cursorTimer?.invalidate();cursorTimer=nil;stream=nil;output=nil;recording=false;busy=false;stopping=false;filter=nil;hasSource=false;sourceSummary="Choose a source for the next recording";SCContentSharingPicker.shared.isActive=false }
    private func fail(_ error: Error) {
        output?.cancel();self.error="\(error.localizedDescription)\n\((error as NSError).domain) (\((error as NSError).code)). Select the source again with the macOS picker. If macOS still refuses, quit Framecraft and re-enable this build in Screen & System Audio Recording."
        cleanup()
    }
    nonisolated func contentSharingPicker(_ picker:SCContentSharingPicker,didCancelFor stream:SCStream?) { Task { @MainActor in self.picking=false } }
    nonisolated func contentSharingPicker(_ picker:SCContentSharingPicker,didUpdateWith filter:SCContentFilter,for stream:SCStream?) {
        Task { @MainActor in
            self.filter=filter;self.hasSource=true;self.picking=false;self.error=nil
            let size=VideoQuality.nativeSize(points:filter.contentRect.size,scale:Double(filter.pointPixelScale))
            let name: String
            if #available(macOS 15.2,*) { name=filter.includedWindows.first?.title ?? "Selected screen" } else { name="Selected source" }
            self.sourceSummary="\(name) · \(size.0) × \(size.1) native pixels"
        }
    }
    nonisolated func contentSharingPickerStartDidFailWithError(_ error:Error) { Task { @MainActor in self.picking=false;self.fail(error) } }
    nonisolated func stream(_ stream:SCStream,didStopWithError error:Error) {
        Task { @MainActor in
            guard self.stream === stream,!self.stopping else { return }
            // A source disappearing is recoverable: finalize received media before reporting it.
            self.cursorTimer?.invalidate();self.cursorTimer=nil
            if let output=self.output {
                do { let result=try await output.finish(cursor:self.smoothCursor ? self.cursorSamples:nil,hostEnd:CMClockGetTime(CMClockGetHostTimeClock()));self.cleanup();self.onFinish?(result);self.error="Recording ended: \(error.localizedDescription). Received frames were saved." }
                catch { self.fail(error) }
            } else { self.fail(error) }
        }
    }
}
