import Foundation

enum LiveTimerState: String, Codable, Hashable, Sendable {
    case running
    case paused
    case completed
}
