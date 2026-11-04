import Foundation

package struct RecordingReference:Codable,Identifiable,Equatable {
    package var sourcePath:String
    package var projectPath:String?
    package var updated:Date
    package var id:String { sourcePath }
    package init(sourcePath:String,projectPath:String? = nil,updated:Date = Date()) { self.sourcePath=sourcePath;self.projectPath=projectPath;self.updated=updated }
}
package enum RecordingCatalog {
    package static func scan(roots:[URL],recent:[RecordingReference]) -> [RecordingReference] {
        func canonical(_ path:String) -> String { URL(fileURLWithPath:path).resolvingSymlinksInPath().standardizedFileURL.path }
        var entries=Dictionary(recent.map { value in var item=value;item.sourcePath=canonical(item.sourcePath);return (item.sourcePath,item) },uniquingKeysWith:{ $0.updated>$1.updated ? $0:$1 })
        struct SourceOnly:Decodable { let sourcePath:String }
        for root in roots {
            let files=((try? FileManager.default.contentsOfDirectory(at:root,includingPropertiesForKeys:[.contentModificationDateKey,.isRegularFileKey,.fileSizeKey],options:.skipsHiddenFiles)) ?? []).map { URL(fileURLWithPath:canonical($0.path)) }
            for file in files where ["mp4","mov","m4v"].contains(file.pathExtension.lowercased()) {
                guard (try? file.resourceValues(forKeys:[.isRegularFileKey]).isRegularFile) == true else { continue }
                if entries[file.path] == nil { entries[file.path]=RecordingReference(sourcePath:file.path,projectPath:ProjectFiles.adjacentProject(for:file)?.path,updated:(try? file.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }
            }
            // Include saved edits with custom filenames, not only adjacent sidecars.
            for file in files where file.pathExtension == "json" {
                guard let size=try? file.resourceValues(forKeys:[.fileSizeKey]).fileSize,size<50_000_000,let data=try? Data(contentsOf:file),let summary=try? JSONDecoder().decode(SourceOnly.self,from:data),var entry=entries[canonical(summary.sourcePath)] else { continue }
                let date=(try? file.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let currentDate=entry.projectPath.flatMap { try? URL(fileURLWithPath:$0).resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate } ?? .distantPast
                if date>currentDate { entry.projectPath=file.path;entries[entry.id]=entry }
            }
        }
        return entries.values.sorted { $0.updated == $1.updated ? $0.sourcePath<$1.sourcePath:$0.updated>$1.updated }
    }
}
