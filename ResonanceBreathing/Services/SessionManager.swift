import Foundation
import SwiftData
import BreathingCore

@MainActor
final class SessionManager: ObservableObject {
    @Published var isActive = false
    @Published var heartRate: Double = 0
    @Published var rmssd: Double = 0
    @Published var coherence: Double = 0
    @Published var hrvDataPoints: [HRVDataPoint] = []

    let timer: BreathingTimer
    let watchConnector: WatchConnector
    let pacer: AdaptivePacer
    let hrvAnalyzer: HRVAnalyzer
    let coherenceCalculator: CoherenceCalculator

    private var sessionStartTime: Date?
    private var hrSamples: [Double] = []
    private var elapsedSeconds: Double = 0
    private var updateTimer: Timer?

    init() {
        self.timer = BreathingTimer()
        self.watchConnector = WatchConnector()
        self.pacer = AdaptivePacer()
        self.hrvAnalyzer = HRVAnalyzer()
        self.coherenceCalculator = CoherenceCalculator()
    }

    func startSession() {
        isActive = true
        sessionStartTime = .now
        elapsedSeconds = 0
        hrvDataPoints = []
        hrSamples = []
        hrvAnalyzer.reset()

        timer.start()
        watchConnector.sendCommand("startWorkout")

        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.processWatchData()
            }
        }
    }

    func endSession(modelContext: ModelContext) -> BreathingSession {
        isActive = false
        timer.stop()
        watchConnector.sendCommand("stopWorkout")
        updateTimer?.invalidate()

        let duration = Date.now.timeIntervalSince(sessionStartTime ?? .now)
        let session = BreathingSession(
            date: sessionStartTime ?? .now,
            duration: duration,
            averageHR: hrSamples.isEmpty ? 0 : hrSamples.reduce(0, +) / Double(hrSamples.count),
            averageRMSSD: rmssd,
            peakCoherence: coherence,
            resonanceRate: pacer.currentParameters.breathsPerMinute
        )
        modelContext.insert(session)
        return session
    }

    private func processWatchData() {
        elapsedSeconds += 0.25

        let hr = watchConnector.latestHeartRate
        if hr > 0 {
            heartRate = hr
            hrSamples.append(hr)
        }

        for rr in watchConnector.latestRRIntervals {
            hrvAnalyzer.addInterval(rr: rr, timestamp: elapsedSeconds)
        }

        if let currentRMSSD = hrvAnalyzer.currentRMSSD(at: elapsedSeconds) {
            rmssd = currentRMSSD
        }

        if hrSamples.count >= 32 {
            let recentHR = Array(hrSamples.suffix(120))
            let breathingFreqHz = timer.parameters.breathsPerMinute / 60.0
            coherence = coherenceCalculator.computeCoherence(
                hrSamples: recentHR,
                sampleRateHz: 4.0,
                breathingFreqHz: breathingFreqHz
            )
        }

        pacer.update(coherence: coherence, elapsedTime: elapsedSeconds)
        timer.parameters = pacer.currentParameters
        watchConnector.sendBreathingParameters(pacer.currentParameters)

        if Int(elapsedSeconds * 4) % 4 == 0 {
            hrvDataPoints.append(HRVDataPoint(time: elapsedSeconds, value: rmssd))
            if hrvDataPoints.count > 60 {
                hrvDataPoints.removeFirst()
            }
        }
    }
}
