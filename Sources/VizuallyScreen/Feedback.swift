import SwiftUI

struct FeedbackTarget {
    var id:String
    var label:String
    var file:String
    var line:Int
    var anchor:Anchor<CGRect>
}
struct FeedbackTargets:PreferenceKey {
    static var defaultValue:[FeedbackTarget] { [] }
    static func reduce(value:inout [FeedbackTarget],nextValue:()->[FeedbackTarget]) { value += nextValue() }
}
extension View {
    func feedbackTarget(_ id:String,_ label:String,file:String = #fileID,line:Int = #line) -> some View {
        transformAnchorPreference(key:FeedbackTargets.self,value:.bounds) { targets,anchor in targets.append(FeedbackTarget(id:id,label:label,file:file,line:line,anchor:anchor)) }
    }
}
struct AppFeedback:Codable,Identifiable,Equatable {
    var id:UUID = UUID()
    var created:Date = Date()
    var targetID:String
    var targetLabel:String
    var sourceFile:String
    var sourceLine:Int
    var route:String
    var playbackTime:Double?
    var bounds:[Double]
    var point:[Double]
    var viewport:[Double]
    var build:String
    var comment:String
    var resolved:Bool = false
    var agentID:String? = nil
    var agentStatus:String? = nil
}
@MainActor final class FeedbackStore:ObservableObject {
    @Published var enabled=false
    @Published var items:[AppFeedback]=[]
    @Published var error:String?
    @Published private(set) var syncing=false
    private let endpoint=URL(string:"http://127.0.0.1:4747")!
    private var sessionID:String? = UserDefaults.standard.string(forKey:"feedback.agentation.session")
    var url:URL { RecordingLibrary.support.appendingPathComponent("Feedback/feedback.json") }
    init() {
        do { if FileManager.default.fileExists(atPath:url.path) { items=try JSONDecoder().decode([AppFeedback].self,from:Data(contentsOf:url)) } }
        catch { self.error="Could not read saved feedback: \(error.localizedDescription)" }
    }
    func add(_ item:AppFeedback) -> Bool {
        var updated=items;updated.insert(item,at:0)
        return save(updated)
    }
    func resolve(_ id:UUID) { var updated=items;if let i=updated.firstIndex(where:{$0.id == id}) { updated[i].resolved.toggle();_ = save(updated) } }
    private func save(_ updated:[AppFeedback]) -> Bool {
        if updated == items { error=nil;return true }
        do { try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true);let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys];try encoder.encode(updated).write(to:url,options:.atomic);items=updated;error=nil;return true }
        catch { self.error="Could not save feedback: \(error.localizedDescription)";return false }
    }
    private func saveReceipts(_ received:[AppFeedback]) {
        var merged=items
        for receipt in received {
            if let index=merged.firstIndex(where:{$0.id == receipt.id}) {
                merged[index].agentID=receipt.agentID;merged[index].agentStatus=receipt.agentStatus;merged[index].resolved=receipt.resolved
            }
        }
        _ = save(merged)
    }
    private func request(_ path:String,body:[String:Any]? = nil) async throws -> [String:Any] {
        var request=URLRequest(url:endpoint.appendingPathComponent(path));request.timeoutInterval=3
        if let body { request.httpMethod="POST";request.setValue("application/json",forHTTPHeaderField:"Content-Type");request.httpBody=try JSONSerialization.data(withJSONObject:body) }
        let (data,response)=try await URLSession.shared.data(for:request)
        guard let http=response as? HTTPURLResponse,(200...299).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return (try JSONSerialization.jsonObject(with:data)) as? [String:Any] ?? [:]
    }
    func sendPending() async {
        guard !syncing else { return };syncing=true;defer { syncing=false }
        do {
            var session:[String:Any]?
            if let id=sessionID { session=try? await request("sessions/\(id)") }
            if session == nil { session=try await request("sessions",body:["url":"vizually-screen://native/workspace"]);sessionID=session?["id"] as? String;UserDefaults.standard.set(sessionID,forKey:"feedback.agentation.session") }
            guard let id=sessionID else { throw URLError(.cannotParseResponse) }
            let remote=session?["annotations"] as? [[String:Any]] ?? []
            var updated=items
            for index in updated.indices {
                if let known=remote.first(where:{ ($0["attributes"] as? [String:String])?["localFeedbackID"] == updated[index].id.uuidString }),let remoteID=known["id"] as? String {
                    updated[index].agentID=remoteID
                    if let status=known["status"] as? String { updated[index].agentStatus=status;updated[index].resolved=status == "resolved" || status == "dismissed" }
                }
                guard updated[index].agentID == nil,!updated[index].resolved else { continue }
                let item=updated[index]
                let annotation=try await request("sessions/\(id)/annotations",body:[
                    "x":item.bounds[0]+item.bounds[2]*item.point[0],"y":item.bounds[1]+item.bounds[3]*item.point[1],
                    "comment":item.comment,"element":item.targetLabel,"elementPath":"SwiftUI/\(item.route)/\(item.targetID)",
                    "timestamp":item.created.timeIntervalSince1970*1000,"sourceFile":"\(item.sourceFile):\(item.sourceLine)",
                    "boundingBox":["x":item.bounds[0],"y":item.bounds[1],"width":item.bounds[2],"height":item.bounds[3]],
                    "attributes":["localFeedbackID":item.id.uuidString,"app":"Vizually Screen","build":item.build,"route":item.route,"playbackTime":item.playbackTime.map(String.init(describing:)) ?? "none"],"kind":"feedback"
                ])
                updated[index].agentID=annotation["id"] as? String
                updated[index].agentStatus="pending"
                // Persist each receipt so a later failure does not resend successful comments.
                saveReceipts(updated)
            }
            saveReceipts(updated)
        } catch { self.error="Saved locally. Agent connection unavailable. Retry when the local agent is running." }
    }
    func copy() { do { let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys];let data=try encoder.encode(items);NSPasteboard.general.clearContents();NSPasteboard.general.setString(String(decoding:data,as:UTF8.self),forType:.string) } catch { self.error=error.localizedDescription } }
}
struct FeedbackSurface:ViewModifier {
    @ObservedObject var store:FeedbackStore
    @ObservedObject var editor:Editor
    var route:String
    func body(content:Content) -> some View {
        content.padding(.bottom,["recording","export","appearance"].contains(route) ? 76:0).background(.white).feedbackTarget("surface.\(route)",route.capitalized)
            .overlayPreferenceValue(FeedbackTargets.self) { targets in
                GeometryReader { geometry in FeedbackOverlay(store:store,editor:editor,route:route,targets:targets,geometry:geometry) }
            }
    }
}
extension View {
    func feedbackSurface(store:FeedbackStore,editor:Editor,route:String) -> some View { modifier(FeedbackSurface(store:store,editor:editor,route:route)) }
}
struct FeedbackOverlay:View {
    @ObservedObject var store:FeedbackStore
    @ObservedObject var editor:Editor
    var route:String
    var targets:[FeedbackTarget]
    var geometry:GeometryProxy
    @State private var pointer:CGPoint?
    @State private var selected:FeedbackTarget?
    @State private var pin=CGPoint.zero
    @State private var comment=""
    @State private var pinnedTime:Double?
    private func target(at point:CGPoint) -> FeedbackTarget? {
        targets.filter { geometry[$0.anchor].contains(point) }.min { let a=geometry[$0.anchor],b=geometry[$1.anchor];return a.width*a.height < b.width*b.height }
    }
    private var dialogPosition:CGPoint {
        CGPoint(x:min(max(pin.x+176,176),geometry.size.width-176),y:min(max(pin.y+125,150),geometry.size.height-130))
    }
    private var fabRect:CGRect { CGRect(x:geometry.size.width-72,y:geometry.size.height-84,width:56,height:56) }
    private var exclusions:[CGRect] {
        var rects=[fabRect.insetBy(dx:-8,dy:-8)]
        if selected != nil { rects.append(CGRect(x:dialogPosition.x-176,y:dialogPosition.y-125,width:352,height:250)) }
        return rects
    }
    private var status:(String,Color) {
        guard let latest=store.items.first else { return ("Comment on this app (C)",Ink.muted) }
        if latest.resolved { return ("Latest feedback completed",.green) }
        if latest.agentStatus == "acknowledged" { return ("Agent working on latest feedback",.blue) }
        return (latest.agentID == nil ? "Waiting to connect · saved locally":"Latest feedback queued",.orange)
    }
    var body:some View {
        ZStack(alignment:.bottomTrailing) {
            FeedbackEvents(selecting:store.enabled,exclusions:exclusions,onMove:{ pointer=$0 },onClick:{ point in
                if let target=target(at:point) { selected=target;pin=point;pinnedTime=route == "editor" ? editor.playhead:nil;comment="" }
            },onToggle:toggle).frame(maxWidth:.infinity,maxHeight:.infinity)
            if store.enabled,let target=selected ?? pointer.flatMap({target(at:$0)}) {
                let rect=geometry[target.anchor]
                RoundedRectangle(cornerRadius:5).stroke(.blue,lineWidth:2).background(.blue.opacity(0.08)).frame(width:rect.width,height:rect.height).position(x:rect.midX,y:rect.midY).allowsHitTesting(false)
                if selected == nil {
                    Text(target.label).font(Geist.font(11,.medium)).padding(.horizontal,8).padding(.vertical,5).foregroundStyle(.white).background(.blue,in:Capsule()).position(x:min(max(rect.midX,90),geometry.size.width-90),y:max(14,rect.minY-14)).allowsHitTesting(false)
                }
            }
            Button(action:toggle) {
                Image(systemName:store.enabled ? "bubble.left.fill":"bubble.left").font(.system(size:19,weight:.medium)).foregroundStyle(store.enabled ? .white:Ink.primary).frame(width:48,height:48).background(store.enabled ? Color.blue:.white,in:Circle()).overlay(Circle().strokeBorder(.black.opacity(0.1),lineWidth:0.5))
                    .overlay(alignment:.topTrailing) { Circle().fill(status.1).frame(width:10,height:10).overlay(Circle().stroke(.white,lineWidth:2)).accessibilityHidden(true) }
            }.buttonStyle(.plain).shadow(color:.black.opacity(0.12),radius:10,y:4).help("\(status.0) · C toggles comment mode").accessibilityLabel(store.enabled ? "Exit comment mode":"Comment on this app").accessibilityValue(status.0).padding(.trailing,20).padding(.bottom,32)
            if let target=selected {
                VStack(alignment:.leading,spacing:12) {
                    HStack { Text(target.label).font(StudioType.controlLabel).lineLimit(1);Spacer();Button { selected=nil } label: { Image(systemName:"xmark") }.buttonStyle(.plain).accessibilityLabel("Cancel comment") }
                    FeedbackInput(text:$comment) { submit(target) }.frame(height:88).padding(6).background(Ink.soft,in:RoundedRectangle(cornerRadius:6))
                    HStack { Text("Enter to send · Shift↵ new line").font(Geist.font(10)).foregroundStyle(Ink.secondary);Spacer();Button("Send") { submit(target) }.buttonStyle(StudioButtonStyle(primary:true)).disabled(comment.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty) }
                    if let error=store.error { Text(error).font(StudioType.caption).foregroundStyle(.red) }
                }.padding(16).frame(width:320).background(.white,in:RoundedRectangle(cornerRadius:12)).overlay { RoundedRectangle(cornerRadius:12).strokeBorder(.black.opacity(0.12),lineWidth:0.5) }.shadow(color:.black.opacity(0.12),radius:18,y:6).position(dialogPosition)
                Circle().fill(.blue).frame(width:12,height:12).overlay(Circle().stroke(.white,lineWidth:2)).position(pin).allowsHitTesting(false)
            }
        }.onChange(of:store.enabled) { _,enabled in if enabled { editor.player.pause() } else { selected=nil;pointer=nil } }
        .onExitCommand { selected=nil;store.enabled=false }
        .task {
            while !Task.isCancelled {
                if !store.items.isEmpty { await store.sendPending() }
                try? await Task.sleep(nanoseconds:3_000_000_000)
            }
        }
    }
    private func toggle() { store.enabled.toggle();selected=nil;pointer=nil }
    private func submit(_ target:FeedbackTarget) {
        guard !comment.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return }
        let rect=geometry[target.anchor]
        let item=AppFeedback(targetID:target.id,targetLabel:target.label,sourceFile:target.file,sourceLine:target.line,route:route,playbackTime:pinnedTime,bounds:[rect.minX,rect.minY,rect.width,rect.height],point:[(pin.x-rect.minX)/max(1,rect.width),(pin.y-rect.minY)/max(1,rect.height)],viewport:[geometry.size.width,geometry.size.height],build:Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "development",comment:comment.trimmingCharacters(in:.whitespacesAndNewlines))
        if store.add(item) { selected=nil;comment="";Task { await store.sendPending() } }
    }
}

