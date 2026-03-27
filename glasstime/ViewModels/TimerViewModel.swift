import SwiftUI
import UserNotifications
import os.log

private let logger = Logger(subsystem: "com.glasstime", category: "Timer")

private func memoryUsageMB() -> String {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    if result == KERN_SUCCESS {
        let mb = Double(info.resident_size) / 1_048_576
        return String(format: "%.1fMB", mb)
    }
    return "?MB"
}

@MainActor @Observable
final class TimerViewModel {
    @ObservationIgnored private let services: AppServices
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var dismissTask: Task<Void, Never>?
    @ObservationIgnored private var laStartTask: Task<Void, Never>?
    @ObservationIgnored private var sessionID: UUID = UUID()
    @ObservationIgnored private var reportedMilestones: Set<Int> = []

    private var sessionIDString: String { sessionID.uuidString }

    // Wall-clock tracking for accurate background/foreground transitions
    @ObservationIgnored private var sessionStartDate: Date?
    @ObservationIgnored private var accumulatedBeforePause: Int = 0

    /// Fixed end date for the Live Activity timer — calculated once, reused on all updates.
    @ObservationIgnored private var liveActivityEndDate: Date?
    /// Push token from the current Live Activity — needed for server timer scheduling.
    @ObservationIgnored private var liveActivityPushToken: String?

    // MARK: - State

    var timerState: TimerState = .idle
    var selectedDurationMinutes: Int = 25
    var elapsedSeconds: Int = 0
    var blocks: [GlassBlock] = []

    // MARK: - Derived

    var totalDurationSeconds: Int {
        #if DEBUG
        return selectedDurationMinutes // in debug, "minutes" are actually seconds
        #else
        return selectedDurationMinutes * 60
        #endif
    }

    var progress: Double {
        guard totalDurationSeconds > 0 else { return 0 }
        return Double(elapsedSeconds) / Double(totalDurationSeconds)
    }

    var remainingSeconds: Int {
        max(0, totalDurationSeconds - elapsedSeconds)
    }

    var remainingFormatted: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var ringLabel: String {
        switch timerState {
        case .idle: return String(localized: "timer.start")
        case .running: return String(localized: "timer.focus")
        case .paused: return String(localized: "timer.resume")
        case .completed: return String(localized: "timer.done")
        case .dismissing: return ""
        }
    }

    var ringTimeDisplay: String {
        switch timerState {
        case .idle:
            #if DEBUG
            let m = selectedDurationMinutes / 60
            let s = selectedDurationMinutes % 60
            return String(format: "%d:%02d", m, s)
            #else
            return String(format: "%d:00", selectedDurationMinutes)
            #endif
        case .running, .paused, .dismissing:
            return remainingFormatted
        case .completed:
            return ""
        }
    }

    // MARK: - Init

    init(services: AppServices) {
        self.services = services
    }

    // MARK: - Actions

    func selectDuration(_ minutes: Int) {
        guard minutes != selectedDurationMinutes else { return }
        selectedDurationMinutes = minutes
        services.analytics.track(.durationSelected(minutes: minutes))
    }

    func primaryAction() {
        switch timerState {
        case .idle:
            startSession()
        case .running:
            pauseSession()
        case .paused:
            resumeSession()
        case .completed:
            dismissCompletion()
        case .dismissing:
            break // animation in progress, ignore taps
        }
    }

