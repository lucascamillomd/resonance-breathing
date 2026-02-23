import SwiftUI
import SwiftData

@main
struct ResonanceBreathingApp: App {
    // Activate WCSession early so the Watch link is ready before a session starts.
    @StateObject private var watchConnector = WatchConnector.shared

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [BreathingSession.self, SessionDataPoint.self, UserSettings.self])
    }
}
