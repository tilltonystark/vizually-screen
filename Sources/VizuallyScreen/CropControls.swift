import VizuallyFeedback
import SwiftUI
import VizuallyScreenCore

struct CropControls: View {
    @EnvironmentObject private var theme: StudioTheme
    let aspect: CropAspect
    let editing: Bool
    let ready: Bool
    let canReset: Bool
    let choose: (CropAspect) -> Void
    let reset: () -> Void
    let cancel: () -> Void
    let apply: () -> Void
    static let full = CGRect(x:0,y:0,width:1,height:1)

    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {
                Label("Crop",systemImage:"crop").font(Geist.font(13,.semibold))
                Spacer()
                Button("Reset",action:reset).buttonStyle(StudioButtonStyle(quiet:true)).disabled(!canReset)
            }
            HStack(spacing:2) {
                ForEach(CropAspect.allCases,id:\.self) { option in
                    Button { choose(option) } label: {
                        Text(option.title).font(Geist.font(10,.medium)).lineLimit(1)
                            .frame(maxWidth:.infinity).frame(height:32)
                            .foregroundStyle(aspect == option ? theme.accent:Ink.secondary)
                            .background(aspect == option ? theme.tint:.clear,in:RoundedRectangle(cornerRadius:5))
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityLabel(option == .current ? "Current aspect ratio":option.title)
                        .accessibilityAddTraits(aspect == option ? .isSelected:[])
                        .feedbackTarget("editor.crop.aspect.\(option.rawValue)","Crop aspect: \(option.title)")
                }
            }.padding(3).background(Ink.soft,in:RoundedRectangle(cornerRadius:8))
                .accessibilityElement(children:.contain).accessibilityLabel("Crop aspect ratio")
            Text(editing ? "Drag the frame or its corners." : "Drag a corner on the video.")
                .font(Geist.font(11)).foregroundStyle(Ink.secondary)
            if editing {
                HStack {
                    Spacer()
                    Button("Cancel",action:cancel)
                        .buttonStyle(StudioButtonStyle()).keyboardShortcut(.cancelAction)
                    Button("Apply crop",action:apply)
                        .buttonStyle(StudioButtonStyle(primary:true)).keyboardShortcut(.defaultAction).disabled(!ready)
                }
            }
        }.feedbackTarget("editor.crop.controls","Crop controls")
    }
}

struct CropCanvas: View {
    let size: CGSize
    let sourceFit: CGSize
    let selection: CGRect
    let editing: Bool
    let ready: Bool
    let ratio: Double?
    let begin: () -> Void
    let change: (CGRect) -> Void
    @State private var dragOrigin: CGPoint?

    var body: some View {
        let visible=editing ? selection:CropControls.full
        let rect=CGRect(x:visible.minX*size.width,y:visible.minY*size.height,
                        width:visible.width*size.width,height:visible.height*size.height)
        ZStack {
            if editing {
                Path { path in
                    path.addRect(CGRect(origin:.zero,size:size))
                    path.addRect(rect)
                }.fill(.black.opacity(0.46),style:FillStyle(eoFill:true)).allowsHitTesting(false)
                Rectangle().strokeBorder(.white,lineWidth:1.5)
                    .frame(width:rect.width,height:rect.height).position(x:rect.midX,y:rect.midY)
                    .allowsHitTesting(false)
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance:4,coordinateSpace:.named("cropFrame")).onChanged { drag in
                        let a=unitPoint(drag.startLocation), b=unitPoint(drag.location)
                        change(CropAspect.drag(anchor:a,toward:b,ratio:ratio,left:b.x<a.x,top:b.y<a.y))
                    }).allowsHitTesting(ready).accessibilityHidden(true)
            }
            ForEach(Corner.allCases,id:\.self) { corner in
                let target=min(40,max(8,min(rect.width,rect.height)/2))
                RoundedRectangle(cornerRadius:2).fill(.white).frame(width:10,height:10)
                    .overlay { RoundedRectangle(cornerRadius:2).strokeBorder(.black.opacity(0.45),lineWidth:1) }
                    .frame(width:target,height:target).contentShape(Rectangle())
                    .focusable()
                    .onKeyPress(.leftArrow) { nudge(corner,dx:-0.01,dy:0);return .handled }
                    .onKeyPress(.rightArrow) { nudge(corner,dx:0.01,dy:0);return .handled }
                    .onKeyPress(.upArrow) { nudge(corner,dx:0,dy:-0.01);return .handled }
                    .onKeyPress(.downArrow) { nudge(corner,dx:0,dy:0.01);return .handled }
                    .accessibilityLabel("\(corner.title) crop corner")
                    .accessibilityAdjustableAction { direction in
                        let amount = direction == .increment ? 0.01:-0.01
                        nudge(corner,dx:corner.left ? -amount:amount,dy:corner.top ? -amount:amount)
                    }
                    .position(x:corner.left ? rect.minX:rect.maxX,y:corner.top ? rect.minY:rect.maxY)
                    .gesture(DragGesture(minimumDistance:1,coordinateSpace:.global).onChanged { drag in
                        let origin=dragOrigin ?? point(corner)
                        if dragOrigin == nil { dragOrigin=origin;begin() }
                        resize(corner,toward:CGPoint(x:origin.x+drag.translation.width/max(1,sourceFit.width),
                                                    y:origin.y+drag.translation.height/max(1,sourceFit.height)))
                    }.onEnded { _ in dragOrigin=nil })
            }
        }.frame(width:size.width,height:size.height).coordinateSpace(name:"cropFrame")
            .onChange(of:editing) { _, active in if !active { dragOrigin=nil } }
    }

    private enum Corner: CaseIterable {
        case topLeft,topRight,bottomLeft,bottomRight
        var left: Bool { self == .topLeft || self == .bottomLeft }
        var top: Bool { self == .topLeft || self == .topRight }
        var title: String { (top ? "Top":"Bottom") + (left ? " left":" right") }
    }

    private func unitPoint(_ point:CGPoint) -> CGPoint {
        CGPoint(x:min(1,max(0,point.x/size.width)),y:min(1,max(0,point.y/size.height)))
    }

    private func point(_ corner:Corner) -> CGPoint {
        CGPoint(x:corner.left ? selection.minX:selection.maxX,y:corner.top ? selection.minY:selection.maxY)
    }

    private func nudge(_ corner:Corner,dx:Double,dy:Double) {
        let origin=point(corner)
        begin()
        resize(corner,toward:CGPoint(x:origin.x+dx,y:origin.y+dy))
    }

    private func resize(_ corner:Corner,toward point:CGPoint) {
        let anchor=CGPoint(x:corner.left ? selection.maxX:selection.minX,
                           y:corner.top ? selection.maxY:selection.minY)
        change(CropAspect.drag(anchor:anchor,toward:point,ratio:ratio,left:corner.left,top:corner.top))
    }
}
