import VizuallyScreenCore
import AppKit
import AVKit
import UniformTypeIdentifiers
import CryptoKit

@MainActor
final class Editor: ObservableObject {
    @Published var project: Project?
    @Published var recordingTitle:String?
    @Published var showsHome=true
    @Published var cropping=false
    var onLibraryChange:((URL,URL?)->Void)?
    private var activeProjectURL:URL?
    private var hasChanges=false
    @Published var duration: Double = 0
    @Published var playhead: Double = 0
    @Published var busy = false
    @Published var message = "Ready when you are."
    @Published var error: String?
    @Published var exportProgress: Double=0
    @Published var isExporting=false
    private var exportControl: ExportControl?
    @Published var selectedZoomID: UUID?
    @Published var isPlaying = false
    @Published var thumbnails: [NSImage] = []
    @Published var videoSize: CGSize = .zero
    private(set) var sourceVideoSize: CGSize = .zero
    @Published var sourceFrameRate: Float = 0
    let player = AVPlayer()
    private var asset: AVURLAsset?
    private var renderState: RenderState?
    private var previewRefresh:Task<Void,Never>?
    private var pendingSeek: Double?
    private var observer: Any?
    private var playbackObservation: NSKeyValueObservation?
    private var loadGeneration = UUID()
    private var seekGeneration = UUID()
    private var seeking = false