/// Use one AppKit coordinate conversion for input and geometry. Transparent to
/// normal interaction; only selection clicks outside our draft/FAB are consumed.
struct FeedbackEvents:NSViewRepresentable {
    var selecting:Bool
    var exclusions:[CGRect]
    var onMove:(CGPoint?)->Void
    var onClick:(CGPoint)->Void
    var onToggle:()->Void
    func makeNSView(context:Context) -> EventView { let view=EventView();view.config=self;return view }
    func updateNSView(_ view:EventView,context:Context) { view.config=self }
    final class EventView:NSView {
        var config:FeedbackEvents?
        private var monitor:Any?
        override var isFlipped:Bool { true }
        override func hitTest(_ point:NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor);self.monitor=nil }
            guard let window else { return };window.acceptsMouseMovedEvents=true
            monitor=NSEvent.addLocalMonitorForEvents(matching:[.mouseMoved,.leftMouseDown,.keyDown]) { [weak self] event in
                guard let self,let config=self.config,event.window === self.window else { return event }
                if event.type == .keyDown {
                    let typing=(self.window?.firstResponder as? NSTextView)?.isEditable == true || self.window?.firstResponder is NSTextField
                    if !typing,!event.isARepeat,event.modifierFlags.intersection([.command,.control,.option]).isEmpty,event.charactersIgnoringModifiers?.lowercased() == "c" { config.onToggle();return nil }
                    return event
                }
                guard config.selecting else { return event }
                let point=self.convert(event.locationInWindow,from:nil)
                guard self.bounds.contains(point),!config.exclusions.contains(where:{$0.contains(point)}) else { if event.type == .mouseMoved { config.onMove(nil) };return event }
                if event.type == .mouseMoved { config.onMove(point);return nil }
                config.onClick(point);return nil
            }
        }
        deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    }
}
struct FeedbackInput:NSViewRepresentable {
    @Binding var text:String
    var submit:()->Void
    func makeNSView(context:Context) -> NSScrollView {
        let scroll=NSScrollView();scroll.drawsBackground=false;scroll.hasVerticalScroller=true
        let input=InputView(frame:NSRect(x:0,y:0,width:288,height:88));input.minSize = .zero;input.maxSize=NSSize(width:CGFloat.greatestFiniteMagnitude,height:CGFloat.greatestFiniteMagnitude);input.isRichText=false;input.drawsBackground=false;input.font=NSFont(name:"Geist-Regular",size:13) ?? NSFont.systemFont(ofSize:13);input.textContainerInset=NSSize(width:5,height:5)
        input.isVerticallyResizable=true;input.isHorizontallyResizable=false;input.autoresizingMask=[.width];input.textContainer?.widthTracksTextView=true
        input.delegate=context.coordinator;input.onSubmit=submit;input.setAccessibilityLabel("Feedback comment")
        scroll.documentView=input
        DispatchQueue.main.async { input.window?.makeFirstResponder(input) }
        return scroll
    }
    func updateNSView(_ scroll:NSScrollView,context:Context) { context.coordinator.parent=self;if let input=scroll.documentView as? InputView { if input.string != text { input.string=text };input.onSubmit=submit } }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator:NSObject,NSTextViewDelegate {
        var parent:FeedbackInput
        init(_ parent:FeedbackInput) { self.parent=parent }
        func textDidChange(_ notification:Notification) { if let view=notification.object as? NSTextView { parent.text=view.string } }
    }
    final class InputView:NSTextView {
        var onSubmit:(()->Void)?
        override func keyDown(with event:NSEvent) { if [36,76].contains(event.keyCode),!event.modifierFlags.contains(.shift) { onSubmit?() } else { super.keyDown(with:event) } }
    }
}
