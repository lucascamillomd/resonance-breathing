import XCTest
@testable import BreathingCore

final class LombScargleTests: XCTestCase {

    func testPureSineWavePeaksAtCorrectFrequency() {
        let freq = 0.1
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
        let freq = 0.092
        var timestamps: [Double] = []
        var values: [Double] = []
        var t = 0.0
        for _ in 0..<80 {
            timestamps.append(t)
            values.append(5.0 * sin(2.0 * .pi * freq * t) + Double.random(in: -0.5...0.5))
            t += 0.8 + Double.random(in: -0.1...0.1)
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
