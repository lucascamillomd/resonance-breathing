import Foundation

public enum RSAAmplitude {
    public static func compute(hrSamples: [Double]) -> Double {
        guard hrSamples.count >= 8 else { return 0 }

        var smoothed = hrSamples
        if hrSamples.count >= 3 {
            smoothed = [hrSamples[0]]
            for i in 1..<(hrSamples.count - 1) {
                smoothed.append((hrSamples[i - 1] + hrSamples[i] + hrSamples[i + 1]) / 3.0)
            }
            smoothed.append(hrSamples[hrSamples.count - 1])
        }

        var peaks: [Double] = []
        var troughs: [Double] = []

        for i in 1..<(smoothed.count - 1) {
            if smoothed[i] > smoothed[i - 1] && smoothed[i] >= smoothed[i + 1] {
                peaks.append(smoothed[i])
            }
            if smoothed[i] < smoothed[i - 1] && smoothed[i] <= smoothed[i + 1] {
                troughs.append(smoothed[i])
            }
        }

        guard !peaks.isEmpty && !troughs.isEmpty else { return 0 }

        let avgPeak = peaks.reduce(0, +) / Double(peaks.count)
        let avgTrough = troughs.reduce(0, +) / Double(troughs.count)
        return max(avgPeak - avgTrough, 0)
    }
}
