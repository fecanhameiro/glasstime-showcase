import UserNotifications
import ActivityKit
import os

/// Schedules a local notification for when the timer ends.
/// When fired in background, updates the Live Activity to completed state.
@MainActor
enum TimerCompletionNotifier {
    static let notificationID = "com.glasstime.timer-completion"
    private static let logger = Logger(subsystem: "com.prismlabs.glasstime", category: "Completion")

    /// Schedule a notification at the timer's end date
    static func schedule(at endDate: Date, sessionID: String) {
        let content = UNMutableNotificationContent()
        content.title = "Focus Complete"
        content.body = "Great work! Your focus session is done."
        content.sound = .default
        content.userInfo = ["sessionID": sessionID]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, endDate.timeIntervalSinceNow),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: notificationID,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                logger.error("Failed to schedule completion notification: \(error.localizedDescription)")
            } else {
                logger.info("📅 Completion notification scheduled at \(endDate)")
            }
        }
    }

    /// Cancel any pending completion notification (on pause, cancel, or manual completion)
    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationID]
        )
    }

    /// Update Live Activity to completed state (called when notification fires in background)
    static func completeActivity() async {
        for activity in Activity<GlassTimeAttributes>.activities {
            let finalState = GlassTimeAttributes.ContentState(
                remainingSeconds: 0,
                elapsedSeconds: 0,
                totalDurationSeconds: 0,
                timerState: .completed,
                timerStartDate: nil,
                timerEndDate: nil
            )
            let content = ActivityContent(state: finalState, staleDate: nil)
            await activity.update(content)
        }
    }
}
