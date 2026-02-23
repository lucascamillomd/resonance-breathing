import Foundation

public enum HeartMath {
    public static let minRRMillis: Double = 300
    public static let maxRRMillis: Double = 2_000

    /// Approximates a single R-R interval (ms) from an instantaneous BPM sample.
    /// This is a heuristic fallback when true beat-to-beat intervals are unavailable.
    public static func pseudoRRIntervalMillis(fromHeartRate bpm: Double) -> Double? {
        guard bpm.isFinite, bpm > 0 else { return nil }
        let rr = 60_000.0 / bpm
        return min(max(rr, minRRMillis), maxRRMillis)
    }
}