    func endSession() {
        guard timerState != .idle && timerState != .dismissing else { return }

        if timerState == .running || timerState == .paused {
            services.analytics.track(.sessionAbandoned(
                sessionID: sessionIDString,
                durationMinutes: selectedDurationMinutes,
                elapsedSeconds: elapsedSeconds
            ))
        }

        timerTask?.cancel()
        timerTask = nil
        dismissTask?.cancel()
        dismissTask = nil
        laStartTask?.cancel()
        laStartTask = nil
        sessionStartDate = nil
        accumulatedBeforePause = 0
        TimerCompletionNotifier.cancel()

        // End Live Activity + cancel server task
        let sid = sessionIDString
        Task {
            await services.liveActivity.endActivity()
            await services.serverTimer.cancelEnd(sessionID: sid)
        }

        // Dissolve blocks + rewind timer back to full duration
        let startElapsed = elapsedSeconds
        let totalDuration = totalDurationSeconds

        logger.info("⏪ Dismiss: startElapsed=\(startElapsed), totalDuration=\(totalDuration), remaining=\(totalDuration - startElapsed)s")


        withAnimation(.spring(.smooth(duration: 0.6))) {
            timerState = .dismissing
        }

        dismissTask = Task { @MainActor in
            guard startElapsed > 0 else {

                logger.info("⏪ No elapsed time, skipping rewind")
                try? await Task.sleep(for: .seconds(1.8))
                guard timerState == .dismissing else { return }
                withAnimation(.spring(.smooth(duration: 0.5))) {
                    timerState = .idle
                    elapsedSeconds = 0
                    blocks = []
                }
                return
            }

            // Rewind: elapsed goes from current → 0 in visible steps
            // Each step reduces elapsed, so remaining climbs back to full duration
            let totalSteps = 20
            let intervalMs = 75
            let secondsPerStep = max(1, startElapsed / totalSteps)

            logger.info("⏪ Rewind: \(totalSteps) steps, \(secondsPerStep)s/step, \(intervalMs)ms interval")


            var current = startElapsed
            for step in 1...totalSteps {
                guard timerState == .dismissing else {
                    logger.info("⏪ Rewind interrupted at step \(step)")
                    return
                }
                try? await Task.sleep(for: .milliseconds(intervalMs))
                current = max(0, current - secondsPerStep)
                elapsedSeconds = current
                let remaining = totalDuration - current

                logger.info("⏪ Step \(step): elapsed=\(current), remaining=\(remaining) (\(remaining/60):\(String(format: "%02d", remaining%60)))")
                if current == 0 { break }
            }

            elapsedSeconds = 0

            logger.info("⏪ Rewind complete: elapsed=\(self.elapsedSeconds), display=\(self.ringTimeDisplay)")

            // Brief pause at full duration before transitioning to idle
            try? await Task.sleep(for: .milliseconds(400))
            guard timerState == .dismissing else { return }
            withAnimation(.spring(.smooth(duration: 0.5))) {
                timerState = .idle
                blocks = []
            }
            logger.info("⏪ Transitioned to idle")
        }
    }

    // MARK: - Background / Foreground

    func handleEnteredBackground() {
        print("⏸️ BG ENTER: timerState=\(timerState), elapsed=\(elapsedSeconds), sessionStartDate=\(String(describing: sessionStartDate))")
        guard timerState == .running else {
            print("⏸️ BG SKIP: not running (state=\(timerState))")
            return
        }

        timerTask?.cancel()
        timerTask = nil

        // Snapshot current elapsed and mark background entry time
        accumulatedBeforePause = elapsedSeconds
        sessionStartDate = Date() // reset: "when did we enter background"

        logger.info("⏸️ Background: elapsed=\(self.elapsedSeconds)/\(self.totalDurationSeconds), remaining=\(self.remainingSeconds)s")
        print("⏸️ BG SNAPSHOT: accumulated=\(accumulatedBeforePause), sessionStartDate=\(sessionStartDate!)")

        // Don't update LA on background — it already has the correct timerInterval/endDate.
        // Sending an update causes the system to re-evaluate Text(timerInterval:) and
        // ProgressView(timerInterval:), which can show a visible "fast seconds" glitch.
    }

