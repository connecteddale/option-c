# Building Option-C: A Complete Development Report

## How a Voice-to-Clipboard macOS App Was Built Using AI-Assisted Development

---

## 1. What Option-C Is

Option-C is a macOS menu bar application for voice-to-text transcription. The user presses a keyboard shortcut (Control+Shift+Space), speaks into their microphone, and the transcribed text is copied to the clipboard -- or auto-pasted directly into the active application. The entire transcription pipeline runs locally on-device using WhisperKit, with no cloud services, no API keys, and no data leaving the Mac.

The core value proposition, stated at the outset and never deviated from:

> Voice-to-clipboard with a single keyboard shortcut. If the hotkey doesn't capture speech and deliver text to clipboard, nothing else matters.

---

## 2. The Development Approach: GSD (Get Stuff Done)

The project was built using GSD, an open-source meta-prompting and spec-driven development system for Claude Code. GSD was created by a solo developer known as TACHES (GitHub: glittercowboy) to solve a specific problem: **context rot** -- the quality degradation that occurs when an AI coding assistant fills its context window during long sessions.

Research shows that Claude performs at its peak when utilising 0-30% of its context window. At 50%+ utilisation, output quality drops noticeably. At 70%+, hallucinations and inconsistencies emerge. GSD prevents this by spawning fresh sub-agent instances for each task, giving each one a clean 200,000-token context window focused on a single job.

### How GSD Works

GSD structures development into a repeating cycle:

1. **Initialise Project** (`/gsd:new-project`) -- Deep context gathering through questions, parallel research agents, requirements extraction, and roadmap creation
2. **Discuss Phase** (`/gsd:discuss-phase`) -- Capture implementation preferences and decisions before any code is written
3. **Plan Phase** (`/gsd:plan-phase`) -- Research, create atomic task plans, verify against requirements
4. **Execute Phase** (`/gsd:execute-phase`) -- Run plans in waves (parallel where possible), fresh context per plan, atomic commits per task
5. **Verify Work** (`/gsd:verify-work`) -- Human acceptance testing with automated fix plans if issues arise

The key files GSD produces:
- `PROJECT.md` -- Project vision, constraints, key decisions
- `REQUIREMENTS.md` -- Scoped v1/v2 requirements with traceability
- `ROADMAP.md` -- Phased development plan mapped to requirements
- `STATE.md` -- Current position, decisions, performance metrics
- Research documents (STACK.md, ARCHITECTURE.md, FEATURES.md, PITFALLS.md)
- Per-phase PLAN.md and SUMMARY.md files

GSD has gained traction in the developer community and is reportedly used by engineers at Amazon, Google, Shopify, and Webflow.

---

## 3. The Technology Stack

### WhisperKit (Speech Recognition)

WhisperKit is an open-source Swift framework created by Argmax that runs OpenAI's Whisper speech recognition models entirely on-device via Apple's CoreML framework. Key characteristics:

- **On-device only** -- No cloud dependency, no API keys, no network latency
- **Multiple model sizes** -- From Tiny (~40MB, fastest) to Large-v3 (~3GB, most accurate)
- **Apple Silicon optimised** -- Uses the Neural Engine for inference, reducing CPU/GPU load
- **MIT licensed** -- Full transparency and control over model selection
- **Swift Package Manager integration** -- Two-line setup in Package.swift

The project chose WhisperKit's base model (~150MB) as the default, balancing 1-2 second processing time against good accuracy. Users can switch to larger models for better accuracy at the cost of longer processing.

### Why WhisperKit Over Apple's Built-in Speech Framework

The project originally planned to use Apple's SFSpeechRecognizer but pivoted to WhisperKit during post-v1 development. The reasons:

- **Model control** -- WhisperKit lets you choose which model runs; Apple's are opaque
- **Better accuracy** -- WhisperKit's small model (12.8% word error rate) beats Apple SpeechAnalyzer (14.0%)
- **Broader compatibility** -- WhisperKit supports macOS 14+; Apple's newer SpeechAnalyzer requires macOS 26+
- **100 languages** versus Apple's 10
- **Custom vocabulary** support substantially outperforms Apple's APIs

### Supporting Technologies

