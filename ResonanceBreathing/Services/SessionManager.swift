import Foundation
import SwiftData
import BreathingCore

@MainActor
final class SessionManager: ObservableObject {
    @Published var isActive = false
    @Published var didCompleteTargetDuration = false
    @Published var heartRate: Double = 0
    @Published var rmssd: Double = 0
    @Published var coherence: Double = 0
    @Published var elapsedSeconds: Double = 0
    @Published var sessionProgress: Double = 0
    @Published var hrvDataPoints: [HRVDataPoint] = []
    @Published var hrTimeSeries: [(time: Double, hr: Double)] = []

    let timer: BreathingTimer
    let watchConnector: WatchConnector
    let hrvAnalyzer: HRVAnalyzer
    let coherenceCalculator: CoherenceCalculator

    private(set) var pacer: BayesianPacer

    private var sessionStartTime: Date?
    private var sessionStartEpoch: TimeInterval?
    private var currentConfiguration: SessionConfiguration = .default
    private var hrSamples: [Double] = []
    private var rmssdHistory: [Double] = []
    private var coherenceHistory: [Double] = []
    private var sessionDataPoints: [SessionDataPoint] = []
    private var updateTimer: Timer?
    private var lastCapturedSecond: Int = -1
    private let updateInterval: TimeInterval
    private let autoScheduleUpdates: Bool
    private let runBreathingTimer: Bool

    #if targetEnvironment(simulator)
    private var simulationTimer: Timer?
    private var simulationSequence: Int = 0
    #endif

    init(
        timer: BreathingTimer? = nil,
        watchConnector: WatchConnector? = nil,
        hrvAnalyzer: HRVAnalyzer = HRVAnalyzer(),
        coherenceCalculator: CoherenceCalculator = CoherenceCalculator(),
        updateInterval: TimeInterval = 0.25,
        autoScheduleUpdates: Bool = true,
        runBreathingTimer: Bool = true
    ) {
        self.timer = timer ?? BreathingTimer()
        self.watchConnector = watchConnector ?? WatchConnector.shared
        self.hrvAnalyzer = hrvAnalyzer
        self.coherenceCalculator = coherenceCalculator
        self.pacer = BayesianPacer()
        self.updateInterval = updateInterval
        self.autoScheduleUpdates = autoScheduleUpdates
        self.runBreathingTimer = runBreathingTimer
    }

