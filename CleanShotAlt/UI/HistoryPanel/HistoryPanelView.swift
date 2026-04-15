import SwiftUI
import SharedModels
import HistoryStore

struct HistoryPanelView: View {
    @State private var captures: [Capture] = []
    @State private var filter: CaptureMode? = nil
    var onOpen: (Capture) -> Void
    var onPin:  (Capture) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            if captures.isEmpty {
                Spacer()
                Text("No captures yet")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(captures) { capture in
                            ThumbnailCell(capture: capture)
                                .contextMenu {
                                    Button("Open in Editor") { onOpen(capture) }
                                    Button("Pin to Screen")  { onPin(capture) }
                                    Button("Copy to Clipboard") { copyCapture(capture) }
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
            filterButton(nil,      label: "All")
            filterButton(.area,    label: "Screenshots")
            filterButton(.video,   label: "Videos")
            filterButton(.gif,     label: "GIFs")
        }
        .padding(8)
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private func filterButton(_ mode: CaptureMode?, label: String) -> some View {
        Button(label) {
            filter = mode
            Task { await loadCaptures() }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(
            filter == mode ? Color.accentColor.opacity(0.15) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
    }

    private func loadCaptures() async {
        captures = (try? await HistoryStore.shared.fetchAll(filter: filter)) ?? []
    }

    private func copyCapture(_ capture: Capture) {
        guard
            let src  = CGImageSourceCreateWithURL(capture.filePath as CFURL, nil),
            let img  = CGImageSourceCreateImageAtIndex(src, 0, nil)
        else { return }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(dest, img, nil)
        guard CGImageDestinationFinalize(dest) else { return }
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
                Image(nsImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 88, height: 66)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 88, height: 66)
            }
            Text(capture.createdAt, style: .time)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
