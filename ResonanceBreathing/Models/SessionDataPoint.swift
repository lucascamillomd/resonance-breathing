import Foundation
import SwiftData

@Model
final class SessionDataPoint {
    var timestamp: Date
    var hr: Double
    var rmssd: Double
    var coherence: Double
    var breathingRate: Double

    init(timestamp: Date = .now, hr: Double, rmssd: Double, coherence: Double, breathingRate: Double) {
        self.timestamp = timestamp
        self.hr = hr
        self.rmssd = rmssd
        self.coherence = coherence
        self.breathingRate = breathingRate
    }
}
