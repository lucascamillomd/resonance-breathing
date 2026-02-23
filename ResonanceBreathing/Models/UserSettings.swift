import Foundation
import SwiftData

@Model
final class UserSettings {
    var defaultDuration: TimeInterval
    var defaultBreathingRate: Double
    var hapticsEnabled: Bool
    var hapticIntensity: Double
    var useECGPrior: Bool
    var calibratedResonanceRate: Double?
    var calibrationDate: Date?

    init(
        defaultDuration: TimeInterval = 600,
        defaultBreathingRate: Double = 5.5,
        hapticsEnabled: Bool = true,
        hapticIntensity: Double = 0.8,
        useECGPrior: Bool = false,
        calibratedResonanceRate: Double? = nil,
        calibrationDate: Date? = nil
    ) {
        self.defaultDuration = defaultDuration
        self.defaultBreathingRate = defaultBreathingRate
        self.hapticsEnabled = hapticsEnabled
        self.hapticIntensity = hapticIntensity
        self.useECGPrior = useECGPrior
        self.calibratedResonanceRate = calibratedResonanceRate
        self.calibrationDate = calibrationDate
    }
}
