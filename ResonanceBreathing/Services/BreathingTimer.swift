import Foundation
import BreathingCore
import QuartzCore

@MainActor
final class BreathingTimer: ObservableObject {
    @Published var currentPhase: BreathingPhase = .inhale
    @Published var phaseProgress: Double = 0.0
    @Published var phaseTimeRemaining: Double = 0.0
    @Published var isRunning: Bool = false

    var parameters: BreathingParameters {
        didSet { updatePhaseDuration() }
    }

    private var displayLink: CADisplayLink?
    private var phaseStartTime: CFTimeInterval = 0
    private var currentPhaseDuration: Double = 0

    init(parameters: BreathingParameters = BreathingParameters(breathsPerMinute: 5.5)) {
        self.parameters = parameters
        updatePhaseDuration()
    }

    func start() {
        isRunning = true
        currentPhase = .inhale
        phaseProgress = 0
        updatePhaseDuration()
        phaseStartTime = CACurrentMediaTime()

        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        isRunning = false
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        let elapsed = CACurrentMediaTime() - phaseStartTime
        phaseProgress = min(elapsed / currentPhaseDuration, 1.0)
        phaseTimeRemaining = max(currentPhaseDuration - elapsed, 0)

        if elapsed >= currentPhaseDuration {
            advancePhase()
        }
    }

    private func advancePhase() {
        currentPhase = currentPhase.next
        phaseStartTime = CACurrentMediaTime()
        updatePhaseDuration()
    }

    private func updatePhaseDuration() {
        switch currentPhase {
        case .inhale: currentPhaseDuration = parameters.inhaleDuration
        case .hold: currentPhaseDuration = parameters.holdDuration
        case .exhale: currentPhaseDuration = parameters.exhaleDuration
        }
    }
}
