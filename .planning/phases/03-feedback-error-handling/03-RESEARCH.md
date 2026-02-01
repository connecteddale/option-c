# Phase 3: Feedback & Error Handling - Research

**Researched:** 2026-02-01
**Domain:** User feedback, error handling, and permission management in macOS apps
**Confidence:** HIGH

## Summary

Phase 3 focuses on completing the user experience loop by providing clear feedback on success/failure and handling permission issues gracefully. Research reveals well-established patterns in modern Swift for notification delivery, error state management, and permission handling. The key architectural decision is to use enum-based state machines for tracking idle/success/error states, SwiftUI's @MainActor for thread-safe state updates, and UNUserNotificationCenter for system notifications.

The modern Swift approach (2026) emphasizes graceful degradation over crashes, user-friendly error messages with actionable guidance, and proactive permission checks rather than reactive error handling. For menu bar apps specifically, state must return to idle after any completion (success or failure) to enable the next recording cycle. Permission denial should provide clear paths to System Settings with helpful context rather than generic error messages.

**Primary recommendation:** Implement enum-based AppState with idle/recording/processing/success/error cases, use Result<String, AppError> for operation outcomes, and leverage LocalizedError protocol for user-facing messages. Combine with UNUserNotificationCenter for completion feedback and defensive permission checks before each operation.

## Standard Stack

The established libraries/frameworks for feedback and error handling in macOS apps:

### Core

| Framework | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| UserNotifications | Built-in (macOS 10.14+) | System notifications for success/error | Modern framework replacing deprecated NSUserNotification, consistent API across platforms |
| Swift Error Handling | Built-in (Swift 5+) | try/catch, Result type, LocalizedError | Native language feature, compile-time safety, graceful degradation patterns |
| AVFoundation Authorization | Built-in | Microphone permission management | Standard API for audio capture permissions, consistent with iOS |
| Speech Authorization | Built-in (macOS 10.15+) | Speech recognition permission | Standard API for SFSpeechRecognizer, handles all authorization states |

### Supporting

| Framework | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| Swift Concurrency | Swift 6.1+ | Async/await timeout patterns | For implementing 30s timeout with Task.sleep and withThrowingTaskGroup |
| @MainActor | Swift 6.1+ | Thread-safe UI updates | Ensures state changes trigger UI updates on main thread |
| Combine | Built-in | Alternative state management | If not using Swift Concurrency, though async/await is recommended for 2026 |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| UNUserNotificationCenter | NSUserNotification (deprecated) | NSUserNotification deprecated in macOS 11, lacks modern features |
| LocalizedError | Custom error strings | LocalizedError provides structured localization support and user-friendly descriptions |
| Swift async/await timeouts | GCD DispatchWorkItem | GCD approach requires more boilerplate, harder to reason about cancellation |
| @MainActor | DispatchQueue.main | @MainActor provides compile-time safety, async/await integration |

**Installation:**

All frameworks are built-in to macOS SDK. No external dependencies required.

## Architecture Patterns

### Recommended State Management Structure

```swift
// State enum with all possible app states
enum AppState {
    case idle
    case recording(startTime: Date)
    case processing(startTime: Date)
    case success(transcription: String)
    case error(AppError)
}

// Centralized state coordinator
@MainActor
class StateCoordinator: ObservableObject {
    @Published var currentState: AppState = .idle

    // Automatically return to idle after showing success/error
    func transitionToSuccess(transcription: String) {
        currentState = .success(transcription: transcription)

        Task {
            try? await Task.sleep(for: .seconds(2))
            currentState = .idle
        }
    }

    func transitionToError(_ error: AppError) {
        currentState = .error(error)

        Task {
            try? await Task.sleep(for: .seconds(3))
            currentState = .idle
        }
    }
}
```

**Why this pattern:**
- Single source of truth for app state
- Automatic state cleanup prevents getting stuck in error states
- SwiftUI views reactively update based on state changes
- Clear separation between transient states (success/error) and stable states (idle/recording)

