# Bayesian Resonance Pacer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the simple AdaptivePacer with a Bayesian frequency estimator (particle filter + UCB rate selection) that finds each user's personal resonant breathing frequency faster and more precisely, with optional ECG-derived priors for stronger initial calibration.

**Architecture:** A particle filter (100 particles) maintains a probability distribution over possible resonant frequencies (4.5–7.0 bpm). An Upper Confidence Bound (UCB) bandit selects which breathing rate to try next, balancing exploration vs exploitation. RSA amplitude (peak-to-trough HR oscillation) is the primary optimization signal — the resonance curve is unimodal, peaking at each person's unique resonant frequency. An optional ECG prior narrows the initial distribution using HealthKit heartbeat series data analyzed via Lomb-Scargle periodogram.

**Tech Stack:** Swift 5.9, BreathingCore package (pure algorithms), HealthKit (ECG reading), SwiftData (settings persistence), watchOS 10+ / iOS 17+

**Reference:** `~/Downloads/compass_artifact_wf-c291f2f8-64f2-4749-af03-21bd7910a75b_text_markdown.md` — Section 6 Algorithm 3 (Bayesian optimization with particle filtering)

---

## Task 1: Lomb-Scargle Periodogram

The Lomb-Scargle periodogram computes power spectra from unevenly-spaced data (R-R intervals), avoiding the interpolation bias of standard FFT. This is the foundation for both the ECG prior and the spectral verification layer.

**Files:**
- Create: `Packages/BreathingCore/Sources/BreathingCore/LombScargle.swift`
- Test: `Packages/BreathingCore/Tests/BreathingCoreTests/LombScargleTests.swift`

**Step 1: Write the failing tests**

```swift
// LombScargleTests.swift
import XCTest
@testable import BreathingCore

final class LombScargleTests: XCTestCase {

    func testPureSineWavePeaksAtCorrectFrequency() {
        // Generate evenly-spaced samples of a 0.1 Hz sine wave (6 bpm breathing)
        let freq = 0.1 // Hz
        let duration = 60.0
        let dt = 1.0
        var timestamps: [Double] = []
        var values: [Double] = []
        var t = 0.0
        while t <= duration {
            timestamps.append(t)
            values.append(sin(2.0 * .pi * freq * t))
            t += dt
        }

        let result = LombScargle.periodogram(
            timestamps: timestamps,
            values: values,
            minFreq: 0.04,
            maxFreq: 0.15,
            freqStep: 0.005
        )

        XCTAssertEqual(result.peakFrequency, freq, accuracy: 0.01,
                       "Peak should be at 0.1 Hz")
        XCTAssertGreaterThan(result.peakPower, 0)
    }

    func testUnevenlySpacedDataStillFindsFrequency() {
        // Simulate R-R intervals with jitter
        let freq = 0.092 // ~5.5 bpm
        var timestamps: [Double] = []
        var values: [Double] = []
        var t = 0.0
        for _ in 0..<80 {
            timestamps.append(t)
            values.append(5.0 * sin(2.0 * .pi * freq * t) + Double.random(in: -0.5...0.5))
            t += 0.8 + Double.random(in: -0.1...0.1) // ~0.8s intervals with jitter
        }

        let result = LombScargle.periodogram(
            timestamps: timestamps,
            values: values,
            minFreq: 0.04,
            maxFreq: 0.15,
            freqStep: 0.002
        )

        XCTAssertEqual(result.peakFrequency, freq, accuracy: 0.015)
    }

    func testEmptyInputReturnsZeroPower() {
        let result = LombScargle.periodogram(
            timestamps: [],
            values: [],
            minFreq: 0.04,
            maxFreq: 0.15,
            freqStep: 0.01
        )
        XCTAssertEqual(result.peakPower, 0)
    }

    func testTooFewSamplesReturnsZeroPower() {
        let result = LombScargle.periodogram(
            timestamps: [0.0],
            values: [1.0],
            minFreq: 0.04,
            maxFreq: 0.15,
            freqStep: 0.01
        )
        XCTAssertEqual(result.peakPower, 0)
    }

    func testFrequencyArrayMatchesRequestedRange() {
        let timestamps = Array(stride(from: 0.0, through: 30.0, by: 1.0))
        let values = timestamps.map { sin(2.0 * .pi * 0.1 * $0) }

        let result = LombScargle.periodogram(
            timestamps: timestamps,
            values: values,
            minFreq: 0.05,
            maxFreq: 0.12,
            freqStep: 0.01
        )

        XCTAssertGreaterThanOrEqual(result.frequencies.first ?? 0, 0.05)
        XCTAssertLessThanOrEqual(result.frequencies.last ?? 1, 0.12)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Packages/BreathingCore && swift test --filter LombScargleTests 2>&1 | tail -5`
Expected: Compilation error — `LombScargle` not found

**Step 3: Write the implementation**

