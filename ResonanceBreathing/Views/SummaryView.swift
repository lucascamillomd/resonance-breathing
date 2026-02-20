import SwiftUI
import SwiftData

struct SummaryView: View {
    let session: BreathingSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Session Complete")
                    .font(.system(.title, design: .rounded, weight: .light))
                    .foregroundStyle(AppTheme.primaryText)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    statCard(title: "Duration", value: "\(Int(session.duration / 60)) min")
                    statCard(title: "Avg HR", value: "\(Int(session.averageHR)) bpm")
                    statCard(title: "Avg RMSSD", value: "\(Int(session.averageRMSSD)) ms")
                    statCard(title: "Peak Coherence", value: "\(Int(session.peakCoherence * 100))%")
                    statCard(title: "Resonance Rate", value: String(format: "%.1f bpm", session.resonanceRate))
                }
                .padding()

                Spacer()

                Button("Done") { dismiss() }
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(AppTheme.petalTeal)
                    .padding()
            }
            .padding()
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.system(.title3, design: .monospaced, weight: .medium))
                .foregroundStyle(AppTheme.primaryText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
}
