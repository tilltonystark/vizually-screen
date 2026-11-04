import AppKit
import VizuallyScreenCore

@MainActor
final class AreaSelector {
    private var panel: AreaPanel?
    func present(on screen:NSScreen, pixelScale:Double, completion:@escaping (CGRect?)->Void) {
        cancel()
        let panel=AreaPanel(contentRect:screen.frame,styleMask:.borderless,backing:.buffered,defer:false)
        panel.isReleasedWhenClosed=false;panel.isOpaque=false;panel.backgroundColor = .clear
        panel.level = .screenSaver;panel.hasShadow=false
        panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary]
        let view=AreaSelectionView(frame:CGRect(origin:.zero,size:screen.frame.size))
        view.pixelScale=pixelScale
        view.finish={ [weak self] rect in
            self?.panel?.orderOut(nil);self?.panel?.close();self?.panel=nil
            completion(rect)
        }
        panel.contentView=view;self.panel=panel
        panel.makeKeyAndOrderFront(nil);panel.makeFirstResponder(view)
    }
    func cancel() { panel?.orderOut(nil);panel?.close();panel=nil }
}
private final class AreaPanel:NSPanel { override var canBecomeKey:Bool { true } }
private final class AreaSelectionView:NSView {
    var pixelScale=1.0
    var finish:((CGRect?)->Void)?
    private var start:CGPoint?
    private var selection:CGRect?
    override var isFlipped:Bool { true }
    override var acceptsFirstResponder:Bool { true }
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
