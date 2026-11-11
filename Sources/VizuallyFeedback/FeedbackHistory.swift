import SwiftUI

struct FeedbackHistory: View {
  @ObservedObject var store: FeedbackStore
  let appearance: FeedbackAppearance
  let maxListHeight: CGFloat
  let hasDraft: Bool
  let startComment: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("Feedback").font(appearance.font(14, medium: true))
          .accessibilityAddTraits(.isHeader)
        Spacer(minLength: 8)
        Button(hasDraft ? "Back to draft" : "New comment", action: startComment)
          .font(appearance.font(12, medium: true))
          .buttonStyle(.bordered)
          .keyboardShortcut("c", modifiers: [])
      }
      .padding(.horizontal, 16).frame(minHeight: 48)
      Divider()
      if store.items.isEmpty {
        Text(store.error == nil ? "No feedback yet." : "Couldn’t load saved feedback.")
          .font(appearance.font(13)).foregroundStyle(appearance.secondaryText)
          .padding(16).frame(maxWidth: .infinity, alignment: .leading)
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(store.items) { item in
              row(item)
              if item.id != store.items.last?.id { Divider().padding(.horizontal, 16) }
            }
          }
        }
        .frame(height: min(maxListHeight, max(144, CGFloat(store.items.count) * 100)))
        .accessibilityLabel("Feedback history")
      }
    }
    .frame(width: 352)
    .foregroundStyle(appearance.text)
    .background(appearance.surface)
    .tint(appearance.accent)
  }

  private func row(_ item: FeedbackRecord) -> some View {
    let status = FeedbackStatus(item, connectionEnabled: store.connectionEnabled)
    return VStack(alignment: .leading, spacing: 5) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(item.targetLabel).font(appearance.font(12, medium: true)).lineLimit(1)
        Spacer(minLength: 0)
        Text(status.rawValue).font(appearance.font(11, medium: true))
          .foregroundStyle(appearance.secondaryText).fixedSize()
      }
      Text(item.comment).font(appearance.font(13)).textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
      if status == .waitingForInput, let question = item.agentQuestion {
        Text(question).font(appearance.font(12)).textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true)
          .padding(8).frame(maxWidth: .infinity, alignment: .leading)
          .background(appearance.field, in: RoundedRectangle(cornerRadius: 6))
      }
      Text(item.created, format: .dateTime.month(.abbreviated).day().year())
        .font(appearance.font(11)).foregroundStyle(appearance.secondaryText)
    }
    .padding(.horizontal, 16).padding(.vertical, 12)
    .accessibilityElement(children: .contain)
  }
}