```swift
// LombScargle.swift
import Foundation

public enum LombScargle {
    public struct Result: Sendable {
        public let frequencies: [Double]
        public let power: [Double]
        public let peakFrequency: Double
        public let peakPower: Double
    }

    /// Compute the Lomb-Scargle periodogram for unevenly-spaced time series data.
    /// Used for spectral analysis of R-R intervals without interpolation.
    ///
    /// - Parameters:
    ///   - timestamps: Time points in seconds (need not be evenly spaced)
    ///   - values: Signal values at each timestamp
    ///   - minFreq: Lower frequency bound in Hz (default 0.04 = LF band start)
    ///   - maxFreq: Upper frequency bound in Hz (default 0.15 = LF band end)
    ///   - freqStep: Frequency resolution in Hz
    /// - Returns: Periodogram result with frequencies, power, and peak location
    public static func periodogram(
        timestamps: [Double],
        values: [Double],
        minFreq: Double = 0.04,
        maxFreq: Double = 0.15,
        freqStep: Double = 0.005
    ) -> Result {
        let n = timestamps.count
        guard n >= 2, timestamps.count == values.count else {
            return Result(frequencies: [], power: [], peakFrequency: 0, peakPower: 0)
        }

        let mean = values.reduce(0, +) / Double(n)
        let centered = values.map { $0 - mean }

        var frequencies: [Double] = []
        var power: [Double] = []

        var freq = minFreq
        while freq <= maxFreq + freqStep * 0.5 {
            let omega = 2.0 * .pi * freq

            // Compute tau (time offset for orthogonalization)
            var sin2Sum = 0.0
            var cos2Sum = 0.0
            for t in timestamps {
                sin2Sum += sin(2.0 * omega * t)
                cos2Sum += cos(2.0 * omega * t)
            }
            let tau = atan2(sin2Sum, cos2Sum) / (2.0 * omega)

            // Compute power at this frequency
            var cosTermNum = 0.0
            var cosTermDen = 0.0
            var sinTermNum = 0.0
            var sinTermDen = 0.0

            for i in 0..<n {
                let phase = omega * (timestamps[i] - tau)
                let cosVal = cos(phase)
                let sinVal = sin(phase)
                cosTermNum += centered[i] * cosVal
                cosTermDen += cosVal * cosVal
                sinTermNum += centered[i] * sinVal
                sinTermDen += sinVal * sinVal
            }

            var p = 0.0
            if cosTermDen > 1e-12 { p += cosTermNum * cosTermNum / cosTermDen }
            if sinTermDen > 1e-12 { p += sinTermNum * sinTermNum / sinTermDen }
            p *= 0.5

            frequencies.append(freq)
            power.append(p)

            freq += freqStep
        }

        let maxIdx = power.indices.max(by: { power[$0] < power[$1] }) ?? 0
        let peakFreq = frequencies.isEmpty ? 0.0 : frequencies[maxIdx]
        let peakPow = power.isEmpty ? 0.0 : power[maxIdx]

        return Result(
            frequencies: frequencies,
            power: power,
            peakFrequency: peakFreq,
            peakPower: peakPow
        )
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd Packages/BreathingCore && swift test --filter LombScargleTests 2>&1 | tail -5`
Expected: All 5 tests PASS

**Step 5: Commit**

```bash
git add Packages/BreathingCore/Sources/BreathingCore/LombScargle.swift \
       Packages/BreathingCore/Tests/BreathingCoreTests/LombScargleTests.swift
git commit -m "feat(core): add Lomb-Scargle periodogram for unevenly-spaced spectral analysis"
```

---

## Task 2: RSA Amplitude Calculator

RSA amplitude (peak-to-trough heart rate oscillation) is the primary optimization signal for the Bayesian pacer. This is distinct from RMSSD — it measures the magnitude of breathing-synchronized HR oscillation directly.

**Files:**
- Create: `Packages/BreathingCore/Sources/BreathingCore/RSAAmplitude.swift`
- Test: `Packages/BreathingCore/Tests/BreathingCoreTests/RSAAmplitudeTests.swift`

**Step 1: Write the failing tests**

```swift
// RSAAmplitudeTests.swift
import XCTest
@testable import BreathingCore

final class RSAAmplitudeTests: XCTestCase {

    func testPureSineWaveReturnsDoubleAmplitude() {
        // A sine wave with amplitude 5 should have peak-to-trough of ~10
        let samples = (0..<60).map { i -> Double in
            68.0 + 5.0 * sin(2.0 * .pi * 0.1 * Double(i))
        }
        let amplitude = RSAAmplitude.compute(hrSamples: samples)
        XCTAssertEqual(amplitude, 10.0, accuracy: 1.0)
    }

    func testFlatSignalReturnsZero() {
        let samples = Array(repeating: 70.0, count: 30)
        let amplitude = RSAAmplitude.compute(hrSamples: samples)
        XCTAssertEqual(amplitude, 0.0, accuracy: 0.1)
    }

    func testTooFewSamplesReturnsZero() {
        let amplitude = RSAAmplitude.compute(hrSamples: [70, 72, 68])
        XCTAssertEqual(amplitude, 0.0)
    }

    func testNoisySignalStillDetectsOscillation() {
        let samples = (0..<60).map { i -> Double in
            68.0 + 5.0 * sin(2.0 * .pi * 0.1 * Double(i)) + Double.random(in: -1...1)
        }
        let amplitude = RSAAmplitude.compute(hrSamples: samples)
        XCTAssertGreaterThan(amplitude, 5.0, "Should detect oscillation despite noise")
        XCTAssertLessThan(amplitude, 15.0, "Noise shouldn't inflate amplitude wildly")
    }

    func testHigherAmplitudeSignalGivesHigherResult() {
        let smallOscillation = (0..<60).map { 68.0 + 2.0 * sin(2.0 * .pi * 0.1 * Double($0)) }
        let largeOscillation = (0..<60).map { 68.0 + 8.0 * sin(2.0 * .pi * 0.1 * Double($0)) }

        let small = RSAAmplitude.compute(hrSamples: smallOscillation)
        let large = RSAAmplitude.compute(hrSamples: largeOscillation)
        XCTAssertGreaterThan(large, small)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Packages/BreathingCore && swift test --filter RSAAmplitudeTests 2>&1 | tail -5`
Expected: Compilation error — `RSAAmplitude` not found

**Step 3: Write the implementation**

```swift
// RSAAmplitude.swift
import Foundation

public enum RSAAmplitude {
    /// Compute RSA amplitude as the average peak-to-trough HR difference.
    /// This measures the magnitude of breathing-synchronized heart rate oscillation.
    ///
    /// - Parameter hrSamples: Heart rate values (at ~1 Hz)
    /// - Returns: Average peak-to-trough amplitude in BPM, or 0 if insufficient data
    public static func compute(hrSamples: [Double]) -> Double {
        guard hrSamples.count >= 8 else { return 0 }

        // 3-point moving average to smooth noise before peak detection
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
```

**Step 4: Run tests to verify they pass**

Run: `cd Packages/BreathingCore && swift test --filter RSAAmplitudeTests 2>&1 | tail -5`
Expected: All 5 tests PASS

**Step 5: Commit**

```bash
git add Packages/BreathingCore/Sources/BreathingCore/RSAAmplitude.swift \
       Packages/BreathingCore/Tests/BreathingCoreTests/RSAAmplitudeTests.swift
git commit -m "feat(core): add RSA amplitude calculator for peak-to-trough HR oscillation"
```

