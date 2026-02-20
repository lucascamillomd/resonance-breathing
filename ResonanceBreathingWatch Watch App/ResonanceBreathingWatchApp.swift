import SwiftUI

@main
struct ResonanceBreathingWatchApp: App {
    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var phoneConnector = PhoneConnector()
    @StateObject private var hapticEngine = HapticEngine()

    var body: some Scene {
        WindowGroup {
            WatchSessionView(
                workoutManager: workoutManager,
                phoneConnector: phoneConnector,
                hapticEngine: hapticEngine
            )
            .onAppear {
                workoutManager.requestAuthorization()
                workoutManager.onHeartRateUpdate = { hr, rr in
                    phoneConnector.sendHeartRateData(hr: hr, rrIntervals: rr)
                }
                phoneConnector.onCommand = { command in
                    switch command {
                    case "startWorkout":
                        workoutManager.startWorkout()
                        hapticEngine.start()
                    case "stopWorkout":
                        workoutManager.stopWorkout()
                        hapticEngine.stop()
                    default: break
                    }
                }
            }
        }
    }
}
