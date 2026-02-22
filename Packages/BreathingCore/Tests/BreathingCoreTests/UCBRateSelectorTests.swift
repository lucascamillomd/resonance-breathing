import XCTest
@testable import BreathingCore

final class UCBRateSelectorTests: XCTestCase {

    func testInitialSelectionIsValid() {
        let selector = UCBRateSelector()
        let rate = selector.selectRate()
        XCTAssertGreaterThanOrEqual(rate, 4.5)
        XCTAssertLessThanOrEqual(rate, 7.0)
    }

    func testExploresUnvisitedRatesFirst() {
        let selector = UCBRateSelector(step: 0.5)
        selector.recordReward(rate: 5.5, reward: 8.0)

        let next = selector.selectRate()
        XCTAssertNotEqual(next, 5.5, "Should explore an unvisited rate first")
    }

    func testConvergesToHighRewardRate() {
        let selector = UCBRateSelector(step: 0.5)
        let bestRate = 5.5

        for _ in 0..<50 {
            for rate in stride(from: 4.5, through: 7.0, by: 0.5) {
                let reward = rate == bestRate ? 10.0 : 3.0 + Double.random(in: -1...1)
                selector.recordReward(rate: rate, reward: reward)
            }
        }

        let selected = selector.selectRate(explorationConstant: 0.1)
        XCTAssertEqual(selected, bestRate, accuracy: 0.5,
                       "Should converge to the rate with highest mean reward")
    }

    func testBestRateReturnsHighestMean() {
        let selector = UCBRateSelector(step: 0.5)
        selector.recordReward(rate: 5.0, reward: 3.0)
        selector.recordReward(rate: 5.5, reward: 9.0)
        selector.recordReward(rate: 6.0, reward: 5.0)

        XCTAssertEqual(selector.bestRate, 5.5, accuracy: 0.01)
    }

    func testRecordRewardSnapsToNearestDiscreteBin() {
        let selector = UCBRateSelector(step: 0.5)
        selector.recordReward(rate: 5.3, reward: 7.0)
        selector.recordReward(rate: 5.7, reward: 7.0)

        XCTAssertEqual(selector.bestRate, 5.5, accuracy: 0.01)
    }
}
