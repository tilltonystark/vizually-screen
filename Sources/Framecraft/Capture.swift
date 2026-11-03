import AppKit
import ScreenCaptureKit
import AVFoundation

@MainActor
final class Capture: NSObject, ObservableObject, SCRecordingOutputDelegate, SCStreamDelegate {
    @Published var displays: [SCDisplay] = []
    @Published var selectedDisplay: CGDirectDisplayID = 0
    @Published var recording = false
    @Published var busy = false
    @Published var systemAudio = true
    @Published var error: String?
    var onFinish: ((URL) -> Void)?
    private var stream: SCStream?
    private var output: SCRecordingOutput?
    private var destination: URL?

    func refresh() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            displays = content.displays
            if !displays.contains(where: { $0.displayID == selectedDisplay }) { selectedDisplay = displays.first?.displayID ?? 0 }
        } catch { self.error = "Screen access is required. Enable Framecraft in System Settings → Privacy & Security → Screen & System Audio Recording, then reopen the app.\n\(error.localizedDescription)" }
    }
    func start() async {
        guard !busy, !recording else { return }
        busy = true
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first(where: { $0.displayID == selectedDisplay }) else { throw NSError(domain: "Capture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Choose a display first."]) }
            let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
            let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
            let config = SCStreamConfiguration()
            config.width = display.width * 2
            config.height = display.height * 2
            // Keep hardware encoding within a predictable 4K budget.
            let ratio = min(1, 3840 / Double(config.width), 2160 / Double(config.height))
            config.width = max(2, Int(Double(config.width) * ratio) / 2 * 2)
            config.height = max(2, Int(Double(config.height) * ratio) / 2 * 2)
            config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
            config.showsCursor = true
            config.capturesAudio = systemAudio
            config.excludesCurrentProcessAudio = true
            let folder = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0].appendingPathComponent("Framecraft")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent("Recording-\(UUID().uuidString.prefix(8)).mp4")
            let recordingConfig = SCRecordingOutputConfiguration()
            recordingConfig.outputURL = url
            recordingConfig.videoCodecType = .h264
            recordingConfig.outputFileType = .mp4
            let output = SCRecordingOutput(configuration: recordingConfig, delegate: self)
            let stream = SCStream(filter: filter, configuration: config, delegate: self)
            try stream.addRecordingOutput(output)
            self.stream = stream; self.output = output; destination = url
            try await stream.startCapture()
        } catch { self.error = error.localizedDescription; cleanup() }
    }
    func stop() async {
        guard recording, !busy else { return }
        busy = true
        do { try await stream?.stopCapture() }
        catch { self.error = error.localizedDescription; cleanup() }
    }
    private func cleanup() { stream = nil; output = nil; destination = nil; recording = false; busy = false }
    nonisolated func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor in self.recording = true; self.busy = false }
    }
    nonisolated func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor in
            let url = self.destination
            self.cleanup()
            if let url { self.onFinish?(url) }
        }
    }
    nonisolated func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        Task { @MainActor in
            let active = self.stream
            self.error = error.localizedDescription
            try? await active?.stopCapture()
            self.cleanup()
        }
    }
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in self.error = error.localizedDescription; self.recording = false; self.busy = false }
    }
}
