import AppKit

final class AreaSelectionView: NSView {
    private var startPoint: CGPoint?
    private var currentRect: CGRect = .zero
    private let onSelect: (CGRect) -> Void
    private let onCancel: () -> Void
    private let screen: NSScreen

    init(screen: NSScreen,
         onSelect: @escaping (CGRect) -> Void,
         onCancel: @escaping () -> Void) {
        self.screen = screen
        self.onSelect = onSelect
        self.onCancel = onCancel
        super.init(frame: screen.frame)
    }

    required init?(coder: NSCoder) { fatalError() }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.35).setFill()
        NSBezierPath.fill(bounds)

        guard currentRect.width > 2 && currentRect.height > 2 else { return }

        // Clear selected region
        NSColor.clear.setFill()
        currentRect.fill(using: .copy)

        // Border
        NSColor.white.setStroke()
        let path = NSBezierPath(rect: currentRect)
        path.lineWidth = 1.5
        path.stroke()

        // Dimension label
        let label = "\(Int(currentRect.width)) × \(Int(currentRect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = (label as NSString).size(withAttributes: attrs)
        let labelRect = CGRect(x: currentRect.midX - size.width / 2,
                               y: currentRect.maxY + 6,
                               width: size.width + 8,
                               height: size.height + 4)
        NSColor.black.withAlphaComponent(0.6).setFill()
        NSBezierPath(roundedRect: labelRect, xRadius: 3, yRadius: 3).fill()
        (label as NSString).draw(at: CGPoint(x: labelRect.minX + 4, y: labelRect.minY + 2),
                                 withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = .zero
        setNeedsDisplay(bounds)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        currentRect = CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        setNeedsDisplay(bounds)
    }

    override func mouseUp(with event: NSEvent) {
        guard currentRect.width > 5 && currentRect.height > 5 else {
            onCancel(); return
        }
        // Convert flipped view coords → screen coords
        let screenRect = CGRect(
            x: screen.frame.minX + currentRect.minX,
            y: screen.frame.minY + (screen.frame.height - currentRect.maxY),
            width: currentRect.width,
            height: currentRect.height
        )
        onSelect(screenRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel() }  // Escape
    }

    override var acceptsFirstResponder: Bool { true }
}
