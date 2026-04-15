import SwiftUI
import ServiceManagement

struct GeneralPrefsView: View {
    @AppStorage("launchAtLogin")               private var launchAtLogin = false
    @AppStorage("hideDesktopIconsOnCapture")   private var hideIcons = false
    @AppStorage("captureDropShadow")           private var dropShadow = true
    @AppStorage("overlayDismissTimeout")       private var dismissTimeout = 5.0
    @AppStorage("namingPattern")               private var namingPattern = "Screenshot {yyyy-MM-dd} at {HH.mm.ss}"
    @AppStorage("defaultSavePath")             private var savePath = ""

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newVal in
                        do {
                            if newVal { try SMAppService.mainApp.register() }
                            else      { try SMAppService.mainApp.unregister() }
                        } catch {
                            print("Launch at login error: \(error)")
                        }
                    }
                Toggle("Hide desktop icons before capture", isOn: $hideIcons)
                Toggle("Add drop shadow to window captures", isOn: $dropShadow)
            }
            Section("Overlay") {
                LabeledContent("Auto-dismiss after") {
                    HStack {
                        Slider(value: $dismissTimeout, in: 1...30, step: 1)
                        Text("\(Int(dismissTimeout))s").monospacedDigit().frame(width: 28)
                    }
                }
            }
            Section("Files") {
                TextField("Naming pattern", text: $namingPattern)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Text(savePath.isEmpty ? "~/Desktop" : savePath)
                        .foregroundStyle(.secondary)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose…") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK {
                            savePath = panel.url?.path ?? ""
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
