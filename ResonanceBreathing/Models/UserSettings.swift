import Foundation
import SwiftData

@Model
final class UserSettings {
    var defaultDuration: TimeInterval
    var defaultBreathingRate: Double
    var hapticsEnabled: Bool
    var hapticIntensity: Double
    var useECGPrior: Bool

    init(
        defaultDuration: TimeInterval = 600,
        defaultBreathingRate: Double = 5.5,
        hapticsEnabled: Bool = true,
        hapticIntensity: Double = 0.8,
        useECGPrior: Bool = false
    ) {
        self.defaultDuration = defaultDuration
        self.defaultBreathingRate = defaultBreathingRate
        self.hapticsEnabled = hapticsEnabled
        self.hapticIntensity = hapticIntensity
        self.useECGPrior = useECGPrior
    }
}
