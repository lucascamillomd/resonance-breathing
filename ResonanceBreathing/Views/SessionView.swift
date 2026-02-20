import SwiftUI
import SwiftData
import BreathingCore

struct SessionView: View {
    @StateObject private var sessionManager = SessionManager()
    @Environment(\.modelContext) private var modelContext
    let onEnd: (BreathingSession?) -> Void

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                MetricsBarView(
                    heartRate: sessionManager.heartRate,
                    rmssd: sessionManager.rmssd,
                    coherence: sessionManager.coherence
                )
                .padding(.top, 8)

                Spacer()

                BloomAnimationView(
                    phase: sessionManager.timer.currentPhase,
                    progress: sessionManager.timer.phaseProgress,
                    coherence: sessionManager.coherence
                )
                .frame(width: 250, height: 250)

                VStack(spacing: 4) {
                    Text(sessionManager.timer.currentPhase.label)
                        .font(.system(.title3, design: .rounded, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(String(format: "%.1fs", sessionManager.timer.phaseTimeRemaining))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.top, 16)

                Spacer()

                HRVChartView(
                    dataPoints: sessionManager.hrvDataPoints,
                    breathingRate: sessionManager.timer.parameters.breathsPerMinute,
                    isAdapting: sessionManager.pacer.sessionPhase != .resonanceLock
                )
                .padding(.bottom, 16)
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: endSession) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear { sessionManager.startSession() }
        .onDisappear { if sessionManager.isActive { endSession() } }
    }

    private func endSession() {
        let session = sessionManager.endSession(modelContext: modelContext)
        onEnd(session)
    }
}
