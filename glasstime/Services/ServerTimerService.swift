import FirebaseFunctions
import Foundation
import os

protocol ServerTimerServicing: Sendable {
    func scheduleEnd(pushToken: String, endDate: Date, sessionID: String, shouldEndActivity: Bool) async
    func cancelEnd(sessionID: String) async
}

@MainActor
final class ServerTimerService: ServerTimerServicing {
    private let logger = Logger(subsystem: "com.prismlabs.glasstime", category: "ServerTimer")
    private lazy var functions = Functions.functions()

    func scheduleEnd(pushToken: String, endDate: Date, sessionID: String, shouldEndActivity: Bool) async {
        let data: [String: Any] = [
            "pushToken": pushToken,
            "endDate": ISO8601DateFormatter().string(from: endDate),
            "sessionID": sessionID,
            "shouldEndActivity": shouldEndActivity,
        ]

        do {
            let result = try await functions.httpsCallable("scheduleTimerEnd").call(data)
            if let response = result.data as? [String: Any] {
                logger.info("📡 Server timer scheduled: \(sessionID) — \(response["status"] as? String ?? "")")
                SharedLogger.log("Server scheduled: \(sessionID), endDate=\(endDate)", source: "APP")
            }
        } catch {
            // Non-critical — local notification is the fallback
            logger.error("📡 Server schedule failed: \(error.localizedDescription)")
        }
    }

    func cancelEnd(sessionID: String) async {
        let data: [String: String] = ["sessionID": sessionID]

        do {
            let result = try await functions.httpsCallable("cancelTimerEnd").call(data)
            if let response = result.data as? [String: Any] {
                logger.info("📡 Server timer cancelled: \(sessionID) — \(response["status"] as? String ?? "")")
            }
        } catch {
            // Non-critical — task may have already fired or been cleaned up
            logger.warning("📡 Server cancel error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview Stub

struct PreviewServerTimerService: ServerTimerServicing {
    func scheduleEnd(pushToken: String, endDate: Date, sessionID: String, shouldEndActivity: Bool) async {}
    func cancelEnd(sessionID: String) async {}
}
