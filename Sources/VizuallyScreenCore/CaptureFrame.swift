import AVFoundation
import CoreImage

/// ScreenCaptureKit's surface can be larger than the source. Never infer its
/// bounds from pixel colors: black is valid screen content.
package struct CaptureFrameGeometry {
    /// Top-left pixel coordinates in the delivered surface.
    package let contentRect: CGRect
    package let nativeSize: CGSize

    package init(surfaceSize: CGSize, contentRectPoints: CGRect?, pixelScale: Double, contentScale: Double) {
        let surface=CGRect(origin:.zero,size:surfaceSize)
        let validScale=pixelScale.isFinite && pixelScale>0 ? pixelScale:1
        let candidate=contentRectPoints?.applying(CGAffineTransform(scaleX:validScale,y:validScale)) ?? surface
        let clipped=candidate.intersection(surface)
        if !clipped.isNull,clipped.width>=2,clipped.height>=2,
           [clipped.minX,clipped.minY,clipped.width,clipped.height].allSatisfy(\.isFinite) {
            // Stay inside the content, including for fractional Retina boundaries.
            let x=ceil(clipped.minX),y=ceil(clipped.minY)
            contentRect=CGRect(x:x,y:y,width:max(2,floor(clipped.maxX)-x),height:max(2,floor(clipped.maxY)-y))
        } else { contentRect=surface }
        let scale=contentScale.isFinite && contentScale>0 ? contentScale:1
        let size=VideoQuality.nativeSize(points:contentRect.size,scale:1/scale)
        nativeSize=CGSize(width:size.0,height:size.1)
    }
}

package final class CaptureFrameProcessor {
    private let context=CIContext(options:[.cacheIntermediates:false])
    private let colorSpace=CGColorSpace(name:CGColorSpace.sRGB)!
    private let size: CGSize
    private let pool: CVPixelBufferPool
    package init(size: CGSize, pixelFormat: OSType) throws {
        self.size=size
        var pool:CVPixelBufferPool?
        let attributes:[String:Any]=[kCVPixelBufferWidthKey as String:Int(size.width),kCVPixelBufferHeightKey as String:Int(size.height),kCVPixelBufferPixelFormatTypeKey as String:pixelFormat,kCVPixelBufferIOSurfacePropertiesKey as String:[:]]
        guard CVPixelBufferPoolCreate(nil,nil,attributes as CFDictionary,&pool)==kCVReturnSuccess,let pool else { throw CocoaError(.fileWriteUnknown) }
        self.pool=pool
    }
    package func process(_ buffer:CVPixelBuffer,geometry:CaptureFrameGeometry) throws -> CVPixelBuffer {
        let sourceSize=CGSize(width:CVPixelBufferGetWidth(buffer),height:CVPixelBufferGetHeight(buffer))
        if geometry.contentRect == CGRect(origin:.zero,size:sourceSize),size == sourceSize { return buffer }
        var output:CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil,pool,&output)==kCVReturnSuccess,let output else { throw CocoaError(.fileWriteUnknown) }
        CVBufferSetAttachment(output,kCVImageBufferColorPrimariesKey,kCVImageBufferColorPrimaries_ITU_R_709_2,.shouldPropagate)
        CVBufferSetAttachment(output,kCVImageBufferTransferFunctionKey,kCVImageBufferTransferFunction_sRGB,.shouldPropagate)
        CVBufferSetAttachment(output,kCVImageBufferYCbCrMatrixKey,kCVImageBufferYCbCrMatrix_ITU_R_709_2,.shouldPropagate)
        // Core Image uses a bottom-left origin; capture metadata uses top-left.
        let crop=CGRect(x:geometry.contentRect.minX,y:sourceSize.height-geometry.contentRect.maxY,width:geometry.contentRect.width,height:geometry.contentRect.height)
        var image=CIImage(cvPixelBuffer:buffer).cropped(to:crop).transformed(by:CGAffineTransform(translationX:-crop.minX,y:-crop.minY))
        let scale=min(size.width/crop.width,size.height/crop.height)
        if abs(scale-1)>0.000001 { image=image.clampedToExtent().applyingFilter("CILanczosScaleTransform",parameters:[kCIInputScaleKey:scale,kCIInputAspectRatioKey:1]) }
        image=image.transformed(by:CGAffineTransform(translationX:(size.width-crop.width*scale)/2,y:(size.height-crop.height*scale)/2))
        let bounds=CGRect(origin:.zero,size:size)
        image=image.composited(over:CIImage(color:.black).cropped(to:bounds))
        context.render(image,to:output,bounds:bounds,colorSpace:colorSpace)
        return output
    }
}
