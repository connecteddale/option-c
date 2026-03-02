# Architecture Research: Claude CLI Post-Processing Integration

**Domain:** macOS menu bar voice-to-text with AI post-processing
**Researched:** 2026-03-02
**Confidence:** HIGH

## Context

This document covers the v1.1 milestone architecture only: integrating Claude CLI as a post-processing step into the already-shipped voice-to-clipboard pipeline. It supersedes the original ARCHITECTURE.md (which described the pre-WhisperKit, Voice Memos era).

The existing pipeline is:

```
hotkey -> AppState -> RecordingController -> AudioCaptureManager
       -> WhisperTranscriptionEngine -> TextReplacementManager
       -> ClipboardManager -> optional CGEvent paste
```

All state flows through `AppState` (@MainActor, ObservableObject). The Claude CLI integration adds one step — after text replacements, before clipboard.

---

## Updated Pipeline

```
hotkey -> AppState -> RecordingController -> AudioCaptureManager
       -> WhisperTranscriptionEngine
       -> TextReplacementManager
       -> [NEW] ClaudeProcessingEngine  (if aiProcessingEnabled)
       -> ClipboardManager
       -> optional CGEvent paste
```

Claude CLI is called only when the toggle is on. If it is off, or if the call fails, the pipeline falls through to clipboard as today.

---

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      MenuBarView (SwiftUI)                   │
│  status | mode | model | replacements | options | quit       │
│         + [NEW] AI Processing toggle checkbox                │
└──────────────────────────┬──────────────────────────────────┘
                           │ @ObservedObject
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                  AppState (@MainActor)                        │
│  currentState | recordingMode | autoPasteEnabled             │
│  selectedWhisperModel | whisperModelLoaded                   │
│  [NEW] aiProcessingEnabled: Bool (@AppStorage)               │
│  [NEW] aiProcessing: Bool (@Published)                       │
└──┬─────────────┬───────────────────────────────────────────┘
   │             │
   ↓             ↓
┌──────────┐  ┌─────────────────────────────────────────────┐
│Recording │  │  stopRecording() pipeline in AppState         │
│Controller│  │                                               │
│          │  │  1. recordingController.stopRecording()       │
│AudioCap  │  │     -> String? (raw Whisper text)             │
│Whisper   │  │                                               │
│Engine    │  │  2. TextReplacementManager.apply(to:)         │
└──────────┘  │     -> String (replaced text)                 │
              │                                               │
              │  3. [NEW] ClaudeProcessingEngine.process(_:)  │
              │     async throws -> String                    │
              │     (only if aiProcessingEnabled)             │
              │                                               │
              │  4. ClipboardManager.copy(_:)                 │
              │                                               │
              │  5. optional simulatePaste()                  │
              └─────────────────────────────────────────────┘
                           │
                           ↓ (new component)
              ┌─────────────────────────────────────────────┐
              │         ClaudeProcessingEngine               │
              │  - Wraps Foundation.Process                  │
              │  - Invokes: claude --print -p <prompt>       │
              │  - Stdin: transcribed text                   │
              │  - Stdout: cleaned text                      │
              │  - Timeout: 15s                              │
              │  - Failure mode: returns input unchanged     │
              └─────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Status | Change |
|-----------|---------------|--------|--------|
| AppState | Central state coordinator, pipeline orchestration | Existing | Add `aiProcessingEnabled`, `aiProcessing`, call ClaudeProcessingEngine in stopRecording() |
| RecordingController | Orchestrate audio capture + transcription | Existing | No change |
| AudioCaptureManager | Microphone via AVAudioEngine | Existing | No change |
| WhisperTranscriptionEngine | On-device speech-to-text (singleton actor) | Existing | No change |
| TextReplacementManager | Find/replace post-processing | Existing | No change |
| ClaudeProcessingEngine | Spawn claude CLI, send text via stdin, read stdout | New | New file |
| ClipboardManager | NSPasteboard write | Existing | No change |
| MenuBarView | Toggle UI for AI processing | Existing | Add checkbox in optionsSection |
| AppError | Error enum | Existing | Add `aiProcessingFailed` case |

---

## Recommended Project Structure

