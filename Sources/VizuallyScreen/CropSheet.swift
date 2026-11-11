import SwiftUI
import VizuallyScreenCore

struct CropSheet: View {
    @ObservedObject var editor: Editor
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: StudioTheme
    @State private var frame: CGImage?
    @State private var selection = CGRect(x:0,y:0,width:1,height:1)
    @State private var failed = false

    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {
                Text("Crop video").font(Geist.font(20,.semibold))
                InfoHint(title:"Crop video",text:"Drag over the original frame to choose what to keep. The crop applies to the entire clip. Reset restores the full frame.")
                Spacer()
            }
            GeometryReader { geometry in
                if let frame {
                    let ratio = CGFloat(frame.width)/CGFloat(frame.height)
                    let width = min(geometry.size.width,geometry.size.height*ratio)
                    let size = CGSize(width:width,height:width/ratio)
                    canvas(frame,size:size).position(x:geometry.size.width/2,y:geometry.size.height/2)
                } else if failed {
                    Text("Could not load the source frame.").frame(maxWidth:.infinity,maxHeight:.infinity)
                } else { ProgressView().frame(maxWidth:.infinity,maxHeight:.infinity) }
            }.frame(height:360).background(Ink.soft,in:RoundedRectangle(cornerRadius:8))
            if frame != nil {
                Grid(horizontalSpacing:20,verticalSpacing:8) {
                    GridRow { margin("Left",edge:.left); margin("Right",edge:.right) }
                    GridRow { margin("Top",edge:.top); margin("Bottom",edge:.bottom) }
                }
            }
            HStack {
                Button("Reset") { selection=Self.full }.buttonStyle(StudioButtonStyle()).disabled(selection == Self.full)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(StudioButtonStyle()).keyboardShortcut(.cancelAction)
                Button("Apply crop") {
                    editor.applyCrop(selection == Self.full ? nil:VideoCrop(selection))
                    dismiss()
                }.buttonStyle(StudioButtonStyle(primary:true)).keyboardShortcut(.defaultAction).disabled(frame == nil || !VideoCrop(selection).isValid)
            }
        }.padding(24).frame(width:744)
            .task {
                selection=editor.project?.crop?.rect ?? Self.full
                do { frame=try await editor.cropFrame() }
                catch { if !Task.isCancelled { failed=true } }
            }
    }

    private static let full = CGRect(x:0,y:0,width:1,height:1)

    private func canvas(_ image: CGImage,size:CGSize) -> some View {
        let rect=CGRect(x:selection.minX*size.width,y:selection.minY*size.height,
                        width:selection.width*size.width,height:selection.height*size.height)
        return ZStack {
            Image(decorative:image,scale:1).resizable()
            Path { path in
                path.addRect(CGRect(origin:.zero,size:size))
                path.addRect(rect)
            }.fill(.black.opacity(0.46),style:FillStyle(eoFill:true))
            Rectangle().strokeBorder(.white,lineWidth:1.5)
                .frame(width:rect.width,height:rect.height).position(x:rect.midX,y:rect.midY)
        }.frame(width:size.width,height:size.height).clipped().contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance:4).onChanged { drag in
                let a = unitPoint(drag.startLocation,size:size), b = unitPoint(drag.location,size:size)
                let candidate = CGRect(x:min(a.x,b.x),y:min(a.y,b.y),width:abs(a.x-b.x),height:abs(a.y-b.y))
                if VideoCrop(candidate).isValid { selection=candidate }
            }).accessibilityHidden(true)
    }

    private func unitPoint(_ point:CGPoint,size:CGSize) -> CGPoint {
        CGPoint(x:min(1,max(0,point.x/size.width)),y:min(1,max(0,point.y/size.height)))
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
            Text(title).font(Geist.font(11)).frame(width:48,alignment:.leading)
            Slider(value:Binding(get:{ value },set:{ next in
                switch edge {
                case .left: selection=CGRect(x:next,y:selection.minY,width:selection.maxX-next,height:selection.height)
                case .right: selection.size.width=1-next-selection.minX
                case .top: selection=CGRect(x:selection.minX,y:next,width:selection.width,height:selection.maxY-next)
                case .bottom: selection.size.height=1-next-selection.minY
                }
            }),in:0...max(value,limit),step:0.001).accessibilityLabel("\(title) crop margin")
            Text("\(Int((value*100).rounded()))%").font(Geist.font(11)).monospacedDigit()
                .foregroundStyle(Ink.secondary).frame(width:36,alignment:.trailing)
        }
    }
}
