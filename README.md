# GlassTime

Focus timer for iOS 26+ with server-driven accuracy.

> This is a curated architecture showcase. Selected files from an active project demonstrating the server-driven timer pattern.

<p align="center">
  <img src="screenshots/glasstime-timer.gif" width="350" />
</p>

## What Makes This Different

Most timer apps use local countdown timers that drift when the app is backgrounded or killed. GlassTime uses a server-driven approach: Firebase Cloud Functions schedule a Cloud Task, which sends an APNs push to complete the Live Activity at the exact end time, even if the app has been terminated.

## How the Server Timer Works

```
1. User starts timer
2. App calls Firebase Cloud Function (scheduleTimerEnd)
3. Cloud Function enqueues a Cloud Task for timer.endTime
4. App shows Live Activity with local countdown
5. At endTime, Cloud Task fires → sends APNs push → Live Activity completes
```

This works even if the app is killed, the phone is locked, or the user is in another app. The Cloud Task guarantees delivery with retry logic (3 attempts, 10s backoff).

### Cancellation and Rescheduling

If the user pauses or cancels, a second callable function (`cancelTimerEnd`) deletes the Cloud Task. If a task with the same session ID already exists, the scheduler handles `ALREADY_EXISTS` by deleting and re-enqueuing.

### Wall-Clock Accuracy

The iOS side tracks elapsed time using wall-clock dates (`sessionStartDate` + `accumulatedBeforePause`), not a ticking counter. On foreground return, elapsed time is recalculated from the clock. No drift.

## Architecture

```
glasstime/
├── Services/
│   ├── ServerTimerService.swift      # iOS → Cloud Functions callable
│   ├── LiveActivityService.swift     # ActivityKit lifecycle
│   ├── TimerService.swift            # Local tick via Timer.publish
│   ├── TimerCompletionNotifier.swift # Completion handling
│   └── AppServices.swift             # Protocol-based DI container
├── ViewModels/
│   └── TimerViewModel.swift          # Orchestration, state machine
├── Models/
│   └── TimerState.swift              # idle, running, paused, completed
├── Views/
│   ├── FocusSessionView.swift        # Main interface
│   └── Components/
│       ├── AuroraBackgroundView.swift # Animated gradient background
│       ├── GlassBlocksView.swift     # Full-screen glass block grid
│       ├── GlassBlockView.swift      # Individual animated block
│       ├── NucleusRingView.swift     # Center timer display
│       └── BottomControlsView.swift  # Duration picker + controls
├── Domain/
│   └── GlassBlockLayout.swift        # Responsive block grid layout
├── Extensions/                       # Design system (colors, fonts, spacing)
└── Shared/                           # Live Activity attributes

functions/                            # Firebase Cloud Functions (Node.js)
├── index.js                          # scheduleTimerEnd, cancelTimerEnd, sendTimerEndPush
└── src/apns.js                       # APNs HTTP/2 push with JWT auth
```

## Key Architecture Decisions

**Why server-driven instead of local notifications?**
Local `UNNotificationRequest` with a time interval fires reliably only when the app is alive. If the user force-quits, the notification may not fire. Cloud Tasks guarantee delivery because the trigger lives on the server, not the device. The trade-off is network dependency, but for a timer that already requires a Live Activity, connectivity is assumed.

**Why Cloud Tasks instead of a simple setTimeout?**
Cloud Functions have a maximum execution time (540s for v2). A 25-minute timer can't wait inside a function. Cloud Tasks schedule a future invocation at the exact end time with built-in retry logic (3 attempts, 10s exponential backoff). If the first push fails, it automatically retries.

**Why APNs HTTP/2 directly instead of FCM?**
Live Activities can only be updated or ended via ActivityKit push notifications, which require APNs directly. FCM doesn't support the `liveactivity` push type. The implementation uses JWT (ES256) authentication with token caching (refreshed every 20 minutes per Apple's recommendation).

**Why wall-clock elapsed time?**
A `Timer.publish` counter drifts when the app is suspended. Instead, the ViewModel stores `sessionStartDate` and `accumulatedBeforePause`. Elapsed time is always `now - sessionStartDate + accumulated`. On foreground return, the display catches up instantly. Zero drift, even after hours in background.

## Design

- **Liquid Glass.** `.glassEffect()` on controls and timer display (iOS 26).
- **Aurora background.** Animated gradient with grain texture overlay.
- **Glass blocks.** Full-screen grid that fills as the timer progresses.
- **Spring animations.** `.spring(.smooth)` for transitions, `.spring(.bouncy)` for feedback.

## Tech Stack

| | |
|-|-|
| **iOS** | SwiftUI, @Observable, ActivityKit, Live Activities |
| **Backend** | Firebase Cloud Functions (Node.js), Google Cloud Tasks |
| **Push** | APNs HTTP/2 with JWT authentication (ES256) |
| **Minimum** | iOS 26+ |

## Setup

**iOS:**
1. Clone the repository
2. Add your `GoogleService-Info.plist` to `glasstime/`
3. Open in Xcode 26+

**Cloud Functions:**
1. Configure APNs credentials via Firebase Secret Manager or Cloud Functions environment variables (`APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_AUTH_KEY`, `APNS_PRODUCTION`)
2. In `functions/src/apns.js`, replace the `BUNDLE_ID` constant with your app's bundle ID
3. Deploy with `firebase deploy --only functions`

## Notes

Firebase credentials and APNs keys are managed via Secret Manager and not included in the repository.

---

Built by [Felipe Canhameiro](https://github.com/fecanhameiro) at [Prism Labs](https://prismlabs.studio).