---

## Task 3: Resonance Particle Filter

100 particles track the probability distribution over the user's resonant frequency. Updated each observation cycle (~30s) using a Gaussian resonance curve model. This is the core Bayesian estimator from Algorithm 3 in the reference document.

**Files:**
- Create: `Packages/BreathingCore/Sources/BreathingCore/ResonanceParticleFilter.swift`
- Test: `Packages/BreathingCore/Tests/BreathingCoreTests/ResonanceParticleFilterTests.swift`

**Step 1: Write the failing tests**

```swift
// ResonanceParticleFilterTests.swift
import XCTest
@testable import BreathingCore

final class ResonanceParticleFilterTests: XCTestCase {

    func testInitialEstimateNearPrior() {
        let pf = ResonanceParticleFilter(priorMean: 5.5, priorStd: 0.75)
        let state = pf.currentState
        XCTAssertEqual(state.estimatedFrequencyBPM, 5.5, accuracy: 0.5,
                       "Initial estimate should be near prior mean")
    }

    func testConvergesToTrueFrequencyWithRepeatedObservations() {
        let pf = ResonanceParticleFilter(priorMean: 5.5, priorStd: 0.75)
        let trueResonance = 6.0 // bpm

        // Simulate: breathing at 6.0 bpm produces high RSA, other rates produce less
        for _ in 0..<20 {
            let amplitude = resonanceCurve(rate: 6.0, trueRate: trueResonance)
            pf.update(observedAmplitude: amplitude, currentRateBPM: 6.0)
        }

        XCTAssertEqual(pf.currentState.estimatedFrequencyBPM, trueResonance, accuracy: 0.3,
                       "Should converge toward the rate that produces highest amplitude")
    }

    func testUncertaintyDecreasesWithObservations() {
        let pf = ResonanceParticleFilter(priorMean: 5.5, priorStd: 0.75)
        let initialUncertainty = pf.currentState.uncertainty

        for _ in 0..<10 {
            pf.update(observedAmplitude: 8.0, currentRateBPM: 5.5)
        }

        XCTAssertLessThan(pf.currentState.uncertainty, initialUncertainty,
                          "Uncertainty should decrease with observations")
    }

    func testEstimateStaysInValidRange() {
        let pf = ResonanceParticleFilter(priorMean: 5.5, priorStd: 0.75)
        for _ in 0..<50 {
            let rate = Double.random(in: 4.5...7.0)
            pf.update(observedAmplitude: Double.random(in: 0...15), currentRateBPM: rate)
            let est = pf.currentState.estimatedFrequencyBPM
            XCTAssertGreaterThanOrEqual(est, 4.0)
            XCTAssertLessThanOrEqual(est, 7.5)
        }
    }

    func testECGPriorNarrowsInitialDistribution() {
        let widePrior = ResonanceParticleFilter(priorMean: 5.5, priorStd: 0.75)
        let narrowPrior = ResonanceParticleFilter(priorMean: 5.8, priorStd: 0.2)

        XCTAssertLessThan(narrowPrior.currentState.uncertainty,
                          widePrior.currentState.uncertainty,
                          "ECG-derived narrow prior should have less initial uncertainty")
    }

    // Helper: Gaussian resonance curve
    private func resonanceCurve(rate: Double, trueRate: Double, peakAmplitude: Double = 10.0, width: Double = 0.5) -> Double {
        peakAmplitude * exp(-pow(rate - trueRate, 2) / (2 * width * width))
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Packages/BreathingCore && swift test --filter ResonanceParticleFilterTests 2>&1 | tail -5`
Expected: Compilation error — `ResonanceParticleFilter` not found

**Step 3: Write the implementation**

```swift
// ResonanceParticleFilter.swift
import Foundation

/// Particle filter that tracks the probability distribution over a user's
/// resonant breathing frequency. Uses a Gaussian resonance curve observation
/// model: amplitude is highest when breathing rate matches resonant frequency.
///
/// Reference: Algorithm 3 in the resonance breathing algorithms document.
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

    /// - Parameters:
    ///   - particleCount: Number of particles (default 100)
    ///   - priorMean: Prior mean resonant frequency in BPM (population: 5.5, or ECG-derived)
    ///   - priorStd: Prior standard deviation (population: 0.75, ECG-derived: ~0.2)
    ///   - processNoise: Random walk noise per update in BPM (default 0.03)
    ///   - responseWidth: Gaussian resonance curve width in BPM (default 0.5)
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

        // Initialize particles from Gaussian prior
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

    /// Update the particle filter with a new observation.
    ///
    /// - Parameters:
    ///   - observedAmplitude: RSA amplitude observed at the current breathing rate
    ///   - currentRateBPM: The breathing rate that was used when this amplitude was measured
    @discardableResult
    public func update(observedAmplitude: Double, currentRateBPM: Double) -> State {
        lock.lock()
        defer { lock.unlock() }

        // Predict: random walk
        for i in 0..<particleCount {
            particles[i] = Self.clamp(particles[i] + Self.gaussianSample(mean: 0, std: processNoise))
        }

        // Update weights: likelihood of observed amplitude given each particle's resonant freq
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

        // Normalize weights
        let weightSum = weights.reduce(0, +)
        guard weightSum > 0 else {
            weights = Array(repeating: 1.0 / Double(particleCount), count: particleCount)
            return stateUnsafe
        }
        for i in 0..<particleCount {
            weights[i] /= weightSum
        }

        // Resample if effective sample size is low
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
        // Box-Muller transform
        let u1 = max(Double.random(in: 0...1), 1e-10)
        let u2 = Double.random(in: 0...1)
        return mean + std * sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
    }

    private static func gaussianPDF(x: Double, mean: Double, std: Double) -> Double {
        let diff = x - mean
        return exp(-diff * diff / (2.0 * std * std)) / (std * sqrt(2.0 * .pi))
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd Packages/BreathingCore && swift test --filter ResonanceParticleFilterTests 2>&1 | tail -5`
Expected: All 5 tests PASS

**Step 5: Commit**

