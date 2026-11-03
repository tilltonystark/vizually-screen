import Foundation

package struct Zoom: Codable, Identifiable, Equatable {
    package var id = UUID()
    package var start: Double
    package var duration: Double = 3
    package var scale: Double = 1.8
    package var x: Double = 0.5
    package var y: Double = 0.5
    package init(id: UUID = UUID(), start: Double, duration: Double = 3, scale: Double = 1.8, x: Double = 0.5, y: Double = 0.5) { self.id = id; self.start = start; self.duration = duration; self.scale = scale; self.x = x; self.y = y }
    package func amount(at time: Double) -> Double {
        guard duration > 0, time >= start, time <= start + duration else { return 0 }
        let ramp = min(0.6, duration / 2)
        let t = min(1, min((time - start) / ramp, (start + duration - time) / ramp))
        return t * t * (3 - 2 * t)
    }
}

package struct Project: Codable {
    package var version = 1
    package var sourcePath: String
    package var trimStart: Double = 0
    package var trimEnd: Double
    package var padding: Double = 0.07
    package var background: String = "Lavender"
    package var zooms: [Zoom] = []
    package init(sourcePath: String, trimStart: Double = 0, trimEnd: Double) { self.sourcePath = sourcePath; self.trimStart = trimStart; self.trimEnd = trimEnd }
    package static func minimumEditableInterval(duration: Double) -> Double {
        duration.isFinite && duration > 0 ? min(0.1, duration) : 0
    }
    package mutating func setTrimStart(_ value: Double, duration: Double) {
        guard value.isFinite, duration.isFinite, duration > 0 else { return }
        let minimum = Self.minimumEditableInterval(duration: duration)
        trimEnd = min(duration, max(minimum, trimEnd))
        trimStart = max(0, min(value, trimEnd - minimum))
    }
    package mutating func setTrimEnd(_ value: Double, duration: Double) {
        guard value.isFinite, duration.isFinite, duration > 0 else { return }
        let minimum = Self.minimumEditableInterval(duration: duration)
        trimStart = max(0, min(trimStart, duration - minimum))
        trimEnd = min(duration, max(value, trimStart + minimum))
    }
    package func newZoom(at time: Double) -> Zoom? {
        guard time.isFinite, trimStart.isFinite, trimEnd.isFinite, trimEnd > trimStart else { return nil }
        let minimum = Self.minimumEditableInterval(duration: trimEnd - trimStart)
        let start = max(trimStart, min(time, trimEnd - minimum))
        return Zoom(start: start, duration: min(3, trimEnd - start))
    }
    package func zoom(at time: Double) -> (scale: Double, x: Double, y: Double) {
        // Latest zoom wins deterministically if regions overlap.
        guard let z = zooms.filter({ $0.amount(at: time) > 0 }).max(by: { $0.start < $1.start }) else { return (1, 0.5, 0.5) }
        return (1 + (z.scale - 1) * z.amount(at: time), z.x, z.y)
    }
    package func validate(duration: Double) throws {
        guard version == 1, duration.isFinite, trimStart.isFinite, trimEnd.isFinite,
              trimStart >= 0, trimEnd <= duration + 0.05, trimEnd > trimStart,
              padding.isFinite, (0...0.2).contains(padding),
              Set(zooms.map(\.id)).count == zooms.count,
              zooms.allSatisfy({ $0.start.isFinite && $0.start >= 0 && $0.start < duration && $0.duration.isFinite && $0.duration > 0 && $0.start + $0.duration <= duration + 0.05 && $0.scale.isFinite && (1...4).contains($0.scale) && $0.x.isFinite && (0...1).contains($0.x) && $0.y.isFinite && (0...1).contains($0.y) }) else {
            throw NSError(domain: "Framecraft", code: 1, userInfo: [NSLocalizedDescriptionKey: "This project contains invalid edits or a mismatched source video."])
        }
    }
}
