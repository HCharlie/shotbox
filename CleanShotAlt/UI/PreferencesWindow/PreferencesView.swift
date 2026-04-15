import SwiftUI

struct PreferencesView: View {
    var body: some View {
        TabView {
            Text("General").tabItem { Label("General", systemImage: "gearshape") }.tag(0)
            Text("Shortcuts").tabItem { Label("Shortcuts", systemImage: "keyboard") }.tag(1)
            Text("Recording").tabItem { Label("Recording", systemImage: "video") }.tag(2)
            Text("Storage").tabItem { Label("Storage", systemImage: "internaldrive") }.tag(3)
        }
        .frame(width: 500, height: 400)
    }
}
