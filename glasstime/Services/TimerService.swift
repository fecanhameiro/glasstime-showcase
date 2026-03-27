import Foundation

protocol TimerServicing: Sendable {
    func start(durationSeconds: Int, fromElapsed: Int) -> AsyncStream<Int>
}

final class TimerService: TimerServicing {

    func start(durationSeconds: Int, fromElapsed: Int) -> AsyncStream<Int> {
        AsyncStream { continuation in
            let task = Task {
                let clock = ContinuousClock()
                let startInstant = clock.now
                var tickCount = 0

                while fromElapsed + tickCount < durationSeconds {
                    tickCount += 1
                    try? await clock.sleep(until: startInstant + .seconds(tickCount))
                    guard !Task.isCancelled else { break }

                    let elapsed = min(fromElapsed + tickCount, durationSeconds)
                    continuation.yield(elapsed)

                    if elapsed >= durationSeconds { break }
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

// MARK: - Debug Timer (10x speed)

final class DebugTimerService: TimerServicing {

    func start(durationSeconds: Int, fromElapsed: Int) -> AsyncStream<Int> {
        AsyncStream { continuation in
            let task = Task {
                let clock = ContinuousClock()
                let startInstant = clock.now
                var tickCount = 0

                while fromElapsed + tickCount < durationSeconds {
                    tickCount += 1
                    // 25ms per "second" = 40x speed
                    try? await clock.sleep(until: startInstant + .milliseconds(tickCount * 25))
                    guard !Task.isCancelled else { break }

                    let elapsed = min(fromElapsed + tickCount, durationSeconds)
                    continuation.yield(elapsed)

                    if elapsed >= durationSeconds { break }
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
