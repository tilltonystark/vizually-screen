import CoreGraphics

/// Crop coordinates are normalized against the upright source, with a top-left origin.
package struct VideoCrop: Codable, Equatable {
    package let x: Double
    package let y: Double
    package let width: Double
    package let height: Double
    package let aspect: CropAspect?

    package init(_ rect: CGRect,aspect:CropAspect?=nil) {
        self.aspect=aspect
        x = rect.minX; y = rect.minY; width = rect.width; height = rect.height
    }

    package var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
    package var isValid: Bool {
        [x,y,width,height].allSatisfy(\.isFinite) && x >= 0 && y >= 0 &&
        width >= 0.01 && height >= 0.01 && x + width <= 1.00000001 && y + height <= 1.00000001
    }

    package func fitsSource(_ size:CGSize) -> Bool {
        guard isValid else { return false }
        guard let step=aspect?.pixelStep else { return true }
        return width*size.width+1e-7 >= step.width && height*size.height+1e-7 >= step.height
    }

    // Core Image uses bottom-left coordinates. Even output dimensions keep 4:2:0 encoders happy.
    package func pixelRect(in size: CGSize) -> CGRect {
        if let step=aspect?.pixelStep,fitsSource(size) {
            let available=floor(min(size.width/step.width,size.height/step.height))
            if available>=1 {
                let count=min(available,max(1,floor(min((width*size.width+1e-7)/step.width,(height*size.height+1e-7)/step.height))))
                let w=count*step.width, h=count*step.height
                let left=min(size.width-w,max(0,((x+width/2)*size.width-w/2).rounded()))
                let bottom=min(size.height-h,max(0,((1-y-height/2)*size.height-h/2).rounded()))
                return CGRect(x:left,y:bottom,width:w,height:h)
            }
        }
        let left = min(size.width - 2, max(0, (x * size.width).rounded()))
        let bottom = min(size.height - 2, max(0, ((1 - y - height) * size.height).rounded()))
        let w = max(2, floor(min(size.width - left, (width * size.width).rounded()) / 2) * 2)
        let h = max(2, floor(min(size.height - bottom, (height * size.height).rounded()) / 2) * 2)
        return CGRect(x: left, y: bottom, width: w, height: h)
    }
}
