import Foundation
import SwiftData
import BreathingCore

@MainActor
final class WatchSessionManager: ObservableObject {
    @Published var isActive = false
    @Published var didComplete = false
    @Published var heartRate: Double = 0
    @Published var rmssd: Double = 0
    @Published var coherence: Double = 0
    @Published var elapsedSeconds: Double = 0
    @Published var sessionProgress: Double = 0
    @Published var currentPhase: BreathingPhase = .inhale
    @Published var guidedBPM: Double = BreathingParameters.defaultBPM
    @Published var pacerPhase: BayesianPacer.Phase = .warmup
    @Published private(set) var lastSession: BreathingSession?

    let workoutManager = WorkoutManager()
    let hapticEngine = HapticEngine()
    private let hrvAnalyzer = HRVAnalyzer()
    private let coherenceCalculator = CoherenceCalculator()
    private var pacer = BayesianPacer()

    private var sessionStartTime: Date?
    private var currentConfiguration: SessionConfiguration = .default
    private var hrSamples: [Double] = []
    private var rmssdHistory: [Double] = []
    private var coherenceHistory: [Double] = []
    private var sessionDataPoints: [SessionDataPoint] = []
    private var lastCapturedSecond: Int = -1
    private var updateTimer: Timer?
    private let updateInterval: TimeInterval = 0.25

    #if targetEnvironment(simulator)
    private var simulationTimer: Timer?
    private var simulationSequence: Int = 0
    #endif

