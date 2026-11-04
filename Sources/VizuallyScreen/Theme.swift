import SwiftUI
import CoreText
import VizuallyScreenCore
import UniformTypeIdentifiers

enum StudioResources {
    static let bundle: Bundle = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("VizuallyScreen_VizuallyScreen.bundle"), let bundle = Bundle(url: url) { return bundle }
        return Bundle.module
    }()
}

@MainActor
final class StudioTheme: ObservableObject {
    @Published var settings = Appearance()
    @Published var savedPath = ""
    @Published var error: String?
    init() {
        if let url = StudioResources.bundle.url(forResource: "appearance", withExtension: "json", subdirectory: "Resources"),
           let data = try? Data(contentsOf: url), let value = try? JSONDecoder().decode(Appearance.self, from: data), (try? value.validate()) != nil { settings = value }
    }
    var accent: Color { .oklch(0.48, 0.18, settings.accentHue) }
    var tint: Color { .oklch(0.95, 0.025, settings.accentHue) }
    var canvas: Color { .oklch(settings.canvasLightness, 0.003) }
    var radius: CGFloat { settings.radius }
    func save() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "appearance.json"
        if panel.runModal() == .OK, let url = panel.url {
            do { try settings.validate(); let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; try encoder.encode(settings).write(to: url, options: .atomic); savedPath = url.path }
            catch { self.error = error.localizedDescription }
        }
    }
    func load() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            do { let value = try JSONDecoder().decode(Appearance.self, from: Data(contentsOf: url)); try value.validate(); settings = value; savedPath = url.path }
            catch { self.error = error.localizedDescription }
        }
    }
}

extension Color {
    static func oklch(_ l: Double, _ c: Double = 0, _ h: Double = 265) -> Color {
        let rgb = StudioColor.rgb(l, c, h)
        return Color(.sRGB, red: rgb.0, green: rgb.1, blue: rgb.2, opacity: 1)
    }
}
enum Ink {
    static let primary = Color.oklch(0.25, 0.008)
    static let secondary = Color.oklch(0.46, 0.008)
    static let muted = Color.oklch(0.51, 0.008)
    static let line = Color.oklch(0.89, 0.004)
    static let soft = Color.oklch(0.975, 0.002)
}
enum StudioLayout {
    static let panelGap:CGFloat=14
    static let swatchHeight:CGFloat=40
    static let headerHeight:CGFloat=56
    static let headerLeading:CGFloat=92
    static let helpWidth:CGFloat=280
    static let helpPadding:CGFloat=16
    static let helpGap:CGFloat=6
    static let helpTarget:CGFloat=28
    static let helpDelay:Duration = .milliseconds(250)
}
enum StudioType {
    static var swatchLabel:Font { Geist.font(10) }
    static var sectionTitle:Font { Geist.font(13,.semibold) }
    static var controlLabel:Font { Geist.font(13,.medium) }
    static var caption:Font { Geist.font(12) }
    static var helpIcon:Font { Geist.font(13) }
}
enum Geist {
    static func register() {
        for name in ["Geist-Regular", "Geist-Medium", "Geist-SemiBold"] {
            guard let url = StudioResources.bundle.url(forResource: name, withExtension: "ttf", subdirectory: "Resources/Fonts") else { fatalError("Missing bundled font: \(name)") }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            precondition(NSFont(name: name, size: 14) != nil, "Geist failed to register")
        }
    }
    static func font(_ size: CGFloat = 13, _ weight: Font.Weight = .regular) -> Font {
        .custom(weight == .semibold || weight == .bold ? "Geist-SemiBold" : weight == .medium ? "Geist-Medium" : "Geist-Regular", size: size)
    }
}

struct StudioButtonStyle: ButtonStyle {
    @EnvironmentObject var theme: StudioTheme
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var primary = false
    var quiet = false
    func makeBody(configuration: Configuration) -> some View {
        ButtonBody(configuration: configuration, primary: primary, quiet: quiet, enabled: enabled, reduceMotion: reduceMotion).environmentObject(theme)
    }
    private struct ButtonBody: View {
        @EnvironmentObject var theme: StudioTheme
        let configuration: Configuration
        let primary: Bool, quiet: Bool, enabled: Bool, reduceMotion: Bool
        @State private var hover = false
        var body: some View {
            configuration.label.font(Geist.font(13, .medium)).lineLimit(1)
                .padding(.horizontal, quiet ? 10 : 14).frame(minHeight: 40)
                .foregroundStyle(primary ? Color.white : Ink.primary)
                .background(primary ? theme.accent : hover && enabled ? Color.oklch(0.94, 0.003) : quiet ? Color.clear : Color.white, in: RoundedRectangle(cornerRadius: theme.radius - 2))
                .overlay { if !quiet && !primary { RoundedRectangle(cornerRadius: theme.radius - 2).strokeBorder(Color.black.opacity(0.09), lineWidth: 0.5) } }
                .shadow(color: !quiet ? .black.opacity(0.04) : .clear, radius: 1, y: 1)
                .opacity(enabled ? 1 : 0.4)
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: hover)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
                .contentShape(Rectangle()).onHover { hover = $0 }
        }
    }
}
struct Rule: View {
    var vertical = false
    @Environment(\.displayScale) private var scale
    var body: some View { Rectangle().fill(Ink.line).frame(width: vertical ? 1/scale : nil, height: vertical ? nil : 1/scale) }
}
struct IconButton: View {
    let symbol: String
    let title: String
    let action: () -> Void
    var body: some View { Button(action: action) { Image(systemName: symbol).frame(width: 20) }.buttonStyle(StudioButtonStyle(quiet: true)).help(title).accessibilityLabel(title).feedbackTarget("control.\(symbol)",title) }
}
func clockText(_ seconds: Double) -> String {
    let safe = seconds.isFinite ? max(0, seconds) : 0
    return String(format: "%02d:%05.2f", Int(safe)/60, safe.truncatingRemainder(dividingBy: 60))
}
