import AppKit
import VizuallyScreenCore

/// Four noninteractive strips outside the crop, rather than an overlay covering the video.
@MainActor
final class RecordingAreaIndicator:NSObject {
    private var panels:[NSPanel]=[]
    private var selection:(displayID:CGDirectDisplayID,rect:CGRect)?
    private var recording=false
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self,selector:#selector(refresh),name:NSApplication.didChangeScreenParametersNotification,object:nil)
    }
    deinit { NotificationCenter.default.removeObserver(self) }
    func show(displayID:CGDirectDisplayID,rect:CGRect,recording:Bool) {
        selection=(displayID,rect);self.recording=recording;refresh()
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
        let frames=CaptureArea.indicatorStrips(around:area)
        if panels.isEmpty {
            for _ in frames {
                let panel=BoundaryPanel(contentRect:.zero,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
                panel.isReleasedWhenClosed=false;panel.isOpaque=false;panel.backgroundColor = .clear
                panel.hasShadow=false;panel.ignoresMouseEvents=true;panel.hidesOnDeactivate=false
                panel.worksWhenModal=true;panel.isMovable=false;panel.isMovableByWindowBackground=false
                panel.level = .statusBar
                panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.ignoresCycle]
                panel.contentView=BoundaryStrip()
                panels.append(panel)
            }
        }
        for (panel,frame) in zip(panels,frames) {
            panel.setFrame(frame,display:false)
            if let view=panel.contentView as? BoundaryStrip {
                view.active=recording
                view.setAccessibilityElement(false)
                view.needsDisplay=true
            }
            panel.orderFrontRegardless();panel.displayIfNeeded()
        }
    }
}
private final class BoundaryPanel:NSPanel {
    override var canBecomeKey:Bool { false }
    override var canBecomeMain:Bool { false }
}
private final class BoundaryStrip:NSView {
    var active=false
    override func draw(_ dirtyRect:NSRect) {
        NSColor.black.withAlphaComponent(0.55).setFill();bounds.fill()
        (active ? NSColor.systemOrange:NSColor.white).setFill()
        bounds.insetBy(dx:bounds.width < bounds.height ? 0.5:0,dy:bounds.width < bounds.height ? 0:0.5).fill()
    }
}