```bash
git add Packages/BreathingCore/Sources/BreathingCore/ResonanceParticleFilter.swift \
       Packages/BreathingCore/Tests/BreathingCoreTests/ResonanceParticleFilterTests.swift
git commit -m "feat(core): add particle filter for Bayesian resonant frequency tracking"
```

---

## Task 4: UCB Rate Selector

Upper Confidence Bound (UCB) bandit algorithm for selecting which breathing rate to try next. Balances exploration (trying unknown rates) with exploitation (staying at the currently best rate). Simpler and more robust than full Gaussian Process Bayesian optimization for our discrete rate space.

**Files:**
- Create: `Packages/BreathingCore/Sources/BreathingCore/UCBRateSelector.swift`
- Test: `Packages/BreathingCore/Tests/BreathingCoreTests/UCBRateSelectorTests.swift`

**Step 1: Write the failing tests**

```swift
// UCBRateSelectorTests.swift
import XCTest
@testable import BreathingCore

final class UCBRateSelectorTests: XCTestCase {

    func testInitialSelectionIsValid() {
        let selector = UCBRateSelector()
        let rate = selector.selectRate()
        XCTAssertGreaterThanOrEqual(rate, 4.5)
        XCTAssertLessThanOrEqual(rate, 7.0)
    }

    func testExploresUnvisitedRatesFirst() {
        let selector = UCBRateSelector(step: 0.5) // 4.5, 5.0, 5.5, 6.0, 6.5, 7.0
        // Record a reward at 5.5
        selector.recordReward(rate: 5.5, reward: 8.0)

        // Next selection should explore an unvisited rate (UCB = infinity for unvisited)
        let next = selector.selectRate()
        XCTAssertNotEqual(next, 5.5, "Should explore an unvisited rate first")
    }

    func testConvergesToHighRewardRate() {
        let selector = UCBRateSelector(step: 0.5)
        let bestRate = 5.5

        // Simulate many observations: 5.5 always gets high reward
        for _ in 0..<50 {
            for rate in stride(from: 4.5, through: 7.0, by: 0.5) {
                let reward = rate == bestRate ? 10.0 : 3.0 + Double.random(in: -1...1)
                selector.recordReward(rate: rate, reward: reward)
            }
        }

        // After many observations, exploitation should dominate
        let selected = selector.selectRate(explorationConstant: 0.1)
        XCTAssertEqual(selected, bestRate, accuracy: 0.5,
                       "Should converge to the rate with highest mean reward")
    }

    func testBestRateReturnsHighestMean() {
        let selector = UCBRateSelector(step: 0.5)
        selector.recordReward(rate: 5.0, reward: 3.0)
        selector.recordReward(rate: 5.5, reward: 9.0)
        selector.recordReward(rate: 6.0, reward: 5.0)

        XCTAssertEqual(selector.bestRate, 5.5, accuracy: 0.01)
    }

    func testRecordRewardSnapsToNearestDiscreteBin() {
        let selector = UCBRateSelector(step: 0.5)
        selector.recordReward(rate: 5.3, reward: 7.0) // snaps to 5.5
        selector.recordReward(rate: 5.7, reward: 7.0) // snaps to 5.5

        // 5.5 should have 2 observations
        XCTAssertEqual(selector.bestRate, 5.5, accuracy: 0.01)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Packages/BreathingCore && swift test --filter UCBRateSelectorTests 2>&1 | tail -5`
Expected: Compilation error — `UCBRateSelector` not found

**Step 3: Write the implementation**

```swift
// UCBRateSelector.swift
import Foundation

/// Upper Confidence Bound (UCB1) bandit for discrete breathing rate selection.
/// Balances exploration of unknown rates with exploitation of the best-known rate.
///
/// UCB(r) = mean_reward(r) + c * sqrt(2 * ln(total_trials) / visits(r))
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

    /// - Parameters:
    ///   - minRate: Minimum breathing rate in BPM (default 4.5)
    ///   - maxRate: Maximum breathing rate in BPM (default 7.0)
    ///   - step: Step size between discrete rate options (default 0.25)
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

    /// Select the next breathing rate to try using UCB1.
    /// Unvisited rates are selected first (UCB = infinity). Among visited rates,
    /// selects the one with the highest upper confidence bound.
    public func selectRate(explorationConstant: Double = 1.0) -> Double {
        lock.lock()
        defer { lock.unlock() }

        // Prioritize unvisited rates
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

    /// Record an observed RSA amplitude reward at a given breathing rate.
    /// The rate is snapped to the nearest discrete bin.
    public func recordReward(rate: Double, reward: Double) {
        lock.lock()
        defer { lock.unlock() }

        let idx = nearestIndex(for: rate)
        rewardSums[idx] += reward
        visitCounts[idx] += 1
        totalTrials += 1
    }

    /// The rate with the highest mean observed reward.
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

    /// Stats for all rates that have been visited.
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
```

**Step 4: Run tests to verify they pass**

Run: `cd Packages/BreathingCore && swift test --filter UCBRateSelectorTests 2>&1 | tail -5`
Expected: All 5 tests PASS

**Step 5: Commit**

```bash
git add Packages/BreathingCore/Sources/BreathingCore/UCBRateSelector.swift \
       Packages/BreathingCore/Tests/BreathingCoreTests/UCBRateSelectorTests.swift
git commit -m "feat(core): add UCB bandit for breathing rate selection"
```

---

## Task 5: BayesianPacer

The orchestrator that replaces `AdaptivePacer`. Combines the particle filter (frequency belief), UCB rate selector (exploration policy), and RSA amplitude (reward signal) into a single `update()` interface compatible with `SessionManager` and `WatchSessionManager`.

**Files:**
- Create: `Packages/BreathingCore/Sources/BreathingCore/BayesianPacer.swift`
- Test: `Packages/BreathingCore/Tests/BreathingCoreTests/BayesianPacerTests.swift`

**Step 1: Write the failing tests**