    func handleReturnToForeground() {
        print("▶️ FG ENTER: timerState=\(timerState), elapsed=\(elapsedSeconds), sessionStartDate=\(String(describing: sessionStartDate)), accumulated=\(accumulatedBeforePause)")
        guard timerState == .running, let backgroundDate = sessionStartDate else {
            print("▶️ FG SKIP: state=\(timerState), sessionStartDate=\(String(describing: sessionStartDate))")
            return
        }

        timerTask?.cancel()
        timerTask = nil

        // Real wall-clock time passed while in background
        let backgroundSeconds = Int(Date().timeIntervalSince(backgroundDate))
        let realElapsed = min(accumulatedBeforePause + backgroundSeconds, totalDurationSeconds)

        logger.info("▶️ Foreground: was \(self.elapsedSeconds)s, accumulated=\(self.accumulatedBeforePause)s, bgTime=\(backgroundSeconds)s, now \(realElapsed)s, mem=\(memoryUsageMB())")

        #if DEBUG
        let widgetLogs = SharedLogger.readAll()
        if widgetLogs != "(no logs)" && !widgetLogs.isEmpty {
            print("📋 === WIDGET LOGS (during background) ===")
            print(widgetLogs)
            print("📋 === END ===")
            SharedLogger.clear()
        }
        #endif

        elapsedSeconds = realElapsed
        sessionStartDate = Date() // reset for current running segment

        if realElapsed >= totalDurationSeconds {
            logger.info("✅ Session completed while backgrounded")
            completeSession()
        } else {
            // Don't update LA on foreground return — the endDate hasn't changed
            // and re-sending causes the timer to "re-sync" with visible fast seconds.
            // The LA is already showing the correct countdown from the original endDate.
            startTimer(fromElapsed: realElapsed)
        }
    }

    // MARK: - Private

    private func startSession() {
        sessionID = UUID()
        elapsedSeconds = 0
        reportedMilestones = []
        accumulatedBeforePause = 0
        sessionStartDate = Date()

        // Cancel any lingering dismiss task from previous session
        dismissTask?.cancel()
        dismissTask = nil

        services.analytics.track(.sessionStarted(sessionID: sessionIDString, durationMinutes: selectedDurationMinutes))
        services.analytics.setUserProperty("\(selectedDurationMinutes)", forName: "preferred_duration")

        logger.info("🟢 Session started: \(self.selectedDurationMinutes)min, id=\(self.sessionIDString), mem=\(memoryUsageMB())")

        withAnimation(.spring(.smooth(duration: 0.6))) {
            timerState = .running
        }

        // Live Activity — calculate end date ONCE, reuse everywhere
        liveActivityEndDate = Date().addingTimeInterval(TimeInterval(totalDurationSeconds))
        let endDate = liveActivityEndDate!
        let sid = sessionIDString
        let dur = selectedDurationMinutes
        laStartTask?.cancel()
        laStartTask = Task {
            let token = await services.liveActivity.startActivity(
                sessionID: sid,
                durationMinutes: dur,
                timerEndDate: endDate
            )
            // Check if local notifications are authorized
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            let notificationsAuthorized = settings.authorizationStatus == .authorized

            // Schedule server push to end LA in background
            // shouldEndActivity: true = LA disappears (notification handles user alert)
            // shouldEndActivity: false = LA shows "Done" (LA IS the notification)
            if let token {
                liveActivityPushToken = token
                await services.serverTimer.scheduleEnd(
                    pushToken: token,
                    endDate: endDate,
                    sessionID: sid,
                    shouldEndActivity: notificationsAuthorized
                )
            }
        }

        // Schedule local notification as fallback
        TimerCompletionNotifier.schedule(at: endDate, sessionID: sid)

        startTimer(fromElapsed: 0)
    }

