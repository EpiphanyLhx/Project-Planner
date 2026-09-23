import SwiftUI

@main
struct ProjectPlannerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 620)
        }
        .defaultSize(width: 1080, height: 720)
        .windowToolbarStyle(.unified)

        Settings {
            SettingsView()
        }
    }
}