    init() {
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(value:1,timescale:60), queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                guard !self.seeking, self.project != nil else { return }
                self.playhead = time.seconds.isFinite ? time.seconds : 0
                if let p = self.project, self.player.rate > 0, self.playhead >= p.trimEnd { self.player.pause(); self.seek(p.trimStart) }
            }
        }
        playbackObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            let playing = player.timeControlStatus == .playing
            Task { @MainActor in self?.isPlaying = playing }
        }
    }
    func load(_ url: URL, saved: Project? = nil,projectURL:URL? = nil,title:String?=nil) async {
        guard !busy else { return }
        guard persistWorkingCopy() else { return }
        let generation = UUID()
        loadGeneration = generation
        busy = true
        let previousMessage = message
        message = "Loading video…"
        defer { if generation == loadGeneration { busy = false } }
        do {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration).seconds
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let video = tracks.first, duration.isFinite, duration > 0 else { throw CocoaError(.fileReadCorruptFile) }
            let sidecar=projectURL ?? ProjectFiles.adjacentProject(for:url)
            var project = saved ?? Project(sourcePath:url.path,trimEnd:duration)
            if saved == nil, let sidecar {
                project=try JSONDecoder().decode(Project.self,from:Data(contentsOf:sidecar));project.sourcePath=url.path
            }
            try project.validate(duration: duration)
            if project.padding>0,let background=project.canvasBackground,background.kind == .image,CanvasBackground.loadImage(background.value) == nil { throw MediaExporter.qualityError("The background image is missing. Restore it or open a project with an available background.") }
            let frameRate = try await video.load(.nominalFrameRate)
            let naturalSize = try await video.load(.naturalSize)
            let transform = try await video.load(.preferredTransform)
            let uprightSize = naturalSize.applying(transform)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 240, height: 144)
            generator.requestedTimeToleranceBefore = CMTime(seconds: 0.12, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 0.12, preferredTimescale: 600)
            var images: [NSImage] = []
            for index in 0..<12 {
                guard generation == loadGeneration else { generator.cancelAllCGImageGeneration(); return }
                // Sample within each cell, never exactly at the non-decodable end time.
                let time = CMTime(seconds: duration * (Double(index) + 0.5) / 12, preferredTimescale: 60_000)
                if let image = try? await generator.image(at: time).image {
                    images.append(NSImage(cgImage: image, size: .zero))
                }
            }
            guard generation == loadGeneration else { return }
            let item = AVPlayerItem(asset: asset)
            let state=RenderState(project)
            let composition = Renderer.composition(asset:asset,project:project,state:state)
            item.videoComposition = composition
            renderState=state
            player.pause()
            // Commit only after validation and staging; failed loads preserve the current edit.
            self.asset = asset; self.duration = duration; self.project = project;recordingTitle=title
            activeProjectURL=sidecar;hasChanges=false;showsHome=false
            onLibraryChange?(url,sidecar)
            self.sourceVideoSize = CGSize(width:abs(uprightSize.width),height:abs(uprightSize.height))
            self.videoSize = composition.renderSize
            self.sourceFrameRate = frameRate
            self.thumbnails = images
            self.selectedZoomID = project.zooms.first?.id
            self.isPlaying = false
            previewRefresh?.cancel();previewRefresh=nil
            seekGeneration=UUID();seeking=false;pendingSeek=nil
            player.replaceCurrentItem(with: item)
            seek(project.trimStart)
            message = url.lastPathComponent
        } catch { self.error = error.localizedDescription; message = previousMessage }
    }
    func loadRecording(_ result: CaptureResult,automaticZoom:Bool = true) async {
        guard !busy else { error="Recording saved. Import it when the current action finishes.";return }
        busy=true;message="Preparing recording…"
        let asset = AVURLAsset(url:result.url)
        do {
            var p=Project(sourcePath:result.url.path,trimEnd:try await asset.load(.duration).seconds)
            p.cursorSamples=result.samples
            if automaticZoom,let samples=result.samples {
                let end=p.trimEnd
                p.zooms=await Task.detached(priority:.userInitiated) { AutoFocus.suggest(samples:samples,start:0,end:end) }.value
            }
            let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
            try encoder.encode(p).write(to:ProjectFiles.sidecar(for:result.url),options:.atomic)
            busy=false;await load(result.url,saved:p,projectURL:ProjectFiles.sidecar(for:result.url))
            message="Recording saved · \(result.dropped) dropped frames"
        } catch { busy=false;self.error=error.localizedDescription }
    }
    func loadDemo() async {
        guard !busy else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("VizuallyScreen-studio-demo-v3.mp4")
        busy = true
        message = "Preparing demo…"
        do {
            if !FileManager.default.fileExists(atPath: url.path) { try await DemoClip.create(at: url,includePointer:false) }
            busy = false
            var demo = Project(sourcePath: url.path, trimEnd: 8)
            demo.padding=0.07
            demo.cursorSamples=(0...960).map { i in
                let t=Double(i)/120
                let phase=min(1,max(0,(t-1)/0.4)),second=min(1,max(0,(t-4)/0.4))
                return CursorSample(time:t,x:0.35+0.45*phase-0.15*second,y:0.5-0.2*phase+0.35*second)
            }
            demo.zooms=AutoFocus.suggest(samples:demo.cursorSamples!,start:0,end:8)
            await load(url, saved: demo)
        } catch { busy = false; self.error = error.localizedDescription }
    }
    func importVideo() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.movie]; panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url { Task { await load(url) } }
    }
    func openProject() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.movie,.json];panel.canChooseDirectories=false;panel.allowsMultipleSelection=false;panel.title="Open recording or saved project"
        if panel.runModal() == .OK, let url = panel.url {
            if url.pathExtension.lowercased() != "json" { Task { await load(url) };return }
            do {
                let saved = try JSONDecoder().decode(Project.self, from: Data(contentsOf: url))
                Task { await load(URL(fileURLWithPath: saved.sourcePath), saved: saved,projectURL:url) }
            } catch { self.error = error.localizedDescription }
        }
    }
    func saveProject() {
        guard let project else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "Untitled.vizually.json"
        if panel.runModal() == .OK, let url = panel.url {
            do { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; try encoder.encode(project).write(to: url, options: .atomic);activeProjectURL=url;hasChanges=false;onLibraryChange?(URL(fileURLWithPath:project.sourcePath),url);message = "Project saved" }
            catch { self.error = error.localizedDescription }
        }
    }
    func update(_ change: (inout Project) -> Void) {
        guard !busy, var p = project, asset != nil else { return }
        change(&p)
        do { try p.validate(duration: duration) }
        catch { self.error = error.localizedDescription; return }
        project = p
        hasChanges=true
        if let selectedZoomID, !p.zooms.contains(where: { $0.id == selectedZoomID }) { self.selectedZoomID = nil }
        renderState?.update(p)
        // AVPlayer caches paused frames. A new composition identity invalidates
        // that frame without rebuilding the filter graph on every slider event.
        // During playback shared parameters are read on the next frame; no seek.
        if player.rate == 0,previewRefresh == nil {
            let generation=loadGeneration
            previewRefresh=Task { @MainActor in
                try? await Task.sleep(for:.milliseconds(16))
                guard !Task.isCancelled,generation == loadGeneration else { return }
                previewRefresh=nil
                if let item=player.currentItem,let composition=item.videoComposition {
                    item.videoComposition=composition.mutableCopy() as? AVVideoComposition
                }
                seek(playhead)
            }
        }
    }
    func seek(_ seconds: Double) {
        guard project != nil,seconds.isFinite else { return }
        let target=max(0,min(duration,seconds));playhead=target
        if seeking { pendingSeek=target;return }
        seeking=true
        let generation=seekGeneration
        player.seek(to:CMTime(seconds:target,preferredTimescale:60_000),toleranceBefore:CMTime(value:1,timescale:120),toleranceAfter:CMTime(value:1,timescale:120)) { [weak self] _ in
            Task { @MainActor in
                guard let self,self.seekGeneration == generation else { return };self.seeking=false
                if let pending=self.pendingSeek { self.pendingSeek=nil;self.seek(pending) }
            }
        }
    }
    func skip(by seconds: Double) {
        guard let project else { return }
        let lastFrame=max(project.trimStart,project.trimEnd-1/Double(max(30,sourceFrameRate)))
        let target=min(lastFrame,max(project.trimStart,playhead+seconds))
        if target >= lastFrame { player.pause() }
        seek(target)
    }
    func togglePlayback() {
        guard project != nil, !busy else { return }
        if player.rate > 0 { player.pause() }
        else { if let p = project, playhead < p.trimStart || playhead >= p.trimEnd { seek(p.trimStart) }; player.play() }
    }
    func addZoom() {
        guard !busy, let zoom = project?.newZoom(at: playhead) else { return }
        update { $0.zooms.append(zoom) }
        selectedZoomID = zoom.id
    }
    func suggestZooms() {
        guard let p=project,let samples=p.cursorSamples,!busy else { return }
        busy=true;message="Finding focus moments…"
        Task {
            let suggestions=await Task.detached(priority:.userInitiated) { AutoFocus.suggest(samples:samples,start:p.trimStart,end:p.trimEnd) }.value
            let zooms=AutoFocus.merge(suggestions,with:p.zooms)
            busy=false;update { $0.zooms=zooms }
            let automatic=zooms.filter { $0.automatic == true }
            selectedZoomID=automatic.first?.id ?? p.zooms.first?.id
            message=automatic.isEmpty ? "No new focus moments. Manual zooms preserved.":"\(automatic.count) automatic zooms · Manual zooms preserved"
        }
    }
    func selectZoom(_ id: UUID) {
        guard !busy, let zoom = project?.zooms.first(where: { $0.id == id }) else { return }
        selectedZoomID = id
        player.pause()
        seek(zoom.start + min(0.6, zoom.duration / 2))
    }
    func deleteSelectedZoom() {
        guard let selectedZoomID else { return }
        update { $0.zooms.removeAll { $0.id == selectedZoomID } }
    }
    func setTrimStart(_ value: Double) { trim(to:value,start:true) }
    func setTrimEnd(_ value: Double) { trim(to:value,start:false) }
    func trim(to value: Double, start: Bool, preview: Bool = false) {
        guard !busy,var p=project,value.isFinite else { return }
        if start { p.setTrimStart(value,duration:duration) }
        else { p.setTrimEnd(value,duration:duration) }
        guard p.trimStart != project?.trimStart || p.trimEnd != project?.trimEnd else { return }
        project=p;hasChanges=true
        if preview {
            player.pause()
            let lastFrame = max(p.trimStart,p.trimEnd - 1/Double(max(30,sourceFrameRate)))
            seek(start ? p.trimStart:lastFrame)
        } else if playhead < p.trimStart || playhead >= p.trimEnd { seek(p.trimStart) }
    }
    func cropFrame() async throws -> CGImage {
        guard let asset else { throw CocoaError(.fileReadUnknown) }
        let generator = AVAssetImageGenerator(asset:asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width:1440,height:1000)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let time = min(playhead,max(0,duration - 1/Double(max(30,sourceFrameRate))))
        return try await generator.image(at:CMTime(seconds:time,preferredTimescale:60_000)).image
    }
    func applyCrop(_ crop: VideoCrop?) {
        guard !busy,let asset,let item=player.currentItem,var p=project,
              crop?.isValid != false,p.crop != crop else { return }
        player.pause()
        p.crop=crop
        let state=RenderState(p)
        let composition=Renderer.composition(asset:asset,project:p,state:state)
        previewRefresh?.cancel();previewRefresh=nil
        renderState=state;project=p;hasChanges=true
        item.videoComposition=composition;videoSize=composition.renderSize
        seek(playhead)
    }
    func cancelExport() { exportControl?.cancel();message="Cancelling export…" }
    @discardableResult func persistWorkingCopy() -> Bool {
        guard let project else { return true }
        let source=URL(fileURLWithPath:project.sourcePath)
        guard !source.lastPathComponent.contains("studio-demo-") else { return true }
        if !hasChanges,let activeProjectURL { onLibraryChange?(source,activeProjectURL);return true }
        do {
            let folder=RecordingLibrary.support.appendingPathComponent("Projects")
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            let key=SHA256.hash(data:Data(source.standardizedFileURL.path.utf8)).prefix(12).map { String(format:"%02x",$0) }.joined()
            let url=folder.appendingPathComponent("\(key).vizually.json")
            let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
            try encoder.encode(project).write(to:url,options:.atomic)
            activeProjectURL=url;hasChanges=false;onLibraryChange?(source,url);return true
        } catch { self.error="Could not save this edit: \(error.localizedDescription)";return false }
    }
    func returnHome() { guard !busy,persistWorkingCopy() else { return };player.pause();showsHome=true }
    func openRecording(_ entry:RecordingReference) {
        let url=URL(fileURLWithPath:entry.sourcePath)
        if let path=entry.projectPath,FileManager.default.fileExists(atPath:path) {
            do {
                var saved=try JSONDecoder().decode(Project.self,from:Data(contentsOf:URL(fileURLWithPath:path)));saved.sourcePath=url.path
                Task { await load(url,saved:saved,projectURL:URL(fileURLWithPath:path),title:entry.title) }
            } catch { self.error="Could not open this saved edit: \(error.localizedDescription)" }
        } else { Task { await load(url,title:entry.title) } }
    }
    func forgetRecording(_ sourcePath:String) {
        guard let project,RecordingIndex.canonical(project.sourcePath) == RecordingIndex.canonical(sourcePath),!busy else { return }
        loadGeneration=UUID();seekGeneration=UUID();previewRefresh?.cancel();previewRefresh=nil
        player.pause();player.replaceCurrentItem(with:nil)
        self.project=nil;recordingTitle=nil;asset=nil;renderState=nil;activeProjectURL=nil;hasChanges=false
        thumbnails=[];duration=0;playhead=0;videoSize = .zero;sourceFrameRate=0;selectedZoomID=nil
        pendingSeek=nil;seeking=false;isPlaying=false;showsHome=true;message="Ready when you are."
    }
    func export(quality: VideoQuality = .high) {
        guard let project, let asset else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = quality == .master ? [.quickTimeMovie] : [.mpeg4Movie]; panel.nameFieldStringValue = "Vizually Screen-export.\(quality.fileExtension)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard url.standardizedFileURL.path != URL(fileURLWithPath: project.sourcePath).standardizedFileURL.path else { error = "Choose a different filename to preserve your original recording."; return }
        busy = true; isExporting=true;exportProgress=0;let control=ExportControl();exportControl=control;player.pause(); message = "Rendering your video…"
        Task {
            // Export to a sibling temporary file before replacing an existing destination.
            let temp = url.deletingLastPathComponent().appendingPathComponent(".vizually-screen-\(UUID().uuidString).\(quality.fileExtension)")
            defer { busy = false;isExporting=false;exportControl=nil;try? FileManager.default.removeItem(at: temp) }
            do {
                try project.validate(duration: duration)
                try await MediaExporter.export(asset:asset,project:project,quality:quality,to:temp,control:control) { [weak self] value in
                    Task { @MainActor in guard let self,self.exportControl === control else { return };self.exportProgress=max(self.exportProgress,value) }
                }
                if FileManager.default.fileExists(atPath: url.path) { _ = try FileManager.default.replaceItemAt(url, withItemAt: temp) }
                else { try FileManager.default.moveItem(at: temp, to: url) }
                message = "Export complete · \(url.lastPathComponent)"
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch is CancellationError { message="Export cancelled. Original preserved." } catch { self.error = error.localizedDescription; message = "Export failed" }
        }
    }
}
