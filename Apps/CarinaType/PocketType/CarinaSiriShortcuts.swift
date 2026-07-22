import AppIntents

/// To activate these Siri Shortcuts, register CarinaShortcuts in your @main SwiftUI App struct using .appShortcutsProvider(CarinaShortcuts.self)

struct OpenCarinaIntent: AppIntent {
    static var title: LocalizedStringResource { "Open CARINA" }
    static var description: IntentDescription { IntentDescription("Open CARINA TYPE and its keyboard controls.") }
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Opening CARINA.")
    }
}

struct CarinaShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor { .purple }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenCarinaIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Talk to \(.applicationName)",
                "Start \(.applicationName)"
            ],
            shortTitle: "Open CARINA",
            systemImageName: "sparkles"
        )
    }
}
