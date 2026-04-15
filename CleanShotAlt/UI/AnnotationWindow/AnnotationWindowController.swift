import AppKit
import SwiftUI
import SharedModels
import AnnotationEditor
import HistoryStore

final class AnnotationWindowController: NSWindowController {
    var onComplete: ((Capture) -> Void)?

    convenience init(capture: Capture) {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 650),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Annotate — CleanShotAlt"
        win.minSize = NSSize(width: 600, height: 400)
        self.init(window: win)

        guard
            let src     = CGImageSourceCreateWithURL(capture.filePath as CFURL, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(src, 0, nil)
        else { return }

        let project = AnnotationProject(baseImage: cgImage)
        let editorView = AnnotationEditorContainerView(
            project: project,
            onSave:   { [weak self] in self?.saveAnnotated(project: project, original: capture) },
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
