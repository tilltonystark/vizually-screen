import SwiftUI

struct FeedbackTarget {
  var id: String
  var label: String
  var file: String
  var line: Int
  var anchor: Anchor<CGRect>
}
struct FeedbackTargets: PreferenceKey {
  static var defaultValue: [FeedbackTarget] { [] }
  static func reduce(value: inout [FeedbackTarget], nextValue: () -> [FeedbackTarget]) {
    value += nextValue()
  }
}
private struct FeedbackStoreKey: EnvironmentKey {
  static var defaultValue: FeedbackStore? { nil }
}
extension EnvironmentValues {
  fileprivate var feedbackStore: FeedbackStore? {
    get { self[FeedbackStoreKey.self] }
    set { self[FeedbackStoreKey.self] = newValue }
  }
}
private struct FeedbackTargetModifier: ViewModifier {
  @Environment(\.feedbackStore) private var store
  var id: String
  var label: String
  var file: String
  var line: Int
  func body(content: Content) -> some View {
    content.transformAnchorPreference(key: FeedbackTargets.self, value: .bounds) {
      targets, anchor in
      targets.append(FeedbackTarget(id: id, label: label, file: file, line: line, anchor: anchor))
    }.accessibilityAction(named: Text("Comment on \(label)")) { store?.requestComment(on: id) }
  }
}
extension View {
  /// Registers a precise target and a native accessibility action for opening a comment.
  public func feedbackTarget(
    _ id: String, _ label: String, file: String = #fileID, line: Int = #line
  ) -> some View {
    modifier(FeedbackTargetModifier(id: id, label: label, file: file, line: line))
  }
}
private struct FeedbackDraftBounds: PreferenceKey {
  static var defaultValue: CGRect { .zero }
  static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}