### Pattern 1: Error Type Hierarchy with LocalizedError

**What:** Custom error enum conforming to LocalizedError for user-friendly messages

**When to use:** All error scenarios that need user-facing feedback

**Example:**
```swift
// Source: Swift error handling best practices (multiple sources)
enum AppError: LocalizedError {
    case microphonePermissionDenied
    case speechRecognitionPermissionDenied
    case noSpeechDetected
    case transcriptionTimeout
    case recordingFailed(underlying: Error)
    case clipboardWriteFailed

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access required"
        case .speechRecognitionPermissionDenied:
            return "Speech recognition access required"
        case .noSpeechDetected:
            return "No speech detected"
        case .transcriptionTimeout:
            return "Transcription took too long"
        case .recordingFailed:
            return "Recording failed"
        case .clipboardWriteFailed:
            return "Failed to copy to clipboard"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Enable microphone access in System Settings > Privacy & Security > Microphone"
        case .speechRecognitionPermissionDenied:
            return "Enable speech recognition in System Settings > Privacy & Security > Speech Recognition"
        case .noSpeechDetected:
            return "Try speaking more clearly or check your microphone"
        case .transcriptionTimeout:
            return "Recording may have been too long. Try a shorter recording."
        case .recordingFailed(let error):
            return "Error: \(error.localizedDescription)"
        case .clipboardWriteFailed:
            return "Please try the recording again"
        }
    }
}
```

**Why:** LocalizedError provides structured user-facing messages, supports localization, and integrates with Swift error handling

### Pattern 2: Permission Checking with Result Type

**What:** Defensive permission checks before operations using Result type

**When to use:** Before starting recording or transcription

**Example:**
```swift
// Source: Swift permission handling patterns (multiple sources)
@MainActor
class PermissionManager {
    enum PermissionStatus {
        case granted
        case denied
        case notDetermined
        case restricted
    }

    func checkMicrophonePermission() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }

    func requestMicrophonePermission() async -> Result<Void, AppError> {
        let status = checkMicrophonePermission()

        switch status {
        case .granted:
            return .success(())
        case .denied, .restricted:
            return .failure(.microphonePermissionDenied)
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            return granted ? .success(()) : .failure(.microphonePermissionDenied)
        }
    }

    func checkSpeechRecognitionPermission() -> PermissionStatus {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }

    func requestSpeechRecognitionPermission() async -> Result<Void, AppError> {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                switch status {
                case .authorized:
                    continuation.resume(returning: .success(()))
                case .denied, .restricted, .notDetermined:
                    continuation.resume(returning: .failure(.speechRecognitionPermissionDenied))
                @unknown default:
                    continuation.resume(returning: .failure(.speechRecognitionPermissionDenied))
                }
            }
        }
    }
}
```

**Why:** Check-before-use prevents runtime failures, Result type makes success/failure explicit, async/await integrates with Swift Concurrency

### Pattern 3: UNUserNotificationCenter for Success/Error Feedback

**What:** System notifications for async operation completion

**When to use:** Transcription ready, errors, timeouts

**Example:**
```swift
// Source: UNUserNotificationCenter tutorials (Hacking with Swift, Apps Developer Blog)
@MainActor
class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func showSuccess(transcription: String) {
        let content = UNMutableNotificationContent()
        content.title = "Transcription Ready"
        content.body = String(transcription.prefix(100)) + (transcription.count > 100 ? "..." : "")
        content.subtitle = "Copied to clipboard"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }

    func showError(_ error: AppError) {
        let content = UNMutableNotificationContent()
        content.title = error.errorDescription ?? "Error"
        content.body = error.recoverySuggestion ?? "Please try again"
        content.sound = .defaultCritical

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func showTimeout() {
        let content = UNMutableNotificationContent()
        content.title = "No Speech Detected"
        content.body = "Recording timed out after 30 seconds. Please try again."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
```

**Why:** UNUserNotificationCenter is modern API, works with menu bar apps, supports rich content and sounds

### Pattern 4: Timeout with Swift Concurrency

