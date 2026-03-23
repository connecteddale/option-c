# Option-C

macOS menu bar app for voice-to-text transcription. Press a keyboard shortcut, speak, and the transcription is copied to clipboard (with optional auto-paste).

## Build and Run

```bash
# Build only
bash bundle-app.sh

# Build, install, and restart
bash bundle-app.sh && cp -r .build/Option-C.app /Applications/ && osascript -e 'quit app "Option-C"' 2>/dev/null; sleep 1; open /Applications/Option-C.app
```

## Tech Stack

- Swift 5.9, macOS 14+, Swift Package Manager
- WhisperKit for on-device speech-to-text (no network required)
- KeyboardShortcuts library for global hotkey registration
- MenuBarExtra for the menu bar UI
- Code-signed with a persistent "OptionC Dev" self-signed certificate (falls back to ad-hoc if missing)

## Architecture

```
Sources/OptionC/
  OptionCApp.swift          -- @main entry, MenuBarExtra scene
  State/AppState.swift      -- Central state coordinator (@MainActor, ObservableObject)
  Recording/RecordingController.swift -- Orchestrates audio capture + transcription
  Audio/AudioCaptureManager.swift     -- Microphone capture via AVAudioEngine
  Transcription/WhisperTranscriptionEngine.swift -- WhisperKit wrapper (singleton)
  Clipboard/ClipboardManager.swift    -- NSPasteboard + CGEvent paste simulation
  Services/PermissionManager.swift    -- Mic and accessibility permission checks
  Views/MenuBarView.swift             -- Menu bar dropdown UI
  Views/ReplacementsWindow.swift      -- Text replacements editor (NSPanel)
  Models/                             -- RecordingState, RecordingMode, AppError, TextReplacement
```

Flow: keyboard shortcut -> AppState -> RecordingController -> AudioCaptureManager (record) -> WhisperTranscriptionEngine (transcribe) -> TextReplacementManager (post-process) -> ClipboardManager (copy) -> optional auto-paste via CGEvent

## Key Conventions

- All UI state flows through AppState. Recording modes are push-to-talk or toggle.
- User preferences use @AppStorage (recording mode, auto-paste, selected model).
- State transitions show briefly (success: 750ms, error: 1s) then auto-reset to idle.
- Menu bar icon reflects state: mic, mic.fill, ellipsis, checkmark, xmark.

## Gotchas

- CGEvent.post needs Accessibility permission. Use `AXIsProcessTrusted()` to check -- System Settings UI can be misleading.
- Auto-paste needs 500ms delay before paste and 50ms gap between keyDown/keyUp for apps to register the keystroke.
- TextFields don't work inside MenuBarExtra popovers. Use a separate NSPanel window (see ReplacementsWindow).
- When cancelling a Task, early returns from `guard !Task.isCancelled` must still clean up state.
- Ad-hoc signing invalidates accessibility trust on every rebuild. The "OptionC Dev" certificate solves this.
- WhisperKit models cache after first download. Base model is ~1-2s, Large ~10-20s.
