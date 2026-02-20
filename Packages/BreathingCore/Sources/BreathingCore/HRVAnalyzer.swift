import Foundation

public final class HRVAnalyzer: @unchecked Sendable {
    private let windowDuration: Double
    private var intervals: [(timestamp: Double, rr: Double)] = []
    private let lock = NSLock()

    public init(windowDuration: Double = 30.0) {
        self.windowDuration = windowDuration
    }

    public func addInterval(rr: Double, timestamp: Double) {
        lock.lock()
        defer { lock.unlock() }
        intervals.append((timestamp: timestamp, rr: rr))
    }

    public func recentIntervals(at now: Double) -> [Double] {
        lock.lock()
        defer { lock.unlock() }
        let cutoff = now - windowDuration
        return intervals.filter { $0.timestamp >= cutoff }.map(\.rr)
    }

    public func currentRMSSD(at now: Double) -> Double? {
        let recent = recentIntervals(at: now)
        return computeRMSSD(rrIntervals: recent)
    }

    public func computeRMSSD(rrIntervals: [Double]) -> Double? {
        guard rrIntervals.count >= 2 else { return nil }
        var sumSquaredDiffs = 0.0
        for i in 1..<rrIntervals.count {
            let diff = rrIntervals[i] - rrIntervals[i - 1]
            sumSquaredDiffs += diff * diff
        }
        let mean = sumSquaredDiffs / Double(rrIntervals.count - 1)
        return sqrt(mean)
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        intervals.removeAll()
    }
}
