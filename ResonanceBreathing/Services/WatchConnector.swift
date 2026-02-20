import Foundation
import WatchConnectivity
import BreathingCore

@MainActor
final class WatchConnector: NSObject, ObservableObject {
    @Published var isWatchReachable = false
    @Published var latestHeartRate: Double = 0
    @Published var latestRRIntervals: [Double] = []

    private var session: WCSession?

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            self.session = session
        }
    }

    func sendBreathingParameters(_ params: BreathingParameters) {
        guard let session, session.isReachable else { return }
        let message: [String: Any] = [
            "type": "breathingParams",
            "inhaleDuration": params.inhaleDuration,
            "holdDuration": params.holdDuration,
            "exhaleDuration": params.exhaleDuration,
            "bpm": params.breathsPerMinute
        ]
        session.sendMessage(message, replyHandler: nil)
    }

    func sendCommand(_ command: String) {
        guard let session, session.isReachable else { return }
        session.sendMessage(["type": "command", "command": command], replyHandler: nil)
    }
}

extension WatchConnector: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isWatchReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        Task { @MainActor in
            switch type {
            case "heartRateData":
                if let hr = message["hr"] as? Double {
                    latestHeartRate = hr
                }
                if let rr = message["rrIntervals"] as? [Double] {
                    latestRRIntervals = rr
                }
            default:
                break
            }
        }
    }
}
