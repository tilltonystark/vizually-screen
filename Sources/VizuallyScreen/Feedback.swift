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
        anchorPreference(key:FeedbackTargets.self,value:.bounds) { [FeedbackTarget(id:id,label:label,file:file,line:line,anchor:$0)] }
    }
}
struct AppFeedback:Codable,Identifiable {
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
        do { try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true);let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys];try encoder.encode(updated).write(to:url,options:.atomic);items=updated;error=nil;return true }
        catch { self.error="Could not save feedback: \(error.localizedDescription)";return false }
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
                    if let status=known["status"] as? String { updated[index].resolved=status == "resolved" || status == "dismissed" }
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
                // Persist each receipt so a later failure does not resend successful comments.
                _ = save(updated)
            }
            _ = save(updated)
        } catch { self.error="Saved locally. Agent connection unavailable. Retry when the local agent is running." }
    }
    func copy() { do { let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys];let data=try encoder.encode(items);NSPasteboard.general.clearContents();NSPasteboard.general.setString(String(decoding:data,as:UTF8.self),forType:.string) } catch { self.error=error.localizedDescription } }
}
struct FeedbackOverlay:View {
    @ObservedObject var store:FeedbackStore
    @ObservedObject var editor:Editor
    var targets:[FeedbackTarget]
    var geometry:GeometryProxy
    @State private var pointer:CGPoint?
    @State private var selected:FeedbackTarget?
    @State private var pin=CGPoint.zero
    @State private var comment=""
    @State private var pinnedTime:Double?
    @State private var showList=false
    @FocusState private var writing:Bool
    private func target(at point:CGPoint) -> FeedbackTarget? {
        targets.filter { geometry[$0.anchor].contains(point) }.min { let a=geometry[$0.anchor],b=geometry[$1.anchor];return a.width*a.height < b.width*b.height }
    }
    private var dialogPosition:CGPoint {
        CGPoint(x:min(max(pin.x+176,176),geometry.size.width-176),y:min(max(pin.y+125,170),geometry.size.height-130))
    }
    var body:some View {
        ZStack(alignment:.bottomLeading) {
            if store.enabled {
                Color.white.opacity(0.001).contentShape(Rectangle())
                    .onContinuousHover { phase in if case let .active(point)=phase { pointer=point } else { pointer=nil } }
                    .onTapGesture { point in if let target=target(at:point) { selected=target;pin=point;pinnedTime=editor.showsHome ? nil:editor.playhead;comment="";writing=true;showList=false } }
                if let target=selected ?? pointer.flatMap({target(at:$0)}) {
                    let rect=geometry[target.anchor]
                    RoundedRectangle(cornerRadius:5).stroke(.blue,lineWidth:2).background(.blue.opacity(0.06)).frame(width:rect.width,height:rect.height).position(x:rect.midX,y:rect.midY).allowsHitTesting(false)
                }
                ForEach(Array(store.items.filter{!$0.resolved && $0.route == (editor.showsHome ? "home":"editor")}.enumerated()),id:\.element.id) { index,item in
                    if let target=targets.first(where:{$0.id == item.targetID}) {
                        let rect=geometry[target.anchor]
                        Button { showList=true;selected=nil } label: { Text("\(index+1)").font(Geist.font(11,.semibold)).foregroundStyle(.white).frame(width:26,height:26).background(.blue,in:Circle()).overlay(Circle().stroke(.white,lineWidth:2)) }.buttonStyle(.plain).position(x:rect.minX+rect.width*item.point[0],y:rect.minY+rect.height*item.point[1]).help(item.comment)
                    }
                }
            }
            HStack(spacing:4) {
                Button { store.enabled.toggle();selected=nil } label: { Image(systemName:store.enabled ? "bubble.left.fill":"bubble.left").frame(width:32,height:32).foregroundStyle(store.enabled ? Color.blue:Ink.primary) }.keyboardShortcut("f",modifiers:[.command,.shift]).help(store.enabled ? "Exit comment mode (Esc)":"Comment on this app (⌘⇧F)").accessibilityLabel(store.enabled ? "Exit comment mode":"Comment on this app")
                Button { showList.toggle();selected=nil;Task { await store.sendPending() } } label: { Image(systemName:"list.bullet").frame(width:32,height:32) }.help("Saved feedback").accessibilityLabel("Saved feedback")
            }.buttonStyle(.plain).padding(4).background(.white,in:Capsule()).overlay(Capsule().strokeBorder(.black.opacity(0.1),lineWidth:0.5)).shadow(color:.black.opacity(0.08),radius:8,y:2).padding(.leading,20).padding(.bottom,36)
            if let target=selected {
                VStack(alignment:.leading,spacing:12) {
                    HStack { Text(target.label).font(StudioType.controlLabel).lineLimit(1);Spacer();Button { selected=nil } label: { Image(systemName:"xmark") }.buttonStyle(.plain).accessibilityLabel("Cancel comment") }
                    TextEditor(text:$comment).font(Geist.font(13)).focused($writing).frame(height:88).padding(6).background(Ink.soft,in:RoundedRectangle(cornerRadius:6)).accessibilityLabel("Feedback comment")
                    HStack { Text("Only this app's UI context").font(Geist.font(10)).foregroundStyle(Ink.secondary);Spacer();Button("Send to agent") { save(target) }.buttonStyle(StudioButtonStyle(primary:true)).disabled(comment.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || store.syncing) }
                }.padding(16).frame(width:320).background(.white,in:RoundedRectangle(cornerRadius:12)).overlay { RoundedRectangle(cornerRadius:12).strokeBorder(.black.opacity(0.12),lineWidth:0.5) }.shadow(color:.black.opacity(0.12),radius:18,y:6).position(dialogPosition)
                Circle().fill(.blue).frame(width:12,height:12).overlay(Circle().stroke(.white,lineWidth:2)).position(pin).allowsHitTesting(false)
            }
            if showList {
                VStack(alignment:.leading,spacing:12) {
                    HStack { Text("App feedback").font(StudioType.controlLabel);Spacer();Button { showList=false } label: { Image(systemName:"xmark") }.buttonStyle(.plain).accessibilityLabel("Close feedback list") }
                    if store.items.isEmpty { Text("Turn on comment mode, then click any area.").font(StudioType.caption) }
                    ScrollView {
                        LazyVStack(alignment:.leading,spacing:16) {
                            ForEach(store.items) { item in
                                VStack(alignment:.leading,spacing:6) {
                                    Text(item.targetLabel).font(StudioType.controlLabel)
                                    Text(item.comment).font(StudioType.caption).textSelection(.enabled)
                                    Text(item.resolved ? "Resolved":item.agentID == nil ? "Saved · waiting to send":"Sent to agent").font(Geist.font(11)).foregroundStyle(Ink.secondary)
                                    Divider()
                                }
                            }
                        }
                    }.frame(height:230)
                    HStack { Button(store.syncing ? "Sending…":"Retry / refresh") { Task { await store.sendPending() } }.disabled(store.syncing);Spacer();Button("Copy",action:store.copy) }.font(StudioType.caption)
                    if let error=store.error { Text(error).font(StudioType.caption).foregroundStyle(.red) }
                }.padding(16).frame(width:300).background(.white,in:RoundedRectangle(cornerRadius:12)).overlay { RoundedRectangle(cornerRadius:12).strokeBorder(.black.opacity(0.1),lineWidth:0.5) }.shadow(color:.black.opacity(0.1),radius:16,y:4).padding(.leading,20).padding(.bottom,90)
            }
        }.onChange(of:store.enabled) { _,enabled in if enabled { editor.player.pause() } }
        .onExitCommand { selected=nil;store.enabled=false;showList=false }
    }
    private func save(_ target:FeedbackTarget) {
        let rect=geometry[target.anchor]
        let item=AppFeedback(targetID:target.id,targetLabel:target.label,sourceFile:target.file,sourceLine:target.line,route:editor.showsHome ? "home":"editor",playbackTime:pinnedTime,bounds:[rect.minX,rect.minY,rect.width,rect.height],point:[(pin.x-rect.minX)/max(1,rect.width),(pin.y-rect.minY)/max(1,rect.height)],viewport:[geometry.size.width,geometry.size.height],build:Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "development",comment:comment.trimmingCharacters(in:.whitespacesAndNewlines))
        if store.add(item) { selected=nil;comment="";showList=true;Task { await store.sendPending() } }
    }
}
