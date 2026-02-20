import SwiftUI
import SwiftData
import BreathingCore

struct SessionView: View {
    @StateObject private var timer = BreathingTimer()
    @State private var heartRate: Double = 0
    @State private var rmssd: Double = 0
    @State private var coherence: Double = 0
    @State private var hrvData: [HRVDataPoint] = []
    @State private var isAdapting = true

    let onEnd: () -> Void

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                MetricsBarView(heartRate: heartRate, rmssd: rmssd, coherence: coherence)
                    .padding(.top, 8)

                Spacer()

                BloomAnimationView(
                    phase: timer.currentPhase,
                    progress: timer.phaseProgress,
                    coherence: coherence
                )
                .frame(width: 250, height: 250)

                VStack(spacing: 4) {
                    Text(timer.currentPhase.label)
                        .font(.system(.title3, design: .rounded, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(String(format: "%.1fs", timer.phaseTimeRemaining))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.top, 16)

                Spacer()

                HRVChartView(
                    dataPoints: hrvData,
                    breathingRate: timer.parameters.breathsPerMinute,
                    isAdapting: isAdapting
                )
                .padding(.bottom, 16)
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        timer.stop()
                        onEnd()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear { timer.start() }
        .onDisappear { timer.stop() }
    }
}
