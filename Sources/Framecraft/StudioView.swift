import SwiftUI
import AVKit
import FramecraftCore

struct StudioView: View {
    @ObservedObject var editor: Editor
    @ObservedObject var capture: Capture
    @EnvironmentObject var theme: StudioTheme
    @Environment(\.openWindow) private var openWindow
    @State private var showRecording = false
    @State private var showExport = false
    @State private var inspectorTab = "Canvas"
    @State private var dropTargeted = false
    private var locked: Bool { editor.busy || capture.recording || capture.busy }
    private var title: String { editor.project.map { URL(fileURLWithPath: $0.sourcePath).deletingPathExtension().lastPathComponent } ?? "Untitled project" }
    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Rule()
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    preview
                    transport
                    Rule()
                    StudioTimeline(editor: editor).disabled(locked)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                Rule(vertical: true)
                StudioInspector(editor: editor, tab: $inspectorTab).frame(width: 282).disabled(locked)
            }
            Rule()
            statusBar
        }
        .background(Color.white)
        .tint(theme.accent)
        .sheet(isPresented: $showExport) { ExportSheet(editor:editor).environmentObject(theme).font(Geist.font()).preferredColorScheme(.light) }
        .sheet(isPresented: $showRecording) { RecordingSheet(capture: capture).environmentObject(theme).font(Geist.font()).preferredColorScheme(.light) }
        .onChange(of: editor.selectedZoomID) { _, value in if value != nil { inspectorTab = "Zoom" } }
        .alert("Unable to complete action", isPresented: Binding(get: { editor.error != nil || capture.error != nil }, set: { if !$0 { editor.error = nil; capture.error = nil } })) {
            Button("OK") { editor.error = nil; capture.error = nil }
        } message: { Text(editor.error ?? capture.error ?? "") }
    }
    private var toolbar: some View {
        HStack(spacing: 12) {
            Image(systemName: "viewfinder").font(.system(size: 21, weight: .medium)).foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Geist.font(13, .medium)).lineLimit(1).truncationMode(.middle).help(title)
                Text("Framecraft").font(Geist.font(11)).foregroundStyle(Ink.secondary)
            }.frame(maxWidth: 300, alignment: .leading)
            Spacer(minLength: 8)
            if capture.recording {
                Button { Task { await capture.stop() } } label: { Label("Stop recording", systemImage: "stop.circle.fill") }
                    .buttonStyle(StudioButtonStyle(primary: true)).disabled(capture.busy)
            } else {
                Button { showRecording = true } label: { Label("Record", systemImage: "record.circle") }.buttonStyle(StudioButtonStyle()).disabled(locked)
            }
            IconButton(symbol: "square.and.arrow.down", title: "Import video (⌘I)", action: editor.importVideo).disabled(locked)
            Menu {
                Button("Open Project…", action: editor.openProject)
                Button("Save Project…", action: editor.saveProject).disabled(editor.project == nil)
                Button("Open Demo Project") { Task { await editor.loadDemo() } }
                Divider()
                Button("Appearance Lab…") { openWindow(id: "appearance-lab") }
            } label: { Image(systemName: "ellipsis").frame(width: 24, height: 40) }.menuStyle(.borderlessButton).fixedSize().help("Project actions").disabled(locked)
            Button { showExport=true } label: { HStack(spacing: 8) { Text("Export video"); Image(systemName: "arrow.up.right") } }
                .buttonStyle(StudioButtonStyle(primary: true)).disabled(editor.project == nil || locked)
        }.padding(.leading, 82).padding(.trailing, 20).frame(height: 70)
    }
    private var preview: some View {
        ZStack {
            theme.canvas
            if editor.project != nil {
                GeometryReader { geometry in
                    let available = CGSize(width: max(1, geometry.size.width - theme.settings.spacing * 3), height: max(1, geometry.size.height - theme.settings.spacing * 3))
                    let aspect = editor.videoSize.width / max(1, editor.videoSize.height)
                    let width = min(available.width, available.height * aspect)
                    NativePlayer(player: editor.player)
                        .frame(width: width, height: width / max(0.1, aspect))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(Color.black.opacity(0.1), lineWidth: 1) }
                        .shadow(color: .black.opacity(0.10), radius: 22, y: 10)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
            } else { emptyState }
            if editor.busy {
                VStack(spacing: 12) { ProgressView(); Text(editor.message).font(Geist.font(13, .medium)) }
                    .padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay { if dropTargeted { RoundedRectangle(cornerRadius: 14).stroke(theme.accent, style: StrokeStyle(lineWidth: 2, dash: [6])).padding(12).allowsHitTesting(false) } }
        .dropDestination(for: URL.self) { urls, _ in
            guard !locked, let url = urls.first, url.isFileURL else { return false }
            Task { await editor.load(url) }; return true
        } isTargeted: { dropTargeted = $0 }
    }
    private var emptyState: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(theme.tint).frame(width: 170, height: 118).rotationEffect(.degrees(-8)).offset(x: -10, y: -5)
                RoundedRectangle(cornerRadius: 16).fill(.white).frame(width: 150, height: 106)
                    .shadow(color: .black.opacity(0.07), radius: 18, y: 8)
                RoundedRectangle(cornerRadius: 16).strokeBorder(.black.opacity(0.07), lineWidth: 0.5).frame(width: 150, height: 106)
                Image(systemName: "play.rectangle").font(.system(size: 34, weight: .light)).foregroundStyle(theme.accent)
            }.frame(height: 154).accessibilityHidden(true)
            Text("A great demo starts here.").font(Geist.font(24, .semibold)).tracking(-0.7)
            Text("Record a walkthrough or bring a video to make it your own.")
                .font(Geist.font(14)).foregroundStyle(Ink.secondary).padding(.top, 10).multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Button { showRecording = true } label: { Label("Record a screen", systemImage: "record.circle") }.buttonStyle(StudioButtonStyle(primary: true))
                Button("Import video", action: editor.importVideo).buttonStyle(StudioButtonStyle())
            }.padding(.top, 26)
            Button { Task { await editor.loadDemo() } } label: { HStack(spacing: 6) { Text("Explore a demo project"); Image(systemName: "arrow.right") } }
                .buttonStyle(StudioButtonStyle(quiet: true)).foregroundStyle(Ink.secondary).padding(.top, 12)
            Text("Or drop a video anywhere on the canvas").font(Geist.font(11)).foregroundStyle(Ink.muted).padding(.top, 20)
        }.padding(32).disabled(locked)
    }
    private var transport: some View {
        HStack(spacing: 8) {
            Text(editor.project == nil ? "Preview" : "\(Int(editor.videoSize.width)) × \(Int(editor.videoSize.height))")
                .font(Geist.font(11, .medium)).foregroundStyle(Ink.secondary).frame(width: 120, alignment: .leading)
            Spacer()
            IconButton(symbol: "backward.end", title: "Go to start") { editor.seek(editor.project?.trimStart ?? 0) }
            IconButton(symbol: editor.isPlaying ? "pause.fill" : "play.fill", title: editor.isPlaying ? "Pause" : "Play") { editor.togglePlayback() }
            Text(clockText(editor.playhead)).font(Geist.font(12, .medium)).monospacedDigit().frame(width: 70)
            Text("/  \(clockText(editor.duration))").font(Geist.font(12)).monospacedDigit().foregroundStyle(Ink.secondary)
            Spacer()
            Text("Fit").font(Geist.font(11)).foregroundStyle(Ink.secondary).frame(width: 120, alignment: .trailing)
        }.padding(.horizontal, 24).frame(height: 56).background(Color.white).disabled(editor.project == nil || locked)
    }
    private var statusBar: some View {
        HStack(spacing: 7) {
            Image(systemName: capture.recording ? "record.circle.fill" : "internaldrive").foregroundStyle(capture.recording ? .red : Ink.secondary)
            Text(capture.recording ? "\(clockText(capture.elapsed)) · \(capture.sourceSummary)" : editor.message).lineLimit(1).help(editor.message)
            Spacer()
            if editor.project != nil { Text("\(editor.project!.zooms.count) zoom regions"); Text("·"); Text("Original preserved") }
            else { Text("On-device editing") }
        }.font(Geist.font(11)).monospacedDigit().foregroundStyle(Ink.secondary).padding(.horizontal, 20).frame(height: 30).background(Ink.soft)
    }
}
struct NativePlayer: NSViewRepresentable {
    let player: AVPlayer
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView(); view.player = player; view.controlsStyle = .none; view.videoGravity = .resizeAspect; return view
    }
    func updateNSView(_ nsView: AVPlayerView, context: Context) { nsView.player = player }
}