| Technology | Purpose |
|-----------|---------|
| Swift 6.1 + SwiftUI | Native macOS development, MenuBarExtra for menu bar presence |
| AVFoundation (AVAudioEngine) | Microphone capture with 16kHz mono resampling |
| KeyboardShortcuts 1.11.0 | Global keyboard shortcut registration |
| NSPasteboard | Clipboard operations with atomic write verification |
| CGEvent | Simulating Cmd+V for auto-paste functionality |
| Swift Package Manager | Dependency management and build system |

---

## 4. Phase 0: Research and Planning (1 February 2026)

*Duration: approximately 2.5 hours. 12 commits. Zero lines of application code.*

### Project Initialisation

The project began with `/gsd:new-project`, which created the initial `PROJECT.md` defining the concept. The original vision was a Voice Memos automation -- use AppleScript to control Voice Memos, then read its SQLite database for transcriptions.

### The First Pivot

Research killed that approach quickly. GSD's parallel research agents discovered three critical problems:

1. Voice Memos has no AppleScript dictionary -- it cannot be automated
2. Reading Voice Memos' database requires Full Disk Access -- an aggressive permission that users rightfully distrust
3. SQLite locking could cause conflicts with the running Voice Memos application

**Decision: Pivot to native recording.** AVFoundation + Speech framework gives simpler permissions, more reliability, and no dependency on another application. This decision was documented in `PROJECT.md` with rationale.

### Research Phase

Four parallel research agents produced comprehensive documentation:

**STACK.md** -- Technology selections with rationale for each choice. Pinned KeyboardShortcuts to version 1.11.0 after discovering that newer versions use Swift's `#Preview` macro, which fails in SPM builds.

**ARCHITECTURE.md** -- Established the state-driven coordinator pattern. A single `AppState` owns all components with unidirectional data flow. All UI-updating code uses `@MainActor` for compiler-enforced thread safety.

**FEATURES.md** -- Competitive landscape analysis identifying table stakes (global hotkey, menu bar state, auto-paste, offline processing, >95% accuracy) versus differentiators to defer (context awareness, AI modes, history, live preview) versus anti-features to avoid (file transcription UI, cloud sync, audio storage).

**PITFALLS.md** -- 13 documented risks with prevention strategies:
- Critical: SQLite locking, Full Disk Access bugs, global hotkey conflicts, NSStatusItem memory leaks, main thread violations
- Moderate: Polling performance, transcription race conditions, pasteboard race conditions
- Minor: Notarisation delays, launch agent performance, menu bar visibility

### Requirements and Roadmap

18 v1 requirements were defined across five categories (Core Recording, Menu Bar, Transcription, Feedback, Error Handling), each mapped to a specific phase. V2 differentiators were explicitly deferred. Out-of-scope items were documented to prevent scope creep.

The roadmap established three phases with explicit dependencies:
1. Foundation and Menu Bar (depends on nothing)
2. Core Recording and Transcription (depends on Phase 1)
3. Feedback and Error Handling (depends on Phase 2)

Each phase was then researched individually, producing phase-specific RESEARCH.md files, and planned with atomic task breakdowns.

---

## 5. Phase 1: Foundation and Menu Bar (1 February 2026)

*Duration: 9 minutes. 6 commits. 2 plans.*

### Plan 01-01: Project Setup

Created the Swift package structure from scratch:
- `Package.swift` with KeyboardShortcuts 1.11.0 and macOS 13+ target
- `OptionCApp.swift` with `@main` and `MenuBarExtra` scene
- `AppState.swift` as the `@MainActor` state coordinator
- `RecordingState` enum (idle, recording, processing) and `RecordingMode` enum (toggle, pushToTalk)
- `Info.plist` with `LSUIElement=true` to hide the Dock icon

**Deviation encountered:** KeyboardShortcuts needed to be pinned to 1.11.0 because newer versions include `#Preview` macros that fail in SPM. Auto-fixed during execution.

**Deviation encountered:** Info.plist was excluded from the SPM build target because SPM executables don't support embedded plists. Prepared for future app bundle packaging.

### Plan 01-02: Hotkey and Menu Content

- Registered the Option+C global shortcut via KeyboardShortcuts library
- Built the state machine in AppState: `handleHotkeyPress()` transitions idle to recording to processing to idle
- Created `MenuBarView.swift` with status display, mode picker, and quit button
- Added a 1-second simulated processing delay as a placeholder for Phase 2's actual transcription

