import SwiftUI
import CryptoKit
import VizuallyScreenCore

struct WorkspaceView:View {
    @ObservedObject var editor:Editor
    @ObservedObject var capture:Capture
    @StateObject private var library=RecordingLibrary()
    @EnvironmentObject private var feedback:FeedbackStore
    @EnvironmentObject var theme:StudioTheme
    @State private var showRecording=false
    var body:some View {
        Group {
            if editor.showsHome { HomeView(editor:editor,library:library) { showRecording=true } }
            else { StudioView(editor:editor,capture:capture,showRecording:$showRecording) }
        }
        .feedbackSurface(store:feedback,editor:editor,route:editor.showsHome ? "home":"editor")
        .ignoresSafeArea(.container,edges:.top)
        .sheet(isPresented:$showRecording) { RecordingSheet(capture:capture).feedbackSurface(store:feedback,editor:editor,route:"recording").environmentObject(theme).font(Geist.font()).preferredColorScheme(.light) }
        .onAppear { editor.onLibraryChange={ source,project in library.register(source,project:project) } }
        .task { await library.refresh() }
        .onReceive(NotificationCenter.default.publisher(for:NSApplication.didBecomeActiveNotification)) { _ in Task { await library.refresh() } }
        .onChange(of:editor.showsHome) { _,home in if home { Task { await library.refresh() } } }
        .onChange(of:capture.recording) { _,recording in if recording { editor.player.pause();editor.showsHome=false } }
        .alert("Unable to complete action",isPresented:Binding(get:{editor.error != nil || capture.error != nil},set:{if !$0 {editor.error=nil;capture.error=nil}})) {
            Button("OK") { editor.error=nil;capture.error=nil }
        } message: { Text(editor.error ?? capture.error ?? "") }
    }
}
struct HomeView:View {
    @ObservedObject var editor:Editor
    @ObservedObject var library:RecordingLibrary
    let record:()->Void
    @EnvironmentObject var theme:StudioTheme
    @State private var query=""
    @FocusState private var recordFocused:Bool
    private var filtered:[RecordingReference] { library.entries.filter { query.isEmpty || URL(fileURLWithPath:$0.sourcePath).lastPathComponent.localizedCaseInsensitiveContains(query) } }
    var body:some View {
        VStack(spacing:0) {
            HStack(spacing:12) {
                Text("Vizually Screen").font(Geist.font(15,.semibold)).feedbackTarget("home.title","App name")
                Spacer()
                HStack(spacing:8) { Image(systemName:"magnifyingglass").foregroundStyle(Ink.muted);TextField("Search recordings",text:$query).textFieldStyle(.plain).font(StudioType.caption) }.padding(10).frame(width:240).feedbackTarget("home.search","Search recordings").background(Ink.soft,in:RoundedRectangle(cornerRadius:8))
                IconButton(symbol:"arrow.clockwise",title:"Refresh recordings") { Task { await library.refresh() } }
                IconButton(symbol:"square.and.arrow.down",title:"Import video",action:editor.importVideo).feedbackTarget("home.import","Import video")
                Button(action:record) { Label("New recording",systemImage:"record.circle") }.buttonStyle(StudioButtonStyle(primary:true)).feedbackTarget("home.record","New recording").focused($recordFocused)
            }.padding(.leading,StudioLayout.headerLeading).padding(.trailing,24).frame(height:StudioLayout.headerHeight).contentShape(Rectangle()).gesture(WindowDragGesture())
            Rule()
            HStack(spacing:0) {
                VStack(alignment:.leading,spacing:16) {
                    Text("LIBRARY").feedbackTarget("home.sidebar.heading","Library heading").font(Geist.font(10,.medium)).tracking(1).foregroundStyle(Ink.muted)
                    Label("All recordings",systemImage:"square.grid.2x2").font(StudioType.controlLabel).foregroundStyle(theme.accent).padding(12).frame(maxWidth:.infinity,alignment:.leading).background(theme.tint,in:RoundedRectangle(cornerRadius:8)).feedbackTarget("home.sidebar.all","All recordings")
                    Label("On this Mac",systemImage:"internaldrive").font(StudioType.caption).foregroundStyle(Ink.secondary).padding(.horizontal,12).feedbackTarget("home.sidebar.local","On this Mac")
                    Spacer()
                    Button { Task { await editor.loadDemo() } } label: { Label("Explore demo",systemImage:"play.rectangle") }.buttonStyle(StudioButtonStyle(quiet:true)).feedbackTarget("home.sidebar.demo","Explore demo")
                    Button("Open project…",action:editor.openProject).buttonStyle(StudioButtonStyle(quiet:true)).feedbackTarget("home.sidebar.open","Open project")
                }.padding(20).frame(width:190).background(.white)
                Rule(vertical:true)
                VStack(alignment:.leading,spacing:24) {
                    HStack(alignment:.center,spacing:10) {
                        Text("Recordings").font(Geist.font(26,.semibold)).tracking(-0.6).feedbackTarget("home.recordings.heading","Recordings heading")
                        Text("\(library.entries.count)").font(Geist.font(12,.medium)).monospacedDigit().foregroundStyle(Ink.secondary).padding(.horizontal,8).frame(minWidth:28,minHeight:28).background(.white,in:Capsule()).overlay(Capsule().strokeBorder(Ink.line,lineWidth:0.5)).feedbackTarget("home.recordings.count","Recording count")
                        Spacer()
                        Text("Most recent").font(StudioType.caption).foregroundStyle(Ink.secondary)
                    }
                    if let error=library.error { Label(error,systemImage:"exclamationmark.triangle").font(StudioType.caption).foregroundStyle(.red) }
                    if library.loading && library.entries.isEmpty { ProgressView("Loading recordings…").frame(maxWidth:.infinity,maxHeight:.infinity) }
                    else if filtered.isEmpty {
                        VStack(spacing:16) {
                            Image(systemName:query.isEmpty ? "rectangle.stack":"magnifyingglass").font(.system(size:34,weight:.light)).foregroundStyle(theme.accent)
                            Text(query.isEmpty ? "Your next walkthrough starts here":"No recordings found").font(Geist.font(20,.semibold))
                            if query.isEmpty { Button("Record a screen",action:record).buttonStyle(StudioButtonStyle()) }
                        }.frame(maxWidth:.infinity,maxHeight:.infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns:[GridItem(.adaptive(minimum:240,maximum:420),spacing:24)],alignment:.leading,spacing:24) {
                                ForEach(filtered) { entry in card(entry) }
                            }.padding(.bottom,24)
                        }
                    }
                }.padding(32).frame(maxWidth:.infinity,maxHeight:.infinity).background(theme.canvas)
            }
        }.background(.white).background(WindowChrome()).disabled(editor.busy)
        .defaultFocus($recordFocused,true)
    }
    private func card(_ entry:RecordingReference) -> some View {
        let detail=library.details[entry.id]
        return Button { editor.openRecording(entry) } label: {
            VStack(alignment:.leading,spacing:0) {
                ZStack(alignment:.bottomTrailing) {
                    RoundedRectangle(cornerRadius:10).fill(Ink.soft)
                    if let image=detail?.image { GeometryReader { g in Image(nsImage:image).resizable().scaledToFill().frame(width:g.size.width,height:g.size.height).clipped() } }
                    else { Image(systemName:"film").font(.system(size:28,weight:.light)).foregroundStyle(Ink.muted).frame(maxWidth:.infinity,maxHeight:.infinity) }
                    if let detail,detail.error == nil { Text(clockText(detail.duration)).font(Geist.font(11,.medium)).monospacedDigit().padding(6).foregroundStyle(.white).background(.black.opacity(0.7),in:RoundedRectangle(cornerRadius:5)).padding(10) }
                }.aspectRatio(16/10,contentMode:.fit).clipped()
                VStack(alignment:.leading,spacing:7) {
                    Text(URL(fileURLWithPath:entry.sourcePath).deletingPathExtension().lastPathComponent).font(StudioType.controlLabel).foregroundStyle(Ink.primary).lineLimit(1).truncationMode(.middle)
                    HStack { Text(entry.updated,style:.date);Spacer();Text(detail?.error ?? (entry.projectPath == nil ? "Original":"Saved edit")) }.font(Geist.font(11)).foregroundStyle(detail?.error == nil ? Ink.secondary:.red)
                }.padding(14).frame(maxWidth:.infinity,alignment:.leading)
            }.background(.white).clipShape(RoundedRectangle(cornerRadius:10)).overlay { RoundedRectangle(cornerRadius:10).strokeBorder(.black.opacity(0.07),lineWidth:0.5) }
        }.buttonStyle(.plain).disabled(detail?.error != nil).accessibilityLabel("Open \(URL(fileURLWithPath:entry.sourcePath).deletingPathExtension().lastPathComponent)")
            .feedbackTarget("library.recording.\(SHA256.hash(data:Data(entry.id.utf8)).prefix(8).map { String(format:"%02x",$0) }.joined())", "Recording: \(URL(fileURLWithPath:entry.sourcePath).lastPathComponent)")
            .contextMenu { Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath:entry.sourcePath)]) } }
            .task { await library.loadDetails(entry) }
    }
}
