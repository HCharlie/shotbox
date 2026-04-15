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
                HStack {
                    Text("\(captureCount) captures stored")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Open Folder") {
                        NSWorkspace.shared.open(HistoryStore.capturesDirectory)
                    }
                    .buttonStyle(.borderless)
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
