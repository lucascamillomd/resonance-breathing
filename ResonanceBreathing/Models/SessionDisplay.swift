import Foundation

enum SessionDisplay {
    static func duration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(hours)h"
        }

        if minutes > 0 {
            if seconds > 0 {
                return "\(minutes)m \(seconds)s"
            }
            return "\(minutes)m"
        }

        return "\(seconds)s"
    }

    static func coherenceBand(for coherence: Double) -> String {
        let clamped = min(max(coherence, 0), 1)
        switch clamped {
        case ..<0.25:
            return "Emerging"
        case ..<0.5:
            return "Building"
        case ..<0.75:
            return "Stable"
        default:
            return "Deep"
        }
    }
}

extension BreathingSession {
    var peakCoherencePercent: Int {
        Int((min(max(peakCoherence, 0), 1) * 100).rounded())
    }

    var averageCoherence: Double {
        guard !dataPoints.isEmpty else { return 0 }
        return dataPoints.reduce(0) { $0 + $1.coherence } / Double(dataPoints.count)
    }

    var averageCoherencePercent: Int {
        Int((min(max(averageCoherence, 0), 1) * 100).rounded())
    }
}
