import AppKit
import ScreenCaptureKit
import CoreImage
import SharedModels

@available(macOS 14.0, *)
@MainActor
public final class WindowCapture {
    private var completion: ((Result<CGImage, Error>) -> Void)?
    private var overlayWindows: [CaptureOverlayWindow] = []

    public init() {}

    public func capture() async throws -> CGImage {
        let windows = try await fetchWindows()
        return try await withCheckedThrowingContinuation { cont in
            self.completion = { cont.resume(with: $0) }
            self.presentWindowOverlay(windows: windows)
        }
    }

    // MARK: - Private

    private func fetchWindows() async throws -> [WindowSelectionView.WindowInfo] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true)
        return content.windows.compactMap { w -> WindowSelectionView.WindowInfo? in
            guard w.frame.width > 50, w.frame.height > 50, w.isOnScreen else { return nil }
            return WindowSelectionView.WindowInfo(
                windowID: w.windowID,
                frame: w.frame,
                appName: w.owningApplication?.applicationName ?? "",
                scWindow: w
            )
        }
    }

    private func presentWindowOverlay(windows: [WindowSelectionView.WindowInfo]) {
        for screen in NSScreen.screens {
            let win = CaptureOverlayWindow(screen: screen)
            let view = WindowSelectionView(screen: screen, windows: windows) { [weak self] info in
                self?.dismissOverlay()
                guard let self else { return }
                Task { @MainActor in
                    do {
                        let image = try await self.captureWindow(info)
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

    private func captureWindow(_ info: WindowSelectionView.WindowInfo) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true)
        guard let scWin = content.windows.first(where: { $0.windowID == info.windowID })
        else { throw CaptureError.noWindowSelected }

        let filter = SCContentFilter(desktopIndependentWindow: scWin)
        let config = SCStreamConfiguration()
        config.scalesToFit = false

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter,
                                                                configuration: config)
        // Drop shadow is applied by the app layer (not CaptureEngine)
        return image
    }
}