struct FeedbackSurface: ViewModifier {
  @ObservedObject var store: FeedbackStore
  var context: FeedbackContext
  var appearance: FeedbackAppearance
  var bottomInset: CGFloat
  var onActivate: () -> Void
  func body(content: Content) -> some View {
    content.padding(.bottom, bottomInset).feedbackTarget(
      "surface.\(context.route)", context.route.capitalized
    )
    .overlayPreferenceValue(FeedbackTargets.self) { targets in
      GeometryReader { geometry in
        FeedbackOverlay(
          store: store, context: context, appearance: appearance, onActivate: onActivate,
          targets: targets, geometry: geometry)
      }
    }
    .environment(\.feedbackStore, store)
  }
}
extension View {
  public func feedbackSurface(
    store: FeedbackStore, context: FeedbackContext,
    appearance: FeedbackAppearance = FeedbackAppearance(), bottomInset: CGFloat = 0,
    onActivate: @escaping () -> Void = {}
  ) -> some View {
    modifier(
      FeedbackSurface(
        store: store, context: context, appearance: appearance, bottomInset: bottomInset,
        onActivate: onActivate))
  }
}
struct FeedbackOverlay: View {
  @ObservedObject var store: FeedbackStore
  var context: FeedbackContext
  var appearance: FeedbackAppearance
  var onActivate: () -> Void
  var targets: [FeedbackTarget]
  var geometry: GeometryProxy
  @State private var pointer: CGPoint?
  @State private var selected: FeedbackTarget?
  @State private var pin = CGPoint.zero
  @State private var comment = ""
  @State private var pinnedContext: FeedbackContext?
  @State private var draftBounds = CGRect.zero
  @State private var historyVisible = false
  private func target(at point: CGPoint) -> FeedbackTarget? {
    targets.filter { geometry[$0.anchor].contains(point) }.min {
      let a = geometry[$0.anchor]
      let b = geometry[$1.anchor]
      return a.width * a.height < b.width * b.height
    }
  }
  private var dialogPosition: CGPoint {
    CGPoint(
      x: min(max(pin.x + 176, 176), geometry.size.width - 176),
      y: min(max(pin.y + 125, 150), geometry.size.height - 130))
  }
  private var fabRect: CGRect {
    CGRect(x: geometry.size.width - 68, y: geometry.size.height - 80, width: 48, height: 48)
  }
  private var exclusions: [CGRect] {
    var rects = [fabRect]
    if selected != nil {
      rects.append(
        draftBounds.isEmpty
          ? CGRect(x: dialogPosition.x - 160, y: dialogPosition.y - 110, width: 320, height: 220)
          : draftBounds)
    }
    return rects
  }
  private var status: (String, Color) {
    guard let latest = store.items.first else {
      return ("No feedback yet", appearance.secondaryText)
    }
    let state = FeedbackStatus(latest, connectionEnabled: store.connectionEnabled)
    switch state {
    case .resolved: return (state.rawValue, .green)
    case .inProgress: return (state.rawValue, .blue)
    case .queued, .unsent, .waitingForInput: return (state.rawValue, .orange)
    case .saved, .dismissed: return (state.rawValue, appearance.secondaryText)
    }
  }
  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      FeedbackEvents(
        selecting: store.enabled && !historyVisible, exclusions: exclusions, onMove: { pointer = $0 },
        onClick: { point in
          if selected != nil {
            clearSelection()
            return
          }
          if let target = target(at: point) {
            selected = target
            pin = point
            pinnedContext = context
            comment = ""
          }
        }, onToggle: toggle,
        onCancel: {
          clearSelection()
          store.enabled = false
        }
      ).frame(maxWidth: .infinity, maxHeight: .infinity)
      if store.enabled, let target = selected ?? pointer.flatMap({ target(at: $0) }) {
        let rect = geometry[target.anchor]
        RoundedRectangle(cornerRadius: 5).stroke(appearance.accent, lineWidth: 2).background(
          appearance.accent.opacity(0.08)
        ).frame(width: rect.width, height: rect.height).position(x: rect.midX, y: rect.midY)
          .allowsHitTesting(false)
        if selected == nil {
          Text(target.label).font(appearance.font(11, medium: true)).padding(.horizontal, 8)
            .padding(.vertical, 5).foregroundStyle(.white).background(
              appearance.accent, in: Capsule()
            ).position(
              x: min(max(rect.midX, 90), geometry.size.width - 90), y: max(14, rect.minY - 14)
            ).allowsHitTesting(false)
        }
      }
      Button(action: showHistory) {
        Image(systemName: store.enabled ? "bubble.left.fill" : "bubble.left").font(
          .system(size: 19, weight: .medium)
        ).foregroundStyle(store.enabled ? Color.white : appearance.text).frame(
          width: 48, height: 48
        ).background(store.enabled ? appearance.accent : appearance.surface, in: Circle()).overlay(
          Circle().strokeBorder(.black.opacity(0.1), lineWidth: 0.5)
        )
        .overlay(alignment: .topTrailing) {
          Circle().fill(status.1).frame(width: 10, height: 10).overlay(
            Circle().stroke(.white, lineWidth: 2)
          ).accessibilityHidden(true)
        }
      }.buttonStyle(.plain).shadow(color: .black.opacity(0.12), radius: 10, y: 4).help(
        "Feedback history · C to comment"
      ).accessibilityLabel("Feedback history").accessibilityValue(status.0)
        .popover(isPresented: $historyVisible, arrowEdge: .bottom) {
          FeedbackHistory(store: store, appearance: appearance,
            maxListHeight: min(344, max(128, geometry.size.height - 144)), hasDraft: selected != nil
          ) {
            historyVisible = false
            if selected == nil { store.enabled = true }
          }
          .onExitCommand { historyVisible = false }
        }
        .padding(.trailing, 20).padding(.bottom, 32)
      if let target = selected {
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Text(target.label).font(appearance.font(13, medium: true)).lineLimit(1)
            Spacer()
            Button(action: clearSelection) {
              Image(systemName: "xmark").font(.system(size: 11, weight: .medium))
                .frame(width: 28, height: 28).contentShape(Rectangle())
            }.buttonStyle(.plain).foregroundStyle(appearance.secondaryText)
              .help("Cancel comment").accessibilityLabel("Cancel comment")
          }
          VStack(alignment: .trailing, spacing: 0) {
            FeedbackInput(text: $comment, fontName: appearance.regularFontName) { submit(target) }
              .frame(height: 72)
              .overlay(alignment: .topLeading) {
                if comment.isEmpty {
                  Text("Write a comment…").font(appearance.font(13))
                    .foregroundStyle(appearance.secondaryText)
                    .padding(.leading, 10).padding(.top, 5)
                    .allowsHitTesting(false).accessibilityHidden(true)
                }
              }
              .padding([.top, .horizontal], 3)
            Button {
              submit(target)
            } label: {
              Image(systemName: "arrow.up")
            }.buttonStyle(FeedbackSendStyle(appearance: appearance))
              .disabled(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
              .help("Send comment").accessibilityLabel("Send comment")
          }
          .background(appearance.field, in: RoundedRectangle(cornerRadius: 9))
          .overlay {
            RoundedRectangle(cornerRadius: 9).strokeBorder(appearance.secondaryText.opacity(0.3))
              .allowsHitTesting(false)
          }
          if let error = store.error { Text(error).font(appearance.font(12)).foregroundStyle(.red) }
        }.padding(16).frame(width: 320).background(
          appearance.surface, in: RoundedRectangle(cornerRadius: 12)
        ).overlay {
          RoundedRectangle(cornerRadius: 12).strokeBorder(.black.opacity(0.12), lineWidth: 0.5)
            .allowsHitTesting(false)
        }.shadow(color: .black.opacity(0.12), radius: 18, y: 6)
          .background(
            GeometryReader { proxy in
              Color.clear.preference(
                key: FeedbackDraftBounds.self,
                value: proxy.frame(in: .named("VizuallyFeedback.overlay")))
            }
          ).position(dialogPosition)
        Circle().fill(appearance.accent).frame(width: 12, height: 12).overlay(
          Circle().stroke(.white, lineWidth: 2)
        ).position(pin).allowsHitTesting(false)
      }
    }.coordinateSpace(name: "VizuallyFeedback.overlay").foregroundStyle(appearance.text)
      .onPreferenceChange(FeedbackDraftBounds.self) { draftBounds = $0 }
      .onChange(of: store.enabled) { _, enabled in
        if enabled { onActivate() } else { clearSelection() }
      }
      .onExitCommand {
        if historyVisible { historyVisible = false }
        else {
          clearSelection()
          store.enabled = false
        }
      }
      .onChange(of: store.requestedTargetID) { _, id in
        if let id, let target = targets.first(where: { $0.id == id }) {
          historyVisible = false
          let rect = geometry[target.anchor]
          selected = target
          pin = CGPoint(x: rect.midX, y: rect.midY)
          pinnedContext = context
          comment = ""
          store.consumeTargetRequest()
        }
      }
      .onChange(of: context.route) { _, _ in
        historyVisible = false
        clearSelection()
      }
      .onReceive(
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
      ) { _ in
        historyVisible = false
        clearSelection()
        store.enabled = false
      }
      .task {
        while !Task.isCancelled {
          if !store.items.isEmpty { await store.sendPending() }
          do { try await Task.sleep(nanoseconds: 3_000_000_000) } catch { return }
        }
      }
  }
  private func clearSelection() {
    selected = nil
    pointer = nil
    comment = ""
    pinnedContext = nil
    draftBounds = .zero
  }
  private func toggle() {
    historyVisible = false
    store.enabled.toggle()
    clearSelection()
  }
  private func showHistory() {
    if selected == nil {
      store.enabled = false
      clearSelection()
    }
    historyVisible.toggle()
  }
  private func submit(_ target: FeedbackTarget) {
    guard !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    let rect = geometry[target.anchor]
    let item = FeedbackRecord(
      targetID: target.id, targetLabel: target.label, sourceFile: target.file,
      sourceLine: target.line, context: pinnedContext ?? context,
      bounds: [rect.minX, rect.minY, rect.width, rect.height],
      point: [(pin.x - rect.minX) / max(1, rect.width), (pin.y - rect.minY) / max(1, rect.height)],
      viewport: [geometry.size.width, geometry.size.height], build: store.configuration.build,
      comment: comment.trimmingCharacters(in: .whitespacesAndNewlines))
    if store.add(item) {
      selected = nil
      comment = ""
      Task { await store.sendPending() }
    }
  }
}
