import Foundation

public final class ResonanceParticleFilter: @unchecked Sendable {
    public struct State: Sendable {
        public let estimatedFrequencyBPM: Double
        public let uncertainty: Double
    }

    private var particles: [Double]
    private var weights: [Double]
    private let particleCount: Int
    private let processNoise: Double
    private let responseWidth: Double
    private let observationNoise: Double
    private let lock = NSLock()

    public init(
        particleCount: Int = 100,
        priorMean: Double = 5.5,
        priorStd: Double = 0.75,
        processNoise: Double = 0.03,
        responseWidth: Double = 0.5
    ) {
        self.particleCount = particleCount
        self.processNoise = processNoise
        self.responseWidth = responseWidth
        self.observationNoise = 2.0

        self.particles = (0..<particleCount).map { _ in
            Self.clamp(Self.gaussianSample(mean: priorMean, std: priorStd))
        }
        self.weights = Array(repeating: 1.0 / Double(particleCount), count: particleCount)
    }

    public var currentState: State {
        lock.lock()
        defer { lock.unlock() }
        return stateUnsafe
    }

    private var stateUnsafe: State {
        let est = zip(particles, weights).reduce(0.0) { $0 + $1.0 * $1.1 }
        let variance = zip(particles, weights).reduce(0.0) { $0 + $1.1 * pow($1.0 - est, 2) }
        return State(estimatedFrequencyBPM: est, uncertainty: sqrt(variance))
    }

    @discardableResult
    public func update(observedAmplitude: Double, currentRateBPM: Double) -> State {
        lock.lock()
        defer { lock.unlock() }

        for i in 0..<particleCount {
            particles[i] = Self.clamp(particles[i] + Self.gaussianSample(mean: 0, std: processNoise))
        }

        for i in 0..<particleCount {
            let expectedAmplitude = 10.0 * exp(-pow(currentRateBPM - particles[i], 2)
                                                / (2.0 * responseWidth * responseWidth))
            let likelihood = Self.gaussianPDF(
                x: observedAmplitude,
                mean: expectedAmplitude,
                std: observationNoise
            )
            weights[i] *= max(likelihood, 1e-30)
        }

        let weightSum = weights.reduce(0, +)
        guard weightSum > 0 else {
            weights = Array(repeating: 1.0 / Double(particleCount), count: particleCount)
            return stateUnsafe
        }
        for i in 0..<particleCount {
            weights[i] /= weightSum
        }

        let nEff = 1.0 / weights.reduce(0.0) { $0 + $1 * $1 }
        if nEff < Double(particleCount) / 2.0 {
            systematicResample()
        }

        return stateUnsafe
    }

    private func systematicResample() {
        let n = particleCount
        var cumWeights = [Double](repeating: 0, count: n)
        cumWeights[0] = weights[0]
        for i in 1..<n {
            cumWeights[i] = cumWeights[i - 1] + weights[i]
        }

        let start = Double.random(in: 0..<(1.0 / Double(n)))
        var newParticles = [Double](repeating: 0, count: n)
        var j = 0
        for i in 0..<n {
            let threshold = start + Double(i) / Double(n)
            while j < n - 1 && cumWeights[j] < threshold {
                j += 1
            }
            newParticles[i] = particles[j]
        }

        particles = newParticles
        weights = Array(repeating: 1.0 / Double(n), count: n)
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 4.0), 7.5)
    }

    private static func gaussianSample(mean: Double, std: Double) -> Double {
        let u1 = max(Double.random(in: 0...1), 1e-10)
        let u2 = Double.random(in: 0...1)
        return mean + std * sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
    }

    private static func gaussianPDF(x: Double, mean: Double, std: Double) -> Double {
        let diff = x - mean
        return exp(-diff * diff / (2.0 * std * std)) / (std * sqrt(2.0 * .pi))
    }
}
