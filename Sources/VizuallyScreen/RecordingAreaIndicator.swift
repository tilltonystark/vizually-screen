import AppKit
import VizuallyScreenCore

/// Dim only excluded parts of the display; the recording rectangle has no window over it.
@MainActor
final class RecordingAreaIndicator:NSObject {
    private var panels:[NSPanel]=[]
    private var selection:(displayID:CGDirectDisplayID,rect:CGRect)?
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self,selector:#selector(refresh),name:NSApplication.didChangeScreenParametersNotification,object:nil)
    }
    deinit { NotificationCenter.default.removeObserver(self) }
    func show(displayID:CGDirectDisplayID,rect:CGRect) {
        selection=(displayID,rect);refresh()
    }
    func hide() {
        selection=nil
        closePanels()
    }
    private func closePanels() {
        let previous=panels;panels=[]
        for panel in previous { panel.orderOut(nil);panel.close() }
    }
    @objc private func refresh() {
        guard let selection,let screen=NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == selection.displayID
        }) else { closePanels();return }
        let area=CaptureArea.appKitBounds(local:selection.rect,displayFrame:screen.frame)
        let frames=CaptureArea.outsideMasks(around:area,in:screen.frame)
        if panels.count != frames.count {
            closePanels()
            for frame in frames {
                let panel=BoundaryPanel(contentRect:frame,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
                panel.isReleasedWhenClosed=false;panel.isOpaque=false;panel.backgroundColor = NSColor.black.withAlphaComponent(0.38)
                panel.hasShadow=false;panel.ignoresMouseEvents=true;panel.hidesOnDeactivate=false
                panel.worksWhenModal=true;panel.isMovable=false;panel.isMovableByWindowBackground=false
                panel.level = .statusBar
                panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.ignoresCycle]
                panels.append(panel)
            }
        }
        for (panel,frame) in zip(panels,frames) {
            panel.setFrame(frame,display:false)
            panel.orderFrontRegardless();panel.displayIfNeeded()
        }
    }
}
private final class BoundaryPanel:NSPanel {
    override var canBecomeKey:Bool { false }
    override var canBecomeMain:Bool { false }
}
