import SwiftUI
import AnnotationEditor
import SharedModels

struct AnnotationEditorContainerView: View {
    @ObservedObject var project: AnnotationProject
    @StateObject private var toolState = ToolState()
    let onSave:   () -> Void
    let onCancel: () -> Void

    var body: some View {
        HSplitView {
            // Tool palette
            VStack(spacing: 4) {
                ForEach(ActiveTool.allCases, id: \.self) { tool in
                    Button {
                        toolState.activeTool = tool
                    } label: {
                        Image(systemName: tool.iconName)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .background(
                        toolState.activeTool == tool
                            ? Color.accentColor.opacity(0.2)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .help(tool.rawValue.capitalized)
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .frame(width: 52)
            .background(Color(NSColor.windowBackgroundColor))

            // Canvas
            ScrollView([.horizontal, .vertical]) {
                AnnotationCanvas(project: project, toolState: toolState)
                    .padding(20)
            }
            .background(Color(NSColor.underPageBackgroundColor))
        }
        .toolbar {
            ToolbarItemGroup(placement: .principal) {
                ColorPicker("", selection: Binding(
                    get: { Color(toolState.strokeColor.nsColor) },
                    set: { toolState.strokeColor = CodableColor(NSColor($0)) }
                )).labelsHidden()
                Slider(value: $toolState.strokeThickness, in: 1...20)
                    .frame(width: 80)
                Text("Size").font(.caption)
            }
            ToolbarItemGroup(placement: .confirmationAction) {
                Button("Copy") {
                    try? ExportService().copyToPasteboard(project)
                }
                Button("Save") { onSave() }
            }
            ToolbarItemGroup(placement: .cancellationAction) {
                Button("Cancel") { onCancel() }
            }
        }
    }
}
