import SwiftUI

struct CoherenceDotsView: View {
    let score: Double
    private let totalDots = 5

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<totalDots, id: \.self) { index in
                Capsule()
                    .fill(index < activeDots ? AppTheme.coherenceActive : AppTheme.coherenceInactive)
                    .frame(width: 12, height: 6)
            }
        }
    }

    private var activeDots: Int {
        let clamped = min(max(score, 0), 1)
        return Int(round(clamped * Double(totalDots)))
    }
}
