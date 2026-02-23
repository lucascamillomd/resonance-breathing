import SwiftUI
import BreathingCore

struct BreathingWaveformView: View {
    let breathingBPM: Double
    let elapsedSeconds: Double
    let phase: BreathingPhase
    let phaseProgress: Double
    let heartRateSamples: [(time: Double, hr: Double)]
    let coherence: Double

    private let visibleWindow: Double = 30.0

    private var windowStart: Double {
        max(0, elapsedSeconds - visibleWindow)
    }

    private var windowEnd: Double {
        max(visibleWindow, elapsedSeconds)
    }

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let midY = h * 0.5
            let amplitude = h * 0.34
            let freqHz = breathingBPM / 60.0
            let timeRange = windowEnd - windowStart
            guard timeRange > 0 else { return }

            // -- Breathing guide fill (gradient under curve) --
            let fillPath = buildBreathingPath(
                width: w, midY: midY, amplitude: amplitude,
                freqHz: freqHz, timeRange: timeRange, closed: true, bottomY: h
            )
            let fillOpacity = 0.08 + coherence * 0.14
            context.fill(
                fillPath,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.45, green: 0.76, blue: 0.98).opacity(fillOpacity),
                        Color(red: 0.33, green: 0.88, blue: 0.75).opacity(fillOpacity * 0.3),
                        Color.clear,
                    ]),
                    startPoint: CGPoint(x: w * 0.5, y: midY - amplitude),
                    endPoint: CGPoint(x: w * 0.5, y: h)
                )
            )

            // -- Breathing guide stroke --
            let strokePath = buildBreathingPath(
                width: w, midY: midY, amplitude: amplitude,
                freqHz: freqHz, timeRange: timeRange, closed: false, bottomY: h
            )
            let strokeOpacity = 0.5 + coherence * 0.5
            context.stroke(
                strokePath,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.45, green: 0.76, blue: 0.98).opacity(strokeOpacity),
                        Color(red: 0.33, green: 0.88, blue: 0.75).opacity(strokeOpacity),
                    ]),
                    startPoint: CGPoint(x: 0, y: midY),
                    endPoint: CGPoint(x: w, y: midY)
                ),
                lineWidth: 2.5
            )

            // -- Glow on breathing curve (coherence-driven) --
            if coherence > 0.1 {
                context.stroke(
                    strokePath,
                    with: .color(Color(red: 0.45, green: 0.76, blue: 0.98).opacity(coherence * 0.3)),
                    lineWidth: 8
                )
                context.addFilter(.blur(radius: 6))
            }

            // -- HR trace --
            let visibleHR = heartRateSamples.filter { $0.time >= windowStart && $0.time <= windowEnd }
            if visibleHR.count >= 2 {
                let hrs = visibleHR.map(\.hr)
                let minHR = hrs.min()!
                let maxHR = hrs.max()!
                let range = max(maxHR - minHR, 1.0)
                let hrMid = (maxHR + minHR) / 2.0

                var hrPath = Path()
                for (i, sample) in visibleHR.enumerated() {
                    let x = ((sample.time - windowStart) / timeRange) * w
                    let normalized = (sample.hr - hrMid) / (range / 2.0)
                    let y = midY - normalized * amplitude * 0.85
                    if i == 0 {
                        hrPath.move(to: CGPoint(x: x, y: y))
                    } else {
                        hrPath.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                // Reset filter before drawing HR
                context.drawLayer { inner in
                    inner.stroke(
                        hrPath,
                        with: .color(Color(red: 0.98, green: 0.41, blue: 0.44).opacity(0.8)),
                        lineWidth: 1.8
                    )
                }
            }

            // -- "Now" indicator --
            let nowX = ((elapsedSeconds - windowStart) / timeRange) * w
            if nowX >= 0 && nowX <= w {
                var nowLine = Path()
                nowLine.move(to: CGPoint(x: nowX, y: 4))
                nowLine.addLine(to: CGPoint(x: nowX, y: h - 4))

                context.drawLayer { inner in
                    inner.stroke(
                        nowLine,
                        with: .color(Color.white.opacity(0.35)),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )

                    // Small dot at the breathing curve position
                    let curveY = midY - amplitude * sin(2.0 * .pi * freqHz * elapsedSeconds)
                    let dotRect = CGRect(x: nowX - 4, y: curveY - 4, width: 8, height: 8)
                    inner.fill(
                        Path(ellipseIn: dotRect),
                        with: .color(Color(red: 0.45, green: 0.76, blue: 0.98))
                    )
                    // Glow ring
                    let glowRect = CGRect(x: nowX - 8, y: curveY - 8, width: 16, height: 16)
                    inner.stroke(
                        Path(ellipseIn: glowRect),
                        with: .color(Color(red: 0.45, green: 0.76, blue: 0.98).opacity(0.4)),
                        lineWidth: 2
                    )
                }
            }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func buildBreathingPath(
        width: CGFloat, midY: CGFloat, amplitude: CGFloat,
        freqHz: Double, timeRange: Double,
        closed: Bool, bottomY: CGFloat
    ) -> Path {
        let steps = 160
        let dt = timeRange / Double(steps)
        var path = Path()

        for i in 0...steps {
            let t = windowStart + Double(i) * dt
            let x = (Double(i) / Double(steps)) * width
            let y = midY - amplitude * sin(2.0 * .pi * freqHz * t)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        if closed {
            path.addLine(to: CGPoint(x: width, y: bottomY))
            path.addLine(to: CGPoint(x: 0, y: bottomY))
            path.closeSubpath()
        }

        return path
    }
}
