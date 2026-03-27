import ActivityKit
import Foundation

struct GlassTimeAttributes: ActivityAttributes {
    // Static: set once at session start, never changes
    let sessionID: String
    let totalDurationMinutes: Int
    let startedAt: Date

    struct ContentState: Codable, Hashable {
        let remainingSeconds: Int
        let elapsedSeconds: Int
        let totalDurationSeconds: Int
        let timerState: LiveTimerState
        /// Fixed start of the timer range. Captured once in the app — never use Date() in the widget.
        /// Using Date() in the widget causes "fast seconds" due to IPC delay between app and widget process.
        let timerStartDate: Date?
        /// When the timer will reach 0:00.
        let timerEndDate: Date?

        var progress: Double {
            guard totalDurationSeconds > 0 else { return 0 }
            return Double(elapsedSeconds) / Double(totalDurationSeconds)
        }

        var remainingFormatted: String {
            let minutes = remainingSeconds / 60
            let seconds = remainingSeconds % 60
            return String(format: "%d:%02d", minutes, seconds)
        }

        var filledBlockCount12: Int {
            min(12, Int((progress * 12).rounded()))
        }

        var filledBlockCount8: Int {
            min(8, Int((progress * 8).rounded()))
        }
    }
}
