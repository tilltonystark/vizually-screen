import VizuallyFeedback
import SwiftUI
import VizuallyScreenCore

struct StudioInspector: View {
    @ObservedObject var editor: Editor
    @Binding var tab: String
    @EnvironmentObject var theme: StudioTheme
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                tabButton("Canvas", icon: "rectangle.on.rectangle")
                tabButton("Zoom", icon: "plus.magnifyingglass")
            }.padding(10)
            Rule()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if tab == "Canvas" { canvasControls } else { zoomControls }
                }.padding(.horizontal,16).padding(.vertical,20)
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
                .frame(maxWidth: .infinity).frame(height: 36)
                .foregroundStyle(tab == name ? theme.accent : Ink.secondary)
                .background(tab == name ? theme.tint : .clear, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain).feedbackTarget("inspector.tab.\(name)","\(name) tab").accessibilityAddTraits(tab == name ? .isSelected : [])
    }
    private func heading(_ text: String, detail: String? = nil) -> some View {
        HStack(spacing:StudioLayout.helpGap) {
            Text(text).font(Geist.font(13, .semibold)).feedbackTarget("inspector.heading.\(text)",text)
            if let detail { InfoHint(title:text,text:detail) }
            Spacer()
        }
    }
    @ViewBuilder private var canvasControls: some View {
        HStack {
            heading("Background", detail: "Optional framing around your video. None uses the entire source without a background.")
            Button("None") { editor.update { $0.padding=0 } }.buttonStyle(StudioButtonStyle(quiet:true))
                .feedbackTarget("canvas.none","No background").accessibilityLabel("No background").accessibilityAddTraits(editor.project?.padding == 0 ? .isSelected:[]).disabled(editor.project == nil)
        }
        BackgroundPicker(editor:editor).feedbackTarget("canvas.background","Background options")
        if let p = editor.project {
            parameter("Padding", value: Binding(get: { p.padding * 100 }, set: { v in editor.update { $0.padding = v / 100 } }), range: 0...20, suffix: "%", decimals: 0)
        } else {
            HStack { Text("Padding"); Spacer(); Text("0%").foregroundStyle(Ink.secondary) }.font(Geist.font(12))
            Slider(value: .constant(0), in: 0...20).disabled(true)
        }
        Rule()
        heading("Trim", detail: "Choose the first and last moments to include. Your original recording stays unchanged.")
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
            detailRow("Format", "MP4 / MOV")
            detailRow("Resolution", editor.project == nil ? "Matches source" : "\(Int(editor.videoSize.width)) × \(Int(editor.videoSize.height))")
            detailRow("Audio", "From source")
        }
    }
    @ViewBuilder private var zoomControls: some View {
        heading("Focus the details", detail: "Add a zoom at the playhead, then choose where it looks.")
        Button(action: editor.addZoom) { Label("Add zoom", systemImage: "plus") }.buttonStyle(StudioButtonStyle()).disabled(editor.project == nil)
        if let p=editor.project, p.cursorSamples?.isEmpty == false {
            HStack {
                Text("Pointer motion").font(StudioType.controlLabel)
                InfoHint(title:"Pointer motion",text:"Smooth softens fast moves and sharp turns. Extra smooth gives a more relaxed path. Recorded follows the saved positions. Original system cursor shapes in older videos cannot be changed.")
            }
            Picker("Pointer motion",selection:Binding(get:{p.pointerSmoothing ?? .smooth},set:{ value in editor.update { $0.pointerSmoothing=value } })) {
                ForEach(PointerSmoothing.allCases) { value in Text(value.name).tag(value) }
            }.labelsHidden().feedbackTarget("motion.pointer","Pointer smoothing")
            HStack {
                Button(action:editor.suggestZooms) { Label("Auto focus",systemImage:"sparkles") }.buttonStyle(StudioButtonStyle()).feedbackTarget("motion.autofocus","Auto focus")
                InfoHint(title:"Auto focus",text:"Suggests zooms from pointer movement and pauses. Refreshing replaces previous automatic suggestions and keeps your manual zooms. Each suggestion stays editable.")
            }
        }
        if let p = editor.project, let z = p.zooms.first(where: { $0.id == editor.selectedZoomID }) {
            Rule()
            HStack { Text(z.automatic == true ? "Automatic zoom":"Selected zoom").font(Geist.font(13, .semibold)); InfoHint(title:"Zoom detail",text:"Zoom enlarges the original pixels. Stronger magnification also enlarges compression artifacts. For future recordings with small text, choose Maximum detail before recording; it uses much more disk space. Lower magnification can keep existing recordings clearer."); Spacer(); IconButton(symbol: "trash", title: "Delete selected zoom", action: editor.deleteSelectedZoom) }
            FocusPad(x: zoomBinding(z, \.x), y: zoomBinding(z, \.y), image: editor.thumbnails.first).environmentObject(theme)
            parameter("Magnification", value: zoomBinding(z, \.scale), range: 1...4, suffix: "×", decimals: 1)
            parameter("Start", value: zoomBinding(z, \.start), range: 0...max(0, editor.duration - z.duration), suffix: "s", decimals: 2)
            parameter("Duration", value: zoomBinding(z, \.duration), range: min(0.1, max(0.001, editor.duration-z.start))...max(0.001, editor.duration-z.start), suffix: "s", decimals: 2)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "cursorarrow.rays").font(.system(size: 25, weight: .light))
                Text(editor.project?.zooms.isEmpty == false ? "Select a region on the timeline to adjust its focus." : "Your zoom regions will appear on the timeline.").multilineTextAlignment(.center).font(Geist.font(12))
            }.foregroundStyle(Ink.secondary).frame(maxWidth: .infinity).padding(.vertical, 36)
        }
    }
    private func zoomBinding(_ z: Zoom, _ key: WritableKeyPath<Zoom, Double>) -> Binding<Double> {
        Binding(get: { z[keyPath: key] }, set: { value in
            editor.update { p in if let i = p.zooms.firstIndex(where: { $0.id == z.id }) { p.zooms[i][keyPath: key] = value;p.zooms[i].automatic=nil } }
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
            Slider(value: value, in: range).tint(theme.accent).accessibilityLabel(label).frame(minHeight: 30).feedbackTarget("parameter.\(label)",label)
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
