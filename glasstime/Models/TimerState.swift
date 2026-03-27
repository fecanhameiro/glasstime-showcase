import Foundation

enum TimerState: Equatable {
    case idle
    case running
    case paused
    case completed
    case dismissing
}
