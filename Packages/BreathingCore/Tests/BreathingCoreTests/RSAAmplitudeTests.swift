import XCTest
@testable import BreathingCore

final class RSAAmplitudeTests: XCTestCase {

    func testPureSineWaveReturnsDoubleAmplitude() {
        let samples = (0..<60).map { i -> Double in
            68.0 + 5.0 * sin(2.0 * .pi * 0.1 * Double(i))
        }
        let amplitude = RSAAmplitude.compute(hrSamples: samples)
        XCTAssertEqual(amplitude, 10.0, accuracy: 2.0)
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
