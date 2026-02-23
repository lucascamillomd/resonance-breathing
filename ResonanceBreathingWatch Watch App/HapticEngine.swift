import Foundation
import WatchKit

final class HapticEngine: ObservableObject {
    @Published var currentPhase: String = "idle"
    @Published var phaseProgress: Double = 0

    private var hapticTimer: Timer?
    private var progressTimer: Timer?
    private var phaseStartTime: Date = .now
    private var inhaleDuration: Double = 4.36
    private var exhaleDuration: Double = 6.55

    func updateParameters(inhale: Double, hold: Double, exhale: Double) {
        inhaleDuration = max(inhale, 0.1)
        exhaleDuration = max(exhale, 0.1)
    }

    func start() {
        phaseStartTime = .now
        currentPhase = "inhale"
        phaseProgress = 0
        scheduleNextTick()
        startProgressUpdates()
    }

    func stop() {
        hapticTimer?.invalidate()
        hapticTimer = nil
        progressTimer?.invalidate()
        progressTimer = nil
        currentPhase = "idle"
        phaseProgress = 0
    }

    private func startProgressUpdates() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let elapsed = Date.now.timeIntervalSince(self.phaseStartTime)
            let duration = self.currentPhase == "inhale" ? self.inhaleDuration : self.exhaleDuration
            self.phaseProgress = min(elapsed / max(duration, 0.1), 1.0)
        }
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
        let device = WKInterfaceDevice.current()

        switch currentPhase {
        case "inhale":
            // Double-tap: directionUp + immediate retry for a strong "rising" feel
            device.play(.directionUp)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                device.play(.directionUp)
            }
            if elapsed >= inhaleDuration {
                fireTransitionBurst {
                    self.transitionTo("exhale")
                }
            } else {
                scheduleNextTick()
            }
        case "exhale":
            // Single directionDown — softer, contrasts with the double-tap inhale
            device.play(.directionDown)
            if elapsed >= exhaleDuration {
                fireTransitionBurst {
                    self.transitionTo("inhale")
                }
            } else {
                scheduleNextTick()
            }
        default:
            break
        }
    }

    /// Triple notification burst — strongest possible signal for phase switch
    private func fireTransitionBurst(then completion: @escaping () -> Void) {
        let device = WKInterfaceDevice.current()
        device.play(.notification)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            device.play(.notification)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                device.play(.notification)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    completion()
                }
            }
        }
    }

    private func transitionTo(_ phase: String) {
        currentPhase = phase
        phaseStartTime = .now
        phaseProgress = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.scheduleNextTick()
        }
    }

    private func currentHapticInterval() -> Double {
        let elapsed = Date.now.timeIntervalSince(phaseStartTime)
        switch currentPhase {
        case "inhale":
            // Very rapid accelerating double-taps: 0.25s → 0.12s
            let progress = min(elapsed / max(inhaleDuration, 0.1), 1.0)
            return max(0.12, 0.25 - progress * 0.13)
        case "exhale":
            // Slower single taps: 0.2s → 0.7s
            let progress = min(elapsed / max(exhaleDuration, 0.1), 1.0)
            return max(0.15, 0.2 + progress * 0.5)
        default:
            return 1.0
        }
    }
}
