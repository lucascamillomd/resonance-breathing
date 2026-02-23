import Foundation
import WatchConnectivity

class PhoneConnector: NSObject, ObservableObject {
    @Published var inhaleDuration: Double = 4.36
    @Published var holdDuration: Double = 0.55
    @Published var exhaleDuration: Double = 6.0

    var onCommand: ((String) -> Void)?
    var onBreathingParameters: ((Double, Double, Double) -> Void)?

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func sendHeartRateData(hr: Double, rrIntervals: [Double], timestamp: TimeInterval, sequence: Int) {
        let message: [String: Any] = [
            "type": "heartRateData",
            "hr": hr,
            "rrIntervals": rrIntervals,
            "timestamp": timestamp,
            "sequence": sequence
        ]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil)
            return
        }

        try? WCSession.default.updateApplicationContext(message)
    }

    private func handleIncomingMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        switch type {
        case "breathingParams":
            inhaleDuration = message["inhaleDuration"] as? Double ?? inhaleDuration
            holdDuration = message["holdDuration"] as? Double ?? holdDuration
            exhaleDuration = message["exhaleDuration"] as? Double ?? exhaleDuration
            onBreathingParameters?(inhaleDuration, holdDuration, exhaleDuration)
        case "command":
            if let command = message["command"] as? String {
                onCommand?(command)
            }
        default:
            break
        }
    }
}

extension PhoneConnector: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.handleIncomingMessage(message)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.handleIncomingMessage(applicationContext)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        DispatchQueue.main.async {
            self.handleIncomingMessage(userInfo)
        }
    }
}
