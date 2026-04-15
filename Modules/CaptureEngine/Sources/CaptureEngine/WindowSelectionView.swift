import AppKit
import ScreenCaptureKit

final class WindowSelectionView: NSView {
    struct WindowInfo {
        let windowID: UInt32
        let frame: CGRect
        let appName: String
        let scWindow: SCWindow
    }

    private let windows: [WindowInfo]
    private var hoveredWindowID: UInt32?
    private let onSelect: (WindowInfo) -> Void
    private let onCancel: () -> Void
    private let screen: NSScreen

    init(screen: NSScreen,
         windows: [WindowInfo],
         onSelect: @escaping (WindowInfo) -> Void,
         onCancel: @escaping () -> Void) {
        self.screen = screen
        self.windows = windows
        self.onSelect = onSelect
        self.onCancel = onCancel
        super.init(frame: screen.frame)
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.activeAlways, .mouseMoved, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    required init?(coder: NSCoder) { fatalError() }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.3).setFill()
        NSBezierPath.fill(bounds)

        guard let hid = hoveredWindowID,
              let win = windows.first(where: { $0.windowID == hid }) else { return }

        let localRect = screenRectToLocal(win.frame)
        NSColor.clear.setFill()
        localRect.fill(using: .copy)

        NSColor.controlAccentColor.setStroke()
        let path = NSBezierPath(rect: localRect.insetBy(dx: -2, dy: -2))
        path.lineWidth = 3
        path.stroke()
    }

    override func mouseMoved(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        let screenPt = CGPoint(x: screen.frame.minX + pt.x,
                               y: screen.frame.minY + (screen.frame.height - pt.y))
        hoveredWindowID = windows.first(where: { $0.frame.contains(screenPt) })?.windowID
        setNeedsDisplay(bounds)
    }

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        let screenPt = CGPoint(x: screen.frame.minX + pt.x,
                               y: screen.frame.minY + (screen.frame.height - pt.y))
        if let win = windows.first(where: { $0.frame.contains(screenPt) }) {
            onSelect(win)
        } else {
            onCancel()
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel() }
    }

    override var acceptsFirstResponder: Bool { true }

    private func screenRectToLocal(_ screenRect: CGRect) -> CGRect {
        CGRect(x: screenRect.minX - screen.frame.minX,
               y: screen.frame.height - (screenRect.minY - screen.frame.minY) - screenRect.height,
               width: screenRect.width,
               height: screenRect.height)
    }
}
