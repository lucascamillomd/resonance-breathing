import SwiftUI

struct MetricsBarView: View {
    let heartRate: Double
    let rmssd: Double
    let coherence: Double
    var estimatedRF: Double = 0
    var pacerPhase: String = ""

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("\(Int(heartRate)) bpm", systemImage: "heart.fill")
                    .foregroundStyle(AppTheme.danger)
                Spacer()
                Text("RMSSD \(Int(rmssd)) ms")
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .font(.system(size: 13, weight: .medium, design: .rounded))

            HStack {
                Text("Coherence")
                    .foregroundStyle(AppTheme.secondaryText)
                CoherenceDotsView(score: coherence)
                Text("\(Int(coherence * 100))%")
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))

            if !pacerPhase.isEmpty {
                HStack {
                    Text(pacerPhase)
                        .foregroundStyle(AppTheme.accent)
                    Spacer()
                    if estimatedRF > 0 {
                        Text(String(format: "RF %.1f bpm", estimatedRF))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .mindfulCard(cornerRadius: 16)
    }
}

#Preview {
    MetricsBarView(heartRate: 68, rmssd: 42, coherence: 0.8, estimatedRF: 5.8, pacerPhase: "Exploring")
        .background(AppTheme.background)
}
