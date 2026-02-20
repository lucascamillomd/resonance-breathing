import Foundation

public struct BreathingParameters: Sendable, Equatable {
    public static let minBPM: Double = 4.5
    public static let maxBPM: Double = 7.0
    public static let defaultBPM: Double = 5.5
    public static let inhaleRatio: Double = 0.4
    public static let holdRatio: Double = 0.05

    public let breathsPerMinute: Double
    public let inhaleDuration: Double
    public let holdDuration: Double
    public let exhaleDuration: Double

    public init(breathsPerMinute: Double) {
        let clamped = min(max(breathsPerMinute, Self.minBPM), Self.maxBPM)
        self.breathsPerMinute = clamped

        let cycleDuration = 60.0 / clamped
        self.holdDuration = cycleDuration * Self.holdRatio
        let breathingTime = cycleDuration - holdDuration
        self.inhaleDuration = breathingTime * Self.inhaleRatio
        self.exhaleDuration = breathingTime * (1.0 - Self.inhaleRatio)
    }

    public func adjustedBy(_ delta: Double) -> BreathingParameters {
        BreathingParameters(breathsPerMinute: breathsPerMinute + delta)
    }
}
