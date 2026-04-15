import AppKit
import Foundation

public final class DesktopManager {
    private var savedWallpapers: [String: URL] = [:]  // screen localizedName → URL

    public init() {}

    /// Hides all Finder desktop icons.
    public func hideIcons() throws {
        try shell("defaults write com.apple.finder CreateDesktop -bool false")
        try shell("killall Finder")
    }

    /// Shows Finder desktop icons (restores previous state).
    public func showIcons() throws {
        try shell("defaults write com.apple.finder CreateDesktop -bool true")
        try shell("killall Finder")
    }

    /// Saves current wallpaper and sets a new one for the given screen.
    public func saveAndSetWallpaper(_ newURL: URL, on screen: NSScreen) throws {
        if let current = NSWorkspace.shared.desktopImageURL(for: screen) {
            savedWallpapers[screen.localizedName] = current
        }
        try NSWorkspace.shared.setDesktopImageURL(newURL, for: screen, options: [:])
    }

    /// Restores the previously saved wallpaper for the given screen.
    public func restoreWallpaper(on screen: NSScreen) throws {
        guard let saved = savedWallpapers[screen.localizedName] else { return }
        try NSWorkspace.shared.setDesktopImageURL(saved, for: screen, options: [:])
        savedWallpapers.removeValue(forKey: screen.localizedName)
    }

    // MARK: - Private

    @discardableResult
    private func shell(_ command: String) throws -> String {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        try task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                                encoding: .utf8) ?? ""
            throw DesktopManagerError.shellFailed(output)
        }
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                      encoding: .utf8) ?? ""
    }
}

public enum DesktopManagerError: Error {
    case shellFailed(String)
}
