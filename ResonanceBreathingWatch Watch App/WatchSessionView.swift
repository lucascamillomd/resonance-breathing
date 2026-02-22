import SwiftUI
import SwiftData
import BreathingCore

struct WatchSessionView: View {
    @ObservedObject var sessionManager: WatchSessionManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserSettings.defaultDuration) private var settings: [UserSettings]

    private var sessionConfiguration: SessionConfiguration {
        SessionConfiguration(settings: settings.first)
    }

    private var elapsedText: String {
        let mins = Int(sessionManager.elapsedSeconds) / 60
        let secs = Int(sessionManager.elapsedSeconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var coherencePercent: Int {
        Int((sessionManager.coherence * 100).rounded())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.14, blue: 0.24), Color(red: 0.03, green: 0.07, blue: 0.14)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if sessionManager.isActive {
                    activeSessionView
                } else if sessionManager.didComplete {
                    summaryView
                } else {
                    startView
                }
            }
            .task {
                _ = try? UserSettingsBootstrapper.ensureSettings(modelContext: modelContext)
            }
        }
    }

    // MARK: - Active Session

    private var activeSessionView: some View {
        VStack(spacing: 6) {
            Text(sessionManager.currentPhase.label)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(Color(red: 0.38, green: 0.9, blue: 0.77))

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 4)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: sessionManager.sessionProgress)
                    .stroke(
                        Color(red: 0.38, green: 0.9, blue: 0.77),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 80, height: 80)

                VStack(spacing: 0) {
                    Text("\(Int(sessionManager.heartRate))")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("BPM")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text("\(coherencePercent)%")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.38, green: 0.9, blue: 0.77))
                    Text("Coherence")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }

                VStack(spacing: 2) {
                    Text("\(Int(sessionManager.rmssd))")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("RMSSD")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }

                VStack(spacing: 2) {
                    Text(elapsedText)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Time")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Text(String(format: "%@ · %.1f bpm", {
                switch sessionManager.pacerPhase {
                case .warmup: return "Warming up"
                case .exploring: return "Exploring"
                case .converged: return "Locked"
                }
            }(), sessionManager.guidedBPM))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))

            Button("Stop") {
                sessionManager.stopSession(modelContext: modelContext)
            }
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(.red.opacity(0.8))
        }
        .padding(.vertical, 4)
    }

    // MARK: - Summary

    private var summaryView: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Session Complete")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 5)
                        .frame(width: 70, height: 70)
                    Circle()
                        .trim(from: 0, to: sessionManager.peakCoherence)
                        .stroke(
                            Color(red: 0.38, green: 0.9, blue: 0.77),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 70, height: 70)
                    VStack(spacing: 0) {
                        Text("\(Int((sessionManager.peakCoherence * 100).rounded()))%")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Peak")
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    summaryCell("Avg HR", "\(Int(sessionManager.averageHR)) bpm")
                    summaryCell("RMSSD", "\(Int(sessionManager.averageRMSSD)) ms")
                    summaryCell("Duration", SessionDisplay.duration(sessionManager.duration))
                    summaryCell("Rate", String(format: "%.1f bpm", sessionManager.resonanceRate))
                }

                Button("Done") {
                    sessionManager.didComplete = false
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(red: 0.38, green: 0.9, blue: 0.77))
                )
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Start

    private var startView: some View {
        VStack(spacing: 10) {
            Text("Resonance")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)

            Button(action: {
                sessionManager.startSession(configuration: sessionConfiguration)
            }) {
                Text("Start Session")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(red: 0.38, green: 0.9, blue: 0.77))
                    )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: WatchHistoryView()) {
                Text("History")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }

            NavigationLink(destination: WatchSettingsView()) {
                Text("Settings")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    // MARK: - Helpers

    private func summaryCell(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}
