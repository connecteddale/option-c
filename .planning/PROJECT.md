# Option-C

## What This Is

A macOS automation that turns Option-C into a voice-to-clipboard shortcut. Press once to start recording via Voice Memos, press again to stop — then Apple's transcription is automatically extracted and copied to clipboard. A menu bar indicator shows current state.

## Core Value

Voice-to-clipboard with a single keyboard shortcut. If the hotkey doesn't capture speech and deliver text to clipboard, nothing else matters.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Option-C toggles Voice Memos recording on/off
- [ ] Menu bar indicator shows recording state (idle/recording/processing)
- [ ] After recording stops, script waits for transcription (up to 30s)
- [ ] Transcription text is copied to clipboard when ready
- [ ] Notification appears when transcription is ready
- [ ] Error notification appears if transcription times out or fails
- [ ] Menu bar returns to idle state when complete

### Out of Scope

- Manual Voice Memos UI interaction — automation handles everything
- Recording storage management — Voice Memos handles this
- Transcription quality settings — using Apple's defaults
- Multiple concurrent recordings — single toggle workflow only

## Context

**Voice Memos storage:**
- Recordings stored in `~/Library/Application Support/com.apple.voicememos/`
- Transcriptions in SQLite database within that directory
- Database access requires Full Disk Access permission

**Transcription timing:**
- Apple's transcription typically takes 10-30 seconds after recording stops
- May fail silently for very short recordings or unclear audio

**macOS automation options:**
- Shortcuts can control Voice Memos recording
- AppleScript for app control
- Python for database access and clipboard
- Swift/SwiftUI or Python (rumps) for menu bar app

## Constraints

- **Platform**: macOS only (current version)
- **Keyboard shortcut**: Option-C (⌥C) — must not conflict with system shortcuts
- **Permissions**: Requires Full Disk Access for database reading
- **Dependency**: Relies on Apple's Voice Memos transcription feature being enabled

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Menu bar app for state | Visual feedback without notifications spam | — Pending |
| 30s transcription timeout | Balance between waiting and failing fast | — Pending |
| Notification on ready | Clear signal that clipboard has content | — Pending |

---
*Last updated: 2026-02-01 after initialization*
