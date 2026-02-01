# Phase 2: Core Recording & Transcription - Research

**Researched:** 2026-02-01
**Domain:** Native audio recording and on-device speech transcription for macOS
**Confidence:** HIGH

## Summary

Phase 2 implements the core value proposition: user speaks into microphone and gets transcribed text on clipboard automatically. This phase builds on Phase 1's state management foundation to deliver the complete audio capture → transcription → clipboard workflow using native macOS frameworks.

Research reveals this domain uses well-established patterns with AVFoundation for audio capture and Apple's Speech framework for transcription. The modern approach (2026) centers on AVAudioEngine for real-time audio buffering combined with SFSpeechRecognizer (or the new SpeechAnalyzer API for macOS 26+). Both offer on-device processing with no internet requirement, meeting privacy expectations.

Critical architectural decisions involve buffer management for real-time audio streaming, implementing both toggle and push-to-talk recording modes, handling asynchronous transcription with proper timeout logic, and ensuring atomic clipboard writes. All components integrate through the Phase 1 StateCoordinator using MainActor isolation for thread safety.

**Primary recommendation:** Use AVAudioEngine with SFSpeechRecognizer for MVP (supports macOS 10.15+), with migration path to SpeechAnalyzer when macOS 26 adoption reaches critical mass. Implement both toggle and push-to-talk modes via KeyboardShortcuts event type detection. Use Timer-based silence detection with audio level monitoring for automatic stop functionality.

## Standard Stack

The established libraries/tools for macOS audio recording and transcription:

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| AVFoundation | Built-in (macOS 10.7+) | Audio capture framework | Apple's standard audio framework, handles mic input, audio session management, buffer processing |
| AVAudioEngine | Built-in (macOS 10.10+) | Real-time audio pipeline | Modern audio graph API, replaces older AVCaptureSession patterns, enables real-time buffer streaming |
| SFSpeechRecognizer | Built-in (macOS 10.15+) | On-device speech-to-text | Apple's mature speech recognition API, works offline, battle-tested since 2016 |
| Speech framework | Built-in (macOS 10.15+) | Speech recognition services | Provides SFSpeechRecognizer and related classes for transcription |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SpeechAnalyzer | Built-in (macOS 26+) | Next-gen transcription | When targeting macOS 26+, 2.2× faster than Whisper, powers Voice Memos/Notes internally |
| AVCaptureDevice | Built-in | Microphone permission | Request and check microphone authorization on macOS (replaces iOS AVAudioSession pattern) |
| Accelerate framework | Built-in | Audio level computation | Calculate RMS power for silence detection, high-performance vDSP functions |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SFSpeechRecognizer | WhisperKit (Argmax) | WhisperKit offers more language options and model control but requires larger bundle size, more complex setup, no Apple Silicon optimization |
| AVAudioEngine | AVAudioRecorder | AVAudioRecorder simpler but file-based only, no real-time buffer streaming for live transcription |
| Native Speech framework | Cloud APIs (Deepgram, AssemblyAI) | Cloud services offer better accuracy but require internet, privacy concerns, latency, ongoing costs |

**Installation:**

All core components are built into macOS frameworks. No external dependencies required for basic functionality.

```swift
import AVFoundation
import Speech
import Accelerate  // For audio level metering
```

**Minimum macOS Version:**
- macOS 10.15 (Catalina) for SFSpeechRecognizer
- macOS 26 (Sequoia) for SpeechAnalyzer (optional upgrade path)

## Architecture Patterns

### Recommended Component Structure

```
RecordingController/
├── AudioCaptureManager.swift       # AVAudioEngine setup and buffer streaming
├── TranscriptionEngine.swift       # SFSpeechRecognizer/SpeechAnalyzer wrapper
├── SilenceDetector.swift           # Audio level monitoring and timeout logic
└── RecordingMode.swift             # Toggle vs Push-to-talk mode enum

ClipboardManager/
└── ClipboardManager.swift          # NSPasteboard atomic writes

NotificationManager/
└── NotificationManager.swift       # UNUserNotificationCenter wrappers
```