    func startSession(configuration: SessionConfiguration = .default) {
        guard !isActive else { return }

        currentConfiguration = configuration
        isActive = true
        didComplete = false
        lastSession = nil
        sessionStartTime = .now
        elapsedSeconds = 0
        sessionProgress = 0
        heartRate = 0
        rmssd = 0
        coherence = 0
        hrSamples = []
        rmssdHistory = []
        coherenceHistory = []
        sessionDataPoints = []
        lastCapturedSecond = -1
        currentPhase = .inhale

        if let mean = configuration.ecgPriorMean, let std = configuration.ecgPriorStd {
            pacer = BayesianPacer(priorMean: mean, priorStd: std)
        } else {
            pacer = BayesianPacer(priorMean: configuration.startingBPM)
        }
        guidedBPM = pacer.currentParameters.breathsPerMinute
        pacerPhase = .warmup
        hrvAnalyzer.reset()

        workoutManager.onHeartRateUpdate = { [weak self] hr, rrIntervals, timestamp, _ in
            self?.processSample(hr: hr, rrIntervals: rrIntervals, timestamp: timestamp)
        }

        workoutManager.startWorkout()
        if configuration.hapticsEnabled {
            hapticEngine.updateParameters(
                inhale: pacer.currentParameters.inhaleDuration,
                hold: pacer.currentParameters.holdDuration,
                exhale: pacer.currentParameters.exhaleDuration
            )
            hapticEngine.start()
        }

        #if targetEnvironment(simulator)
        startSimulatedHeartRate()
        #endif

        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.tick()
            }
        }
    }

    func stopSession(modelContext: ModelContext? = nil) {
        guard isActive else { return }
        isActive = false
        workoutManager.stopWorkout()
        hapticEngine.stop()
        updateTimer?.invalidate()
        updateTimer = nil
        workoutManager.onHeartRateUpdate = nil

        #if targetEnvironment(simulator)
        simulationTimer?.invalidate()
        simulationTimer = nil
        #endif

        if let modelContext {
            lastSession = persistSession(modelContext: modelContext)
        }
    }

    // MARK: - Summary accessors

    var averageHR: Double {
        hrSamples.isEmpty ? 0 : hrSamples.reduce(0, +) / Double(hrSamples.count)
    }

    var averageRMSSD: Double {
        rmssdHistory.isEmpty ? 0 : rmssdHistory.reduce(0, +) / Double(rmssdHistory.count)
    }

    var peakCoherence: Double {
        max(coherenceHistory.max() ?? 0, coherence)
    }

    var averageCoherence: Double {
        coherenceHistory.isEmpty ? 0 : coherenceHistory.reduce(0, +) / Double(coherenceHistory.count)
    }

    var resonanceRate: Double {
        pacer.currentParameters.breathsPerMinute
    }

    var duration: Double {
        elapsedSeconds
    }

    var targetDuration: TimeInterval {
        currentConfiguration.targetDuration
    }

    // MARK: - Private

    private func processSample(hr: Double, rrIntervals: [Double], timestamp: TimeInterval) {
        if hr > 0 {
            heartRate = hr
            hrSamples.append(hr)
        }

        for rr in rrIntervals where rr.isFinite && rr > 0 {
            hrvAnalyzer.addInterval(rr: rr, timestamp: elapsedSeconds)
        }
    }

    private func tick() {
        guard isActive else { return }
        elapsedSeconds += updateInterval
        sessionProgress = min(elapsedSeconds / currentConfiguration.targetDuration, 1.0)

        if let currentRMSSD = hrvAnalyzer.currentRMSSD(at: elapsedSeconds) {
            rmssd = currentRMSSD
            rmssdHistory.append(currentRMSSD)
        }

        if hrSamples.count >= 32 {
            let recentHR = Array(hrSamples.suffix(120))
            let breathingFreqHz = pacer.currentParameters.breathsPerMinute / 60.0
            coherence = coherenceCalculator.computeCoherence(
                hrSamples: recentHR,
                sampleRateHz: 4.0,
                breathingFreqHz: breathingFreqHz
            )
            coherenceHistory.append(coherence)
        }

        let recentHRForPacer = Array(hrSamples.suffix(30))
        pacer.update(hrSamples: recentHRForPacer, elapsedTime: elapsedSeconds)
        guidedBPM = pacer.currentParameters.breathsPerMinute
        pacerPhase = pacer.phase

        if currentConfiguration.hapticsEnabled {
            hapticEngine.updateParameters(
                inhale: pacer.currentParameters.inhaleDuration,
                hold: pacer.currentParameters.holdDuration,
                exhale: pacer.currentParameters.exhaleDuration
            )
        }

        switch hapticEngine.currentPhase {
        case "inhale": currentPhase = .inhale
        case "hold": currentPhase = .hold
        case "exhale": currentPhase = .exhale
        default: break
        }

        captureDataPointIfNeeded()

        if elapsedSeconds >= currentConfiguration.targetDuration {
            didComplete = true
            stopSession()
        }
    }

    private func captureDataPointIfNeeded() {
        let currentSecond = Int(elapsedSeconds.rounded(.down))
        guard currentSecond != lastCapturedSecond else { return }
        lastCapturedSecond = currentSecond

        let absoluteTimestamp = (sessionStartTime ?? .now).addingTimeInterval(elapsedSeconds)
        let point = SessionDataPoint(
            timestamp: absoluteTimestamp,
            hr: heartRate,
            rmssd: rmssd,
            coherence: coherence,
            breathingRate: pacer.currentParameters.breathsPerMinute
        )
        sessionDataPoints.append(point)
    }

    private func persistSession(modelContext: ModelContext) -> BreathingSession {
        let wallClockDuration = Date.now.timeIntervalSince(sessionStartTime ?? .now)
        let finalDuration = max(elapsedSeconds, wallClockDuration)

        let session = BreathingSession(
            date: sessionStartTime ?? .now,
            duration: finalDuration,
            averageHR: averageHR,
            averageRMSSD: averageRMSSD,
            peakCoherence: peakCoherence,
            resonanceRate: resonanceRate,
            dataPoints: sessionDataPoints
        )
        modelContext.insert(session)
        try? modelContext.save()
        return session
    }

    // MARK: - Simulator

    #if targetEnvironment(simulator)
    private func startSimulatedHeartRate() {
        simulationSequence = 0
        print("[WatchSimHR] Starting simulated heart rate at 1 Hz")
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.injectSimulatedSample()
            }
        }
    }

    private func injectSimulatedSample() {
        let t = elapsedSeconds
        let breathingFreqHz = pacer.currentParameters.breathsPerMinute / 60.0
        let hr = 68.0 + 5.0 * sin(2.0 * Double.pi * breathingFreqHz * t) + Double.random(in: -1...1)
        guard let rrMillis = HeartMath.pseudoRRIntervalMillis(fromHeartRate: hr) else { return }

        simulationSequence += 1
        processSample(hr: hr, rrIntervals: [rrMillis], timestamp: Date.now.timeIntervalSince1970)

        if simulationSequence % 5 == 0 {
            print("[WatchSimHR] t=\(String(format: "%.0f", t))s HR=\(String(format: "%.1f", hr)) RR=\(String(format: "%.0f", rrMillis))ms RMSSD=\(String(format: "%.1f", rmssd)) coherence=\(String(format: "%.3f", coherence))")
        }
    }
    #endif
}
