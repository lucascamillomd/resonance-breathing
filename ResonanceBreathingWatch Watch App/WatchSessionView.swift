import SwiftUI

struct WatchSessionView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @ObservedObject var phoneConnector: PhoneConnector
    @ObservedObject var hapticEngine: HapticEngine

    var body: some View {
        VStack(spacing: 8) {
            if workoutManager.isWorkoutActive {
                Text(hapticEngine.currentPhase.uppercased())
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.teal)

                Text("\(Int(workoutManager.heartRate))")
                    .font(.system(size: 48, weight: .thin, design: .rounded))

                Text("BPM")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Resonance")
                    .font(.headline)
                Text("Open iPhone app\nto begin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
