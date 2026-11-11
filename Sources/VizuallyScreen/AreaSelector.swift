import AppKit
import VizuallyScreenCore

@MainActor
final class AreaSelector: NSObject {
    private var panels:[AreaPanel]=[]
    func present(on screens:[NSScreen], completion:@escaping ((NSScreen,CGRect)?)->Void) {
        cancel()
        guard !screens.isEmpty else { completion(nil);return }
        for screen in screens {
            let panel=AreaPanel(contentRect:screen.frame,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
            panel.isReleasedWhenClosed=false;panel.isOpaque=false;panel.backgroundColor = .clear
            panel.level = .statusBar;panel.hasShadow=false;panel.hidesOnDeactivate=false
            panel.worksWhenModal=true;panel.becomesKeyOnlyIfNeeded=false
            panel.isMovable=false;panel.isMovableByWindowBackground=false
            panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.canJoinAllApplications,.ignoresCycle]
            let view=AreaSelectionView(frame:CGRect(origin:.zero,size:screen.frame.size))
            view.wantsLayer=true
            view.setAccessibilityElement(true)
            view.setAccessibilityRole(.group)
            view.setAccessibilityLabel("Select recording area. Drag a rectangle; Escape cancels.")
            view.pixelScale=screen.backingScaleFactor
            view.finish={ [weak self] rect in
                self?.cancel()
                completion(rect.map { (screen,$0) })
            }
            panel.contentView=view;panels.append(panel)
            panel.orderFrontRegardless()
            view.needsDisplay=true
            panel.displayIfNeeded()
        }
        let center=NSWorkspace.shared.notificationCenter
        center.addObserver(self,selector:#selector(raisePanels),name:NSWorkspace.didActivateApplicationNotification,object:nil)
        center.addObserver(self,selector:#selector(raisePanels),name:NSWorkspace.activeSpaceDidChangeNotification,object:nil)
        let active=panels.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? panels.first
        active?.makeKeyAndOrderFront(nil)
        if let active { active.makeFirstResponder(active.contentView) }
    }
    @objc private func raisePanels() {
        for panel in panels { panel.orderFrontRegardless() }
    }
    func cancel() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        let previous=panels;panels=[]
        for panel in previous { panel.orderOut(nil);panel.close() }
    }
}
private final class AreaPanel:NSPanel {
    override var canBecomeKey:Bool { true }
    override var canBecomeMain:Bool { false }
}
private final class AreaSelectionView:NSView {
    var pixelScale=1.0
    var finish:((CGRect?)->Void)?
    private var start:CGPoint?
    private var selection:CGRect?
    private lazy var cancelButton=NSButton(title:"Cancel",target:self,action:#selector(cancelSelection))
    private var badge:CGRect {
        let width=max(1,min(bounds.width-24,454))
        return CGRect(x:(bounds.width-width)/2,y:24,width:width,height:40)
    }
    override init(frame:NSRect) {
        super.init(frame:frame)
        addSubview(cancelButton)
    }
    required init?(coder:NSCoder) { nil }
    override func layout() {
        super.layout()
        cancelButton.frame=CGRect(x:badge.maxX-84,y:badge.minY,width:72,height:40)
    }
    @objc private func cancelSelection() { finish?(nil) }
    override var isFlipped:Bool { true }
    override var acceptsFirstResponder:Bool { true }
    override func acceptsFirstMouse(for event:NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds,cursor:.crosshair) }
    override func mouseDown(with event:NSEvent) {
        start=convert(event.locationInWindow,from:nil);selection=nil;needsDisplay=true
    }
    override func mouseDragged(with event:NSEvent) {
        guard let start else { return }
        selection=CaptureArea.selection(from:start,to:convert(event.locationInWindow,from:nil),displaySize:bounds.size,pixelScale:pixelScale)
        needsDisplay=true
    }
    override func mouseUp(with event:NSEvent) {
        mouseDragged(with:event)
        if let selection { finish?(selection) }
    }
    override func cancelOperation(_ sender:Any?) { finish?(nil) }
    override func keyDown(with event:NSEvent) { if event.keyCode == 53 { finish?(nil) } else { super.keyDown(with:event) } }
    override func draw(_ dirtyRect:NSRect) {
        NSColor.black.withAlphaComponent(0.38).setFill();bounds.fill()
        if let selection {
            NSColor.clear.setFill();selection.fill(using:.copy)
            NSColor.white.setStroke();let border=NSBezierPath(rect:selection);border.lineWidth=2;border.stroke()
        }
        let text:String
        if let selection { text="\(Int((selection.width*pixelScale).rounded())) × \(Int((selection.height*pixelScale).rounded())) px   ·   Release to select" }
        else { text="Switch apps with ⌘Tab, then drag to select" }
        let font=NSFont(name:"Geist-Medium",size:13) ?? .systemFont(ofSize:13,weight:.medium)
        let attributes:[NSAttributedString.Key:Any]=[.font:font,.foregroundColor:NSColor.black]
        let size=(text as NSString).size(withAttributes:attributes)
        NSColor.white.setFill();NSBezierPath(roundedRect:badge,xRadius:10,yRadius:10).fill()
        (text as NSString).draw(at:CGPoint(x:badge.minX+14,y:badge.minY+(badge.height-size.height)/2),withAttributes:attributes)
    }
}
