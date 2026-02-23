import XCTest
import BreathingCore

final class HeartMathTests: XCTestCase {
    func testPseudoRRIntervalIsBoundedAndStable() {
        XCTAssertNil(HeartMath.pseudoRRIntervalMillis(fromHeartRate: 0))
        XCTAssertNil(HeartMath.pseudoRRIntervalMillis(fromHeartRate: -12))

        XCTAssertEqual(HeartMath.pseudoRRIntervalMillis(fromHeartRate: 60) ?? 0, 1000, accuracy: 0.01)
        XCTAssertEqual(HeartMath.pseudoRRIntervalMillis(fromHeartRate: 120) ?? 0, 500, accuracy: 0.01)
        XCTAssertEqual(HeartMath.pseudoRRIntervalMillis(fromHeartRate: 300) ?? 0, HeartMath.minRRMillis, accuracy: 0.001)
        XCTAssertEqual(HeartMath.pseudoRRIntervalMillis(fromHeartRate: 10) ?? 0, HeartMath.maxRRMillis, accuracy: 0.001)
    }
}
