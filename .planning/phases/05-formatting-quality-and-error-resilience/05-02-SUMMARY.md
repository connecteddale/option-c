---
phase: 05-formatting-quality-and-error-resilience
plan: 02
subsystem: processing, ui
tags: [ollama, error-handling, availability-check, menu-bar, resilience]

requires:
  - phase: 05-formatting-quality-and-error-resilience
    provides: OllamaProcessingEngine with configurable model and full system prompt (Plan 01)
provides:
  - Ollama availability checking with checkAvailability() method
  - OllamaAvailabilityStatus enum for structured availability state
  - Inline warning UI when Ollama is unavailable
  - AppError cases for Ollama-specific errors
affects: [future model selection UI, future health check polling]

tech-stack:
  added: []
  patterns: ["availability check on toggle enable (not app startup)", "model name normalisation for tag comparison"]

key-files:
  created: []
  modified:
    - Sources/OptionC/Processing/OllamaProcessingEngine.swift
    - Sources/OptionC/State/AppState.swift
    - Sources/OptionC/Views/MenuBarView.swift
    - Sources/OptionC/Models/AppError.swift

key-decisions:
  - "Availability check triggers on AI toggle enable, not on app startup (avoids unnecessary network calls)"
  - "5-second timeout for health check vs 60-second timeout for chat requests"
  - "Model name normalisation strips :tag suffix to handle llama3.2 vs llama3.2:latest"
  - "Warning is informational only — does not block recording or prevent pipeline from running"

patterns-established:
  - "onChange handler on toggle triggers async availability check"
  - "Inline warning pattern mirroring existing accessibility warning"

requirements-completed: [LLM-03, UX-03, UX-04]

duration: 3 min
completed: 2026-03-02
---

# Phase 5 Plan 02: Ollama Availability Checking and Error Resilience Summary

**Ollama health check with /api/tags endpoint, model name normalisation, inline warning UI, and preserved graceful fallback**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-02T14:26:00Z
- **Completed:** 2026-03-02T14:29:05Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Added checkAvailability() method to OllamaProcessingEngine querying /api/tags with 5-second timeout
- Model name normalisation handles "llama3.2" vs "llama3.2:latest" comparison correctly
- AppState publishes ollamaAvailable and ollamaAvailabilityMessage for UI binding
- MenuBarView shows inline orange warning when AI toggle is on but Ollama is unavailable
- AppError extended with ollamaNotRunning and ollamaModelMissing cases
- Existing graceful fallback in stopRecording() preserved (UX-04)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add checkAvailability method and supporting types** - `07ff93a` (feat)
2. **Task 2: Add availability state, error cases, and warning UI** - `0babc0b` (feat)

## Files Created/Modified
- `Sources/OptionC/Processing/OllamaProcessingEngine.swift` - checkAvailability(), OllamaAvailabilityStatus, OllamaTagsResponse
- `Sources/OptionC/State/AppState.swift` - ollamaAvailable, ollamaAvailabilityMessage, checkOllamaAvailability()
- `Sources/OptionC/Views/MenuBarView.swift` - onChange handler on AI toggle, inline availability warning
- `Sources/OptionC/Models/AppError.swift` - ollamaNotRunning and ollamaModelMissing cases

## Decisions Made
- Availability check on toggle enable, not app startup — avoids unnecessary network calls when AI is off
- 5-second timeout for health check (vs 60-second chat timeout) — fail fast for unavailability
- Warning is informational only — does not prevent pipeline from running (user may start Ollama after seeing warning)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 5 complete — all formatting quality and error resilience requirements implemented
- Ready for phase verification

---
*Phase: 05-formatting-quality-and-error-resilience*
*Completed: 2026-03-02*