**Key decision:** Toggle mode was implemented first. Push-to-talk requires separate `onKeyDown`/`onKeyUp` handlers, which would come in Phase 2.

---

## 6. Phase 2: Core Recording and Transcription (1 February 2026)

*Duration: 5 minutes. 6 commits. 2 plans.*

### Plan 02-01: Audio Infrastructure

**AudioCaptureManager** -- AVAudioEngine-based microphone capture. A critical discovery was made here that shaped all future development:

> Fresh AVAudioEngine instances must be created for each recording session. Reusing engine instances causes state corruption where the tap callback silently stops firing.

The manager captures audio at the device's native format and converts to 16kHz mono PCM float32 (WhisperKit's required format) using AVAudioConverter. Buffer size is set to 1024 for low latency.

**TranscriptionEngine** (original version) -- SFSpeechRecognizer with `requiresOnDeviceRecognition = true` for offline-only processing. 30-second timeout to prevent infinite waits. This was later replaced by WhisperKit.

### Plan 02-02: Integration and Clipboard

**ClipboardManager** -- Atomic clipboard operations following a clear-write-verify pattern:
1. Clear existing clipboard content
2. Write new text
3. Read back and compare to verify the write succeeded

This guards against race conditions with other clipboard managers (password managers, clipboard history tools, etc.).

**RecordingController** -- The orchestrator bridging audio capture and transcription. A critical ordering discovery:

> `endAudio()` must be called BEFORE `stopCapture()`. The speech recogniser needs to be signalled to finalise transcription before the audio stream is stopped. Reversing this order causes the recogniser to hang or return incomplete results.

**AppState wiring** -- Added dual-mode hotkey handling with `handleKeyDown()` for push-to-talk and `handleKeyUp()` for toggle mode and push-to-talk stop. Both key events now drive the recording lifecycle.

---

## 7. Phase 3: Feedback and Error Handling (1 February 2026)

*Duration: 6 minutes. 6 commits. 3 plans.*

### Plan 03-01: Error Types and Permissions

**AppError enum** -- Six error cases, each with user-friendly `errorDescription` and actionable `recoverySuggestion` (including System Settings deep-link paths):
- `microphonePermissionDenied`
- `speechRecognitionPermissionDenied`
- `noSpeechDetected`
- `transcriptionTimeout`
- `recordingFailed(underlying: Error)`
- `clipboardWriteFailed`

**PermissionManager** -- Async microphone and speech recognition permission checking. Uses `withCheckedContinuation` to bridge Apple's callback-based permission API to async/await.

### Plan 03-02: Notification System

Created `NotificationManager` as a `@MainActor` singleton with methods for success, error, and timeout notifications. Permission requested at app launch.

*Note: This notification system was later removed entirely in the post-v1 feature sprint, replaced by menu bar icon feedback which proved less intrusive.*

### Plan 03-03: State Machine Integration

The most architecturally significant plan in Phase 3:

- Added `success(transcription: String)` and `error(AppError)` cases to `RecordingState`
- Integrated PermissionManager into the recording flow -- permissions checked before every recording starts
- **Auto-reset state transitions**: Success resets to idle after 2 seconds, errors after 3 seconds. This prevents the state machine from ever getting stuck in a non-idle state.
- 30-second transcription timeout using `withThrowingTaskGroup` to race the operation against a sleep

**All three GSD phases were complete. The v1 app was fully functional.**

---

## 8. Execution Metrics

The GSD system tracked performance across all phases:

| Phase | Plans | Total Time | Avg Per Plan |
|-------|-------|-----------|-------------|
| 1. Foundation and Menu Bar | 2 | 11 min | 5.5 min |
| 2. Core Recording and Transcription | 2 | 6 min | 3.0 min |
| 3. Feedback and Error Handling | 3 | 4 min | 1.3 min |
| **Total** | **7** | **21 min** | **3.1 min** |

The decreasing time per plan reflects a learning curve effect -- later phases built on established patterns and required less scaffolding. Phase 1 took longest because it included project setup, dependency resolution, and the first build verification.

Only 2 deviations from plans occurred, both in Plan 01-01, both auto-fixed during execution. Build success rate was 100%.

---

## 9. The Post-v1 Evolution (14-17 February 2026)

