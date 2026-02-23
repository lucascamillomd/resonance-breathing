import Foundation

public final class BayesianPacer: @unchecked Sendable {
    public enum Phase: String, Sendable, Equatable {
        case warmup
        case exploring
        case converged
    }

    public private(set) var phase: Phase = .warmup
    public private(set) var currentParameters: BreathingParameters

    private let particleFilter: ResonanceParticleFilter
    private let rateSelector: UCBRateSelector
    private let warmupDuration: Double
    private let convergenceThreshold: Double
    private let observationInterval: Double
    private var lastObservationTime: Double = 0
    private var startingBPM: Double

    public init(
        priorMean: Double = BreathingParameters.defaultBPM,
        priorStd: Double = 0.75,
        warmupDuration: Double = 60.0,
        convergenceThreshold: Double = 0.08,
        observationInterval: Double = 30.0
    ) {
        self.warmupDuration = warmupDuration
        self.convergenceThreshold = convergenceThreshold
        self.observationInterval = observationInterval
        self.startingBPM = priorMean
        self.currentParameters = BreathingParameters(breathsPerMinute: priorMean)
        self.particleFilter = ResonanceParticleFilter(
            priorMean: priorMean,
            priorStd: priorStd
        )
        self.rateSelector = UCBRateSelector()
    }

    public var estimatedResonanceFrequency: Double {
        particleFilter.currentState.estimatedFrequencyBPM
    }

    public var uncertainty: Double {
        particleFilter.currentState.uncertainty
    }

    public func update(hrSamples: [Double], elapsedTime: Double) {
        if elapsedTime < warmupDuration {
            phase = .warmup
            return
        }

        guard elapsedTime - lastObservationTime >= observationInterval else { return }
        lastObservationTime = elapsedTime

        let amplitude = RSAAmplitude.compute(hrSamples: hrSamples)
        let currentRateBPM = currentParameters.breathsPerMinute

        let state = particleFilter.update(
            observedAmplitude: amplitude,
            currentRateBPM: currentRateBPM
        )

        rateSelector.recordReward(rate: currentRateBPM, reward: amplitude)

        if state.uncertainty < convergenceThreshold && phase != .warmup {
            phase = .converged
            currentParameters = BreathingParameters(breathsPerMinute: state.estimatedFrequencyBPM)
            return
        }

        phase = .exploring
        let nextRate = rateSelector.selectRate()
        currentParameters = BreathingParameters(breathsPerMinute: nextRate)
    }
}
