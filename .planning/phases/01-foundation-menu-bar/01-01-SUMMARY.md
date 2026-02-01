---
phase: 01-foundation-menu-bar
plan: 01
subsystem: ui
tags: [swift, swiftui, menubarextra, keyboard-shortcuts, macos]

# Dependency graph
requires: []
provides:
  - Swift package project structure with executable target
  - MenuBarExtra-based menu bar app scaffold
  - State management infrastructure (AppState, RecordingState, RecordingMode)
  - Info.plist prepared for app bundle distribution
affects: [01-02, 01-03, 02-audio-recording, 03-transcription]

# Tech tracking
tech-stack:
  added: [KeyboardShortcuts 1.11.0]
  patterns: [@MainActor state coordinator, MenuBarExtra scene, @Published state observation]

key-files:
  created:
    - Package.swift
    - Sources/OptionC/OptionCApp.swift
    - Sources/OptionC/State/AppState.swift
    - Sources/OptionC/Models/RecordingState.swift
    - Sources/OptionC/Models/RecordingMode.swift
    - Sources/OptionC/Resources/Info.plist

key-decisions:
  - "KeyboardShortcuts 1.11.0 pinned to avoid #Preview macro build issues in SPM"
  - "Info.plist excluded from SPM build (for future app bundle packaging)"

patterns-established:
  - "@MainActor AppState as centralized state coordinator"
  - "RecordingState enum driving menu bar icon changes"
  - "MenuBarExtra with dynamic label binding to state"

# Metrics
duration: 8min
completed: 2026-02-01
---

# Phase 1 Plan 01: Swift Package + MenuBarExtra Setup Summary

**SwiftUI MenuBarExtra scaffold with @MainActor AppState coordinator, KeyboardShortcuts dependency, and state-driven menu bar icon**

## Performance

- **Duration:** 8 min
- **Started:** 2026-02-01T14:38:18Z
- **Completed:** 2026-02-01T14:46:28Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments
- Swift package project builds successfully (debug and release)
- MenuBarExtra scene with dynamic mic.circle icon bound to AppState
- State management infrastructure: AppState, RecordingState, RecordingMode enums
- Info.plist prepared with LSUIElement=true for Dock hiding
- Release binary at .build/release/OptionC (441KB arm64 executable)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Swift Package Project Structure** - `8a05407` (feat)
2. **Task 2: Add Info.plist for Dock Hiding** - `8baab97` (feat)
3. **Task 3: Verify Menu Bar App Runs** - No commit (verification only)

## Files Created/Modified
- `Package.swift` - Swift package manifest with KeyboardShortcuts dependency
- `Sources/OptionC/OptionCApp.swift` - @main entry point with MenuBarExtra scene
- `Sources/OptionC/State/AppState.swift` - @MainActor state coordinator with @Published state
- `Sources/OptionC/Models/RecordingState.swift` - Enum: idle, recording, processing
- `Sources/OptionC/Models/RecordingMode.swift` - Enum: toggle, pushToTalk
- `Sources/OptionC/Resources/Info.plist` - App config with LSUIElement=true
- `Package.resolved` - Resolved dependency versions

## Decisions Made

1. **KeyboardShortcuts pinned to 1.11.0** - Newer versions (1.12.0+) include #Preview macros that fail to build with Swift Package Manager outside of Xcode. Version 1.11.0 is the latest without this issue.

2. **Info.plist excluded from SPM build** - Swift Package Manager doesn't support Info.plist as a bundled resource for executables. The file is prepared for future app bundle packaging (Xcode project or build script).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] KeyboardShortcuts version downgrade**
- **Found during:** Task 1 (Swift package build)
- **Issue:** KeyboardShortcuts 2.4.0 and 1.17.0 contain #Preview macros that require Xcode's PreviewsMacros plugin, which isn't available when building with `swift build`
- **Fix:** Pinned to version 1.11.0 (last version without #Preview macros)
- **Files modified:** Package.swift
- **Verification:** `swift build` completes successfully
- **Committed in:** 8a05407 (Task 1 commit)

**2. [Rule 3 - Blocking] Info.plist resource exclusion**
- **Found during:** Task 2 (Info.plist integration)
- **Issue:** Swift Package Manager forbids Info.plist as a top-level resource in the bundle
- **Fix:** Changed from `resources: [.copy()]` to `exclude:` - Info.plist kept for future app bundle creation
- **Files modified:** Package.swift
- **Verification:** `swift build` completes without warnings
- **Committed in:** 8baab97 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (2 blocking issues)
**Impact on plan:** Both auto-fixes necessary to achieve working build. No scope creep. KeyboardShortcuts 1.11.0 has all features needed for Phase 1. Info.plist will be used when creating proper app bundle for distribution.

## Issues Encountered

None beyond the blocking issues documented as deviations.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Swift package foundation complete
- AppState ready for hotkey integration (Plan 01-02)
- RecordingState enum ready to drive state machine
- Menu bar icon dynamically updates when currentState changes
- Ready to add KeyboardShortcuts.Recorder UI and hotkey handler

**Note:** Full Dock hiding (LSUIElement) will only work when app is packaged as proper .app bundle. Swift Package Manager executables appear in Dock during development.

---
*Phase: 01-foundation-menu-bar*
*Completed: 2026-02-01*
