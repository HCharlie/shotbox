import AppKit
import ScreenCaptureKit
import SharedModels

/// Presents a crosshair selection overlay and returns the captured CGImage.
@available(macOS 14.0, *)
@MainActor
public final class AreaCapture {
    public static var lastRect: CGRect? = nil

    private var completion: ((Result<CGImage, Error>) -> Void)?
    private var overlayWindows: [CaptureOverlayWindow] = []

    public init() {}

    public func capture() async throws -> CGImage {
        try await withCheckedThrowingContinuation { cont in
            self.completion = { cont.resume(with: $0) }
            self.presentOverlay()
        }
    }

    public func retakeLast() async throws -> CGImage {
        guard let rect = Self.lastRect else { throw CaptureError.noLastRect }
        let screen = NSScreen.screens.first(where: { $0.frame.contains(
            CGPoint(x: rect.midX, y: rect.midY)) }) ?? NSScreen.main ?? NSScreen.screens[0]
        return try await captureRect(rect, on: screen)
    }

    // MARK: - Private

    private func presentOverlay() {
        for screen in NSScreen.screens {
            let win = CaptureOverlayWindow(screen: screen)
            let view = AreaSelectionView(screen: screen) { [weak self] selectedRect in
                self?.dismissOverlay()
                guard let self else { return }
                Task { @MainActor in
                    do {
                        let image = try await self.captureRect(selectedRect, on: screen)
                        AreaCapture.lastRect = selectedRect
                        self.completion?(.success(image))
                    } catch {
                        self.completion?(.failure(error))
                    }
                }
            } onCancel: { [weak self] in
                self?.dismissOverlay()
                self?.completion?(.failure(CaptureError.cancelled))
            }
            win.contentView = view
            win.makeKeyAndOrderFront(nil)
            overlayWindows.append(win)
        }
        NSCursor.crosshair.push()
    }

    private func dismissOverlay() {
        NSCursor.pop()
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
    }

    private func captureRect(_ rect: CGRect, on screen: NSScreen) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.frame.intersects(screen.frame) })
        else { throw CaptureError.noDisplayFound }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = rect
        config.scalesToFit = false
        return try await SCScreenshotManager.captureImage(contentFilter: filter,
                                                           configuration: config)
    }
}
