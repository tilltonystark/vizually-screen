import Foundation

package enum ProjectFiles {
    package static func sidecar(for video:URL) -> URL { video.deletingPathExtension().appendingPathExtension("vizually.json") }
    package static func candidates(for video:URL) -> [URL] {
        [sidecar(for:video),video.deletingPathExtension().appendingPathExtension("framecraft.json")]
    }
    package static func adjacentProject(for video:URL) -> URL? {
        candidates(for:video).first { FileManager.default.fileExists(atPath:$0.path) }
    }
}
