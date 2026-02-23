import Foundation
import BreathingCore

struct SessionConfiguration: Equatable, Sendable {
    var targetDuration: TimeInterval
    var startingBPM: Double
    var hapticsEnabled: Bool
    var useECGPrior: Bool
    var ecgPriorMean: Double?
    var ecgPriorStd: Double?

    static let `default` = SessionConfiguration(
        targetDuration: 600,
        startingBPM: BreathingParameters.defaultBPM,
        hapticsEnabled: true
    )

    init(targetDuration: TimeInterval, startingBPM: Double, hapticsEnabled: Bool, useECGPrior: Bool = false, ecgPriorMean: Double? = nil, ecgPriorStd: Double? = nil) {
        self.targetDuration = max(60, targetDuration)
        self.startingBPM = min(max(startingBPM, BreathingParameters.minBPM), BreathingParameters.maxBPM)
        self.hapticsEnabled = hapticsEnabled
        self.useECGPrior = useECGPrior
        self.ecgPriorMean = ecgPriorMean
        self.ecgPriorStd = ecgPriorStd
    }

    init(settings: UserSettings?) {
        guard let settings else {
            self = .default
            return
        }
        if let calibratedRate = settings.calibratedResonanceRate {
            self.init(
                targetDuration: settings.defaultDuration,
                startingBPM: settings.defaultBreathingRate,
                hapticsEnabled: settings.hapticsEnabled,
                useECGPrior: false,
                ecgPriorMean: calibratedRate,
                ecgPriorStd: 0.2
            )
        } else {
            self.init(
                targetDuration: settings.defaultDuration,
                startingBPM: settings.defaultBreathingRate,
                hapticsEnabled: settings.hapticsEnabled,
                useECGPrior: settings.useECGPrior
            )
        }
    }
}
