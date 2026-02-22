import SwiftUI
import SwiftData
import BreathingCore
#if os(iOS)
import UIKit
#endif

struct SessionView: View {
    @StateObject private var sessionManager = SessionManager()
    @Environment(\.modelContext) private var modelContext
    @State private var didSendEndCallback = false

    let configuration: SessionConfiguration
    let onEnd: (BreathingSession?) -> Void

    private var remainingTimeText: String {
        let remaining = max(configuration.targetDuration - sessionManager.elapsedSeconds, 0)
        return SessionDisplay.duration(remaining)
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    MetricsBarView(
                        heartRate: sessionManager.heartRate,
                        rmssd: sessionManager.rmssd,
                        coherence: sessionManager.coherence
                    )

                    Button(action: endSession) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(AppTheme.cardFill))
                            .overlay(Circle().stroke(AppTheme.cardStroke, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                VStack(spacing: 12) {
                    BloomAnimationView(
                        phase: sessionManager.timer.currentPhase,
                        progress: sessionManager.timer.phaseProgress,
                        coherence: sessionManager.coherence
                    )
                    .frame(width: 320, height: 320)

                    Text(sessionManager.timer.currentPhase.label)
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.primaryText)

                    Text(String(format: "%.1fs", sessionManager.timer.phaseTimeRemaining))
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.secondaryText)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Session")
                            Spacer()
                            Text("\(remainingTimeText) left")
                        }
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.tertiaryText)

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.13))
                                Capsule()
                                    .fill(AppTheme.buttonGradient)
                                    .frame(width: max(4, proxy.size.width * sessionManager.sessionProgress))
                            }
                        }
                        .frame(height: 7)
                    }
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 0)

                HRVChartView(
                    dataPoints: sessionManager.hrvDataPoints,
                    breathingRate: sessionManager.timer.parameters.breathsPerMinute,
                    isAdapting: sessionManager.pacer.phase != .converged
                )
                .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onAppear {
            didSendEndCallback = false
            setIdleTimer(disabled: true)
            sessionManager.startSession(configuration: configuration)
        }
        .onDisappear {
            setIdleTimer(disabled: false)
            if sessionManager.isActive { endSession() }
        }
        .onChange(of: sessionManager.didCompleteTargetDuration) { _, didComplete in
            if didComplete {
                endSession()
            }
        }
    }

    private func endSession() {
        guard !didSendEndCallback else { return }
        didSendEndCallback = true
        setIdleTimer(disabled: false)
        let session = sessionManager.endSession(modelContext: modelContext)
        onEnd(session)
    }

    private func setIdleTimer(disabled: Bool) {
#if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = disabled
#endif
    }
}