    func startSession(configuration: SessionConfiguration = .default) {
        guard !isActive else { return }

        currentConfiguration = configuration
        isActive = true
        didCompleteTargetDuration = false
        sessionStartTime = .now
        sessionStartEpoch = sessionStartTime?.timeIntervalSince1970
        elapsedSeconds = 0
        sessionProgress = 0
        heartRate = 0
        rmssd = 0
        coherence = 0
        hrvDataPoints = []
        hrTimeSeries = []
        hrSamples = []
        rmssdHistory = []
        coherenceHistory = []
        sessionDataPoints = []
        lastCapturedSecond = -1

        watchConnector.resetSampleBuffer()
        if let mean = configuration.ecgPriorMean, let std = configuration.ecgPriorStd {
            pacer = BayesianPacer(priorMean: mean, priorStd: std)
        } else {
            pacer = BayesianPacer(priorMean: configuration.startingBPM)
        }
        timer.parameters = pacer.currentParameters
        hrvAnalyzer.reset()

        if runBreathingTimer {
            timer.start()
        }
        watchConnector.sendCommand(configuration.hapticsEnabled ? "startWorkout" : "startWorkoutNoHaptics")
        watchConnector.sendBreathingParameters(timer.parameters)

        #if targetEnvironment(simulator)
        startSimulatedHeartRate()
        #endif

        guard autoScheduleUpdates else { return }
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.processWatchData(deltaTime: self.updateInterval)
            }
        }
    }

    func endSession(modelContext: ModelContext) -> BreathingSession? {
        guard isActive else { return nil }
        isActive = false
        if runBreathingTimer {
            timer.stop()
        }
        watchConnector.sendCommand("stopWorkout")
        updateTimer?.invalidate()
        updateTimer = nil

        #if targetEnvironment(simulator)
        simulationTimer?.invalidate()
        simulationTimer = nil
        #endif

        let wallClockDuration = Date.now.timeIntervalSince(sessionStartTime ?? .now)
        let duration = max(elapsedSeconds, wallClockDuration)
        let averageHR = hrSamples.average
        let averageRMSSD = rmssdHistory.average
        let peakCoherence = max(coherenceHistory.max() ?? 0, coherence)

        let session = BreathingSession(
            date: sessionStartTime ?? .now,
            duration: duration,
            averageHR: averageHR,
            averageRMSSD: averageRMSSD,
            peakCoherence: peakCoherence,
            resonanceRate: timer.parameters.breathsPerMinute,
            dataPoints: sessionDataPoints
        )
        modelContext.insert(session)
        try? modelContext.save()
        return session
    }

    func processWatchData(deltaTime: Double = 0.25) {
        guard isActive else { return }
        elapsedSeconds += deltaTime
        sessionProgress = min(elapsedSeconds / currentConfiguration.targetDuration, 1.0)

        let samples = watchConnector.drainSamples()
        for sample in samples {
            processSample(sample)
        }

        if let currentRMSSD = hrvAnalyzer.currentRMSSD(at: elapsedSeconds) {
            rmssd = currentRMSSD
            rmssdHistory.append(currentRMSSD)
        }

        if hrSamples.count >= 32 {
            let recentHR = Array(hrSamples.suffix(120))
            let breathingFreqHz = timer.parameters.breathsPerMinute / 60.0
            coherence = coherenceCalculator.computeCoherence(
                hrSamples: recentHR,
                sampleRateHz: 4.0,
                breathingFreqHz: breathingFreqHz
            )
            coherenceHistory.append(coherence)
        }

        let recentHRForPacer = Array(hrSamples.suffix(30))
        pacer.update(hrSamples: recentHRForPacer, elapsedTime: elapsedSeconds)
        timer.parameters = pacer.currentParameters
        if currentConfiguration.hapticsEnabled {
            watchConnector.sendBreathingParameters(pacer.currentParameters)
        }

        captureDataPointIfNeeded()

        if elapsedSeconds >= currentConfiguration.targetDuration {
            didCompleteTargetDuration = true
            updateTimer?.invalidate()
            updateTimer = nil
        }
    }

    private func processSample(_ sample: WatchPhysioSample) {
        if sample.heartRate > 0 {
            heartRate = sample.heartRate
            hrSamples.append(sample.heartRate)
            hrTimeSeries.append((time: elapsedSeconds, hr: sample.heartRate))
            if hrTimeSeries.count > 300 {
                hrTimeSeries.removeFirst()
            }
        }

        let relativeTimestamp = max(
            elapsedSeconds,
            sample.timestamp - (sessionStartEpoch ?? sample.timestamp)
        )

        for rr in sample.rrIntervals where rr.isFinite && rr > 0 {
            hrvAnalyzer.addInterval(rr: rr, timestamp: relativeTimestamp)
        }
    }

    // MARK: - Simulator Heart Rate Simulation

    #if targetEnvironment(simulator)
    private func startSimulatedHeartRate() {
        simulationSequence = 0
        print("[SimHR] Starting simulated heart rate at 1 Hz")
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.injectSimulatedSample()
            }
        }
    }

    private func injectSimulatedSample() {
        let t = elapsedSeconds
        let breathingFreqHz = timer.parameters.breathsPerMinute / 60.0
        let hr = 68.0 + 5.0 * sin(2.0 * Double.pi * breathingFreqHz * t) + Double.random(in: -1...1)

        guard let rrMillis = HeartMath.pseudoRRIntervalMillis(fromHeartRate: hr) else { return }

        simulationSequence += 1
        let sample = WatchPhysioSample(
            timestamp: Date.now.timeIntervalSince1970,
            heartRate: hr,
            rrIntervals: [rrMillis],
            sequence: simulationSequence
        )
        watchConnector.enqueueSample(sample)

        if simulationSequence % 5 == 0 {
            print("[SimHR] t=\(String(format: "%.0f", t))s seq=\(simulationSequence) HR=\(String(format: "%.1f", hr)) RR=\(String(format: "%.0f", rrMillis))ms RMSSD=\(String(format: "%.1f", rmssd)) coherence=\(String(format: "%.3f", coherence))")
        }
    }
    #endif

    private func captureDataPointIfNeeded() {
        let currentSecond = Int(elapsedSeconds.rounded(.down))
        guard currentSecond != lastCapturedSecond else { return }
        lastCapturedSecond = currentSecond

        hrvDataPoints.append(HRVDataPoint(time: elapsedSeconds, value: rmssd))
        if hrvDataPoints.count > 120 {
            hrvDataPoints.removeFirst()
        }

        let absoluteTimestamp = (sessionStartTime ?? .now).addingTimeInterval(elapsedSeconds)
        let point = SessionDataPoint(
            timestamp: absoluteTimestamp,
            hr: heartRate,
            rmssd: rmssd,
            coherence: coherence,
            breathingRate: timer.parameters.breathsPerMinute
        )
        sessionDataPoints.append(point)
    }
}

private extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