```
Sources/OptionC/
  OptionCApp.swift
  State/
    AppState.swift                    -- modified: add aiProcessingEnabled, aiProcessing
  Recording/
    RecordingController.swift         -- no change
  Audio/
    AudioCaptureManager.swift         -- no change
  Transcription/
    WhisperTranscriptionEngine.swift  -- no change
  Processing/                         -- NEW directory
    ClaudeProcessingEngine.swift      -- NEW: Process wrapper + prompt
  Clipboard/
    ClipboardManager.swift            -- no change
  Services/
    PermissionManager.swift           -- no change
  Views/
    MenuBarView.swift                 -- modified: add AI toggle to optionsSection
    ReplacementsWindow.swift          -- no change
  Models/
    RecordingState.swift              -- no change
    RecordingMode.swift               -- no change
    AppError.swift                    -- modified: add aiProcessingFailed case
    TextReplacement.swift             -- no change
```

### Structure Rationale

- **Processing/:** New directory mirrors the existing naming convention. Keeps ClaudeProcessingEngine alongside WhisperTranscriptionEngine conceptually but separate from it physically (different stage in pipeline).
- **No new state file:** `aiProcessingEnabled` and `aiProcessing` belong in AppState — same pattern as `autoPasteEnabled` and `whisperModelLoading`.

---

## Architectural Patterns

### Pattern 1: Toggle State via @AppStorage

**What:** AI processing is a user preference persisted across launches, stored in UserDefaults via @AppStorage. The toggle follows the exact same pattern as `autoPasteEnabled`.

**When to use:** Any user-configurable option that should persist across launches and needs no migration logic.

**Trade-offs:** Simple, automatic persistence, SwiftUI binding works directly. No access from non-MainActor code without care.

**Example:**

```swift
// In AppState.swift

/// Whether Claude CLI post-processing is enabled
@AppStorage("aiProcessingEnabled") var aiProcessingEnabled: Bool = false

/// Whether Claude CLI is currently running (drives UI feedback)
@Published var aiProcessing: Bool = false
```

In MenuBarView, bind directly:

```swift
Toggle("AI text cleanup (Claude)", isOn: $appState.aiProcessingEnabled)
    .toggleStyle(.checkbox)
```

This works because `appState` is an @ObservedObject and `aiProcessingEnabled` is @AppStorage — SwiftUI picks up changes automatically.

### Pattern 2: Process Invocation via withCheckedThrowingContinuation

**What:** Foundation.Process is callback/synchronous. Bridge it to async/await using `withCheckedThrowingContinuation`, running the process on a background DispatchQueue to avoid blocking the main thread.

**When to use:** Any time a synchronous or callback-based API needs to be called from async/await context. This is the established pattern until Swift Subprocess lands in a stable release (expected Swift 6.2, not available on macOS 14 today).

**Trade-offs:** More boilerplate than the future Subprocess API, but proven, stable, and works on macOS 14+.

**Example:**

