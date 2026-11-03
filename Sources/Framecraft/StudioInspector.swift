import SwiftUI
import FramecraftCore

struct StudioInspector: View {
    @ObservedObject var editor: Editor
    @Binding var tab: String
    @EnvironmentObject var theme: StudioTheme
    private let palettes: [(String, Color, Color)] = [
        ("Lavender", .oklch(0.72, 0.13, 290), .oklch(0.37, 0.10, 290)),
        ("Ocean", .oklch(0.74, 0.10, 200), .oklch(0.34, 0.08, 250)),
        ("Peach", .oklch(0.83, 0.10, 55), .oklch(0.49, 0.13, 10)),
        ("Midnight", .oklch(0.36, 0.03, 260), .oklch(0.18, 0.02, 260))
    ]
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                tabButton("Canvas", icon: "rectangle.on.rectangle")
                tabButton("Zoom", icon: "plus.magnifyingglass")
            }.padding(12)
            Rule()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if tab == "Canvas" { canvasControls } else { zoomControls }
                }.padding(20)
            }
            if editor.project != nil {
                Rule()
                Button(action: editor.saveProject) { Label("Save project", systemImage: "square.and.arrow.down") }.buttonStyle(StudioButtonStyle(quiet: true)).padding(8)
            }
        }.background(.white)
    }
    private func tabButton(_ name: String, icon: String) -> some View {
        Button { tab = name } label: {
            HStack(spacing: 6) { Image(systemName: icon); Text(name) }.font(Geist.font(12, .medium))
                .frame(maxWidth: .infinity).frame(height: 40)
                .foregroundStyle(tab == name ? theme.accent : Ink.secondary)
                .background(tab == name ? theme.tint : .clear, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain).accessibilityAddTraits(tab == name ? .isSelected : [])
    }
    private func heading(_ text: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text).font(Geist.font(13, .semibold))
            if let detail { Text(detail).font(Geist.font(12)).foregroundStyle(Ink.secondary).fixedSize(horizontal: false, vertical: true) }
        }
    }
    @ViewBuilder private var canvasControls: some View {
        heading("Background", detail: "A little space around your story.")
        HStack(spacing: 10) {
            ForEach(palettes, id: \.0) { name, light, dark in
                Button { editor.update { $0.background = name } } label: {
                    RoundedRectangle(cornerRadius: 8).fill(LinearGradient(colors: [light, dark], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                        .overlay { if editor.project?.background == name { Image(systemName: "checkmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).shadow(color: .black.opacity(0.4), radius: 2) } }
                        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(.black.opacity(0.1), lineWidth: 1) }
                }.buttonStyle(.plain).help(name).accessibilityLabel("\(name) background").accessibilityAddTraits(editor.project?.background == name ? .isSelected : [])
            }
        }.disabled(editor.project == nil)
        if let p = editor.project {
            Text(p.background).font(Geist.font(11)).foregroundStyle(Ink.secondary).padding(.top, -14)
            parameter("Padding", value: Binding(get: { p.padding * 100 }, set: { v in editor.update { $0.padding = v / 100 } }), range: 0...20, suffix: "%", decimals: 0)
        } else {
            HStack { Text("Padding"); Spacer(); Text("7%").foregroundStyle(Ink.secondary) }.font(Geist.font(12))
            Slider(value: .constant(7), in: 0...20).disabled(true)
        }
        Rule()
        heading("Trim", detail: "Keep the part that matters.")
        if let p = editor.project {
            VStack(spacing: 12) {
                trimRow("Start", value: p.trimStart, action: editor.setTrimStart)
                trimRow("End", value: p.trimEnd, action: editor.setTrimEnd)
                HStack { Text("Final duration"); Spacer(); Text(clockText(p.trimEnd - p.trimStart)).monospacedDigit() }.font(Geist.font(11)).foregroundStyle(Ink.secondary)
            }
        } else { Text("Import or record a video to start editing.").font(Geist.font(12)).foregroundStyle(Ink.secondary) }
        Rule()
        heading("Output")
        VStack(spacing: 12) {
            detailRow("Format", "MP4")
            detailRow("Resolution", editor.project == nil ? "Matches source" : "\(Int(editor.videoSize.width)) × \(Int(editor.videoSize.height))")
            detailRow("Audio", "From source")
        }
    }
    @ViewBuilder private var zoomControls: some View {
        heading("Focus the details", detail: "Add a zoom at the playhead, then choose where it looks.")
        Button(action: editor.addZoom) { Label("Add zoom", systemImage: "plus") }.buttonStyle(StudioButtonStyle()).disabled(editor.project == nil)
        if let p = editor.project, let z = p.zooms.first(where: { $0.id == editor.selectedZoomID }) {
            Rule()
            HStack { Text("Selected zoom").font(Geist.font(13, .semibold)); Spacer(); IconButton(symbol: "trash", title: "Delete selected zoom", action: editor.deleteSelectedZoom) }
            FocusPad(x: zoomBinding(z, \.x), y: zoomBinding(z, \.y), image: editor.thumbnails.first).environmentObject(theme)
            Text("Drag the focus point").font(Geist.font(11)).foregroundStyle(Ink.secondary).frame(maxWidth: .infinity).padding(.top, -16)
            parameter("Magnification", value: zoomBinding(z, \.scale), range: 1...4, suffix: "×", decimals: 1)
            parameter("Start", value: zoomBinding(z, \.start), range: 0...max(0, editor.duration - z.duration), suffix: "s", decimals: 2)
            parameter("Duration", value: zoomBinding(z, \.duration), range: min(0.1, max(0.001, editor.duration-z.start))...max(0.001, editor.duration-z.start), suffix: "s", decimals: 2)
            HStack { Image(systemName: "waveform.path"); Text("Smooth entrance and exit") }.font(Geist.font(11)).foregroundStyle(Ink.secondary)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "cursorarrow.rays").font(.system(size: 25, weight: .light))
                Text(editor.project?.zooms.isEmpty == false ? "Select a region on the timeline to adjust its focus." : "Your zoom regions will appear on the timeline.").multilineTextAlignment(.center).font(Geist.font(12))
            }.foregroundStyle(Ink.secondary).frame(maxWidth: .infinity).padding(.vertical, 36)
        }
    }
    private func zoomBinding(_ z: Zoom, _ key: WritableKeyPath<Zoom, Double>) -> Binding<Double> {
        Binding(get: { z[keyPath: key] }, set: { value in
            editor.update { p in if let i = p.zooms.firstIndex(where: { $0.id == z.id }) { p.zooms[i][keyPath: key] = value } }
        })
    }
    private func trimRow(_ title: String, value: Double, action: @escaping (Double) -> Void) -> some View {
        VStack(spacing: 2) {
            HStack { Text(title); Spacer(); Text(clockText(value)).monospacedDigit().padding(.horizontal, 8).padding(.vertical, 6).background(Ink.soft, in: RoundedRectangle(cornerRadius: 6)) }.font(Geist.font(12))
            Slider(value: Binding(get: { value }, set: action), in: 0...max(0.001, editor.duration)).tint(theme.accent).accessibilityLabel("Trim \(title.lowercased())").frame(minHeight: 30)
        }
    }
    private func parameter(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String, decimals: Int) -> some View {
        VStack(spacing: 5) {
            HStack { Text(label); Spacer(); Text(String(format: "%.*f%@", decimals, value.wrappedValue, suffix)).monospacedDigit().foregroundStyle(Ink.secondary).padding(.horizontal, 8).padding(.vertical, 6).background(Ink.soft, in: RoundedRectangle(cornerRadius: 6)) }.font(Geist.font(12))
            Slider(value: value, in: range).tint(theme.accent).accessibilityLabel(label).frame(minHeight: 30)
        }
    }
    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack { Text(title).foregroundStyle(Ink.secondary); Spacer(); Text(value) }.font(Geist.font(11))
    }
}
struct FocusPad: View {
    @Binding var x: Double
    @Binding var y: Double
    var image: NSImage? = nil
    @EnvironmentObject var theme: StudioTheme
    var body: some View {
        GeometryReader { g in
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(theme.canvas)
                if let image { Image(nsImage: image).resizable().scaledToFit().frame(width: g.size.width, height: g.size.height).opacity(0.85).allowsHitTesting(false) }
                Path { p in
                    for i in 1...3 {
                        let t = CGFloat(i)/4
                        p.move(to: CGPoint(x: g.size.width*t, y: 0)); p.addLine(to: CGPoint(x: g.size.width*t, y: g.size.height))
                        p.move(to: CGPoint(x: 0, y: g.size.height*t)); p.addLine(to: CGPoint(x: g.size.width, y: g.size.height*t))
                    }
                }.stroke(Ink.line, style: StrokeStyle(lineWidth: 0.5, dash: [3,3]))
                Circle().fill(theme.accent.opacity(0.18)).frame(width: 38, height: 38).overlay { Circle().fill(theme.accent).frame(width: 12, height: 12).overlay { Circle().strokeBorder(.white, lineWidth: 2) } }.position(x: x*g.size.width, y: y*g.size.height)
            }.clipShape(RoundedRectangle(cornerRadius: 8)).contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in x = min(1,max(0,v.location.x/g.size.width)); y = min(1,max(0,v.location.y/g.size.height)) })
        }.frame(height: 134).accessibilityElement(children: .ignore).accessibilityLabel("Zoom focal point").accessibilityValue("Horizontal \(Int(x*100)) percent, vertical \(Int(y*100)) percent")
        .accessibilityAdjustableAction { direction in if direction == .increment { x = min(1, x+0.05) } else { x = max(0,x-0.05) } }
    }
}
