import AppKit

/// A transparent, fullscreen, non-activating NSPanel covering one display.
/// Used as the interaction surface for area/window/scrolling capture modes.
final class CaptureOverlayWindow: NSPanel {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        ignoresMouseEvents = false
        isMovable = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
}
