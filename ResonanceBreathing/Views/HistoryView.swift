import SwiftUI
import SwiftData
import Charts

struct HistoryView: View {
    @Query(sort: \BreathingSession.date, order: .reverse) private var sessions: [BreathingSession]

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if sessions.isEmpty {
                Text("No sessions yet")
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                List {
                    Section("Trends") {
                        trendChart
                            .listRowBackground(Color.white.opacity(0.05))
                    }

                    Section("Sessions") {
                        ForEach(sessions) { session in
                            sessionRow(session)
                                .listRowBackground(Color.white.opacity(0.05))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("History")
    }

    private var trendChart: some View {
        Chart(sessions.prefix(30).reversed()) { session in
            LineMark(
                x: .value("Date", session.date),
                y: .value("RMSSD", session.averageRMSSD)
            )
            .foregroundStyle(AppTheme.chartLine)
        }
        .frame(height: 120)
    }

    private func sessionRow(_ session: BreathingSession) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.body)
                Text("\(Int(session.duration / 60)) min")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(String(format: "%.1f bpm", session.resonanceRate))
                    .font(.system(.body, design: .monospaced))
                Text("\(Int(session.peakCoherence * 100))%")
                    .font(.caption)
                    .foregroundStyle(AppTheme.petalTeal)
            }
        }
        .foregroundStyle(AppTheme.primaryText)
    }
}
