import SwiftUI
import SharedModels

/// Panel for configuring the canvas background wrapper.
public struct BackgroundToolView: View {
    @ObservedObject public var project: AnnotationProject
    @State private var config = BackgroundConfig()

    public init(project: AnnotationProject) { self.project = project }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Background").font(.headline)

            Picker("Style", selection: $config.style) {
                Text("Solid").tag(BackgroundStyle.solid)
                Text("Linear Gradient").tag(BackgroundStyle.linearGradient)
                Text("Image").tag(BackgroundStyle.image)
            }.pickerStyle(.segmented)

            if config.style == .solid {
                ColorPicker("Color", selection: Binding(
                    get: { Color(config.color.nsColor) },
                    set: { config.color = CodableColor(NSColor($0)) }
                ))
            }

            LabeledContent("Padding") {
                HStack {
                    Slider(value: $config.padding, in: 0...200)
                    Text("\(Int(config.padding))pt").monospacedDigit()
                }
            }
            LabeledContent("Corner Radius") {
                Slider(value: $config.cornerRadius, in: 0...40)
            }
            LabeledContent("Shadow") {
                Slider(value: $config.shadowRadius, in: 0...40)
            }

            HStack {
                Button("Apply") { project.backgroundConfig = config }
                    .buttonStyle(.borderedProminent)
                Button("Remove") { project.backgroundConfig = nil }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .onAppear { config = project.backgroundConfig ?? BackgroundConfig() }
    }
}
