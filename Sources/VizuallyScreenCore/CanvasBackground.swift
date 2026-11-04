import CoreImage
import Foundation

package struct CanvasBackground: Codable, Equatable {
    package enum Kind:String,Codable { case gradient,solid,image }
    package var kind:Kind
    package var value:String
    package init(kind:Kind,value:String) { self.kind=kind;self.value=value }
    package var isValid:Bool {
        switch kind {
        case .gradient:return BackgroundPreset.all.contains { $0.id == value }
        case .solid:return Self.color(value) != nil
        case .image:return value.hasPrefix("/") && !value.contains("\0")
        }
    }
    package static func color(_ hex:String) -> CIColor? {
        let value=hex.hasPrefix("#") ? String(hex.dropFirst()):hex
        guard value.count == 6,let number=UInt32(value,radix:16) else { return nil }
        return CIColor(red:Double((number>>16)&255)/255,green:Double((number>>8)&255)/255,blue:Double(number&255)/255)
    }
    package static func loadImage(_ path:String) -> CIImage? { CIImage(contentsOf:URL(fileURLWithPath:path),options:[.applyOrientationProperty:true]) }
    package func render(in rect:CGRect,image:CIImage?) -> CIImage {
        switch kind {
        case .solid:return CIImage(color:Self.color(value) ?? .white).cropped(to:rect)
        case .image:
            if let image,image.extent.width>0,image.extent.height>0 {
                let scale=max(rect.width/image.extent.width,rect.height/image.extent.height)
                return image.transformed(by:CGAffineTransform(translationX:-image.extent.minX,y:-image.extent.minY))
                    .clampedToExtent()
                    .applyingFilter("CILanczosScaleTransform",parameters:[kCIInputScaleKey:scale,kCIInputAspectRatioKey:1])
                    .transformed(by:CGAffineTransform(translationX:rect.midX-image.extent.width*scale/2,y:rect.midY-image.extent.height*scale/2)).cropped(to:rect)
            }
            return CIImage(color:.white).cropped(to:rect)
        case .gradient:
            let preset=BackgroundPreset.all.first { $0.id == value } ?? BackgroundPreset.all[0]
            return CIFilter(name:"CILinearGradient",parameters:["inputPoint0":CIVector(x:rect.minX,y:rect.maxY),"inputPoint1":CIVector(x:rect.maxX,y:rect.minY),"inputColor0":Self.color(preset.top)!,"inputColor1":Self.color(preset.bottom)!])!.outputImage!.cropped(to:rect)
        }
    }
}
package struct BackgroundPreset:Identifiable {
    package let id:String
    package let name:String
    package let top:String
    package let bottom:String
    package static let all:[BackgroundPreset]=[
        .init(id:"Dune",name:"Dune",top:"F3E7D8",bottom:"D2BBA4"),
        .init(id:"Pearl",name:"Pearl",top:"F6F5F2",bottom:"DCDDE1"),
        .init(id:"Mist",name:"Mist",top:"E3EBEC",bottom:"A8B9C2"),
        .init(id:"Sage",name:"Sage",top:"DCE6DB",bottom:"9BAF9F"),
        .init(id:"Glacier",name:"Glacier",top:"DAE8F7",bottom:"8EAFCF"),
        .init(id:"Rose",name:"Rose",top:"F0DFE2",bottom:"C3A1AB"),
        .init(id:"Twilight",name:"Twilight",top:"C5BEDC",bottom:"6F709B"),
        .init(id:"Graphite",name:"Graphite",top:"626878",bottom:"242934")
    ]
    package static let solids=["F7F5F0","FFFFFF","E3E7EB","D4DDD3","D3DFEF","E8D7DA","292D38","12151D"]
}