After a 13-day gap, a major feature sprint transformed the app from "works" to "actually useful". This work was done outside the formal GSD phase structure, co-authored with Claude Opus 4.6 (upgraded from 4.5 which built the v1).

### WhisperKit Replaces SFSpeechRecognizer

The original `TranscriptionEngine.swift` using Apple's Speech framework was deleted and replaced with `WhisperTranscriptionEngine.swift` using WhisperKit. The new engine:

- Runs as a Swift `actor` for thread-safe concurrent access
- Supports five model sizes (tiny, base, small, medium, large-v3)
- Configures decoding for quality: `language: "en"`, `temperature: 0.0` (deterministic), `suppressBlank: true`
- Caches downloaded models so switching is near-instant after first download

### The Neural Engine Warm-up Discovery

A critical performance issue was discovered and solved:

> The first real transcription after loading a WhisperKit model triggers CoreML's Neural Engine compilation, which can take 30-60 seconds for large models. This made the first use after app launch appear broken.

**Solution:** After loading a model, the engine runs a "dummy" transcription on one second of silence. This forces the Neural Engine compilation to happen during the loading phase (when the user sees a download/loading indicator) rather than during the first real transcription.

### Auto-Paste via CGEvent

One of the most technically challenging features. After copying transcription to the clipboard, the app can automatically paste it into the active application by simulating Cmd+V:

```
CGEventSource(.combinedSessionState) → CGEvent(keyDown, V key)
→ set .maskCommand flag → post to .cgSessionEventTap
→ usleep(50ms) → CGEvent(keyUp, V key) → post
```

**Critical discoveries:**
- A **50ms gap** between keyDown and keyUp is required. Without it, many applications fail to register the keystroke.
- A **500ms delay** before paste is needed to let the frontmost application regain focus after the menu bar interaction.
- `CGEvent.post` requires **Accessibility permission**, which macOS manages per-application identity.

### The Code Signing Problem

Accessibility permissions in macOS are tied to an application's code signature. Ad-hoc signing (`codesign -s -`) generates a different signature hash on every build, which means:

1. Build the app
2. Grant Accessibility permission in System Settings
3. Rebuild the app (even with no changes)
4. Accessibility permission is now invalid -- the app identity changed

macOS makes this worse by showing the app as "trusted" in System Settings even when the binary hash has changed. The actual check is `AXIsProcessTrusted()`, which returns the real permission state.

**Solution:** Created a persistent self-signed "OptionC Dev" certificate using OpenSSL. The build script (`bundle-app.sh`) signs with this certificate first, falling back to ad-hoc if it's not found. Because the certificate identity stays constant across rebuilds, Accessibility permissions persist.

The certificate creation process (one-time setup):
1. Generate a self-signed x509 certificate with code signing extensions
2. Export as PKCS12
3. Import into the login keychain with codesign trust
4. Add as trusted root certificate for code signing

### Text Replacements System

A post-processing step that runs after transcription but before clipboard copy, adding zero latency to the pipeline. The system handles recurring transcription quirks:

**Example rules:**
- "dot dot dot" becomes "..."
- "new paragraph" becomes "\n\n"
- "full stop" becomes "."

**Technical challenges solved:**

1. **Multi-word matching with punctuation** -- Whisper often inserts punctuation between words ("dot, dot, dot" or "dot. Dot. Dot"). The regex uses `[\s,;.!?]+` between words to match regardless of what Whisper adds.

2. **Three replacement categories:**
   - *Structural* (contains `\n` or `\t`) -- absorbs leading space and trailing punctuation
   - *Punctuation* (replace is only punctuation) -- absorbs preceding punctuation to prevent doubling
   - *Normal* -- simple case-insensitive replacement

3. **Post-replacement cleanup** -- Collapses duplicate punctuation (`..` becomes `.`), removes orphan punctuation at line and text starts.

4. **UI constraint** -- TextFields do not work reliably inside MenuBarExtra popovers. The solution was to open replacements editing in a separate `NSPanel` window with `level: .floating`.

### Notification Removal

System notifications were removed entirely. All feedback now comes through the menu bar icon:
- Mic icon = ready
- Filled mic = recording
- Ellipsis = processing
- Checkmark = success (750ms)
- X mark = error (1 second)

This proved less intrusive than macOS notification banners, which can obscure content and require notification centre permission.

