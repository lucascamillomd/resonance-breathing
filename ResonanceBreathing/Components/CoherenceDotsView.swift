import SwiftUI

struct CoherenceDotsView: View {
    let score: Double
    private let totalDots = 5

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalDots, id: \.self) { index in
                Circle()
                    .fill(index < activeDots ? AppTheme.coherenceActive : AppTheme.coherenceInactive)
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var activeDots: Int {
        Int(round(score * Double(totalDots)))
    }
}
