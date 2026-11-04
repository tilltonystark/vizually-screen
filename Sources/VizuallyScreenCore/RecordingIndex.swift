import Foundation

/// Local titles and recent-project associations; source files are never renamed.
package struct RecordingIndex {
    package let url:URL
    package init(url:URL) { self.url=url }
    package static func canonical(_ path:String) -> String { URL(fileURLWithPath:path).resolvingSymlinksInPath().standardizedFileURL.path }
    package func read() throws -> [RecordingReference] {
        guard FileManager.default.fileExists(atPath:url.path) else { return [] }
        return try JSONDecoder().decode([RecordingReference].self,from:Data(contentsOf:url))
    }
    package func write(_ entries:[RecordingReference]) throws {
        try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
        try JSONEncoder().encode(entries).write(to:url,options:.atomic)
    }
    package func rename(_ entry:RecordingReference,to value:String) throws -> [RecordingReference] {
        let title=value.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !title.isEmpty,title.count<=160,!title.unicodeScalars.contains(where:CharacterSet.controlCharacters.contains) else {
            throw NSError(domain:"VizuallyScreen.Library",code:1,userInfo:[NSLocalizedDescriptionKey:"Use a title of 1–160 characters on one line."])
        }
        let key=Self.canonical(entry.sourcePath)
        var entries=try read()
        var updated=entries.first(where:{ Self.canonical($0.sourcePath) == key }) ?? entry
        updated.sourcePath=key;updated.title=title
        entries.removeAll { Self.canonical($0.sourcePath) == key }
        entries.append(updated)
        try write(entries)
        return entries
    }
    /// On an index-write failure, restore the video so a failed action does not silently delete it.
    package func remove(_ entry:RecordingReference,trash:(URL)throws->URL,restore:(URL,URL)throws->Void) throws -> [RecordingReference] {
        let key=Self.canonical(entry.sourcePath)
        var entries=try read()
        entries.removeAll { Self.canonical($0.sourcePath) == key }
        let source=URL(fileURLWithPath:key)
        let trashed:URL?
        if FileManager.default.fileExists(atPath:source.path) {
            guard try source.resourceValues(forKeys:[.isRegularFileKey]).isRegularFile == true else { throw CocoaError(.fileReadUnsupportedScheme) }
            trashed=try trash(source)
        } else { trashed=nil }
        do { try write(entries) }
        catch {
            if let trashed {
                do { try restore(trashed,source) }
                catch let restoreError { throw NSError(domain:"VizuallyScreen.Library",code:2,userInfo:[NSLocalizedDescriptionKey:"The library could not be updated. The video is in Trash and could not be restored automatically: \(restoreError.localizedDescription)"]) }
            }
            throw error
        }
        return entries
    }
}