**What:** Race async operation against 30-second timeout

**When to use:** Transcription processing, any long-running operation

**Example:**
```swift
// Source: Swift Forums, Donny Wals timeout tutorial
func withTimeout<T>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Add timeout task
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw AppError.transcriptionTimeout
        }

        // Add actual operation
        group.addTask {
            try await operation()
        }

        // Wait for first to complete
        let result = try await group.next()!

        // Cancel remaining tasks
        group.cancelAll()

        return result
    }
}

// Usage:
do {
    let transcription = try await withTimeout(seconds: 30) {
        await transcriptionEngine.transcribe(audioURL: url)
    }
    coordinator.transitionToSuccess(transcription: transcription)
} catch AppError.transcriptionTimeout {
    coordinator.transitionToError(.noSpeechDetected)
} catch {
    coordinator.transitionToError(.recordingFailed(underlying: error))
}
```

**Why:** Clean cancellation semantics, first-to-complete wins, integrates naturally with async/await

### Anti-Patterns to Avoid

- **Generic "Something went wrong" messages:** Users can't take action. Always provide specific error and recovery steps.
- **Staying in error state indefinitely:** App appears broken. Always return to idle after showing error.
- **Silent failures:** User doesn't know what happened. Always show notification for async completions.
- **Requesting permissions after failure:** Ask proactively before starting operation, not reactively after failure.
- **Blocking main thread for permission requests:** Use async/await to keep UI responsive.
- **Using try! for permission checks:** App crashes on denial. Always use try/try? or Result type.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Timeout mechanism | Custom Timer + cancellation logic | withThrowingTaskGroup + Task.sleep | Built-in cancellation, cleaner semantics, no manual cleanup |
| Error localization | String interpolation with if/else | LocalizedError protocol | Structured localization support, consistent with Apple frameworks |
| Permission state tracking | Manual boolean flags | AVCaptureDevice.authorizationStatus / SFSpeechRecognizer.authorizationStatus | Single source of truth, handles restricted/denied/notDetermined states |
| Notification delivery | Custom UI overlays | UNUserNotificationCenter | System integration, respects user preferences, handles Focus modes |
| State transitions | Boolean flags (isRecording, isProcessing, hasError) | Single AppState enum | Prevents invalid states, makes transitions explicit |

**Key insight:** Swift and Apple frameworks provide robust primitives for async operations, error handling, and user feedback. Custom solutions introduce bugs around edge cases (permission changes while app running, timeout cancellation failures, notification delivery timing).

## Common Pitfalls

### Pitfall 1: Not Returning to Idle State

**What goes wrong:** After showing success or error notification, app stays in that state. Next hotkey press doesn't work or causes unexpected behavior.

**Why it happens:** Developer focuses on showing notification but forgets to transition state back to idle. SwiftUI view continues showing success/error indicator.

**Consequences:**
- User presses Option-C again and nothing happens
- Menu bar shows stale state (still shows "Success" from 5 minutes ago)
- App appears frozen or broken
- State machine stuck, requires app restart

**Prevention:**
1. Use automatic state reset with Task.sleep after transient states
2. Implement completion handlers that always transition to idle
3. Add state machine validation (idle is only state that accepts recording trigger)
4. Test rapid successive Option-C presses
5. Add state timeout fallback (if not idle after 60s, force reset)

**Detection:**
- Second Option-C press doesn't trigger recording
- Menu bar icon stuck in success/error state
- State logs show non-idle state persisting
- UI tests fail on consecutive operations

**Phase to address:** Phase 3 - Core requirement, blocks multi-use functionality

### Pitfall 2: Permission Denied After App Already Running

**What goes wrong:** User grants permissions on first launch, app works. Later, user revokes permission in System Settings. Next recording attempt fails with unclear error because app cached "permission granted" state.

**Why it happens:** Permission checked once at launch, not before each operation. User can revoke permissions at any time while app is running.

**Consequences:**
- Recording fails with cryptic error (AVFoundation error code)
- User doesn't know why it stopped working
- No guidance to re-enable permissions
- Support burden from confused users

