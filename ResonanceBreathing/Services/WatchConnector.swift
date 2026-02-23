import Foundation
import WatchConnectivity
import BreathingCore

struct WatchPhysioSample: Equatable, Sendable {
    let timestamp: TimeInterval
    let heartRate: Double
    let rrIntervals: [Double]
    let sequence: Int
}

@MainActor
final class WatchConnector: NSObject, ObservableObject {
    static let shared = WatchConnector()

    @Published var isWatchReachable = false
    @Published private(set) var pendingSampleCount = 0

    private var session: WCSession?
    private var pendingSamples: [WatchPhysioSample] = []
    private var fallbackSequence: Int = 0
    private var seenSequences: Set<Int> = []
    private var pendingCommands: [[String: Any]] = []

    init(activateSession: Bool = true) {
        super.init()
        if activateSession, WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            self.session = session
        }
    }

    func sendBreathingParameters(_ params: BreathingParameters) {
        let message: [String: Any] = [
            "type": "breathingParams",
            "inhaleDuration": params.inhaleDuration,
            "holdDuration": params.holdDuration,
            "exhaleDuration": params.exhaleDuration,
            "bpm": params.breathsPerMinute
        ]
        send(message)
    }

    func sendCommand(_ command: String) {
        let message: [String: Any] = ["type": "command", "command": command]
        guard let session else { return }

        // Try every delivery method: sendMessage for immediate, transferUserInfo
        // for queued, and updateApplicationContext as last resort.
        // WCSession may report isWatchAppInstalled=false when apps are sideloaded
        // during development, so we attempt delivery regardless.
        if session.activationState == .activated {
            if session.isReachable {
                session.sendMessage(message, replyHandler: nil, errorHandler: nil)
            }
            session.transferUserInfo(message)
            try? session.updateApplicationContext(message)
        } else {
            pendingCommands.append(message)
        }
    }

    func enqueueSample(_ sample: WatchPhysioSample) {
        guard seenSequences.insert(sample.sequence).inserted else { return }
        pendingSamples.append(sample)
        pendingSampleCount = pendingSamples.count
    }

    func drainSamples() -> [WatchPhysioSample] {
        let drained = pendingSamples.sorted { $0.sequence < $1.sequence }
        pendingSamples.removeAll(keepingCapacity: true)
        pendingSampleCount = 0
        return drained
    }

    func resetSampleBuffer() {
        pendingSamples.removeAll(keepingCapacity: true)
        seenSequences.removeAll(keepingCapacity: true)
        fallbackSequence = 0
        pendingSampleCount = 0
    }

    private func flushPendingCommands() {
        guard let session, session.activationState == .activated else { return }
        let commands = pendingCommands
        pendingCommands.removeAll()
        for message in commands {
            if session.isReachable {
                session.sendMessage(message, replyHandler: nil, errorHandler: nil)
            }
            session.transferUserInfo(message)
            try? session.updateApplicationContext(message)
        }
    }

    private func send(_ message: [String: Any]) {
        guard let session else { return }
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil)
            return
        }
        try? session.updateApplicationContext(message)
    }

    private func parseSample(message: [String: Any]) -> WatchPhysioSample? {
        guard let type = message["type"] as? String, type == "heartRateData" else { return nil }
        let heartRate = message["hr"] as? Double ?? 0
        let rr = message["rrIntervals"] as? [Double] ?? []
        let timestamp = message["timestamp"] as? TimeInterval ?? Date.now.timeIntervalSince1970
        let sequence = message["sequence"] as? Int ?? nextFallbackSequence()
        return WatchPhysioSample(timestamp: timestamp, heartRate: heartRate, rrIntervals: rr, sequence: sequence)
    }

    private func nextFallbackSequence() -> Int {
        fallbackSequence += 1
        return fallbackSequence
    }
}

extension WatchConnector: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            isWatchReachable = session.isReachable
            flushPendingCommands()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isWatchReachable = session.isReachable
            if session.isReachable {
                flushPendingCommands()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            if let sample = parseSample(message: message) {
                enqueueSample(sample)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            if let sample = parseSample(message: applicationContext) {
                enqueueSample(sample)
            }
        }
    }
}