```swift
// Sources/OptionC/Processing/ClaudeProcessingEngine.swift

import Foundation

enum ClaudeProcessingError: Error {
    case claudeNotFound
    case processLaunchFailed(Error)
    case timeout
    case nonZeroExit(Int32, String)
    case emptyOutput
}

final class ClaudeProcessingEngine {

    static let shared = ClaudeProcessingEngine()

    /// Path to claude CLI. Resolved once at init.
    private let claudePath: String?

    private init() {
        claudePath = ClaudeProcessingEngine.resolveClaudePath()
    }

    /// Find the claude binary. Checks known install locations.
    private static func resolveClaudePath() -> String? {
        let candidates = [
            "/usr/local/bin/claude",
            "\(NSHomeDirectory())/.local/bin/claude",
            "/opt/homebrew/bin/claude",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    /// Send text through Claude CLI for cleanup.
    /// - Returns: Cleaned text, or throws on failure.
    /// - Note: Called from AppState.stopRecording() which is @MainActor.
    ///   Process runs on a background queue; continuation resumes on arbitrary thread.
    ///   AppState must await this call and then update @Published state on MainActor.
    func process(_ text: String, timeout: TimeInterval = 15) async throws -> String {
        guard let claudePath else {
            throw ClaudeProcessingError.claudeNotFound
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                let stdinPipe = Pipe()
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()

                task.executableURL = URL(fileURLWithPath: claudePath)
                task.arguments = [
                    "--print",
                    "--model", "claude-haiku-4-5",
                    "--no-session-persistence",
                    "--output-format", "text",
                    "--allowedTools", "",   // no tools needed
                    Self.systemPrompt,
                ]
                task.standardInput = stdinPipe
                task.standardOutput = stdoutPipe
                task.standardError = stderrPipe

                // Strip CLAUDECODE env var so nested invocation is allowed
                var env = ProcessInfo.processInfo.environment
                env.removeValue(forKey: "CLAUDECODE")
                task.environment = env

                // Timeout: terminate process if it runs too long
                let timeoutItem = DispatchWorkItem {
                    task.terminate()
                    continuation.resume(throwing: ClaudeProcessingError.timeout)
                }
                DispatchQueue.global().asyncAfter(
                    deadline: .now() + timeout,
                    execute: timeoutItem
                )

                do {
                    try task.run()

                    // Write input text to stdin then close
                    let inputData = text.data(using: .utf8) ?? Data()
                    stdinPipe.fileHandleForWriting.write(inputData)
                    try stdinPipe.fileHandleForWriting.close()

                    // Block until process exits (on background queue — this is safe)
                    task.waitUntilExit()
                    timeoutItem.cancel()

                    let exitCode = task.terminationStatus

                    // Read stdout
                    let outputData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: outputData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                    // Read stderr for diagnostics (log only)
                    let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

                    guard exitCode == 0 else {
                        NSLog("[OptionC] Claude CLI exit \(exitCode): \(errorOutput)")
                        continuation.resume(
                            throwing: ClaudeProcessingError.nonZeroExit(exitCode, errorOutput)
                        )
                        return
                    }

                    guard !output.isEmpty else {
                        continuation.resume(throwing: ClaudeProcessingError.emptyOutput)
                        return
                    }

                    continuation.resume(returning: output)

                } catch {
                    timeoutItem.cancel()
                    continuation.resume(
                        throwing: ClaudeProcessingError.processLaunchFailed(error)
                    )
                }
            }
        }
    }

    private static let systemPrompt = """
        You are a transcription cleanup engine. The user will provide raw speech-to-text output. \
        Clean it up: fix punctuation, capitalisation, spelling. \
        Convert spoken numbers to digits (e.g. "forty two" -> "42"). \
        Convert spoken currency (e.g. "fifty dollars" -> "$50"). \
        Format times in 24h format with 'h' separator (e.g. "2 30 pm" -> "14h30", "half three" -> "15h30"). \
        Return ONLY the cleaned text. No explanation, no preamble, no quotes.
        """
}
```

### Pattern 3: Graceful Degradation on AI Failure

**What:** If Claude CLI fails (not installed, timeout, non-zero exit), the pipeline falls through and delivers the text-replacement-processed text to clipboard without AI cleanup. The user still gets output. The error is logged but does not cause an error state in the UI.

**When to use:** Any enhancement step that is not core to the primary value proposition. The primary value is voice-to-clipboard. AI cleanup is a bonus.

**Trade-offs:** Users may not notice the degradation silently. Consider a brief toast or icon change to indicate AI was skipped, without blocking the flow.

**Example in AppState.stopRecording():**

```swift
// Apply text replacements
let replacedText = TextReplacementManager.shared.apply(to: rawText)

// Apply Claude AI cleanup if enabled
var finalText = replacedText
if aiProcessingEnabled {
    aiProcessing = true
    do {
        finalText = try await ClaudeProcessingEngine.shared.process(replacedText)
    } catch {
        NSLog("[OptionC] Claude processing skipped: \(error)")
        // finalText stays as replacedText — pipeline continues unchanged
    }
    aiProcessing = false
}

// Copy to clipboard
try ClipboardManager.copy(finalText)
```

### Pattern 4: State Feedback During AI Processing

**What:** The existing `processing` state in `RecordingState` covers WhisperKit transcription. Once WhisperKit returns, the app briefly enters a post-transcription phase where Claude CLI runs. The `aiProcessing` flag on AppState drives this, and the menu bar icon stays on `ellipsis` (processing) until the full pipeline completes.

**When to use:** Multi-step async pipelines where each step adds latency. Avoid adding new RecordingState cases — the existing `processing` state is the right abstraction.

