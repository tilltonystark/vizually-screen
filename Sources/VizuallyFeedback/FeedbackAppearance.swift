import SwiftUI

/// Styling belongs to the host. The library does not bundle fonts or import its theme.
public struct FeedbackAppearance {
  public var regularFontName: String?
  public var mediumFontName: String?
  public var accent: Color
  public var surface: Color
  public var field: Color
  public var text: Color
  public var secondaryText: Color
  public init(
    regularFontName: String? = nil, mediumFontName: String? = nil, accent: Color = .blue,
    surface: Color = Color(nsColor: .windowBackgroundColor),
    field: Color = Color(nsColor: .controlBackgroundColor), text: Color = .primary,
    secondaryText: Color = .secondary
  ) {
    self.regularFontName = regularFontName
    self.mediumFontName = mediumFontName
    self.accent = accent
    self.surface = surface
    self.field = field
    self.text = text
    self.secondaryText = secondaryText
  }
  func font(_ size: CGFloat, medium: Bool = false) -> Font {
    if let name = medium ? mediumFontName ?? regularFontName : regularFontName {
      return .custom(name, size: size)
    }
    return .system(size: size, weight: medium ? .medium : .regular)
  }
}
struct FeedbackSendStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  var appearance: FeedbackAppearance
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 14, weight: .semibold))
      .frame(width: 32, height: 32)
      .foregroundStyle(isEnabled ? Color.white : appearance.secondaryText)
      .background(
        isEnabled ? appearance.accent.opacity(configuration.isPressed ? 0.8 : 1)
          : appearance.secondaryText.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
      .frame(width: 44, height: 44).contentShape(Rectangle())
  }
}
