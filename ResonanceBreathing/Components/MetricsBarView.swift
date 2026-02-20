import SwiftUI

struct MetricsBarView: View {
    let heartRate: Double
    let rmssd: Double
    let coherence: Double

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Label("\(Int(heartRate)) bpm", systemImage: "heart.fill")
                    .foregroundStyle(.red.opacity(0.8))
                Spacer()
                Text("RMSSD: \(Int(rmssd))ms")
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .font(.system(.caption, design: .monospaced))

            HStack {
                Text("Coherence:")
                    .foregroundStyle(AppTheme.secondaryText)
                CoherenceDotsView(score: coherence)
                Text("(\(Int(coherence * 100))%)")
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
            }
            .font(.system(.caption, design: .monospaced))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

#Preview {
    MetricsBarView(heartRate: 68, rmssd: 42, coherence: 0.8)
        .background(AppTheme.background)
}
