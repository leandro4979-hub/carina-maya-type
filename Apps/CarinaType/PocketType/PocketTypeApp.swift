import SwiftUI

@main
struct PocketTypeApp: App {
    init() {
        CarinaShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
