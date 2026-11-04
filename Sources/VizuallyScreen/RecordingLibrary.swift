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
    private var storage:RecordingIndex { RecordingIndex(url:index) }
    init() { do { recent=try storage.read() } catch { self.error="Could not read the recording library: \(error.localizedDescription)" } }
    func register(_ source:URL,project:URL?) {
        guard !source.lastPathComponent.contains("studio-demo-") else { return }
        do {
            let key=RecordingIndex.canonical(source.path)
            var updated=try storage.read()
            let title=updated.first(where:{RecordingIndex.canonical($0.sourcePath) == key})?.title
            updated.removeAll { RecordingIndex.canonical($0.sourcePath) == key }
            updated.insert(RecordingReference(sourcePath:key,projectPath:project?.path,title:title),at:0)
            try storage.write(updated);recent=updated
        } catch { self.error="Could not save recent recordings: \(error.localizedDescription)" }
    }
    func rename(_ entry:RecordingReference,to title:String) {
        do {
            recent=try storage.rename(entry,to:title)
            generation=UUID();loading=false
            if let index=entries.firstIndex(where:{$0.id == entry.id}),let updated=recent.first(where:{$0.id == entry.id}) { entries[index]=updated }
            error=nil
        } catch { self.error="Could not rename recording: \(error.localizedDescription)" }
    }
    @discardableResult func trash(_ entry:RecordingReference) -> Bool {
        do {
            recent=try storage.remove(entry,trash:{ source in
                var result:NSURL?
                try FileManager.default.trashItem(at:source,resultingItemURL:&result)
                guard let result else { throw CocoaError(.fileWriteUnknown) }
                return result as URL
            },restore:{ trashed,source in try FileManager.default.moveItem(at:trashed,to:source) })
            generation=UUID();loading=false
            entries.removeAll { $0.id == entry.id };details[entry.id]=nil
            error=nil;return true
        } catch { self.error="Could not remove recording: \(error.localizedDescription)";return false }
    }
    func refresh() async {
        let token=UUID();generation=token;loading=true
        let movies=FileManager.default.urls(for:.moviesDirectory,in:.userDomainMask)[0]
        let roots=[movies.appendingPathComponent("Vizually Screen"),movies.appendingPathComponent("Framecraft"),Self.support.appendingPathComponent("Projects")]
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
