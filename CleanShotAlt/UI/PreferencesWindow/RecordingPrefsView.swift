import SwiftUI

struct RecordingPrefsView: View {
    @AppStorage("recordingFPS")        private var fps = 30
    @AppStorage("recordMicrophone")    private var recordMic = false
    @AppStorage("recordSystemAudio")   private var recordSystem = true
    @AppStorage("showMouseClicks")     private var showClicks = false
    @AppStorage("showKeystrokes")      private var showKeys = false

    var body: some View {
        Form {
            Section("Quality") {
                Picker("Frame rate", selection: $fps) {
                    Text("15 fps").tag(15)
                    Text("24 fps").tag(24)
                    Text("30 fps").tag(30)
                    Text("60 fps").tag(60)
                }
            }
            Section("Audio") {
                Toggle("Record microphone",    isOn: $recordMic)
                Toggle("Record system audio",  isOn: $recordSystem)
            }
            Section("Visual Feedback") {
                Toggle("Show mouse clicks",    isOn: $showClicks)
                Toggle("Show keystrokes",      isOn: $showKeys)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