```swift
// BayesianPacerTests.swift
import XCTest
@testable import BreathingCore

final class BayesianPacerTests: XCTestCase {

    func testStartsInWarmupPhase() {
        let pacer = BayesianPacer()
        XCTAssertEqual(pacer.phase, .warmup)
    }

    func testOutputsValidBreathingParameters() {
        let pacer = BayesianPacer()
        let bpm = pacer.currentParameters.breathsPerMinute
        XCTAssertGreaterThanOrEqual(bpm, BreathingParameters.minBPM)
        XCTAssertLessThanOrEqual(bpm, BreathingParameters.maxBPM)
    }

    func testTransitionsToExploringAfterWarmup() {
        let pacer = BayesianPacer(warmupDuration: 5.0)
        let hrSamples = generateSinusoidalHR(seconds: 8, breathingFreqHz: 0.092)
        pacer.update(hrSamples: hrSamples, elapsedTime: 6.0)
        XCTAssertEqual(pacer.phase, .exploring)
    }

    func testTransitionsToConvergedWhenUncertaintyLow() {
        let pacer = BayesianPacer(warmupDuration: 2.0, convergenceThreshold: 0.5)
        // Feed many consistent observations at 5.5 bpm
        for t in stride(from: 3.0, through: 120.0, by: 5.0) {
            let hrSamples = generateSinusoidalHR(seconds: 30, breathingFreqHz: 0.092, amplitude: 8.0)
            pacer.update(hrSamples: hrSamples, elapsedTime: t)
        }
        XCTAssertEqual(pacer.phase, .converged)
    }

    func testRateStaysWithinBounds() {
        let pacer = BayesianPacer(warmupDuration: 1.0)
        for t in stride(from: 0.0, through: 60.0, by: 3.0) {
            let hrSamples = generateSinusoidalHR(seconds: 10, breathingFreqHz: 0.1)
            pacer.update(hrSamples: hrSamples, elapsedTime: t)
            let bpm = pacer.currentParameters.breathsPerMinute
            XCTAssertGreaterThanOrEqual(bpm, BreathingParameters.minBPM)
            XCTAssertLessThanOrEqual(bpm, BreathingParameters.maxBPM)
        }
    }

    func testECGPriorInfluencesInitialRate() {
        let defaultPacer = BayesianPacer()
        let ecgPacer = BayesianPacer(priorMean: 6.2, priorStd: 0.2)
        // ECG pacer should start closer to 6.2
        XCTAssertEqual(ecgPacer.currentParameters.breathsPerMinute, 6.2, accuracy: 0.3)
        XCTAssertEqual(defaultPacer.currentParameters.breathsPerMinute, 5.5, accuracy: 0.3)
    }

    func testEstimatedResonanceFrequencyAccessible() {
        let pacer = BayesianPacer()
        XCTAssertGreaterThan(pacer.estimatedResonanceFrequency, 4.0)
        XCTAssertLessThan(pacer.estimatedResonanceFrequency, 8.0)
    }

    // Helper: generate sinusoidal HR samples
    private func generateSinusoidalHR(seconds: Int, breathingFreqHz: Double, amplitude: Double = 5.0) -> [Double] {
        (0..<seconds).map { i in
            68.0 + amplitude * sin(2.0 * .pi * breathingFreqHz * Double(i))
        }
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Packages/BreathingCore && swift test --filter BayesianPacerTests 2>&1 | tail -5`
Expected: Compilation error — `BayesianPacer` not found

**Step 3: Write the implementation**

```swift
// BayesianPacer.swift
import Foundation

/// Bayesian adaptive pacer that finds a user's personal resonant breathing frequency
/// using a particle filter for frequency tracking and UCB bandit for rate selection.
///
/// Replaces the simple AdaptivePacer with a principled Bayesian approach:
/// 1. Particle filter maintains belief distribution over resonant frequency
/// 2. UCB bandit selects breathing rates to balance exploration/exploitation
/// 3. RSA amplitude (peak-to-trough HR oscillation) is the optimization signal
///
/// Optional ECG prior: pass a narrow priorStd (~0.2) with ECG-derived priorMean
/// to skip broad population exploration and converge faster.
public final class BayesianPacer: @unchecked Sendable {
    public enum Phase: String, Sendable, Equatable {
        case warmup      // Collecting initial data (no rate changes)
        case exploring   // UCB actively exploring rates
        case converged   // Locked to estimated resonant frequency
    }

    public private(set) var phase: Phase = .warmup
    public private(set) var currentParameters: BreathingParameters

    private let particleFilter: ResonanceParticleFilter
    private let rateSelector: UCBRateSelector
    private let warmupDuration: Double
    private let convergenceThreshold: Double
    private let observationInterval: Double
    private var lastObservationTime: Double = 0
    private var startingBPM: Double

    /// - Parameters:
    ///   - priorMean: Prior mean resonant frequency in BPM (default 5.5 population mean)
    ///   - priorStd: Prior standard deviation (default 0.75 population, ~0.2 for ECG prior)
    ///   - warmupDuration: Seconds before exploration begins (default 30)
    ///   - convergenceThreshold: Particle filter uncertainty below which to lock rate (default 0.15)
    ///   - observationInterval: Seconds between UCB observations (default 30)
    public init(
        priorMean: Double = BreathingParameters.defaultBPM,
        priorStd: Double = 0.75,
        warmupDuration: Double = 30.0,
        convergenceThreshold: Double = 0.15,
        observationInterval: Double = 30.0
    ) {
        self.warmupDuration = warmupDuration
        self.convergenceThreshold = convergenceThreshold
        self.observationInterval = observationInterval
        self.startingBPM = priorMean
        self.currentParameters = BreathingParameters(breathsPerMinute: priorMean)
        self.particleFilter = ResonanceParticleFilter(
            priorMean: priorMean,
            priorStd: priorStd
        )
        self.rateSelector = UCBRateSelector()
    }

    /// The particle filter's current best estimate of the user's resonant frequency.
    public var estimatedResonanceFrequency: Double {
        particleFilter.currentState.estimatedFrequencyBPM
    }

    /// Current uncertainty in the resonant frequency estimate.
    public var uncertainty: Double {
        particleFilter.currentState.uncertainty
    }

    /// Update the pacer with new heart rate data.
    ///
    /// - Parameters:
    ///   - hrSamples: Recent HR samples (last ~30s at ~1 Hz). Used to compute RSA amplitude.
    ///   - elapsedTime: Session elapsed time in seconds
    public func update(hrSamples: [Double], elapsedTime: Double) {
        // Warmup: just collect data
        if elapsedTime < warmupDuration {
            phase = .warmup
            return
        }

        // Check if it's time for a new observation
        guard elapsedTime - lastObservationTime >= observationInterval else { return }
        lastObservationTime = elapsedTime

        // Compute RSA amplitude from recent HR data
        let amplitude = RSAAmplitude.compute(hrSamples: hrSamples)
        let currentRateBPM = currentParameters.breathsPerMinute

        // Update particle filter with observation
        let state = particleFilter.update(
            observedAmplitude: amplitude,
            currentRateBPM: currentRateBPM
        )

        // Record reward for UCB
        rateSelector.recordReward(rate: currentRateBPM, reward: amplitude)

        // Check convergence
        if state.uncertainty < convergenceThreshold && phase != .warmup {
            phase = .converged
            currentParameters = BreathingParameters(breathsPerMinute: state.estimatedFrequencyBPM)
            return
        }

        // Exploration: use UCB to pick next rate
        phase = .exploring
        let nextRate = rateSelector.selectRate()
        currentParameters = BreathingParameters(breathsPerMinute: nextRate)
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd Packages/BreathingCore && swift test --filter BayesianPacerTests 2>&1 | tail -5`
Expected: All 6 tests PASS

