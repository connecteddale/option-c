# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-02)

**Core value:** Voice-to-clipboard with a single keyboard shortcut. If the hotkey doesn't capture speech and deliver text to clipboard, nothing else matters.

**Current focus:** Milestone v1.1 — Smart Text Processing

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-03-02 — Milestone v1.1 started

## Performance Metrics

**Velocity (from v1.0):**
- Total plans completed: 7
- Average duration: 3.1min
- Total execution time: 0.36 hours

## Accumulated Context

### Decisions

- Native recording over Voice Memos: Simpler permissions, more reliable, no Full Disk Access
- WhisperKit over Speech framework: Better accuracy, model selection, active development
- Menu bar app for state: Visual feedback without notification spam
- Auto-paste via CGEvent: Seamless workflow, optional toggle
- Text replacements post-processing: Zero latency, user-customisable
- Self-signed certificate: Persistent accessibility trust across rebuilds
- Fresh AVAudioEngine per session: Avoids state corruption where tap callback stops firing
- Offline recognition only: requiresOnDeviceRecognition = true for privacy-first approach
- 30-second transcription timeout: Prevents infinite waits if recognizer unresponsive

### Pending Todos

None yet.

### Blockers/Concerns

None yet.

## Session Continuity

Last session: 2026-03-02
Stopped at: Starting milestone v1.1
Resume file: None

---
*Created: 2026-02-01*
*Last updated: 2026-03-02*