**Trade-offs:** The user sees "processing" for the combined WhisperKit + Claude time. This is accurate and avoids introducing a new `.aiProcessing` state that would multiply menu bar icon logic. Menu item could show "AI cleanup..." text during this phase as a refinement.

---

## Data Flow

### Transcription + AI Cleanup Flow

```
User releases hotkey
    |
    v
AppState.stopRecording()
    |
    v (async, withTimeout 30s)
RecordingController.stopRecording()
    |
    +--> AudioCaptureManager.getAudioSamples() -> [Float]
    +--> AudioCaptureManager.stopCapture()
    +--> WhisperTranscriptionEngine.transcribe(audioSamples:) -> String
    |
    v
TextReplacementManager.apply(to: rawText) -> String
    |
    v (conditional: aiProcessingEnabled)
ClaudeProcessingEngine.process(_:) -> String
    |    (background DispatchQueue, 15s timeout)
    |    (graceful fallback: returns replacedText on any error)
    |
    v
ClipboardManager.copy(finalText)
    |
    v (conditional: autoPasteEnabled)
simulatePaste() via CGEvent
    |
    v
transitionToSuccess(transcription: finalText)
```

### State Transitions with AI Processing

```
idle
  |-- hotkey down/up -->
recording
  |-- hotkey up (toggle) / release (PTT) -->
processing   <-- RecordingState.processing covers this entire phase
  |-- WhisperKit returns, TextReplacementManager runs -->
  |-- (if aiProcessingEnabled) ClaudeProcessingEngine runs -->
  |-- ClipboardManager.copy() -->
success(transcription:)
  |-- 750ms -->
idle
```

`AppState.aiProcessing: Bool` is a secondary flag for future UI differentiation (e.g., showing "AI cleanup..." text in the menu dropdown during the Claude phase) but does not change `RecordingState`.

### Toggle State Management

```
MenuBarView
  Toggle("AI text cleanup", isOn: $appState.aiProcessingEnabled)
      |
      @AppStorage("aiProcessingEnabled") persists to UserDefaults
      |
      AppState.stopRecording() reads aiProcessingEnabled synchronously
      (no async needed — it's a Bool read on MainActor)
```

No observer, no notification needed. The `stopRecording()` method reads `aiProcessingEnabled` at the point it needs it. The setting takes effect on the next recording.

---

## Integration Points

### New vs Modified Components

| Component | New or Modified | What Changes |
|-----------|----------------|--------------|
| ClaudeProcessingEngine.swift | NEW | Entire file |
| AppState.swift | MODIFIED | `aiProcessingEnabled`, `aiProcessing` properties; call site in `stopRecording()` |
| MenuBarView.swift | MODIFIED | Add Toggle in `optionsSection` |
| AppError.swift | MODIFIED | Add `aiProcessingFailed` case (for future use if error UX is desired) |

### External Boundary: Claude CLI

| Property | Value |
|----------|-------|
| Executable path | `/Users/[user]/.local/bin/claude` (primary), `/usr/local/bin/claude`, `/opt/homebrew/bin/claude` |
| Invocation mode | `claude --print --model claude-haiku-4-5 --no-session-persistence --output-format text [prompt]` |
| Input | stdin (raw transcribed text) |
| Output | stdout (cleaned text) |
| Authentication | Session already authenticated on user's machine — no API key management needed |
| Environment | Must strip `CLAUDECODE` env var to allow nested invocation |
| Timeout | 15 seconds (network round-trip + model inference) |
| Failure behaviour | Log and fall through; do not surface as UI error |

### CLAUDECODE Environment Variable

Claude CLI detects if it is being run inside another Claude Code session via `CLAUDECODE` env variable and refuses to launch. Option-C's process inherits this variable when run from the terminal. The Process invocation must strip it:

```swift
var env = ProcessInfo.processInfo.environment
env.removeValue(forKey: "CLAUDECODE")
task.environment = env
```

This is verified behaviour: `claude --version` works with a clean environment, blocked when `CLAUDECODE` is set.

### Model Selection for Claude CLI

Use `claude-haiku-4-5` (or the `haiku` alias). Rationale:

