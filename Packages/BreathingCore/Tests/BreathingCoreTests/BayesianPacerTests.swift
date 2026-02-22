import XCTest
@testable import BreathingCore

final class BayesianPacerTests: XCTestCase {

    func testStartsInWarmupPhase() {
        let pacer = BayesianPacer()
        XCTAssertEqual(pacer.phase, .warmup)
    }

    func testOutputsValidBreathingParameters() {
        let pacer = BayesianPacer()
        let bpm = pacer.currentParameters.breathsPerMinute
        XCTAssertGreaterThanOrEqual(bpm, BreathingParameters.minBPM)
        XCTAssertLessThanOrEqual(bpm, BreathingParameters.maxBPM)
    }

    func testTransitionsToExploringAfterWarmup() {
        let pacer = BayesianPacer(warmupDuration: 5.0, observationInterval: 1.0)
        let hrSamples = generateSinusoidalHR(seconds: 8, breathingFreqHz: 0.092)
        pacer.update(hrSamples: hrSamples, elapsedTime: 6.0)
        XCTAssertEqual(pacer.phase, .exploring)
    }

    func testTransitionsToConvergedWhenUncertaintyLow() {
        let pacer = BayesianPacer(warmupDuration: 2.0, convergenceThreshold: 0.5)
        for t in stride(from: 3.0, through: 120.0, by: 5.0) {
            let hrSamples = generateSinusoidalHR(seconds: 30, breathingFreqHz: 0.092, amplitude: 8.0)
            pacer.update(hrSamples: hrSamples, elapsedTime: t)
        }
        XCTAssertEqual(pacer.phase, .converged)
    }

    func testRateStaysWithinBounds() {
        let pacer = BayesianPacer(warmupDuration: 1.0)
        for t in stride(from: 0.0, through: 60.0, by: 3.0) {
            let hrSamples = generateSinusoidalHR(seconds: 10, breathingFreqHz: 0.1)
            pacer.update(hrSamples: hrSamples, elapsedTime: t)
            let bpm = pacer.currentParameters.breathsPerMinute
            XCTAssertGreaterThanOrEqual(bpm, BreathingParameters.minBPM)
            XCTAssertLessThanOrEqual(bpm, BreathingParameters.maxBPM)
        }
    }

    func testECGPriorInfluencesInitialRate() {
        let defaultPacer = BayesianPacer()
        let ecgPacer = BayesianPacer(priorMean: 6.2, priorStd: 0.2)
        XCTAssertEqual(ecgPacer.currentParameters.breathsPerMinute, 6.2, accuracy: 0.3)
        XCTAssertEqual(defaultPacer.currentParameters.breathsPerMinute, 5.5, accuracy: 0.3)
    }

    func testEstimatedResonanceFrequencyAccessible() {
        let pacer = BayesianPacer()
        XCTAssertGreaterThan(pacer.estimatedResonanceFrequency, 4.0)
        XCTAssertLessThan(pacer.estimatedResonanceFrequency, 8.0)
    }

    private func generateSinusoidalHR(seconds: Int, breathingFreqHz: Double, amplitude: Double = 5.0) -> [Double] {
        (0..<seconds).map { i in
            68.0 + amplitude * sin(2.0 * .pi * breathingFreqHz * Double(i))
        }
    }
}
