import AVFoundation
import CoreImage
import CoreGraphics

package final class RenderState: @unchecked Sendable {
    private let lock=NSLock()
    private var value: Project
    private var smoothing:PointerSmoothing
    private var backgroundImage:CIImage?
    private var backgroundPath:String?
    package init(_ project:Project) {
        value=project;smoothing=project.pointerSmoothing ?? .smooth
        value.cursorSamples=project.cursorSamples.map { Motion.smooth($0,sigma:smoothing.sigma) }
        backgroundPath=project.canvasBackground?.kind == .image ? project.canvasBackground?.value:nil
        backgroundImage=backgroundPath.flatMap(CanvasBackground.loadImage)
    }
    package var project:Project { lock.lock();defer{lock.unlock()};return value }
    package var snapshot:(Project,CIImage?) { lock.lock();defer{lock.unlock()};return (value,backgroundImage) }
    package func update(_ project:Project) {
        lock.lock();defer { lock.unlock() }
        let setting=project.pointerSmoothing ?? .smooth
        let samples=setting == smoothing && project.cursorSamples?.count == value.cursorSamples?.count ? value.cursorSamples:project.cursorSamples.map { Motion.smooth($0,sigma:setting.sigma) }
        value=project;value.cursorSamples=samples;smoothing=setting
        let path=project.canvasBackground?.kind == .image ? project.canvasBackground?.value:nil
        if path != backgroundPath { backgroundPath=path;backgroundImage=path.flatMap(CanvasBackground.loadImage) }
    }
}
package enum Renderer {
    package static let palettes: [String: (CIColor, CIColor)] = [
        "Lavender": (CIColor(red: 0.60, green: 0.50, blue: 0.94), CIColor(red: 0.20, green: 0.17, blue: 0.42)),
        "Ocean": (CIColor(red: 0.24, green: 0.72, blue: 0.79), CIColor(red: 0.08, green: 0.22, blue: 0.40)),
        "Peach": (CIColor(red: 0.98, green: 0.71, blue: 0.55), CIColor(red: 0.62, green: 0.28, blue: 0.40)),
        "Midnight": (CIColor(red: 0.20, green: 0.23, blue: 0.30), CIColor(red: 0.06, green: 0.07, blue: 0.10))
    ]
    package static func composition(asset: AVAsset, project: Project, state: RenderState? = nil) -> AVVideoComposition {
        let state=state ?? RenderState(project)
        let composition = AVVideoComposition(asset: asset) { request in
            let (project,backgroundImage)=state.snapshot
            let source = request.sourceImage
            let rect = source.extent
            let z = project.zoom(at: request.compositionTime.seconds)
            let center = CGPoint(x: rect.minX + rect.width * z.x, y: rect.minY + rect.height * (1 - z.y))
            // Clamp pan so a zoom never reveals pixels outside the source frame.
            let tx = min(0, max(rect.width * (1 - z.scale), rect.width / 2 - center.x * z.scale))
            let ty = min(0, max(rect.height * (1 - z.scale), rect.height / 2 - center.y * z.scale))
            let inset = min(rect.width, rect.height) * project.padding
            let scale = min((rect.width - 2 * inset) / rect.width, (rect.height - 2 * inset) / rect.height)
            let frame = CGRect(x: (rect.width - rect.width * scale) / 2, y: (rect.height - rect.height * scale) / 2, width: rect.width * scale, height: rect.height * scale)
            var content = source
            if let samples = project.cursorSamples, let cursor = Motion.cursor(at: request.compositionTime.seconds, samples: samples) {
                let cursorSize = max(18, rect.width / 75)
                let arrow = cursorImage.transformed(by: CGAffineTransform(a:cursorSize/128,b:0,c:0,d:cursorSize/128,tx:cursor.x*rect.width,ty:(1-cursor.y)*rect.height-cursorSize))
                content = arrow.composited(over:content)
            }
            // One spatial resampling stage for zoom + framing; no intermediate raster resize.
            let combined = z.scale * scale
            let resampled = abs(combined-1)<0.000001 ? content : content.applyingFilter("CILanczosScaleTransform",parameters:[kCIInputScaleKey:combined,kCIInputAspectRatioKey:1])
            let foreground = resampled.transformed(by:CGAffineTransform(translationX:tx*scale+frame.minX,y:ty*scale+frame.minY)).cropped(to:frame)
            if project.padding == 0 { request.finish(with:foreground.cropped(to:rect),context:nil);return }
            let bg:CIImage
            if let background=project.canvasBackground { bg=background.render(in:rect,image:backgroundImage) }
            else if BackgroundPreset.all.contains(where: { $0.id == project.background }) { bg=CanvasBackground(kind:.gradient,value:project.background).render(in:rect,image:nil) }
            else {
                let colors=palettes[project.background] ?? palettes["Lavender"]!
                bg=CIFilter(name:"CILinearGradient",parameters:["inputPoint0":CIVector(x:0,y:rect.height),"inputPoint1":CIVector(x:rect.width,y:0),"inputColor0":colors.0,"inputColor1":colors.1])!.outputImage!.cropped(to:rect)
            }
            let mask = CIFilter(name: "CIRoundedRectangleGenerator", parameters: ["inputExtent": CIVector(cgRect: frame), "inputRadius": min(24, inset / 2), "inputColor": CIColor.white])!.outputImage!.cropped(to: rect)
            let result = foreground.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: bg, kCIInputMaskImageKey: mask]).cropped(to: rect)
            request.finish(with: result, context: nil)
        }
        let mutable = composition.mutableCopy() as! AVMutableVideoComposition
        // Camera/cursor motion has a steady clock even when capture is variable frame rate.
        mutable.frameDuration = CMTime(value:1,timescale:60)
        mutable.sourceTrackIDForFrameTiming = kCMPersistentTrackID_Invalid
        return mutable
    }
    package static let cursorImage: CIImage = {
        let space=CGColorSpace(name:CGColorSpace.sRGB)!
        let context=CGContext(data:nil,width:128,height:128,bitsPerComponent:8,bytesPerRow:0,space:space,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setShouldAntialias(true)
        context.translateBy(x:0,y:128);context.scaleBy(x:4,y:-4)
        let path=CGMutablePath();path.move(to:CGPoint(x:1,y:1));path.addLine(to:CGPoint(x:1,y:25));path.addLine(to:CGPoint(x:7,y:19));path.addLine(to:CGPoint(x:12,y:30));path.addLine(to:CGPoint(x:17,y:28));path.addLine(to:CGPoint(x:12,y:17));path.addLine(to:CGPoint(x:22,y:17));path.closeSubpath()
        context.addPath(path);context.setFillColor(CGColor(gray:0.08,alpha:1));context.setStrokeColor(CGColor(gray:1,alpha:1));context.setLineWidth(2);context.drawPath(using:.fillStroke)
        return CIImage(cgImage:context.makeImage()!)
    }()
    package static func export(asset: AVAsset, project: Project, to url: URL) async throws {
        try await MediaExporter.export(asset:asset,project:project,quality:.high,to:url)
    }
}
