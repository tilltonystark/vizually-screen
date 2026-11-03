import FramecraftCore
import AppKit
import AVKit
import UniformTypeIdentifiers

@MainActor
final class Editor: ObservableObject {
    @Published var project: Project?
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
    @Published var sourceFrameRate: Float = 0
    let player = AVPlayer()
    private var asset: AVURLAsset?
    private var renderState: RenderState?
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
    func load(_ url: URL, saved: Project? = nil) async {
        guard !busy else { return }
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
            let sidecar=url.deletingPathExtension().appendingPathExtension("framecraft.json")
            var project = saved ?? Project(sourcePath:url.path,trimEnd:duration)
            if saved == nil, FileManager.default.fileExists(atPath:sidecar.path) {
                project=try JSONDecoder().decode(Project.self,from:Data(contentsOf:sidecar));project.sourcePath=url.path
            }
            try project.validate(duration: duration)
            let naturalSize = try await video.load(.naturalSize)
            let transform = try await video.load(.preferredTransform)
            let transformedSize = naturalSize.applying(transform)
            let frameRate = try await video.load(.nominalFrameRate)
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
            item.videoComposition = Renderer.composition(asset:asset,project:project,state:state)
            renderState=state
            player.pause()
            // Commit only after validation and staging; failed loads preserve the current edit.
            self.asset = asset; self.duration = duration; self.project = project
            self.videoSize = CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))
            self.sourceFrameRate = frameRate
            self.thumbnails = images
            self.selectedZoomID = project.zooms.first?.id
            self.isPlaying = false
            seekGeneration=UUID();seeking=false;pendingSeek=nil
            player.replaceCurrentItem(with: item)
            seek(project.trimStart)
            message = url.lastPathComponent
        } catch { self.error = error.localizedDescription; message = previousMessage }
    }
    func loadRecording(_ result: CaptureResult) async {
        let asset = AVURLAsset(url:result.url)
        do {
            var p=Project(sourcePath:result.url.path,trimEnd:try await asset.load(.duration).seconds)
            p.cursorSamples=result.samples
            let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
            try encoder.encode(p).write(to:result.url.deletingPathExtension().appendingPathExtension("framecraft.json"),options:.atomic)
            await load(result.url,saved:p)
            message="Recording saved · \(result.dropped) dropped frames"
        } catch { self.error=error.localizedDescription }
    }
    func loadDemo() async {
        guard !busy else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Framecraft-studio-demo-v2.mp4")
        busy = true
        message = "Preparing demo…"
        do {
            if !FileManager.default.fileExists(atPath: url.path) { try await DemoClip.create(at: url) }
            busy = false
            var demo = Project(sourcePath: url.path, trimEnd: 8)
            demo.padding=0.07
            demo.zooms = [Zoom(start: 1.2, duration: 2.4, scale: 1.65, x: 0.65, y: 0.42), Zoom(start: 4.8, duration: 2.2, scale: 1.9, x: 0.73, y: 0.65)]
            await load(url, saved: demo)
        } catch { busy = false; self.error = error.localizedDescription }
    }
    func importVideo() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.movie]; panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url { Task { await load(url) } }
    }
    func openProject() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let saved = try JSONDecoder().decode(Project.self, from: Data(contentsOf: url))
                Task { await load(URL(fileURLWithPath: saved.sourcePath), saved: saved) }
            } catch { self.error = error.localizedDescription }
        }
    }
    func saveProject() {
        guard let project else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "Untitled.framecraft.json"
        if panel.runModal() == .OK, let url = panel.url {
            do { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; try encoder.encode(project).write(to: url, options: .atomic); message = "Project saved" }
            catch { self.error = error.localizedDescription }
        }
    }
    func update(_ change: (inout Project) -> Void) {
        guard !busy, var p = project, asset != nil else { return }
        change(&p)
        do { try p.validate(duration: duration) }
        catch { self.error = error.localizedDescription; return }
        project = p
        if let selectedZoomID, !p.zooms.contains(where: { $0.id == selectedZoomID }) { self.selectedZoomID = nil }
        renderState?.update(p)
        // Re-seek to render changes while paused.
        seek(playhead)
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
    func setTrimStart(_ value: Double) {
        update { $0.setTrimStart(value, duration: duration) }
        if let p = project, playhead < p.trimStart || playhead > p.trimEnd { seek(p.trimStart) }
    }
    func setTrimEnd(_ value: Double) {
        update { $0.setTrimEnd(value, duration: duration) }
        if let p = project, playhead > p.trimEnd || playhead < p.trimStart { seek(p.trimStart) }
    }
    func cancelExport() { exportControl?.cancel();message="Cancelling export…" }
    func export(quality: VideoQuality = .high) {
        guard let project, let asset else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = quality == .master ? [.quickTimeMovie] : [.mpeg4Movie]; panel.nameFieldStringValue = "Framecraft-export.\(quality.fileExtension)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard url.standardizedFileURL.path != URL(fileURLWithPath: project.sourcePath).standardizedFileURL.path else { error = "Choose a different filename to preserve your original recording."; return }
        busy = true; isExporting=true;exportProgress=0;let control=ExportControl();exportControl=control;player.pause(); message = "Rendering your video…"
        Task {
            // Export to a sibling temporary file before replacing an existing destination.
            let temp = url.deletingLastPathComponent().appendingPathComponent(".framecraft-\(UUID().uuidString).\(quality.fileExtension)")
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
