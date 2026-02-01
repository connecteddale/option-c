# Option-C

## What This Is

A macOS menu bar app that turns Option-C into a voice-to-clipboard shortcut. Press once to start recording, press again to stop — audio is transcribed using Apple's Speech framework and copied to clipboard. Menu bar indicator shows current state.

## Core Value

Voice-to-clipboard with a single keyboard shortcut. If the hotkey doesn't capture speech and deliver text to clipboard, nothing else matters.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Option-C toggles recording on/off
- [ ] Menu bar indicator shows recording state (idle/recording/processing)
- [ ] After recording stops, audio is transcribed via Speech framework
- [ ] Transcription text is copied to clipboard when ready
- [ ] Notification appears when transcription is ready
- [ ] Error notification appears if transcription fails
- [ ] Menu bar returns to idle state when complete

### Out of Scope

- Voice Memos integration — native recording is more reliable
- Persistent recording storage — transcribe and discard
- Transcription quality settings — using Apple's defaults
- Multiple concurrent recordings — single toggle workflow only

## Context

**Native recording stack:**
- AVFoundation (AVAudioEngine) for microphone capture
- Speech framework (SFSpeechRecognizer) for transcription
- Both are built-in macOS frameworks, no external dependencies

**Transcription:**
- On-device processing, no internet required
- Real-time or post-recording transcription supported
- Same engine that powers Siri dictation

**Menu bar app:**
- Swift + SwiftUI MenuBarExtra (macOS 13+)
- KeyboardShortcuts library for global hotkey
- NSPasteboard for clipboard, UserNotifications for alerts

## Constraints

- **Platform**: macOS 13+ (Ventura) — required for MenuBarExtra
- **Keyboard shortcut**: Option-C (⌥C) — must not conflict with system shortcuts
- **Permissions**: Microphone access + Speech Recognition (standard permissions)
- **Language**: Swift + SwiftUI — native frameworks require native language

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Native recording over Voice Memos | Simpler permissions, more reliable, no Full Disk Access | ✓ Good |
| Menu bar app for state | Visual feedback without notification spam | — Pending |
| Notification on ready | Clear signal that clipboard has content | — Pending |

---
*Last updated: 2026-02-01 after research pivot to native recording*
