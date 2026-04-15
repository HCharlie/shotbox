# CleanShot Alternative — Design Spec
**Date:** 2026-04-14
**Status:** Approved
**Platform:** macOS 13+ (Ventura)
**Language:** Swift (SwiftUI + AppKit where needed)
**Distribution:** Direct `.dmg` (no App Store sandboxing)
**Cloud features:** Out of scope

---

## 1. Overview

A local, open-source macOS screenshot and screen recording tool that replicates the core feature set of CleanShot X without any cloud or subscription dependency. All data stays on device. The app lives in the menu bar and is driven primarily by global keyboard shortcuts.

---

## 2. Architecture

### App Target: `CleanShotAlt`

```
CleanShotAlt/
├── App/
│   ├── AppDelegate.swift          # NSApplicationDelegate, menu bar setup, hotkey registration
│   ├── MenuBarController.swift    # NSStatusItem, dropdown menu
│   ├── HotkeyManager.swift        # Global hotkey registration (Carbon / CGEventTap)
│   └── Settings.swift             # UserDefaults-backed app settings
├── Modules/                        # Swift Package Manager local packages
│   ├── CaptureEngine/
│   ├── AnnotationEditor/
│   ├── OCRService/
│   ├── HistoryStore/
│   ├── DesktopManager/
│   └── SharedModels/
└── UI/
    ├── QuickOverlay/
    ├── AnnotationWindow/
    ├── HistoryPanel/
    ├── FloatingScreenshot/
    └── PreferencesWindow/
```

### Local SPM Packages

Each module is a local Swift Package under `Modules/`. The app target depends on all of them. Modules only depend on `SharedModels` and Apple frameworks — no module depends on another module (except SharedModels).

---

## 3. Module Specifications

### 3.1 `SharedModels`

Common types shared across all modules.

```swift
// Core capture record
// filePath and thumbnailPath are stored as absolute path strings in the database
// (not bookmark data) — sufficient for single-user local use.
struct Capture: Identifiable, Codable {
    let id: UUID
    let mode: CaptureMode
    let createdAt: Date
    let filePath: URL          // absolute file URL; serialized as path string in DB
    let thumbnailPath: URL     // absolute file URL; serialized as path string in DB
    var exportFormat: ExportFormat
}

enum CaptureMode: String, Codable {
    case area, window, fullscreen, scrolling, video, gif
}

enum ExportFormat: String, Codable, CaseIterable {
    case png, jpeg, tiff, webp, gif, mp4
}

// Annotation object protocol
protocol AnnotationObject: Identifiable, Codable {
    var id: UUID { get }
    var zIndex: Int { get set }
}

// Concrete annotation types (all Codable)
struct ArrowAnnotation: AnnotationObject { ... }
struct ShapeAnnotation: AnnotationObject { ... }   // rect, ellipse, line
struct TextAnnotation: AnnotationObject { ... }
struct HighlightAnnotation: AnnotationObject { ... }
struct PixelateAnnotation: AnnotationObject { ... }
struct BlurAnnotation: AnnotationObject { ... }
struct SpotlightAnnotation: AnnotationObject { ... }
struct CounterAnnotation: AnnotationObject { ... }
struct PencilAnnotation: AnnotationObject { ... }  // bezier path

// Codable wrapper for heterogeneous annotation arrays.
// Swift cannot synthesize Codable for [any AnnotationObject] existentials,
// so we use a tagged-union enum that the JSON encoder/decoder can handle.
enum AnyAnnotation: Codable {
    case arrow(ArrowAnnotation)
    case shape(ShapeAnnotation)
    case text(TextAnnotation)
    case highlight(HighlightAnnotation)
    case pixelate(PixelateAnnotation)
    case blur(BlurAnnotation)
    case spotlight(SpotlightAnnotation)
    case counter(CounterAnnotation)
    case pencil(PencilAnnotation)

    // Custom encode/decode uses a "type" discriminator key
    private enum TypeKey: String, Codable { case arrow, shape, text, highlight, pixelate, blur, spotlight, counter, pencil }
    // (full encode/decode implementation in AnnotationEditor module)
}
```

