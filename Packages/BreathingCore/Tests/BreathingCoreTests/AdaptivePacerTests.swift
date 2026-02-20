import XCTest
@testable import BreathingCore

final class AdaptivePacerTests: XCTestCase {

    func testStartsInCalibrationPhase() {
        let pacer = AdaptivePacer()
        XCTAssertEqual(pacer.sessionPhase, .calibration)
        XCTAssertEqual(pacer.currentParameters.breathsPerMinute, BreathingParameters.defaultBPM)
    }

    func testTransitionsToExplorationAfterCalibrationDuration() {
        let pacer = AdaptivePacer(calibrationDuration: 10.0, explorationDuration: 20.0)
        pacer.update(coherence: 0.5, elapsedTime: 11.0)
        XCTAssertEqual(pacer.sessionPhase, .exploration)
    }

    func testTransitionsToResonanceLockAfterExploration() {
        let pacer = AdaptivePacer(calibrationDuration: 10.0, explorationDuration: 20.0)
        pacer.update(coherence: 0.5, elapsedTime: 31.0)
        XCTAssertEqual(pacer.sessionPhase, .resonanceLock)
    }

    func testExplorationSweepsBreathingRate() {
        let pacer = AdaptivePacer(calibrationDuration: 2.0, explorationDuration: 60.0)
        var rates: Set<Double> = []
        for t in stride(from: 3.0, through: 60.0, by: 3.0) {
            pacer.update(coherence: Double.random(in: 0.2...0.8), elapsedTime: t)
            rates.insert(pacer.currentParameters.breathsPerMinute)
        }
        XCTAssertGreaterThan(rates.count, 3, "Exploration should try multiple rates")
    }

    func testResonanceLockStabilizesAtBestRate() {
        let pacer = AdaptivePacer(calibrationDuration: 2.0, explorationDuration: 10.0)
        pacer.update(coherence: 0.3, elapsedTime: 1.0)
        pacer.update(coherence: 0.9, elapsedTime: 5.0)
        let bestRate = pacer.currentParameters.breathsPerMinute
        pacer.update(coherence: 0.85, elapsedTime: 13.0)
        XCTAssertEqual(pacer.sessionPhase, .resonanceLock)
        XCTAssertEqual(pacer.currentParameters.breathsPerMinute, bestRate, accuracy: 0.5)
    }

    func testRateStaysWithinValidRange() {
        let pacer = AdaptivePacer(calibrationDuration: 1.0, explorationDuration: 5.0)
        for t in stride(from: 0.0, through: 100.0, by: 1.0) {
            pacer.update(coherence: Double.random(in: 0...1), elapsedTime: t)
            let bpm = pacer.currentParameters.breathsPerMinute
            XCTAssertGreaterThanOrEqual(bpm, BreathingParameters.minBPM)
            XCTAssertLessThanOrEqual(bpm, BreathingParameters.maxBPM)
        }
    }
}
