import ActivityKit
import Foundation
import os

protocol LiveActivityServicing: Sendable {
    func startActivity(sessionID: String, durationMinutes: Int, timerEndDate: Date) async -> String?
    func updateActivity(remainingSeconds: Int, elapsedSeconds: Int, totalSeconds: Int, state: LiveTimerState, timerEndDate: Date?) async
    func endActivity() async
}

@MainActor
final class LiveActivityService: LiveActivityServicing {
    private let logger = Logger(subsystem: "com.prismlabs.glasstime", category: "LiveActivity")
    private var currentActivity: Activity<GlassTimeAttributes>?
    private var tokenTask: Task<Void, Never>?

    /// Starts a Live Activity and returns the push token (or nil if unavailable).
    func startActivity(sessionID: String, durationMinutes: Int, timerEndDate: Date) async -> String? {
        // End any existing activity first
        await endActivity()

        // Clean up orphaned activities from previous crashes
        for orphan in Activity<GlassTimeAttributes>.activities {
            await orphan.end(nil, dismissalPolicy: .immediate)
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.warning("Live Activities not enabled")
            return nil
        }

        let attributes = GlassTimeAttributes(
            sessionID: sessionID,
            totalDurationMinutes: durationMinutes,
            startedAt: Date()
        )

        let totalSeconds = durationMinutes * 60
        let remaining = max(0, Int(timerEndDate.timeIntervalSinceNow))

        let now = Date()
        let state = GlassTimeAttributes.ContentState(
            remainingSeconds: remaining,
            elapsedSeconds: totalSeconds - remaining,
            totalDurationSeconds: totalSeconds,
            timerState: .running,
            timerStartDate: now,
            timerEndDate: timerEndDate
        )

        let content = ActivityContent(state: state, staleDate: timerEndDate)

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: .token
            )
            logger.info("🟢 Live Activity started: \(sessionID)")
            SharedLogger.log("LA started: session=\(sessionID), endDate=\(timerEndDate)", source: "APP")

            // Wait for push token
            let token = await waitForPushToken()
            return token
        } catch {
            logger.error("Failed to start Live Activity: \(error.localizedDescription)")
            return nil
        }
    }

    func updateActivity(remainingSeconds: Int, elapsedSeconds: Int, totalSeconds: Int, state: LiveTimerState, timerEndDate: Date?) async {
        guard let activity = currentActivity else { return }

        let now = Date()
        let contentState = GlassTimeAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            elapsedSeconds: elapsedSeconds,
            totalDurationSeconds: totalSeconds,
            timerState: state,
            timerStartDate: state == .running ? now : nil,
            timerEndDate: state == .running ? timerEndDate : nil
        )

        let staleDate = state == .running ? timerEndDate : nil
        let content = ActivityContent(state: contentState, staleDate: staleDate)

        await activity.update(content)
        logger.info("🔄 Live Activity updated: state=\(state.rawValue), remaining=\(remainingSeconds)")
        SharedLogger.log("LA updated: state=\(state.rawValue), remaining=\(remainingSeconds), endDate=\(timerEndDate?.description ?? "nil")", source: "APP")
    }

    func endActivity() async {
        tokenTask?.cancel()
        tokenTask = nil

        guard let activity = currentActivity else { return }

        await activity.end(nil, dismissalPolicy: .immediate)
        currentActivity = nil
        logger.info("🔴 Live Activity ended")
        SharedLogger.log("LA ended", source: "APP")
    }

    // MARK: - Push Token

    /// Waits for the first push token with a 10-second timeout.
    /// Returns nil if token doesn't arrive in time (server fallback won't be scheduled,
    /// but local notification still works as fallback).
    private func waitForPushToken() async -> String? {
        guard let activity = currentActivity else { return nil }

        // Capture the async sequence on MainActor before entering task group
        let tokenUpdates = activity.pushTokenUpdates

        return await withTaskGroup(of: String?.self) { group in
            group.addTask { @MainActor in
                for await tokenData in tokenUpdates {
                    return tokenData.map { String(format: "%02x", $0) }.joined()
                }
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(10))
                return nil
            }

            let result = await group.next() ?? nil
            group.cancelAll()

            if let token = result {
                logger.info("🔑 Push token received: \(token.prefix(20))...")
                SharedLogger.log("Push token: \(token.prefix(20))...", source: "APP")
            } else {
                logger.warning("⚠️ Push token timeout — server fallback unavailable")
            }
            return result
        }
    }
}

// MARK: - Preview Stub

struct PreviewLiveActivityService: LiveActivityServicing {
    func startActivity(sessionID: String, durationMinutes: Int, timerEndDate: Date) async -> String? { nil }
    func updateActivity(remainingSeconds: Int, elapsedSeconds: Int, totalSeconds: Int, state: LiveTimerState, timerEndDate: Date?) async {}
    func endActivity() async {}
}
