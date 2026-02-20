import Foundation

public enum BreathingPhase: String, CaseIterable, Sendable {
    case inhale
    case hold
    case exhale

    public var next: BreathingPhase {
        switch self {
        case .inhale: return .hold
        case .hold: return .exhale
        case .exhale: return .inhale
        }
    }

    public var label: String {
        switch self {
        case .inhale: return "INHALE"
        case .hold: return "HOLD"
        case .exhale: return "EXHALE"
        }
    }
}