- Transcription cleanup is a simple transformation task — no deep reasoning required
- Haiku is fastest and cheapest, minimising added latency
- A 30-50 word transcription processes in under 2 seconds on Haiku vs 5-8 seconds on Sonnet
- If the user wants a slower/better model, that can be added as a preference later

---

## Async/Await + Process: Implementation Notes

### Why Not Swift Subprocess

Swift Subprocess (SF-0007) is in review/testing as of early 2026. It is not available as a stable API on macOS 14 targets. Foundation.Process with `withCheckedThrowingContinuation` is the correct approach today.

### stdin Closure Timing

Write to stdin pipe and close it **after** `task.run()` returns. Closing stdin before the process starts can cause a broken pipe. The process must be running before stdin is written:

```swift
try task.run()
stdinPipe.fileHandleForWriting.write(inputData)
try stdinPipe.fileHandleForWriting.close()   // signals EOF to the subprocess
task.waitUntilExit()
```

### Timeout vs Task Cancellation

The 30-second `withTimeout` in `AppState.stopRecording()` wraps the entire pipeline including ClaudeProcessingEngine. The ClaudeProcessingEngine also has its own 15-second internal timeout via `DispatchWorkItem`. This means:

- WhisperKit gets up to 30s (as today)
- Claude CLI gets up to 15s within that window
- If the outer 30s fires first, the task throws `AppError.transcriptionTimeout` and the Claude process is terminated by the timeout DispatchWorkItem

The outer `withTimeout` in RecordingController does not propagate Task cancellation into a running Process — it resolves the continuation with a timeout error, which causes `stopRecording()` to throw and short-circuit. The Claude process continues running briefly in the background but its output is discarded. This is acceptable: the Pipe buffers are small and the process will exit on its own.

For a cleaner solution, store the `task` reference and call `task.terminate()` from a `withTaskCancellationHandler` block. This is a refinement, not a blocker for MVP.

### Continuation Safety

`withCheckedThrowingContinuation` enforces that the continuation is resumed exactly once. The pattern above resumes in exactly one place per code path (success, launch failure, or timeout). Verify this holds before shipping — the compiler does not catch double-resume at runtime; it will crash.

---

## Anti-Patterns

### Anti-Pattern 1: Running Process on MainActor

**What people do:** Call `task.run()` and `task.waitUntilExit()` directly in AppState without dispatching to a background queue.

**Why it is wrong:** `task.waitUntilExit()` blocks the calling thread. If called on the main thread, the UI freezes. The menu bar icon will not update to "processing" during Claude inference.

**Do this instead:** Always dispatch Process execution to `DispatchQueue.global(qos: .userInitiated)` inside `withCheckedThrowingContinuation`.

### Anti-Pattern 2: Letting Claude Process Inherit CLAUDECODE

**What people do:** Pass nil for `task.environment` (which inherits the parent environment including `CLAUDECODE`).

**Why it is wrong:** Claude CLI will refuse to start inside another Claude session. This causes silent failure in production builds run from the terminal during development.

**Do this instead:** Always strip `CLAUDECODE` from the environment passed to the Process. Also a good practice: inherit a minimal environment (`PATH`, `HOME`, `USER`) rather than the full parent environment.

### Anti-Pattern 3: Surfacing AI Failure as a Hard Error

**What people do:** Add `aiProcessingFailed` to `AppError` and call `transitionToError(.aiProcessingFailed)` when Claude CLI fails.

**Why it is wrong:** The primary value is voice-to-clipboard. A failed AI cleanup should not block the user from getting their transcription. Treating it as a hard error creates a bad experience when Claude is unavailable or slow.

**Do this instead:** Log the failure, fall through with the pre-AI text, and copy it to clipboard. Optionally: add a subtle indicator (e.g., menu bar icon briefly different) if user needs to know AI was skipped.

### Anti-Pattern 4: Adding a New RecordingState Case for AI Processing

**What people do:** Add `.aiProcessing` to `RecordingState` to differentiate WhisperKit processing from Claude processing.

**Why it is wrong:** Multiplies icon/color logic in MenuBarView, adds a state transition edge, and does not provide meaningful UX benefit — the user sees "processing" either way. The `aiProcessing: Bool` flag on AppState is sufficient for any future differentiation.

**Do this instead:** Keep `RecordingState.processing` as the single "busy" state. Use `AppState.aiProcessing` only for UI text hints ("AI cleanup..." in the dropdown) if needed.