    private func pauseSession() {
        timerTask?.cancel()
        timerTask = nil
        TimerCompletionNotifier.cancel()

        // Calculate remaining from liveActivityEndDate (single source of truth)
        // This avoids drift from timer stream being 0-1s behind wall-clock
        if let endDate = liveActivityEndDate {
            let preciseRemaining = max(0, Int(endDate.timeIntervalSinceNow))
            elapsedSeconds = totalDurationSeconds - preciseRemaining
        }

        // Update accumulated for background/foreground tracking
        accumulatedBeforePause = elapsedSeconds
        sessionStartDate = nil

        services.analytics.track(.sessionPaused(
            sessionID: sessionIDString,
            durationMinutes: selectedDurationMinutes,
            elapsedSeconds: elapsedSeconds
        ))

        withAnimation(.spring(.smooth(duration: 0.5))) {
            timerState = .paused
        }

        // Live Activity — no endDate when paused
        let remaining = remainingSeconds
        let elapsed = elapsedSeconds
        let sid = sessionIDString
        Task {
            await services.liveActivity.updateActivity(
                remainingSeconds: remaining,
                elapsedSeconds: elapsed,
                totalSeconds: totalDurationSeconds,
                state: .paused,
                timerEndDate: nil
            )
            // Cancel server task
            await services.serverTimer.cancelEnd(sessionID: sid)
        }
    }

