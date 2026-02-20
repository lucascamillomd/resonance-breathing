import XCTest
@testable import BreathingCore

/// Deterministic PRNG for reproducible tests (SplitMix64 algorithm).
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}

final class CoherenceCalculatorTests: XCTestCase {

    func testPerfectlySinusoidalHRGivesHighCoherence() {
        let breathingFreqHz = 5.5 / 60.0
        let sampleRate = 4.0
        let duration = 30.0
        let numSamples = Int(duration * sampleRate)

        var hrSamples: [Double] = []
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let hr = 70.0 + 5.0 * sin(2.0 * .pi * breathingFreqHz * t)
            hrSamples.append(hr)
        }

        let calc = CoherenceCalculator()
        let score = calc.computeCoherence(
            hrSamples: hrSamples,
            sampleRateHz: sampleRate,
            breathingFreqHz: breathingFreqHz
        )
        XCTAssertGreaterThan(score, 0.7, "Perfect sinusoidal HR should yield high coherence")
    }

    func testRandomHRGivesLowCoherence() {
        // Use enough samples (120s at 4 Hz = 480) so the resonance band
        // contains many DFT bins (~13), preventing random concentration
        // in the 3-bin target window.
        var rng = SplitMix64(seed: 42)
        var hrSamples: [Double] = []
        for _ in 0..<480 {
            hrSamples.append(Double.random(in: 60...80, using: &rng))
        }

        let calc = CoherenceCalculator()
        let score = calc.computeCoherence(
            hrSamples: hrSamples,
            sampleRateHz: 4.0,
            breathingFreqHz: 5.5 / 60.0
        )
        XCTAssertLessThan(score, 0.4, "Random HR should yield low coherence")
    }

    func testCoherenceScaleIs0To1() {
        let calc = CoherenceCalculator()
        let score = calc.computeCoherence(
            hrSamples: Array(repeating: 70.0, count: 120),
            sampleRateHz: 4.0,
            breathingFreqHz: 5.5 / 60.0
        )
        XCTAssertGreaterThanOrEqual(score, 0.0)
        XCTAssertLessThanOrEqual(score, 1.0)
    }

    func testInsufficientSamplesReturnsZero() {
        let calc = CoherenceCalculator()
        let score = calc.computeCoherence(
            hrSamples: [70, 72],
            sampleRateHz: 4.0,
            breathingFreqHz: 5.5 / 60.0
        )
        XCTAssertEqual(score, 0.0)
    }
}
