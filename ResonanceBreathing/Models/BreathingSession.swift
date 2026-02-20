import Foundation
import SwiftData

@Model
final class BreathingSession {
    var id: UUID
    var date: Date
    var duration: TimeInterval
    var averageHR: Double
    var averageRMSSD: Double
    var peakCoherence: Double
    var resonanceRate: Double
    @Relationship(deleteRule: .cascade) var dataPoints: [SessionDataPoint]

    init(
        date: Date = .now,
        duration: TimeInterval = 0,
        averageHR: Double = 0,
        averageRMSSD: Double = 0,
        peakCoherence: Double = 0,
        resonanceRate: Double = 0,
        dataPoints: [SessionDataPoint] = []
    ) {
        self.id = UUID()
        self.date = date
        self.duration = duration
        self.averageHR = averageHR
        self.averageRMSSD = averageRMSSD
        self.peakCoherence = peakCoherence
        self.resonanceRate = resonanceRate
        self.dataPoints = dataPoints
    }
}