**Step 5: Commit**

```bash
git add Packages/BreathingCore/Sources/BreathingCore/BayesianPacer.swift \
       Packages/BreathingCore/Tests/BreathingCoreTests/BayesianPacerTests.swift
git commit -m "feat(core): add BayesianPacer orchestrating particle filter + UCB rate selection"
```

---

## Task 6: ECG Prior Service

Reads the user's most recent ECG recording from HealthKit, extracts beat-to-beat intervals, runs Lomb-Scargle to find the dominant LF frequency, and returns it as a prior for the BayesianPacer. This lives in the app layer (not BreathingCore) because it depends on HealthKit.

**Files:**
- Create: `ResonanceBreathing/Services/ECGPriorService.swift`
- Modify: `ResonanceBreathing/ResonanceBreathing.entitlements` (add ECG read permission)
- Modify: `ResonanceBreathingWatch Watch App/ResonanceBreathingWatch.entitlements` (add ECG read permission)
- Modify: `ResonanceBreathing/Info.plist` (add NSHealthShareUsageDescription if not present)

**Step 1: Write the implementation**

NOTE: This service depends on HealthKit which cannot be unit tested in the BreathingCore package. We test via integration in the app.

```swift
// ECGPriorService.swift
import Foundation
import HealthKit
import BreathingCore

/// Reads the user's most recent ECG heartbeat series from HealthKit and computes
/// a Lomb-Scargle spectral peak as a prior for the Bayesian resonance estimator.
@MainActor
final class ECGPriorService {
    struct Prior: Sendable {
        let meanBPM: Double     // Estimated resonant frequency from ECG
        let stdBPM: Double      // Confidence (narrow = 0.2, broad = 0.75)
        let dataAge: TimeInterval // How old the ECG recording is
    }

    private let healthStore = HKHealthStore()

    /// Request HealthKit authorization for ECG and heartbeat data.
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        var readTypes: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        ]

        if #available(iOS 14.0, watchOS 7.0, *) {
            readTypes.insert(HKObjectType.electrocardiogramType())
        }

        if let heartbeatType = HKSeriesType.heartbeat() as? HKObjectType {
            readTypes.insert(heartbeatType)
        }

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    /// Fetch the most recent heartbeat series and compute a resonant frequency prior.
    /// Returns nil if no suitable data is available.
    func computePrior() async -> Prior? {
        guard let intervals = await fetchRecentHeartbeatIntervals() else { return nil }
        guard intervals.count >= 10 else { return nil }

        // Build timestamps from cumulative RR intervals (in seconds)
        var timestamps: [Double] = [0]
        for rr in intervals {
            timestamps.append(timestamps.last! + rr / 1000.0) // RR in ms → seconds
        }

        // Use RR intervals as the signal, timestamps as time axis
        let result = LombScargle.periodogram(
            timestamps: Array(timestamps.dropLast()),
            values: intervals.map { 60000.0 / $0 }, // Convert RR to instantaneous HR
            minFreq: 0.04,
            maxFreq: 0.15,
            freqStep: 0.002
        )

        guard result.peakPower > 0 else { return nil }

        let resonantBPM = result.peakFrequency * 60.0 // Hz → BPM
        guard resonantBPM >= 4.0 && resonantBPM <= 7.5 else { return nil }

        // ECG gives ~30s of data → moderate confidence
        return Prior(
            meanBPM: resonantBPM,
            stdBPM: 0.3,
            dataAge: 0 // Will be set by caller
        )
    }

    private func fetchRecentHeartbeatIntervals() async -> [Double]? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }

        let heartbeatType = HKSeriesType.heartbeat()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: heartbeatType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, _, _ in }

        return await withCheckedContinuation { continuation in
            let sampleQuery = HKSampleQuery(
                sampleType: heartbeatType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, samples, error in
                guard let self,
                      let sample = samples?.first as? HKHeartbeatSeriesSample else {
                    continuation.resume(returning: nil)
                    return
                }

                var intervals: [Double] = []
                var previousTime: TimeInterval?

                let seriesQuery = HKHeartbeatSeriesQuery(heartbeatSeries: sample) { _, timeSinceStart, precededByGap, done, error in
                    if let prev = previousTime, !precededByGap {
                        let rrMs = (timeSinceStart - prev) * 1000.0
                        if rrMs > 300 && rrMs < 2000 { // Valid RR range
                            intervals.append(rrMs)
                        }
                    }
                    previousTime = timeSinceStart

                    if done {
                        continuation.resume(returning: intervals.isEmpty ? nil : intervals)
                    }
                }
                self.healthStore.execute(seriesQuery)
            }
            healthStore.execute(sampleQuery)
        }
    }
}
```

**Step 2: Verify build**

