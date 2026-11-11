import SwiftUI

/// Use one AppKit coordinate conversion for input and geometry. Transparent to
/// normal interaction; only selection clicks outside our draft/FAB are consumed.
struct FeedbackEvents: NSViewRepresentable {
  var selecting: Bool
  var exclusions: [CGRect]
  var onMove: (CGPoint?) -> Void
  var onClick: (CGPoint) -> Void
  var onToggle: () -> Void
  var onCancel: () -> Void
  func makeNSView(context: Context) -> EventView {
    let view = EventView()
    view.config = self
    return view
  }
  func updateNSView(_ view: EventView, context: Context) { view.config = self }
  final class EventView: NSView {
    var config: FeedbackEvents?
    private var monitor: Any?
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if let monitor {
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
      }
      guard let window else { return }
      window.acceptsMouseMovedEvents = true
      monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .keyDown])
      { [weak self] event in
        guard let self, let config = self.config, event.window === self.window else { return event }
        if event.type == .keyDown {
          if config.selecting, event.keyCode == 53 {
            config.onCancel()
            return nil
          }
          let typing =
            (self.window?.firstResponder as? NSTextView)?.isEditable == true
            || self.window?.firstResponder is NSTextField
          if !typing, !event.isARepeat,
            event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
            event.charactersIgnoringModifiers?.lowercased() == "c"
          {
            config.onToggle()
            return nil
          }
          return event
        }
        guard config.selecting else { return event }
        let point = self.convert(event.locationInWindow, from: nil)
        guard self.bounds.contains(point),
          !config.exclusions.contains(where: { $0.contains(point) })
        else {
          if event.type == .mouseMoved { config.onMove(nil) }
          return event
        }
        if event.type == .mouseMoved {
          config.onMove(point)
          return nil
        }
        config.onClick(point)
        return nil
      }
    }
    deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
  }
}
struct FeedbackInput: NSViewRepresentable {
  @Binding var text: String
  var fontName: String?
  var submit: () -> Void
  func makeNSView(context: Context) -> NSScrollView {
    let scroll = NSScrollView()
    scroll.borderType = .noBorder
    scroll.focusRingType = .none
    scroll.drawsBackground = false
    scroll.hasVerticalScroller = true
    let input = InputView(frame: NSRect(x: 0, y: 0, width: 288, height: 88))
    input.minSize = .zero
    input.maxSize = NSSize(
      width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    input.isRichText = false
    input.focusRingType = .none
    input.drawsBackground = false
    input.font = fontName.flatMap { NSFont(name: $0, size: 13) } ?? NSFont.systemFont(ofSize: 13)
    input.textContainerInset = NSSize(width: 5, height: 5)
    input.isVerticallyResizable = true
    input.isHorizontallyResizable = false
    input.autoresizingMask = [.width]
    input.textContainer?.widthTracksTextView = true
    input.delegate = context.coordinator
    input.onSubmit = submit
    input.setAccessibilityLabel("Feedback comment")
    scroll.documentView = input
    DispatchQueue.main.async { input.window?.makeFirstResponder(input) }
    return scroll
  }
  func updateNSView(_ scroll: NSScrollView, context: Context) {
    context.coordinator.parent = self
    if let input = scroll.documentView as? InputView {
      if input.string != text { input.string = text }
      input.onSubmit = submit
    }
  }
  func makeCoordinator() -> Coordinator { Coordinator(self) }
  final class Coordinator: NSObject, NSTextViewDelegate {
    var parent: FeedbackInput
    init(_ parent: FeedbackInput) { self.parent = parent }
    func textDidChange(_ notification: Notification) {
      if let view = notification.object as? NSTextView { parent.text = view.string }
    }
  }
  final class InputView: NSTextView {
    var onSubmit: (() -> Void)?
    override func keyDown(with event: NSEvent) {
      if [36, 76].contains(event.keyCode), !event.modifierFlags.contains(.shift) {
        onSubmit?()
      } else {
        super.keyDown(with: event)
      }
    }
  }
}
