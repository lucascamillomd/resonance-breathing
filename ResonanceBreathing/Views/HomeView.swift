import SwiftUI
import SwiftData
import Charts

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BreathingSession.date, order: .reverse) private var sessions: [BreathingSession]
    @State private var showSession = false
    @State private var completedSession: BreathingSession?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    Text("Resonance")
                        .font(.system(.largeTitle, design: .rounded, weight: .thin))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Breathing")
                        .font(.system(.title2, design: .rounded, weight: .light))
                        .foregroundStyle(AppTheme.secondaryText)

                    Spacer()

                    Button(action: { showSession = true }) {
                        Text("Begin Session")
                            .font(.system(.title3, design: .rounded, weight: .medium))
                            .foregroundStyle(AppTheme.background)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 16)
                            .background(AppTheme.petalTeal, in: Capsule())
                    }

                    if let last = sessions.first {
                        lastSessionCard(last)
                    }

                    Spacer()
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(destination: HistoryView()) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }
            .fullScreenCover(isPresented: $showSession) {
                SessionView(onEnd: {
                    showSession = false
                })
            }
            .sheet(item: $completedSession) { session in
                SummaryView(session: session)
            }
        }
    }

    private func lastSessionCard(_ session: BreathingSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last Session")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            HStack {
                VStack(alignment: .leading) {
                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                    Text("\(Int(session.duration / 60)) min")
                        .font(.system(.body, design: .monospaced))
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(String(format: "%.1f bpm", session.resonanceRate))
                        .font(.system(.body, design: .monospaced))
                    Text("\(Int(session.peakCoherence * 100))% peak")
                        .font(.caption2)
                }
            }
            .foregroundStyle(AppTheme.primaryText)
        }
        .padding()
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
}
