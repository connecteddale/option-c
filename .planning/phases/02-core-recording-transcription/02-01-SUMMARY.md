---
phase: 02-core-recording-transcription
plan: 01
subsystem: audio-transcription
tags: [avfoundation, speech, audio-capture, transcription]

dependency_graph:
  requires: [01-02-hotkey-menu]
  provides: [audio-capture-manager, transcription-engine]
  affects: [02-02-recording-controller]

tech_stack:
  added: []
  patterns:
    - AVAudioEngine buffer streaming
    - SFSpeechRecognizer with Locale.current
    - Timer-based timeout handling
    - Fresh engine instance per session

files:
  created:
    - Sources/OptionC/Audio/AudioCaptureManager.swift
    - Sources/OptionC/Transcription/TranscriptionEngine.swift
  modified: []

decisions:
  - id: fresh-engine-per-session
    choice: Create new AVAudioEngine instance for each recording session
    reason: Reusing instances causes state corruption where tap callback stops firing
  - id: offline-recognition-only
    choice: Set requiresOnDeviceRecognition = true
    reason: Privacy-first approach, no internet required, consistent with app philosophy
  - id: 30-second-timeout
    choice: Default 30-second timeout for transcription
    reason: Prevents infinite waits if recognizer becomes unresponsive

metrics:
  duration: 3min
  completed: 2026-02-01
---

# Phase 02 Plan 01: Audio Capture and Transcription Foundation Summary

AVAudioEngine microphone capture with buffer streaming to SFSpeechRecognizer, 30s timeout, offline-only recognition.

## What Was Built

### AudioCaptureManager (Sources/OptionC/Audio/AudioCaptureManager.swift)

Microphone audio capture using AVAudioEngine with buffer streaming to speech recognition.

**Key implementation details:**
- `@MainActor` class for thread safety
- Optional `AVAudioEngine` property - fresh instance created per session to avoid state corruption
- `startCapture(request:)` - creates engine, installs tap with bufferSize 1024, starts streaming
- `stopCapture()` - removes tap, stops engine, nils out for complete deallocation
- `isCapturing` computed property based on engine running state
- `[weak self]` in tap closure prevents retain cycles

### TranscriptionEngine (Sources/OptionC/Transcription/TranscriptionEngine.swift)

Speech-to-text transcription using SFSpeechRecognizer with timeout handling.

**Key implementation details:**
- `@MainActor` class for thread safety
- SFSpeechRecognizer initialized with `Locale.current` for user's language
- `requiresOnDeviceRecognition = true` enforces offline transcription
- `transcribe(request:timeout:onPartialResult:completion:)` method with 30s default timeout
- Timer-based timeout restarts on each partial result
- `TranscriptionError` enum: timeout, recognizerUnavailable, noSpeechDetected
- `cancel()` method cleans up timer and recognition task

## Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Engine lifecycle | Fresh AVAudioEngine per session | Avoids state corruption bug documented in research - reusing instances causes tap callback to stop firing |
| Recognition mode | Offline only (requiresOnDeviceRecognition) | Privacy-first, no internet dependency, consistent with app philosophy |
| Timeout strategy | 30-second default, resets on partial results | Prevents infinite waits while allowing long recordings to complete |
| Buffer size | 1024 samples | Standard for low-latency streaming, balances responsiveness and efficiency |

## Verification Results

| Check | Status | Notes |
|-------|--------|-------|
| swift build | PASS | Both files compile without errors |
| AudioCaptureManager structure | PASS | @MainActor, optional engine, startCapture/stopCapture, bufferSize 1024 |
| TranscriptionEngine structure | PASS | @MainActor, Locale.current, timeout handling, offline recognition |
| Files exist | PASS | Audio/ and Transcription/ directories created with files |

## Deviations from Plan

None - plan executed exactly as written.

## Commits

| Hash | Type | Description |
|------|------|-------------|
| 42f20a5 | feat | Add AudioCaptureManager for microphone capture |
| 25b32ff | feat | Add TranscriptionEngine for speech-to-text |

## Next Phase Readiness

**Ready for 02-02:** RecordingController integration

The two foundation classes are complete and ready for integration:

1. **AudioCaptureManager** provides:
   - `startCapture(request:)` - takes SFSpeechAudioBufferRecognitionRequest
   - `stopCapture()` - clean shutdown
   - `isCapturing` - state check

2. **TranscriptionEngine** provides:
   - `transcribe(request:timeout:onPartialResult:completion:)` - processes audio
   - `cancel()` - abort in progress

**Integration pattern for RecordingController:**
```swift
let request = SFSpeechAudioBufferRecognitionRequest()
try audioCaptureManager.startCapture(request: request)
transcriptionEngine.transcribe(request: request) { result in
    // Handle result
}
// Later...
request.endAudio()  // Signal end of audio
audioCaptureManager.stopCapture()
```

**Critical:** Caller must call `request.endAudio()` before stopping audio capture to signal recognizer that audio is complete. TranscriptionEngine expects this from the caller (RecordingController).