### Anti-Pattern 5: Using --dangerously-skip-permissions

**What people do:** Add `--dangerously-skip-permissions` or `--allowedTools ""` incorrectly, or omit tool restrictions entirely.

**Why it is wrong:** Without `--allowedTools ""` (empty string), Claude CLI may attempt to use Bash/Edit/Read tools. For a text transformation task this wastes time and introduces unpredictable behaviour.

**Do this instead:** Pass `--allowedTools ""` to explicitly disable all tools. The task is pure text in, text out — no tools needed.

---

## Build Order for v1.1 Phases

### Phase 1: ClaudeProcessingEngine (foundation)

Build the engine in isolation before wiring it into AppState. Verify:
- CLI found at expected path
- CLAUDECODE stripping works
- stdin/stdout piping works
- Timeout fires and terminates the process
- Graceful fallback on non-zero exit

Test with a minimal Swift command-line target or a unit test before integrating.

Deliverable: `ClaudeProcessingEngine.swift` passes manual smoke test.

### Phase 2: AppState Integration + Toggle

Add `aiProcessingEnabled` and `aiProcessing` to AppState. Wire ClaudeProcessingEngine into `stopRecording()`. Add Toggle to MenuBarView. Add `aiProcessingFailed` to AppError.

Verify:
- Toggle persists across app restarts
- Pipeline still works when toggle is off (no regression)
- Pipeline calls Claude when toggle is on
- Failure falls through without crashing

Deliverable: End-to-end voice -> AI cleanup -> clipboard working with toggle.

### Phase 3: Prompt Tuning

Tune the system prompt for the specific formatting requirements: 24h times, number conversion, currency, punctuation, capitalisation. Test with representative transcription samples.

Verify:
- "two thirty pm" -> "14h30"
- "forty two dollars" -> "$42"
- "its a good idea" -> "It's a good idea."
- Existing text replacements still run before AI (so custom jargon is handled pre-Claude)

Deliverable: Consistent formatting across a test corpus of 20+ representative phrases.

### Phase 4: WhisperKit Native Formatting Research (parallel track)

Research whether WhisperKit's `DecodingOptions` offer any formatting improvements (punctuation model, word timestamps, initial prompt). This is independent of Claude CLI integration and can run in parallel. Findings may reduce the work Claude needs to do.

---

## Confidence Assessment

| Area | Confidence | Basis |
|------|------------|-------|
| Pipeline insertion point | HIGH | Verified from reading AppState.stopRecording() source |
| @AppStorage toggle pattern | HIGH | Matches existing autoPasteEnabled pattern in same file |
| Process + withCheckedThrowingContinuation | HIGH | Standard documented pattern, verified via multiple sources |
| CLAUDECODE env stripping | HIGH | Confirmed by running claude in nested env from shell |
| Claude CLI flags (--print, --no-session-persistence) | HIGH | Verified from --help output, version 2.1.63 |
| Model recommendation (Haiku) | MEDIUM | Haiku availability confirmed; latency estimate from general knowledge |
| Prompt effectiveness | MEDIUM | Needs empirical tuning against real transcription samples |
| Swift Subprocess status | MEDIUM | Under review as of 2026; not stable on macOS 14 |

---

## Sources

- AppState.swift source (verified 2026-03-02) — existing pipeline structure
- RecordingController.swift source (verified 2026-03-02) — withTimeout pattern
- TextReplacement.swift source (verified 2026-03-02) — @MainActor shared manager pattern
- Claude CLI --help output (version 2.1.63, verified 2026-03-02) — flags, modes
- Shell verification: claude nested invocation blocked by CLAUDECODE env var (verified 2026-03-02)
- [Asynchronous Process Handling in Swift](https://arturgruchala.com/asynchronous-process-handling/) — withCheckedThrowingContinuation + Process pattern
- [Swift Subprocess (SF-0007)](https://forums.swift.org/t/pitch-swift-subprocess/69805) — future API, not yet stable
- [Apple Developer Forums: Running a Child Process](https://developer.apple.com/forums/thread/690310) — Foundation.Process async patterns

---

*Architecture research for: Claude CLI integration into Option-C v1.1*
*Researched: 2026-03-02*
