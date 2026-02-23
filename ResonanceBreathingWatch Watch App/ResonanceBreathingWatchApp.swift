import SwiftUI
import SwiftData

@main
struct ResonanceBreathingWatchApp: App {
    @StateObject private var sessionManager = WatchSessionManager()

    var body: some Scene {
        WindowGroup {
            WatchSessionView(sessionManager: sessionManager)
                .onAppear {
                    sessionManager.workoutManager.requestAuthorization()
                    #if targetEnvironment(simulator)
                    if ProcessInfo.processInfo.arguments.contains("-autoStartSession") {
                        sessionManager.startSession()
                    }
                    #endif
                }
        }
        .modelContainer(for: [BreathingSession.self, SessionDataPoint.self, UserSettings.self])
    }
}
