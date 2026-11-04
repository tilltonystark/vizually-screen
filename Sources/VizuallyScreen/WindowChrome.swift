import SwiftUI
import AppKit

/// Let AppKit place traffic lights in the same unified header as the studio.
struct WindowChrome:NSViewRepresentable {
    func makeNSView(context:Context) -> NSView { ChromeView() }
    func updateNSView(_ view:NSView,context:Context) {}
    private final class ChromeView:NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.title="Vizually Screen"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent=true
            window.isMovableByWindowBackground=true
            if window.toolbar == nil {
                let toolbar=NSToolbar(identifier:"VizuallyScreen.Header")
                window.toolbar=toolbar
            }
            window.toolbarStyle = .unified
        }
    }
}
