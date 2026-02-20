import Foundation
import SwiftData

@Model
final class UserSettings {
    var defaultDuration: TimeInterval
    var defaultBreathingRate: Double
    var hapticsEnabled: Bool
    var hapticIntensity: Double

    init(
        defaultDuration: TimeInterval = 600,
        defaultBreathingRate: Double = 5.5,
        hapticsEnabled: Bool = true,
        hapticIntensity: Double = 0.8
    ) {
        self.defaultDuration = defaultDuration
        self.defaultBreathingRate = defaultBreathingRate
        self.hapticsEnabled = hapticsEnabled
        self.hapticIntensity = hapticIntensity
    }
}
