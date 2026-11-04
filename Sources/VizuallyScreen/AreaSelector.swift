import AppKit
import VizuallyScreenCore

@MainActor
final class AreaSelector {
    private var panels:[AreaPanel]=[]
    func present(on screens:[NSScreen], completion:@escaping ((NSScreen,CGRect)?)->Void) {
        cancel()
        for screen in screens {
            let panel=AreaPanel(contentRect:screen.frame,styleMask:.borderless,backing:.buffered,defer:false)
            panel.isReleasedWhenClosed=false;panel.isOpaque=false;panel.backgroundColor = .clear
            panel.level = .statusBar;panel.hasShadow=false;panel.hidesOnDeactivate=false
            panel.worksWhenModal=true;panel.becomesKeyOnlyIfNeeded=false
            panel.isMovable=false;panel.isMovableByWindowBackground=false
            panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary]
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
        NSApp.activate(ignoringOtherApps:true)
        let active=panels.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? panels.first
        active?.makeKeyAndOrderFront(nil)
        if let active { active.makeFirstResponder(active.contentView) }
    }
    func cancel() {
        let previous=panels;panels=[]
        for panel in previous { panel.orderOut(nil);panel.close() }
    }
}
private final class AreaPanel:NSPanel { override var canBecomeKey:Bool { true } }
private final class AreaSelectionView:NSView {
    var pixelScale=1.0
    var finish:((CGRect?)->Void)?
    private var start:CGPoint?
    private var selection:CGRect?
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
        if let selection { text="\(Int((selection.width*pixelScale).rounded())) × \(Int((selection.height*pixelScale).rounded())) px   ·   Release to select   ·   Esc to cancel" }
        else { text="Drag to select an area   ·   Esc to cancel" }
        let font=NSFont(name:"Geist-Medium",size:13) ?? .systemFont(ofSize:13,weight:.medium)
        let attributes:[NSAttributedString.Key:Any]=[.font:font,.foregroundColor:NSColor.labelColor]
        let size=(text as NSString).size(withAttributes:attributes)
        let badge=CGRect(x:max(12,(bounds.width-size.width-28)/2),y:24,width:size.width+28,height:40)
        NSColor.white.setFill();NSBezierPath(roundedRect:badge,xRadius:10,yRadius:10).fill()
        (text as NSString).draw(at:CGPoint(x:badge.minX+14,y:badge.minY+(badge.height-size.height)/2),withAttributes:attributes)
    }
}
