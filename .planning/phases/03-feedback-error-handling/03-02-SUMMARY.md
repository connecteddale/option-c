---
phase: 03-feedback-error-handling
plan: 02
subsystem: notifications
tags: [usernotifications, feedback, macOS]

dependency_graph:
  requires:
    - 03-01 (AppError enum with LocalizedError)
  provides:
    - NotificationManager singleton for system notification delivery
    - Notification permission requested at app launch
  affects:
    - 03-03 (StateCoordinator will call NotificationManager methods)

tech_stack:
  added:
    - UserNotifications framework
  patterns:
    - UNUserNotificationCenter for modern macOS notifications
    - UNMutableNotificationContent for notification construction
    - UNNotificationRequest with nil trigger for immediate delivery
    - @MainActor singleton pattern

key_files:
  created:
    - Sources/OptionC/Services/NotificationManager.swift
  modified:
    - Sources/OptionC/OptionCApp.swift

decisions:
  - id: notification-permission-timing
    choice: Request on app launch (not first hotkey)
    reason: Simpler implementation, permission dialog appears at predictable time

metrics:
  duration: 1m 21s
  completed: 2026-02-01
---

# Phase 3 Plan 02: Notification System Summary

**One-liner:** NotificationManager singleton with UNUserNotificationCenter for success/error/timeout system notifications, permission requested at app launch.

## What Was Built

### NotificationManager (`Sources/OptionC/Services/NotificationManager.swift`)

A @MainActor singleton service that delivers system notifications for transcription feedback.

**Methods:**
- `requestPermission() async -> Bool` - Requests .alert and .sound authorization
- `showSuccess(transcription: String)` - "Transcription Ready" with clipboard preview (truncated to 100 chars)
- `showError(_ error: AppError)` - Error title/recovery from LocalizedError, critical sound
- `showTimeout()` - "No Speech Detected" with 30-second timeout message

**Key Implementation Details:**
- Uses `UNUserNotificationCenter.current()` (modern API, not deprecated NSUserNotification)
- All notifications use `trigger: nil` for immediate delivery
- Error notifications use `.defaultCritical` sound to draw attention
- Success notifications show truncated transcription preview in body

### App Launch Integration (`Sources/OptionC/OptionCApp.swift`)

Added init() method that fires async permission request on app launch:
```swift
init() {
    Task {
        await NotificationManager.shared.requestPermission()
    }
}
```

Non-blocking - app continues regardless of permission result.

## Commits

| Commit | Type | Description |
|--------|------|-------------|
| e27973b | feat | Create NotificationManager with all four methods |
| 095456b | feat | Request notification permission at app launch |

## Verification Results

- NotificationManager.swift exists with singleton pattern
- All four methods implemented (requestPermission, showSuccess, showError, showTimeout)
- Uses UNUserNotificationCenter (5 references)
- Success notification truncates at 100 chars with "..."
- Error notification uses .defaultCritical sound
- OptionCApp requests permission in init()
- Clean build: `swift build` succeeds

## Deviations from Plan

None - plan executed exactly as written.

## Integration Points

**Ready for StateCoordinator (Plan 03):**
- NotificationManager.shared.showSuccess(transcription:) - Call after clipboard write
- NotificationManager.shared.showError(_:) - Call on any AppError
- NotificationManager.shared.showTimeout() - Call on transcription timeout

**Works with existing:**
- AppError enum - showError() uses errorDescription and recoverySuggestion

## Next Phase Readiness

- Notifications ready to be triggered from StateCoordinator
- No blockers for Plan 03 integration
- Menu bar icon state changes will provide backup feedback if notifications denied