Run: `xcodebuild build -project ResonanceBreathing.xcodeproj -scheme ResonanceBreathing -destination 'generic/platform=iOS Simulator' -quiet 2>&1 | tail -3`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ResonanceBreathing/Services/ECGPriorService.swift
git commit -m "feat: add ECG prior service reading heartbeat series from HealthKit"
```

---

## Task 7: Add `useECGPrior` to UserSettings and SessionConfiguration

Add a toggle to `UserSettings` (SwiftData model) and wire it through `SessionConfiguration` so both iPhone and Watch session managers know whether to use the ECG prior.

**Files:**
- Modify: `ResonanceBreathing/Models/UserSettings.swift` — add `useECGPrior: Bool` property
- Modify: `ResonanceBreathing/Services/SessionConfiguration.swift` — add `useECGPrior` and `ecgPriorMean/Std` fields

**Step 1: Add the new property to UserSettings**

In `ResonanceBreathing/Models/UserSettings.swift`, add:

```swift
var useECGPrior: Bool
```

And update the `init`:

```swift
init(
    defaultDuration: TimeInterval = 600,
    defaultBreathingRate: Double = 5.5,
    hapticsEnabled: Bool = true,
    hapticIntensity: Double = 0.8,
    useECGPrior: Bool = false
)
```

**Step 2: Add ECG prior fields to SessionConfiguration**

In `ResonanceBreathing/Services/SessionConfiguration.swift`, add:

```swift
var useECGPrior: Bool
var ecgPriorMean: Double?
var ecgPriorStd: Double?
```

And update both `init`s to include these fields. The `init(settings:)` should read `settings.useECGPrior`.

**Step 3: Verify build and run tests**

Run: `xcodebuild build -project ResonanceBreathing.xcodeproj -scheme ResonanceBreathing -destination 'generic/platform=iOS Simulator' -quiet && xcodebuild test -project ResonanceBreathing.xcodeproj -scheme ResonanceBreathing -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | grep "Executed"`
Expected: BUILD SUCCEEDED, all tests pass

**Step 4: Commit**

```bash
git add ResonanceBreathing/Models/UserSettings.swift \
       ResonanceBreathing/Services/SessionConfiguration.swift
git commit -m "feat: add useECGPrior setting to UserSettings and SessionConfiguration"
```

---

## Task 8: Wire BayesianPacer into SessionManager (iOS)

Replace the `AdaptivePacer` in `SessionManager` with `BayesianPacer`. The BayesianPacer should receive recent HR samples (last ~30s) and use RSA amplitude as its optimization signal. The old AdaptivePacer is kept in BreathingCore but no longer used.

**Files:**
- Modify: `ResonanceBreathing/Services/SessionManager.swift`

**Key changes:**
1. Replace `pacer: AdaptivePacer` with `pacer: BayesianPacer`
2. In `startSession()`: create BayesianPacer with ECG prior if available, otherwise population prior
3. In `processWatchData()`: pass `hrSamples` to `pacer.update(hrSamples:elapsedTime:)` instead of `pacer.update(coherence:elapsedTime:)`
4. Update `SessionView` references from `pacer.sessionPhase` to `pacer.phase`
5. Add ECG prior computation in `startSession()` if `configuration.useECGPrior` is true

**Detailed changes to `SessionManager.swift`:**

Replace the `pacer` property type:
```swift
private(set) var pacer: BayesianPacer
```

In `init()`:
```swift
self.pacer = BayesianPacer()
```

In `startSession()`:
```swift
if let mean = configuration.ecgPriorMean, let std = configuration.ecgPriorStd {
    pacer = BayesianPacer(priorMean: mean, priorStd: std)
} else {
    pacer = BayesianPacer(priorMean: configuration.startingBPM)
}
```

In `processWatchData()`, replace the pacer update block:
```swift
// Replace:
// pacer.update(coherence: coherence, elapsedTime: elapsedSeconds)
// With:
let recentHRForPacer = Array(hrSamples.suffix(30))
pacer.update(hrSamples: recentHRForPacer, elapsedTime: elapsedSeconds)
```

**Step 1: Make the changes described above**

**Step 2: Update SessionView pacer phase reference**

In `ResonanceBreathing/Views/SessionView.swift`, line ~88:
```swift
// Replace:
isAdapting: sessionManager.pacer.sessionPhase != .resonanceLock
// With:
isAdapting: sessionManager.pacer.phase != .converged
```

**Step 3: Build and run tests**

Run: `xcodebuild build -project ResonanceBreathing.xcodeproj -scheme ResonanceBreathing -destination 'generic/platform=iOS Simulator' -quiet 2>&1 | tail -3`
Expected: BUILD SUCCEEDED

Run: `xcodebuild test -project ResonanceBreathing.xcodeproj -scheme ResonanceBreathing -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep "Executed"`
Expected: All tests pass (may need to update SessionManagerTests for new pacer type)

**Step 4: Commit**

```bash
git add ResonanceBreathing/Services/SessionManager.swift \
       ResonanceBreathing/Views/SessionView.swift
git commit -m "feat: wire BayesianPacer into iOS SessionManager replacing AdaptivePacer"
```

---

## Task 9: Wire BayesianPacer into WatchSessionManager

Same changes as Task 8 but for the standalone Watch session manager.

**Files:**
- Modify: `ResonanceBreathingWatch Watch App/WatchSessionManager.swift`

**Key changes (mirror Task 8):**
1. Replace `pacer: AdaptivePacer` with `pacer: BayesianPacer`
2. Update `startSession()` to create BayesianPacer with configuration
3. Update `tick()` to pass hrSamples to pacer
4. Update `WatchSessionView.swift` if it references `pacerPhase`

**Step 1: Make changes to WatchSessionManager.swift**

Replace `AdaptivePacer` → `BayesianPacer` in the same way as Task 8.

In `tick()`:
```swift
// Replace:
// pacer.update(coherence: coherence, elapsedTime: elapsedSeconds)
// With:
let recentHRForPacer = Array(hrSamples.suffix(30))
pacer.update(hrSamples: recentHRForPacer, elapsedTime: elapsedSeconds)
```

Update the `pacerPhase` published property mapping.

**Step 2: Build Watch app**

Run: `xcodebuild build -project ResonanceBreathing.xcodeproj -scheme "ResonanceBreathingWatch Watch App" -destination 'generic/platform=watchOS Simulator' -quiet 2>&1 | tail -3`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add "ResonanceBreathingWatch Watch App/WatchSessionManager.swift"
git commit -m "feat: wire BayesianPacer into Watch standalone session manager"
```

