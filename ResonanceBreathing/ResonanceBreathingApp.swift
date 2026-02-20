import SwiftUI
import SwiftData

@main
struct ResonanceBreathingApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [BreathingSession.self, UserSettings.self])
    }
}
