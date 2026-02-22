import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var allSettings: [UserSettings]
    @Environment(\.modelContext) private var modelContext

    @State private var currentSettings: UserSettings?

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            if let settings = currentSettings ?? allSettings.first {
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

                        HStack {
                            Text("Cycle Length")
                            Spacer()
                            Text(String(format: "%.1f s", 60.0 / settings.defaultBreathingRate))
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
                        .tint(AppTheme.accent)
                    }

                    Section("Haptics") {
                        Toggle("Haptic Feedback", isOn: Binding(
                            get: { settings.hapticsEnabled },
                            set: { settings.hapticsEnabled = $0 }
                        ))
                        .tint(AppTheme.tint)
                    }

                    Section("Calibration") {
                        Toggle("ECG Prior", isOn: Binding(
                            get: { settings.useECGPrior },
                            set: { settings.useECGPrior = $0 }
                        ))
                        .tint(AppTheme.tint)

                        if settings.useECGPrior {
                            Text("Reads your most recent ECG recording to estimate your resonant frequency before each session.")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundStyle(AppTheme.tertiaryText)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            } else {
                ProgressView()
                    .tint(AppTheme.primaryText)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            currentSettings = try? UserSettingsBootstrapper.ensureSettings(modelContext: modelContext)
        }
    }
}
