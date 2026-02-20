import SwiftUI
import BreathingCore

struct BloomAnimationView: View {
    let phase: BreathingPhase
    let progress: Double       // 0.0–1.0 progress through current phase
    let coherence: Double      // 0.0–1.0 coherence score
    let petalCount: Int

    init(phase: BreathingPhase, progress: Double, coherence: Double, petalCount: Int = 7) {
        self.phase = phase
        self.progress = progress
        self.coherence = coherence
        self.petalCount = petalCount
    }

    var body: some View {
        ZStack {
            ForEach(0..<petalCount, id: \.self) { index in
                PetalShape()
                    .fill(petalFill)
                    .frame(width: 40, height: petalHeight)
                    .offset(y: -petalOffset)
                    .rotationEffect(.degrees(Double(index) * (360.0 / Double(petalCount))))
                    .shadow(color: glowColor, radius: glowRadius)
            }

            Circle()
                .fill(AppTheme.petalTeal.opacity(0.6 + coherence * 0.4))
                .frame(width: 20, height: 20)
                .shadow(color: glowColor, radius: glowRadius * 0.5)
        }
        .animation(.easeInOut(duration: 1.0), value: expansion)
    }

    private var expansion: Double {
        switch phase {
        case .inhale: return progress
        case .hold: return 1.0
        case .exhale: return 1.0 - progress
        }
    }

    private var petalHeight: CGFloat {
        let minHeight: CGFloat = 30
        let maxHeight: CGFloat = 100
        return minHeight + CGFloat(expansion) * (maxHeight - minHeight)
    }

    private var petalOffset: CGFloat {
        petalHeight * 0.3
    }

    private var petalFill: some ShapeStyle {
        AppTheme.petalGradient.opacity(0.5 + expansion * 0.5)
    }

    private var glowColor: Color {
        AppTheme.coherenceGlow.opacity(coherence * 0.6)
    }

    private var glowRadius: CGFloat {
        CGFloat(coherence * 15 + expansion * 10)
    }
}

#Preview {
    BloomAnimationView(phase: .inhale, progress: 0.5, coherence: 0.8)
        .frame(width: 300, height: 300)
        .background(AppTheme.background)
}