**Prevention:**
1. Check permissions before EVERY recording operation, not just at launch
2. Handle .denied state gracefully with specific error message
3. Provide notification with direct link guidance to System Settings
4. Show permission status in menu bar dropdown
5. Test permission revocation while app is running

**Detection:**
- Works on fresh launch but fails after permission revoked
- Error logs show authorization failures
- User reports "stopped working suddenly"

**Phase to address:** Phase 3 - Error handling requirement

### Pitfall 3: Notification Permission Denial Silent Failure

**What goes wrong:** User denies notification permission. Success/error notifications never appear. User doesn't know transcription completed or failed.

**Why it happens:** requestAuthorization returns false but code doesn't handle denial. Notification.add() silently fails when permission denied.

**Consequences:**
- User doesn't know when transcription is ready
- User manually checks clipboard after every recording
- Timeout errors invisible to user
- Poor UX, app feels unresponsive

**Prevention:**
1. Check notification authorization status before relying on notifications
2. Provide fallback feedback (menu bar icon change, sound)
3. Show permission status in menu bar dropdown
4. Request notification permission on first launch with clear explanation
5. Don't make notifications critical path - clipboard is primary output

**Detection:**
- Notifications don't appear but operations succeed
- UNUserNotificationCenter returns false for permission request
- User reports "how do I know when it's done?"

**Phase to address:** Phase 3 - Feedback requirement

### Pitfall 4: Swift Concurrency Continuation Misuse

**What goes wrong:** Using withCheckedContinuation for SFSpeechRecognizer.requestAuthorization but resuming multiple times or never resuming, causing crashes or hangs.

**Why it happens:** Continuation must resume exactly once. Multiple resumes crash, zero resumes hang forever.

**Consequences:**
- App crashes with "FATAL: continuation misuse" error
- Permission requests hang indefinitely
- Unpredictable behavior in permission flow
- Hard to debug timing issues

