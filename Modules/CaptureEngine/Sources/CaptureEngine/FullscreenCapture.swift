import AppKit
import ScreenCaptureKit
import SharedModels

@available(macOS 14.0, *)
public final class FullscreenCapture {
    public init() {}

    /// Captures all connected displays. Returns one CGImage per display.
    public func captureAll() async throws -> [(screen: NSScreen, image: CGImage)] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true)
        var results: [(NSScreen, CGImage)] = []
        for screen in NSScreen.screens {
            guard let display = content.displays.first(where: { $0.frame.intersects(screen.frame) })
            else { continue }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.scalesToFit = false
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter,
                                                                    configuration: config)
            results.append((screen, image))
        }
        return results
    }

    /// Captures the display under the current mouse cursor.
    public func captureMainDisplay() async throws -> CGImage {
        let mouseScreen = NSScreen.screens.first(where: {
            $0.frame.contains(NSEvent.mouseLocation)
        }) ?? NSScreen.main ?? NSScreen.screens[0]

        let content = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: {
            $0.frame.intersects(mouseScreen.frame)
        }) else { throw CaptureError.noDisplayFound }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.scalesToFit = false
        return try await SCScreenshotManager.captureImage(contentFilter: filter,
                                                           configuration: config)
    }
}
