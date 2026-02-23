import SwiftUI
import SwiftData
import Charts
import WatchConnectivity

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BreathingSession.date, order: .reverse) private var sessions: [BreathingSession]
    @Query private var settings: [UserSettings]

    @State private var showSession = false
    @State private var completedSession: BreathingSession?
    private let calendar = Calendar.current

    private var sessionConfiguration: SessionConfiguration {
        SessionConfiguration(settings: settings.first)
    }

    private var totalPracticeMinutes: Int {
        Int(sessions.reduce(0) { $0 + $1.duration } / 60)
    }

    private var sevenDaySessionCount: Int {
        guard let from = calendar.date(byAdding: .day, value: -6, to: Date.now) else { return 0 }
        return sessions.filter { $0.date >= from }.count
    }

    private var currentStreakDays: Int {
        let uniqueDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        var streak = 0
        var day = calendar.startOfDay(for: Date.now)

        while uniqueDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }

        return streak
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                Circle()
                    .fill(AppTheme.accent.opacity(0.12))
                    .frame(width: 340, height: 340)
                    .blur(radius: 50)
                    .offset(x: -130, y: -250)

                Circle()
                    .fill(AppTheme.tint.opacity(0.1))
                    .frame(width: 280, height: 280)
                    .blur(radius: 40)
                    .offset(x: 160, y: -150)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("Resonance Breathing")
                            .font(.system(size: 36, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.primaryText)
                            .padding(.top, 12)

                        Text("A quiet, adaptive practice guided by your heart rhythm.")
                            .font(.system(size: 17, weight: .regular, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryText)

                        Button(action: { showSession = true }) {
                            HStack(spacing: 10) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Begin Session")
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(AppTheme.backgroundBase)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(AppTheme.buttonGradient)
                            )
                            .shadow(color: AppTheme.tint.opacity(0.4), radius: 14, y: 10)
                        }

                        configurationSummaryCard
                        practiceInsightsCard

                        if let last = sessions.first {
                            lastSessionCard(last)
                        }

                        trendCard

                        #if DEBUG
                        wcDiagnosticCard
                        #endif
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(AppTheme.backgroundBase.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(destination: HistoryView()) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(width: 34, height: 34)
                            .mindfulCard(cornerRadius: 11)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(width: 34, height: 34)
                            .mindfulCard(cornerRadius: 11)
                    }
                }
            }
            .task {
                _ = try? UserSettingsBootstrapper.ensureSettings(modelContext: modelContext)
                #if targetEnvironment(simulator)
                if ProcessInfo.processInfo.arguments.contains("-autoStartSession") {
                    showSession = true
                }
                #endif
            }
            .fullScreenCover(isPresented: $showSession) {
                SessionView(configuration: sessionConfiguration) { session in
                    showSession = false
                    if let session {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            completedSession = session
                        }
                    }
                }
                .ignoresSafeArea()
                .interactiveDismissDisabled(true)
            }
            .sheet(item: $completedSession) { session in
                SummaryView(session: session)
            }
        }
    }

    private var configurationSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Defaults")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.tertiaryText)

            HStack {
                Label("\(Int(sessionConfiguration.targetDuration / 60)) min", systemImage: "timer")
                Spacer()
                Label(String(format: "%.1f bpm", sessionConfiguration.startingBPM), systemImage: "wind")
                Spacer()
                Label(sessionConfiguration.hapticsEnabled ? "Haptics On" : "Haptics Off", systemImage: "applewatch")
            }
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(AppTheme.primaryText)
        }
        .padding(16)
        .mindfulCard()
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("30-Session RMSSD Trend")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)

            if sessions.count >= 2 {
                Chart(sessions.prefix(30).reversed()) { session in
                    LineMark(
                        x: .value("Date", session.date),
                        y: .value("RMSSD", session.averageRMSSD)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(AppTheme.chartLine)
                }
                .frame(height: 100)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            } else {
                Text("Complete a few sessions to see your trend.")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(AppTheme.tertiaryText)
            }
        }
        .padding(16)
        .mindfulCard()
    }

    private var practiceInsightsCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Current Streak")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.tertiaryText)
                Text("\(currentStreakDays) day\(currentStreakDays == 1 ? "" : "s")")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text("This Week")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.tertiaryText)
                Text("\(sevenDaySessionCount) sessions")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text("Total Practice")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.tertiaryText)
                Text("\(totalPracticeMinutes) min")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .mindfulCard()
    }

    private func lastSessionCard(_ session: BreathingSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last Session")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.tertiaryText)

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                    Text(SessionDisplay.duration(session.duration))
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(String(format: "%.1f bpm", session.resonanceRate))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("\(session.peakCoherencePercent)% peak")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.accent)
                }
                .foregroundStyle(AppTheme.primaryText)
            }
        }
        .padding(16)
        .mindfulCard()
    }

    #if DEBUG
    private var wcDiagnosticCard: some View {
        let session = WCSession.isSupported() ? WCSession.default : nil
        let supported = WCSession.isSupported()
        let activated = session?.activationState == .activated
        let paired = session?.isPaired ?? false
        let appInstalled = session?.isWatchAppInstalled ?? false
        let reachable = session?.isReachable ?? false

        return VStack(alignment: .leading, spacing: 8) {
            Text("WCSession Diagnostic")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.tertiaryText)

            VStack(alignment: .leading, spacing: 4) {
                diagRow("Supported", supported)
                diagRow("Activated", activated)
                diagRow("Paired", paired)
                diagRow("Watch App Installed", appInstalled)
                diagRow("Reachable", reachable)
            }
        }
        .padding(16)
        .mindfulCard()
    }

    private func diagRow(_ label: String, _ value: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.secondaryText)
            Spacer()
            Text(value ? "YES" : "NO")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(value ? Color.green : Color.red)
        }
    }
    #endif
}
