import SwiftUI
import SwiftData

struct WatchHistoryView: View {
    @Query(sort: \BreathingSession.date, order: .reverse) private var sessions: [BreathingSession]

    var body: some View {
        List {
            if sessions.isEmpty {
                Text("No sessions yet")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                ForEach(sessions.prefix(20)) { session in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                        HStack {
                            Text(SessionDisplay.duration(session.duration))
                            Spacer()
                            Text("\(session.peakCoherencePercent)% peak")
                                .foregroundStyle(Color(red: 0.38, green: 0.9, blue: 0.77))
                        }
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                }
            }
        }
        .navigationTitle("History")
    }
}
