import SwiftUI
import SharedModels

struct QuickOverlayView: View {
    let capture: Capture
    let onAnnotate: () -> Void
    let onCopy:     () -> Void
    let onSave:     () -> Void
    let onPin:      () -> Void
    let onOCR:      () -> Void
    let onDelete:   () -> Void
    let onDismiss:  () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Thumbnail
            if let img = NSImage(contentsOf: capture.thumbnailPath) {
                Image(nsImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 80, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 80, height: 60)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    overlayButton("pencil",                label: "Edit",   action: onAnnotate)
                    overlayButton("doc.on.doc",            label: "Copy",   action: onCopy)
                    overlayButton("square.and.arrow.down", label: "Save",   action: onSave)
                }
                HStack(spacing: 4) {
                    overlayButton("pin",                   label: "Pin",    action: onPin)
                    overlayButton("text.viewfinder",       label: "OCR",    action: onOCR)
                    overlayButton("trash",                 label: "Delete", action: onDelete)
                }
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.white.opacity(0.15), lineWidth: 1))
        .shadow(radius: 8)
    }

    @ViewBuilder
    private func overlayButton(_ icon: String, label: String,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 13))
                Text(label).font(.system(size: 9))
            }
            .frame(width: 52, height: 38)
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }
}
