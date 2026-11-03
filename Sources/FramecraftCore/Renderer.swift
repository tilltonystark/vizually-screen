import AVFoundation
import CoreImage

package enum Renderer {
    package static let palettes: [String: (CIColor, CIColor)] = [
        "Lavender": (CIColor(red: 0.60, green: 0.50, blue: 0.94), CIColor(red: 0.20, green: 0.17, blue: 0.42)),
        "Ocean": (CIColor(red: 0.24, green: 0.72, blue: 0.79), CIColor(red: 0.08, green: 0.22, blue: 0.40)),
        "Peach": (CIColor(red: 0.98, green: 0.71, blue: 0.55), CIColor(red: 0.62, green: 0.28, blue: 0.40)),
        "Midnight": (CIColor(red: 0.20, green: 0.23, blue: 0.30), CIColor(red: 0.06, green: 0.07, blue: 0.10))
    ]
    package static func composition(asset: AVAsset, project: Project) -> AVVideoComposition {
        AVVideoComposition(asset: asset) { request in
            let source = request.sourceImage
            let rect = source.extent
            let z = project.zoom(at: request.compositionTime.seconds)
            let center = CGPoint(x: rect.minX + rect.width * z.x, y: rect.minY + rect.height * (1 - z.y))
            // Clamp pan so a zoom never reveals pixels outside the source frame.
            let tx = min(0, max(rect.width * (1 - z.scale), rect.width / 2 - center.x * z.scale))
            let ty = min(0, max(rect.height * (1 - z.scale), rect.height / 2 - center.y * z.scale))
            let zoomed = source.transformed(by: CGAffineTransform(a: z.scale, b: 0, c: 0, d: z.scale, tx: tx, ty: ty)).cropped(to: rect)
            let inset = min(rect.width, rect.height) * project.padding
            let scale = min((rect.width - 2 * inset) / rect.width, (rect.height - 2 * inset) / rect.height)
            let frame = CGRect(x: (rect.width - rect.width * scale) / 2, y: (rect.height - rect.height * scale) / 2, width: rect.width * scale, height: rect.height * scale)
            let foreground = zoomed.transformed(by: CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: frame.minX, ty: frame.minY))
            let colors = palettes[project.background] ?? palettes["Lavender"]!
            let bg = CIFilter(name: "CILinearGradient", parameters: ["inputPoint0": CIVector(x: 0, y: rect.height), "inputPoint1": CIVector(x: rect.width, y: 0), "inputColor0": colors.0, "inputColor1": colors.1])!.outputImage!.cropped(to: rect)
            let mask = CIFilter(name: "CIRoundedRectangleGenerator", parameters: ["inputExtent": CIVector(cgRect: frame), "inputRadius": min(24, inset / 2), "inputColor": CIColor.white])!.outputImage!.cropped(to: rect)
            let result = foreground.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: bg, kCIInputMaskImageKey: mask]).cropped(to: rect)
            request.finish(with: result, context: nil)
        }
    }
    package static func export(asset: AVAsset, project: Project, to url: URL) async throws {
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { throw CocoaError(.fileWriteUnknown) }
        exporter.videoComposition = composition(asset: asset, project: project)
        exporter.timeRange = CMTimeRange(start: CMTime(seconds: project.trimStart, preferredTimescale: 600), duration: CMTime(seconds: project.trimEnd - project.trimStart, preferredTimescale: 600))
        exporter.shouldOptimizeForNetworkUse = true
        try await exporter.export(to: url, as: .mp4)
    }
}
