import Foundation
import AppKit
import SwiftUI

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("defaultExportFormat") var defaultExportFormat: String = "png"
    @AppStorage("defaultSavePath") var defaultSavePath: String = ""
    @AppStorage("namingPattern") var namingPattern: String = "Screenshot {yyyy-MM-dd} at {HH.mm.ss}"
    @AppStorage("overlayDismissTimeout") var overlayDismissTimeout: Double = 5.0
    @AppStorage("historyRetentionDays") var historyRetentionDays: Int = 30
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("hideDesktopIconsOnCapture") var hideDesktopIconsOnCapture: Bool = false
    @AppStorage("showMouseClicks") var showMouseClicks: Bool = false
    @AppStorage("showKeystrokes") var showKeystrokes: Bool = false
    @AppStorage("captureDropShadow") var captureDropShadow: Bool = true
    @AppStorage("recordingFPS") var recordingFPS: Int = 30
    @AppStorage("recordMicrophone") var recordMicrophone: Bool = false
    @AppStorage("recordSystemAudio") var recordSystemAudio: Bool = true

    var resolvedSavePath: URL {
        if defaultSavePath.isEmpty {
            return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        }
        return URL(fileURLWithPath: defaultSavePath)
    }
}