struct RecordingSheet: View {
    @ObservedObject var capture: Capture
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var theme: StudioTheme
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Text("New recording").font(Geist.font(21, .semibold)); Spacer(); IconButton(symbol: "xmark", title: "Close") { dismiss() } }
            VStack(alignment:.leading,spacing:12) {
                HStack { Image(systemName:capture.hasSource ? "checkmark.circle" : "display").foregroundStyle(theme.accent);Text(capture.sourceSummary).font(Geist.font(12,.medium)).fixedSize(horizontal:false,vertical:true);Spacer();InfoHint(title:"Recording source",text:"Record a whole screen or choose one app window. Size follows the selected source. If macOS requires it, choose the source in its sharing picker to authorize this session.") }
                Button(capture.hasSource ? "Change source…" : "Choose source…") { capture.chooseSource() }.buttonStyle(StudioButtonStyle())
            }.frame(maxWidth:.infinity,alignment:.leading).padding(18).background(Ink.soft,in:RoundedRectangle(cornerRadius:10))
            QualityPicker(selection:$capture.quality)
            HStack { Toggle("Smooth pointer",isOn:$capture.smoothCursor).toggleStyle(.switch).tint(theme.accent).disabled(!capture.supportsSmoothPointer);InfoHint(title:"Smooth pointer",text:"Records movement separately and renders a smooth arrow. Turn off to keep original cursor shapes, such as text selection and resize. Requires macOS 15.2 or later.") }
            Toggle("Include system audio", isOn: $capture.systemAudio).toggleStyle(.switch).tint(theme.accent)
            HStack { Text("Saved to Movies/Framecraft").font(Geist.font(12)).foregroundStyle(Ink.secondary);InfoHint(title:"Saved recordings",text:"The original video and its pointer data are saved together in Movies/Framecraft. Stop recording from the app or menu bar.") }
            if let error = capture.error { Text(error).font(Geist.font(12)).foregroundStyle(.red).textSelection(.enabled) }
            HStack { Spacer(); Button("Cancel") { dismiss() }.buttonStyle(StudioButtonStyle()); Button("Start recording") { Task { await capture.start(); if capture.error == nil { dismiss() } } }.buttonStyle(StudioButtonStyle(primary: true)).disabled(!capture.hasSource || capture.busy || capture.picking) }
        }.padding(28).frame(width: 450).foregroundStyle(Ink.primary).background(.white)
            .task { await capture.prepareDefaultSource() }
    }
}
