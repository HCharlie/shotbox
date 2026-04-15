import AppKit
import SwiftUI
import ScreenCaptureKit
import KeyboardShortcuts
import SharedModels
import HistoryStore
import CaptureEngine
import OCRService
import DesktopManager

class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Core components
    private var menuBarController: MenuBarController?
    private var overlayPanel: QuickOverlayPanel?
    private var historyPanelController: NSWindowController?
    private var annotationControllers: [UUID: AnnotationWindowController] = [:]
    private var floatingPanels: [FloatingScreenshotPanel] = []

    // MARK: - Recording state
    // Stored as Any? to avoid @available on stored properties (not valid Swift)
    private var _screenRecorder: Any? = nil
    private var _gifRecorder: Any? = nil
    private var isRecordingScreen = false
    private var isRecordingGIF = false

    @available(macOS 13.0, *)
    private var screenRecorder: ScreenRecorder? {
        get { _screenRecorder as? ScreenRecorder }
        set { _screenRecorder = newValue }
    }

    @available(macOS 13.0, *)
    private var gifRecorder: GIFRecorder? {
        get { _gifRecorder as? GIFRecorder }
        set { _gifRecorder = newValue }
    }

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBarController = MenuBarController()

        overlayPanel = QuickOverlayPanel()
        wireOverlayCallbacks()

        // Prune old history on launch
        Task {
            try? await HistoryStore.shared.pruneOlderThan(AppSettings.shared.historyRetentionDays)
        }

        registerNotificationObservers()
        registerKeyboardShortcuts()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Notification observers

    private func registerNotificationObservers() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleCaptureArea),
                       name: .captureArea, object: nil)
        nc.addObserver(self, selector: #selector(handleCaptureWindow),
                       name: .captureWindow, object: nil)
        nc.addObserver(self, selector: #selector(handleCaptureFullscreen),
                       name: .captureFullscreen, object: nil)
        nc.addObserver(self, selector: #selector(handleCaptureScrolling),
                       name: .captureScrolling, object: nil)
        nc.addObserver(self, selector: #selector(handleRecordScreen),
                       name: .recordScreen, object: nil)
        nc.addObserver(self, selector: #selector(handleRecordGIF),
                       name: .recordGIF, object: nil)
        nc.addObserver(self, selector: #selector(handleShowHistory),
                       name: .showHistory, object: nil)
        nc.addObserver(self, selector: #selector(handleOCR),
                       name: .ocrText, object: nil)
    }

    @objc private func handleCaptureArea()       { triggerCaptureArea() }
    @objc private func handleCaptureWindow()     { triggerCaptureWindow() }
    @objc private func handleCaptureFullscreen() { triggerCaptureFullscreen() }
    @objc private func handleCaptureScrolling()  { triggerCaptureScrolling() }
    @objc private func handleRecordScreen()      { triggerRecordScreen() }
    @objc private func handleRecordGIF()         { triggerRecordGIF() }
    @objc private func handleShowHistory()       { showHistoryPanel() }
    @objc private func handleOCR()               { triggerOCR() }

    // MARK: - Keyboard shortcuts

    private func registerKeyboardShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .captureArea)       { [weak self] in self?.triggerCaptureArea() }
        KeyboardShortcuts.onKeyUp(for: .captureWindow)     { [weak self] in self?.triggerCaptureWindow() }
        KeyboardShortcuts.onKeyUp(for: .captureFullscreen) { [weak self] in self?.triggerCaptureFullscreen() }
        KeyboardShortcuts.onKeyUp(for: .captureScrolling)  { [weak self] in self?.triggerCaptureScrolling() }
        KeyboardShortcuts.onKeyUp(for: .recordScreen)      { [weak self] in self?.triggerRecordScreen() }
        KeyboardShortcuts.onKeyUp(for: .recordGIF)         { [weak self] in self?.triggerRecordGIF() }
        KeyboardShortcuts.onKeyUp(for: .captureOCR)        { [weak self] in self?.triggerOCR() }
        KeyboardShortcuts.onKeyUp(for: .retakeLastCapture) { [weak self] in self?.triggerRetakeLastCapture() }
    }

    // MARK: - Capture triggers

    private func triggerCaptureArea() {
        if #available(macOS 14.0, *) {
            Task { @MainActor in
                do {
                    let image = try await AreaCapture().capture()
                    await saveAndShowOverlay(image: image, mode: .area)
                } catch {
                    NSLog("CaptureArea failed: %@", error.localizedDescription)
                }
            }
        } else {
            NSLog("Area capture requires macOS 14.0 or later")
        }
    }

    private func triggerCaptureWindow() {
        if #available(macOS 14.0, *) {
            Task { @MainActor in
                do {
                    let image = try await WindowCapture().capture()
                    await saveAndShowOverlay(image: image, mode: .window)
                } catch {
                    NSLog("CaptureWindow failed: %@", error.localizedDescription)
                }
            }
        } else {
            NSLog("Window capture requires macOS 14.0 or later")
        }
    }

    private func triggerCaptureFullscreen() {
        if #available(macOS 14.0, *) {
            Task { @MainActor in
                do {
                    let image = try await FullscreenCapture().captureMainDisplay()
                    await saveAndShowOverlay(image: image, mode: .fullscreen)
                } catch {
                    NSLog("CaptureFullscreen failed: %@", error.localizedDescription)
                }
            }
        } else {
            NSLog("Fullscreen capture requires macOS 14.0 or later")
        }
    }

    private func triggerCaptureScrolling() {
        if #available(macOS 14.0, *) {
            Task { @MainActor in
                do {
                    let content = try await SCShareableContent.excludingDesktopWindows(
                        false, onScreenWindowsOnly: true)
                    guard let window = content.windows.first(where: { $0.isOnScreen }) else {
                        NSLog("CaptureScrolling: no on-screen window found")
                        return
                    }
                    let image = try await ScrollingCapture().capture(in: window)
                    await saveAndShowOverlay(image: image, mode: .scrolling)
                } catch {
                    NSLog("CaptureScrolling failed: %@", error.localizedDescription)
                }
            }
        } else {
            NSLog("Scrolling capture requires macOS 14.0 or later")
        }
    }

    private func triggerRetakeLastCapture() {
        if #available(macOS 14.0, *) {
            Task { @MainActor in
                do {
                    let image = try await AreaCapture().retakeLast()
                    await saveAndShowOverlay(image: image, mode: .area)
                } catch {
                    NSLog("RetakeLast failed, falling back to area capture: %@", error.localizedDescription)
                    triggerCaptureArea()
                }
            }
        } else {
            NSLog("Retake last capture requires macOS 14.0 or later")
        }
    }

    // MARK: - Recording triggers

    private func triggerRecordScreen() {
        if #available(macOS 13.0, *) {
            if isRecordingScreen {
                stopScreenRecording()
            } else {
                startScreenRecording()
            }
        } else {
            NSLog("Screen recording requires macOS 13.0 or later")
        }
    }

    @available(macOS 13.0, *)
    private func startScreenRecording() {
        isRecordingScreen = true
        Task { @MainActor in
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(
                    false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    NSLog("No display found for screen recording")
                    isRecordingScreen = false
                    return
                }
                let filter = SCContentFilter(display: display, excludingWindows: [])
                var config = ScreenRecorder.Config()
                config.fps = AppSettings.shared.recordingFPS
                config.captureMicrophone = AppSettings.shared.recordMicrophone
                config.captureSystemAudio = AppSettings.shared.recordSystemAudio
                let recorder = ScreenRecorder(config: config)
                screenRecorder = recorder
                _ = try await recorder.startRecording(filter: filter)
                NSLog("Screen recording started")
            } catch {
                NSLog("Failed to start screen recording: %@", error.localizedDescription)
                isRecordingScreen = false
            }
        }
    }

    @available(macOS 13.0, *)
    private func stopScreenRecording() {
        guard let recorder = screenRecorder else { return }
        Task { @MainActor in
            do {
                let url = try await recorder.stopRecording()
                isRecordingScreen = false
                screenRecorder = nil
                NSLog("Screen recording saved to: %@", url.path)
                let thumbURL = HistoryStore.thumbnailsDirectory
                    .appendingPathComponent(UUID().uuidString + "_thumb.jpg")
                let capture = Capture(mode: .video, filePath: url, thumbnailPath: thumbURL)
                try? await HistoryStore.shared.ingest(capture)
            } catch {
                NSLog("Failed to stop screen recording: %@", error.localizedDescription)
                isRecordingScreen = false
                screenRecorder = nil
            }
        }
    }

    private func triggerRecordGIF() {
        if #available(macOS 13.0, *) {
            if isRecordingGIF {
                stopGIFRecording()
            } else {
                startGIFRecording()
            }
        } else {
            NSLog("GIF recording requires macOS 13.0 or later")
        }
    }

    @available(macOS 13.0, *)
    private func startGIFRecording() {
        isRecordingGIF = true
        Task { @MainActor in
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(
                    false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    NSLog("No display found for GIF recording")
                    isRecordingGIF = false
                    return
                }
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let recorder = GIFRecorder()
                gifRecorder = recorder
                try await recorder.startRecording(filter: filter)
                NSLog("GIF recording started")
            } catch {
                NSLog("Failed to start GIF recording: %@", error.localizedDescription)
                isRecordingGIF = false
            }
        }
    }

    @available(macOS 13.0, *)
    private func stopGIFRecording() {
        guard let recorder = gifRecorder else { return }
        Task { @MainActor in
            do {
                let url = try await recorder.stopRecording()
                isRecordingGIF = false
                gifRecorder = nil
                NSLog("GIF recording saved to: %@", url.path)
                let thumbURL = HistoryStore.thumbnailsDirectory
                    .appendingPathComponent(UUID().uuidString + "_thumb.jpg")
                let capture = Capture(mode: .gif, filePath: url, thumbnailPath: thumbURL)
                try? await HistoryStore.shared.ingest(capture)
            } catch {
                NSLog("Failed to stop GIF recording: %@", error.localizedDescription)
                isRecordingGIF = false
                gifRecorder = nil
            }
        }
    }

    // MARK: - OCR trigger

    private func triggerOCR() {
        if #available(macOS 14.0, *) {
            Task { @MainActor in
                do {
                    let image = try await AreaCapture().capture()
                    let result = try await OCRService().recognize(image: image)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result.fullText, forType: .string)
                    NSLog("OCR complete — %d chars copied to clipboard", result.fullText.count)
                } catch {
                    NSLog("OCR failed: %@", error.localizedDescription)
                }
            }
        } else {
            NSLog("OCR capture requires macOS 14.0 or later")
        }
    }

    // MARK: - Save and show overlay

    @MainActor
    private func saveAndShowOverlay(image: CGImage, mode: CaptureMode) async {
        let settings = AppSettings.shared
        let ext = settings.defaultExportFormat.isEmpty ? "png" : settings.defaultExportFormat
        let filename = resolveFilename(pattern: settings.namingPattern, ext: ext)
        let fileURL = settings.resolvedSavePath.appendingPathComponent(filename)

        // Optionally hide desktop icons before writing
        let desktopMgr = DesktopManager()
        let shouldHide = settings.hideDesktopIconsOnCapture
        if shouldHide { try? desktopMgr.hideIcons() }

        // Write image to disk
        let saved = writeCGImage(image, to: fileURL, format: ext)

        if shouldHide { try? desktopMgr.showIcons() }

        guard saved else {
            NSLog("Failed to write capture to disk at: %@", fileURL.path)
            return
        }

        let thumbURL = HistoryStore.thumbnailsDirectory
            .appendingPathComponent(UUID().uuidString + "_thumb.jpg")
        writeThumbnail(from: image, to: thumbURL)
        let capture = Capture(mode: mode, filePath: fileURL, thumbnailPath: thumbURL)

        // Ingest into history
        try? await HistoryStore.shared.ingest(capture)

        // Show overlay
        overlayPanel?.show(capture: capture)
    }

    private func resolveFilename(pattern: String, ext: String) -> String {
        let now = Date()
        let cal = Calendar.current
        var name = pattern
        let replacements: [(String, String)] = [
            ("{yyyy}", String(cal.component(.year, from: now))),
            ("{MM}",   String(format: "%02d", cal.component(.month, from: now))),
            ("{dd}",   String(format: "%02d", cal.component(.day, from: now))),
            ("{HH}",   String(format: "%02d", cal.component(.hour, from: now))),
            ("{mm}",   String(format: "%02d", cal.component(.minute, from: now))),
            ("{ss}",   String(format: "%02d", cal.component(.second, from: now))),
            // common pattern: {yyyy-MM-dd}
            ("{yyyy-MM-dd}", {
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                return df.string(from: now)
            }()),
            ("{HH.mm.ss}", {
                let df = DateFormatter()
                df.dateFormat = "HH.mm.ss"
                return df.string(from: now)
            }()),
        ]
        for (token, value) in replacements {
            name = name.replacingOccurrences(of: token, with: value)
        }
        return "\(name).\(ext)"
    }

    private func writeCGImage(_ image: CGImage, to url: URL, format: String) -> Bool {
        let utType: CFString
        switch format.lowercased() {
        case "jpeg", "jpg": utType = "public.jpeg" as CFString
        case "tiff":        utType = "public.tiff" as CFString
        default:            utType = "public.png" as CFString
        }
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, utType, 1, nil) else {
            return false
        }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest)
    }

    private func writeThumbnail(from image: CGImage, to url: URL) {
        let maxDim = 240
        let scale = min(CGFloat(maxDim) / CGFloat(image.width),
                        CGFloat(maxDim) / CGFloat(image.height), 1.0)
        let w = Int(CGFloat(image.width) * scale)
        let h = Int(CGFloat(image.height) * scale)
        guard let ctx = CGContext(data: nil, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let finalThumb = ctx.makeImage() else { return }
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, finalThumb, [kCGImageDestinationLossyCompressionQuality: 0.7] as CFDictionary)
        _ = CGImageDestinationFinalize(dest)
    }

    // MARK: - Annotation editor

    private func openAnnotationEditor(for capture: Capture) {
        if let existing = annotationControllers[capture.id] {
            existing.showWindow(nil)
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }
        let controller = AnnotationWindowController(capture: capture)
        annotationControllers[capture.id] = controller
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification,
                                               object: controller.window,
                                               queue: .main) { [weak self] _ in
            self?.annotationControllers.removeValue(forKey: capture.id)
        }
        controller.showWindow(nil)
    }

    // MARK: - Overlay callbacks

    private func wireOverlayCallbacks() {
        guard let panel = overlayPanel else { return }

        panel.onAnnotate = { [weak self] capture in
            guard let self else { return }
            self.openAnnotationEditor(for: capture)
        }

        panel.onCopy = { capture in
            if let src = CGImageSourceCreateWithURL(capture.filePath as CFURL, nil),
               let img = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                let data = NSMutableData()
                if let dest = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) {
                    CGImageDestinationAddImage(dest, img, nil)
                    CGImageDestinationFinalize(dest)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setData(data as Data, forType: .png)
                }
            }
        }

        panel.onSave = { capture in
            let savePanel = NSSavePanel()
            savePanel.nameFieldStringValue = capture.filePath.lastPathComponent
            savePanel.allowedContentTypes = [.png, .jpeg, .tiff]
            savePanel.begin { response in
                guard response == .OK, let dest = savePanel.url else { return }
                try? FileManager.default.copyItem(at: capture.filePath, to: dest)
            }
        }

        panel.onPin = { [weak self] capture in
            guard let self else { return }
            let floater = FloatingScreenshotPanel(capture: capture)
            self.floatingPanels.append(floater)
        }

        panel.onOCR = { capture in
            Task {
                guard
                    let src = CGImageSourceCreateWithURL(capture.filePath as CFURL, nil),
                    let img = CGImageSourceCreateImageAtIndex(src, 0, nil)
                else { return }
                do {
                    let result = try await OCRService().recognize(image: img)
                    await MainActor.run {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(result.fullText, forType: .string)
                        NSLog("OCR complete — %d chars copied to clipboard", result.fullText.count)
                    }
                } catch {
                    NSLog("OCR on capture failed: %@", error.localizedDescription)
                }
            }
        }

        panel.onDelete = { capture in
            Task {
                try? await HistoryStore.shared.delete(capture.id)
            }
        }
    }

    // MARK: - History panel

    private func showHistoryPanel() {
        if let controller = historyPanelController {
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 500),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Capture History"
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let historyView = HistoryPanelView(
            onOpen: { [weak self] capture in
                guard let self else { return }
                self.openAnnotationEditor(for: capture)
            },
            onPin: { [weak self] capture in
                guard let self else { return }
                let floater = FloatingScreenshotPanel(capture: capture)
                self.floatingPanels.append(floater)
            }
        )
        panel.contentView = NSHostingView(rootView: historyView)
        panel.center()

        let controller = NSWindowController(window: panel)
        historyPanelController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
