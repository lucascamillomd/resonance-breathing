import Foundation
import WatchKit

final class HapticEngine: ObservableObject {
    @Published var currentPhase: String = "idle"

    private var hapticTimer: Timer?
    private var phaseStartTime: Date = .now
    private var inhaleDuration: Double = 4.36
    private var holdDuration: Double = 0.55
    private var exhaleDuration: Double = 6.0

    func updateParameters(inhale: Double, hold: Double, exhale: Double) {
        inhaleDuration = inhale
        holdDuration = hold
        exhaleDuration = exhale
    }

    func start() {
        phaseStartTime = .now
        currentPhase = "inhale"
        scheduleNextTick()
    }

    func stop() {
        hapticTimer?.invalidate()
        hapticTimer = nil
        currentPhase = "idle"
    }

    private func scheduleNextTick() {
        let interval = currentHapticInterval()
        hapticTimer?.invalidate()
        hapticTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        let elapsed = Date.now.timeIntervalSince(phaseStartTime)

        switch currentPhase {
        case "inhale":
            WKInterfaceDevice.current().play(.directionUp)
            if elapsed >= inhaleDuration {
                transitionTo("hold")
            } else {
                scheduleNextTick()
            }
        case "hold":
            WKInterfaceDevice.current().play(.click)
            if elapsed >= holdDuration {
                transitionTo("exhale")
            } else {
                scheduleNextTick()
            }
        case "exhale":
            WKInterfaceDevice.current().play(.directionDown)
            if elapsed >= exhaleDuration {
                transitionTo("inhale")
            } else {
                scheduleNextTick()
            }
        default:
            break
        }
    }

    private func transitionTo(_ phase: String) {
        currentPhase = phase
        phaseStartTime = .now
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.scheduleNextTick()
        }
    }

    private func currentHapticInterval() -> Double {
        let elapsed = Date.now.timeIntervalSince(phaseStartTime)
        switch currentPhase {
        case "inhale":
            let progress = min(elapsed / inhaleDuration, 1.0)
            return 0.8 - progress * 0.5
        case "hold":
            return 0.6
        case "exhale":
            let progress = min(elapsed / exhaleDuration, 1.0)
            return 0.3 + progress * 0.5
        default:
            return 1.0
        }
    }
}
