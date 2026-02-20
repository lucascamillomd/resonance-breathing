import Foundation

public final class CoherenceCalculator: Sendable {
    private static let minSamples = 32

    public init() {}

    /// Compute coherence score (0.0–1.0) measuring how much HR oscillation
    /// is concentrated at the breathing frequency.
    public func computeCoherence(
        hrSamples: [Double],
        sampleRateHz: Double,
        breathingFreqHz: Double
    ) -> Double {
        guard hrSamples.count >= Self.minSamples else { return 0.0 }

        let n = hrSamples.count
        let mean = hrSamples.reduce(0, +) / Double(n)
        let centered = hrSamples.map { $0 - mean }

        let freqResolution = sampleRateHz / Double(n)
        let minBin = max(1, Int(0.04 / freqResolution))
        let maxBin = min(n / 2, Int(0.15 / freqResolution))

        guard maxBin > minBin else { return 0.0 }

        let targetBin = Int(round(breathingFreqHz / freqResolution))
        let targetRange = max(minBin, targetBin - 1)...min(maxBin, targetBin + 1)

        var targetPower = 0.0
        var totalPower = 0.0

        for k in minBin...maxBin {
            let power = dftPowerAtBin(k: k, signal: centered)
            totalPower += power
            if targetRange.contains(k) {
                targetPower += power
            }
        }

        guard totalPower > 0 else { return 0.0 }
        return min(max(targetPower / totalPower, 0.0), 1.0)
    }

    private func dftPowerAtBin(k: Int, signal: [Double]) -> Double {
        let n = signal.count
        var real = 0.0
        var imag = 0.0
        let angle = 2.0 * .pi * Double(k) / Double(n)
        for i in 0..<n {
            real += signal[i] * cos(angle * Double(i))
            imag -= signal[i] * sin(angle * Double(i))
        }
        return (real * real + imag * imag) / Double(n * n)
    }
}
