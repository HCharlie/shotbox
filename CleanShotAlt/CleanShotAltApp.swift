import SwiftUI

@main
struct CleanShotAltApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            Text("Preferences").frame(width: 500, height: 400)
        }
    }
}