---

### 3.2 `CaptureEngine`

Responsible for all capture operations. No UI — returns `CGImage` or file URL to the caller.

#### Area Capture
- Present a transparent fullscreen `NSPanel` (one per display) with a dark tinted overlay
- Draw crosshair cursor; show a 8x magnifier loupe near the cursor using `CGWindowListCreateImage` sampled at cursor position. Note: `CGWindowListCreateImage` is deprecated in macOS 14 (Sonoma); acceptable for v1 since minimum target is macOS 13. Migrate loupe to `SCScreenshotManager` in a future release.
- Show live `W × H` label following the drag rect
- On mouse-up: capture the selected rect via `SCScreenshotManager.captureImage(contentFilter:configuration:)`
- Store last selection rect; expose `retakeLast()` to reuse it

#### Window Capture
- Enumerate all on-screen windows via `CGWindowListCopyWindowInfo(CGWindowListOption.optionOnScreenOnly, kCGNullWindowID)`
- Present transparent overlay; highlight the window under cursor with a colored border
- On click: capture the specific window using `SCFilter` (window filter) → produces image with transparent background
- Apply drop shadow via `CIFilter(name: "CIDropShadow")` (correct Core Image API) if enabled in settings

#### Fullscreen Capture
- Enumerate displays via `NSScreen.screens`
- Capture each via `SCScreenshotManager`; if multi-display, either capture all or let user pick

#### Scrolling Capture
- Present overlay for the user to select a scroll container
- Inject `CGEventCreateScrollWheelEvent` scroll events at fixed intervals (requires Accessibility permission — see Section 7)
- Capture a frame after each scroll step via `CGWindowListCreateImage`
- Detect overlap between consecutive frames using normalized cross-correlation (template matching on a horizontal strip)
- Stitch frames vertically into one tall `CGImage` using `CGContext`
- Stop when two consecutive frames are identical (reached bottom) or user cancels

#### Screen Recorder
- Uses `SCStream` (ScreenCaptureKit) for live screen capture frames
- Audio: microphone via `AVCaptureSession`; system audio via `SCStream` audio (macOS 13+)
- Video encoding: `AVAssetWriter` with `AVVideoCodecType.h264`
- Configurable: FPS (15/30/60), resolution (native, 1080p, 720p, 480p), bitrate
- Camera overlay: `AVCaptureSession` (webcam) → composite via `CALayer` or `Metal`
- Click/keystroke visualizer: `CGEventTap` monitors global events → sends notifications to overlay window
- On stop: writes `.mp4` to temp path, hands off to caller