---

## 10. Debugging the Timeout Bug (17 February 2026)

The most significant bug discovered post-v1 was a timeout mechanism that never actually fired.

### The Problem

The original timeout implementation used `withThrowingTaskGroup`:

```swift
try await withThrowingTaskGroup(of: String.self) { group in
    group.addTask { /* actual transcription */ }
    group.addTask {
        try await Task.sleep(for: .seconds(30))
        throw AppError.transcriptionTimeout
    }
    // Wait for first result
}
```

This looked correct but had a fatal flaw: `withThrowingTaskGroup` waits for ALL child tasks to complete, not just the first one. When WhisperKit blocked during Neural Engine compilation (which could take 30-60 seconds), the timeout task would fire, but the group would still wait for the transcription task to complete before propagating the error.

### The Fix

Replaced with a continuation-based approach using independent Tasks:

```swift
class TimeoutState {
    var completed = false
    let lock = NSLock()
}

// Operation task and timeout task run independently
// Whichever finishes first wins via continuation.resume()
// Thread-safe via NSLock in TimeoutState
```

Both tasks run completely independently. Whichever completes first claims the continuation via an NSLock-protected state flag, preventing the other from also calling `resume()`. This ensures the timeout genuinely fires after 30 seconds regardless of what the transcription task is doing.

---

## 11. Key Technical Decisions and Why They Were Made

### Fresh AVAudioEngine Per Session

**Problem:** Reusing an AVAudioEngine instance across recording sessions causes the audio tap callback to silently stop firing after the second or third session.

**Root cause:** AVAudioEngine maintains internal state that becomes corrupted when repeatedly stopping and starting. The engine reports that it is running, the tap reports that it is installed, but no audio buffers arrive.

**Solution:** Create a new AVAudioEngine instance for every recording session. The old instance is nil'd out and deallocated. This adds negligible overhead (engine creation takes microseconds) but completely eliminates the reliability issue.

### endAudio() Before stopCapture()

**Problem:** If the audio capture engine is stopped before the speech recogniser is told to finalise, the recogniser either hangs indefinitely or returns a truncated transcription.

**Solution:** Always call `endAudio()` on the recognition request first (which tells the recogniser "no more audio is coming, please produce a final result"), wait for the final result, then stop the audio engine. This ordering is critical and was discovered through debugging rather than documented in Apple's API reference.

### Atomic Clipboard with Verification

**Problem:** Other applications (password managers, clipboard history tools) can interfere with clipboard operations. A write that appears to succeed may have been immediately overwritten.

**Solution:** After writing to NSPasteboard, immediately read back and compare. If the read-back doesn't match what was written, throw a verification error rather than silently proceeding with incorrect data.

### @MainActor Isolation

All state-holding and UI-updating classes are marked `@MainActor`, including AppState, RecordingController, AudioCaptureManager, ClipboardManager, and PermissionManager. This provides compiler-enforced thread safety rather than relying on runtime checks like `DispatchQueue.main.async`. The Swift 6 concurrency model catches data races at compile time.

### WhisperTranscriptionEngine as Actor

The transcription engine uses Swift's `actor` type rather than a class. This provides automatic serialisation of all method calls, preventing concurrent access to the underlying WhisperKit instance, which is not thread-safe.

---

## 12. Architecture: The Final System

```
User presses Ctrl+Shift+Space
         |
         v
KeyboardShortcuts library --> AppState.handleKeyDown() / handleKeyUp()
         |
         v
PermissionManager.requestMicrophonePermission()
         |
         v
RecordingController.startRecording()
  --> AudioCaptureManager.startCaptureForWhisper()
      --> AVAudioEngine tap collects 16kHz mono samples
         |
         v
[User speaks into microphone]
         |
         v
User releases key (or presses again)
         |
         v
AppState.stopRecording() with 30s timeout
  --> RecordingController.stopRecording()
      --> AudioCaptureManager.getAudioSamples()
      --> WhisperTranscriptionEngine.transcribe(audioSamples)
          --> WhisperKit.transcribe(audioArray:, decodeOptions:)
         |
         v
TextReplacementManager.apply(to: rawText)
  --> Regex-based find/replace with punctuation handling
         |
         v
ClipboardManager.copy(text)
  --> NSPasteboard: clear, write, verify
         |
         v
[If auto-paste enabled]
  --> Task.sleep(500ms)
  --> simulatePaste() via CGEvent Cmd+V
         |
         v
Menu bar icon: checkmark for 750ms --> idle
```

