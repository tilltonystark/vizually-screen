import CoreGraphics

/// Display-local, top-left coordinates in logical points, aligned to even encoder pixels.
package enum CaptureArea {
    package static func selection(from start: CGPoint, to end: CGPoint, displaySize: CGSize, pixelScale: Double) -> CGRect? {
        guard pixelScale.isFinite, pixelScale > 0,
              [start.x,start.y,end.x,end.y,displaySize.width,displaySize.height].allSatisfy({ $0.isFinite }),
              displaySize.width > 0, displaySize.height > 0 else { return nil }
        let clipped=CGRect(x:min(start.x,end.x),y:min(start.y,end.y),width:abs(end.x-start.x),height:abs(end.y-start.y))
            .intersection(CGRect(origin:.zero,size:displaySize))
        guard !clipped.isNull else { return nil }
        // Stay inside the drag rectangle; no stretched odd-pixel output or hidden padding.
        let x=ceil(clipped.minX*pixelScale/2)*2, y=ceil(clipped.minY*pixelScale/2)*2
        let right=floor(clipped.maxX*pixelScale/2)*2, bottom=floor(clipped.maxY*pixelScale/2)*2
        guard right-x >= 32, bottom-y >= 32 else { return nil }
        return CGRect(x:x/pixelScale,y:y/pixelScale,width:(right-x)/pixelScale,height:(bottom-y)/pixelScale)
    }
    package static func globalBounds(local: CGRect, display: CGRect) -> CGRect {
        local.offsetBy(dx:display.minX,dy:display.minY)
    }
}

extension CaptureArea {
    /// AppKit uses a bottom-left global origin; selection uses display-local top-left.
    package static func appKitBounds(local: CGRect, displayFrame: CGRect) -> CGRect {
        CGRect(x:displayFrame.minX+local.minX,y:displayFrame.maxY-local.maxY,width:local.width,height:local.height)
    }
    /// A one-point gap keeps every indicator window outside the captured rectangle.
    /// Do not rely on NSWindow.sharingType to exclude UI from ScreenCaptureKit.
    package static func indicatorStrips(around rect:CGRect) -> [CGRect] {
        [CGRect(x:rect.minX-3,y:rect.minY-3,width:2,height:rect.height+6),
         CGRect(x:rect.maxX+1,y:rect.minY-3,width:2,height:rect.height+6),
         CGRect(x:rect.minX-1,y:rect.minY-3,width:rect.width+2,height:2),
         CGRect(x:rect.minX-1,y:rect.maxY+1,width:rect.width+2,height:2)]
    }
}