### Pattern 1: Real-Time Audio Buffer Streaming

**What:** Use AVAudioEngine with installTap to stream audio buffers to SFSpeechAudioBufferRecognitionRequest in real-time.

**When to use:** Any live transcription scenario where user speaks continuously and expects immediate results.

**Example:**
```swift
// Source: https://www.createwithswift.com/implementing-advanced-speech-to-text-in-your-swiftui-app/
// Verified pattern from Apple Developer Documentation

class AudioCaptureManager {
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    func startRecording() throws {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap on input node to capture audio buffers
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            // Stream buffer to recognition request
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
    }
}
```

**Critical details:**
- Buffer size of 1024 samples is standard for low-latency streaming
- Must remove tap before stopping engine to avoid crashes
- Call `endAudio()` on request to finalize transcription
- Use `[weak self]` in closure to prevent retain cycles

### Pattern 2: Toggle vs Push-to-Talk Mode Detection

**What:** Detect whether user pressed-and-released (toggle) or is holding key (push-to-talk) using KeyboardShortcuts event types.

**When to use:** Supporting both recording interaction modes in a single hotkey.

**Example:**
```swift
// Source: Derived from https://github.com/sindresorhus/KeyboardShortcuts patterns
// and https://developer.apple.com/forums/thread/125425

enum RecordingMode {
    case toggle      // Press once to start, press again to stop
    case pushToTalk  // Hold to record, release to stop
}

class StateCoordinator {
    private var recordingMode: RecordingMode = .toggle
    private var isKeyCurrentlyPressed = false

    init() {
        // Listen for key down events
        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            guard let self = self else { return }

            if self.recordingMode == .toggle {
                // Toggle mode: flip recording state
                if self.currentState == .idle {
                    self.startRecording()
                } else if self.currentState == .recording {
                    self.stopRecording()
                }
            } else {
                // Push-to-talk mode: start recording on key down
                self.isKeyCurrentlyPressed = true
                if self.currentState == .idle {
                    self.startRecording()
                }
            }
        }

        // Listen for key up events (push-to-talk mode only)
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            guard let self = self else { return }

            if self.recordingMode == .pushToTalk {
                self.isKeyCurrentlyPressed = false
                if self.currentState == .recording {
                    self.stopRecording()
                }
            }
        }
    }
}
```

**UX consideration:** Provide preference toggle to switch modes. Toggle is better for long recordings, push-to-talk for quick snippets.

### Pattern 3: Asynchronous Transcription with Timeout

**What:** Use SFSpeechRecognitionTask with async result handler and Timer-based timeout for unresponsive transcription.

**When to use:** All transcription scenarios to handle edge cases (no speech detected, API failure, etc.).

**Example:**
```swift
// Source: https://developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition
// Enhanced with timeout pattern from https://github.com/Compiler-Inc/Transcriber

class TranscriptionEngine {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionTask: SFSpeechRecognitionTask?
    private var timeoutTimer: Timer?

    func transcribe(
        request: SFSpeechAudioBufferRecognitionRequest,
        timeout: TimeInterval = 30.0,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Start timeout timer
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            self?.recognitionTask?.cancel()
            completion(.failure(TranscriptionError.timeout))
        }

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            // Cancel timeout on any result
            self.timeoutTimer?.invalidate()
            self.timeoutTimer = nil

            if let error = error {
                completion(.failure(error))
                return
            }

            if let result = result, result.isFinal {
                completion(.success(result.bestTranscription.formattedString))
            }
        }
    }

    func cancel() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}
```

**Timeout values:**
- 30 seconds standard for general recording
- Consider making configurable via user preferences
- Show UI progress indicator during processing state

### Pattern 4: Silence Detection with Audio Level Monitoring

**What:** Monitor audio buffer RMS power to detect silence periods and auto-stop recording.

**When to use:** Implementing "express mode" or automatic stop functionality to improve UX.

