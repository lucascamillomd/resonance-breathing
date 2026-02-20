import XCTest
@testable import BreathingCore

final class HRVAnalyzerTests: XCTestCase {

    func testRMSSDWithKnownValues() {
        // R-R intervals in milliseconds: [800, 810, 795, 820, 805]
        // Successive diffs: [10, -15, 25, -15]
        // Squared: [100, 225, 625, 225]
        // Mean: 293.75
        // RMSSD: sqrt(293.75) ≈ 17.14
        let analyzer = HRVAnalyzer()
        let intervals: [Double] = [800, 810, 795, 820, 805]
        let rmssd = analyzer.computeRMSSD(rrIntervals: intervals)
        XCTAssertNotNil(rmssd)
        XCTAssertEqual(rmssd!, 17.14, accuracy: 0.01)
    }

    func testRMSSDNeedsAtLeastTwoIntervals() {
        let analyzer = HRVAnalyzer()
        XCTAssertNil(analyzer.computeRMSSD(rrIntervals: []))
        XCTAssertNil(analyzer.computeRMSSD(rrIntervals: [800]))
    }

    func testConstantIntervalsGiveZeroRMSSD() {
        let analyzer = HRVAnalyzer()
        let intervals = Array(repeating: 800.0, count: 10)
        let rmssd = analyzer.computeRMSSD(rrIntervals: intervals)
        XCTAssertNotNil(rmssd)
        XCTAssertEqual(rmssd!, 0.0, accuracy: 0.001)
    }

    func testSlidingWindowReturnsRecentIntervals() {
        let analyzer = HRVAnalyzer(windowDuration: 5.0) // 5-second window
        let timestamps: [Double] = [0, 0.8, 1.6, 2.4, 3.2, 4.0, 4.8, 5.6, 6.4]
        let intervals: [Double] = [800, 800, 800, 800, 800, 800, 800, 800, 800]
        for (t, rr) in zip(timestamps, intervals) {
            analyzer.addInterval(rr: rr, timestamp: t)
        }
        let windowed = analyzer.recentIntervals(at: 6.4)
        XCTAssertTrue(windowed.count < intervals.count)
        XCTAssertTrue(windowed.count >= 5)
    }

    func testRMSSDFromSlidingWindow() {
        let analyzer = HRVAnalyzer(windowDuration: 30.0)
        var timestamp = 0.0
        let baseInterval = 800.0
        for i in 0..<50 {
            let rr = baseInterval + Double(i % 5) * 5.0
            analyzer.addInterval(rr: rr, timestamp: timestamp)
            timestamp += rr / 1000.0
        }
        let rmssd = analyzer.currentRMSSD(at: timestamp)
        XCTAssertNotNil(rmssd)
        XCTAssertGreaterThan(rmssd!, 0)
    }
}
