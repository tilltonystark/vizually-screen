import SwiftUI
import FramecraftCore

struct StudioTimeline: View {
    @ObservedObject var editor: Editor
    @EnvironmentObject var theme: StudioTheme
    private let labelWidth: CGFloat = 76
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Timeline").font(Geist.font(12, .semibold))
                Spacer()
                Text("Source time").font(Geist.font(11)).foregroundStyle(Ink.secondary)
                Button(action: editor.addZoom) { Label("Add zoom", systemImage: "plus.magnifyingglass") }.buttonStyle(StudioButtonStyle(quiet: true)).disabled(editor.project == nil)
            }.padding(.horizontal, 20).frame(height: 45)
            GeometryReader { geometry in
                let width = max(1, geometry.size.width - labelWidth - 32)
                let duration = max(0.001, editor.duration)
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 26)
                        Label("Video", systemImage: "film").frame(height: 52)
                        Label("Zoom", systemImage: "viewfinder").frame(height: 42)
                    }.font(Geist.font(11)).foregroundStyle(Ink.secondary).frame(width: labelWidth, alignment: .leading)
                    ZStack(alignment: .topLeading) {
                        VStack(spacing: 7) {
                            ruler(width: width, duration: duration).frame(height: 19)
                            filmstrip(width: width, duration: duration).frame(height: 52)
                            zoomTrack(width: width, duration: duration).frame(height: 35)
                        }
                        if editor.project != nil {
                            Rectangle().fill(theme.accent).frame(width: 1.5, height: 121)
                                .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 2).fill(theme.accent).frame(width: 9, height: 10).offset(y: -2) }
                                .offset(x: min(width, max(0, editor.playhead / duration * width)))
                                .allowsHitTesting(false)
                        }
                    }.frame(width: width)
                }.padding(.leading, 16)
            }.frame(height: 134)
        }.background(Ink.soft)
    }
    private func ruler(width: CGFloat, duration: Double) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<9) { i in
                VStack(spacing: 4) {
                    Text(editor.project == nil ? "—" : String(format: "%.1fs", duration * Double(i)/8)).font(Geist.font(9)).monospacedDigit().foregroundStyle(Ink.secondary)
                    Rectangle().fill(Ink.line).frame(width: 1, height: i % 2 == 0 ? 6 : 3)
                }.position(x: CGFloat(i)/8*width, y: 9)
            }
        }.contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 0).onChanged { v in editor.seek(min(1,max(0,v.location.x/width))*duration) }).accessibilityLabel("Timeline ruler")
    }
    private func filmstrip(width: CGFloat, duration: Double) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 6).fill(Color.oklch(0.92,0.008))
            if !editor.thumbnails.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(editor.thumbnails.enumerated()), id: \.offset) { _, image in
                        Image(nsImage: image).resizable().scaledToFill().frame(width: width/CGFloat(editor.thumbnails.count), height: 52).clipped()
                    }
                }.clipShape(RoundedRectangle(cornerRadius: 6)).accessibilityHidden(true).allowsHitTesting(false)
            }
            if let p = editor.project {
                let left = p.trimStart/duration*width
                let right = p.trimEnd/duration*width
                Rectangle().fill(Color.white.opacity(0.7)).frame(width: max(0,left))
                Rectangle().fill(Color.white.opacity(0.7)).frame(width: max(0,width-right)).offset(x: right)
                RoundedRectangle(cornerRadius: 5).strokeBorder(theme.accent, lineWidth: 2).frame(width: max(1,right-left)).offset(x:left)
            } else { Text("Your video will appear here").font(Geist.font(11)).foregroundStyle(Ink.secondary).padding(.leading, 12) }
        }.clipped().accessibilityElement(children: .ignore).contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 0).onChanged { v in editor.seek(min(1,max(0,v.location.x/width))*duration) })
        .accessibilityLabel("Video timeline").accessibilityValue(clockText(editor.playhead))
        .accessibilityAdjustableAction { direction in editor.seek(editor.playhead + (direction == .increment ? 0.1 : -0.1)) }
    }
    private func zoomTrack(width: CGFloat, duration: Double) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 6).fill(Color.oklch(0.945, 0.003))
            if let p = editor.project {
                ForEach(Array(p.zooms.enumerated()), id: \.element.id) { index, zoom in
                    let selected = zoom.id == editor.selectedZoomID
                    Button { editor.selectZoom(zoom.id) } label: {
                        HStack(spacing: 5) { Image(systemName: "plus.magnifyingglass"); Text("\(zoom.scale, specifier: "%.1f")×").monospacedDigit() }
                            .font(Geist.font(10,.medium)).foregroundStyle(selected ? .white : theme.accent)
                            .frame(width: max(3,min(zoom.duration,duration-zoom.start)/duration*width), height: 31)
                            .background(selected ? theme.accent : theme.tint, in: RoundedRectangle(cornerRadius: 5)).clipped()
                    }.buttonStyle(.plain).offset(x: zoom.start/duration*width)
                        .help("Zoom \(index+1) · \(clockText(zoom.start))").accessibilityLabel("Zoom region \(index+1)")
                }
                if p.zooms.isEmpty { Text("Add a zoom to focus on a detail").font(Geist.font(11)).foregroundStyle(Ink.secondary).padding(.leading, 12).allowsHitTesting(false) }
            }
        }.clipped()
    }
}