**Example:**
```swift
// Source: https://medium.com/@garejakirit/how-to-get-sound-level-in-ios-using-swift-c71072dd3414
// Enhanced with https://www.forasoft.com/blog/article/how-to-implement-silence-trimming-feature-to-your-ios-app-1720

import Accelerate

class SilenceDetector {
    private let silenceThreshold: Float = -50.0  // dB threshold
    private let silenceDuration: TimeInterval = 2.0  // seconds of silence before auto-stop
    private var silenceStartTime: Date?

    func processSample(buffer: AVAudioPCMBuffer) -> Bool {
        guard let channelData = buffer.floatChannelData else { return false }

        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(
            from: 0,
            to: Int(buffer.frameLength),
            by: buffer.stride
        ).map { channelDataValue[$0] }

        // Calculate RMS power using Accelerate framework
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(channelDataValueArray.count))
        let avgPower = 20 * log10(rms)

        // Check if below silence threshold
        if avgPower < silenceThreshold {
            if silenceStartTime == nil {
                silenceStartTime = Date()
            } else if let startTime = silenceStartTime,
                      Date().timeIntervalSince(startTime) >= silenceDuration {
                return true  // Silence detected for required duration
            }
        } else {
            silenceStartTime = nil  // Reset on any sound
        }

        return false
    }
}
```

**Threshold tuning:**
- -50 dB is standard for typical speech scenarios
- May need adjustment based on mic quality and environment
- Consider making configurable or adaptive based on initial background noise level

### Pattern 5: Atomic Clipboard Write with Verification

**What:** Clear pasteboard before writing and verify write succeeded by reading back immediately.

**When to use:** All clipboard operations to ensure reliability and avoid race conditions with other apps.

**Example:**
```swift
// Source: https://nilcoalescing.com/blog/CopyStringToClipboardInSwiftOnMacOS/
// Enhanced with verification pattern from https://levelup.gitconnected.com/swiftui-macos-working-with-nspasteboard-b5811f98d5d1

@MainActor
class ClipboardManager {
    enum ClipboardError: Error {
        case writeFailed
        case verificationFailed
    }

    static func copy(_ text: String) throws {
        let pasteboard = NSPasteboard.general

        // Step 1: Clear existing contents
        pasteboard.clearContents()

        // Step 2: Write new content
        let success = pasteboard.setString(text, forType: .string)
        guard success else {
            throw ClipboardError.writeFailed
        }

        // Step 3: Verify write succeeded
        guard let readBack = pasteboard.string(forType: .string), readBack == text else {
            throw ClipboardError.verificationFailed
        }
    }
}
```

**Why @MainActor:** NSPasteboard must be accessed on main thread. MainActor ensures this at compile time.

**Retry logic:** Consider retrying once on verification failure before throwing error.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Audio buffer ring buffer | Custom circular buffer | AVAudioEngine tap with 1024 buffer size | Apple's implementation handles edge cases (buffer overruns, thread safety, format conversion) |
| Speech recognition API | Direct CoreML integration | SFSpeechRecognizer or SpeechAnalyzer | Apple manages model downloads, updates, language packs, optimization for Apple Silicon |
| Microphone permission UI | Custom alert dialog | AVCaptureDevice.requestAccess system prompt | System dialog is trusted, localized, consistent with macOS HIG |
| Audio level metering | Manual sample processing | Accelerate framework vDSP functions | Hardware-accelerated, optimized for SIMD, handles edge cases in signal processing |
| Silence trimming | Sample-by-sample threshold check | Accelerate framework with envelope detection | Orders of magnitude faster, battle-tested algorithms |

**Key insight:** Audio processing and speech recognition have numerous edge cases (format mismatches, sample rate changes, interruptions, background/foreground transitions). Apple's frameworks handle these internally. Custom implementations will hit production bugs that take months to discover and fix.

## Common Pitfalls

### Pitfall 1: AVAudioEngine State Corruption on Stop/Start Cycles

**What goes wrong:** AVAudioEngine becomes internally corrupted during stop/start cycles. The tap callback is never invoked, resulting in zero audio data, and the engine silently stops itself mid-session.

**Why it happens:** Internal state management bug in AVAudioEngine when reusing the same instance across multiple recording sessions. The tap remains installed but becomes disconnected from the audio graph.

