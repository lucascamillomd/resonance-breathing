import SwiftUI
import SwiftData
import Charts

struct HistoryView: View {
    @Query(sort: \BreathingSession.date, order: .reverse) private var sessions: [BreathingSession]
    @Environment(\.modelContext) private var modelContext
    @State private var pendingDelete: BreathingSession?
    private let calendar = Calendar.current

    private var totalPracticeMinutes: Int {
        Int(sessions.reduce(0) { $0 + $1.duration } / 60)
    }

    private var last7DayCount: Int {
        guard let from = calendar.date(byAdding: .day, value: -6, to: Date.now) else { return 0 }
        return sessions.filter { $0.date >= from }.count
    }

    private var bestCoherencePercent: Int {
        sessions.map(\.peakCoherencePercent).max() ?? 0
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            if sessions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(AppTheme.tertiaryText)
                    Text("No sessions yet")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        overviewCard
                        trendCard

                        Text("Sessions")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryText)

                        ForEach(sessions) { session in
                            sessionRow(session)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete this session?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Session", role: .destructive) {
                guard let pendingDelete else { return }
                modelContext.delete(pendingDelete)
                try? modelContext.save()
                self.pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
    }

    private var overviewCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Total Sessions")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.tertiaryText)
                Text("\(sessions.count)")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                Text("Total Practice")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.tertiaryText)
                Text("\(totalPracticeMinutes) min")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                Text("7-Day / Peak")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.tertiaryText)
                Text("\(last7DayCount) / \(bestCoherencePercent)%")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .mindfulCard()
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RMSSD Trend")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)

            Chart(sessions.prefix(30).reversed()) { session in
                LineMark(
                    x: .value("Date", session.date),
                    y: .value("RMSSD", session.averageRMSSD)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(AppTheme.chartLine)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 120)
        }
        .padding(16)
        .mindfulCard()
    }

    private func sessionRow(_ session: BreathingSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                Text(SessionDisplay.duration(session.duration))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f bpm", session.resonanceRate))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text("\(session.peakCoherencePercent)%")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.accent)
            }
            .foregroundStyle(AppTheme.primaryText)
        }
        .padding(14)
        .mindfulCard(cornerRadius: 16)
        .contextMenu {
            Button("Delete Session", role: .destructive) {
                pendingDelete = session
            }
        }
    }
}