    private func resumeSession() {
        sessionStartDate = Date()

        // Recalculate endDate from current remaining (precise, from last pause)
        liveActivityEndDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))

        // Reschedule completion notification
        TimerCompletionNotifier.schedule(at: liveActivityEndDate!, sessionID: sessionIDString)

        services.analytics.track(.sessionResumed(
            sessionID: sessionIDString,
            durationMinutes: selectedDurationMinutes,
            elapsedSeconds: elapsedSeconds
        ))

        withAnimation(.spring(.smooth(duration: 0.5))) {
            timerState = .running
        }

        // Live Activity — use recalculated endDate
        let endDate = liveActivityEndDate
        let sid = sessionIDString
        let token = liveActivityPushToken
        Task {
            await services.liveActivity.updateActivity(
                remainingSeconds: remainingSeconds,
                elapsedSeconds: elapsedSeconds,
                totalSeconds: totalDurationSeconds,
                state: .running,
                timerEndDate: endDate
            )
            // Reschedule server task with new endDate
            if let token, let endDate {
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                let notifAuth = settings.authorizationStatus == .authorized
                await services.serverTimer.scheduleEnd(
                    pushToken: token,
                    endDate: endDate,
                    sessionID: sid,
                    shouldEndActivity: notifAuth
                )
            }
        }

        startTimer(fromElapsed: elapsedSeconds)
    }

    private func dismissCompletion() {
        services.analytics.track(.sessionDismissed(sessionID: sessionIDString, durationMinutes: selectedDurationMinutes))
        sessionStartDate = nil
        accumulatedBeforePause = 0

        // End Live Activity + cancel server task
        let sid = sessionIDString
        Task {
            await services.liveActivity.endActivity()
            await services.serverTimer.cancelEnd(sessionID: sid)
        }

        // For completion, elapsed == totalDuration, so rewind from full back to 0
        let startElapsed = elapsedSeconds
        let totalDuration = totalDurationSeconds

        logger.info("⏪ Dismiss completion: elapsed=\(startElapsed), total=\(totalDuration)")

        withAnimation(.spring(.smooth(duration: 0.6))) {
            timerState = .dismissing
        }

        dismissTask = Task { @MainActor in
            // Rewind timer from complete back to full duration display
            if startElapsed > 0 {
                let totalSteps = 20
                let intervalMs = 75
                let secondsPerStep = max(1, startElapsed / totalSteps)



                var current = startElapsed
                for _ in 1...totalSteps {
                    guard timerState == .dismissing else { return }
                    try? await Task.sleep(for: .milliseconds(intervalMs))
                    current = max(0, current - secondsPerStep)
                    elapsedSeconds = current
                    if current == 0 { break }
                }
                elapsedSeconds = 0
            }


            try? await Task.sleep(for: .milliseconds(400))
            guard timerState == .dismissing else { return }
            withAnimation(.spring(.smooth(duration: 0.5))) {
                timerState = .idle
                blocks = []
            }
        }
    }

    private func startTimer(fromElapsed: Int) {
        let stream = services.timer.start(
            durationSeconds: totalDurationSeconds,
            fromElapsed: fromElapsed
        )

        timerTask = Task {
            for await elapsed in stream {
                guard !Task.isCancelled else { break }

                self.elapsedSeconds = elapsed

                // Track progress milestones
                let percentComplete = Int((Double(elapsed) / Double(totalDurationSeconds)) * 100)
                for milestone in [25, 50, 75] {
                    if percentComplete >= milestone && !reportedMilestones.contains(milestone) {
                        reportedMilestones.insert(milestone)
                        logger.info("📊 \(milestone)% — mem=\(memoryUsageMB()), blocks=\(self.blocks.count)")
                        services.analytics.track(.progressMilestone(
                            sessionID: sessionIDString,
                            percent: milestone,
                            durationMinutes: selectedDurationMinutes
                        ))
                    }
                }

                if elapsed >= totalDurationSeconds {
                    completeSession()
                    break
                }
            }
        }
    }

    private func completeSession() {
        guard timerState != .completed else { return }
        timerTask?.cancel()
        timerTask = nil
        sessionStartDate = nil

        logger.info("🏆 Session completed: \(self.selectedDurationMinutes)min, mem=\(memoryUsageMB())")
        TimerCompletionNotifier.cancel()
        services.sound.playCompletion()
        services.analytics.track(.sessionCompleted(sessionID: sessionIDString, durationMinutes: selectedDurationMinutes))

        let count = UserDefaults.standard.integer(forKey: "totalSessionsCompleted") + 1
        UserDefaults.standard.set(count, forKey: "totalSessionsCompleted")
        services.analytics.setUserProperty("\(count)", forName: "total_sessions_completed")

        withAnimation(.spring(.smooth(duration: 0.6))) {
            timerState = .completed
        }

        // End Live Activity immediately.
        // The local notification tells the user the session is done.
        // While app is in background, the LA stays stale (dimmed by system) until
        // the user returns to the app — this is an iOS limitation for third-party apps.
        liveActivityEndDate = nil
        let sid = sessionIDString
        Task {
            await services.liveActivity.endActivity()
            await services.serverTimer.cancelEnd(sessionID: sid)
        }
    }

    // MARK: - Analytics

    func trackAppOpened() {
        services.analytics.track(.appOpened)

        #if DEBUG
        // Dump shared logs from widget on app launch
        let logs = SharedLogger.readAll()
        if logs != "(no logs)" && !logs.isEmpty {
            print("📋 === SHARED LOGS (app + widget) ===")
            print(logs)
            print("📋 === END SHARED LOGS ===")
            SharedLogger.clear()
        }
        #endif
    }

    func trackAppBackgrounded() {
        services.analytics.track(.appBackgrounded)
    }

    // MARK: - Intent Actions (from Live Activity controls)

    func pauseFromIntent() {
        guard timerState == .running else { return }
        pauseSession()
    }

    func resumeFromIntent() {
        guard timerState == .paused else { return }
        resumeSession()
    }

    func endFromIntent() {
        endSession()
    }

    func dismissFromIntent() {
        guard timerState == .completed else { return }
        dismissCompletion()
    }

    // MARK: - Layout

    func generateBlocks(for containerSize: CGSize, blockArea: CGRect) {
        guard blocks.isEmpty else { return }
        let seedValue = sessionID.uuid
        let seed = UInt64(seedValue.0) &+ UInt64(seedValue.1) << 8 &+ UInt64(seedValue.2) << 16

        blocks = GlassBlockLayoutEngine.generateLayout(
            containerSize: containerSize,
            blockArea: blockArea,
            seed: seed
        )
    }
}
