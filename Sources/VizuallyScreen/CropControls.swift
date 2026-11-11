import SwiftUI
import VizuallyScreenCore

struct CropControls: View {
    @Binding var selection: CGRect
    let ready: Bool
    let cancel: () -> Void
    let apply: () -> Void
    static let full = CGRect(x:0,y:0,width:1,height:1)

    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {
                Label("Crop video",systemImage:"crop").font(Geist.font(13,.semibold))
                Spacer()
                Button("Reset") { selection=Self.full }
                    .buttonStyle(StudioButtonStyle(quiet:true)).disabled(selection == Self.full)
            }
            Text("Drag on the video or resize the corners.")
                .font(Geist.font(12)).foregroundStyle(Ink.secondary)
            VStack(spacing:12) {
                margin("Left",edge:.left)
                margin("Right",edge:.right)
                margin("Top",edge:.top)
                margin("Bottom",edge:.bottom)
            }.disabled(!ready)
            HStack {
                Spacer()
                Button("Cancel",action:cancel)
                    .buttonStyle(StudioButtonStyle()).keyboardShortcut(.cancelAction)
                Button("Apply crop",action:apply)
                    .buttonStyle(StudioButtonStyle(primary:true)).keyboardShortcut(.defaultAction)
                    .disabled(!ready || !VideoCrop(selection).isValid)
            }
        }
    }

    private enum Edge { case left,right,top,bottom }
    private func margin(_ title:String,edge:Edge) -> some View {
        let value:Double
        let limit:Double
        switch edge {
        case .left: value=selection.minX;limit=selection.maxX-0.011
        case .right: value=1-selection.maxX;limit=1-selection.minX-0.011
        case .top: value=selection.minY;limit=selection.maxY-0.011
        case .bottom: value=1-selection.maxY;limit=1-selection.minY-0.011
        }
        return HStack(spacing:8) {
            Text(title).font(Geist.font(11)).frame(width:42,alignment:.leading)
            Slider(value:Binding(get:{ value },set:{ next in
                switch edge {
                case .left: selection=CGRect(x:next,y:selection.minY,width:selection.maxX-next,height:selection.height)
                case .right: selection.size.width=1-next-selection.minX
                case .top: selection=CGRect(x:selection.minX,y:next,width:selection.width,height:selection.maxY-next)
                case .bottom: selection.size.height=1-next-selection.minY
                }
            }),in:0...max(value,limit),step:0.001).accessibilityLabel("\(title) crop margin")
            Text("\(Int((value*100).rounded()))%").font(Geist.font(11)).monospacedDigit()
                .foregroundStyle(Ink.secondary).frame(width:34,alignment:.trailing)
        }
    }
}

struct CropCanvas: View {
    let image: CGImage
    let size: CGSize
    @Binding var selection: CGRect

    var body: some View {
        let rect=CGRect(x:selection.minX*size.width,y:selection.minY*size.height,
                        width:selection.width*size.width,height:selection.height*size.height)
        ZStack {
            ZStack {
                Image(decorative:image,scale:1).resizable()
                Path { path in
                    path.addRect(CGRect(origin:.zero,size:size))
                    path.addRect(rect)
                }.fill(.black.opacity(0.46),style:FillStyle(eoFill:true))
                Rectangle().strokeBorder(.white,lineWidth:1.5)
                    .frame(width:rect.width,height:rect.height).position(x:rect.midX,y:rect.midY)
            }.frame(width:size.width,height:size.height).clipped().contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance:4,coordinateSpace:.named("cropFrame")).onChanged { drag in
                    let a=unitPoint(drag.startLocation), b=unitPoint(drag.location)
                    let candidate=rectangle(a,b)
                    if VideoCrop(candidate).isValid { selection=candidate }
                })
            ForEach(Corner.allCases,id:\.self) { corner in
                let target = min(40,max(12,min(rect.width,rect.height)/2))
                RoundedRectangle(cornerRadius:2).fill(.white).frame(width:10,height:10)
                    .overlay { RoundedRectangle(cornerRadius:2).strokeBorder(.black.opacity(0.35),lineWidth:1) }
                    .frame(width:target,height:target).contentShape(Rectangle())
                    .position(x:corner.left ? rect.minX:rect.maxX,y:corner.top ? rect.minY:rect.maxY)
                    .gesture(DragGesture(minimumDistance:1,coordinateSpace:.named("cropFrame")).onChanged { drag in
                        resize(corner,to:unitPoint(drag.location))
                    })
            }
        }.frame(width:size.width,height:size.height).coordinateSpace(name:"cropFrame").accessibilityHidden(true)
    }

    private enum Corner: CaseIterable {
        case topLeft,topRight,bottomLeft,bottomRight
        var left: Bool { self == .topLeft || self == .bottomLeft }
        var top: Bool { self == .topLeft || self == .topRight }
    }

    private func unitPoint(_ point:CGPoint) -> CGPoint {
        CGPoint(x:min(1,max(0,point.x/size.width)),y:min(1,max(0,point.y/size.height)))
    }

    private func rectangle(_ a:CGPoint,_ b:CGPoint) -> CGRect {
        CGRect(x:min(a.x,b.x),y:min(a.y,b.y),width:abs(a.x-b.x),height:abs(a.y-b.y))
    }

    private func resize(_ corner:Corner,to point:CGPoint) {
        let opposite=CGPoint(x:corner.left ? selection.maxX:selection.minX,
                             y:corner.top ? selection.maxY:selection.minY)
        let minSize=0.011
        let x=corner.left ? min(point.x,max(0,opposite.x-minSize)):max(point.x,min(1,opposite.x+minSize))
        let y=corner.top ? min(point.y,max(0,opposite.y-minSize)):max(point.y,min(1,opposite.y+minSize))
        let candidate=rectangle(opposite,CGPoint(x:x,y:y))
        if VideoCrop(candidate).isValid { selection=candidate }
    }
}
