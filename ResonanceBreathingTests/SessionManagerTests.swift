import XCTest
import SwiftData
import BreathingCore
@testable import ResonanceBreathing

@MainActor
final class SessionManagerTests: XCTestCase {
    func testEndSessionPersistsAggregatesAndDataPoints() throws {
        let container = try ModelContainer(
            for: BreathingSession.self,
            SessionDataPoint.self,
            UserSettings.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let connector = WatchConnector(activateSession: false)
        let manager = SessionManager(
            watchConnector: connector,
            updateInterval: 0.25,
            autoScheduleUpdates: false,
            runBreathingTimer: false
        )

        manager.startSession(
            configuration: SessionConfiguration(targetDuration: 120, startingBPM: 5.5, hapticsEnabled: false)
        )

        let baseTimestamp = Date.now.timeIntervalSince1970

        for second in 1...45 {
            let heartRate = 68.0 + sin(Double(second) * 0.22) * 4.0
            let rr = HeartMath.pseudoRRIntervalMillis(fromHeartRate: heartRate).map { [$0] } ?? []
            connector.enqueueSample(
                WatchPhysioSample(
                    timestamp: baseTimestamp + Double(second),
                    heartRate: heartRate,
                    rrIntervals: rr,
                    sequence: second
                )
            )
            manager.processWatchData(deltaTime: 1.0)
        }

        let session = manager.endSession(modelContext: context)
        XCTAssertNotNil(session)

        guard let session else { return }
        XCTAssertGreaterThan(session.averageHR, 0)
        XCTAssertGreaterThan(session.averageRMSSD, 0)
        XCTAssertGreaterThanOrEqual(session.peakCoherence, 0)
        XCTAssertFalse(session.dataPoints.isEmpty)
        XCTAssertGreaterThan(session.duration, 0)
    }
}