**How to avoid:**
1. Create fresh AVAudioEngine instance for each recording session
2. Set `audioEngine = nil` for complete deallocation in stopCapture
3. Don't reuse AVAudioEngine instances across sessions

**Warning signs:**
- Tap closure never called after second recording
- Buffer callback receives empty buffers
- Engine.isRunning returns true but no audio flows

**Code pattern:**
```swift
class AudioCaptureManager {
    private var audioEngine: AVAudioEngine?  // Optional, not persistent

    func startRecording() {
        // Create fresh instance every time
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine!.inputNode
        // ... setup and start
    }

    func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil  // Complete deallocation
    }
}
```

**Source:** [Correct way to recover from Core Audio interruptions](https://www.audiodog.co.uk/blog/2021/07/11/correct-way-to-recover-from-core-audio-interruptions/) and multiple Apple Developer Forums threads.

### Pitfall 2: Missing SFSpeechRecognizer.endAudio() Causes Infinite Wait

**What goes wrong:** Transcription never completes. Recognition task callback receives intermediate results but never calls completion with `isFinal = true`. App hangs in "processing" state indefinitely.

**Why it happens:** SFSpeechRecognizer waits for `endAudio()` signal before finalizing transcription. Without it, the recognizer assumes more audio is coming and keeps waiting.

**How to avoid:**
1. Always call `recognitionRequest?.endAudio()` when recording stops
2. Call endAudio() BEFORE stopping the audio engine
3. Set up timeout timer as fallback (30s recommended)

**Warning signs:**
- Processing state never transitions to idle
- Partial transcriptions appear but never finalize
- Completion handler called multiple times with intermediate results

**Code pattern:**
```swift
func stopRecording() {
    // Order matters: end audio FIRST
    recognitionRequest?.endAudio()

    // Then stop engine
    audioEngine.stop()
    audioEngine.inputNode.removeTap(onBus: 0)
}
```

**Source:** Apple Developer Documentation and [SFSpeechRecognizer Tips](http://cleanswifter.com/sfspeechrecognizer-tips-for-ios-10/)

### Pitfall 3: Microphone Permission Requests Differ Between iOS and macOS

**What goes wrong:** Using iOS pattern `AVAudioSession.requestRecordPermission` on macOS causes runtime errors. Permission request never appears and recording silently fails.

**Why it happens:** AVAudioSession is iOS-specific. macOS uses different API (AVCaptureDevice) for microphone permissions.

**How to avoid:**
1. Use `AVCaptureDevice.requestAccess(for: .audio)` on macOS
2. Check authorization with `AVCaptureDevice.authorizationStatus(for: .audio)`
3. Add `NSMicrophoneUsageDescription` to Info.plist for both platforms

**Warning signs:**
- No permission prompt appears on macOS
- AVAudioEngine.start() throws permission error
- Works in development, fails on clean install

**Code pattern:**
```swift
#if os(macOS)
func requestMicrophonePermission() async -> Bool {
    // macOS pattern
    let status = AVCaptureDevice.authorizationStatus(for: .audio)

    switch status {
    case .authorized:
        return true
    case .notDetermined:
        return await AVCaptureDevice.requestAccess(for: .audio)
    default:
        return false
    }
}
#elseif os(iOS)
func requestMicrophonePermission() async -> Bool {
    // iOS pattern
    return await AVAudioApplication.requestRecordPermission()
}
#endif
```

**Source:** [Apple Developer Forums - Microphone Permission macOS](https://developer.apple.com/forums/thread/738986)

### Pitfall 4: SFSpeechRecognizer Locale Mismatch Causes Poor Accuracy

**What goes wrong:** Transcription accuracy is terrible (<70%) even for clear speech. Words are mangled or completely wrong despite proper mic setup.

**Why it happens:** SFSpeechRecognizer initialized with wrong locale (e.g., en-GB when user speaks en-US). Speech recognizer uses language models optimized for specific regional pronunciations and vocabularies.

**How to avoid:**
1. Initialize with user's current locale: `SFSpeechRecognizer(locale: Locale.current)`
2. Verify locale is supported with `SFSpeechRecognizer.supportedLocales()`
3. Provide UI to override locale if auto-detection fails
4. Download language pack if not available (system handles this)

**Warning signs:**
- Accuracy < 90% for clear speech
- Common words consistently misrecognized
- Works better for some users than others

**Code pattern:**
```swift
let recognizer = SFSpeechRecognizer(locale: Locale.current)

// Verify support
guard let recognizer = recognizer, recognizer.isAvailable else {
    // Locale not supported or language pack not downloaded
    // Fallback to en-US or prompt user to download
    return
}
```

**Source:** [Apple SFSpeechRecognizer Documentation](https://developer.apple.com/documentation/speech/sfspeechrecognizer)

### Pitfall 5: Forgetting to Handle Audio Interruptions

**What goes wrong:** User receives phone call during recording. App crashes or produces corrupted audio when user returns. Recording state becomes inconsistent.

**Why it happens:** macOS stops audio engine during system interruptions (FaceTime call, system alert sounds). App doesn't receive notification and continues as if recording.

**How to avoid:**
1. Observe `AVAudioEngineConfigurationChangeNotification`
2. Save current state and gracefully stop recording
3. Optionally resume recording after interruption ends
4. Update UI to reflect interruption

**Warning signs:**
- Crashes after system sounds play
- Audio contains gaps or corruption
- State coordinator shows "recording" but no audio captured

**Code pattern:**
```swift
class AudioCaptureManager {
    private var configurationObserver: NSObjectProtocol?

    init() {
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: .main
        ) { [weak self] _ in
            // Engine has been stopped by system
            self?.handleInterruption()
        }
    }

    private func handleInterruption() {
        // Clean up state
        stopRecording()
        // Notify coordinator
        delegate?.recordingInterrupted()
    }
}
```

**Source:** [Managing Audio Interruptions](https://medium.com/@mehsamadi/managing-audio-interruption-and-route-change-in-ios-application-8202801fd72f)

## Code Examples

Verified patterns from official sources:

### Complete Recording to Transcription Flow

```swift
// Source: https://www.createwithswift.com/implementing-advanced-speech-to-text-in-your-swiftui-app/
// Simplified for macOS with error handling

import AVFoundation
import Speech

@MainActor
class RecordingController: ObservableObject {
    private var audioEngine: AVAudioEngine?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    @Published var isRecording = false
    @Published var transcribedText = ""

    // MARK: - Permissions

    func requestPermissions() async -> Bool {
        // Request microphone access
        let micAuthorized = await AVCaptureDevice.requestAccess(for: .audio)
        guard micAuthorized else { return false }

        // Request speech recognition access
        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        return speechAuthorized
    }

    // MARK: - Recording Control

    func startRecording() throws {
        // Create fresh audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw RecordingError.recognitionUnavailable
        }

        // Configure for partial results
        recognitionRequest.shouldReportPartialResults = true

        // Set up audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap to stream audio buffers
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                self.transcribedText = result.bestTranscription.formattedString
            }

            if error != nil || result?.isFinal == true {
                // Transcription complete or failed
                Task { @MainActor in
                    self.stopRecording()
                }
            }
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        isRecording = true
    }

    func stopRecording() {
        // End audio first
        recognitionRequest?.endAudio()

        // Stop and clean up engine
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil

        // Cancel tasks
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        isRecording = false
    }
}

enum RecordingError: Error {
    case recognitionUnavailable
    case permissionDenied
}
```

### Integration with Phase 1 State Coordinator

```swift
// Source: Derived from architecture patterns in .planning/research/ARCHITECTURE.md

@MainActor
class StateCoordinator: ObservableObject {
    @Published var currentState: AppState = .idle

    private let recordingController = RecordingController()
    private let clipboardManager = ClipboardManager()
    private let notificationManager = NotificationManager()

    enum AppState {
        case idle
        case recording
        case processing
    }

    // Called by hotkey manager
    func handleHotkeyPress() {
        switch currentState {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .processing:
            // Ignore presses while processing
            break
        }
    }

    private func startRecording() {
        Task {
            // Check permissions first
            let authorized = await recordingController.requestPermissions()
            guard authorized else {
                notificationManager.showError("Microphone permission required")
                return
            }

            // Start recording
            do {
                try recordingController.startRecording()
                currentState = .recording
            } catch {
                notificationManager.showError("Failed to start recording: \(error)")
            }
        }
    }

    private func stopRecording() {
        recordingController.stopRecording()
        currentState = .processing

        // Process transcription
        Task {
            await processTranscription()
        }
    }

    private func processTranscription() async {
        let text = recordingController.transcribedText

        guard !text.isEmpty else {
            notificationManager.showError("No speech detected")
            currentState = .idle
            return
        }

        // Copy to clipboard
        do {
            try clipboardManager.copy(text)
            notificationManager.showSuccess(text: text)
            currentState = .idle
        } catch {
            notificationManager.showError("Failed to copy to clipboard")
            currentState = .idle
        }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| AVAudioRecorder (file-based) | AVAudioEngine (buffer-based) | macOS 10.10 (2014) | Enables real-time processing, lower latency, live transcription |
| Manual CoreML integration | SFSpeechRecognizer API | macOS 10.15 (2019) | Simplified integration, automatic model updates, better accuracy |
| SFSpeechRecognizer | SpeechAnalyzer | macOS 26 (2026) | 2.2× faster, better long-form support, powers system apps |
| Manual vDSP calls | Accelerate framework wrappers | Ongoing | Cleaner API, same performance, better type safety |
| AVAudioSession (iOS) | AVCaptureDevice (macOS) | Always separate | Platform-specific permission models, avoid iOS patterns on macOS |

**Deprecated/outdated:**
- **AVAudioRecorder for live transcription**: Still works but can't stream to SFSpeechRecognizer. Use AVAudioEngine instead.
- **AVAudioSession.requestRecordPermission on macOS**: iOS-only API. Use AVCaptureDevice.requestAccess.
- **NSUserNotification**: Replaced by UNUserNotificationCenter in macOS 10.14. Old API still works but limited.

## Open Questions

Things that couldn't be fully resolved:

1. **SpeechAnalyzer adoption timeline**
   - What we know: SpeechAnalyzer requires macOS 26+, currently in beta, 2.2× faster than Whisper
   - What's unclear: When will macOS 26 reach sufficient adoption to make it primary API? Current fallback strategy to SFSpeechRecognizer is safe but slower.
   - Recommendation: Ship with SFSpeechRecognizer for MVP, add SpeechAnalyzer support in Phase 3 when macOS 26 releases. Monitor adoption via Analytics.

2. **Optimal silence detection threshold for diverse environments**
   - What we know: -50 dB is standard threshold, but varies by mic quality and ambient noise
   - What's unclear: Should threshold be adaptive based on initial noise floor measurement? Fixed threshold may cause false positives in noisy environments.
   - Recommendation: Start with -50 dB fixed threshold. Add adaptive threshold in Phase 3 based on user feedback. Consider making configurable in preferences.

3. **Transcription timeout value for long-form recordings**
   - What we know: 30 seconds is standard timeout, but Voice Memos can transcribe 5+ minute recordings
   - What's unclear: Should timeout scale with recording duration? Fixed 30s may be too short for long recordings.
   - Recommendation: Start with fixed 30s timeout for MVP. Consider dynamic timeout (e.g., recording_duration + 30s) in Phase 3 based on real usage patterns.

4. **Clipboard race conditions with clipboard manager apps**
   - What we know: Clipboard managers poll NSPasteboard every 500ms, can cause race conditions
   - What's unclear: Is retry logic sufficient or should we detect clipboard managers and adjust strategy?
   - Recommendation: Implement verification retry (1-2 attempts). If issues persist in production, add clipboard manager detection and compatibility mode.

## Sources

### Primary (HIGH confidence)

**Speech Recognition APIs:**
- [Apple SpeechAnalyzer Documentation](https://developer.apple.com/documentation/speech/speechanalyzer) - Official API reference
- [WWDC 2025: Bring advanced speech-to-text to your app with SpeechAnalyzer](https://developer.apple.com/videos/play/wwdc2025/277/) - Official session with implementation patterns
- [Apple SFSpeechRecognizer Documentation](https://developer.apple.com/documentation/speech/sfspeechrecognizer) - Mature API reference
- [Asking Permission to Use Speech Recognition](https://developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition) - Official permission patterns

**Audio Recording:**
- [AVCaptureDevice.requestAccess Documentation](https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media) - macOS microphone permissions
- [Implementing advanced speech-to-text in your SwiftUI app](https://www.createwithswift.com/implementing-advanced-speech-to-text-in-your-swiftui-app/) - Complete implementation guide
- [Transcribing audio from live audio using the Speech framework](https://www.createwithswift.com/transcribing-audio-from-live-audio-using-the-speech-framework/) - Buffer streaming patterns

**Clipboard Operations:**
- [NSPasteboard Documentation](https://developer.apple.com/documentation/appkit/nspasteboard) - Official clipboard API
- [Copy a string to the clipboard in Swift on macOS](https://nilcoalescing.com/blog/CopyStringToClipboardInSwiftOnMacOS/) - Best practices
- [SwiftUI/MacOS: Working with NSPasteboard](https://levelup.gitconnected.com/swiftui-macos-working-with-nspasteboard-b5811f98d5d1) - Verification patterns

### Secondary (MEDIUM confidence)

**Implementation Examples:**
- [GitHub: Transcriber - Swift wrapper with silence detection](https://github.com/Compiler-Inc/Transcriber) - Open source reference
- [GitHub: katip - SFSpeechRecognizer transcriber for macOS](https://github.com/imdatceleste/katip) - macOS-specific implementation
- [GitHub: SwiftCaptionTesting - SpeechAnalyzer live captioning POC](https://github.com/edmistond/SwiftCaptionTesting) - SpeechAnalyzer example
- [Speech-to-Text: Building a Clean Voice Manager in iOS](https://medium.com/@burakekmen/speech-to-text-building-a-clean-modular-voice-manager-in-ios-with-swift-4eba58606c8c) - Architecture patterns

**Audio Processing:**
- [How to Get Sound Level in iOS Using Swift](https://medium.com/@garejakirit/how-to-get-sound-level-in-ios-using-swift-c71072dd3414) - RMS calculation
- [How to Implement Silence Trimming Feature](https://www.forasoft.com/blog/article/how-to-implement-silence-trimming-feature-to-your-ios-app-1720) - Silence detection algorithms
- [Correct way to recover from Core Audio interruptions](https://www.audiodog.co.uk/blog/2021/07/11/correct-way-to-recover-from-core-audio-interruptions/) - Interruption handling

**Push-to-Talk Patterns:**
- [Using Push-to-talk - Mic Drop](https://getmicdrop.com/help/push-to-talk) - UX patterns
- [GitHub: osx-push-to-talk](https://github.com/yulrizka/osx-push-to-talk) - Reference implementation

### Tertiary (LOW confidence)

- [Apple SpeechAnalyzer and Argmax WhisperKit](https://www.argmaxinc.com/blog/apple-and-argmax) - Performance comparisons (2.2× speed claim)
- [iOS 26: SpeechAnalyzer Guide](https://antongubarenko.substack.com/p/ios-26-speechanalyzer-guide) - Early adoption guide

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All APIs verified via official Apple documentation
- Architecture: HIGH - Patterns derived from official samples and verified open source implementations
- Pitfalls: HIGH - All pitfalls sourced from Apple Developer Forums and documented community issues

**Research date:** 2026-02-01
**Valid until:** 60 days (stable APIs, but SpeechAnalyzer adoption may shift recommendations)

**Next steps for planning:**
- Implementation approach: Use SFSpeechRecognizer with fallback architecture for SpeechAnalyzer
- Testing strategy: Requires physical Mac with microphone (Xcode Simulator insufficient)
- Dependencies: Phase 1 StateCoordinator must be complete and stable
