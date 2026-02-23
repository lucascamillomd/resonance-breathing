import XCTest
@testable import ResonanceBreathing

@MainActor
final class WatchConnectorTests: XCTestCase {
    func testDrainSamplesReturnsQueuedSamplesOnlyOnce() {
        let connector = WatchConnector(activateSession: false)

        connector.enqueueSample(
            WatchPhysioSample(
                timestamp: 100,
                heartRate: 66,
                rrIntervals: [900],
                sequence: 1
            )
        )
        connector.enqueueSample(
            WatchPhysioSample(
                timestamp: 101,
                heartRate: 67,
                rrIntervals: [895],
                sequence: 2
            )
        )

        let drained = connector.drainSamples()
        XCTAssertEqual(drained.count, 2)
        XCTAssertEqual(drained.map(\.sequence), [1, 2])
        XCTAssertTrue(connector.drainSamples().isEmpty)
    }

    func testDuplicateSequencesAreDropped() {
        let connector = WatchConnector(activateSession: false)

        connector.enqueueSample(
            WatchPhysioSample(
                timestamp: 100,
                heartRate: 66,
                rrIntervals: [900],
                sequence: 1
            )
        )
        connector.enqueueSample(
            WatchPhysioSample(
                timestamp: 101,
                heartRate: 66,
                rrIntervals: [900],
                sequence: 1
            )
        )

        let drained = connector.drainSamples()
        XCTAssertEqual(drained.count, 1)
        XCTAssertEqual(drained.first?.sequence, 1)
    }

    func testResetSampleBufferAllowsSequenceRestart() {
        let connector = WatchConnector(activateSession: false)

        connector.enqueueSample(
            WatchPhysioSample(
                timestamp: 100,
                heartRate: 66,
                rrIntervals: [900],
                sequence: 1
            )
        )
        _ = connector.drainSamples()
        connector.resetSampleBuffer()
        connector.enqueueSample(
            WatchPhysioSample(
                timestamp: 200,
                heartRate: 70,
                rrIntervals: [850],
                sequence: 1
            )
        )

        let drained = connector.drainSamples()
        XCTAssertEqual(drained.count, 1)
        XCTAssertEqual(drained.first?.heartRate, 70)
    }
}
