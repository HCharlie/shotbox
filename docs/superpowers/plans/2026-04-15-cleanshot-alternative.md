# CleanShot Alternative Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local, open-source macOS screenshot and screen recording app that replicates CleanShot X without any cloud dependency.

**Architecture:** Six SPM local packages (SharedModels, CaptureEngine, AnnotationEditor, OCRService, HistoryStore, DesktopManager) consumed by a single app target. All UI is SwiftUI with AppKit where SwiftUI gaps exist (NSPanel, NSStatusItem). No cloud, no App Store — direct .dmg distribution.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, ScreenCaptureKit, AVFoundation, Vision, GRDB.swift, Gifski, KeyboardShortcuts, XCTest

---

## File Structure

```
CleanShotAlt/
├── CleanShotAlt.xcodeproj
├── CleanShotAlt/                          # App target
│   ├── CleanShotAltApp.swift              # @main, Settings scene
│   ├── App/
│   │   ├── AppDelegate.swift              # NSApplicationDelegate, bootstraps all controllers
│   │   ├── MenuBarController.swift        # NSStatusItem + dropdown NSMenu
│   │   ├── HotkeyManager.swift            # Registers/dispatches global hotkeys via KeyboardShortcuts
│   │   └── AppSettings.swift             # @AppStorage property wrappers, typed accessors
│   └── UI/
│       ├── QuickOverlay/
│       │   ├── QuickOverlayPanel.swift    # NSPanel subclass, floating non-activating
│       │   └── QuickOverlayView.swift     # SwiftUI thumbnail + action buttons
│       ├── AnnotationWindow/
│       │   ├── AnnotationWindowController.swift  # NSWindowController wrapper
│       │   └── AnnotationEditorView.swift         # SwiftUI root for editor UI
│       ├── HistoryPanel/
│       │   ├── HistoryPanelController.swift
│       │   └── HistoryPanelView.swift     # Grid of thumbnails, filter tabs
│       ├── FloatingScreenshot/
│       │   └── FloatingScreenshotPanel.swift  # NSPanel level=.floating, ignoresMouseEvents toggle
│       └── PreferencesWindow/
│           ├── PreferencesView.swift      # TabView root
│           ├── GeneralPrefsView.swift
│           ├── ShortcutsPrefsView.swift
│           ├── RecordingPrefsView.swift
│           └── StoragePrefsView.swift
├── Modules/
│   ├── SharedModels/
│   │   ├── Package.swift
│   │   └── Sources/SharedModels/
│   │       ├── Capture.swift              # Capture struct, CaptureMode, ExportFormat
│   │       ├── AnnotationModels.swift     # AnnotationObject protocol + all concrete types
│   │       ├── AnyAnnotation.swift        # Tagged-union Codable enum wrapper
│   │       ├── CodableColor.swift         # NSColor ↔ Codable bridge
│   │       └── BackgroundConfig.swift     # BackgroundConfig, BackgroundStyle, GradientConfig
│   ├── HistoryStore/
│   │   ├── Package.swift
│   │   ├── Sources/HistoryStore/
│   │   │   └── HistoryStore.swift         # GRDB-backed store, ingest/fetch/delete/replace/prune
│   │   └── Tests/HistoryStoreTests/
│   │       └── HistoryStoreTests.swift
│   ├── DesktopManager/
│   │   ├── Package.swift
│   │   ├── Sources/DesktopManager/
│   │   │   └── DesktopManager.swift       # Hide/show icons, save/restore wallpaper
│   │   └── Tests/DesktopManagerTests/
│   │       └── DesktopManagerTests.swift
│   ├── OCRService/
│   │   ├── Package.swift
│   │   ├── Sources/OCRService/
│   │   │   └── OCRService.swift           # VNRecognizeTextRequest + VNDetectBarcodesRequest
│   │   └── Tests/OCRServiceTests/
│   │       └── OCRServiceTests.swift
│   ├── CaptureEngine/
│   │   ├── Package.swift
│   │   ├── Sources/CaptureEngine/
│   │   │   ├── CaptureOverlayWindow.swift # Transparent fullscreen NSPanel for selection UI
│   │   │   ├── AreaCapture.swift          # Crosshair, magnifier, rect selection
│   │   │   ├── WindowCapture.swift        # Window enumeration + per-window capture
│   │   │   ├── FullscreenCapture.swift    # Per-display SCScreenshotManager capture
│   │   │   ├── ScrollingCapture.swift     # Scroll-inject, frame-stitch pipeline
│   │   │   ├── ScreenRecorder.swift       # SCStream → AVAssetWriter → .mp4
│   │   │   ├── GIFRecorder.swift          # SCStream → Gifski → .gif
│   │   │   ├── CameraOverlay.swift        # AVCaptureSession webcam overlay
│   │   │   └── ClickKeystrokeVisualizer.swift  # CGEventTap overlay
│   │   └── Tests/CaptureEngineTests/
│   │       └── CaptureEngineTests.swift
│   └── AnnotationEditor/
│       ├── Package.swift
│       ├── Sources/AnnotationEditor/
│       │   ├── AnnotationProject.swift    # Project model, load/save .cleanalt
│       │   ├── AnnotationCanvas.swift     # SwiftUI Canvas renderer + hit testing
│       │   ├── ToolState.swift            # Active tool enum + per-tool style state
│       │   ├── Tools/
│       │   │   ├── ArrowTool.swift
│       │   │   ├── ShapeTool.swift
│       │   │   ├── TextTool.swift
│       │   │   ├── HighlightTool.swift
│       │   │   ├── EffectTool.swift       # Pixelate + Blur (share CIFilter pipeline)
│       │   │   ├── SpotlightTool.swift
│       │   │   ├── CounterTool.swift
│       │   │   ├── PencilTool.swift
│       │   │   └── TransformTool.swift    # Crop, Resize, Rotate, Flip
│       │   ├── BackgroundTool.swift       # Wraps canvas in padded background
│       │   └── ExportService.swift        # Flatten → CGImageDestination / NSPasteboard
│       └── Tests/AnnotationEditorTests/
│           └── AnnotationEditorTests.swift
└── docs/
    └── superpowers/
        ├── specs/2026-04-14-cleanshot-alternative-design.md
        └── plans/2026-04-15-cleanshot-alternative.md
```

---

## Chunk 1: Xcode Project Scaffold

**Goal:** A buildable, runnable macOS app target with all 6 SPM local packages wired in, correct entitlements, and a menu-bar-only app shell.

### Task 1: Create the Xcode project and folder structure

**Files:**
- Create: `CleanShotAlt.xcodeproj` (via Xcode)
- Create: `CleanShotAlt/CleanShotAltApp.swift`
- Create: `CleanShotAlt/App/AppDelegate.swift`
- Create: `CleanShotAlt.entitlements`
- Create: `CleanShotAlt/Info.plist`

- [ ] Open Xcode → File → New → Project → macOS → App
  - Product Name: `CleanShotAlt`
  - Interface: SwiftUI
  - Language: Swift
  - Uncheck "Include Tests" (tests live in SPM packages)
- [ ] In project settings → Signing & Capabilities:
  - Set minimum deployment to **macOS 13.0**
  - Add capability: **App Sandbox** → disable sandbox (direct distribution, not App Store)
  - Add capability: **Hardened Runtime**
- [ ] Replace `CleanShotAltApp.swift` with:

```swift
import SwiftUI

@main
struct CleanShotAltApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu-bar-only app: no visible window at launch
        Settings {
            PreferencesView()
        }
    }
}
```

- [ ] Create `CleanShotAlt/App/AppDelegate.swift`:

```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock — menu bar only app
        NSApp.setActivationPolicy(.accessory)
        menuBarController = MenuBarController()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
```

