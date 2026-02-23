import Foundation
import BreathingCore

@MainActor
final class CalibrationManager: ObservableObject {
    enum State: Equatable {
        case idle
        case preparingRate(index: Int)
        case breathing(index: Int)
        case analyzing
        case complete(bestRate: Double)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.preparingRate(let a), .preparingRate(let b)): return a == b
            case (.breathing(let a), .breathing(let b)): return a == b
            case (.analyzing, .analyzing): return true
            case (.complete(let a), .complete(let b)): return a == b
            default: return false
            }
        }
    }

    static let testRates: [Double] = [4.5, 5.5, 6.5]
    static let segmentDuration: Double = 30.0
    static let restDuration: Double = 3.0

    @Published var state: State = .idle
    @Published var currentRateIndex: Int = 0
    @Published var segmentProgress: Double = 0
    @Published var heartRate: Double = 0
    @Published var guidePhase: BreathingPhase = .inhale
    @Published var guideProgress: Double = 0
    @Published var countdown: Int = 3
    @Published private(set) var rsaResults: [Double] = []

    let watchConnector: WatchConnector
    private let timer: BreathingTimer

    private var segmentHRSamples: [Double] = []
    private var segmentStartTime: Date?
    private var updateTimer: Timer?
    private var countdownTimer: Timer?

    #if targetEnvironment(simulator)
    private var simulationTimer: Timer?
    private var simulationSequence: Int = 0
    #endif

    init(watchConnector: WatchConnector? = nil) {
        self.watchConnector = watchConnector ?? WatchConnector.shared
        self.timer = BreathingTimer()
    }

    func startCalibration() {
        rsaResults = []
        currentRateIndex = 0
        prepareRate(index: 0)
    }

    func cancel() {
        stopTimers()
        timer.stop()
        watchConnector.sendCommand("stopWorkout")
        #if targetEnvironment(simulator)
        simulationTimer?.invalidate()
        simulationTimer = nil
        #endif
        state = .idle
    }

    private func prepareRate(index: Int) {
        currentRateIndex = index
        state = .preparingRate(index: index)
        countdown = 3

        let rate = Self.testRates[index]
        timer.parameters = BreathingParameters(breathsPerMinute: rate)

        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            Task { @MainActor in
                self.countdown -= 1
                if self.countdown <= 0 {
                    timer.invalidate()
                    self.startSegment(index: index)
                }
            }
        }
    }

    private func startSegment(index: Int) {
        state = .breathing(index: index)
        segmentHRSamples = []
        segmentProgress = 0
        segmentStartTime = .now

        watchConnector.resetSampleBuffer()
        watchConnector.sendCommand("startWorkout")
        timer.start()

        #if targetEnvironment(simulator)
        startSimulatedHeartRate()
        #endif

        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.processSegmentData()
            }
        }
    }

    private func processSegmentData() {
        guard let start = segmentStartTime else { return }
        let elapsed = Date.now.timeIntervalSince(start)
        segmentProgress = min(elapsed / Self.segmentDuration, 1.0)

        guidePhase = timer.currentPhase
        guideProgress = timer.phaseProgress

        let samples = watchConnector.drainSamples()
        for sample in samples where sample.heartRate > 0 {
            heartRate = sample.heartRate
            segmentHRSamples.append(sample.heartRate)
        }

        if elapsed >= Self.segmentDuration {
            finishSegment()
        }
    }

    private func finishSegment() {
        stopTimers()
        timer.stop()
        watchConnector.sendCommand("stopWorkout")

        #if targetEnvironment(simulator)
        simulationTimer?.invalidate()
        simulationTimer = nil
        #endif

        let amplitude = RSAAmplitude.compute(hrSamples: segmentHRSamples)
        rsaResults.append(amplitude)

        let nextIndex = currentRateIndex + 1
        if nextIndex < Self.testRates.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.restDuration) { [weak self] in
                self?.prepareRate(index: nextIndex)
            }
        } else {
            analyzeResults()
        }
    }

    private func analyzeResults() {
        state = .analyzing

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            guard let maxIndex = self.rsaResults.enumerated().max(by: { $0.element < $1.element })?.offset else {
                self.state = .idle
                return
            }
            let bestRate = Self.testRates[maxIndex]
            self.state = .complete(bestRate: bestRate)
        }
    }

    private func stopTimers() {
        updateTimer?.invalidate()
        updateTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    // MARK: - Simulator

    #if targetEnvironment(simulator)
    private func startSimulatedHeartRate() {
        simulationSequence = 0
        let rate = Self.testRates[currentRateIndex]
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.injectSimulatedSample(breathingBPM: rate)
            }
        }
    }

    private func injectSimulatedSample(breathingBPM: Double) {
        guard let start = segmentStartTime else { return }
        let t = Date.now.timeIntervalSince(start)
        let breathingFreqHz = breathingBPM / 60.0
        let amplitude: Double = breathingBPM == 5.5 ? 7.0 : (breathingBPM == 6.5 ? 5.0 : 3.0)
        let hr = 68.0 + amplitude * sin(2.0 * .pi * breathingFreqHz * t) + Double.random(in: -1...1)

        simulationSequence += 1
        let sample = WatchPhysioSample(
            timestamp: Date.now.timeIntervalSince1970,
            heartRate: hr,
            rrIntervals: [],
            sequence: simulationSequence
        )
        watchConnector.enqueueSample(sample)
    }
    #endif
}
