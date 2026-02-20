import Foundation
import WatchConnectivity

class PhoneConnector: NSObject, ObservableObject {
    @Published var inhaleDuration: Double = 4.36
    @Published var holdDuration: Double = 0.55
    @Published var exhaleDuration: Double = 6.0

    var onCommand: ((String) -> Void)?

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func sendHeartRateData(hr: Double, rrIntervals: [Double]) {
        guard WCSession.default.isReachable else { return }
        let message: [String: Any] = [
            "type": "heartRateData",
            "hr": hr,
            "rrIntervals": rrIntervals
        ]
        WCSession.default.sendMessage(message, replyHandler: nil)
    }
}

extension PhoneConnector: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        DispatchQueue.main.async {
            switch type {
            case "breathingParams":
                self.inhaleDuration = message["inhaleDuration"] as? Double ?? self.inhaleDuration
                self.holdDuration = message["holdDuration"] as? Double ?? self.holdDuration
                self.exhaleDuration = message["exhaleDuration"] as? Double ?? self.exhaleDuration
            case "command":
                if let command = message["command"] as? String {
                    self.onCommand?(command)
                }
            default:
                break
            }
        }
    }
}
