---
phase: 01-foundation-menu-bar
plan: 02
subsystem: ui
tags: [swift, swiftui, keyboardshortcuts, menubarextra, macos]

# Dependency graph
requires:
  - phase: 01-01
    provides: Swift package with MenuBarExtra shell and state types
provides:
  - Option-C hotkey registration and handler
  - State machine for recording lifecycle
  - Menu bar view with mode picker and quit button
  - Visual feedback via icon changes
affects: [01-03-audio-recording, 02-transcription]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - KeyboardShortcuts.onKeyUp handler pattern
    - State machine via switch on RecordingState
    - Picker with binding for persistent settings

key-files:
  created:
    - Sources/OptionC/KeyboardShortcuts+Names.swift
    - Sources/OptionC/Views/MenuBarView.swift
  modified:
    - Sources/OptionC/State/AppState.swift
    - Sources/OptionC/Models/RecordingState.swift
    - Sources/OptionC/OptionCApp.swift

key-decisions:
  - "handleHotkeyPress() implements toggle mode only - push-to-talk deferred to onKeyDown addition"
  - "1-second simulated processing delay as placeholder for Phase 2 transcription"

patterns-established:
  - "State machine: Use switch on RecordingState enum for state transitions"
  - "Hotkey registration: Call KeyboardShortcuts.onKeyUp in init() with [weak self]"
  - "Menu content: Pass AppState via @ObservedObject to MenuBarView"

# Metrics
duration: 3min
completed: 2026-02-01
---

# Phase 1 Plan 02: Hotkey Detection & Menu Content Summary

**Option-C hotkey triggers state machine (idle->recording->processing->idle) with visual menu bar icon feedback and dropdown menu for mode selection**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-01T14:48:25Z
- **Completed:** 2026-02-01T14:51:31Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments
- Option-C keyboard shortcut registered and triggers handleHotkeyPress()
- State machine cycles through idle -> recording -> processing -> idle
- Menu bar icon changes: mic.circle (idle), mic.circle.fill (recording), waveform.circle (processing)
- Menu dropdown displays current state, mode picker (toggle/push-to-talk), and quit button
- Recording mode persists via @AppStorage

## Task Commits

Each task was committed atomically:

1. **Task 1: Add KeyboardShortcuts Integration** - `79d2200` (feat)
2. **Task 2: Create Menu Content View** - `7746f9a` (feat)
3. **Task 3: Final Build and Verification** - verification only, no commit

**Plan metadata:** (this commit)

## Files Created/Modified
- `Sources/OptionC/KeyboardShortcuts+Names.swift` - Defines toggleRecording shortcut (Option+C)
- `Sources/OptionC/State/AppState.swift` - Added init() with hotkey handler and handleHotkeyPress() state machine
- `Sources/OptionC/Views/MenuBarView.swift` - Menu content with status display, mode picker, quit button
- `Sources/OptionC/Models/RecordingState.swift` - Added displayName computed property
- `Sources/OptionC/OptionCApp.swift` - Updated to use MenuBarView as MenuBarExtra content

## Decisions Made
- handleHotkeyPress() implements toggle mode behavior only; push-to-talk requires onKeyDown handler (future task)
- Processing state includes 1-second delay to simulate transcription (placeholder for Phase 2)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Hotkey detection and menu bar UI complete
- Ready for Phase 2: Audio recording and transcription
- Push-to-talk mode will need onKeyDown handler addition in future plan

---
*Phase: 01-foundation-menu-bar*
*Completed: 2026-02-01*
