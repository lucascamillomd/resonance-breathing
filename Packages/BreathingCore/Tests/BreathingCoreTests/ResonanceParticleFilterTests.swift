import XCTest
@testable import BreathingCore

final class ResonanceParticleFilterTests: XCTestCase {

    func testInitialEstimateNearPrior() {
        let pf = ResonanceParticleFilter(priorMean: 5.5, priorStd: 0.75)
        let state = pf.currentState
        XCTAssertEqual(state.estimatedFrequencyBPM, 5.5, accuracy: 0.5,
                       "Initial estimate should be near prior mean")
    }

    func testConvergesToTrueFrequencyWithRepeatedObservations() {
        let pf = ResonanceParticleFilter(priorMean: 5.5, priorStd: 0.75)
        let trueResonance = 6.0

        for _ in 0..<20 {
            let amplitude = resonanceCurve(rate: 6.0, trueRate: trueResonance)
            pf.update(observedAmplitude: amplitude, currentRateBPM: 6.0)
        }

        XCTAssertEqual(pf.currentState.estimatedFrequencyBPM, trueResonance, accuracy: 0.3,
                       "Should converge toward the rate that produces highest amplitude")
    }

    func testUncertaintyDecreasesWithObservations() {
        let pf = ResonanceParticleFilter(priorMean: 5.5, priorStd: 0.75)
        let initialUncertainty = pf.currentState.uncertainty

        for _ in 0..<10 {
            pf.update(observedAmplitude: 8.0, currentRateBPM: 5.5)
        }

        XCTAssertLessThan(pf.currentState.uncertainty, initialUncertainty,
                          "Uncertainty should decrease with observations")
    }

    func testEstimateStaysInValidRange() {
        let pf = ResonanceParticleFilter(priorMean: 5.5, priorStd: 0.75)
        for _ in 0..<50 {
            let rate = Double.random(in: 4.5...7.0)
            pf.update(observedAmplitude: Double.random(in: 0...15), currentRateBPM: rate)
            let est = pf.currentState.estimatedFrequencyBPM
            XCTAssertGreaterThanOrEqual(est, 4.0)
            XCTAssertLessThanOrEqual(est, 7.5)
        }
    }

    func testECGPriorNarrowsInitialDistribution() {
        let widePrior = ResonanceParticleFilter(priorMean: 5.5, priorStd: 0.75)
        let narrowPrior = ResonanceParticleFilter(priorMean: 5.8, priorStd: 0.2)

        XCTAssertLessThan(narrowPrior.currentState.uncertainty,
                          widePrior.currentState.uncertainty,
                          "ECG-derived narrow prior should have less initial uncertainty")
    }

    private func resonanceCurve(rate: Double, trueRate: Double, peakAmplitude: Double = 10.0, width: Double = 0.5) -> Double {
        peakAmplitude * exp(-pow(rate - trueRate, 2) / (2 * width * width))
    }
}