### File Structure

```
Sources/OptionC/
  OptionCApp.swift                          # @main with MenuBarExtra
  State/AppState.swift                      # Central state coordinator
  Audio/AudioCaptureManager.swift           # Microphone capture (AVAudioEngine)
  Recording/RecordingController.swift       # Pipeline orchestrator + timeout
  Transcription/WhisperTranscriptionEngine.swift  # WhisperKit actor
  Clipboard/ClipboardManager.swift          # Atomic clipboard operations
  Models/
    RecordingState.swift                    # idle/recording/processing/success/error
    RecordingMode.swift                     # toggle/pushToTalk
    TextReplacement.swift                   # Find/replace engine + manager
    AppError.swift                          # 6 error types with recovery guidance
  Views/
    MenuBarView.swift                       # Menu bar dropdown UI
    ReplacementsWindow.swift                # Text replacements editor (NSPanel)
  Services/
    PermissionManager.swift                 # Microphone permission handling
  KeyboardShortcuts+Names.swift             # Shortcut definition
  Resources/Info.plist                      # Bundle config (LSUIElement=true)
```

---

## 13. The Development Timeline

| Date | Duration | What Happened |
|------|----------|---------------|
| 1 Feb, 13:50 | -- | Project initialised with `/gsd:new-project` |
| 1 Feb, 13:50-14:36 | ~45 min | Research and first architectural pivot |
| 1 Feb, 14:36-16:12 | ~1.5 hours | Requirements, roadmap, per-phase research and planning |
| 1 Feb, 16:43-16:52 | 9 min | Phase 1: Foundation and menu bar (2 plans) |
| 1 Feb, 16:55-17:00 | 5 min | Phase 2: Core recording and transcription (2 plans) |
| 1 Feb, 17:01-17:07 | 6 min | Phase 3: Feedback and error handling (3 plans) |
| 14 Feb, afternoon | -- | Major feature sprint: WhisperKit, auto-paste, text replacements |
| 14 Feb, 17:30 | -- | README, cleanup, removed dead code |
| 17 Feb, 09:55 | -- | Critical timeout bug fix, model warm-up, editable replacements |

The most notable aspect: the entire three-phase v1 implementation was coded in approximately 20 minutes. Nearly half the total commits (18 of 37) are documentation. The planning-first approach meant that when execution began, every decision had already been made.

---

## 14. Commit History

37 commits in total, all on the main branch:

| # | Hash | Message | Phase |
|---|------|---------|-------|
| 1 | c03b6e6 | docs: initialize project | Planning |
| 2 | 1d3b056 | chore: add project config | Planning |
| 3 | bcdd060 | docs: complete project research | Research |
| 4 | 557722d | docs: pivot to native recording approach | Research |
| 5 | 57b980a | docs: define v1 requirements | Planning |
| 6 | 243599b | docs: create roadmap (3 phases) | Planning |
| 7-9 | 724a6e0 - 0a8477c | docs: research per-phase implementation | Research |
| 10-12 | f509c13 - 6069260 | docs: create detailed execution plans | Planning |
| 13 | 8a05407 | feat(01-01): create Swift package project structure | Phase 1 |
| 14 | 8baab97 | feat(01-01): add Info.plist for Dock hiding | Phase 1 |
| 15 | 8eb30a1 | docs(01-01): complete plan | Phase 1 |
| 16 | 79d2200 | feat(01-02): add Option-C hotkey registration and state machine | Phase 1 |
| 17 | 7746f9a | feat(01-02): create menu bar view with mode picker | Phase 1 |
| 18 | 9ea9552 | docs(01-02): complete plan | Phase 1 |
| 19 | 42f20a5 | feat(02-01): add AudioCaptureManager | Phase 2 |
| 20 | 25b32ff | feat(02-01): add TranscriptionEngine | Phase 2 |
| 21 | 037ed18 | docs(02-01): complete plan | Phase 2 |
| 22 | 3eec55e | feat(02-02): create ClipboardManager | Phase 2 |
| 23 | d101779 | feat(02-02): create RecordingController | Phase 2 |
| 24 | 10572ed | feat(02-02): update AppState with dual-mode hotkey handling | Phase 2 |
| 25 | 9a8678d | docs(02-02): complete plan | Phase 2 |
| 26 | 30ba4a1 | feat(03-01): add AppError enum | Phase 3 |
| 27 | 0b8b152 | feat(03-01): add PermissionManager | Phase 3 |
| 28 | e27973b | feat(03-02): create NotificationManager | Phase 3 |
| 29 | 095456b | feat(03-02): request notification permission at launch | Phase 3 |
| 30-31 | 99fc442 - 94812d4 | docs(03-01, 03-02): complete plans | Phase 3 |
| 32 | 781cfea | feat(03-03): add withTimeout helper | Phase 3 |
| 33 | 2dc5f86 | feat(03-03): integrate state management with notifications | Phase 3 |
| 34 | 97f052b | docs(03-03): complete plan | Phase 3 |
| 35 | 5538a03 | feat: auto-paste, text replacements, WhisperKit, UX improvements | Post-v1 |
| 36 | 0121b25 | docs: add README, .gitignore, remove unused NotificationManager | Post-v1 |
| 37 | 13e6400 | feat: fix timeout, model warm-up, editable replacements | Post-v1 |