#### GIF Recorder
- Same `SCStream` pipeline as video
- Frame encoding: integrate [Gifski](https://github.com/sindresorhus/Gifski) (Swift package) for high-quality palette quantization
- Configurable FPS (5/10/15/24) and scale factor

#### Do Not Disturb
- No public API exists to programmatically enable macOS Focus/DND from a third-party app.
- Chosen approach: shell out to `shortcuts run "<FocusShortcutName>"` before recording starts, and again with an "off" shortcut on stop. The user must create these Shortcuts in the macOS Shortcuts app (one-time setup; guided via Preferences).
- Fallback if shortcuts are not configured: show a banner in the overlay UI ("Set up DND shortcuts in Preferences to suppress notifications during recording") and skip silently.

---

### 3.3 `AnnotationEditor`

A self-contained SwiftUI image editor. Accepts a `CGImage` and returns an annotated `CGImage` + optional `.cleanalt` project file.

#### Data Model
```swift
struct AnnotationProject: Codable {
    let baseImage: Data           // raw PNG bytes (Data is binary; JSON serialization uses base64 automatically via Codable)
    var annotations: [AnyAnnotation]   // uses AnyAnnotation tagged-union enum — see SharedModels
    var backgroundConfig: BackgroundConfig?
    var canvasSize: CGSize
}

enum BackgroundStyle: String, Codable { case solid, linearGradient, radialGradient, image }

struct GradientConfig: Codable {
    var colors: [CodableColor]
    var angle: Double            // degrees, 0–360; used for linear gradient
    var center: CGPoint          // normalized 0–1; used for radial gradient
}

struct BackgroundConfig: Codable {
    var style: BackgroundStyle
    var color: CodableColor                // used when style == .solid
    var gradient: GradientConfig?          // used when style == .linearGradient or .radialGradient
    var imageURL: URL?                     // used when style == .image
    var padding: CGFloat
    var cornerRadius: CGFloat
    var shadowRadius: CGFloat
    var shadowOpacity: CGFloat
    var aspectRatio: CGSize?               // nil = free; otherwise lock to this ratio
}
```

#### Canvas Rendering
- SwiftUI `Canvas` view renders base image + all annotation objects in z-order
- Selection handles drawn over selected annotation
- Hit-testing for selection: each annotation type implements `contains(_ point: CGPoint) -> Bool`

#### Tools
| Tool | Implementation |
|------|---------------|
| Arrow | Bezier path with arrowhead; 4 head styles; thickness slider |
| Rectangle / Ellipse / Line | `Path` primitives; stroke/fill toggles |
| Text | `NSTextView` embedded in canvas; font size + color; background chip |
| Highlighter | Semi-transparent `Path`, free-draw; 3 opacity levels |
| Pixelate | Capture sub-rect of canvas → apply `CIPixellate` filter → render as overlay |
| Blur | Same but `CIGaussianBlur` |
| Spotlight | Full-canvas dark overlay with a clear cutout `Path` |
| Counter | Circle with auto-incrementing number; reset button in toolbar |
| Pencil | Free-draw; raw points smoothed into cubic bezier via Catmull-Rom |
| Crop | Draggable rect; on confirm, clips canvas and base image |
| Resize | Input fields for W/H with aspect-ratio lock toggle |
| Rotate/Flip | Rotate 90° CW/CCW; flip H/V via affine transforms |

#### Background Tool
- Activated from toolbar; wraps the annotation canvas in a larger padded canvas
- Background options: solid color picker, linear/radial gradient builder, image picker
- Padding slider (0–200pt), aspect ratio presets (16:9, 4:3, 1:1, free)
- Drop shadow: radius + opacity sliders

#### Export (`ExportService`)

```swift
public struct ExportService {
    public func export(_ image: CGImage, to url: URL, format: ExportFormat) throws
    public func copyToPasteboard(_ image: CGImage) throws
}
```

- Flatten annotations + base image to `CGImage` via `CGContext` before exporting
- Write via `CGImageDestination` for PNG/JPEG/TIFF/WebP
- Copy to `NSPasteboard` as PNG data

---

### 3.4 `OCRService`

```swift
public struct OCRResult {
    public let text: String
    public let candidates: [RecognizedBlock]
}

public struct RecognizedBlock {
    public let text: String
    public let boundingBox: CGRect   // normalized coordinates
    public let confidence: Float
}

public class OCRService {
    public func recognize(image: CGImage) async throws -> OCRResult
    public func detectQRCodes(image: CGImage) async throws -> [String]
}
```

- `VNRecognizeTextRequest` with `.accurate` recognition level
- `VNDetectBarcodesRequest` with `.qr` symbology filter
- Fully on-device; no network calls
- Caller presents a crosshair overlay → captures selected region → passes CGImage to this service → result copied to clipboard

---

### 3.5 `HistoryStore`

Persistent local history of all captures, queryable and browsable.

#### Storage Layout
```
~/Library/Application Support/CleanShotAlt/
├── history.sqlite          # GRDB database
├── captures/               # full-res files (PNG/MP4/GIF)
└── thumbnails/             # 240×180 JPEG thumbnails
```

#### Schema
```sql
CREATE TABLE captures (
    id TEXT PRIMARY KEY,
    mode TEXT NOT NULL,
    created_at INTEGER NOT NULL,    -- unix timestamp
    file_path TEXT NOT NULL,
    thumbnail_path TEXT NOT NULL,
    export_format TEXT NOT NULL,
    file_size INTEGER,
    width INTEGER,
    height INTEGER
);
```

#### API
```swift
public class HistoryStore {
    public func ingest(_ capture: Capture) async throws
    public func fetchAll(filter: CaptureMode? = nil) async throws -> [Capture]
    public func delete(_ id: UUID) async throws
    public func pruneOlderThan(_ days: Int) async throws   // called at launch
    // Called after annotation: replaces the original capture record with the
    // annotated version (new file path/thumbnail); deletes the original files.
    public func replace(originalID: UUID, with annotated: Capture) async throws
}
```

- Thumbnail generated at ingest using `ImageIO` / `AVAssetImageGenerator` (video)
- Auto-prune: on app launch, delete records + files older than 30 days

---

### 3.6 `DesktopManager`

```swift
public class DesktopManager {
    public func hideIcons() throws
    public func showIcons() throws
    public func setWallpaper(_ url: URL, on screen: NSScreen) throws
    public func restoreWallpaper(on screen: NSScreen) throws
}
```

- Hide icons: `defaults write com.apple.finder CreateDesktop -bool false && killall Finder`
- Restore: `defaults write com.apple.finder CreateDesktop -bool true && killall Finder`
- Wallpaper: save current URL from `NSWorkspace.shared.desktopImageURL(for:)`, apply new via `NSWorkspace.shared.setDesktopImageURL(_:for:options:)`

---

## 4. UI Components

### 4.1 Menu Bar (`MenuBarController`)
- `NSStatusItem` with camera icon
- Dropdown menu: all capture modes, separator, History, Preferences, Quit
- All items have hotkey glyphs showing configured shortcut

### 4.2 Quick Access Overlay (`QuickOverlay`)
- Appears bottom-right after every capture; slides in with spring animation
- Shows thumbnail, capture type badge, file size
- Buttons: Annotate, Copy, Save, Pin, OCR, Delete
- Auto-dismisses after configurable timeout (default 5s); pauses on hover
- Implemented as `NSPanel` (floating, non-activating) with SwiftUI content

### 4.3 Annotation Window (`AnnotationWindow`)
- Standard `NSWindow` (activating, resizable)
- Left toolbar: tool picker with icons
- Top bar: style controls for active tool (color, thickness, opacity)
- Canvas: center, scrollable if image > window
- Bottom bar: zoom, export format picker, Copy / Save / Done buttons

### 4.4 History Panel (`HistoryPanel`)
- `NSPanel` shown from menu bar
- Grid of thumbnails (3 columns); filter tabs: All / Screenshots / Recordings / GIFs
- Right-click context menu: Open in Editor, Copy, Save As, Delete
- Search field filters by date

### 4.5 Floating Screenshot (`FloatingScreenshot`)
- `NSPanel` with `NSWindowLevel.floating`
- Draggable by content; resize handles on edges
- Toolbar (shown on hover): opacity slider, Lock Mode toggle (click-through), Close
- Lock Mode: sets `ignoresMouseEvents = true` on the panel

### 4.6 Preferences Window (`PreferencesWindow`)
- SwiftUI `Settings` scene (macOS 13+)
- Tabs: General, Shortcuts, Annotations, Recording, Storage
- General: launch at login, default save path, naming pattern, default format
- Shortcuts: hotkey recorder for each capture mode (using `KeyboardShortcuts` package)
- Annotations: default colors, font, tool sizes
- Recording: default FPS, resolution, audio sources
- Storage: history retention period, open captures folder, clear history

---

## 5. Data Flow

```
Global Hotkey / Menu Bar Action
        │
        ▼
HotkeyManager dispatches to CaptureEngine
        │
        ├─── DesktopManager.hideIcons() (if enabled in settings)
        │
        ▼
CaptureEngine runs mode-specific capture
        │
        ├──► HistoryStore.ingest(capture)          [always, async]
        │
        ├─── DesktopManager.restoreIcons()         [if hidden]
        │
        └──► QuickOverlay.show(capture)
                    │
                    ├─ [Annotate]  → AnnotationWindow(capture)
                    │                       │
                    │                       └─► HistoryStore.ingest(annotatedCapture)
                    │                           (annotated result is a new Capture record
                    │                            replacing the original; original deleted)
                    ├─ [Copy]      → NSPasteboard.setImage(...)
                    ├─ [Save]      → NSSavePanel → AnnotationEditor.ExportService.save(...)
                    │                           (ExportService is a struct in AnnotationEditor
                    │                            module that writes CGImage to disk in the
                    │                            selected format via CGImageDestination)
                    ├─ [Pin]       → FloatingScreenshot(capture)
                    ├─ [OCR]       → OCRService.recognize(...) → clipboard
                    └─ [Delete]    → HistoryStore.delete(id) + file removal
```

---

## 6. Dependencies

| Package | Purpose | License |
|---------|---------|---------|
| [GRDB.swift](https://github.com/groue/GRDB.swift) | SQLite ORM for HistoryStore | MIT |
| [Gifski](https://github.com/sindresorhus/Gifski) | High-quality GIF encoding | MIT |
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | Global hotkey management | MIT |

All dependencies are MIT licensed and available as Swift packages.

---

## 7. Permissions Required

Declared in `Info.plist` / entitlements:

| Permission | Reason |
|-----------|--------|
| `NSScreenCaptureDescription` | Screen capture |
| `NSMicrophoneUsageDescription` | Audio recording |
| `NSCameraUsageDescription` | Webcam overlay |
| `com.apple.security.temporary-exception.apple-events` | Hiding desktop icons (Finder AppleEvents) |
| Accessibility (AX API) | CGEventTap for click/keystroke visualizer; CGEvent injection for scrolling capture |

---

## 8. Settings Schema (`UserDefaults`)

```swift
struct AppSettings {
    var defaultExportFormat: ExportFormat = .png
    var defaultSavePath: URL = ~/Desktop
    var namingPattern: String = "Screenshot {yyyy-MM-dd} at {HH.mm.ss}"
    var overlayDismissTimeout: TimeInterval = 5.0
    var historyRetentionDays: Int = 30
    var launchAtLogin: Bool = false
    var hideDesktopIconsOnCapture: Bool = false
    var showMouseClicks: Bool = false
    var showKeystrokes: Bool = false
    var captureDropShadow: Bool = true
    var recordingFPS: Int = 30
    var recordingResolution: RecordingResolution = .native
    var recordMicrophone: Bool = false
    var recordSystemAudio: Bool = true
}
```

---

## 9. Out of Scope (v1)

- Cloud upload / sharing links
- Password-protected or expiring links
- Team collaboration features
- CleanShot Cloud integration
- Windows / Linux support

---

## 10. Project Scaffold

```
CleanShotAlt/
├── CleanShotAlt.xcodeproj
├── CleanShotAlt/                  # app target sources
├── Modules/
│   ├── SharedModels/Package.swift
│   ├── CaptureEngine/Package.swift
│   ├── AnnotationEditor/Package.swift
│   ├── OCRService/Package.swift
│   ├── HistoryStore/Package.swift
│   └── DesktopManager/Package.swift
├── docs/
│   └── superpowers/specs/
│       └── 2026-04-14-cleanshot-alternative-design.md
└── README.md
```
