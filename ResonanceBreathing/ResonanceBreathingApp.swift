import SwiftUI
import SwiftData

@main
struct ResonanceBreathingApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [BreathingSession.self, UserSettings.self])
    }
}

struct ContentView: View {
    var body: some View {
        Text("Resonance Breathing")
            .font(.title)
    }
}
