import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let captureArea       = Self("captureArea",       default: nil)
    static let captureWindow     = Self("captureWindow",     default: nil)
    static let captureFullscreen = Self("captureFullscreen", default: nil)
    static let captureScrolling  = Self("captureScrolling",  default: nil)
    static let recordScreen      = Self("recordScreen",      default: nil)
    static let recordGIF         = Self("recordGIF",         default: nil)
    static let captureOCR        = Self("captureOCR",        default: nil)
    static let retakeLastCapture = Self("retakeLastCapture", default: nil)
}

struct ShortcutsPrefsView: View {
    var body: some View {
        Form {
            Section("Screenshots") {
                KeyboardShortcuts.Recorder("Capture Area",        name: .captureArea)
                KeyboardShortcuts.Recorder("Capture Window",      name: .captureWindow)
                KeyboardShortcuts.Recorder("Capture Fullscreen",  name: .captureFullscreen)
                KeyboardShortcuts.Recorder("Scrolling Capture",   name: .captureScrolling)
                KeyboardShortcuts.Recorder("Retake Last Capture", name: .retakeLastCapture)
            }
            Section("Recording") {
                KeyboardShortcuts.Recorder("Record Screen", name: .recordScreen)
                KeyboardShortcuts.Recorder("Record GIF",    name: .recordGIF)
            }
            Section("Tools") {
                KeyboardShortcuts.Recorder("OCR Text", name: .captureOCR)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
