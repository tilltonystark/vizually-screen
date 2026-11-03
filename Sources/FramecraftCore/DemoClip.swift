import AVFoundation
import CoreGraphics
import CoreText

/// Deterministic, local sample content: a real movie that exercises preview and export.
package enum DemoClip {
    package static func create(at url: URL) async throws {
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".demo-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: temporary) }
        let writer = try AVAssetWriter(outputURL: temporary, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 1280, AVVideoHeightKey: 720,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 3_000_000]
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 1280, kCVPixelBufferHeightKey as String: 720,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ])
        guard writer.canAdd(input) else { throw CocoaError(.fileWriteUnknown) }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        writer.startSession(atSourceTime: .zero)
        do {
            for frame in 0..<240 {
                try Task.checkCancellation()
                while !input.isReadyForMoreMediaData {
                    guard writer.status == .writing else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
                    try await Task.sleep(nanoseconds: 2_000_000)
                }
                guard let pool = adaptor.pixelBufferPool else { throw CocoaError(.fileWriteUnknown) }
                var storage: CVPixelBuffer?
                guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &storage) == kCVReturnSuccess, let buffer = storage else { throw CocoaError(.fileWriteUnknown) }
                CVPixelBufferLockBaseAddress(buffer, [])
                guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: 1280, height: 720, bitsPerComponent: 8,
                                              bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) else {
                    CVPixelBufferUnlockBaseAddress(buffer, [])
                    throw CocoaError(.fileWriteUnknown)
                }
                draw(context, time: Double(frame) / 30)
                CVPixelBufferUnlockBaseAddress(buffer, [])
                guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 30)) else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
            }
            input.markAsFinished()
            await writer.finishWriting()
            guard writer.status == .completed else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
            if FileManager.default.fileExists(atPath: url.path) { _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary) }
            else { try FileManager.default.moveItem(at: temporary, to: url) }
        } catch { writer.cancelWriting(); throw error }
    }

    private static func draw(_ c: CGContext, time: Double) {
        c.translateBy(x: 0, y: 720); c.scaleBy(x: 1, y: -1)
        c.setShouldAntialias(true)
        func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }
        let ink = color(0.13, 0.16, 0.23), muted = color(0.48, 0.52, 0.60), accent = color(0.36, 0.32, 0.86)
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ fill: CGColor, _ radius: CGFloat = 0) {
            c.setFillColor(fill)
            c.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: radius, cornerHeight: radius, transform: nil)); c.fillPath()
        }
        func text(_ value: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat = 14, _ fill: CGColor? = nil, bold: Bool = false) {
            let font = CTFontCreateWithName((bold ? "HelveticaNeue-Medium" : "HelveticaNeue") as CFString, size, nil)
            let string = NSAttributedString(string: value, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): fill ?? ink])
            c.saveGState(); c.translateBy(x: x, y: y + size); c.scaleBy(x: 1, y: -1); c.textMatrix = .identity
            CTLineDraw(CTLineCreateWithAttributedString(string), c); c.restoreGState()
        }
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [color(0.88, 0.90, 0.98), color(0.97, 0.91, 0.87)] as CFArray, locations: [0, 1])!
        c.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 1280, y: 720), options: [])
        c.saveGState(); c.setShadow(offset: CGSize(width: 0, height: 12), blur: 40, color: color(0.16, 0.17, 0.30, 0.13)); rect(100, 70, 1080, 580, color(1, 1, 1), 18); c.restoreGState()
        rect(100, 70, 1080, 48, color(0.98, 0.98, 0.99), 18)
        rect(100, 100, 1080, 18, color(0.98, 0.98, 0.99))
        for (i, tint) in [color(1, 0.39, 0.36), color(1, 0.75, 0.28), color(0.29, 0.77, 0.40)].enumerated() {
            c.setFillColor(tint); c.fillEllipse(in: CGRect(x: 121 + i * 20, y: 89, width: 11, height: 11))
        }
        text("orbit.app / overview", 525, 86, 12, muted)
        rect(100, 118, 204, 532, color(0.97, 0.975, 0.99), 0)
        text("orbit", 128, 144, 26, ink, bold: true)
        text("YOUR WORKSPACE", 128, 204, 10, muted, bold: true)
        rect(116, 232, 172, 38, color(0.91, 0.90, 0.99), 8)
        text("Overview", 145, 242, 14, accent, bold: true)
        for (i, title) in ["Projects", "Analytics", "Team", "Settings"].enumerated() { text(title, 145, CGFloat(292 + i * 44), 14, muted) }
        rect(120, 575, 164, 50, color(1, 1, 1), 9)
        c.setFillColor(accent); c.fillEllipse(in: CGRect(x: 133, y: 586, width: 27, height: 27))
        text("Alex Morgan", 172, 584, 11, ink, bold: true); text("Pro workspace", 172, 601, 10, muted)
        text("Workspace overview", 337, 148, 27, ink, bold: true)
        text("A little clarity for your next big idea.", 338, 187, 13, muted)
        rect(1021, 151, 124, 36, accent, 8); text("+ New project", 1035, 160, 12, color(1, 1, 1), bold: true)
        let titles = ["Total revenue", "Active projects", "Team velocity"]
        let values = ["$24,680", "18", "94%"]
        for i in 0..<3 {
            let x = CGFloat(338 + i * 277)
            rect(x, 231, 256, 112, color(0.975, 0.978, 0.99), 10)
            text(titles[i], x + 18, 247, 12, muted)
            text(values[i], x + 18, 274, 27, ink, bold: true)
            text(["↑ 18.6% this month", "4 ready to ship", "↑ 12 points"][i], x + 18, 316, 10, color(0.16, 0.55, 0.40))
        }
        rect(338, 368, 532, 244, color(0.978, 0.98, 0.99), 10)
        text("Growth, at a glance", 359, 388, 15, ink, bold: true); text("LAST 7 MONTHS", 737, 392, 9, muted)
        for y in stride(from: 440, through: 570, by: 43) { rect(362, CGFloat(y), 480, 1, color(0.90, 0.92, 0.95)) }
        let points: [CGFloat] = [0.11, 0.23, 0.17, 0.43, 0.37, 0.68, 0.86]
        let reveal = min(1, time / 2)
        c.saveGState(); c.clip(to: CGRect(x: 360, y: 425, width: 487 * reveal, height: 157))
        let line = CGMutablePath()
        for (i, amount) in points.enumerated() {
            let p = CGPoint(x: 368 + CGFloat(i) * 77, y: 568 - amount * 130)
            if i == 0 { line.move(to: p) } else { line.addLine(to: p) }
        }
        c.addPath(line); c.setStrokeColor(accent); c.setLineWidth(3); c.setLineJoin(.round); c.strokePath()
        for (i, amount) in points.enumerated() { c.setFillColor(accent); c.fillEllipse(in: CGRect(x: 364 + CGFloat(i) * 77, y: 564 - amount * 130, width: 8, height: 8)) }
        c.restoreGState()
        for (i, month) in ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul"].enumerated() { text(month, 358 + CGFloat(i) * 77, 587, 10, muted) }
        rect(892, 368, 253, 244, color(0.975, 0.978, 0.99), 10)
        text("Recent projects", 912, 388, 15, ink, bold: true)
        for (i, title) in ["Website refresh", "Launch campaign", "Mobile experience"].enumerated() {
            let y = CGFloat(435 + i * 54)
            rect(912, y, 30, 30, [color(0.88, 0.85, 0.99), color(0.82, 0.93, 0.90), color(1, 0.90, 0.78)][i], 7)
            text(title, 953, y, 11, ink, bold: true); text(["Design · In progress", "Marketing · Review", "Product · Planning"][i], 953, y + 17, 9, muted)
        }
        // A smooth pointer journey gives the real clip visible motion throughout.
        let phase = min(1, max(0, (time - 0.8) / 5.8))
        let smooth = phase * phase * (3 - 2 * phase)
        let px = 540 + 480 * smooth, py = 485 - 310 * sin(smooth * .pi / 2)
        c.saveGState(); c.translateBy(x: px, y: py)
        let pointer = CGMutablePath(); pointer.move(to: .zero); pointer.addLine(to: CGPoint(x: 3, y: 25)); pointer.addLine(to: CGPoint(x: 10, y: 17)); pointer.addLine(to: CGPoint(x: 17, y: 29)); pointer.addLine(to: CGPoint(x: 22, y: 26)); pointer.addLine(to: CGPoint(x: 15, y: 14)); pointer.addLine(to: CGPoint(x: 25, y: 13)); pointer.closeSubpath()
        c.addPath(pointer); c.setFillColor(ink); c.setStrokeColor(color(1, 1, 1)); c.setLineWidth(2); c.drawPath(using: .fillStroke); c.restoreGState()
        if time > 6.5 {
            let alpha = min(1, (time - 6.5) * 3)
            rect(873, 205, 272, 54, color(0.13, 0.16, 0.23, alpha), 10)
            text("Your next great project starts here.", 891, 223, 12, color(1, 1, 1, alpha))
        }
    }
}