---

## Task 10: ECG Prior Toggle in Settings UI

Add the "Use ECG Prior" toggle to both the iPhone Settings view and Watch Settings view. When enabled, the app will read the most recent ECG/heartbeat recording from HealthKit before starting a session to seed the Bayesian estimator.

**Files:**
- Modify: `ResonanceBreathing/Views/SettingsView.swift`
- Modify: `ResonanceBreathingWatch Watch App/WatchSettingsView.swift`
- Modify: `ResonanceBreathing/Views/HomeView.swift` — compute ECG prior before session starts

**Step 1: Add toggle to iPhone SettingsView**

In `ResonanceBreathing/Views/SettingsView.swift`, add a new Section after "Haptics":

```swift
Section("Calibration") {
    Toggle("ECG Prior", isOn: Binding(
        get: { settings.useECGPrior },
        set: { settings.useECGPrior = $0 }
    ))
    .tint(AppTheme.tint)

    if settings.useECGPrior {
        Text("Reads your most recent ECG recording to estimate your resonant frequency before each session.")
            .font(.system(size: 13, weight: .regular, design: .rounded))
            .foregroundStyle(AppTheme.tertiaryText)
    }
}
```

**Step 2: Add toggle to Watch WatchSettingsView**

In `ResonanceBreathingWatch Watch App/WatchSettingsView.swift`, add:

```swift
Section {
    Toggle("ECG Prior", isOn: ecgPriorEnabled)
        .tint(Color(red: 0.38, green: 0.9, blue: 0.77))
        .listRowBackground(Color.white.opacity(0.06))
}
```

With the corresponding binding.

**Step 3: Wire ECG prior computation in HomeView**

In `ResonanceBreathing/Views/HomeView.swift`, before presenting SessionView, compute the ECG prior:

Add a `@State private var ecgPrior: ECGPriorService.Prior?` property and an async task that runs when `useECGPrior` is enabled. Pass the prior through `SessionConfiguration`:

```swift
.fullScreenCover(isPresented: $showSession) {
    let config: SessionConfiguration = {
        var c = sessionConfiguration
        if let prior = ecgPrior {
            c.ecgPriorMean = prior.meanBPM
            c.ecgPriorStd = prior.stdBPM
        }
        return c
    }()
    SessionView(configuration: config) { session in
        // ... existing completion handler
    }
}
```

**Step 4: Build both targets**

Run: `xcodebuild build -project ResonanceBreathing.xcodeproj -scheme ResonanceBreathing -destination 'generic/platform=iOS Simulator' -quiet && xcodebuild build -project ResonanceBreathing.xcodeproj -scheme "ResonanceBreathingWatch Watch App" -destination 'generic/platform=watchOS Simulator' -quiet 2>&1 | tail -3`
Expected: BUILD SUCCEEDED for both

**Step 5: Commit**

```bash
git add ResonanceBreathing/Views/SettingsView.swift \
       ResonanceBreathing/Views/HomeView.swift \
       "ResonanceBreathingWatch Watch App/WatchSettingsView.swift"
git commit -m "feat: add ECG Prior toggle to settings and wire into session start"
```

---

## Task 11: Session View Bayesian Info Display

Show the Bayesian estimator's state during a session: estimated resonant frequency, uncertainty, and pacer phase (warmup/exploring/converged).

**Files:**
- Modify: `ResonanceBreathing/Components/MetricsBarView.swift` — add estimated RF and uncertainty
- Modify: `ResonanceBreathing/Views/SessionView.swift` — pass new metrics
- Modify: `ResonanceBreathingWatch Watch App/WatchSessionView.swift` — show pacer phase name

**Step 1: Update MetricsBarView on iPhone**

Read `ResonanceBreathing/Components/MetricsBarView.swift` first to understand the current layout, then add `estimatedRF: Double` and `pacerPhase: String` parameters.

**Step 2: Update WatchSessionView**

In the active session view, replace the static "guide" text with the pacer phase:

```swift
Text("\(pacerPhaseLabel) · \(String(format: "%.1f bpm", sessionManager.guidedBPM))")
    .font(.system(size: 10, weight: .medium, design: .rounded))
    .foregroundStyle(.white.opacity(0.5))
```

Where `pacerPhaseLabel` maps `.warmup` → "Warming up", `.exploring` → "Exploring", `.converged` → "Locked".

**Step 3: Build both targets**

Run both build commands as in Task 10.
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add ResonanceBreathing/Components/MetricsBarView.swift \
       ResonanceBreathing/Views/SessionView.swift \
       "ResonanceBreathingWatch Watch App/WatchSessionView.swift"
git commit -m "feat: display Bayesian pacer state and estimated resonant frequency in session UI"
```

---

## Task 12: Run All Tests and Verify

Final verification that everything works together.

**Step 1: Run BreathingCore package tests**

Run: `cd Packages/BreathingCore && swift test 2>&1 | grep "Executed"`
Expected: All tests pass (original + LombScargle + RSAAmplitude + ParticleFilter + UCB + BayesianPacer)

**Step 2: Run app tests**

Run: `xcodebuild test -project ResonanceBreathing.xcodeproj -scheme ResonanceBreathing -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep "Executed"`
Expected: All tests pass

**Step 3: Build Watch app**

Run: `xcodebuild build -project ResonanceBreathing.xcodeproj -scheme "ResonanceBreathingWatch Watch App" -destination 'generic/platform=watchOS Simulator' 2>&1 | tail -3`
Expected: BUILD SUCCEEDED

**Step 4: Launch Watch simulator and verify**

Run the Watch app in the simulator with `-autoStartSession` and verify:
- Session starts in "Warming up" phase
- Transitions to "Exploring" after ~30 seconds
- Coherence and RMSSD populate
- Breathing rate changes as UCB explores
- Eventually transitions to "Locked" when particle filter converges

**Step 5: Final commit**

```bash
git add -A
git commit -m "chore: final verification — all tests pass, both targets build"
```
