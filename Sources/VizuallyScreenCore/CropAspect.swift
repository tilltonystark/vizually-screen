import CoreGraphics

package enum CropAspect: String, Codable, CaseIterable {
    case freeform, current, wide, square, portrait

    package var title: String {
        switch self {
        case .freeform: return "Freeform"
        case .current: return "Current"
        case .wide: return "16:9"
        case .square: return "1:1"
        case .portrait: return "4:5"
        }
    }

    var pixelStep: CGSize? {
        switch self {
        case .wide: return CGSize(width:32,height:18)
        case .square: return CGSize(width:2,height:2)
        case .portrait: return CGSize(width:8,height:10)
        default: return nil
        }
    }

    package func normalizedRatio(source:CGSize,current:CGRect) -> Double? {
        if self == .current { return current.width/current.height }
        guard let step=pixelStep,source.width>0,source.height>0 else { return nil }
        return step.width*source.height/(step.height*source.width)
    }

    package static func fit(_ rect:CGRect,ratio:Double?) -> CGRect {
        guard let ratio else { return rect }
        let width=min(rect.width,rect.height*ratio)
        let height=width/ratio
        return CGRect(x:rect.midX-width/2,y:rect.midY-height/2,width:width,height:height)
    }

    package static func drag(anchor:CGPoint,toward point:CGPoint,ratio:Double?,left:Bool,top:Bool) -> CGRect {
        let limitX=left ? anchor.x:1-anchor.x
        let limitY=top ? anchor.y:1-anchor.y
        let dx=max(0,(point.x-anchor.x)*(left ? -1:1))
        let dy=max(0,(point.y-anchor.y)*(top ? -1:1))
        var w=min(limitX,dx), h=min(limitY,dy)
        if let ratio {
            // Project the pointer onto the locked diagonal, then stop at the frame edge.
            w=min(limitX,limitY*ratio,(dx*ratio*ratio+dy*ratio)/(ratio*ratio+1))
            h=w/ratio
        }
        return CGRect(x:left ? anchor.x-w:anchor.x,y:top ? anchor.y-h:anchor.y,width:w,height:h)
    }
}
