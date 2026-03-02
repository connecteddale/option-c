# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-02)

**Core value:** Voice-to-clipboard with a single keyboard shortcut. If the hotkey doesn't capture speech and deliver text to clipboard, nothing else matters.
**Current focus:** Phase 4 — Ollama Engine and Pipeline Integration

## Current Position

Phase: 4 of 5 (v1.1 — Ollama Engine and Pipeline Integration)
Plan: 0 of 2 in current phase
Status: Ready to plan
Last activity: 2026-03-02 — Roadmap created for v1.1 (Phases 4-5)

Progress: [######----] 60% (3/5 phases complete, v1.0 shipped)

## Performance Metrics

**Velocity (from v1.0):**
- Total plans completed: 7
- Average duration: 3.1 min
- Total execution time: 0.36 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1. Foundation & Menu Bar | 2 | ~6 min | 3 min |
| 2. Core Recording & Transcription | 2 | ~6 min | 3 min |
| 3. Feedback & Error Handling | 3 | ~9 min | 3 min |

*Updated after each plan completion*

## Accumulated Context

### Decisions

- Ollama over Claude CLI: CLI has confirmed TTY hang and empty-output bugs (closed won't-fix). Ollama is local, no API key, no network.
- Swappable provider architecture: Protocol-based so Ollama can be replaced later without rewiring AppState
- AI slots between TextReplacementManager and ClipboardManager: Text replacements handle jargon first; AI sees clean input
- AI processing as toggle (default off): User controls the latency trade-off; never break voice-to-clipboard
- Graceful fallback on any AI failure: Raw transcription always reaches clipboard

### Pending Todos

None yet.

### Blockers/Concerns

- Confirm bundle ID from Package.swift before writing Keychain/URLSession code (service identifier must match exactly)
- Output length guard threshold (300% of input) needs empirical calibration after Phase 5 prompt tuning
- Instrument actual Ollama latency during Phase 4 smoke testing to confirm timeout value is appropriate

## Session Continuity

Last session: 2026-03-02
Stopped at: Roadmap created — ready to plan Phase 4
Resume file: None

---
*Created: 2026-02-01*
*Last updated: 2026-03-02 (v1.1 roadmap, STATE reset for Phase 4)*
