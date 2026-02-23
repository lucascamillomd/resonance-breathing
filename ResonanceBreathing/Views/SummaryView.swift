import SwiftUI
import SwiftData

struct SummaryView: View {
    let session: BreathingSession
    @Environment(\.dismiss) private var dismiss

    private var coherencePercent: Int { session.peakCoherencePercent }
    private var averageCoherencePercent: Int { session.averageCoherencePercent }
    private var coherenceBand: String { SessionDisplay.coherenceBand(for: session.peakCoherence) }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Session Complete")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.16), lineWidth: 12)
                        .frame(width: 144, height: 144)

                    Circle()
                        .trim(from: 0, to: min(max(0.01, session.peakCoherence), 1.0))
                        .stroke(
                            AppTheme.buttonGradient,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 144, height: 144)

                    VStack(spacing: 2) {
                        Text("\(coherencePercent)%")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("Peak Coherence")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .foregroundStyle(AppTheme.primaryText)
                }

                Text("\(coherenceBand) coherence session")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statCard(title: "Duration", value: SessionDisplay.duration(session.duration))
                    statCard(title: "Avg HR", value: "\(Int(session.averageHR)) bpm")
                    statCard(title: "Avg RMSSD", value: "\(Int(session.averageRMSSD)) ms")
                    statCard(title: "Avg Coherence", value: "\(averageCoherencePercent)%")
                    statCard(title: "Resonance", value: String(format: "%.1f bpm", session.resonanceRate))
                }

                Button("Done") { dismiss() }
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.backgroundBase)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.buttonGradient)
                    )
            }
            .padding(20)
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.tertiaryText)
            Text(value)
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .mindfulCard(cornerRadius: 16)
    }
}
