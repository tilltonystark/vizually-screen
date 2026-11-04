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
  var appearance: FeedbackAppearance
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(appearance.font(13, medium: true)).padding(.horizontal, 14).frame(
      minHeight: 36
    )
    .foregroundStyle(.white).background(
      appearance.accent.opacity(configuration.isPressed ? 0.8 : 1),
      in: RoundedRectangle(cornerRadius: 8))
  }
}
