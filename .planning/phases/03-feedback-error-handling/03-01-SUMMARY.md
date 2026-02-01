---
phase: 03-feedback-error-handling
plan: 01
subsystem: error-handling
tags: [LocalizedError, AVCaptureDevice, SFSpeechRecognizer, permissions]

# Dependency graph
requires:
  - phase: 02-core-recording-transcription
    provides: TranscriptionService and AudioCaptureSession that will use these error types
provides:
  - AppError enum with 6 error cases and LocalizedError conformance
  - PermissionManager for microphone and speech recognition permissions
  - PermissionStatus enum for permission state tracking
affects: [03-02-notification-system, 03-03-state-coordinator-error-integration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - LocalizedError conformance for user-facing error messages
    - withCheckedContinuation for callback-to-async conversion
    - @MainActor isolation for permission manager

key-files:
  created:
    - Sources/OptionC/Models/AppError.swift
    - Sources/OptionC/Services/PermissionManager.swift
  modified: []

key-decisions:
  - "System Settings paths in recoverySuggestion for actionable guidance"
  - "@unknown default handled as .denied for future-proof permission checking"

patterns-established:
  - "AppError.errorDescription for user-facing error titles"
  - "AppError.recoverySuggestion for actionable recovery guidance"
  - "Result<Void, AppError> for async permission operations"

# Metrics
duration: 1min
completed: 2026-02-01
---

# Phase 3 Plan 01: Error Types and Permission Manager Summary

**AppError enum with LocalizedError conformance and PermissionManager for microphone/speech recognition permission checking and requesting**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-01T15:00:44Z
- **Completed:** 2026-02-01T15:02:02Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- AppError enum with 6 error cases covering all permission and operation failures
- User-friendly errorDescription and actionable recoverySuggestion for each error
- PermissionManager with synchronous status checking and async permission requesting
- Proper continuation handling for SFSpeechRecognizer callback API

## Task Commits

Each task was committed atomically:

1. **Task 1: Create AppError enum with LocalizedError conformance** - `30ba4a1` (feat)
2. **Task 2: Create PermissionManager for microphone and speech permissions** - `0b8b152` (feat)

## Files Created/Modified
- `Sources/OptionC/Models/AppError.swift` - Centralized error types with user-friendly messages
- `Sources/OptionC/Services/PermissionManager.swift` - Permission checking and requesting for microphone and speech recognition

## Decisions Made
- System Settings paths included in recoverySuggestion for direct user action
- @unknown default cases handled as .denied for future macOS versions
- PermissionStatus enum provides clean abstraction over platform-specific status types

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- AppError ready for integration with NotificationManager (Plan 02)
- PermissionManager ready for integration with StateCoordinator (Plan 03)
- Error types can be thrown from existing TranscriptionService and AudioCaptureSession

---
*Phase: 03-feedback-error-handling*
*Completed: 2026-02-01*
