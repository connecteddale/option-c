# Option-C

## What This Is

A macOS menu bar app that turns Option-C into a voice-to-clipboard shortcut. Press a keyboard shortcut, speak, and WhisperKit transcribes your speech on-device. Text is copied to clipboard with optional auto-paste. Supports toggle and push-to-talk recording modes, text replacements for custom shortcuts, and WhisperKit model selection.

## Core Value

Voice-to-clipboard with a single keyboard shortcut. If the hotkey doesn't capture speech and deliver text to clipboard, nothing else matters.

## Current Milestone: v1.1 Smart Text Processing

**Goal:** Add intelligent text post-processing via local LLM (Ollama) so transcriptions come back properly formatted — punctuation, 24h times, numbers, currencies, spelling, capitalisation.

**Target features:**
- Ollama integration for local AI text cleanup (no API key, no network)
- Full text post-processing: punctuation, spelling, capitalisation, numbers, currencies
- 24h time format with 'h' separator (15:15, 09:30)
- Menu toggle for AI processing on/off
- Swappable provider architecture (Ollama first, Anthropic API fallback)

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

- Option-C toggles recording on/off (toggle mode)
- Push-to-talk recording mode (hold to record, release to stop)
- Mode switching via menu bar dropdown
- Menu bar icon reflects state (idle/recording/processing/success/error)
- WhisperKit on-device transcription (no internet required)
- WhisperKit model selection (base/large) via menu
- Transcription text copied to clipboard automatically
- Auto-paste option (simulates Cmd+V after copy)
- Text replacements for custom find/replace post-processing
- Text replacements editor window (NSPanel)
- WhisperKit hallucination filtering (blank audio detection)
- Auto-capitalisation of line starts
- Error notifications with recovery suggestions
- Permission handling (microphone, accessibility)
- Timeout handling (30s no speech)
- Auto-reset state transitions (success/error)
- Self-signed certificate for persistent accessibility trust

### Active

<!-- Current scope. Building toward these. -->

- [ ] AI-powered text cleanup via Ollama (punctuation, spelling, capitalisation)
- [ ] Time formatting to 24h international format (15:15)
- [ ] Number conversion (spoken words to digits)
- [ ] Currency formatting (spoken to symbols)
- [ ] Menu toggle for AI processing on/off
- [ ] Swappable LLM provider architecture (Ollama first, Anthropic API later)

### Out of Scope

<!-- Explicit boundaries. Includes reasoning to prevent re-adding. -->

- Multi-language support — user doesn't need it; can add later if requested
- File transcription — this is a clipboard tool, not a transcription service
- Cloud sync / accounts — privacy-first, local-only approach
- Audio storage — delete after transcription; no history
- Voice commands — conflicts with macOS Voice Control
- Custom notification sounds — keep it minimal, use system defaults
- Dock icon — menu bar only, invisible until needed
- Live transcription preview — complexity not justified for v1
- Context awareness (detect focused app) — defer to future
- AI reformatting modes (formal, code, casual) — defer to future
- History with playback — defer to future

## Context

**Current tech stack:**
- Swift 5.9, macOS 14+, Swift Package Manager
- WhisperKit for on-device speech-to-text
- KeyboardShortcuts library for global hotkey registration
- MenuBarExtra for menu bar UI
- Code-signed with persistent "OptionC Dev" self-signed certificate

**Architecture:**
- AppState coordinates all UI state
- RecordingController orchestrates audio capture + transcription
- AudioCaptureManager handles microphone via AVAudioEngine
- WhisperTranscriptionEngine wraps WhisperKit (singleton)
- ClipboardManager handles NSPasteboard + CGEvent paste simulation
- TextReplacementManager runs find/replace post-processing
- Flow: hotkey -> AppState -> RecordingController -> AudioCaptureManager -> WhisperTranscriptionEngine -> TextReplacementManager -> ClipboardManager -> optional auto-paste

**v1.1 integration point:**
- Ollama processing slots in after TextReplacementManager, before ClipboardManager
- New pipeline: WhisperKit -> text replacements -> (if AI on) Ollama -> clipboard
- Ollama HTTP API at localhost:11434 — same URLSession pattern, no API key needed

## Constraints

- **Platform**: macOS 14+ (Sonoma) — required for MenuBarExtra
- **Ollama**: Must be installed with a model downloaded on user's machine
- **Latency**: Local LLM adds processing time; faster than API round-trip, acceptable trade-off
- **Language**: Swift + SwiftUI — native frameworks require native language

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Native recording over Voice Memos | Simpler permissions, more reliable, no Full Disk Access | ✓ Good |
| WhisperKit over Speech framework | Better accuracy, model selection, active development | ✓ Good |
| Menu bar app for state | Visual feedback without notification spam | ✓ Good |
| Auto-paste via CGEvent | Seamless workflow, optional toggle | ✓ Good |
| Text replacements post-processing | Zero latency, user-customisable | ✓ Good |
| Self-signed certificate | Persistent accessibility trust across rebuilds | ✓ Good |
| Ollama over Claude CLI | CLI has confirmed bugs (TTY hang, empty output). Ollama is local, no API key, no network. | — Pending |
| Swappable provider architecture | Start with Ollama, swap to Anthropic API if quality insufficient | — Pending |
| Keep text replacements alongside AI | Custom shortcuts/jargon that AI shouldn't touch | — Pending |
| AI processing as toggle | User controls latency trade-off | — Pending |

---
*Last updated: 2026-03-02 after starting milestone v1.1*
