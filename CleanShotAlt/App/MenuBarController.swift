import AppKit

final class MenuBarController {
    private var statusItem: NSStatusItem!

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera.on.rectangle",
                                   accessibilityDescription: "CleanShotAlt")
        }
        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.addItem(makeItem("Capture Area",        action: #selector(captureArea)))
        menu.addItem(makeItem("Capture Window",      action: #selector(captureWindow)))
        menu.addItem(makeItem("Capture Fullscreen",  action: #selector(captureFullscreen)))
        menu.addItem(makeItem("Scrolling Capture",   action: #selector(captureScrolling)))
        menu.addItem(.separator())
        menu.addItem(makeItem("Record Screen",       action: #selector(recordScreen)))
        menu.addItem(makeItem("Record GIF",          action: #selector(recordGIF)))
        menu.addItem(.separator())
        menu.addItem(makeItem("History",             action: #selector(showHistory)))
        menu.addItem(makeItem("OCR Text",            action: #selector(ocrText)))
        menu.addItem(.separator())
        menu.addItem(makeItem("Preferences…",        action: #selector(openPreferences), key: ","))
        menu.addItem(makeItem("Quit",                action: #selector(NSApplication.terminate(_:)), key: "q"))
        statusItem.menu = menu
    }

    private func makeItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    // Stubs — wired up fully in Task 18
    @objc private func captureArea()       { NotificationCenter.default.post(name: .captureArea, object: nil) }
    @objc private func captureWindow()     { NotificationCenter.default.post(name: .captureWindow, object: nil) }
    @objc private func captureFullscreen() { NotificationCenter.default.post(name: .captureFullscreen, object: nil) }
    @objc private func captureScrolling()  { NotificationCenter.default.post(name: .captureScrolling, object: nil) }
    @objc private func recordScreen()      { NotificationCenter.default.post(name: .recordScreen, object: nil) }
    @objc private func recordGIF()         { NotificationCenter.default.post(name: .recordGIF, object: nil) }
    @objc private func showHistory()       { NotificationCenter.default.post(name: .showHistory, object: nil) }
    @objc private func ocrText()           { NotificationCenter.default.post(name: .ocrText, object: nil) }
    @objc private func openPreferences()   {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension Notification.Name {
    static let captureArea       = Notification.Name("captureArea")
    static let captureWindow     = Notification.Name("captureWindow")
    static let captureFullscreen = Notification.Name("captureFullscreen")
    static let captureScrolling  = Notification.Name("captureScrolling")
    static let recordScreen      = Notification.Name("recordScreen")
    static let recordGIF         = Notification.Name("recordGIF")
    static let showHistory       = Notification.Name("showHistory")
    static let ocrText           = Notification.Name("ocrText")
}
