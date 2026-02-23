import Foundation

public final class AdaptivePacer: @unchecked Sendable {
    public enum SessionPhase: String, Sendable, Equatable {
        case calibration
        case exploration
        case resonanceLock
    }

    private let calibrationDuration: Double
    private let explorationDuration: Double
    private let stepSize: Double = 0.1

    public private(set) var sessionPhase: SessionPhase = .calibration
    public private(set) var currentParameters: BreathingParameters

    // Tracking state - available for use in your implementation
    private var coherenceHistory: [(time: Double, coherence: Double, bpm: Double)] = []
    private var bestCoherence: Double = 0.0
    private var bestBPM: Double = BreathingParameters.defaultBPM
    private var explorationDirection: Double = 1.0
    private var lastAdjustmentTime: Double = 0.0

    public init(
        calibrationDuration: Double = 120.0,
        explorationDuration: Double = 180.0,
        startingBPM: Double = BreathingParameters.defaultBPM
    ) {
        self.calibrationDuration = calibrationDuration
        self.explorationDuration = explorationDuration
        self.currentParameters = BreathingParameters(breathsPerMinute: startingBPM)
    }

    public func update(coherence: Double, elapsedTime: Double) {
        // Record history
        coherenceHistory.append((time: elapsedTime, coherence: coherence, bpm: currentParameters.breathsPerMinute))

        // Track best coherence seen
        if coherence > bestCoherence {
            bestCoherence = coherence
            bestBPM = currentParameters.breathsPerMinute
        }

        // Determine phase based on elapsed time
        if elapsedTime <= calibrationDuration {
            sessionPhase = .calibration
            // During calibration: just collect baseline data, don't change rate
            return
        }

        if elapsedTime <= calibrationDuration + explorationDuration {
            sessionPhase = .exploration

            // Exploration: adjust rate every ~3 seconds, reverse on coherence drop or boundary
            if elapsedTime - lastAdjustmentTime >= 3.0 {
                let prevCoherence = coherenceHistory.dropLast().last?.coherence ?? coherence
                if coherence < prevCoherence {
                    explorationDirection *= -1
                }

                let newBPM = currentParameters.breathsPerMinute + stepSize * explorationDirection
                if newBPM < BreathingParameters.minBPM || newBPM > BreathingParameters.maxBPM {
                    explorationDirection *= -1
                }

                currentParameters = currentParameters.adjustedBy(stepSize * explorationDirection)
                lastAdjustmentTime = elapsedTime
            }
            return
        }

        // Past calibration + exploration → Resonance Lock phase
        sessionPhase = .resonanceLock

        // Resonance lock: jump to best rate, then micro-adjust if coherence declines
        if abs(currentParameters.breathsPerMinute - bestBPM) > stepSize {
            currentParameters = BreathingParameters(breathsPerMinute: bestBPM)
        }

        if elapsedTime - lastAdjustmentTime >= 3.0 {
            let recentCoherences = coherenceHistory.suffix(3).map(\.coherence)
            let trend = (recentCoherences.last ?? coherence) - (recentCoherences.first ?? coherence)
            if trend < -0.05 {
                currentParameters = currentParameters.adjustedBy(stepSize * explorationDirection)
                explorationDirection *= -1
                lastAdjustmentTime = elapsedTime
            }
        }
    }
}