**Prevention:**
1. Always resume continuation exactly once in all code paths
2. Use withCheckedThrowingContinuation to catch violations in debug builds
3. Structure authorization handler to have single resume point
4. Test all authorization states (.authorized, .denied, .restricted, .notDetermined, @unknown)
5. Add timeout to permission requests (shouldn't take >30s)

**Detection:**
- Crash with "continuation resumed multiple times"
- Permission request never completes
- Xcode runtime warnings about continuation misuse
- Test suite hangs on permission tests

**Phase to address:** Phase 3 - Permission handling implementation

### Pitfall 5: Timeout Error Indistinguishable from No Speech

**What goes wrong:** User records 35-second speech. Transcription engine still processing when 30-second timeout fires. User sees "No speech detected" even though they spoke clearly.

**Why it happens:** Timeout implementation doesn't distinguish between "no audio input" and "processing taking too long". Both trigger same error.

**Consequences:**
- User thinks microphone broken
- User tries again with same long recording, same timeout
- Confusing error messages ("I definitely spoke!")
- Users give up thinking app doesn't work

**Prevention:**
1. Detect actual audio input separately from transcription timeout
2. Different error messages: "No speech detected" vs "Transcription taking longer than expected"
3. Show processing indicator during timeout period (not just idle wait)
4. Consider longer timeout for long recordings (scale with recording length?)
5. Log audio input levels to help debug microphone issues

**Detection:**
- User reports incorrect "no speech" errors
- Logs show audio captured but transcription timed out
- User complaints about specific recording lengths

**Phase to address:** Phase 3 - Timeout requirement refinement

## Code Examples

Verified patterns for Phase 3 implementation:

### Complete Permission Flow

```swift
// Source: AVFoundation and Speech framework documentation patterns
@MainActor
class RecordingCoordinator {
    private let permissionManager = PermissionManager()
    private let notificationManager = NotificationManager.shared

    func startRecording() async {
        // Check permissions before starting
        let micResult = await permissionManager.requestMicrophonePermission()
        guard case .success = micResult else {
            if case .failure(let error) = micResult {
                await handleError(error)
            }
            return
        }

        let speechResult = await permissionManager.requestSpeechRecognitionPermission()
        guard case .success = speechResult else {
            if case .failure(let error) = speechResult {
                await handleError(error)
            }
            return
        }

        // Permissions granted, proceed with recording
        await performRecording()
    }

    private func handleError(_ error: AppError) {
        notificationManager.showError(error)
        // Transition back to idle after showing error
        Task {
            try? await Task.sleep(for: .seconds(3))
            currentState = .idle
        }
    }
}
```

### State-Driven UI Updates

```swift
// Source: SwiftUI state management patterns
@main
struct OptionCApp: App {
    @StateObject private var coordinator = StateCoordinator()

    var body: some Scene {
        MenuBarExtra {
            Button("Quit") { NSApplication.shared.terminate(nil) }
        } label: {
            HStack {
                Image(systemName: menuBarIcon)
                if let statusText = statusText {
                    Text(statusText)
                }
            }
        }
    }

    private var menuBarIcon: String {
        switch coordinator.currentState {
        case .idle:
            return "mic"
        case .recording:
            return "mic.fill"
        case .processing:
            return "hourglass"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    private var statusText: String? {
        switch coordinator.currentState {
        case .idle:
            return nil
        case .recording:
            return "Recording"
        case .processing:
            return "Processing"
        case .success:
            return "Success"
        case .error(let error):
            return error.errorDescription
        }
    }
}
```

### Graceful Error Handling with Recovery

```swift
// Source: Swift error handling best practices
func processRecording(audioURL: URL) async {
    do {
        // Try transcription with timeout
        let transcription = try await withTimeout(seconds: 30) {
            await transcriptionEngine.transcribe(audioURL: audioURL)
        }

        // Success path
        copyToClipboard(transcription)
        await notificationManager.showSuccess(transcription: transcription)
        await coordinator.transitionToSuccess(transcription: transcription)

    } catch AppError.transcriptionTimeout {
        // Specific timeout handling
        await notificationManager.showTimeout()
        await coordinator.transitionToError(.noSpeechDetected)

    } catch AppError.microphonePermissionDenied {
        // Permission error with recovery guidance
        await notificationManager.showError(.microphonePermissionDenied)
        await coordinator.transitionToError(.microphonePermissionDenied)

    } catch {
        // Generic error fallback
        let appError = AppError.recordingFailed(underlying: error)
        await notificationManager.showError(appError)
        await coordinator.transitionToError(appError)
    }
}

private func copyToClipboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NSUserNotification | UNUserNotificationCenter | macOS 11 (2020) | Rich notifications, unified API, better Focus mode support |
| Completion handlers with @escaping | async/await with continuations | Swift 5.5 (2021) | Cleaner syntax, better cancellation, compile-time safety |
| Manual permission tracking | Built-in authorization status APIs | Always available but often ignored | Handles edge cases like runtime permission changes |
| GCD DispatchWorkItem for timeouts | Task.sleep with withThrowingTaskGroup | Swift 5.5 (2021) | Structured concurrency, automatic cleanup, cancellation support |
| Boolean state flags | Enum-based state machines | Swift pattern evolution | Prevents invalid states, makes transitions explicit |

**Deprecated/outdated:**
- NSUserNotification: Deprecated macOS 11, removed in macOS 12. Use UNUserNotificationCenter.
- Nested completion handler pyramids: "Callback hell" replaced by async/await linear flow.
- try! for permission requests: Causes crashes on denial. Use Result type or try/catch.

## Open Questions

Things that couldn't be fully resolved:

1. **Deep linking to System Settings permission panels**
   - What we know: Deep links (x-apple.systempreferences:) stopped working reliably in macOS Ventura
   - What's unclear: Whether Apple will provide new URL scheme or if programmatic opening is intentionally blocked
   - Recommendation: Use generic guidance text ("System Settings > Privacy & Security > Microphone") rather than attempting to open specific panel. Test on macOS 13+.

2. **Notification delivery timing with Focus modes**
   - What we know: UNUserNotificationCenter respects Focus mode settings, may delay or suppress notifications
   - What's unclear: How to guarantee immediate delivery for time-sensitive "transcription ready" notifications
   - Recommendation: Don't rely solely on notifications. Use menu bar icon state changes as primary feedback, notifications as secondary.

3. **Permission request timing best practices**
   - What we know: Apple HIG recommends requesting permissions in context, not at launch
   - What's unclear: For this app, is "on first hotkey press" better than "at app launch"?
   - Recommendation: Request on first hotkey press with clear explanation. Avoids scary permission dialogs before user understands app value.

## Sources

### Primary (HIGH confidence)
- [UNUserNotificationCenter | Apple Developer Documentation](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter) - Official framework documentation
- [requestAccess(for:completionHandler:) | Apple Developer Documentation](https://developer.apple.com/documentation/avfoundation/avcapturedevice/1624584-requestaccess) - Microphone permission API
- [requestAuthorization(_:) | Apple Developer Documentation](https://developer.apple.com/documentation/speech/sfspeechrecognizer/1649892-requestauthorization) - Speech recognition permission API
- [Asking Permission to Use Speech Recognition | Apple Developer Documentation](https://developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition) - Permission flow guidance
- [Handling notifications and notification-related actions | Apple Developer Documentation](https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions) - Notification handling

### Secondary (MEDIUM confidence)
- [Scheduling notifications: UNUserNotificationCenter and UNNotificationRequest - Hacking with Swift](https://www.hackingwithswift.com/read/21/2/scheduling-notifications-unusernotificationcenter-and-unnotificationrequest) - Practical tutorial
- [Implementing Task timeout with Swift Concurrency – Donny Wals](https://www.donnywals.com/implementing-task-timeout-with-swift-concurrency/) - May 2025, timeout pattern
- [Running an async task with a timeout - Swift Forums](https://forums.swift.org/t/running-an-async-task-with-a-timeout/49733) - Community patterns
- [Mastering Error Handling in Swift: Best Practices - Medium](https://anasaman-p.medium.com/mastering-error-handling-in-swift-best-practices-and-detailed-examples-76ea86d4f25c) - Error patterns
- [Handling loading states within SwiftUI views | Swift by Sundell](https://www.swiftbysundell.com/articles/handling-loading-states-in-swiftui/) - State management patterns
- [Success Message UX Examples & Best Practices - Pencil & Paper](https://www.pencilandpaper.io/articles/success-ux) - User feedback UX
- [App Push Notification Best Practices for 2026 - Appbot](https://appbot.co/blog/app-push-notifications-2026-best-practices/) - 2026 notification trends
- [SwiftUI Permissions - Medium](https://medium.com/@sarimk80/swiftui-permissions-df11a0f4e264) - Permission handling patterns
- [Requesting authorization for media capture - Medium](https://medium.com/@nayananp/requesting-authorization-for-media-capture-and-audio-on-ios-b7b62c7f9ba7) - Authorization patterns

### Tertiary (LOW confidence)
- [Deeplinks into new System Settings app in macOS Ventura - Apple Developer Forums](https://developer.apple.com/forums/thread/709289) - Deep linking issues (unresolved)
- [How to use continuations - Hacking with Swift](https://www.hackingwithswift.com/quick-start/concurrency/how-to-use-continuations-to-convert-completion-handlers-into-async-functions) - Continuation patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All built-in frameworks with official documentation
- Architecture: HIGH - Enum-based state machines are well-established pattern, multiple verified sources
- Pitfalls: MEDIUM-HIGH - Permission edge cases well-documented, timeout patterns verified, continuation misuse from official Swift docs
- Code examples: HIGH - All patterns from official Apple docs, Swift Forums, or verified tutorials

**Research date:** 2026-02-01
**Valid until:** 60 days (stable APIs, unlikely to change before macOS 27)

**Phase 3 readiness:** All patterns identified, no additional research needed for planning. Implementation can proceed with confidence.
