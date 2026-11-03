import SwiftUI
import FramecraftCore
import CoreText

struct AppearanceLab: View {
    @EnvironmentObject var theme: StudioTheme
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Appearance Lab").font(Geist.font(24,.semibold)).tracking(-0.6)
                    Text("Tune the real editor. Keep the settings you like.").font(Geist.font(13)).foregroundStyle(Ink.secondary)
                }
                Spacer()
                Button("Reset") { theme.settings = Appearance() }.buttonStyle(StudioButtonStyle(quiet: true))
            }
            VStack(alignment: .leading, spacing: 16) {
                AntialiasedTypeSample().frame(height: 34)
                Text("Geist · Regular, Medium, Semibold").font(Geist.font(12)).foregroundStyle(Ink.secondary)
                HStack(spacing: 12) {
                    Button("Primary action") {}.buttonStyle(StudioButtonStyle(primary: true))
                    Button("Secondary") {}.buttonStyle(StudioButtonStyle())
                    Text("00:12.48").font(Geist.font(13,.medium)).monospacedDigit().foregroundStyle(Ink.secondary)
                }
                HStack(spacing: 8) { Circle().fill(theme.accent).frame(width: 7,height: 7); Text("Preview uses the same type, colors and controls as the editor.").font(Geist.font(12)).foregroundStyle(Ink.secondary) }
            }.padding(theme.settings.spacing).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white, in: RoundedRectangle(cornerRadius: theme.radius))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
            labSlider("Accent hue", value: $theme.settings.accentHue, range: 230...300, suffix: "°")
            labSlider("Canvas lightness", value: $theme.settings.canvasLightness, range: 0.92...0.98, suffix: "", decimals: 3)
            labSlider("Corner radius", value: $theme.settings.radius, range: 6...16, suffix: " pt")
            labSlider("Canvas spacing", value: $theme.settings.spacing, range: 16...28, suffix: " pt")
            HStack {
                Image(systemName: "checkmark.circle").foregroundStyle(theme.accent)
                Text("Text contrast \(StudioColor.contrast(StudioColor.rgb(0.46,0.008),StudioColor.rgb(theme.settings.canvasLightness,0.003)), specifier: "%.1f"):1 · Native antialiasing")
                    .font(Geist.font(12)).foregroundStyle(Ink.secondary)
            }
            Rule()
            HStack {
                Button("Import settings…", action: theme.load).buttonStyle(StudioButtonStyle())
                Spacer()
                Button("Save appearance…", action: theme.save).buttonStyle(StudioButtonStyle(primary: true))
            }
            Text(theme.savedPath.isEmpty ? "Save as appearance.json. To ship it as the default, replace Resources/appearance.json and rebuild." : "Saved configuration: \(theme.savedPath)")
                .font(Geist.font(11)).foregroundStyle(Ink.secondary).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }.padding(28).frame(width: 604).background(theme.canvas).tint(theme.accent)
        .alert("Unable to load appearance", isPresented: Binding(get: { theme.error != nil }, set: { if !$0 { theme.error = nil } })) { Button("OK") { theme.error = nil } } message: { Text(theme.error ?? "") }
    }
    private func labSlider(_ name: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String, decimals: Int = 0) -> some View {
        HStack(spacing: 20) {
            Text(name).font(Geist.font(13,.medium)).frame(width: 132, alignment: .leading)
            Slider(value: value, in: range).accessibilityLabel(name)
            Text(String(format: "%.*f%@",decimals,value.wrappedValue,suffix)).font(Geist.font(12)).monospacedDigit().frame(width: 60,alignment: .trailing)
        }.frame(height: 32)
    }
}

// Core Text sample explicitly enables antialiasing/smoothing in its drawing context.
// SwiftUI text elsewhere uses macOS's native antialiased rendering by default.
struct AntialiasedTypeSample: NSViewRepresentable {
    func makeNSView(context: Context) -> TypeSampleView { TypeSampleView() }
    func updateNSView(_ nsView: TypeSampleView, context: Context) { nsView.needsDisplay = true }
}
final class TypeSampleView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.setAllowsAntialiasing(true); context.setShouldAntialias(true)
        context.setAllowsFontSmoothing(true); context.setShouldSmoothFonts(true)
        let text = NSAttributedString(string: "Make room for the details.", attributes: [.font: NSFont(name: "Geist-Medium", size: 24)!, .foregroundColor: NSColor(calibratedWhite: 0.12, alpha: 1)])
        context.textPosition = CGPoint(x: 0, y: 7)
        CTLineDraw(CTLineCreateWithAttributedString(text), context)
        context.restoreGState()
    }
}
