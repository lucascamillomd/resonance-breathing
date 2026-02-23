import SwiftUI
import SwiftData
import BreathingCore

struct WatchSessionView: View {
    @ObservedObject var sessionManager: WatchSessionManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserSettings.defaultDuration) private var settings: [UserSettings]

    private var sessionConfiguration: SessionConfiguration {
        SessionConfiguration(settings: settings.first)
    }

    private var elapsedText: String {
        let mins = Int(sessionManager.elapsedSeconds) / 60
        let secs = Int(sessionManager.elapsedSeconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var coherencePercent: Int {
        Int((sessionManager.coherence * 100).rounded())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundForState
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.4), value: sessionManager.currentPhase)

                if sessionManager.isActive {
                    activeSessionView
                } else if sessionManager.didComplete {
                    summaryView
                } else {
                    startView
                }
            }
            .task {
                _ = try? UserSettingsBootstrapper.ensureSettings(modelContext: modelContext)
            }
        }
    }

    // MARK: - Background

    private var backgroundForState: some View {
        Group {
            if sessionManager.isActive {
                let isInhale = sessionManager.currentPhase == .inhale
                LinearGradient(
                    colors: isInhale
                        ? [Color(red: 0.06, green: 0.10, blue: 0.22), Color(red: 0.02, green: 0.05, blue: 0.14)]
                        : [Color(red: 0.04, green: 0.14, blue: 0.16), Color(red: 0.02, green: 0.07, blue: 0.10)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.14, blue: 0.24), Color(red: 0.03, green: 0.07, blue: 0.14)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    // MARK: - Active Session

    private let inhaleColor = Color(red: 0.45, green: 0.76, blue: 0.98)
    private let exhaleColor = Color(red: 0.38, green: 0.9, blue: 0.77)

    private var breathExpansion: Double {
        switch sessionManager.currentPhase {
        case .inhale: return sessionManager.phaseProgress
        case .exhale: return 1.0 - sessionManager.phaseProgress
        case .hold: return 1.0
        }
    }

    private var phaseColor: Color {
        sessionManager.currentPhase == .inhale ? inhaleColor : exhaleColor
    }

    private var activeSessionView: some View {
        VStack(spacing: 2) {
            // Phase label + breathing circle row
            HStack(spacing: 8) {
                // Breathing circle — fully closed (12pt) to fully open (72pt)
                ZStack {
                    let circleSize: CGFloat = 12 + CGFloat(breathExpansion) * 60
                    Circle()
                        .fill(phaseColor.opacity(0.06 + breathExpansion * 0.08))
                        .frame(width: 76, height: 76)
                    Circle()
                        .fill(phaseColor.opacity(0.2 + breathExpansion * 0.35))
                        .frame(width: circleSize, height: circleSize)
                    Circle()
                        .stroke(phaseColor, lineWidth: 2.5)
                        .frame(width: circleSize, height: circleSize)
                }
                .animation(.easeInOut(duration: 0.2), value: breathExpansion)

                // Right side: phase + metrics
                VStack(alignment: .leading, spacing: 2) {
                    Text(sessionManager.currentPhase.label)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(phaseColor)

                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Color(red: 0.98, green: 0.41, blue: 0.44))
                            Text("\(Int(sessionManager.heartRate))")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        HStack(spacing: 2) {
                            Text("HRV")
                                .font(.system(size: 8, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                            Text("\(Int(sessionManager.rmssd))")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(exhaleColor)
                        }
                    }

                    HStack(spacing: 4) {
                        Text(String(format: "%.1f bpm", sessionManager.guidedBPM))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(sessionManager.pacerPhase == .converged ? "Locked" : (sessionManager.pacerPhase == .exploring ? "Tuning" : "Warmup"))
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                            .foregroundStyle(sessionManager.pacerPhase == .converged ? exhaleColor : .white.opacity(0.4))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(sessionManager.pacerPhase == .converged ? exhaleColor.opacity(0.15) : Color.white.opacity(0.08))
                            )
                        Text(elapsedText)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)

            // Session progress bar
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(phaseColor.opacity(0.6))
                        .frame(width: max(2, proxy.size.width * sessionManager.sessionProgress))
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 4)

            // Live waveform
            liveWaveformView
                .frame(height: 70)
                .padding(.horizontal, 2)

            Button("Stop") {
                sessionManager.stopSession(modelContext: modelContext)
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.red.opacity(0.8))
        }
        .padding(.vertical, 2)
    }

    // MARK: - Live Waveform

    private var liveWaveformView: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let window: Double = 30.0
            let windowEnd = max(window, sessionManager.elapsedSeconds)
            let windowStart = windowEnd - window
            guard window > 0 else { return }

            // Subtle grid lines
            for i in 1..<4 {
                let y = h * Double(i) / 4.0
                var gridLine = Path()
                gridLine.move(to: CGPoint(x: 0, y: y))
                gridLine.addLine(to: CGPoint(x: w, y: y))
                context.stroke(gridLine, with: .color(.white.opacity(0.06)), lineWidth: 0.5)
            }

            // HR trace (red/pink)
            let hrPoints = sessionManager.hrTimeSeries.filter { $0.time >= windowStart && $0.time <= windowEnd }
            if hrPoints.count >= 2 {
                let hrs = hrPoints.map(\.hr)
                let minHR = hrs.min()!
                let maxHR = hrs.max()!
                let range = max(maxHR - minHR, 2.0)
                let padding = range * 0.1
                let yMin = minHR - padding
                let yMax = maxHR + padding
                let yRange = yMax - yMin

                var hrPath = Path()
                var fillPath = Path()
                for (i, pt) in hrPoints.enumerated() {
                    let x = ((pt.time - windowStart) / window) * w
                    let y = h - ((pt.hr - yMin) / yRange) * h
                    if i == 0 {
                        hrPath.move(to: CGPoint(x: x, y: y))
                        fillPath.move(to: CGPoint(x: x, y: h))
                        fillPath.addLine(to: CGPoint(x: x, y: y))
                    } else {
                        hrPath.addLine(to: CGPoint(x: x, y: y))
                        fillPath.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                // Fill under HR curve
                if let lastPt = hrPoints.last {
                    let lastX = ((lastPt.time - windowStart) / window) * w
                    fillPath.addLine(to: CGPoint(x: lastX, y: h))
                    fillPath.closeSubpath()
                }
                context.fill(fillPath, with: .color(Color(red: 0.98, green: 0.41, blue: 0.44).opacity(0.1)))
                context.stroke(hrPath, with: .color(Color(red: 0.98, green: 0.41, blue: 0.44).opacity(0.8)), lineWidth: 1.5)
            }

            // RMSSD trace (teal, dashed)
            let rmssdPoints = sessionManager.rmssdTimeSeries.filter { $0.time >= windowStart && $0.time <= windowEnd }
            if rmssdPoints.count >= 2 {
                let vals = rmssdPoints.map(\.value)
                let minV = max((vals.min() ?? 0) - 5, 0)
                let maxV = (vals.max() ?? 100) + 5
                let yRange = max(maxV - minV, 1.0)

                var rmssdPath = Path()
                for (i, pt) in rmssdPoints.enumerated() {
                    let x = ((pt.time - windowStart) / window) * w
                    let y = h - ((pt.value - minV) / yRange) * h
                    if i == 0 {
                        rmssdPath.move(to: CGPoint(x: x, y: y))
                    } else {
                        rmssdPath.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                context.stroke(
                    rmssdPath,
                    with: .color(Color(red: 0.38, green: 0.9, blue: 0.77).opacity(0.6)),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 2])
                )
            }

            // "Now" line
            let nowX = ((sessionManager.elapsedSeconds - windowStart) / window) * w
            if nowX >= 0 && nowX <= w {
                var nowLine = Path()
                nowLine.move(to: CGPoint(x: nowX, y: 0))
                nowLine.addLine(to: CGPoint(x: nowX, y: h))
                context.stroke(nowLine, with: .color(.white.opacity(0.25)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
            }

            // Labels
            context.draw(
                Text("HR").font(.system(size: 7, weight: .medium)).foregroundColor(Color(red: 0.98, green: 0.41, blue: 0.44).opacity(0.7)),
                at: CGPoint(x: 12, y: 6)
            )
            context.draw(
                Text("HRV").font(.system(size: 7, weight: .medium)).foregroundColor(Color(red: 0.38, green: 0.9, blue: 0.77).opacity(0.6)),
                at: CGPoint(x: 34, y: 6)
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Summary

    private var summaryView: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Session Complete")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 5)
                        .frame(width: 70, height: 70)
                    Circle()
                        .trim(from: 0, to: sessionManager.peakCoherence)
                        .stroke(
                            Color(red: 0.38, green: 0.9, blue: 0.77),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 70, height: 70)
                    VStack(spacing: 0) {
                        Text("\(Int((sessionManager.peakCoherence * 100).rounded()))%")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Peak")
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    summaryCell("Avg HR", "\(Int(sessionManager.averageHR)) bpm")
                    summaryCell("RMSSD", "\(Int(sessionManager.averageRMSSD)) ms")
                    summaryCell("Duration", SessionDisplay.duration(sessionManager.duration))
                    summaryCell("Rate", String(format: "%.1f bpm", sessionManager.resonanceRate))
                }

                Button("Done") {
                    sessionManager.didComplete = false
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(red: 0.38, green: 0.9, blue: 0.77))
                )
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Start

    private var startView: some View {
        VStack(spacing: 10) {
            Text("Resonance")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)

            Button(action: {
                sessionManager.startSession(configuration: sessionConfiguration)
            }) {
                Text("Start Session")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(red: 0.38, green: 0.9, blue: 0.77))
                    )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: WatchHistoryView()) {
                Text("History")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }

            NavigationLink(destination: WatchSettingsView()) {
                Text("Settings")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    // MARK: - Helpers

    private func summaryCell(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}
