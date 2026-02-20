import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var allSettings: [UserSettings]
    @Environment(\.modelContext) private var modelContext

    private var settings: UserSettings {
        if let existing = allSettings.first { return existing }
        let new = UserSettings()
        modelContext.insert(new)
        return new
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            Form {
                Section("Session Defaults") {
                    Picker("Duration", selection: Binding(
                        get: { settings.defaultDuration },
                        set: { settings.defaultDuration = $0 }
                    )) {
                        Text("5 min").tag(TimeInterval(300))
                        Text("10 min").tag(TimeInterval(600))
                        Text("15 min").tag(TimeInterval(900))
                        Text("20 min").tag(TimeInterval(1200))
                    }

                    HStack {
                        Text("Starting Rate")
                        Spacer()
                        Text(String(format: "%.1f bpm", settings.defaultBreathingRate))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Slider(
                        value: Binding(
                            get: { settings.defaultBreathingRate },
                            set: { settings.defaultBreathingRate = $0 }
                        ),
                        in: 4.5...7.0,
                        step: 0.1
                    )
                }

                Section("Haptics") {
                    Toggle("Haptic Feedback", isOn: Binding(
                        get: { settings.hapticsEnabled },
                        set: { settings.hapticsEnabled = $0 }
                    ))
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
    }
}
