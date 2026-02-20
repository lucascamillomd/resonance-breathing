import XCTest
@testable import BreathingCore

final class BreathingCoreTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(BreathingCore.version, "0.1.0")
    }
}
