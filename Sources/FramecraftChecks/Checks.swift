import Foundation
import AVFoundation
import FramecraftCore

func XCTAssertTrue(_ value: Bool, file: StaticString = #file, line: UInt = #line) { precondition(value, "Check failed at line \(line)", file: file, line: line) }
func XCTAssertEqual<T: Equatable>(_ lhs: T, _ rhs: T) { precondition(lhs == rhs, "Expected \(lhs) == \(rhs)") }
func XCTAssertEqual(_ lhs: Double, _ rhs: Double, accuracy: Double) { precondition(abs(lhs - rhs) <= accuracy, "Expected \(lhs) ≈ \(rhs)") }
func XCTAssertGreaterThan(_ lhs: Int, _ rhs: Int) { precondition(lhs > rhs) }
func XCTAssertThrowsError(_ action: @autoclosure () throws -> Void) { do { try action(); fatalError("Expected validation to throw") } catch {} }
@main
struct FramecraftChecks {
    static func main() async throws {
        let checks = FramecraftChecks()
        checks.testZoomIsContinuousAndReturnsToOriginal()
        try checks.testProjectRoundtripAndValidation()
        try checks.testShortClipAndTrimIntervals()
        try checks.testAppearanceRoundtripAndContrast()
        try await checks.testDemoClip()
        try await checks.testActualVideoExport()
        print("PASS: zoom curves, short-clip/trim bounds, project and appearance roundtrips, supported-palette contrast, synthetic demo decode, and actual trimmed MP4 export/decode")
    }
    func testZoomIsContinuousAndReturnsToOriginal() {
        let z = Zoom(start: 2, duration: 3)
        XCTAssertEqual(z.amount(at: 1.99), 0)
        XCTAssertEqual(z.amount(at: 2), 0)
        XCTAssertEqual(z.amount(at: 2.3), 0.5, accuracy: 0.0001)
        XCTAssertEqual(z.amount(at: 3), 1)
        XCTAssertEqual(z.amount(at: 5), 0)
        XCTAssertEqual(z.amount(at: 6), 0)
        let short = Zoom(start: 0, duration: 0.1)
        XCTAssertEqual(short.amount(at: 0.05), 1)
    }
    func testProjectRoundtripAndValidation() throws {
        var p = Project(sourcePath: "/tmp/test.mp4", trimEnd: 8)
        p.zooms = [Zoom(start: 1), Zoom(start: 2, scale: 3)]
        let copy = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(copy.zooms, p.zooms)
        XCTAssertEqual(copy.zoom(at: 3).scale, 3)
        XCTAssertEqual(copy.zoom(at: 7).scale, 1)
        try copy.validate(duration: 8)
        p.trimStart = 9
        XCTAssertThrowsError(try p.validate(duration: 8))
    }
    func testShortClipAndTrimIntervals() throws {
        for duration in [0.001, 0.04, 0.1, 1, 8] {
            var p = Project(sourcePath: "/tmp/short.mp4", trimEnd: duration)
            p.setTrimStart(duration, duration: duration)
            XCTAssertTrue(p.trimEnd - p.trimStart >= min(0.1, duration) - 0.0000001)
            p.setTrimEnd(-5, duration: duration)
            try p.validate(duration: duration)
            XCTAssertTrue(p.trimStart >= 0 && p.trimEnd <= duration)
            for time in [-10.0, 0, duration, duration + 10] {
                let zoom = p.newZoom(at: time)!
                XCTAssertTrue(zoom.start >= p.trimStart && zoom.duration > 0)
                XCTAssertTrue(zoom.start + zoom.duration <= p.trimEnd + 0.0000001)
                p.zooms = [zoom]
                try p.validate(duration: duration)
            }
            let previous = p.trimStart
            p.setTrimStart(.nan, duration: duration)
            XCTAssertEqual(p.trimStart, previous)
            XCTAssertTrue(p.newZoom(at: .infinity) == nil)
        }
        var invalid = Project(sourcePath: "/tmp/test.mp4", trimEnd: 1)
        invalid.zooms = [Zoom(start: 0.9, duration: 1)]
        XCTAssertThrowsError(try invalid.validate(duration: 1))
        invalid.zooms = [Zoom(start: 0, duration: 0.5)]
        invalid.zooms.append(invalid.zooms[0])
        XCTAssertThrowsError(try invalid.validate(duration: 1))
    }
    func testAppearanceRoundtripAndContrast() throws {
        var appearance = Appearance()
        appearance.accentHue = 281; appearance.canvasLightness = 0.94; appearance.radius = 14; appearance.spacing = 24
        try appearance.validate()
        let copy = try JSONDecoder().decode(Appearance.self, from: JSONEncoder().encode(appearance))
        XCTAssertEqual(copy, appearance)
        for invalid in [Double.nan, .infinity, 229, 301] {
            var value = appearance; value.accentHue = invalid
            XCTAssertThrowsError(try value.validate())
        }
        for invalid in [Double.nan, 0.91, 0.99] {
            var value = appearance; value.canvasLightness = invalid
            XCTAssertThrowsError(try value.validate())
        }
        var invalid = appearance; invalid.radius = 17
        XCTAssertThrowsError(try invalid.validate())
        invalid = appearance; invalid.spacing = 15
        XCTAssertThrowsError(try invalid.validate())
        let white = (1.0, 1.0, 1.0)
        for hue in stride(from: 230.0, through: 300, by: 1) {
            let accent = StudioColor.rgb(0.48, 0.18, hue)
            XCTAssertTrue(StudioColor.contrast(white, accent) >= 4.5)
            for lightness in [0.92, 0.955, 0.98] {
                let canvas = StudioColor.rgb(lightness, 0.003)
                for ink in [0.25, 0.46, 0.51] { XCTAssertTrue(StudioColor.contrast(StudioColor.rgb(ink, 0.008), canvas) >= 4.5) }
                XCTAssertTrue(StudioColor.contrast(accent, canvas) >= 4.5)
            }
        }
    }
    func testDemoClip() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("demo-check-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: url) }
        try await DemoClip.create(at: url)
        let asset = AVURLAsset(url: url)
        XCTAssertEqual(try await asset.load(.duration).seconds, 8, accuracy: 0.04)
        let generator = AVAssetImageGenerator(asset: asset)
        let first = try await generator.image(at: CMTime(seconds: 0.2, preferredTimescale: 600)).image
        let last = try await generator.image(at: CMTime(seconds: 7, preferredTimescale: 600)).image
        XCTAssertEqual(first.width, 1280); XCTAssertEqual(first.height, 720)
        XCTAssertTrue((first.dataProvider!.data! as Data) != (last.dataProvider!.data! as Data))
    }
    func testActualVideoExport() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let inputURL = dir.appendingPathComponent("source.mp4")
        let outputURL = dir.appendingPathComponent("export.mp4")
        let writer = try AVAssetWriter(outputURL: inputURL, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 320, AVVideoHeightKey: 180])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 180])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<60 {
            var buffer: CVPixelBuffer?
            XCTAssertEqual(CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer), kCVReturnSuccess)
            let pixel = buffer!
            CVPixelBufferLockBaseAddress(pixel, [])
            let ptr = CVPixelBufferGetBaseAddress(pixel)!.assumingMemoryBound(to: UInt8.self)
            let row = CVPixelBufferGetBytesPerRow(pixel)
            for y in 0..<180 { for x in 0..<320 { let i = y * row + x * 4; ptr[i] = 255; ptr[i+1] = UInt8(x % 256); ptr[i+2] = UInt8(y); ptr[i+3] = UInt8(frame * 4) } }
            CVPixelBufferUnlockBaseAddress(pixel, [])
            while !input.isReadyForMoreMediaData {
                if writer.status == .failed { throw writer.error! }
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            guard adaptor.append(pixel, withPresentationTime: CMTime(value: Int64(frame), timescale: 30)) else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        }
        input.markAsFinished()
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed)
        let asset = AVURLAsset(url: inputURL)
        var p = Project(sourcePath: inputURL.path, trimStart: 0.25, trimEnd: 1.75)
        p.zooms = [Zoom(start: 0.3, duration: 1.2, scale: 2, x: 0.8, y: 0.2)]
        try await Renderer.export(asset: asset, project: p, to: outputURL)
        let rendered = AVURLAsset(url: outputURL)
        let duration = try await rendered.load(.duration).seconds
        XCTAssertEqual(duration, 1.5, accuracy: 0.08)
        let generator = AVAssetImageGenerator(asset: rendered)
        let image = try await generator.image(at: CMTime(seconds: 0.5, preferredTimescale: 600)).image
        XCTAssertEqual(image.width, 320)
        XCTAssertEqual(image.height, 180)
        // Verify export produced more than a container header.
        XCTAssertGreaterThan(try Data(contentsOf: outputURL).count, 1000)
    }
}
