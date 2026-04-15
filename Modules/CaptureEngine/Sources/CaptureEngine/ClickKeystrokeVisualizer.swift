import AppKit
import CoreGraphics

/// Monitors global mouse clicks and keystrokes via CGEventTap, showing
/// visual fade-out indicators in a transparent overlay window.
/// Requires Accessibility permission.
public final class ClickKeystrokeVisualizer {
    private var eventTap: CFMachPort?
    private var overlayWindow: NSWindow?
    private var overlayView: VisualizerView?

    public init() {}

    public func start() {
        let mask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue)
                              | (1 << CGEventType.keyDown.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let viz = Unmanaged<ClickKeystrokeVisualizer>.fromOpaque(refcon)
                    .takeUnretainedValue()
                if type == .leftMouseDown {
                    let loc = event.location
                    DispatchQueue.main.async {
                        viz.showClickIndicator(at: NSPoint(x: loc.x, y: loc.y))
                    }
                } else if type == .keyDown {
                    let code = event.getIntegerValueField(.keyboardEventKeycode)
                    DispatchQueue.main.async { viz.showKeystroke(keyCode: Int(code)) }
                }
                return Unmanaged.passRetained(event)
            },
            userInfo: selfPtr
        )
        guard let tap = eventTap else { return }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        setupOverlay()
    }

    public func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        eventTap = nil
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        overlayView = nil
    }

    private func setupOverlay() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let win = NSWindow(contentRect: screen.frame, styleMask: .borderless,
                           backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .screenSaver
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = VisualizerView(frame: screen.frame)
        win.contentView = view
        win.orderFront(nil)
        overlayWindow = win
        overlayView = view
    }

    private func showClickIndicator(at point: NSPoint) { overlayView?.addClick(at: point) }
    private func showKeystroke(keyCode: Int) { overlayView?.addKeystroke(keyCode: keyCode) }
}

// MARK: - VisualizerView

private final class VisualizerView: NSView {
    private struct Indicator {
        var center: CGPoint
        var opacity: CGFloat = 1.0
        var isKeystroke: Bool = false
    }
    private var indicators: [Indicator] = []
    private var timer: Timer?

    override init(frame: NSRect) {
        super.init(frame: frame)
        timer = Timer.scheduledTimer(withTimeInterval: 1/30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    func addClick(at point: NSPoint) {
        indicators.append(Indicator(center: point))
        setNeedsDisplay(bounds)
    }

    func addKeystroke(keyCode: Int) {
        let center = CGPoint(x: bounds.midX, y: 80)
        indicators.append(Indicator(center: center, isKeystroke: true))
        setNeedsDisplay(bounds)
    }

    private func tick() {
        indicators = indicators.compactMap { var i = $0; i.opacity -= 0.04; return i.opacity > 0 ? i : nil }
        setNeedsDisplay(bounds)
    }

    override func draw(_ dirtyRect: NSRect) {
        for ind in indicators {
            let r: CGFloat = ind.isKeystroke ? 24 : 18
            NSColor.systemYellow.withAlphaComponent(ind.opacity).setFill()
            NSBezierPath(ovalIn: CGRect(x: ind.center.x - r, y: ind.center.y - r,
                                        width: r * 2, height: r * 2)).fill()
        }
    }
}
