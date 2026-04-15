import AppKit
import SwiftUI
import SharedModels

final class QuickOverlayPanel: NSPanel {
    private var dismissTimer: Timer?
    private var capture: Capture?

    var onAnnotate: ((Capture) -> Void)?
    var onCopy:    ((Capture) -> Void)?
    var onSave:    ((Capture) -> Void)?
    var onPin:     ((Capture) -> Void)?
    var onOCR:     ((Capture) -> Void)?
    var onDelete:  ((Capture) -> Void)?

    init() {
        super.init(contentRect: CGRect(x: 0, y: 0, width: 300, height: 110),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    func show(capture: Capture) {
        self.capture = capture
        let view = QuickOverlayView(
            capture: capture,
            onAnnotate: { [weak self] in self?.capture.map { self?.onAnnotate?($0) }; self?.dismiss() },
            onCopy:     { [weak self] in self?.capture.map { self?.onCopy?($0) };    self?.dismiss() },
            onSave:     { [weak self] in self?.capture.map { self?.onSave?($0) } },
            onPin:      { [weak self] in self?.capture.map { self?.onPin?($0) };     self?.dismiss() },
            onOCR:      { [weak self] in self?.capture.map { self?.onOCR?($0) };     self?.dismiss() },
            onDelete:   { [weak self] in self?.capture.map { self?.onDelete?($0) };  self?.dismiss() },
            onDismiss:  { [weak self] in self?.dismiss() }
        )
        contentView = NSHostingView(rootView: view)

        // Position: bottom-right of main screen
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.maxX - frame.width - 16
            let y = screen.visibleFrame.minY + 16
            setFrameOrigin(NSPoint(x: x, y: y))
        }
        orderFront(nil)
        scheduleDismiss()
    }

    private func scheduleDismiss() {
        let timeout = AppSettings.shared.overlayDismissTimeout
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissTimer?.invalidate()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            self?.alphaValue = 1
        })
    }
}