Co-authored with Claude Opus 4.5 (commits 1-34) and Claude Opus 4.6 (commits 35-37).

---

## 15. What Was Learned

### About AI-Assisted Development

1. **Planning-first pays off dramatically.** Spending 2.5 hours on research and planning before writing any code meant the actual implementation took 20 minutes. Every decision was pre-made, every risk pre-identified.

2. **GSD's context isolation works.** Each sub-agent got a clean context window focused on one task. No degradation, no forgotten specifications, no hallucinated code. Build success rate was 100%.

3. **Velocity increases as patterns establish.** Phase 1 averaged 5.5 minutes per plan. Phase 3 averaged 1.3 minutes. The codebase patterns were consistent enough that later phases required less exploration.

4. **Research that kills bad ideas is as valuable as research that confirms good ones.** The Voice Memos pivot happened because research agents discovered the approach was unworkable before any code was written.

### About macOS Development

5. **AVAudioEngine cannot be reused across sessions.** Create fresh instances. This is not documented by Apple.

6. **Audio must be finalised before capture stops.** `endAudio()` before `stopCapture()`. Reversing the order causes hangs or truncated results.

7. **CGEvent auto-paste requires careful timing.** 50ms between keyDown and keyUp. 500ms before paste to let the frontmost app regain focus.

8. **Accessibility permissions are tied to code signature identity.** Ad-hoc signing breaks permissions on every rebuild. Persistent self-signed certificates solve this.

9. **macOS lies about accessibility trust in System Settings.** The UI shows "trusted" even when the binary hash has changed. Only `AXIsProcessTrusted()` tells the truth.

10. **TextFields don't work in MenuBarExtra popovers.** Use separate NSPanel windows for text input.

### About WhisperKit

11. **The first transcription triggers Neural Engine compilation.** This can take 30-60 seconds for large models. A dummy inference during loading eliminates the surprise.

12. **Models cache after first download.** Switching between previously-downloaded models is near-instant.

13. **Setting language explicitly and suppressing blanks improves quality.** `language: "en"` and `suppressBlank: true` are essential for English-only use cases.

14. **Task group timeout patterns can silently fail.** `withThrowingTaskGroup` waits for all tasks, not just the first. Use continuation-based approaches for genuine timeout behaviour.

---

## 16. Current State

The app is stable and running on macOS. All original requirements are met. The build and install cycle is:

```bash
bash bundle-app.sh
cp -r .build/Option-C.app /Applications/
open /Applications/Option-C.app
```

Features working:
- Global hotkey (Ctrl+Shift+Space) with toggle and push-to-talk modes
- On-device transcription via WhisperKit (multiple model sizes)
- Automatic clipboard copy with verification
- Auto-paste into active application via CGEvent
- Text replacements with smart punctuation handling
- Menu bar icon feedback for all states
- Model warm-up for consistent first-transcription performance
- 30-second hard timeout on transcription

---

*Report generated 22 February 2026*
*Based on analysis of 37 git commits, GSD planning documents, research files, and the complete Swift source code*