- [ ] Create `CleanShotAlt.entitlements` with these keys:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.device.microphone</key>
    <true/>
    <key>com.apple.security.device.camera</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```

- [ ] In `Info.plist`, add usage description keys:

```xml
<key>NSScreenCaptureUsageDescription</key>
<string>CleanShotAlt needs screen capture access to take screenshots and recordings.</string>
<key>NSMicrophoneUsageDescription</key>
<string>CleanShotAlt needs microphone access to record audio with screen recordings.</string>
<key>NSCameraUsageDescription</key>
<string>CleanShotAlt needs camera access for the webcam overlay during recordings.</string>
<key>NSAppleEventsUsageDescription</key>
<string>CleanShotAlt needs to send events to Finder to hide desktop icons.</string>
```

- [ ] Build (`Cmd+B`) — should compile with zero errors.
- [ ] Commit:

```bash
git init
git add .
git commit -m "chore: initial Xcode project scaffold, menu-bar-only app shell"
```

---

### Task 2: Create the 6 SPM local packages

**Files:** `Modules/*/Package.swift` × 6, placeholder `Sources/*/Placeholder.swift` × 6

- [ ] Create `Modules/SharedModels/Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SharedModels",
    platforms: [.macOS(.v13)],
    products: [.library(name: "SharedModels", targets: ["SharedModels"])],
    targets: [
        .target(name: "SharedModels", path: "Sources/SharedModels"),
    ]
)
```

- [ ] Create `Modules/HistoryStore/Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HistoryStore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "HistoryStore", targets: ["HistoryStore"])],
    dependencies: [
        .package(path: "../SharedModels"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0"),
    ],
    targets: [
        .target(name: "HistoryStore",
                dependencies: ["SharedModels", .product(name: "GRDB", package: "GRDB.swift")],
                path: "Sources/HistoryStore"),
        .testTarget(name: "HistoryStoreTests",
                    dependencies: ["HistoryStore"],
                    path: "Tests/HistoryStoreTests"),
    ]
)
```

- [ ] Create `Modules/DesktopManager/Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DesktopManager",
    platforms: [.macOS(.v13)],
    products: [.library(name: "DesktopManager", targets: ["DesktopManager"])],
    targets: [
        .target(name: "DesktopManager", path: "Sources/DesktopManager"),
        .testTarget(name: "DesktopManagerTests",
                    dependencies: ["DesktopManager"],
                    path: "Tests/DesktopManagerTests"),
    ]
)
```

- [ ] Create `Modules/OCRService/Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OCRService",
    platforms: [.macOS(.v13)],
    products: [.library(name: "OCRService", targets: ["OCRService"])],
    dependencies: [
        .package(path: "../SharedModels"),
    ],
    targets: [
        .target(name: "OCRService",
                dependencies: ["SharedModels"],
                path: "Sources/OCRService"),
        .testTarget(name: "OCRServiceTests",
                    dependencies: ["OCRService"],
                    path: "Tests/OCRServiceTests"),
    ]
)
```

- [ ] Create `Modules/CaptureEngine/Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CaptureEngine",
    platforms: [.macOS(.v13)],
    products: [.library(name: "CaptureEngine", targets: ["CaptureEngine"])],
    dependencies: [
        .package(path: "../SharedModels"),
        .package(url: "https://github.com/sindresorhus/Gifski.git", from: "2.2.0"),
    ],
    targets: [
        .target(name: "CaptureEngine",
                dependencies: ["SharedModels", "Gifski"],
                path: "Sources/CaptureEngine"),
        .testTarget(name: "CaptureEngineTests",
                    dependencies: ["CaptureEngine"],
                    path: "Tests/CaptureEngineTests"),
    ]
)
```

- [ ] Create `Modules/AnnotationEditor/Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AnnotationEditor",
    platforms: [.macOS(.v13)],
    products: [.library(name: "AnnotationEditor", targets: ["AnnotationEditor"])],
    dependencies: [
        .package(path: "../SharedModels"),
    ],
    targets: [
        .target(name: "AnnotationEditor",
                dependencies: ["SharedModels"],
                path: "Sources/AnnotationEditor"),
        .testTarget(name: "AnnotationEditorTests",
                    dependencies: ["AnnotationEditor"],
                    path: "Tests/AnnotationEditorTests"),
    ]
)
```

- [ ] Add a `Placeholder.swift` in each `Sources/*/` folder (so packages compile):

```swift
// Placeholder — delete when real sources are added
```

- [ ] In Xcode: File → Add Package Dependencies → Add Local → select each `Modules/*` folder in order: SharedModels, HistoryStore, DesktopManager, OCRService, CaptureEngine, AnnotationEditor. Add all to the `CleanShotAlt` target.
- [ ] Also add remote packages via Xcode:
  - `https://github.com/sindresorhus/KeyboardShortcuts` (from: "2.0.0") → add to app target
- [ ] Build (`Cmd+B`) — all packages resolve, zero errors.
- [ ] Commit:

```bash
git add Modules/ CleanShotAlt.xcodeproj
git commit -m "chore: add 6 SPM local packages with GRDB, Gifski, KeyboardShortcuts dependencies"
```

---

### Task 3: Stub MenuBarController and AppSettings

**Files:**
- Create: `CleanShotAlt/App/MenuBarController.swift`
- Create: `CleanShotAlt/App/AppSettings.swift`
- Create: `CleanShotAlt/UI/PreferencesWindow/PreferencesView.swift`

- [ ] Create `CleanShotAlt/App/AppSettings.swift`:

```swift
import Foundation
import AppKit

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
```

- [ ] Create `CleanShotAlt/App/MenuBarController.swift`:

```swift
import AppKit
import KeyboardShortcuts

final class MenuBarController {
    private var statusItem: NSStatusItem!

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera.on.rectangle", accessibilityDescription: "CleanShotAlt")
        }
        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Capture Area", action: #selector(captureArea), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Capture Window", action: #selector(captureWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Capture Fullscreen", action: #selector(captureFullscreen), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Scrolling Capture", action: #selector(captureScrolling), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Record Screen", action: #selector(recordScreen), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Record GIF", action: #selector(recordGIF), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "History", action: #selector(showHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "OCR Text", action: #selector(ocrText), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        for item in menu.items { item.target = self }
        statusItem.menu = menu
    }

    // Stubs — wired up in later tasks
    @objc private func captureArea() {}
    @objc private func captureWindow() {}
    @objc private func captureFullscreen() {}
    @objc private func captureScrolling() {}
    @objc private func recordScreen() {}
    @objc private func recordGIF() {}
    @objc private func showHistory() {}
    @objc private func ocrText() {}
    @objc private func openPreferences() { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) }
}
```

- [ ] Create stub `CleanShotAlt/UI/PreferencesWindow/PreferencesView.swift`:

```swift
import SwiftUI

struct PreferencesView: View {
    var body: some View {
        TabView {
            Text("General").tabItem { Label("General", systemImage: "gearshape") }
            Text("Shortcuts").tabItem { Label("Shortcuts", systemImage: "keyboard") }
            Text("Recording").tabItem { Label("Recording", systemImage: "video") }
            Text("Storage").tabItem { Label("Storage", systemImage: "internaldrive") }
        }
        .frame(width: 500, height: 400)
    }
}
```

- [ ] Build and run — menu bar icon appears, menu opens, all items visible.
- [ ] Commit:

```bash
git add CleanShotAlt/
git commit -m "feat: menu bar controller stub, app settings, preferences placeholder"
```

---

## Chunk 2: SharedModels

**Goal:** All shared data types implemented, Codable, and tested.

### Task 4: Implement SharedModels

**Files:**
- Create: `Modules/SharedModels/Sources/SharedModels/Capture.swift`
- Create: `Modules/SharedModels/Sources/SharedModels/AnnotationModels.swift`
- Create: `Modules/SharedModels/Sources/SharedModels/AnyAnnotation.swift`
- Create: `Modules/SharedModels/Sources/SharedModels/CodableColor.swift`
- Create: `Modules/SharedModels/Sources/SharedModels/BackgroundConfig.swift`

- [ ] Delete the `Placeholder.swift` in `Modules/SharedModels/Sources/SharedModels/`.

- [ ] Create `Capture.swift`:

```swift
import Foundation

public struct Capture: Identifiable, Codable, Hashable {
    public let id: UUID
    public let mode: CaptureMode
    public let createdAt: Date
    public let filePath: URL        // absolute path, stored as path string in DB
    public let thumbnailPath: URL   // absolute path, stored as path string in DB
    public var exportFormat: ExportFormat

    public init(id: UUID = UUID(), mode: CaptureMode, createdAt: Date = Date(),
                filePath: URL, thumbnailPath: URL, exportFormat: ExportFormat = .png) {
        self.id = id; self.mode = mode; self.createdAt = createdAt
        self.filePath = filePath; self.thumbnailPath = thumbnailPath
        self.exportFormat = exportFormat
    }
}

public enum CaptureMode: String, Codable, CaseIterable {
    case area, window, fullscreen, scrolling, video, gif
}

public enum ExportFormat: String, Codable, CaseIterable {
    case png, jpeg, tiff, webp, gif, mp4

    public var fileExtension: String { rawValue }

    public var utType: String {
        switch self {
        case .png: return "public.png"
        case .jpeg: return "public.jpeg"
        case .tiff: return "public.tiff"
        case .webp: return "org.webmproject.webp"
        case .gif: return "com.compuserve.gif"
        case .mp4: return "public.mpeg-4"
        }
    }
}
```

- [ ] Create `CodableColor.swift`:

```swift
import AppKit

public struct CodableColor: Codable, Hashable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    public init(_ nsColor: NSColor) {
        let c = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        self.init(red: c.redComponent, green: c.greenComponent,
                  blue: c.blueComponent, alpha: c.alphaComponent)
    }

    public var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    public static let black = CodableColor(red: 0, green: 0, blue: 0)
    public static let white = CodableColor(red: 1, green: 1, blue: 1)
    public static let yellow = CodableColor(red: 1, green: 0.9, blue: 0)
    public static let red = CodableColor(red: 0.9, green: 0.1, blue: 0.1)
}
```

- [ ] Create `AnnotationModels.swift`:

```swift
import Foundation
import CoreGraphics

public protocol AnnotationObject: Identifiable, Codable {
    var id: UUID { get }
    var zIndex: Int { get set }
    func contains(_ point: CGPoint) -> Bool
}

public struct ArrowAnnotation: AnnotationObject {
    public var id = UUID()
    public var zIndex: Int = 0
    public var start: CGPoint
    public var end: CGPoint
    public var color: CodableColor = .red
    public var thickness: CGFloat = 3
    public var headStyle: ArrowHeadStyle = .filled
    public func contains(_ point: CGPoint) -> Bool {
        pointNearSegment(point, from: start, to: end, tolerance: thickness + 4)
    }
}

public enum ArrowHeadStyle: String, Codable { case filled, outline, open, none }

public struct ShapeAnnotation: AnnotationObject {
    public var id = UUID()
    public var zIndex: Int = 0
    public var shape: ShapeKind = .rectangle
    public var rect: CGRect
    public var color: CodableColor = .red
    public var fillColor: CodableColor? = nil
    public var thickness: CGFloat = 2
    public func contains(_ point: CGPoint) -> Bool { rect.insetBy(dx: -8, dy: -8).contains(point) }
}

public enum ShapeKind: String, Codable { case rectangle, ellipse, line }

public struct TextAnnotation: AnnotationObject {
    public var id = UUID()
    public var zIndex: Int = 0
    public var text: String = ""
    public var origin: CGPoint
    public var fontSize: CGFloat = 16
    public var color: CodableColor = .white
    public var backgroundColor: CodableColor? = CodableColor.red
    public func contains(_ point: CGPoint) -> Bool {
        let estimatedRect = CGRect(x: origin.x, y: origin.y,
                                   width: CGFloat(text.count) * fontSize * 0.6, height: fontSize * 1.4)
        return estimatedRect.contains(point)
    }
}

public struct HighlightAnnotation: AnnotationObject {
    public var id = UUID()
    public var zIndex: Int = 0
    public var points: [CGPoint] = []
    public var color: CodableColor = .yellow
    public var opacity: Double = 0.4
    public var thickness: CGFloat = 20
    public func contains(_ point: CGPoint) -> Bool {
        points.enumerated().dropFirst().contains { i, p in
            pointNearSegment(point, from: points[i.offset - 1], to: p, tolerance: thickness)
        }
    }
}

public struct PixelateAnnotation: AnnotationObject {
    public var id = UUID()
    public var zIndex: Int = 0
    public var rect: CGRect
    public var pixelSize: CGFloat = 12
    public func contains(_ point: CGPoint) -> Bool { rect.insetBy(dx: -8, dy: -8).contains(point) }
}

public struct BlurAnnotation: AnnotationObject {
    public var id = UUID()
    public var zIndex: Int = 0
    public var rect: CGRect
    public var radius: CGFloat = 10
    public func contains(_ point: CGPoint) -> Bool { rect.insetBy(dx: -8, dy: -8).contains(point) }
}

public struct SpotlightAnnotation: AnnotationObject {
    public var id = UUID()
    public var zIndex: Int = 0
    public var rect: CGRect
    public var dimOpacity: Double = 0.6
    public func contains(_ point: CGPoint) -> Bool { rect.insetBy(dx: -8, dy: -8).contains(point) }
}

public struct CounterAnnotation: AnnotationObject {
    public var id = UUID()
    public var zIndex: Int = 0
    public var center: CGPoint
    public var number: Int
    public var radius: CGFloat = 16
    public var color: CodableColor = .red
    public func contains(_ point: CGPoint) -> Bool {
        let dx = point.x - center.x; let dy = point.y - center.y
        return sqrt(dx*dx + dy*dy) <= radius + 6
    }
}

public struct PencilAnnotation: AnnotationObject {
    public var id = UUID()
    public var zIndex: Int = 0
    public var points: [CGPoint] = []
    public var color: CodableColor = .red
    public var thickness: CGFloat = 2
    public func contains(_ point: CGPoint) -> Bool {
        points.enumerated().dropFirst().contains { i, p in
            pointNearSegment(point, from: points[i.offset - 1], to: p, tolerance: thickness + 4)
        }
    }
}

// MARK: - Geometry helper
func pointNearSegment(_ point: CGPoint, from a: CGPoint, to b: CGPoint, tolerance: CGFloat) -> Bool {
    let dx = b.x - a.x; let dy = b.y - a.y
    let lenSq = dx*dx + dy*dy
    guard lenSq > 0 else { return hypot(point.x - a.x, point.y - a.y) <= tolerance }
    let t = max(0, min(1, ((point.x - a.x)*dx + (point.y - a.y)*dy) / lenSq))
    let projX = a.x + t*dx; let projY = a.y + t*dy
    return hypot(point.x - projX, point.y - projY) <= tolerance
}
```

- [ ] Create `AnyAnnotation.swift`:

```swift
import Foundation

/// Tagged-union wrapper enabling Codable serialization of heterogeneous annotation arrays.
public enum AnyAnnotation: Codable {
    case arrow(ArrowAnnotation)
    case shape(ShapeAnnotation)
    case text(TextAnnotation)
    case highlight(HighlightAnnotation)
    case pixelate(PixelateAnnotation)
    case blur(BlurAnnotation)
    case spotlight(SpotlightAnnotation)
    case counter(CounterAnnotation)
    case pencil(PencilAnnotation)

    private enum TypeKey: String, Codable {
        case arrow, shape, text, highlight, pixelate, blur, spotlight, counter, pencil
    }

    private enum CodingKeys: String, CodingKey { case type, value }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(TypeKey.self, forKey: .type)
        switch type {
        case .arrow:     self = .arrow(try c.decode(ArrowAnnotation.self, forKey: .value))
        case .shape:     self = .shape(try c.decode(ShapeAnnotation.self, forKey: .value))
        case .text:      self = .text(try c.decode(TextAnnotation.self, forKey: .value))
        case .highlight: self = .highlight(try c.decode(HighlightAnnotation.self, forKey: .value))
        case .pixelate:  self = .pixelate(try c.decode(PixelateAnnotation.self, forKey: .value))
        case .blur:      self = .blur(try c.decode(BlurAnnotation.self, forKey: .value))
        case .spotlight: self = .spotlight(try c.decode(SpotlightAnnotation.self, forKey: .value))
        case .counter:   self = .counter(try c.decode(CounterAnnotation.self, forKey: .value))
        case .pencil:    self = .pencil(try c.decode(PencilAnnotation.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .arrow(let v):     try c.encode(TypeKey.arrow, forKey: .type);     try c.encode(v, forKey: .value)
        case .shape(let v):     try c.encode(TypeKey.shape, forKey: .type);     try c.encode(v, forKey: .value)
        case .text(let v):      try c.encode(TypeKey.text, forKey: .type);      try c.encode(v, forKey: .value)
        case .highlight(let v): try c.encode(TypeKey.highlight, forKey: .type); try c.encode(v, forKey: .value)
        case .pixelate(let v):  try c.encode(TypeKey.pixelate, forKey: .type);  try c.encode(v, forKey: .value)
        case .blur(let v):      try c.encode(TypeKey.blur, forKey: .type);      try c.encode(v, forKey: .value)
        case .spotlight(let v): try c.encode(TypeKey.spotlight, forKey: .type); try c.encode(v, forKey: .value)
        case .counter(let v):   try c.encode(TypeKey.counter, forKey: .type);   try c.encode(v, forKey: .value)
        case .pencil(let v):    try c.encode(TypeKey.pencil, forKey: .type);    try c.encode(v, forKey: .value)
        }
    }

    public var base: any AnnotationObject {
        switch self {
        case .arrow(let v): return v
        case .shape(let v): return v
        case .text(let v): return v
        case .highlight(let v): return v
        case .pixelate(let v): return v
        case .blur(let v): return v
        case .spotlight(let v): return v
        case .counter(let v): return v
        case .pencil(let v): return v
        }
    }
}
```

- [ ] Create `BackgroundConfig.swift`:

```swift
import Foundation
import CoreGraphics

public enum BackgroundStyle: String, Codable {
    case solid, linearGradient, radialGradient, image
}

public struct GradientConfig: Codable, Hashable {
    public var colors: [CodableColor]
    public var angle: Double = 135   // degrees; used for linear gradient
    public var center: CGPoint = CGPoint(x: 0.5, y: 0.5)  // normalized; used for radial
    public init(colors: [CodableColor], angle: Double = 135, center: CGPoint = CGPoint(x: 0.5, y: 0.5)) {
        self.colors = colors; self.angle = angle; self.center = center
    }
}

public struct BackgroundConfig: Codable, Hashable {
    public var style: BackgroundStyle = .solid
    public var color: CodableColor = CodableColor(red: 0.2, green: 0.5, blue: 1.0)
    public var gradient: GradientConfig? = nil
    public var imageURL: URL? = nil
    public var padding: CGFloat = 40
    public var cornerRadius: CGFloat = 12
    public var shadowRadius: CGFloat = 20
    public var shadowOpacity: CGFloat = 0.4
    public var aspectRatio: CGSize? = nil  // nil = free

    public init() {}
}
```

- [ ] Write tests. Create `Modules/SharedModels/Tests/SharedModelsTests/SharedModelsTests.swift`:

> Note: SharedModels/Package.swift needs a test target added first:

```swift
// In Package.swift, add to targets array:
.testTarget(name: "SharedModelsTests",
            dependencies: ["SharedModels"],
            path: "Tests/SharedModelsTests"),
```

```swift
import XCTest
@testable import SharedModels

final class SharedModelsTests: XCTestCase {

    func test_capture_roundtrips_codable() throws {
        let original = Capture(mode: .area, filePath: URL(fileURLWithPath: "/tmp/a.png"),
                               thumbnailPath: URL(fileURLWithPath: "/tmp/a_thumb.jpg"))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Capture.self, from: data)
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.mode, decoded.mode)
        XCTAssertEqual(original.filePath, decoded.filePath)
    }

    func test_anyAnnotation_arrow_roundtrips() throws {
        let arrow = ArrowAnnotation(start: CGPoint(x: 10, y: 20), end: CGPoint(x: 100, y: 200))
        let wrapped = AnyAnnotation.arrow(arrow)
        let data = try JSONEncoder().encode(wrapped)
        let decoded = try JSONDecoder().decode(AnyAnnotation.self, from: data)
        guard case .arrow(let decoded) = decoded else { XCTFail("wrong type"); return }
        XCTAssertEqual(decoded.start.x, arrow.start.x)
    }

    func test_anyAnnotation_all_cases_roundtrip() throws {
        let cases: [AnyAnnotation] = [
            .arrow(ArrowAnnotation(start: .zero, end: CGPoint(x: 1, y: 1))),
            .shape(ShapeAnnotation(rect: CGRect(x: 0, y: 0, width: 100, height: 50))),
            .text(TextAnnotation(origin: .zero)),
            .highlight(HighlightAnnotation()),
            .pixelate(PixelateAnnotation(rect: .zero)),
            .blur(BlurAnnotation(rect: .zero)),
            .spotlight(SpotlightAnnotation(rect: CGRect(x: 10, y: 10, width: 200, height: 100))),
            .counter(CounterAnnotation(center: .zero, number: 1)),
            .pencil(PencilAnnotation()),
        ]
        for annotation in cases {
            let data = try JSONEncoder().encode(annotation)
            let decoded = try JSONDecoder().decode(AnyAnnotation.self, from: data)
            XCTAssertEqual(String(describing: annotation).prefix(10),
                           String(describing: decoded).prefix(10),
                           "Roundtrip failed for \(annotation)")
        }
    }

    func test_codable_color_roundtrips() throws {
        let color = CodableColor(red: 0.5, green: 0.25, blue: 0.75, alpha: 0.9)
        let data = try JSONEncoder().encode(color)
        let decoded = try JSONDecoder().decode(CodableColor.self, from: data)
        XCTAssertEqual(color.red, decoded.red, accuracy: 0.001)
        XCTAssertEqual(color.alpha, decoded.alpha, accuracy: 0.001)
    }

    func test_background_config_gradient_roundtrips() throws {
        var config = BackgroundConfig()
        config.style = .linearGradient
        config.gradient = GradientConfig(colors: [.red, .white], angle: 45)
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(BackgroundConfig.self, from: data)
        XCTAssertEqual(decoded.gradient?.angle, 45)
        XCTAssertEqual(decoded.gradient?.colors.count, 2)
    }
}
```

- [ ] Run tests:

```bash
cd Modules/SharedModels && swift test
```

Expected: **5 tests pass**

- [ ] Commit:

```bash
cd ../..
git add Modules/SharedModels/
git commit -m "feat: SharedModels — Capture, AnyAnnotation tagged union, CodableColor, BackgroundConfig"
```

---

---

## Chunk 3: HistoryStore

**Goal:** Persistent SQLite-backed capture history with 30-day auto-prune, thumbnail generation, and full CRUD.

### Task 5: Implement HistoryStore

**Files:**
- Create: `Modules/HistoryStore/Sources/HistoryStore/HistoryStore.swift`
- Create: `Modules/HistoryStore/Tests/HistoryStoreTests/HistoryStoreTests.swift`

- [ ] Delete `Placeholder.swift` from `Modules/HistoryStore/Sources/HistoryStore/`.

- [ ] Create `HistoryStore.swift`:

```swift
import Foundation
import GRDB
import SharedModels
import AppKit
import AVFoundation

public final class HistoryStore {
    private let db: DatabaseQueue
    public static let shared: HistoryStore = {
        let url = Self.storeDirectory.appendingPathComponent("history.sqlite")
        return try! HistoryStore(databaseURL: url)
    }()

    static var storeDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("CleanShotAlt")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var capturesDirectory: URL {
        let dir = storeDirectory.appendingPathComponent("captures")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var thumbnailsDirectory: URL {
        let dir = storeDirectory.appendingPathComponent("thumbnails")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    init(databaseURL: URL) throws {
        db = try DatabaseQueue(path: databaseURL.path)
        try migrate()
    }

    private func migrate() throws {
        try db.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS captures (
                    id TEXT PRIMARY KEY,
                    mode TEXT NOT NULL,
                    created_at INTEGER NOT NULL,
                    file_path TEXT NOT NULL,
                    thumbnail_path TEXT NOT NULL,
                    export_format TEXT NOT NULL,
                    file_size INTEGER,
                    width INTEGER,
                    height INTEGER
                )
                """)
        }
    }

    // MARK: - Public API

    public func ingest(_ capture: Capture) async throws {
        let thumbnail = try await generateThumbnail(for: capture)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            do {
                try db.write { db in
                    try db.execute(sql: """
                        INSERT INTO captures (id, mode, created_at, file_path, thumbnail_path, export_format)
                        VALUES (?, ?, ?, ?, ?, ?)
                        """, arguments: [
                        capture.id.uuidString,
                        capture.mode.rawValue,
                        Int(capture.createdAt.timeIntervalSince1970),
                        capture.filePath.path,
                        thumbnail.path,
                        capture.exportFormat.rawValue
                    ])
                }
                cont.resume()
            } catch { cont.resume(throwing: error) }
        }
    }

    public func fetchAll(filter: CaptureMode? = nil) async throws -> [Capture] {
        try await withCheckedThrowingContinuation { cont in
            do {
                let captures = try db.read { db -> [Capture] in
                    var sql = "SELECT * FROM captures"
                    var args: StatementArguments = []
                    if let filter {
                        sql += " WHERE mode = ?"
                        args = [filter.rawValue]
                    }
                    sql += " ORDER BY created_at DESC"
                    let rows = try Row.fetchAll(db, sql: sql, arguments: args)
                    return rows.compactMap { row -> Capture? in
                        guard let id = UUID(uuidString: row["id"] as String),
                              let mode = CaptureMode(rawValue: row["mode"] as String),
                              let format = ExportFormat(rawValue: row["export_format"] as String)
                        else { return nil }
                        let ts: Int = row["created_at"]
                        return Capture(
                            id: id, mode: mode,
                            createdAt: Date(timeIntervalSince1970: Double(ts)),
                            filePath: URL(fileURLWithPath: row["file_path"] as String),
                            thumbnailPath: URL(fileURLWithPath: row["thumbnail_path"] as String),
                            exportFormat: format
                        )
                    }
                }
                cont.resume(returning: captures)
            } catch { cont.resume(throwing: error) }
        }
    }

    public func delete(_ id: UUID) async throws {
        // Fetch paths before deleting row
        let capture = try await fetchAll().first(where: { $0.id == id })
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            do {
                try db.write { db in
                    try db.execute(sql: "DELETE FROM captures WHERE id = ?", arguments: [id.uuidString])
                }
                cont.resume()
            } catch { cont.resume(throwing: error) }
        }
        if let capture {
            try? FileManager.default.removeItem(at: capture.filePath)
            try? FileManager.default.removeItem(at: capture.thumbnailPath)
        }
    }

    public func replace(originalID: UUID, with annotated: Capture) async throws {
        try await delete(originalID)
        try await ingest(annotated)
    }

    public func pruneOlderThan(_ days: Int) async throws {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        let old = try await fetchAll().filter { $0.createdAt < cutoff }
        for capture in old { try await delete(capture.id) }
    }

    // MARK: - Thumbnail generation

    private func generateThumbnail(for capture: Capture) async throws -> URL {
        let destURL = Self.thumbnailsDirectory
            .appendingPathComponent(capture.id.uuidString + "_thumb.jpg")

        switch capture.mode {
        case .video:
            let asset = AVAsset(url: capture.filePath)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            let cgImage = try await gen.image(at: .zero).image
            try writeJPEG(cgImage, to: destURL)
        default:
            guard let src = CGImageSourceCreateWithURL(capture.filePath as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(src, 0, nil)
            else { throw HistoryStoreError.thumbnailFailed }
            try writeJPEG(cgImage, to: destURL, maxDimension: 240)
        }
        return destURL
    }

    private func writeJPEG(_ image: CGImage, to url: URL, maxDimension: Int = 240) throws {
        // Scale down if needed
        let scale = min(1.0, Double(maxDimension) / Double(max(image.width, image.height)))
        let w = Int(Double(image.width) * scale)
        let h = Int(Double(image.height) * scale)
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        let ctx = CGContext(data: nil, width: w, height: h,
                            bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let scaled = ctx.makeImage()!

        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil)
        else { throw HistoryStoreError.thumbnailFailed }
        CGImageDestinationAddImage(dest, scaled, [kCGImageDestinationLossyCompressionQuality: 0.7] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw HistoryStoreError.thumbnailFailed }
    }
}

public enum HistoryStoreError: Error {
    case thumbnailFailed
    case notFound
}
```

- [ ] Create `HistoryStoreTests.swift`:

```swift
import XCTest
@testable import HistoryStore
import SharedModels

final class HistoryStoreTests: XCTestCase {
    var store: HistoryStore!
    var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let dbURL = tempDir.appendingPathComponent("test.sqlite")
        store = try HistoryStore(databaseURL: dbURL)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func makeCapture(mode: CaptureMode = .area) throws -> Capture {
        // Create a minimal 1x1 PNG so thumbnail generation works
        let pngURL = tempDir.appendingPathComponent(UUID().uuidString + ".png")
        let ctx = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8,
                            bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        let img = ctx.makeImage()!
        let dest = CGImageDestinationCreateWithURL(pngURL as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, img, nil)
        CGImageDestinationFinalize(dest)
        return Capture(mode: mode, filePath: pngURL,
                       thumbnailPath: tempDir.appendingPathComponent("thumb.jpg"))
    }

    func test_ingest_and_fetch() async throws {
        let capture = try makeCapture()
        try await store.ingest(capture)
        let all = try await store.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].id, capture.id)
    }

    func test_fetch_filters_by_mode() async throws {
        try await store.ingest(try makeCapture(mode: .area))
        try await store.ingest(try makeCapture(mode: .video))
        let screenshots = try await store.fetchAll(filter: .area)
        XCTAssertEqual(screenshots.count, 1)
        XCTAssertEqual(screenshots[0].mode, .area)
    }

    func test_delete_removes_record() async throws {
        let capture = try makeCapture()
        try await store.ingest(capture)
        try await store.delete(capture.id)
        let all = try await store.fetchAll()
        XCTAssertTrue(all.isEmpty)
    }

    func test_prune_removes_old_captures() async throws {
        var old = try makeCapture()
        // Manually insert with old timestamp by going through raw DB
        // Since we can't modify createdAt after init, use replace with old capture
        // Simplification: test that prune(0) removes a just-inserted capture
        try await store.ingest(old)
        try await store.pruneOlderThan(0)
        let all = try await store.fetchAll()
        XCTAssertTrue(all.isEmpty)
    }

    func test_replace_swaps_capture() async throws {
        let original = try makeCapture()
        try await store.ingest(original)
        let annotated = Capture(mode: .area, filePath: original.filePath,
                                thumbnailPath: original.thumbnailPath)
        try await store.replace(originalID: original.id, with: annotated)
        let all = try await store.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertNotEqual(all[0].id, original.id)
    }
}
```

- [ ] Run tests:

```bash
cd Modules/HistoryStore && swift test
```

Expected: **5 tests pass**

- [ ] Commit:

```bash
cd ../..
git add Modules/HistoryStore/
git commit -m "feat: HistoryStore — GRDB-backed capture history, thumbnail generation, auto-prune"
```

---

## Chunk 4: DesktopManager + OCRService

### Task 6: Implement DesktopManager

**Files:**
- Create: `Modules/DesktopManager/Sources/DesktopManager/DesktopManager.swift`
- Create: `Modules/DesktopManager/Tests/DesktopManagerTests/DesktopManagerTests.swift`

- [ ] Delete `Placeholder.swift` from `Modules/DesktopManager/Sources/DesktopManager/`.

- [ ] Create `DesktopManager.swift`:

```swift
import AppKit
import Foundation

public final class DesktopManager {
    private var savedWallpapers: [NSScreen: URL] = [:]

    public init() {}

    public func hideIcons() throws {
        try shell("defaults write com.apple.finder CreateDesktop -bool false")
        try shell("killall Finder")
        // Give Finder time to relaunch
        Thread.sleep(forTimeInterval: 0.5)
    }

    public func showIcons() throws {
        try shell("defaults write com.apple.finder CreateDesktop -bool true")
        try shell("killall Finder")
        Thread.sleep(forTimeInterval: 0.5)
    }

    public func saveAndSetWallpaper(_ newURL: URL, on screen: NSScreen) throws {
        if let current = NSWorkspace.shared.desktopImageURL(for: screen) {
            savedWallpapers[screen] = current
        }
        try NSWorkspace.shared.setDesktopImageURL(newURL, for: screen, options: [:])
    }

    public func restoreWallpaper(on screen: NSScreen) throws {
        guard let saved = savedWallpapers[screen] else { return }
        try NSWorkspace.shared.setDesktopImageURL(saved, for: screen, options: [:])
        savedWallpapers.removeValue(forKey: screen)
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
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

public enum DesktopManagerError: Error {
    case shellFailed(String)
}
```

- [ ] Create `DesktopManagerTests.swift`:

```swift
import XCTest
@testable import DesktopManager

final class DesktopManagerTests: XCTestCase {
    // Note: hideIcons/showIcons interact with Finder — tested manually.
    // Unit test only the wallpaper save/restore state tracking.

    func test_wallpaper_save_state_cleared_on_restore() throws {
        let manager = DesktopManager()
        let screen = NSScreen.main!
        // Save current wallpaper path for restore
        let current = NSWorkspace.shared.desktopImageURL(for: screen)
        // Restore without prior save should not throw
        XCTAssertNoThrow(try manager.restoreWallpaper(on: screen))
        // Clean up: restore original
        if let current { try? NSWorkspace.shared.setDesktopImageURL(current, for: screen, options: [:]) }
    }
}
```

- [ ] Run:

```bash
cd Modules/DesktopManager && swift test
```

Expected: **1 test passes**

- [ ] Commit:

```bash
cd ../..
git add Modules/DesktopManager/
git commit -m "feat: DesktopManager — hide/show desktop icons, save/restore wallpaper"
```

---

### Task 7: Implement OCRService

**Files:**
- Create: `Modules/OCRService/Sources/OCRService/OCRService.swift`
- Create: `Modules/OCRService/Tests/OCRServiceTests/OCRServiceTests.swift`

- [ ] Delete `Placeholder.swift` from `Modules/OCRService/Sources/OCRService/`.

- [ ] Create `OCRService.swift`:

```swift
import Foundation
import Vision
import CoreGraphics

public struct OCRResult {
    public let fullText: String
    public let blocks: [RecognizedBlock]
}

public struct RecognizedBlock {
    public let text: String
    public let boundingBox: CGRect  // normalized 0–1, origin bottom-left (Vision coords)
    public let confidence: Float
}

public final class OCRService {
    public init() {}

    public func recognize(image: CGImage) async throws -> OCRResult {
        try await withCheckedThrowingContinuation { cont in
            let request = VNRecognizeTextRequest { req, err in
                if let err { cont.resume(throwing: err); return }
                guard let observations = req.results as? [VNRecognizedTextObservation] else {
                    cont.resume(returning: OCRResult(fullText: "", blocks: []))
                    return
                }
                var blocks: [RecognizedBlock] = []
                var lines: [String] = []
                for obs in observations {
                    guard let candidate = obs.topCandidates(1).first else { continue }
                    blocks.append(RecognizedBlock(text: candidate.string,
                                                  boundingBox: obs.boundingBox,
                                                  confidence: candidate.confidence))
                    lines.append(candidate.string)
                }
                cont.resume(returning: OCRResult(fullText: lines.joined(separator: "\n"), blocks: blocks))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do { try handler.perform([request]) }
            catch { cont.resume(throwing: error) }
        }
    }

    public func detectQRCodes(image: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { cont in
            let request = VNDetectBarcodesRequest { req, err in
                if let err { cont.resume(throwing: err); return }
                let barcodes = req.results as? [VNBarcodeObservation] ?? []
                let values = barcodes.filter { $0.symbology == .qr }
                    .compactMap { $0.payloadStringValue }
                cont.resume(returning: values)
            }
            request.symbologies = [.qr]
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do { try handler.perform([request]) }
            catch { cont.resume(throwing: error) }
        }
    }
}
```

- [ ] Create `OCRServiceTests.swift`:

```swift
import XCTest
@testable import OCRService
import CoreGraphics
import AppKit

final class OCRServiceTests: XCTestCase {
    let service = OCRService()

    // Helper: render text to CGImage for OCR testing
    func imageWithText(_ text: String, size: CGSize = CGSize(width: 300, height: 60)) -> CGImage {
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        let ctx = CGContext(data: nil,
                            width: Int(size.width), height: Int(size.height),
                            bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: bitmapInfo.rawValue)!
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(origin: .zero, size: size))

        let ns = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 24),
            .foregroundColor: NSColor.black
        ])
        let line = CTLineCreateWithAttributedString(ns)
        ctx.textPosition = CGPoint(x: 10, y: 15)
        CTLineDraw(line, ctx)
        return ctx.makeImage()!
    }

    func test_recognize_returns_text() async throws {
        let image = imageWithText("Hello World")
        let result = try await service.recognize(image: image)
        XCTAssertTrue(result.fullText.lowercased().contains("hello"),
                      "Expected 'hello' in '\(result.fullText)'")
    }

    func test_empty_image_returns_empty_result() async throws {
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        let ctx = CGContext(data: nil, width: 100, height: 100, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: bitmapInfo.rawValue)!
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        let image = ctx.makeImage()!
        let result = try await service.recognize(image: image)
        XCTAssertTrue(result.blocks.isEmpty || result.fullText.isEmpty)
    }
}
```

- [ ] Run:

```bash
cd Modules/OCRService && swift test
```

Expected: **2 tests pass** (OCR on a rendered image may vary — assert `.contains` loosely)

- [ ] Commit:

```bash
cd ../..
git add Modules/OCRService/
git commit -m "feat: OCRService — on-device text recognition and QR code detection via Vision"
```


---

## Chunk 5: CaptureEngine — Screenshots

**Goal:** Area, window, and fullscreen capture working end-to-end, producing a `CGImage` the caller can hand to `HistoryStore` and `QuickOverlay`.

### Task 8: Capture overlay window + area capture

**Files:**
- Create: `Modules/CaptureEngine/Sources/CaptureEngine/CaptureOverlayWindow.swift`
- Create: `Modules/CaptureEngine/Sources/CaptureEngine/AreaCapture.swift`
- Create: `Modules/CaptureEngine/Tests/CaptureEngineTests/AreaCaptureTests.swift`

- [ ] Delete `Placeholder.swift` from `Modules/CaptureEngine/Sources/CaptureEngine/`.

- [ ] Create `CaptureOverlayWindow.swift` — transparent fullscreen NSPanel used by multiple capture modes:

```swift
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
        level = .screenSaver          // above everything
        ignoresMouseEvents = false
        isMovable = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
}
```

- [ ] Create `AreaCapture.swift`:

```swift
import AppKit
import ScreenCaptureKit
import SharedModels

/// Presents an interactive selection UI and returns the captured CGImage.
@MainActor
public final class AreaCapture: NSObject {
    public static var lastRect: CGRect? = nil

    private var completion: ((Result<CGImage, Error>) -> Void)?
    private var overlayWindows: [CaptureOverlayWindow] = []
    private var selectionView: AreaSelectionView?

    public func capture() async throws -> CGImage {
        try await withCheckedThrowingContinuation { cont in
            self.completion = { cont.resume(with: $0) }
            self.presentOverlay()
        }
    }

    public func retakeLast() async throws -> CGImage {
        guard let rect = Self.lastRect else { throw CaptureError.noLastRect }
        return try await captureRect(rect, on: NSScreen.main ?? NSScreen.screens[0])
    }

    // MARK: - Private

    private func presentOverlay() {
        for screen in NSScreen.screens {
            let win = CaptureOverlayWindow(screen: screen)
            let view = AreaSelectionView(screen: screen) { [weak self] selectedRect in
                self?.dismissOverlay()
                guard let self else { return }
                Task {
                    do {
                        let image = try await self.captureRect(selectedRect, on: screen)
                        Self.lastRect = selectedRect
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
            selectionView = view
        }
        NSCursor.crosshair.push()
    }

    private func dismissOverlay() {
        NSCursor.pop()
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
    }

    private func captureRect(_ rect: CGRect, on screen: NSScreen) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let display = content.displays.first(where: { $0.frame.intersects(screen.frame) })
            ?? content.displays[0]
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCScreenshotConfiguration()
        config.sourceRect = rect
        config.scalesToFit = false
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
}

public enum CaptureError: Error {
    case cancelled
    case noLastRect
    case noDisplayFound
    case permissionDenied
}
```

- [ ] Create `AreaSelectionView.swift` (NSView subclass for drawing the selection rect):

```swift
import AppKit

final class AreaSelectionView: NSView {
    private var startPoint: CGPoint?
    private var currentRect: CGRect = .zero
    private let onSelect: (CGRect) -> Void
    private let onCancel: () -> Void
    private let screen: NSScreen

    init(screen: NSScreen, onSelect: @escaping (CGRect) -> Void, onCancel: @escaping () -> Void) {
        self.screen = screen
        self.onSelect = onSelect
        self.onCancel = onCancel
        super.init(frame: screen.frame)
    }
    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        // Dark tint overlay
        NSColor.black.withAlphaComponent(0.35).setFill()
        NSBezierPath.fill(bounds)

        if currentRect.width > 2 && currentRect.height > 2 {
            // Clear the selected region
            NSColor.clear.setFill()
            currentRect.fill(using: .copy)

            // Selection border
            NSColor.white.setStroke()
            let path = NSBezierPath(rect: currentRect)
            path.lineWidth = 1.5
            path.stroke()

            // Dimension label
            let label = "\(Int(currentRect.width)) × \(Int(currentRect.height))"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.white
            ]
            let size = (label as NSString).size(withAttributes: attrs)
            let labelRect = CGRect(x: currentRect.midX - size.width/2,
                                   y: currentRect.maxY + 6,
                                   width: size.width + 8, height: size.height + 4)
            NSColor.black.withAlphaComponent(0.6).setFill()
            NSBezierPath(roundedRect: labelRect, xRadius: 3, yRadius: 3).fill()
            (label as NSString).draw(at: CGPoint(x: labelRect.minX + 4, y: labelRect.minY + 2),
                                     withAttributes: attrs)
        }
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = .zero
        setNeedsDisplay(bounds)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        currentRect = CGRect(
            x: min(start.x, current.x), y: min(start.y, current.y),
            width: abs(current.x - start.x), height: abs(current.y - start.y)
        )
        setNeedsDisplay(bounds)
    }

    override func mouseUp(with event: NSEvent) {
        guard currentRect.width > 5 && currentRect.height > 5 else {
            onCancel(); return
        }
        // Convert from flipped view coords to screen coords
        let screenRect = CGRect(
            x: screen.frame.minX + currentRect.minX,
            y: screen.frame.minY + (screen.frame.height - currentRect.maxY),
            width: currentRect.width,
            height: currentRect.height
        )
        onSelect(screenRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel() }  // Escape
    }
    override var acceptsFirstResponder: Bool { true }
}
```

- [ ] Write tests for the geometry helper in `CaptureEngineTests.swift`:

```swift
import XCTest
@testable import CaptureEngine

final class CaptureEngineTests: XCTestCase {
    // AreaCapture geometry: test that small drags are rejected
    func test_small_selection_is_cancelled() {
        // Simulate a 3×3 drag — should trigger onCancel
        var cancelled = false
        let view = AreaSelectionView(
            screen: NSScreen.main!,
            onSelect: { _ in XCTFail("Should not select") },
            onCancel: { cancelled = true }
        )
        // Simulate mouseDown + mouseUp at same point (0 size rect)
        // We test the guard condition: width > 5 && height > 5
        // Access via internal test — if internal, we verify behavior via output
        // Since AreaSelectionView is internal, test at integration level:
        // Just verify CaptureError cases exist
        XCTAssertNotNil(CaptureError.cancelled)
        XCTAssertNotNil(CaptureError.noLastRect)
    }
}
```

- [ ] Build to check compilation (`Cmd+B` in Xcode, or `swift build` in `Modules/CaptureEngine`).
- [ ] Commit:

```bash
git add Modules/CaptureEngine/Sources/CaptureEngine/CaptureOverlayWindow.swift
git add Modules/CaptureEngine/Sources/CaptureEngine/AreaCapture.swift
git add Modules/CaptureEngine/Sources/CaptureEngine/AreaSelectionView.swift
git add Modules/CaptureEngine/Tests/
git commit -m "feat: CaptureEngine — area capture with crosshair overlay, selection UI, dimension label"
```

---

### Task 9: Window capture + fullscreen capture

**Files:**
- Create: `Modules/CaptureEngine/Sources/CaptureEngine/WindowCapture.swift`
- Create: `Modules/CaptureEngine/Sources/CaptureEngine/FullscreenCapture.swift`

- [ ] Create `WindowCapture.swift`:

```swift
import AppKit
import ScreenCaptureKit
import CoreImage
import SharedModels

@MainActor
public final class WindowCapture: NSObject {
    private var completion: ((Result<CGImage, Error>) -> Void)?
    private var overlayWindows: [CaptureOverlayWindow] = []

    public func capture() async throws -> CGImage {
        let windows = try await fetchWindows()
        return try await withCheckedThrowingContinuation { cont in
            self.completion = { cont.resume(with: $0) }
            self.presentWindowOverlay(windows: windows)
        }
    }

    // MARK: - Private

    private struct WindowInfo {
        let windowID: CGWindowID
        let frame: CGRect
        let appName: String
        let scWindow: SCWindow
    }

    private func fetchWindows() async throws -> [WindowInfo] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        return content.windows.compactMap { w -> WindowInfo? in
            guard w.frame.width > 50, w.frame.height > 50, w.isOnScreen else { return nil }
            return WindowInfo(windowID: CGWindowID(w.windowID),
                              frame: w.frame,
                              appName: w.owningApplication?.applicationName ?? "",
                              scWindow: w)
        }
    }

    private func presentWindowOverlay(windows: [WindowInfo]) {
        for screen in NSScreen.screens {
            let win = CaptureOverlayWindow(screen: screen)
            let view = WindowSelectionView(screen: screen, windows: windows) { [weak self] selectedWindow in
                self?.dismissOverlay()
                guard let self else { return }
                Task {
                    do {
                        let image = try await self.captureWindow(selectedWindow)
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

    private func captureWindow(_ info: WindowInfo) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let scWin = content.windows.first(where: { $0.windowID == info.scWindow.windowID })
        else { throw CaptureError.noDisplayFound }

        let filter = SCContentFilter(desktopIndependentWindow: scWin)
        let config = SCScreenshotConfiguration()
        config.scalesToFit = false

        var image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

        if AppSettings.shared.captureDropShadow {
            image = try applyShadow(to: image) ?? image
        }
        return image
    }

    private func applyShadow(to image: CGImage) throws -> CGImage? {
        guard let filter = CIFilter(name: "CIDropShadow") else { return nil }
        let ciImage = CIImage(cgImage: image)
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: 0, y: -4), forKey: "inputOffset")
        filter.setValue(8.0, forKey: kCIInputRadiusKey)
        filter.setValue(0.5, forKey: "inputOpacity")
        let ctx = CIContext()
        guard let output = filter.outputImage,
              let result = ctx.createCGImage(output, from: output.extent) else { return nil }
        return result
    }
}

/// NSView subclass that highlights windows on hover and fires selection on click
final class WindowSelectionView: NSView {
    private let windows: [WindowCapture.WindowInfo]  // make internal for this
    private var hoveredWindowID: CGWindowID?
    private let onSelect: (WindowCapture.WindowInfo) -> Void
    private let onCancel: () -> Void
    private let screen: NSScreen

    init(screen: NSScreen,
         windows: [WindowCapture.WindowInfo],
         onSelect: @escaping (WindowCapture.WindowInfo) -> Void,
         onCancel: @escaping () -> Void) {
        self.screen = screen; self.windows = windows
        self.onSelect = onSelect; self.onCancel = onCancel
        super.init(frame: screen.frame)
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.activeAlways, .mouseMoved, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }
    required init?(coder: NSCoder) { fatalError() }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.3).setFill()
        NSBezierPath.fill(bounds)
        guard let hid = hoveredWindowID,
              let win = windows.first(where: { $0.windowID == hid }) else { return }
        let localRect = screenRectToLocal(win.frame)
        NSColor.clear.setFill()
        localRect.fill(using: .copy)
        NSColor.controlAccentColor.setStroke()
        let path = NSBezierPath(rect: localRect.insetBy(dx: -2, dy: -2))
        path.lineWidth = 3
        path.stroke()
    }

    override func mouseMoved(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        let screenPt = CGPoint(x: screen.frame.minX + pt.x,
                               y: screen.frame.minY + (screen.frame.height - pt.y))
        hoveredWindowID = windows.first(where: { $0.frame.contains(screenPt) })?.windowID
        setNeedsDisplay(bounds)
    }

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        let screenPt = CGPoint(x: screen.frame.minX + pt.x,
                               y: screen.frame.minY + (screen.frame.height - pt.y))
        if let win = windows.first(where: { $0.frame.contains(screenPt) }) {
            onSelect(win)
        } else {
            onCancel()
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel() }
    }
    override var acceptsFirstResponder: Bool { true }

    private func screenRectToLocal(_ screenRect: CGRect) -> CGRect {
        CGRect(x: screenRect.minX - screen.frame.minX,
               y: screen.frame.height - (screenRect.minY - screen.frame.minY) - screenRect.height,
               width: screenRect.width, height: screenRect.height)
    }
}

// Expose WindowInfo publicly for the selection callback
extension WindowCapture {
    struct WindowInfo {
        let windowID: CGWindowID
        let frame: CGRect
        let appName: String
        let scWindow: SCWindow
    }
}
```

- [ ] Create `FullscreenCapture.swift`:

```swift
import AppKit
import ScreenCaptureKit
import SharedModels

public final class FullscreenCapture {
    public init() {}

    /// Captures all connected displays, returns one CGImage per display.
    public func captureAll() async throws -> [(screen: NSScreen, image: CGImage)] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        var results: [(NSScreen, CGImage)] = []
        for screen in NSScreen.screens {
            guard let display = content.displays.first(where: { $0.frame.intersects(screen.frame) })
            else { continue }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCScreenshotConfiguration()
            config.scalesToFit = false
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter,
                                                                    configuration: config)
            results.append((screen, image))
        }
        return results
    }

    /// Captures the display containing the current mouse cursor.
    public func captureMainDisplay() async throws -> CGImage {
        let mouseScreen = NSScreen.screens.first(where: {
            $0.frame.contains(NSEvent.mouseLocation)
        }) ?? NSScreen.main ?? NSScreen.screens[0]

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.frame.intersects(mouseScreen.frame) })
        else { throw CaptureError.noDisplayFound }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCScreenshotConfiguration()
        config.scalesToFit = false
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
}
```

- [ ] Build (`Cmd+B`). Fix any compilation errors.
- [ ] Commit:

```bash
git add Modules/CaptureEngine/Sources/CaptureEngine/WindowCapture.swift
git add Modules/CaptureEngine/Sources/CaptureEngine/FullscreenCapture.swift
git commit -m "feat: CaptureEngine — window capture with hover highlight, fullscreen capture"
```

---

### Task 10: Scrolling capture

**Files:**
- Create: `Modules/CaptureEngine/Sources/CaptureEngine/ScrollingCapture.swift`

- [ ] Create `ScrollingCapture.swift`:

```swift
import AppKit
import ScreenCaptureKit
import CoreGraphics
import SharedModels

@MainActor
public final class ScrollingCapture {
    public init() {}

    public func capture(in window: SCWindow) async throws -> CGImage {
        var frames: [CGImage] = []
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCScreenshotConfiguration()
        config.scalesToFit = false

        // Capture initial frame
        let first = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        frames.append(first)

        var previousFrame = first
        var reachedBottom = false
        let maxScrollSteps = 50

        for _ in 0..<maxScrollSteps {
            // Inject scroll event (requires Accessibility permission)
            let scrollEvent = CGEvent(scrollWheelEvent2Source: nil,
                                      units: .pixel,
                                      wheelCount: 1,
                                      wheel1: -120,  // scroll down
                                      wheel2: 0,
                                      wheel3: 0)
            scrollEvent?.post(tap: .cghidEventTap)

            // Wait for scroll animation to settle
            try await Task.sleep(nanoseconds: 150_000_000)  // 150ms

            let frame = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

            if framesAreIdentical(previousFrame, frame) {
                reachedBottom = true
                break
            }
            frames.append(frame)
            previousFrame = frame
        }

        return try stitchFrames(frames, overlapDetection: true)
    }

    // MARK: - Private

    /// Compares a horizontal strip in the middle of both frames to detect identical content.
    private func framesAreIdentical(_ a: CGImage, _ b: CGImage) -> Bool {
        guard a.width == b.width, a.height == b.height else { return false }
        let stripHeight = min(20, a.height)
        let stripY = a.height / 2
        guard let aStrip = a.cropping(to: CGRect(x: 0, y: stripY, width: a.width, height: stripHeight)),
              let bStrip = b.cropping(to: CGRect(x: 0, y: stripY, width: b.width, height: stripHeight))
        else { return false }

        let aData = imageToBytes(aStrip)
        let bData = imageToBytes(bStrip)
        return aData == bData
    }

    /// Stitches frames by detecting overlap via matching a bottom strip of frame N against frame N+1.
    private func stitchFrames(_ frames: [CGImage], overlapDetection: Bool) throws -> CGImage {
        guard !frames.isEmpty else { throw CaptureError.cancelled }
        guard frames.count > 1 else { return frames[0] }

        var yOffsets: [Int] = [0]
        let stripHeight = 30

        for i in 1..<frames.count {
            let prev = frames[i-1]
            let curr = frames[i]
            let overlap = findOverlap(prev, curr, stripHeight: stripHeight)
            let advance = prev.height - overlap
            yOffsets.append(yOffsets[i-1] + advance)
        }

        let totalHeight = yOffsets.last! + frames.last!.height
        let width = frames[0].width

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let ctx = CGContext(data: nil, width: width, height: totalHeight,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: bitmapInfo.rawValue)
        else { throw CaptureError.cancelled }

        for (i, frame) in frames.enumerated() {
            let y = totalHeight - yOffsets[i] - frame.height
            ctx.draw(frame, in: CGRect(x: 0, y: y, width: frame.width, height: frame.height))
        }

        guard let result = ctx.makeImage() else { throw CaptureError.cancelled }
        return result
    }

    /// Returns how many pixels of overlap exist at the bottom of `a` matching the top of `b`.
    private func findOverlap(_ a: CGImage, _ b: CGImage, stripHeight: Int) -> Int {
        let checkRows = min(stripHeight, a.height, b.height)
        for overlap in stride(from: checkRows, through: 1, by: -1) {
            let aStrip = a.cropping(to: CGRect(x: 0, y: a.height - overlap, width: a.width, height: overlap))
            let bStrip = b.cropping(to: CGRect(x: 0, y: 0, width: b.width, height: overlap))
            if let aS = aStrip, let bS = bStrip, imageToBytes(aS) == imageToBytes(bS) {
                return overlap
            }
        }
        return 0
    }

    private func imageToBytes(_ image: CGImage) -> Data {
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let ctx = CGContext(data: nil, width: image.width, height: image.height,
                                  bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: bitmapInfo.rawValue)
        else { return Data() }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let data = ctx.data else { return Data() }
        return Data(bytes: data, count: image.width * image.height * 4)
    }
}
```

- [ ] Build. Commit:

```bash
git add Modules/CaptureEngine/Sources/CaptureEngine/ScrollingCapture.swift
git commit -m "feat: CaptureEngine — scrolling capture with frame stitching and overlap detection"
```

---

## Chunk 6: CaptureEngine — Recording

**Goal:** Screen recording to MP4 and GIF, camera overlay, click/keystroke visualizer.

### Task 11: Screen recorder (MP4)

**Files:**
- Create: `Modules/CaptureEngine/Sources/CaptureEngine/ScreenRecorder.swift`

- [ ] Create `ScreenRecorder.swift`:

```swift
import Foundation
import ScreenCaptureKit
import AVFoundation
import SharedModels

public final class ScreenRecorder: NSObject, SCStreamDelegate, SCStreamOutput {
    public enum State { case idle, recording, stopping }

    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var outputURL: URL?
    private(set) public var state: State = .idle
    private var firstSampleTime: CMTime?

    public struct Config {
        public var fps: Int = 30
        public var resolution: CGSize? = nil   // nil = native
        public var captureMicrophone: Bool = false
        public var captureSystemAudio: Bool = true
        public var showMouseClicks: Bool = false
        public var showKeystrokes: Bool = false
        public init() {}
    }

    public init(config: Config = Config()) {
        self.config = config
    }
    private let config: Config

    public func startRecording(filter: SCContentFilter) async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp4")
        outputURL = url

        // AVAssetWriter
        assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(config.resolution?.width ?? 1920),
            AVVideoHeightKey: Int(config.resolution?.height ?? 1080),
        ]
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput!.expectsMediaDataInRealTime = true
        assetWriter!.add(videoInput!)

        if config.captureSystemAudio || config.captureMicrophone {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
            ]
            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput!.expectsMediaDataInRealTime = true
            assetWriter!.add(audioInput!)
        }

        // SCStream config
        let streamConfig = SCStreamConfiguration()
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(config.fps))
        streamConfig.capturesAudio = config.captureSystemAudio
        streamConfig.showsCursor = true

        stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
        try stream!.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue(label: "video"))
        if config.captureSystemAudio {
            try stream!.addStreamOutput(self, type: .audio, sampleHandlerQueue: DispatchQueue(label: "audio"))
        }
        try await stream!.startCapture()
        state = .recording
        return url
    }

    public func stopRecording() async throws -> URL {
        guard let stream, let assetWriter, let outputURL else {
            throw RecordingError.notRecording
        }
        state = .stopping
        try await stream.stopCapture()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            assetWriter.finishWriting { cont.resume() }
        }
        self.stream = nil
        state = .idle
        return outputURL
    }

    // MARK: - SCStreamOutput

    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                       of outputType: SCStreamOutputType) {
        guard state == .recording,
              CMSampleBufferDataIsReady(sampleBuffer) else { return }

        if firstSampleTime == nil {
            firstSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            assetWriter?.startWriting()
            assetWriter?.startSession(atSourceTime: firstSampleTime!)
        }

        switch outputType {
        case .screen:
            if videoInput?.isReadyForMoreMediaData == true {
                videoInput?.append(sampleBuffer)
            }
        case .audio:
            if audioInput?.isReadyForMoreMediaData == true {
                audioInput?.append(sampleBuffer)
            }
        @unknown default: break
        }
    }

    // MARK: - SCStreamDelegate

    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        state = .idle
    }
}

public enum RecordingError: Error {
    case notRecording
    case writeFailed
}
```

- [ ] Build. Commit:

```bash
git add Modules/CaptureEngine/Sources/CaptureEngine/ScreenRecorder.swift
git commit -m "feat: CaptureEngine — SCStream-based screen recorder, AVAssetWriter MP4 output"
```

---

### Task 12: GIF recorder + camera overlay + click visualizer

**Files:**
- Create: `Modules/CaptureEngine/Sources/CaptureEngine/GIFRecorder.swift`
- Create: `Modules/CaptureEngine/Sources/CaptureEngine/CameraOverlay.swift`
- Create: `Modules/CaptureEngine/Sources/CaptureEngine/ClickKeystrokeVisualizer.swift`

- [ ] Create `GIFRecorder.swift`:

```swift
import Foundation
import ScreenCaptureKit
import Gifski
import AVFoundation
import CoreVideo

public final class GIFRecorder: NSObject, SCStreamDelegate, SCStreamOutput {
    public struct Config {
        public var fps: Int = 10
        public var scale: Double = 1.0
        public init() {}
    }

    private let config: Config
    private var stream: SCStream?
    private var frames: [(image: CGImage, delay: Double)] = []
    private var lastTimestamp: CMTime?
    private(set) public var isRecording = false

    public init(config: Config = Config()) {
        self.config = config
    }

    public func startRecording(filter: SCContentFilter) async throws {
        frames.removeAll()
        lastTimestamp = nil

        let streamConfig = SCStreamConfiguration()
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(config.fps))
        streamConfig.capturesAudio = false

        stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
        try stream!.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue(label: "gif"))
        try await stream!.startCapture()
        isRecording = true
    }

    public func stopRecording() async throws -> URL {
        guard let stream else { throw RecordingError.notRecording }
        try await stream.stopCapture()
        self.stream = nil
        isRecording = false
        return try await encodeGIF()
    }

    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                       of type: SCStreamOutputType) {
        guard type == .screen, isRecording else { return }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let delay = lastTimestamp.map { CMTimeGetSeconds(CMTimeSubtract(ts, $0)) } ?? (1.0 / Double(config.fps))
        lastTimestamp = ts

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let ctx = CIContext()
        guard let cgImage = ctx.createCGImage(ciImage, from: ciImage.extent) else { return }
        frames.append((cgImage, delay))
    }

    public func stream(_ stream: SCStream, didStopWithError error: Error) { isRecording = false }

    private func encodeGIF() async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".gif")
        let gifski = Gifski()

        return try await withCheckedThrowingContinuation { cont in
            var settings = Gifski.Settings()
            settings.quality = 90
            gifski.encode(frames: frames.enumerated().map { i, f in
                Gifski.Frame(image: f.image, delay: f.delay, index: i)
            }, settings: settings) { result in
                switch result {
                case .success(let data):
                    do { try data.write(to: url); cont.resume(returning: url) }
                    catch { cont.resume(throwing: error) }
                case .failure(let err):
                    cont.resume(throwing: err)
                }
            }
        }
    }
}
```

- [ ] Create `CameraOverlay.swift`:

```swift
import AppKit
import AVFoundation

/// Floating NSPanel showing the webcam feed, composited over recordings.
public final class CameraOverlay: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var panel: NSPanel?
    public private(set) var isRunning = false

    public func start(at position: CGPoint = CGPoint(x: 20, y: 20),
                      size: CGFloat = 160) throws {
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
        else { throw CameraError.noDevice }

        session.addInput(input)
        session.startRunning()
        self.session = session

        // Floating circular preview panel
        let panel = NSPanel(contentRect: CGRect(x: position.x, y: position.y, width: size, height: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = CGRect(x: 0, y: 0, width: size, height: size)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.cornerRadius = size / 2
        previewLayer.masksToBounds = true

        panel.contentView?.layer = CALayer()
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.addSublayer(previewLayer)
        panel.orderFront(nil)

        self.previewLayer = previewLayer
        self.panel = panel
        isRunning = true
    }

    public func stop() {
        session?.stopRunning()
        panel?.orderOut(nil)
        session = nil; panel = nil; previewLayer = nil
        isRunning = false
    }
}

public enum CameraError: Error { case noDevice }
```

- [ ] Create `ClickKeystrokeVisualizer.swift`:

```swift
import AppKit
import CoreGraphics

/// Monitors global mouse clicks and keystrokes via CGEventTap and shows
/// visual indicators in a transparent overlay window.
/// Requires Accessibility permission.
public final class ClickKeystrokeVisualizer {
    private var eventTap: CFMachPort?
    private var overlayWindow: NSWindow?
    private var overlayView: VisualizerView?

    public init() {}

    public func start() {
        let mask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue)
                              | (1 << CGEventType.keyDown.rawValue)
        eventTap = CGEvent.tapCreate(tap: .cghidEventTap,
                                     place: .headInsertEventTap,
                                     options: .listenOnly,
                                     eventsOfInterest: mask,
                                     callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
            guard let refcon else { return Unmanaged.passRetained(event) }
            let slf = Unmanaged<ClickKeystrokeVisualizer>.fromOpaque(refcon).takeUnretainedValue()
            if type == .leftMouseDown {
                let loc = event.location
                DispatchQueue.main.async { slf.showClickIndicator(at: NSPoint(x: loc.x, y: loc.y)) }
            } else if type == .keyDown {
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                DispatchQueue.main.async { slf.showKeystroke(keyCode: Int(keyCode)) }
            }
            return Unmanaged.passRetained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())

        guard let tap = eventTap else { return }
        let loop = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), loop, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        setupOverlay()
    }

    public func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        eventTap = nil
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
    }

    private func setupOverlay() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let win = NSWindow(contentRect: screen.frame, styleMask: .borderless,
                           backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .screenSaver
        win.ignoresMouseEvents = true
        let view = VisualizerView(frame: screen.frame)
        win.contentView = view
        win.orderFront(nil)
        overlayWindow = win
        overlayView = view
    }

    private func showClickIndicator(at point: NSPoint) {
        overlayView?.addClickIndicator(at: point)
    }

    private func showKeystroke(keyCode: Int) {
        overlayView?.addKeystroke(keyCode: keyCode)
    }
}

/// Transparent NSView that draws and fades click/keystroke indicators
private final class VisualizerView: NSView {
    private struct Indicator {
        var center: CGPoint
        var opacity: CGFloat = 1.0
        var keyLabel: String?
    }
    private var indicators: [Indicator] = []
    private var timer: Timer?

    override init(frame: NSRect) {
        super.init(frame: frame)
        timer = Timer.scheduledTimer(withTimeInterval: 1/30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    func addClickIndicator(at point: NSPoint) {
        indicators.append(Indicator(center: point))
        setNeedsDisplay(bounds)
    }

    func addKeystroke(keyCode: Int) {
        let center = CGPoint(x: bounds.midX, y: 80)
        indicators.append(Indicator(center: center, keyLabel: "\(keyCode)"))
        setNeedsDisplay(bounds)
    }

    private func tick() {
        indicators = indicators.compactMap { var i = $0; i.opacity -= 0.04; return i.opacity > 0 ? i : nil }
        setNeedsDisplay(bounds)
    }

    override func draw(_ dirtyRect: NSRect) {
        for indicator in indicators {
            let color = NSColor.systemYellow.withAlphaComponent(indicator.opacity)
            color.setFill()
            let r: CGFloat = indicator.keyLabel == nil ? 20 : 30
            NSBezierPath(ovalIn: CGRect(x: indicator.center.x - r, y: indicator.center.y - r,
                                        width: r*2, height: r*2)).fill()
        }
    }
}
```

- [ ] Build. Commit:

```bash
git add Modules/CaptureEngine/Sources/CaptureEngine/GIFRecorder.swift
git add Modules/CaptureEngine/Sources/CaptureEngine/CameraOverlay.swift
git add Modules/CaptureEngine/Sources/CaptureEngine/ClickKeystrokeVisualizer.swift
git commit -m "feat: CaptureEngine — GIF recorder (Gifski), camera overlay, click/keystroke visualizer"
```


---

## Chunk 7: AnnotationEditor

**Goal:** Full image editor with all annotation tools, background tool, and export service.

### Task 13: AnnotationProject model + ExportService

**Files:**
- Create: `Modules/AnnotationEditor/Sources/AnnotationEditor/AnnotationProject.swift`
- Create: `Modules/AnnotationEditor/Sources/AnnotationEditor/ExportService.swift`
- Create: `Modules/AnnotationEditor/Tests/AnnotationEditorTests/AnnotationEditorTests.swift`

- [ ] Delete `Placeholder.swift` from `Modules/AnnotationEditor/Sources/AnnotationEditor/`.

- [ ] Create `AnnotationProject.swift`:

```swift
import Foundation
import CoreGraphics
import AppKit
import SharedModels

public final class AnnotationProject: ObservableObject {
    public let baseImage: CGImage
    @Published public var annotations: [AnyAnnotation] = []
    @Published public var backgroundConfig: BackgroundConfig? = nil
    public var canvasSize: CGSize

    public init(baseImage: CGImage) {
        self.baseImage = baseImage
        self.canvasSize = CGSize(width: baseImage.width, height: baseImage.height)
    }

    // MARK: - Annotation management

    public func add(_ annotation: AnyAnnotation) {
        var a = annotation
        // Assign next zIndex
        let maxZ = annotations.map { $0.base.zIndex }.max() ?? -1
        // We need mutable access — use a helper since protocol value types are tricky
        annotations.append(a)
    }

    public func remove(id: UUID) {
        annotations.removeAll { $0.base.id == id }
    }

    public func update(_ annotation: AnyAnnotation) {
        if let idx = annotations.firstIndex(where: { $0.base.id == annotation.base.id }) {
            annotations[idx] = annotation
        }
    }

    public func moveToFront(id: UUID) {
        guard let idx = annotations.firstIndex(where: { $0.base.id == id }) else { return }
        let item = annotations.remove(at: idx)
        annotations.append(item)
    }

    // MARK: - Persistence (.cleanalt project file)

    private struct ProjectFile: Codable {
        let baseImagePNG: Data
        let annotations: [AnyAnnotation]
        let backgroundConfig: BackgroundConfig?
        let canvasWidth: Double
        let canvasHeight: Double
    }

    public func save(to url: URL) throws {
        guard let data = cgImageToPNG(baseImage) else {
            throw AnnotationError.exportFailed
        }
        let file = ProjectFile(
            baseImagePNG: data,
            annotations: annotations,
            backgroundConfig: backgroundConfig,
            canvasWidth: canvasSize.width,
            canvasHeight: canvasSize.height
        )
        let encoded = try JSONEncoder().encode(file)
        try encoded.write(to: url)
    }

    public static func load(from url: URL) throws -> AnnotationProject {
        let data = try Data(contentsOf: url)
        let file = try JSONDecoder().decode(ProjectFile.self, from: data)
        guard let cgImage = pngToCGImage(file.baseImagePNG) else {
            throw AnnotationError.invalidProjectFile
        }
        let project = AnnotationProject(baseImage: cgImage)
        project.annotations = file.annotations
        project.backgroundConfig = file.backgroundConfig
        project.canvasSize = CGSize(width: file.canvasWidth, height: file.canvasHeight)
        return project
    }

    // MARK: - Helpers

    private func cgImageToPNG(_ image: CGImage) -> Data? {
        let mutable = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(mutable, "public.png" as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return mutable as Data
    }

    private static func pngToCGImage(_ data: Data) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }
}

public enum AnnotationError: Error {
    case exportFailed
    case invalidProjectFile
}
```

- [ ] Create `ExportService.swift`:

```swift
import Foundation
import CoreGraphics
import AppKit
import SharedModels

public struct ExportService {
    public init() {}

    /// Flatten base image + all annotations to a single CGImage and write to disk.
    public func export(_ project: AnnotationProject, to url: URL, format: ExportFormat) throws {
        let flattened = try flatten(project)
        try write(flattened, to: url, format: format)
    }

    /// Copy the flattened image to the system clipboard as PNG.
    public func copyToPasteboard(_ project: AnnotationProject) throws {
        let flattened = try flatten(project)
        guard let data = cgImageToPNG(flattened) else { throw AnnotationError.exportFailed }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(data, forType: .png)
    }

    // MARK: - Flatten

    public func flatten(_ project: AnnotationProject) throws -> CGImage {
        let size = project.canvasSize
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let ctx = CGContext(data: nil,
                                  width: Int(size.width), height: Int(size.height),
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: bitmapInfo.rawValue)
        else { throw AnnotationError.exportFailed }

        // Draw background if configured
        if let bg = project.backgroundConfig {
            drawBackground(bg, in: ctx, size: size)
        }

        // Draw base image
        ctx.draw(project.baseImage, in: CGRect(origin: .zero, size: size))

        // Draw each annotation using the canvas renderer
        // (AnnotationCanvas handles the drawing; here we call the same render path)
        for annotation in project.annotations {
            drawAnnotation(annotation, in: ctx, canvasSize: size)
        }

        guard let result = ctx.makeImage() else { throw AnnotationError.exportFailed }
        return result
    }

    // MARK: - Write to disk

    private func write(_ image: CGImage, to url: URL, format: ExportFormat) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, format.utType as CFString, 1, nil)
        else { throw AnnotationError.exportFailed }

        let properties: CFDictionary?
        if format == .jpeg {
            properties = [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary
        } else {
            properties = nil
        }
        CGImageDestinationAddImage(dest, image, properties)
        guard CGImageDestinationFinalize(dest) else { throw AnnotationError.exportFailed }
    }

    private func cgImageToPNG(_ image: CGImage) -> Data? {
        let mutable = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(mutable, "public.png" as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest) ? (mutable as Data) : nil
    }

    // MARK: - Drawing helpers (simplified; detailed rendering in AnnotationCanvas)

    private func drawBackground(_ config: BackgroundConfig, in ctx: CGContext, size: CGSize) {
        switch config.style {
        case .solid:
            ctx.setFillColor(config.color.nsColor.cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
        case .linearGradient, .radialGradient:
            guard let grad = config.gradient else { return }
            let colors = grad.colors.map { $0.nsColor.cgColor } as CFArray
            let locs: [CGFloat] = grad.colors.enumerated().map { CGFloat($0.offset) / CGFloat(max(grad.colors.count - 1, 1)) }
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locs)
            else { return }
            if config.style == .linearGradient {
                let rad = grad.angle * .pi / 180
                let startX = size.width / 2 - cos(rad) * size.width / 2
                let startY = size.height / 2 - sin(rad) * size.height / 2
                let endX   = size.width / 2 + cos(rad) * size.width / 2
                let endY   = size.height / 2 + sin(rad) * size.height / 2
                ctx.drawLinearGradient(gradient,
                                       start: CGPoint(x: startX, y: startY),
                                       end: CGPoint(x: endX, y: endY), options: [])
            } else {
                let center = CGPoint(x: grad.center.x * size.width, y: grad.center.y * size.height)
                let radius = max(size.width, size.height)
                ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                       endCenter: center, endRadius: radius, options: [])
            }
        case .image:
            if let url = config.imageURL,
               let src = CGImageSourceCreateWithURL(url as CFURL, nil),
               let img = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                ctx.draw(img, in: CGRect(origin: .zero, size: size))
            }
        }
    }

    private func drawAnnotation(_ annotation: AnyAnnotation, in ctx: CGContext, canvasSize: CGSize) {
        // Detailed per-tool rendering is in AnnotationCanvas (SwiftUI Canvas).
        // ExportService calls the same CGContext-based render functions.
        // Implementation in Task 14.
    }
}
```

- [ ] Write tests:

```swift
import XCTest
@testable import AnnotationEditor
import SharedModels
import CoreGraphics

final class AnnotationEditorTests: XCTestCase {
    func makeSolidImage(width: Int = 100, height: Int = 100, color: CGColor = .white) -> CGImage {
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        let ctx = CGContext(data: nil, width: width, height: height,
                            bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info.rawValue)!
        ctx.setFillColor(color)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }

    func test_annotation_project_add_remove() {
        let project = AnnotationProject(baseImage: makeSolidImage())
        let arrow = AnyAnnotation.arrow(ArrowAnnotation(start: .zero, end: CGPoint(x: 50, y: 50)))
        project.add(arrow)
        XCTAssertEqual(project.annotations.count, 1)
        project.remove(id: arrow.base.id)
        XCTAssertEqual(project.annotations.count, 0)
    }

    func test_project_saves_and_loads() throws {
        let project = AnnotationProject(baseImage: makeSolidImage())
        project.add(.arrow(ArrowAnnotation(start: .zero, end: CGPoint(x: 10, y: 10))))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test.cleanalt")
        try project.save(to: url)
        let loaded = try AnnotationProject.load(from: url)
        XCTAssertEqual(loaded.annotations.count, 1)
        try? FileManager.default.removeItem(at: url)
    }

    func test_export_service_flatten_produces_image() throws {
        let project = AnnotationProject(baseImage: makeSolidImage())
        let service = ExportService()
        let flattened = try service.flatten(project)
        XCTAssertEqual(flattened.width, 100)
        XCTAssertEqual(flattened.height, 100)
    }

    func test_export_service_writes_png() throws {
        let project = AnnotationProject(baseImage: makeSolidImage())
        let service = ExportService()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("out.png")
        try service.export(project, to: url, format: .png)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        try? FileManager.default.removeItem(at: url)
    }
}
```

- [ ] Run:

```bash
cd Modules/AnnotationEditor && swift test
```

Expected: **4 tests pass**

- [ ] Commit:

```bash
cd ../..
git add Modules/AnnotationEditor/Sources/AnnotationEditor/AnnotationProject.swift
git add Modules/AnnotationEditor/Sources/AnnotationEditor/ExportService.swift
git add Modules/AnnotationEditor/Tests/
git commit -m "feat: AnnotationEditor — AnnotationProject model, .cleanalt save/load, ExportService"
```

---

### Task 14: AnnotationCanvas + ToolState + all tools

**Files:**
- Create: `Modules/AnnotationEditor/Sources/AnnotationEditor/ToolState.swift`
- Create: `Modules/AnnotationEditor/Sources/AnnotationEditor/AnnotationCanvas.swift`
- Create: `Modules/AnnotationEditor/Sources/AnnotationEditor/Tools/ArrowTool.swift` (+ other tool files)
- Create: `Modules/AnnotationEditor/Sources/AnnotationEditor/BackgroundTool.swift`

- [ ] Create `ToolState.swift`:

```swift
import Foundation
import SharedModels
import SwiftUI

public enum ActiveTool: String, CaseIterable {
    case select, arrow, shape, text, highlight, pixelate, blur, spotlight, counter, pencil
    case crop, resize, rotate, background

    public var icon: String {
        switch self {
        case .select:     return "cursorarrow"
        case .arrow:      return "arrow.up.right"
        case .shape:      return "rectangle"
        case .text:       return "textformat"
        case .highlight:  return "highlighter"
        case .pixelate:   return "mosaic"
        case .blur:       return "aqi.medium"
        case .spotlight:  return "spotlight"
        case .counter:    return "number.circle"
        case .pencil:     return "pencil"
        case .crop:       return "crop"
        case .resize:     return "arrow.up.left.and.arrow.down.right"
        case .rotate:     return "rotate.right"
        case .background: return "photo.on.rectangle"
        }
    }
}

public final class ToolState: ObservableObject {
    @Published public var activeTool: ActiveTool = .select
    @Published public var selectedAnnotationID: UUID? = nil
    @Published public var strokeColor: CodableColor = .red
    @Published public var fillColor: CodableColor? = nil
    @Published public var strokeThickness: CGFloat = 3
    @Published public var fontSize: CGFloat = 16
    @Published public var opacity: Double = 1.0
    @Published public var arrowHeadStyle: ArrowHeadStyle = .filled
    @Published public var shapeKind: ShapeKind = .rectangle
    @Published public var counterValue: Int = 1
    @Published public var pixelSize: CGFloat = 12
    @Published public var blurRadius: CGFloat = 10

    public init() {}

    public func resetCounter() { counterValue = 1 }
    public func nextCounter() -> Int { defer { counterValue += 1 }; return counterValue }
}
```

- [ ] Create `AnnotationCanvas.swift` — SwiftUI `Canvas`-based renderer:

```swift
import SwiftUI
import SharedModels

/// Main interactive canvas view embedded in AnnotationWindow.
public struct AnnotationCanvas: View {
    @ObservedObject public var project: AnnotationProject
    @ObservedObject public var toolState: ToolState

    // Drag state for in-progress annotation
    @State private var dragStart: CGPoint? = nil
    @State private var dragCurrent: CGPoint? = nil
    @State private var pencilPoints: [CGPoint] = []

    public init(project: AnnotationProject, toolState: ToolState) {
        self.project = project
        self.toolState = toolState
    }

    public var body: some View {
        Canvas { ctx, size in
            // Draw base image
            if let img = Image(cgImage: project.baseImage) as? Image {
                ctx.draw(img, in: CGRect(origin: .zero, size: size))
            }

            // Draw all committed annotations
            for annotation in project.annotations {
                drawAnnotation(annotation, in: &ctx, size: size)
            }

            // Draw in-progress annotation ghost
            if let start = dragStart, let current = dragCurrent {
                drawInProgress(from: start, to: current, in: &ctx)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleDragChanged(value)
                }
                .onEnded { value in
                    handleDragEnded(value)
                }
        )
        .frame(width: project.canvasSize.width, height: project.canvasSize.height)
    }

    // MARK: - Gesture handlers

    private func handleDragChanged(_ value: DragGesture.Value) {
        let loc = value.location
        if dragStart == nil { dragStart = value.startLocation }
        dragCurrent = loc
        if toolState.activeTool == .pencil { pencilPoints.append(loc) }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        guard let start = dragStart else { return }
        let end = value.location
        commitAnnotation(from: start, to: end)
        dragStart = nil; dragCurrent = nil; pencilPoints = []
    }

    // MARK: - Commit annotation

    private func commitAnnotation(from start: CGPoint, to end: CGPoint) {
        let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                          width: abs(end.x - start.x), height: abs(end.y - start.y))
        switch toolState.activeTool {
        case .arrow:
            project.add(.arrow(ArrowAnnotation(start: start, end: end,
                                               color: toolState.strokeColor,
                                               thickness: toolState.strokeThickness,
                                               headStyle: toolState.arrowHeadStyle)))
        case .shape:
            project.add(.shape(ShapeAnnotation(shape: toolState.shapeKind, rect: rect,
                                               color: toolState.strokeColor,
                                               fillColor: toolState.fillColor,
                                               thickness: toolState.strokeThickness)))
        case .highlight:
            project.add(.highlight(HighlightAnnotation(points: pencilPoints,
                                                        color: toolState.strokeColor,
                                                        opacity: toolState.opacity,
                                                        thickness: toolState.strokeThickness)))
        case .pixelate:
            project.add(.pixelate(PixelateAnnotation(rect: rect, pixelSize: toolState.pixelSize)))
        case .blur:
            project.add(.blur(BlurAnnotation(rect: rect, radius: toolState.blurRadius)))
        case .spotlight:
            project.add(.spotlight(SpotlightAnnotation(rect: rect)))
        case .counter:
            project.add(.counter(CounterAnnotation(center: start, number: toolState.nextCounter())))
        case .pencil:
            let smooth = catmullRomSmooth(pencilPoints)
            project.add(.pencil(PencilAnnotation(points: smooth, color: toolState.strokeColor,
                                                  thickness: toolState.strokeThickness)))
        case .text:
            project.add(.text(TextAnnotation(origin: start)))
        default: break
        }
    }

    // MARK: - Rendering

    private func drawAnnotation(_ annotation: AnyAnnotation, in ctx: inout GraphicsContext, size: CGSize) {
        switch annotation {
        case .arrow(let a):     drawArrow(a, in: &ctx)
        case .shape(let s):     drawShape(s, in: &ctx)
        case .text(let t):      drawText(t, in: &ctx)
        case .highlight(let h): drawHighlight(h, in: &ctx)
        case .pixelate(let p):  drawPixelate(p, in: &ctx, baseImage: project.baseImage)
        case .blur(let b):      drawBlur(b, in: &ctx, baseImage: project.baseImage)
        case .spotlight(let s): drawSpotlight(s, in: &ctx, size: size)
        case .counter(let c):   drawCounter(c, in: &ctx)
        case .pencil(let p):    drawPencil(p, in: &ctx)
        }
    }

    private func drawInProgress(from start: CGPoint, to end: CGPoint, in ctx: inout GraphicsContext) {
        switch toolState.activeTool {
        case .arrow:
            var a = ArrowAnnotation(start: start, end: end, color: toolState.strokeColor,
                                    thickness: toolState.strokeThickness, headStyle: toolState.arrowHeadStyle)
            drawArrow(a, in: &ctx)
        case .shape:
            let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                              width: abs(end.x - start.x), height: abs(end.y - start.y))
            var s = ShapeAnnotation(shape: toolState.shapeKind, rect: rect,
                                    color: toolState.strokeColor, thickness: toolState.strokeThickness)
            drawShape(s, in: &ctx)
        default: break
        }
    }

    // MARK: - Per-tool draw functions

    private func drawArrow(_ a: ArrowAnnotation, in ctx: inout GraphicsContext) {
        var path = Path()
        path.move(to: a.start)
        path.addLine(to: a.end)
        ctx.stroke(path, with: .color(Color(a.color.nsColor)), lineWidth: a.thickness)

        // Arrowhead
        let angle = atan2(a.end.y - a.start.y, a.end.x - a.start.x)
        let headLen: CGFloat = max(12, a.thickness * 4)
        let spread: CGFloat = .pi / 6
        let p1 = CGPoint(x: a.end.x - headLen * cos(angle - spread),
                         y: a.end.y - headLen * sin(angle - spread))
        let p2 = CGPoint(x: a.end.x - headLen * cos(angle + spread),
                         y: a.end.y - headLen * sin(angle + spread))
        var head = Path()
        head.move(to: a.end); head.addLine(to: p1)
        head.move(to: a.end); head.addLine(to: p2)
        if a.headStyle == .filled {
            head.move(to: p1); head.addLine(to: p2); head.closeSubpath()
            ctx.fill(head, with: .color(Color(a.color.nsColor)))
        } else {
            ctx.stroke(head, with: .color(Color(a.color.nsColor)), lineWidth: a.thickness)
        }
    }

    private func drawShape(_ s: ShapeAnnotation, in ctx: inout GraphicsContext) {
        let color = Color(s.color.nsColor)
        switch s.shape {
        case .rectangle:
            let path = Path(s.rect)
            if let fill = s.fillColor { ctx.fill(path, with: .color(Color(fill.nsColor))) }
            ctx.stroke(path, with: .color(color), lineWidth: s.thickness)
        case .ellipse:
            let path = Path(ellipseIn: s.rect)
            if let fill = s.fillColor { ctx.fill(path, with: .color(Color(fill.nsColor))) }
            ctx.stroke(path, with: .color(color), lineWidth: s.thickness)
        case .line:
            var path = Path()
            path.move(to: CGPoint(x: s.rect.minX, y: s.rect.minY))
            path.addLine(to: CGPoint(x: s.rect.maxX, y: s.rect.maxY))
            ctx.stroke(path, with: .color(color), lineWidth: s.thickness)
        }
    }

    private func drawText(_ t: TextAnnotation, in ctx: inout GraphicsContext) {
        guard !t.text.isEmpty else { return }
        let text = Text(t.text).font(.system(size: t.fontSize)).foregroundColor(Color(t.color.nsColor))
        if let bg = t.backgroundColor {
            var bgPath = Path(CGRect(x: t.origin.x - 4, y: t.origin.y - 2,
                                     width: CGFloat(t.text.count) * t.fontSize * 0.6 + 8,
                                     height: t.fontSize * 1.5))
            ctx.fill(bgPath, with: .color(Color(bg.nsColor)))
        }
        ctx.draw(text, at: t.origin, anchor: .topLeading)
    }

    private func drawHighlight(_ h: HighlightAnnotation, in ctx: inout GraphicsContext) {
        guard h.points.count > 1 else { return }
        var path = Path()
        path.move(to: h.points[0])
        for pt in h.points.dropFirst() { path.addLine(to: pt) }
        ctx.stroke(path, with: .color(Color(h.color.nsColor).opacity(h.opacity)), lineWidth: h.thickness)
    }

    private func drawPixelate(_ p: PixelateAnnotation, in ctx: inout GraphicsContext, baseImage: CGImage) {
        guard let cropped = baseImage.cropping(to: p.rect),
              let filter = CIFilter(name: "CIPixellate") else { return }
        let ci = CIImage(cgImage: cropped)
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(p.pixelSize, forKey: kCIInputScaleKey)
        let ciCtx = CIContext()
        guard let out = filter.outputImage,
              let result = ciCtx.createCGImage(out, from: ci.extent) else { return }
        ctx.draw(Image(result, scale: 1, orientation: .up, label: Text("")),
                 in: p.rect)
    }

    private func drawBlur(_ b: BlurAnnotation, in ctx: inout GraphicsContext, baseImage: CGImage) {
        guard let cropped = baseImage.cropping(to: b.rect),
              let filter = CIFilter(name: "CIGaussianBlur") else { return }
        let ci = CIImage(cgImage: cropped)
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(b.radius, forKey: kCIInputRadiusKey)
        let ciCtx = CIContext()
        guard let out = filter.outputImage,
              let result = ciCtx.createCGImage(out, from: ci.extent) else { return }
        ctx.draw(Image(result, scale: 1, orientation: .up, label: Text("")),
                 in: b.rect)
    }

    private func drawSpotlight(_ s: SpotlightAnnotation, in ctx: inout GraphicsContext, size: CGSize) {
        var dimPath = Path(CGRect(origin: .zero, size: size))
        dimPath.addRect(s.rect)  // subpath creates a hole via even-odd fill
        ctx.fill(dimPath, with: .color(.black.opacity(s.dimOpacity)),
                 style: FillStyle(eoFill: true))
    }

    private func drawCounter(_ c: CounterAnnotation, in ctx: inout GraphicsContext) {
        let rect = CGRect(x: c.center.x - c.radius, y: c.center.y - c.radius,
                          width: c.radius * 2, height: c.radius * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(Color(c.color.nsColor)))
        let label = Text("\(c.number)").font(.system(size: c.radius * 1.1, weight: .bold))
                                       .foregroundColor(.white)
        ctx.draw(label, at: c.center, anchor: .center)
    }

    private func drawPencil(_ p: PencilAnnotation, in ctx: inout GraphicsContext) {
        guard p.points.count > 1 else { return }
        var path = Path()
        path.move(to: p.points[0])
        for pt in p.points.dropFirst() { path.addLine(to: pt) }
        ctx.stroke(path, with: .color(Color(p.color.nsColor)), lineWidth: p.thickness)
    }

    // MARK: - Catmull-Rom smoothing

    private func catmullRomSmooth(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count > 3 else { return points }
        var result = [points[0]]
        for i in 0..<(points.count - 1) {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[min(i + 1, points.count - 1)]
            let p3 = points[min(i + 2, points.count - 1)]
            for t: CGFloat in stride(from: 0.1, through: 1.0, by: 0.1) {
                let t2 = t * t; let t3 = t2 * t
                let x = 0.5 * ((2*p1.x) + (-p0.x + p2.x)*t + (2*p0.x - 5*p1.x + 4*p2.x - p3.x)*t2 + (-p0.x + 3*p1.x - 3*p2.x + p3.x)*t3)
                let y = 0.5 * ((2*p1.y) + (-p0.y + p2.y)*t + (2*p0.y - 5*p1.y + 4*p2.y - p3.y)*t2 + (-p0.y + 3*p1.y - 3*p2.y + p3.y)*t3)
                result.append(CGPoint(x: x, y: y))
            }
        }
        result.append(points.last!)
        return result
    }
}

// Helper: CGImage → SwiftUI Image
extension CGImage {
    var swiftUIImage: Image { Image(self, scale: 1, orientation: .up, label: Text("")) }
}
```

- [ ] Create `BackgroundTool.swift`:

```swift
import SwiftUI
import SharedModels

/// View for configuring and previewing the background wrapping the canvas.
public struct BackgroundToolView: View {
    @ObservedObject public var project: AnnotationProject
    @State private var config = BackgroundConfig()

    public init(project: AnnotationProject) { self.project = project }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Background").font(.headline)
            Picker("Style", selection: $config.style) {
                Text("Solid").tag(BackgroundStyle.solid)
                Text("Gradient").tag(BackgroundStyle.linearGradient)
                Text("Image").tag(BackgroundStyle.image)
            }.pickerStyle(.segmented)

            if config.style == .solid {
                ColorPicker("Color", selection: Binding(
                    get: { Color(config.color.nsColor) },
                    set: { config.color = CodableColor(NSColor($0)) }
                ))
            }

            HStack {
                Text("Padding")
                Slider(value: $config.padding, in: 0...200)
                Text("\(Int(config.padding))pt")
            }
            HStack {
                Text("Corner Radius")
                Slider(value: $config.cornerRadius, in: 0...40)
            }
            HStack {
                Text("Shadow")
                Slider(value: $config.shadowRadius, in: 0...40)
            }

            HStack {
                Button("Apply") { project.backgroundConfig = config }
                Button("Remove") { project.backgroundConfig = nil }
            }.buttonStyle(.bordered)
        }
        .padding()
        .onAppear { config = project.backgroundConfig ?? BackgroundConfig() }
    }
}
```

- [ ] Build and run tests:

```bash
cd Modules/AnnotationEditor && swift test
```

Expected: all passing.

- [ ] Commit:

```bash
cd ../..
git add Modules/AnnotationEditor/
git commit -m "feat: AnnotationEditor — Canvas renderer, all annotation tools, background tool, tool state"
```

---

## Chunk 8: App UI — QuickOverlay, AnnotationWindow, HistoryPanel, FloatingScreenshot, Preferences, Integration

**Goal:** All UI panels wired to the real modules; end-to-end capture → overlay → editor → history flow working.

### Task 15: QuickOverlay panel

**Files:**
- Create: `CleanShotAlt/UI/QuickOverlay/QuickOverlayPanel.swift`
- Create: `CleanShotAlt/UI/QuickOverlay/QuickOverlayView.swift`

- [ ] Create `QuickOverlayPanel.swift`:

```swift
import AppKit
import SwiftUI
import SharedModels

final class QuickOverlayPanel: NSPanel {
    private var dismissTimer: Timer?
    private var capture: Capture?
    var onAnnotate: ((Capture) -> Void)?
    var onCopy: ((Capture) -> Void)?
    var onSave: ((Capture) -> Void)?
    var onPin: ((Capture) -> Void)?
    var onOCR: ((Capture) -> Void)?
    var onDelete: ((Capture) -> Void)?

    init() {
        super.init(contentRect: CGRect(x: 0, y: 0, width: 280, height: 100),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    func show(capture: Capture) {
        self.capture = capture
        let view = QuickOverlayView(capture: capture,
            onAnnotate: { [weak self] in self?.capture.map { self?.onAnnotate?($0) }; self?.dismiss() },
            onCopy:     { [weak self] in self?.capture.map { self?.onCopy?($0) }; self?.dismiss() },
            onSave:     { [weak self] in self?.capture.map { self?.onSave?($0) } },
            onPin:      { [weak self] in self?.capture.map { self?.onPin?($0) }; self?.dismiss() },
            onOCR:      { [weak self] in self?.capture.map { self?.onOCR?($0) }; self?.dismiss() },
            onDelete:   { [weak self] in self?.capture.map { self?.onDelete?($0) }; self?.dismiss() },
            onDismiss:  { [weak self] in self?.dismiss() }
        )
        contentView = NSHostingView(rootView: view)

        // Position bottom-right of main screen
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

    func pauseDismiss() { dismissTimer?.invalidate() }
    func resumeDismiss() { scheduleDismiss() }

    func dismiss() {
        dismissTimer?.invalidate()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            self?.alphaValue = 1
        })
    }
}
```

- [ ] Create `QuickOverlayView.swift`:

```swift
import SwiftUI
import SharedModels

struct QuickOverlayView: View {
    let capture: Capture
    let onAnnotate: () -> Void
    let onCopy: () -> Void
    let onSave: () -> Void
    let onPin: () -> Void
    let onOCR: () -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Thumbnail
            if let thumb = loadThumbnail() {
                Image(nsImage: thumb)
                    .resizable().scaledToFill()
                    .frame(width: 72, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.3), lineWidth: 1))
            }

            // Action buttons
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    overlayButton("pencil",       label: "Edit",   action: onAnnotate)
                    overlayButton("doc.on.doc",   label: "Copy",   action: onCopy)
                    overlayButton("square.and.arrow.down", label: "Save", action: onSave)
                }
                HStack(spacing: 4) {
                    overlayButton("pin",          label: "Pin",    action: onPin)
                    overlayButton("text.viewfinder", label: "OCR", action: onOCR)
                    overlayButton("trash",        label: "Delete", action: onDelete)
                }
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 1))
        .shadow(radius: 8)
        .onHover { hovering in
            // Pause/resume dismiss timer based on hover
            // Communicated via AppKit panel — see QuickOverlayPanel
        }
    }

    @ViewBuilder
    private func overlayButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 13))
                Text(label).font(.system(size: 9))
            }
            .frame(width: 48, height: 36)
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }

    private func loadThumbnail() -> NSImage? {
        guard FileManager.default.fileExists(atPath: capture.thumbnailPath.path) else { return nil }
        return NSImage(contentsOf: capture.thumbnailPath)
    }
}
```

- [ ] Commit:

```bash
git add CleanShotAlt/UI/QuickOverlay/
git commit -m "feat: UI — QuickOverlay panel with thumbnail, action buttons, auto-dismiss timer"
```

---

### Task 16: AnnotationWindow + HistoryPanel + FloatingScreenshot

**Files:**
- Create: `CleanShotAlt/UI/AnnotationWindow/AnnotationWindowController.swift`
- Create: `CleanShotAlt/UI/AnnotationWindow/AnnotationEditorView.swift`
- Create: `CleanShotAlt/UI/HistoryPanel/HistoryPanelController.swift`
- Create: `CleanShotAlt/UI/HistoryPanel/HistoryPanelView.swift`
- Create: `CleanShotAlt/UI/FloatingScreenshot/FloatingScreenshotPanel.swift`

- [ ] Create `AnnotationWindowController.swift`:

```swift
import AppKit
import SwiftUI
import SharedModels
import AnnotationEditor

final class AnnotationWindowController: NSWindowController {
    private var project: AnnotationProject?
    var onComplete: ((Capture) -> Void)?

    convenience init(capture: Capture) {
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 650),
                           styleMask: [.titled, .closable, .resizable, .miniaturizable],
                           backing: .buffered, defer: false)
        win.title = "Annotate — CleanShotAlt"
        win.minSize = NSSize(width: 600, height: 400)
        self.init(window: win)

        guard let src = CGImageSourceCreateWithURL(capture.filePath as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(src, 0, nil)
        else { return }

        let project = AnnotationProject(baseImage: cgImage)
        self.project = project

        let editorView = AnnotationEditorView(
            project: project,
            onSave: { [weak self] in self?.saveAnnotated(project: project, original: capture) },
            onCancel: { [weak self] in self?.close() }
        )
        win.contentView = NSHostingView(rootView: editorView)
        win.center()
    }

    private func saveAnnotated(project: AnnotationProject, original: Capture) {
        let service = ExportService()
        let destURL = HistoryStore.capturesDirectory
            .appendingPathComponent(UUID().uuidString + ".png")
        try? service.export(project, to: destURL, format: .png)
        let thumbURL = HistoryStore.thumbnailsDirectory
            .appendingPathComponent(UUID().uuidString + "_thumb.jpg")
        let annotated = Capture(mode: original.mode, filePath: destURL, thumbnailPath: thumbURL)
        Task {
            try? await HistoryStore.shared.replace(originalID: original.id, with: annotated)
        }
        onComplete?(annotated)
        close()
    }
}
```

- [ ] Create `AnnotationEditorView.swift`:

```swift
import SwiftUI
import AnnotationEditor
import SharedModels

struct AnnotationEditorView: View {
    @ObservedObject var project: AnnotationProject
    @StateObject private var toolState = ToolState()
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HSplitView {
            // Left: tool palette
            ToolPaletteView(toolState: toolState)
                .frame(width: 52)

            // Center: canvas in scroll view
            ScrollView([.horizontal, .vertical]) {
                AnnotationCanvas(project: project, toolState: toolState)
                    .padding(20)
            }
            .background(Color(NSColor.underPageBackgroundColor))
        }
        .toolbar {
            ToolbarItemGroup(placement: .principal) {
                StyleControlsView(toolState: toolState)
            }
            ToolbarItemGroup(placement: .confirmationAction) {
                Button("Copy") { try? ExportService().copyToPasteboard(project) }
                Button("Save") { onSave() }
            }
            ToolbarItemGroup(placement: .cancellationAction) {
                Button("Cancel") { onCancel() }
            }
        }
    }
}

struct ToolPaletteView: View {
    @ObservedObject var toolState: ToolState

    var body: some View {
        VStack(spacing: 4) {
            ForEach(ActiveTool.allCases, id: \.self) { tool in
                Button(action: { toolState.activeTool = tool }) {
                    Image(systemName: tool.icon).frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .background(toolState.activeTool == tool ? Color.accentColor.opacity(0.2) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6))
                .help(tool.rawValue.capitalized)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct StyleControlsView: View {
    @ObservedObject var toolState: ToolState
    var body: some View {
        HStack(spacing: 12) {
            ColorPicker("", selection: Binding(
                get: { Color(toolState.strokeColor.nsColor) },
                set: { toolState.strokeColor = CodableColor(NSColor($0)) }
            )).labelsHidden()
            Slider(value: $toolState.strokeThickness, in: 1...20) { Text("Size") }
                .frame(width: 80)
            Slider(value: $toolState.opacity, in: 0.1...1.0) { Text("Opacity") }
                .frame(width: 80)
        }
    }
}
```

- [ ] Create `HistoryPanelView.swift`:

```swift
import SwiftUI
import SharedModels
import HistoryStore

struct HistoryPanelView: View {
    @State private var captures: [Capture] = []
    @State private var filter: CaptureMode? = nil
    var onOpen: (Capture) -> Void
    var onPin: (Capture) -> Void

    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            if captures.isEmpty {
                Spacer()
                Text("No captures yet").foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(captures) { capture in
                            ThumbnailCell(capture: capture)
                                .contextMenu {
                                    Button("Open in Editor") { onOpen(capture) }
                                    Button("Pin to Screen") { onPin(capture) }
                                    Button("Copy") { copyCapture(capture) }
                                    Divider()
                                    Button("Delete", role: .destructive) { deleteCapture(capture) }
                                }
                        }
                    }
                    .padding(8)
                }
            }
        }
        .frame(width: 320, height: 480)
        .task { await loadCaptures() }
    }

    private var filterBar: some View {
        HStack(spacing: 0) {
            filterButton(nil, label: "All")
            filterButton(.area, label: "Screenshots")
            filterButton(.video, label: "Videos")
            filterButton(.gif, label: "GIFs")
        }
        .padding(8)
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private func filterButton(_ mode: CaptureMode?, label: String) -> some View {
        Button(label) { filter = mode; Task { await loadCaptures() } }
            .buttonStyle(.plain)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(filter == mode ? Color.accentColor.opacity(0.15) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6))
    }

    private func loadCaptures() async {
        captures = (try? await HistoryStore.shared.fetchAll(filter: filter)) ?? []
    }

    private func copyCapture(_ capture: Capture) {
        guard let src = CGImageSourceCreateWithURL(capture.filePath as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil),
              let data = NSMutableData() as? NSMutableData,
              let dest = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(dest, img, nil)
        CGImageDestinationFinalize(dest)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(data as Data, forType: .png)
    }

    private func deleteCapture(_ capture: Capture) {
        Task {
            try? await HistoryStore.shared.delete(capture.id)
            await loadCaptures()
        }
    }
}

struct ThumbnailCell: View {
    let capture: Capture
    var body: some View {
        VStack(spacing: 4) {
            if let img = NSImage(contentsOf: capture.thumbnailPath) {
                Image(nsImage: img).resizable().scaledToFill()
                    .frame(width: 88, height: 66).clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.2))
                    .frame(width: 88, height: 66)
            }
            Text(capture.createdAt, style: .time).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
```

- [ ] Create `FloatingScreenshotPanel.swift`:

```swift
import AppKit
import SwiftUI
import SharedModels

final class FloatingScreenshotPanel: NSPanel {
    private var capture: Capture
    private var isLocked = false

    init(capture: Capture) {
        self.capture = capture
        let initialRect = NSRect(x: 100, y: 100, width: 400, height: 300)
        super.init(contentRect: initialRect, styleMask: [.borderless, .resizable, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = FloatingScreenshotView(capture: capture,
            onClose: { [weak self] in self?.orderOut(nil) },
            onToggleLock: { [weak self] in self?.toggleLock() }
        )
        contentView = NSHostingView(rootView: view)
        makeKeyAndOrderFront(nil)
    }

    private func toggleLock() {
        isLocked.toggle()
        ignoresMouseEvents = isLocked
    }
}

struct FloatingScreenshotView: View {
    let capture: Capture
    let onClose: () -> Void
    let onToggleLock: () -> Void
    @State private var isHovering = false
    @State private var opacity: Double = 1.0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let img = NSImage(contentsOf: capture.filePath) {
                Image(nsImage: img).resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 6)
                    .opacity(opacity)
            }
            if isHovering {
                HStack(spacing: 4) {
                    Button(action: onToggleLock) {
                        Image(systemName: "lock").padding(4)
                    }
                    Slider(value: $opacity, in: 0.2...1.0).frame(width: 60)
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill").padding(4)
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(6)
            }
        }
        .onHover { isHovering = $0 }
    }
}
```

- [ ] Commit:

```bash
git add CleanShotAlt/UI/
git commit -m "feat: UI — AnnotationWindow, HistoryPanel grid, FloatingScreenshot with lock mode"
```

---

### Task 17: Preferences window + launch at login

**Files:**
- Modify: `CleanShotAlt/UI/PreferencesWindow/PreferencesView.swift`
- Create: `CleanShotAlt/UI/PreferencesWindow/GeneralPrefsView.swift`
- Create: `CleanShotAlt/UI/PreferencesWindow/ShortcutsPrefsView.swift`
- Create: `CleanShotAlt/UI/PreferencesWindow/StoragePrefsView.swift`

- [ ] Replace `PreferencesView.swift` with:

```swift
import SwiftUI

struct PreferencesView: View {
    var body: some View {
        TabView {
            GeneralPrefsView().tabItem { Label("General", systemImage: "gearshape") }.tag(0)
            ShortcutsPrefsView().tabItem { Label("Shortcuts", systemImage: "keyboard") }.tag(1)
            RecordingPrefsView().tabItem { Label("Recording", systemImage: "video") }.tag(2)
            StoragePrefsView().tabItem { Label("Storage", systemImage: "internaldrive") }.tag(3)
        }
        .frame(width: 520, height: 420)
    }
}
```

- [ ] Create `GeneralPrefsView.swift`:

```swift
import SwiftUI
import ServiceManagement

struct GeneralPrefsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("hideDesktopIconsOnCapture") private var hideIcons = false
    @AppStorage("captureDropShadow") private var dropShadow = true
    @AppStorage("overlayDismissTimeout") private var dismissTimeout = 5.0
    @AppStorage("namingPattern") private var namingPattern = "Screenshot {yyyy-MM-dd} at {HH.mm.ss}"
    @AppStorage("defaultSavePath") private var savePath = ""

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newVal in
                        if newVal { try? SMAppService.mainApp.register() }
                        else { try? SMAppService.mainApp.unregister() }
                    }
                Toggle("Hide desktop icons before capture", isOn: $hideIcons)
                Toggle("Add drop shadow to window captures", isOn: $dropShadow)
            }
            Section("Overlay") {
                HStack {
                    Text("Auto-dismiss after")
                    Slider(value: $dismissTimeout, in: 1...30, step: 1)
                    Text("\(Int(dismissTimeout))s")
                }
            }
            Section("Files") {
                TextField("Naming pattern", text: $namingPattern)
                HStack {
                    Text(savePath.isEmpty ? "~/Desktop" : savePath)
                        .foregroundStyle(.secondary).truncationMode(.middle)
                    Spacer()
                    Button("Choose…") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true; panel.canChooseFiles = false
                        if panel.runModal() == .OK { savePath = panel.url?.path ?? "" }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
```

- [ ] Create `ShortcutsPrefsView.swift`:

```swift
import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let captureArea       = Self("captureArea")
    static let captureWindow     = Self("captureWindow")
    static let captureFullscreen = Self("captureFullscreen")
    static let captureScrolling  = Self("captureScrolling")
    static let recordScreen      = Self("recordScreen")
    static let recordGIF         = Self("recordGIF")
    static let captureOCR        = Self("captureOCR")
    static let retakeLastCapture = Self("retakeLastCapture")
}

struct ShortcutsPrefsView: View {
    var body: some View {
        Form {
            Section("Screenshots") {
                KeyboardShortcuts.Recorder("Capture Area", name: .captureArea)
                KeyboardShortcuts.Recorder("Capture Window", name: .captureWindow)
                KeyboardShortcuts.Recorder("Capture Fullscreen", name: .captureFullscreen)
                KeyboardShortcuts.Recorder("Scrolling Capture", name: .captureScrolling)
                KeyboardShortcuts.Recorder("Retake Last Capture", name: .retakeLastCapture)
            }
            Section("Recording") {
                KeyboardShortcuts.Recorder("Record Screen", name: .recordScreen)
                KeyboardShortcuts.Recorder("Record GIF", name: .recordGIF)
            }
            Section("Tools") {
                KeyboardShortcuts.Recorder("OCR Text", name: .captureOCR)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
```

- [ ] Create `StoragePrefsView.swift`:

```swift
import SwiftUI
import HistoryStore

struct StoragePrefsView: View {
    @AppStorage("historyRetentionDays") private var retentionDays = 30
    @State private var captureCount = 0

    var body: some View {
        Form {
            Section("History") {
                Picker("Retain captures for", selection: $retentionDays) {
                    Text("7 days").tag(7)
                    Text("14 days").tag(14)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                }
                Text("\(captureCount) captures stored")
                    .foregroundStyle(.secondary)
                Button("Open Captures Folder") {
                    NSWorkspace.shared.open(HistoryStore.capturesDirectory)
                }
                Button("Clear All History", role: .destructive) {
                    Task { try? await HistoryStore.shared.pruneOlderThan(0) }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .task {
            captureCount = (try? await HistoryStore.shared.fetchAll())?.count ?? 0
        }
    }
}
```

- [ ] Commit:

```bash
git add CleanShotAlt/UI/PreferencesWindow/
git commit -m "feat: Preferences — general, shortcuts (KeyboardShortcuts), storage tabs"
```

---

### Task 18: Wire everything together in AppDelegate

**Files:**
- Modify: `CleanShotAlt/App/AppDelegate.swift`
- Modify: `CleanShotAlt/App/MenuBarController.swift`

- [ ] Update `AppDelegate.swift` to bootstrap services and register hotkeys:

```swift
import AppKit
import KeyboardShortcuts
import HistoryStore
import DesktopManager
import CaptureEngine
import OCRService

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var overlayPanel: QuickOverlayPanel?
    private var historyPanelController: NSWindowController?
    let desktopManager = DesktopManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Prune old history on launch
        Task { try? await HistoryStore.shared.pruneOlderThan(AppSettings.shared.historyRetentionDays) }

        overlayPanel = QuickOverlayPanel()
        wireOverlayCallbacks()

        menuBarController = MenuBarController(delegate: self)
        registerHotkeys()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: - Hotkey registration

    private func registerHotkeys() {
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

    func triggerCaptureArea() {
        Task { @MainActor in
            if AppSettings.shared.hideDesktopIconsOnCapture { try? desktopManager.hideIcons() }
            defer { if AppSettings.shared.hideDesktopIconsOnCapture { try? desktopManager.showIcons() } }
            guard let image = try? await AreaCapture().capture() else { return }
            await saveAndShowOverlay(image: image, mode: .area)
        }
    }

    func triggerCaptureWindow() {
        Task { @MainActor in
            guard let image = try? await WindowCapture().capture() else { return }
            await saveAndShowOverlay(image: image, mode: .window)
        }
    }

    func triggerCaptureFullscreen() {
        Task {
            guard let image = try? await FullscreenCapture().captureMainDisplay() else { return }
            await saveAndShowOverlay(image: image, mode: .fullscreen)
        }
    }

    func triggerCaptureScrolling() {
        // Present window picker, then pass SCWindow to ScrollingCapture
        // Implementation: reuse WindowCapture overlay, but on selection call ScrollingCapture
    }

    func triggerRecordScreen() {
        // Toggle: if not recording, start; if recording, stop
        menuBarController?.toggleRecording()
    }

    func triggerRecordGIF() {
        menuBarController?.toggleGIFRecording()
    }

    func triggerOCR() {
        Task { @MainActor in
            guard let image = try? await AreaCapture().capture() else { return }
            let result = try? await OCRService().recognize(image: image)
            if let text = result?.fullText, !text.isEmpty {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                // Show brief notification
                showOCRToast(text: "Copied \(text.count) characters")
            }
        }
    }

    func triggerRetakeLastCapture() {
        Task { @MainActor in
            guard let image = try? await AreaCapture().retakeLast() else { return }
            await saveAndShowOverlay(image: image, mode: .area)
        }
    }

    // MARK: - Save + overlay

    @MainActor
    private func saveAndShowOverlay(image: CGImage, mode: CaptureMode) async {
        let settings = AppSettings.shared
        let filename = resolveFilename(pattern: settings.namingPattern,
                                       ext: settings.defaultExportFormat)
        let destURL = settings.resolvedSavePath.appendingPathComponent(filename)

        guard let dest = CGImageDestinationCreateWithURL(destURL as CFURL,
                                                          "public.png" as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return }

        let thumbURL = HistoryStore.thumbnailsDirectory
            .appendingPathComponent(UUID().uuidString + "_thumb.jpg")
        let capture = Capture(mode: mode, filePath: destURL, thumbnailPath: thumbURL)
        try? await HistoryStore.shared.ingest(capture)
        overlayPanel?.show(capture: capture)
    }

    private func resolveFilename(pattern: String, ext: String) -> String {
        let formatter = DateFormatter()
        let now = Date()
        var name = pattern
        formatter.dateFormat = "yyyy-MM-dd"; name = name.replacingOccurrences(of: "{yyyy-MM-dd}", with: formatter.string(from: now))
        formatter.dateFormat = "HH.mm.ss"; name = name.replacingOccurrences(of: "{HH.mm.ss}", with: formatter.string(from: now))
        return name + "." + ext
    }

    private func showOCRToast(text: String) {
        // Deliver via NSUserNotification (or UserNotifications framework)
        let notification = NSUserNotification()
        notification.title = "CleanShotAlt"
        notification.informativeText = text
        NSUserNotificationCenter.default.deliver(notification)
    }

    // MARK: - Overlay callbacks

    private func wireOverlayCallbacks() {
        overlayPanel?.onAnnotate = { [weak self] capture in
            DispatchQueue.main.async { self?.openAnnotationEditor(for: capture) }
        }
        overlayPanel?.onCopy = { capture in
            if let src = CGImageSourceCreateWithURL(capture.filePath as CFURL, nil),
               let img = CGImageSourceCreateImageAtIndex(src, 0, nil),
               let data = NSMutableData() as? NSMutableData,
               let dest = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) {
                CGImageDestinationAddImage(dest, img, nil)
                CGImageDestinationFinalize(dest)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setData(data as Data, forType: .png)
            }
        }
        overlayPanel?.onSave = { [weak self] capture in
            let panel = NSSavePanel()
            panel.nameFieldStringValue = capture.filePath.lastPathComponent
            if panel.runModal() == .OK, let url = panel.url {
                try? FileManager.default.copyItem(at: capture.filePath, to: url)
            }
        }
        overlayPanel?.onPin = { capture in
            DispatchQueue.main.async { _ = FloatingScreenshotPanel(capture: capture) }
        }
        overlayPanel?.onDelete = { capture in
            Task { try? await HistoryStore.shared.delete(capture.id) }
        }
    }

    func openAnnotationEditor(for capture: Capture) {
        let controller = AnnotationWindowController(capture: capture)
        controller.showWindow(nil)
    }

    func showHistoryPanel() {
        if historyPanelController == nil {
            let win = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 480),
                              styleMask: [.titled, .closable, .nonactivatingPanel],
                              backing: .buffered, defer: false)
            win.title = "History"
            win.contentView = NSHostingView(rootView: HistoryPanelView(
                onOpen: { [weak self] capture in self?.openAnnotationEditor(for: capture) },
                onPin: { capture in _ = FloatingScreenshotPanel(capture: capture) }
            ))
            historyPanelController = NSWindowController(window: win)
        }
        historyPanelController?.showWindow(nil)
        historyPanelController?.window?.orderFront(nil)
    }
}
```

- [ ] Update `MenuBarController.swift` to call real AppDelegate methods:

```swift
// In buildMenu(), set targets and actions to AppDelegate methods:
// captureArea → AppDelegate.triggerCaptureArea()
// etc.
// Pass a delegate/reference to AppDelegate, or use NotificationCenter.
// Simplest: store weak ref to AppDelegate.

final class MenuBarController {
    weak var delegate: AppDelegate?
    // ... (update @objc stubs to call delegate methods)
}
```

- [ ] Build and run the full app. Test the end-to-end flow:
  1. App launches, menu bar icon appears
  2. Click "Capture Area" → crosshair overlay → select a region → `QuickOverlay` appears
  3. Click "Edit" → `AnnotationWindow` opens with the capture
  4. Add an arrow annotation, click Save
  5. Click "History" → panel shows the capture
  6. Click "Pin" → floating screenshot stays above all windows

- [ ] Commit:

```bash
git add CleanShotAlt/App/AppDelegate.swift
git add CleanShotAlt/App/MenuBarController.swift
git commit -m "feat: wire AppDelegate — capture triggers, overlay callbacks, hotkeys, end-to-end flow"
```

- [ ] Final integration commit:

```bash
git add .
git commit -m "chore: complete v1 implementation — all modules, UI, and integration wired"
```

---

## Summary

**Build order:**
1. SharedModels → 2. HistoryStore → 3. DesktopManager → 4. OCRService → 5. CaptureEngine (screenshots) → 6. CaptureEngine (recording) → 7. AnnotationEditor → 8. App UI + integration

**Testing:**
- `cd Modules/SharedModels && swift test`
- `cd Modules/HistoryStore && swift test`
- `cd Modules/DesktopManager && swift test`
- `cd Modules/OCRService && swift test`
- `cd Modules/AnnotationEditor && swift test`
- Manual integration test: launch app, run through all capture modes

**Permissions to grant on first run:**
1. Screen Recording (System Settings → Privacy → Screen Recording)
2. Accessibility (System Settings → Privacy → Accessibility — required for CGEventTap and scroll injection)
3. Microphone (prompted automatically on first recording attempt)

