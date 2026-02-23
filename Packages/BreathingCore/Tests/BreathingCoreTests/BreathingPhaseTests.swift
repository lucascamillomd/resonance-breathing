import XCTest
@testable import BreathingCore

final class BreathingPhaseTests: XCTestCase {

    func testPhaseCycleThroughInhaleHoldExhale() {
        let phase = BreathingPhase.inhale
        XCTAssertEqual(phase.next, .exhale)
        XCTAssertEqual(BreathingPhase.hold.next, .exhale)
        XCTAssertEqual(BreathingPhase.exhale.next, .inhale)
    }

    func testDefaultParametersAt5_5BPM() {
        let params = BreathingParameters(breathsPerMinute: 5.5)
        let cycleDuration = params.inhaleDuration + params.holdDuration + params.exhaleDuration
        let expectedCycle = 60.0 / 5.5
        XCTAssertEqual(cycleDuration, expectedCycle, accuracy: 0.01)
    }

    func testExhaleAlwaysLongerThanInhale() {
        for bpm in stride(from: 4.5, through: 7.0, by: 0.5) {
            let params = BreathingParameters(breathsPerMinute: bpm)
            XCTAssertGreaterThanOrEqual(params.exhaleDuration, params.inhaleDuration,
                "Exhale should be >= inhale at \(bpm) bpm")
        }
    }

    func testInhaleExhaleRatioApproximately4to6() {
        let params = BreathingParameters(breathsPerMinute: 5.5)
        let totalBreathing = params.inhaleDuration + params.exhaleDuration
        let inhaleRatio = params.inhaleDuration / totalBreathing
        XCTAssertEqual(inhaleRatio, 0.4, accuracy: 0.05)
    }

    func testParametersClampToValidRange() {
        let tooFast = BreathingParameters(breathsPerMinute: 20.0)
        XCTAssertEqual(tooFast.breathsPerMinute, 7.0)

        let tooSlow = BreathingParameters(breathsPerMinute: 1.0)
        XCTAssertEqual(tooSlow.breathsPerMinute, 4.5)
    }
}
