import SwiftUI
import SwiftData
import BreathingCore

struct WatchSettingsView: View {
    @Query private var allSettings: [UserSettings]
    @Environment(\.modelContext) private var modelContext

    private var settings: UserSettings? { allSettings.first }

    private var durationMinutes: Binding<Double> {
        Binding(
            get: { (settings?.defaultDuration ?? 600) / 60 },
            set: { settings?.defaultDuration = $0 * 60 }
        )
    }

    private var breathingRate: Binding<Double> {
        Binding(
            get: { settings?.defaultBreathingRate ?? BreathingParameters.defaultBPM },
            set: { settings?.defaultBreathingRate = $0 }
        )
    }

    private var hapticsEnabled: Binding<Bool> {
        Binding(
            get: { settings?.hapticsEnabled ?? true },
            set: { settings?.hapticsEnabled = $0 }
        )
    }

    var body: some View {
        List {
            Section("Duration") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Int(durationMinutes.wrappedValue)) min")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Slider(value: durationMinutes, in: 1...30, step: 1)
                        .tint(Color(red: 0.38, green: 0.9, blue: 0.77))
                }
                .listRowBackground(Color.white.opacity(0.06))
            }

            Section("Breathing Rate") {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: "%.1f bpm", breathingRate.wrappedValue))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Slider(value: breathingRate, in: BreathingParameters.minBPM...BreathingParameters.maxBPM, step: 0.5)
                        .tint(Color(red: 0.38, green: 0.9, blue: 0.77))
                }
                .listRowBackground(Color.white.opacity(0.06))
            }

            Section {
                Toggle("Haptics", isOn: hapticsEnabled)
                    .tint(Color(red: 0.38, green: 0.9, blue: 0.77))
                    .listRowBackground(Color.white.opacity(0.06))
            }

        }
        .navigationTitle("Settings")
    }
}
