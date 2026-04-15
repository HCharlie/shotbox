import SwiftUI

struct PreferencesView: View {
    var body: some View {
        TabView {
            GeneralPrefsView()
                .tabItem { Label("General", systemImage: "gearshape") }.tag(0)
            ShortcutsPrefsView()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }.tag(1)
            RecordingPrefsView()
                .tabItem { Label("Recording", systemImage: "video") }.tag(2)
            StoragePrefsView()
                .tabItem { Label("Storage", systemImage: "internaldrive") }.tag(3)
        }
        .frame(width: 520, height: 420)
    }
}
