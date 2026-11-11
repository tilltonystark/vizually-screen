import VizuallyFeedback
import SwiftUI
import AVKit
import VizuallyScreenCore

struct StudioView: View {
    @ObservedObject var editor: Editor
    @ObservedObject var capture: Capture
    @EnvironmentObject var theme: StudioTheme
    @EnvironmentObject var feedback:FeedbackStore
    @Environment(\.openWindow) private var openWindow
    @Binding var showRecording:Bool
    @State private var showExport = false
    private var cropping: Bool { editor.cropping }
    @State private var cropSelection = CropControls.full
    @State private var draftAspect: CropAspect = .freeform
    @State private var aspectBaseline: CGRect?
    @State private var cropImage: CGImage?
    @State private var cropFrameFailed = false
    @State private var inspectorTab = "Canvas"
    @State private var dropTargeted = false
    private var locked: Bool { editor.busy || capture.recording || capture.busy }
    private var savedSelection: CGRect { editor.project?.crop?.rect ?? CropControls.full }
    private var cropAspect: CropAspect { cropping ? draftAspect:(editor.project?.crop?.aspect ?? .freeform) }
    private var cropRatio: Double? { cropAspect.normalizedRatio(source:editor.sourceVideoSize,current:savedSelection) }
    private var title: String { editor.recordingTitle ?? editor.project.map { URL(fileURLWithPath: $0.sourcePath).deletingPathExtension().lastPathComponent } ?? "Untitled project" }
    var body: some View {
        VStack(spacing: 0) {
            toolbar.disabled(cropping).feedbackTarget("editor.header","Editor header")
            Rule()
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    preview.feedbackTarget("editor.preview","Video preview")
                    transport.feedbackTarget("editor.playback","Playback controls")
                    Rule()
                    StudioTimeline(editor: editor).disabled(locked || cropping).feedbackTarget("editor.timeline","Timeline")
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                Rule(vertical: true)
                StudioInspector(editor:editor,tab:$inspectorTab,cropping:cropping) {
                    CropControls(aspect:cropAspect,editing:cropping,ready:cropImage != nil,
                                 canReset:cropping ? cropSelection != CropControls.full:editor.project?.crop != nil,
                                 choose:chooseCropAspect,reset:resetCrop,cancel:endCrop,apply:applyCrop)
                }.feedbackTarget("editor.inspector","Inspector").frame(width:282).disabled(locked)
            }
            Rule()
            statusBar
        }
        .background(Color.white)
        .background(WindowChrome())
        .tint(theme.accent)
        .sheet(isPresented: $showExport) { ExportSheet(editor:editor).feedbackSurface(store:feedback,editor:editor,route:"export").environmentObject(theme).font(Geist.font()).preferredColorScheme(.light) }
        .task(id:cropping) {
            guard cropping else { return }
            do {
                let image=try await editor.cropFrame()
                if !Task.isCancelled && cropping { cropImage=image }
            } catch {
                if !Task.isCancelled && cropping { cropFrameFailed=true }
            }
        }
        .onChange(of:locked) { _, value in if value { endCrop() } }
        .onChange(of:showRecording) { _, value in if value { endCrop() } }
        .onDisappear { endCrop() }
        .onChange(of: editor.selectedZoomID) { _, value in if value != nil { inspectorTab = "Zoom" } }
    }
    private var toolbar: some View {
        HStack(spacing: 12) {
            IconButton(symbol:"chevron.left",title:"All recordings",action:editor.returnHome).disabled(locked)
            VStack(alignment: .leading, spacing: 3) {
                Text("Vizually Screen").font(Geist.font(13, .semibold)).feedbackTarget("editor.title.app","App name")
                Text(title).font(Geist.font(11)).foregroundStyle(Ink.secondary).lineLimit(1).truncationMode(.middle).help(title).feedbackTarget("editor.title.recording","Recording name")
            }.accessibilityElement(children:.contain).frame(maxWidth: 300, alignment: .leading).feedbackTarget("editor.title","Project title")
            Spacer(minLength: 8)
            IconButton(symbol: "square.and.arrow.down", title: "Import video (⌘I)", action: editor.importVideo).disabled(locked)
            Menu {
                Button("Open Recording or Project…", action: editor.openProject)
                Button("Save Project…", action: editor.saveProject).disabled(editor.project == nil)
                Button("Open Demo Project") { Task { await editor.loadDemo() } }
                Divider()
                Button("Appearance Lab…") { openWindow(id: "appearance-lab") }
            } label: { Image(systemName:"ellipsis").accessibilityLabel("Project actions") }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .modifier(StudioIconSurface()).help("Project actions").accessibilityLabel("Project actions")
                .feedbackTarget("editor.actions","Project actions").disabled(locked)
            if capture.recording {
                Button { Task { await capture.stop() } } label: { Label("Stop recording", systemImage: "stop.circle.fill") }
                    .buttonStyle(StudioButtonStyle(primary: true)).disabled(capture.busy)
            } else {
                Button { showRecording = true } label: { Label("Record", systemImage: "record.circle") }.buttonStyle(StudioButtonStyle()).disabled(locked).feedbackTarget("editor.record","Record")
            }
            Button { showExport=true } label: { HStack(spacing: 8) { Text("Export video"); Image(systemName: "arrow.up.right") } }
                .buttonStyle(StudioButtonStyle(primary: true)).disabled(editor.project == nil || locked).feedbackTarget("editor.export","Export video")
        }.padding(.leading,StudioLayout.headerLeading).padding(.trailing,20).frame(height:StudioLayout.headerHeight).contentShape(Rectangle()).gesture(WindowDragGesture())
    }
    private var preview: some View {
        ZStack {
            theme.canvas
            if editor.project != nil {
                GeometryReader { geometry in
                    let available = CGSize(width: max(1, geometry.size.width - theme.settings.spacing * 3), height: max(1, geometry.size.height - theme.settings.spacing * 3))
                    let sourceFit=fitVideo(editor.sourceVideoSize,in:available)
                    let size=cropping ? sourceFit:fitVideo(editor.videoSize,in:available)
                    ZStack {
                        if cropping {
                            if let cropImage {
                                Image(decorative:cropImage,scale:1).resizable()
                            } else if cropFrameFailed {
                                Text("Could not load the original frame.").font(Geist.font(13)).foregroundStyle(Ink.secondary)
                            } else { ProgressView("Loading original frame…") }
                        } else {
                            NativePlayer(player:editor.player)
                                .clipShape(RoundedRectangle(cornerRadius:7))
                                .overlay { RoundedRectangle(cornerRadius:7).strokeBorder(.black.opacity(0.1),lineWidth:1) }
                                .shadow(color:.black.opacity(0.10),radius:22,y:10)
                        }
                        CropCanvas(size:size,sourceFit:sourceFit,selection:cropping ? cropSelection:savedSelection,
                                   editing:cropping,ready:cropImage != nil,ratio:cropRatio,begin:beginCrop,
                                   change:setCropSelection).disabled(locked)
                    }.frame(width:size.width,height:size.height)
                        .position(x:geometry.size.width/2,y:geometry.size.height/2)
                }
            } else { emptyState }
            if editor.busy {
                VStack(spacing: 12) { ProgressView(); Text(editor.message).font(Geist.font(13, .medium)) }
                    .padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay { if dropTargeted { RoundedRectangle(cornerRadius: 14).stroke(theme.accent, style: StrokeStyle(lineWidth: 2, dash: [6])).padding(12).allowsHitTesting(false) } }
        .dropDestination(for: URL.self) { urls, _ in
            guard !locked,!cropping, let url = urls.first, url.isFileURL else { return false }
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
            IconButton(symbol:"gobackward.5",title:"Back 5 seconds") { editor.skip(by:-5) }
            IconButton(symbol: editor.isPlaying ? "pause.fill" : "play.fill", title: editor.isPlaying ? "Pause" : "Play") { editor.togglePlayback() }
            IconButton(symbol:"goforward.5",title:"Forward 5 seconds") { editor.skip(by:5) }
            Text(clockText(editor.playhead)).font(Geist.font(12, .medium)).monospacedDigit().frame(width: 70)
            Text("/  \(clockText(editor.duration))").font(Geist.font(12)).monospacedDigit().foregroundStyle(Ink.secondary)
            Spacer()
            Text(cropping ? "Original frame" : "Fit").font(Geist.font(11))
                .foregroundStyle(Ink.secondary).frame(width:120,alignment:.trailing)
        }.padding(.horizontal,24).frame(height:56).background(Color.white).disabled(editor.project == nil || locked || cropping)
    }
    private func fitVideo(_ source:CGSize,in available:CGSize) -> CGSize {
        let aspect=max(0.001,source.width/max(1,source.height))
        let width=min(available.width,available.height*aspect)
        return CGSize(width:width,height:width/aspect)
    }
    private func beginCrop() {
        guard !cropping,!locked,editor.project != nil else { return }
        editor.player.pause()
        cropSelection=savedSelection
        draftAspect=editor.project?.crop?.aspect ?? .freeform
        editor.cropping=true
    }
    private func setCropSelection(_ rect:CGRect) {
        if cropping,VideoCrop(rect,aspect:draftAspect).fitsSource(editor.sourceVideoSize) {
            cropSelection=rect;aspectBaseline=nil
        }
    }
    private func chooseCropAspect(_ option:CropAspect) {
        guard !locked,editor.project != nil else { return }
        let ratio=option.normalizedRatio(source:editor.sourceVideoSize,current:savedSelection)
        let baseline=aspectBaseline ?? (cropping ? cropSelection:savedSelection)
        let proposed=CropAspect.fit(baseline,ratio:ratio)
        let fitted=VideoCrop(proposed,aspect:option).fitsSource(editor.sourceVideoSize) ? proposed:CropAspect.fit(CropControls.full,ratio:ratio)
        guard VideoCrop(fitted,aspect:option).fitsSource(editor.sourceVideoSize) else { return }
        beginCrop()
        aspectBaseline=baseline;draftAspect=option;cropSelection=fitted
    }
    private func resetCrop() {
        if cropping { draftAspect = .freeform;cropSelection=CropControls.full;aspectBaseline=nil }
        else { editor.applyCrop(nil) }
    }
    private func applyCrop() {
        guard cropImage != nil else { return }
        let crop=VideoCrop(cropSelection,aspect:draftAspect)
        guard crop.fitsSource(editor.sourceVideoSize) else { return }
        editor.applyCrop(cropSelection == CropControls.full && draftAspect == .freeform ? nil:crop)
        endCrop()
    }
    private func endCrop() {
        if cropping { editor.cropping=false }
        cropImage=nil;cropFrameFailed=false;aspectBaseline=nil
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
                HStack { Image(systemName:capture.hasSource ? "checkmark.circle" : "display").foregroundStyle(theme.accent);Text(capture.selectionStatus ?? capture.sourceSummary).font(Geist.font(12,.medium)).fixedSize(horizontal:false,vertical:true);Spacer();InfoHint(title:"Recording source",text:"Record a screen, one app window, or a selected area of a display. Size follows the selected source. If macOS requires it, choose the source in its sharing picker to authorize this session.") }
                HStack(spacing:8) {
                    Button(capture.hasSource ? "Change source…" : "Choose source…") { capture.chooseSource() }.buttonStyle(StudioButtonStyle()).feedbackTarget("recording.source","Recording source")
                    Button("Select area…") { capture.chooseArea() }.buttonStyle(StudioButtonStyle()).disabled(!capture.supportsArea).help("Drag an area of one display. Requires macOS 15.2 or later.").feedbackTarget("recording.area","Select recording area")
                }.disabled(capture.picking || capture.busy)
            }.frame(maxWidth:.infinity,alignment:.leading).padding(18).background(Ink.soft,in:RoundedRectangle(cornerRadius:10))
            if let area=capture.areaPreview {
                VStack(alignment:.leading,spacing:10) {
                    HStack {
                        Text("Recording area").font(Geist.font(12,.medium))
                        Spacer()
                        Text(area.dimensions).font(Geist.font(12,.medium)).monospacedDigit()
                        InfoHint(title:"Area recording permission",text:"macOS authorizes a display and calls its button Share Screen. Vizually Screen crops the stream to the rectangle shown here. Only that area is saved. The rest of the display is not saved in the video.")
                    }
                    GeometryReader { geometry in
                        let scale=min(geometry.size.width/area.displaySize.width,geometry.size.height/area.displaySize.height)
                        let size=CGSize(width:area.displaySize.width*scale,height:area.displaySize.height*scale)
                        ZStack(alignment:.topLeading) {
                            RoundedRectangle(cornerRadius:4).fill(Ink.line)
                            Rectangle().fill(theme.accent.opacity(0.18)).overlay(Rectangle().stroke(theme.accent,lineWidth:2))
                                .frame(width:area.rect.width*scale,height:area.rect.height*scale)
                                .offset(x:area.rect.minX*scale,y:area.rect.minY*scale)
                        }.frame(width:size.width,height:size.height).frame(maxWidth:.infinity,maxHeight:.infinity)
                    }.frame(height:100).accessibilityLabel("Only the highlighted rectangle will be recorded, \(area.dimensions)")
                    if capture.areaNeedsAuthorization {
                        Button("Allow area recording…",action:capture.authorizeArea).buttonStyle(StudioButtonStyle()).disabled(capture.picking)
                        Text("macOS will ask to share this display. Only the outlined area will be recorded.").font(Geist.font(11)).foregroundStyle(Ink.secondary).fixedSize(horizontal:false,vertical:true)
                    }
                }.padding(14).background(Ink.soft,in:RoundedRectangle(cornerRadius:10))
            }
            QualityPicker(selection:$capture.quality,recording:true).feedbackTarget("recording.quality","Recording quality")
            HStack { Toggle("Smooth pointer",isOn:$capture.smoothCursor).toggleStyle(.switch).tint(theme.accent).disabled(!capture.supportsSmoothPointer).feedbackTarget("recording.pointer","Smooth pointer");InfoHint(title:"Smooth pointer",text:"Records movement separately and renders a smooth arrow. Turn off to keep original cursor shapes, such as text selection and resize. Requires macOS 15.2 or later.") }
            HStack { Toggle("Automatic zoom",isOn:$capture.automaticZoom).toggleStyle(.switch).tint(theme.accent).disabled(!capture.smoothCursor).feedbackTarget("recording.zoom","Automatic zoom");InfoHint(title:"Automatic zoom",text:"Adds editable zooms where your pointer settles after moving. Requires Smooth pointer. You can adjust or remove each zoom in the editor.") }
            Toggle("Include system audio", isOn: $capture.systemAudio).toggleStyle(.switch).tint(theme.accent).feedbackTarget("recording.audio","System audio")
            HStack { Text("Saved to Movies/Vizually Screen").font(Geist.font(12)).foregroundStyle(Ink.secondary);InfoHint(title:"Saved recordings",text:"The original video and its pointer data are saved together in Movies/Vizually Screen. Stop recording from the app or menu bar.") }
            if let error = capture.error { Text(error).font(Geist.font(12)).foregroundStyle(.red).textSelection(.enabled) }
            HStack { Spacer(); Button("Cancel") { dismiss() }.buttonStyle(StudioButtonStyle()); Button(capture.areaPreview == nil ? "Start recording":"Record this area") { Task { await capture.start(); if capture.error == nil { dismiss() } } }.buttonStyle(StudioButtonStyle(primary: true)).disabled(!capture.hasSource || capture.busy || capture.picking || capture.areaNeedsAuthorization).feedbackTarget("recording.start",capture.areaPreview == nil ? "Start recording":"Record this area") }
        }.padding(28).frame(width: 450).foregroundStyle(Ink.primary).background(.white)
            .task { capture.restoreAreaIndicator();await capture.prepareDefaultSource() }
            .onDisappear { if !capture.recording && !capture.busy { capture.hideAreaIndicator() } }
    }
}
