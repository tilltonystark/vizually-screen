import AppKit
import AVFoundation
import VizuallyScreenCore

@MainActor
final class RecordingLibrary:ObservableObject {
    struct Details { var image:NSImage?;var duration:Double;var error:String? }
    @Published private(set) var entries:[RecordingReference]=[]
    @Published private(set) var details:[String:Details]=[:]
    @Published private(set) var loading=false
    @Published var error:String?
    private var recent:[RecordingReference]=[]
    private var generation=UUID()
    private var loadingDetails=Set<String>()
    static var support:URL { FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("Vizually Screen") }
    private var index:URL { Self.support.appendingPathComponent("library.json") }
    init() { if let data=try? Data(contentsOf:index),let saved=try? JSONDecoder().decode([RecordingReference].self,from:data) { recent=saved } }
    func register(_ source:URL,project:URL?) {
        guard !source.lastPathComponent.contains("studio-demo-") else { return }
        recent.removeAll { $0.sourcePath == source.path }
        recent.insert(RecordingReference(sourcePath:source.path,projectPath:project?.path),at:0)
        do {
            try FileManager.default.createDirectory(at:Self.support,withIntermediateDirectories:true)
            try JSONEncoder().encode(recent).write(to:index,options:.atomic)
        } catch { self.error="Could not save recent recordings: \(error.localizedDescription)" }
    }
    func refresh() async {
        let token=UUID();generation=token;loading=true
        let movies=FileManager.default.urls(for:.moviesDirectory,in:.userDomainMask)[0]
        let roots=[movies.appendingPathComponent("Vizually Screen"),movies.appendingPathComponent("Framecraft")]
        let recent=self.recent
        let found=await Task.detached(priority:.userInitiated) { RecordingCatalog.scan(roots:roots,recent:recent) }.value
        guard generation == token else { return }
        entries=found;loading=false
    }
    func loadDetails(_ entry:RecordingReference) async {
        guard details[entry.id] == nil,!loadingDetails.contains(entry.id) else { return }
        loadingDetails.insert(entry.id);defer { loadingDetails.remove(entry.id) }
        do {
            let asset=AVURLAsset(url:URL(fileURLWithPath:entry.sourcePath))
            let duration=try await asset.load(.duration).seconds
            guard duration.isFinite,duration>0 else { throw CocoaError(.fileReadCorruptFile) }
            let generator=AVAssetImageGenerator(asset:asset);generator.appliesPreferredTrackTransform=true;generator.maximumSize=CGSize(width:600,height:360)
            let image=try? await generator.image(at:CMTime(seconds:min(0.5,duration/3),preferredTimescale:600)).image
            details[entry.id]=Details(image:image.map { NSImage(cgImage:$0,size:.zero) },duration:duration,error:nil)
        } catch { details[entry.id]=Details(image:nil,duration:0,error:"Source unavailable") }
    }
}
