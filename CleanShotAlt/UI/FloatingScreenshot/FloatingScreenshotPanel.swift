import AppKit
import SwiftUI
import SharedModels

final class FloatingScreenshotPanel: NSPanel {
    init(capture: Capture) {
        super.init(
            contentRect: NSRect(x: 100, y: 100, width: 400, height: 300),
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = FloatingScreenshotView(
            capture: capture,
            onClose:      { [weak self] in self?.orderOut(nil) },
            onToggleLock: { [weak self] in
                guard let self else { return }
                ignoresMouseEvents.toggle()
            }
        )
        contentView = NSHostingView(rootView: view)
        makeKeyAndOrderFront(nil)
    }
}

struct FloatingScreenshotView: View {
    let capture: Capture
    let onClose:      () -> Void
    let onToggleLock: () -> Void

    @State private var isHovering = false
    @State private var opacity: Double = 1.0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let img = NSImage(contentsOf: capture.filePath) {
                Image(nsImage: img)
                    .resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 6)
                    .opacity(opacity)
            }
            if isHovering {
                HStack(spacing: 4) {
                    Button(action: onToggleLock) {
                        Image(systemName: "lock")
                    }
                    .buttonStyle(.plain)
                    Slider(value: $opacity, in: 0.2...1.0)
                        .frame(width: 60)
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(6)
            }
        }
        .onHover { isHovering = $0 }
    }
}
