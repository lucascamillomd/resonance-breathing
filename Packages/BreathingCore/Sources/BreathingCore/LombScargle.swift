import Foundation

public enum LombScargle {
    public struct Result: Sendable {
        public let frequencies: [Double]
        public let power: [Double]
        public let peakFrequency: Double
        public let peakPower: Double
    }

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

            var sin2Sum = 0.0
            var cos2Sum = 0.0
            for t in timestamps {
                sin2Sum += sin(2.0 * omega * t)
                cos2Sum += cos(2.0 * omega * t)
            }
            let tau = atan2(sin2Sum, cos2Sum) / (2.0 * omega)

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
