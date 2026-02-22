import Foundation

public final class UCBRateSelector: @unchecked Sendable {
    public struct RateStats: Sendable {
        public let rate: Double
        public let meanReward: Double
        public let visitCount: Int
    }

    private let rates: [Double]
    private var rewardSums: [Double]
    private var visitCounts: [Int]
    private var totalTrials: Int = 0
    private let lock = NSLock()

    public init(minRate: Double = 4.5, maxRate: Double = 7.0, step: Double = 0.25) {
        var r: [Double] = []
        var v = minRate
        while v <= maxRate + step * 0.1 {
            r.append(v)
            v += step
        }
        self.rates = r
        self.rewardSums = Array(repeating: 0, count: r.count)
        self.visitCounts = Array(repeating: 0, count: r.count)
    }

    public func selectRate(explorationConstant: Double = 1.0) -> Double {
        lock.lock()
        defer { lock.unlock() }

        let unvisited = rates.indices.filter { visitCounts[$0] == 0 }
        if let idx = unvisited.randomElement() {
            return rates[idx]
        }

        guard totalTrials > 0 else { return rates[rates.count / 2] }

        let logTotal = log(Double(totalTrials))
        var bestUCB = -Double.infinity
        var bestIdx = 0

        for i in rates.indices {
            let mean = rewardSums[i] / Double(visitCounts[i])
            let exploration = explorationConstant * sqrt(2.0 * logTotal / Double(visitCounts[i]))
            let ucb = mean + exploration
            if ucb > bestUCB {
                bestUCB = ucb
                bestIdx = i
            }
        }

        return rates[bestIdx]
    }

    public func recordReward(rate: Double, reward: Double) {
        lock.lock()
        defer { lock.unlock() }

        let idx = nearestIndex(for: rate)
        rewardSums[idx] += reward
        visitCounts[idx] += 1
        totalTrials += 1
    }

    public var bestRate: Double {
        lock.lock()
        defer { lock.unlock() }

        var best = rates[rates.count / 2]
        var bestMean = -Double.infinity
        for i in rates.indices where visitCounts[i] > 0 {
            let mean = rewardSums[i] / Double(visitCounts[i])
            if mean > bestMean {
                bestMean = mean
                best = rates[i]
            }
        }
        return best
    }

    public var allStats: [RateStats] {
        lock.lock()
        defer { lock.unlock() }
        return rates.indices.compactMap { i in
            guard visitCounts[i] > 0 else { return nil }
            return RateStats(
                rate: rates[i],
                meanReward: rewardSums[i] / Double(visitCounts[i]),
                visitCount: visitCounts[i]
            )
        }
    }

    private func nearestIndex(for rate: Double) -> Int {
        var bestIdx = 0
        var bestDist = abs(rates[0] - rate)
        for i in 1..<rates.count {
            let dist = abs(rates[i] - rate)
            if dist < bestDist {
                bestDist = dist
                bestIdx = i
            }
        }
        return bestIdx
    }
}
