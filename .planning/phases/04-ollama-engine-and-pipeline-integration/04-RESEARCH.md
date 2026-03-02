# Phase 4: Ollama Engine and Pipeline Integration - Research

**Researched:** 2026-03-02
**Domain:** Ollama HTTP API, URLSession async/await, Swift protocol abstraction, SwiftUI toggle wiring
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| LLM-01 | App calls Ollama HTTP API (localhost:11434) with configurable timeout | URLSession POST to `/api/chat` with `stream: false`; `timeoutIntervalForRequest` on URLRequest |
| LLM-02 | LLM provider is behind a protocol so Ollama can be swapped for Anthropic API later | Swift protocol `LLMProcessingProvider` with single `process(_:) async throws -> String` method; OllamaProcessingEngine conforms to it |
| UX-01 | User can toggle AI processing on/off via menu bar dropdown | `@AppStorage("aiProcessingEnabled")` on AppState; `Toggle` in `optionsSection` of MenuBarView — exact same pattern as `autoPasteEnabled` |
| UX-02 | Menu bar icon shows distinct state when AI is processing | `@Published var aiProcessing: Bool` on AppState; `menuBarIcon` computed property returns `"wand.and.stars"` (or similar) while `aiProcessing == true` |
</phase_requirements>

---

## Summary

Phase 4 adds Ollama as an optional post-processing step to the existing voice-to-clipboard pipeline. The integration is a single conditional block inserted in `AppState.stopRecording()` between `TextReplacementManager` and `ClipboardManager` — the same slot identified in the project-level architecture research, but using URLSession to call the Ollama HTTP API instead of a CLI subprocess.

The key contextual fact for this phase: the project-level research was written for the Anthropic CLI/API and is superseded by the user decision to use Ollama. Ollama's API is a local HTTP server at `localhost:11434`. Calls are simple JSON POSTs — no authentication, no API key, no Keychain integration needed for Phase 4. All the Keychain and API key complexity from the project research docs is out of scope here (that belongs to the Anthropic path, deferred to PROV-01/PROV-02).

The two plans for this phase are: (1) `OllamaProcessingEngine` — URLSession wrapper, protocol definition, Codable request/response models; and (2) AppState/MenuBarView wiring — toggle persistence, `aiProcessing` state flag, icon differentiation. Both plans have HIGH confidence implementation patterns. No new Swift Package dependencies are required: URLSession is built-in and sufficient for a single local HTTP endpoint.

**Primary recommendation:** Use `URLSession.shared.data(for:)` with `stream: false` against `/api/chat`. Define a `LLMProcessingProvider` protocol with a single `process(_:) async throws -> String` method. `OllamaProcessingEngine` conforms to it. AppState holds a `currentProvider: any LLMProcessingProvider` property, making the Anthropic swap a single-line change later.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| URLSession | Built-in (macOS 14+) | HTTP POST to Ollama API | Native, async/await, no new dependency, sufficient for single local endpoint |
| Foundation.JSONEncoder / JSONDecoder | Built-in | Encode request body, decode response | Pairs with Codable structs, standard approach |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ollama-swift (mattt) | 1.8.0+ | Pre-built Ollama Swift client | If complexity grows (tool calling, streaming); overkill for Phase 4's one-shot generate |
| OllamaKit | 5.0.8+ | Alternative Swift Ollama client | Same rationale as above — adds dependency for what URLSession handles in ~40 lines |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| URLSession (hand-rolled) | ollama-swift | ollama-swift is MIT, well-maintained, macOS 13+; adds a Package.swift dependency for 40 lines of URLSession code — not worth it for Phase 4 |
| `/api/chat` endpoint | `/api/generate` endpoint | `/api/chat` is the modern endpoint; supports system messages as first-class messages in the `messages` array; `/api/generate` has a separate `system` field but is the older pattern |
| `stream: false` | Streaming | Streaming would require SSE parsing; `stream: false` returns one JSON object; correct for short transcription text where we need the complete result |

**Installation:** No new packages. URLSession is built into Foundation, already imported in AppState.swift.

---

## Architecture Patterns

### Recommended Project Structure

```
Sources/OptionC/
  Processing/                             -- NEW directory
    LLMProcessingProvider.swift           -- NEW: protocol definition
    OllamaProcessingEngine.swift          -- NEW: URLSession wrapper conforming to protocol
  State/
    AppState.swift                        -- MODIFIED: aiProcessingEnabled, aiProcessing, provider call
  Views/
    MenuBarView.swift                     -- MODIFIED: Toggle in optionsSection
  Models/
    AppError.swift                        -- MODIFIED: add aiProcessingFailed case
```

All other files unchanged. Pattern mirrors how `TextReplacementManager` sits in no particular folder but `Processing/` is the correct new directory following existing conventions — WhisperTranscriptionEngine is in `Transcription/`, audio in `Audio/`, etc.

### Pattern 1: LLMProcessingProvider Protocol

**What:** A protocol with a single method. OllamaProcessingEngine conforms to it today. If the user later wants Anthropic API, a new conforming type is created and AppState's `provider` property is swapped.

**When to use:** Any time a concrete implementation needs to be swappable without rewiring call sites.

```swift
// Sources/OptionC/Processing/LLMProcessingProvider.swift

import Foundation

/// Abstraction over any LLM post-processing backend.
/// Phase 4 ships OllamaProcessingEngine.
/// A future AnthropicProcessingEngine can conform without touching AppState.
protocol LLMProcessingProvider {
    /// Send transcribed text for cleanup. Returns cleaned text.
    /// Throws on unrecoverable failure — caller must fall back to input text.
    func process(_ text: String) async throws -> String
}
```

### Pattern 2: OllamaProcessingEngine — URLSession wrapper

**What:** Concrete implementation of `LLMProcessingProvider`. POSTs to `http://localhost:11434/api/chat` with `stream: false`. Returns the `message.content` string from the response.

**Key implementation details verified from Ollama API docs (HIGH confidence):**
- Endpoint: `POST http://localhost:11434/api/chat`
- Content-Type: `application/json`
- Request body fields: `model` (String), `messages` ([{role, content}]), `stream` (Bool = false)
- Response field: `message.content` (String)
- Timeout: set via `URLRequest.timeoutIntervalForRequest` (recommended: 30s for Phase 4 — empirical calibration in Phase 5)

```swift
// Sources/OptionC/Processing/OllamaProcessingEngine.swift

import Foundation

enum OllamaError: Error {
    case invalidResponse
    case httpError(Int)
    case emptyOutput
    case outputLengthSuspect  // output > 300% of input character count
}

final class OllamaProcessingEngine: LLMProcessingProvider {

    static let shared = OllamaProcessingEngine()

    private let baseURL = URL(string: "http://localhost:11434")!
    private let model: String
    private let timeoutSeconds: TimeInterval

    init(model: String = "llama3.2", timeout: TimeInterval = 30) {
        self.model = model
        self.timeoutSeconds = timeout
    }

    func process(_ text: String) async throws -> String {
        let endpoint = baseURL.appendingPathComponent("/api/chat")

        // Request body
        let body = OllamaChatRequest(
            model: model,
            messages: [
                OllamaMessage(role: "system", content: Self.systemPrompt),
                OllamaMessage(role: "user", content: text)
            ],
            stream: false
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutIntervalForRequest = timeoutSeconds

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw OllamaError.httpError(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        let output = decoded.message.content.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !output.isEmpty else {
            throw OllamaError.emptyOutput
        }

        // Safety guard: if output is more than 3x input length, something went wrong
        if output.count > text.count * 3 {
            NSLog("[OptionC] Ollama output suspiciously long (\(output.count) vs \(text.count)) — falling back")
            throw OllamaError.outputLengthSuspect
        }

        return output
    }

    // Placeholder prompt — Phase 5 will tune this
    private static let systemPrompt = """
        You are a transcription cleanup engine. \
        Fix punctuation and capitalisation. \
        Return ONLY the cleaned text. No explanation, no preamble, no quotes.
        """
}

// MARK: - Codable Models

struct OllamaChatRequest: Encodable {
    let model: String
    let messages: [OllamaMessage]
    let stream: Bool
}

struct OllamaMessage: Codable {
    let role: String
    let content: String
}

struct OllamaChatResponse: Decodable {
    let message: OllamaMessage
    let done: Bool
}
```

### Pattern 3: AppState — toggle and pipeline wiring

**What:** Two new AppState properties mirror the existing `autoPasteEnabled` / `whisperModelLoading` pattern exactly. The pipeline gains one conditional block after TextReplacementManager.

```swift
// In AppState.swift — new properties

/// Whether AI post-processing via Ollama is enabled (persisted)
@AppStorage("aiProcessingEnabled") var aiProcessingEnabled: Bool = false

/// Whether the Ollama engine is currently processing (drives UI feedback)
@Published var aiProcessing: Bool = false

/// The active LLM provider — swap here to change backend
private let llmProvider: any LLMProcessingProvider = OllamaProcessingEngine.shared
```

```swift
// In AppState.stopRecording() — insert between TextReplacementManager and ClipboardManager

// Apply text replacements (existing)
let replacedText = TextReplacementManager.shared.apply(to: rawText)

// Apply AI cleanup if enabled (NEW)
var finalText = replacedText
if aiProcessingEnabled {
    aiProcessing = true
    do {
        finalText = try await llmProvider.process(replacedText)
    } catch {
        NSLog("[OptionC] Ollama processing skipped: \(error)")
        // finalText stays as replacedText — pipeline continues unchanged
    }
    aiProcessing = false
}

// Copy to clipboard (existing)
try ClipboardManager.copy(finalText)
```

### Pattern 4: MenuBarView — AI toggle in optionsSection

**What:** Add one `Toggle` to the existing `optionsSection`. Exact same pattern as `autoPasteEnabled`.

```swift
// In optionsSection — add after existing Toggle

Toggle("AI text cleanup (Ollama)", isOn: $appState.aiProcessingEnabled)
    .toggleStyle(.checkbox)
```

No additional UI needed for Phase 4. Phase 5 adds error messaging for unavailability.

### Pattern 5: menuBarIcon — distinct AI processing state

**What:** The `menuBarIcon` computed property in AppState returns a different SF Symbol when `aiProcessing == true`. This drives UX-02.

```swift
// In AppState.menuBarIcon — extended

var menuBarIcon: String {
    switch currentState {
    case .idle:
        if whisperModelLoading { return "arrow.down.circle" }
        return whisperModelLoaded ? "mic" : "mic.slash"
    case .recording:
        return "mic.fill"
    case .processing:
        // Distinguish Ollama phase from WhisperKit phase
        return aiProcessing ? "wand.and.stars" : "ellipsis"
    case .success:
        return "checkmark"
    case .error:
        return "xmark"
    }
}
```

Suitable SF Symbols for the AI processing state: `wand.and.stars`, `sparkles`, `brain`, `waveform.and.magnifyingglass`. `wand.and.stars` is available macOS 13+ and clearly suggests transformation. Verify in SF Symbols app before committing.

### Anti-Patterns to Avoid

- **Adding a new `RecordingState.aiProcessing` case:** Multiplies icon/colour logic in MenuBarView. `AppState.aiProcessing: Bool` is sufficient. The `processing` state remains the single "busy" abstraction; `aiProcessing` is a secondary flag within it.
- **Storing the provider in AppState as a concrete `OllamaProcessingEngine`:** Defeats the protocol abstraction. Store as `any LLMProcessingProvider` so the Phase 5+ Anthropic engine swap is a one-line change.
- **Surfacing Ollama failure as a hard error:** Voice-to-clipboard must never break. Log and fall through to `replacedText`. Hard errors belong to Phase 5 availability checking (LLM-03, UX-03, UX-04 — out of scope here).
- **Setting `stream: true` (default):** Ollama streams by default. Omitting `stream: false` means URLSession receives a series of newline-delimited JSON objects, not a single response — `JSONDecoder` will fail on the first chunk. Always explicitly set `"stream": false`.
- **Calling URLSession on the MainActor without `await`:** `URLSession.shared.data(for:)` is async/await native in Swift. It suspends without blocking the main thread. No DispatchQueue.global dance needed (unlike Foundation.Process, which the project research described for the CLI approach).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP JSON POST | Custom socket or Foundation.Stream | URLSession + Codable | URLSession handles redirects, timeouts, TLS — none apply here but the pattern is standard and correct |
| Streaming response parsing | SSE or newline-delimited JSON parser | Set `stream: false` in request body | Eliminates entire category of parsing complexity; short transcriptions don't benefit from streaming |
| LLM provider abstraction | Complex factory pattern | Single `LLMProcessingProvider` protocol with one method | One method is enough; YAGNI for anything more complex |

**Key insight:** The CLI complexity catalogued in the project-level ARCHITECTURE.md (PATH resolution, CLAUDECODE env stripping, Process TTY, pipe deadlock, withCheckedThrowingContinuation boilerplate) is entirely eliminated by using URLSession to call the local HTTP server. The Ollama HTTP API is simpler than the CLI in every measurable way.

---

## Common Pitfalls

### Pitfall 1: Ollama streams by default

**What goes wrong:** `URLSession.data(for:)` receives a body that is multiple newline-separated JSON objects. `JSONDecoder.decode(OllamaChatResponse.self, from: data)` throws a decoding error on the first chunk.

**Why it happens:** Ollama's `/api/chat` and `/api/generate` endpoints stream by default (per official API docs). `stream: false` must be set explicitly in the request body.

**How to avoid:** Always encode `stream: false` in the request body. Verify in a `curl` test before writing Swift code.

**Warning signs:** JSONDecoder throwing "dataCorrupted" or "keyNotFound" on response parsing despite a 200 status code.

### Pitfall 2: Model name mismatch

**What goes wrong:** OllamaProcessingEngine sends a request for `"llama3.2"` but the user has pulled `"llama3.2:3b"` or `"mistral"`. Ollama returns HTTP 404 with `{"error": "model 'llama3.2' not found"}`. The app falls back silently — no cleanup happens.

**Why it happens:** The model name in the request must exactly match an installed model. Ollama does not fuzzy-match.

**How to avoid:** Default to a model that is very likely to exist, or make the model name a user-configurable `@AppStorage` preference. Phase 5 (LLM-03) adds availability checking — for Phase 4, use a widely-pulled default (e.g., `"llama3.2"`) and accept that users who haven't pulled it get graceful degradation.

**Warning signs:** AI toggle appears to work (no error) but transcriptions are never cleaned — HTTP 404 causes `OllamaError.httpError(404)` which is caught and logged but not surfaced.

### Pitfall 3: `aiProcessing = false` skipped on Task cancellation

**What goes wrong:** If `AppState.stopRecording()` is cancelled (e.g., outer 30s timeout fires), the `aiProcessing = false` assignment after `llmProvider.process()` is never reached. Menu bar stays in "AI processing" state permanently.

**Why it happens:** Task cancellation skips code after the cancellation point.

**How to avoid:** Use `defer { aiProcessing = false }` immediately after `aiProcessing = true`. This executes on all exit paths including throw and cancellation.

```swift
if aiProcessingEnabled {
    aiProcessing = true
    defer { aiProcessing = false }  // always resets, even on throw or cancellation
    do {
        finalText = try await llmProvider.process(replacedText)
    } catch {
        NSLog("[OptionC] Ollama processing skipped: \(error)")
    }
}
```

### Pitfall 4: URLSession timeout vs Ollama cold-start

**What goes wrong:** Ollama must load the model into memory on first use. On a MacBook with an unloaded model, this can take 10-30 seconds. A 15s URLSession timeout causes the first request after Ollama restarts to always fail.

**Why it happens:** Model cold-start is much slower than inference. Subsequent requests use the cached model (Ollama's `keep_alive` defaults to 5 minutes).

**How to avoid:** Set `timeoutIntervalForRequest` to 60s for Phase 4. Instrument actual first-load and warm latencies during smoke testing. Phase 5 can add a health check or warm-up call. The STATE.md already flags this: "Instrument actual Ollama latency during Phase 4 smoke testing to confirm timeout value is appropriate."

**Warning signs:** First transcription after Ollama restart always silently falls back to raw text; subsequent ones work.

### Pitfall 5: Output length guard miscalibrated for short inputs

**What goes wrong:** A 10-word input like "um yeah so like meeting at three" gets cleaned to "Meeting at 15:00." — 4 words. The output (18 chars) is shorter than input (36 chars). The 300% guard passes. But consider the reverse: a 5-word input could legitimately expand with punctuation added. The guard threshold should not trigger on legitimate expansions.

**Why it happens:** Short inputs have high relative variance in length.

**How to avoid:** Only apply the output length guard when both (a) output exceeds 3x input character count AND (b) output length is > 200 characters absolute. This prevents false positives on trivially short inputs.

---

## Code Examples

Verified patterns from official sources:

### Ollama /api/chat request (non-streaming)

```bash
# Source: https://docs.ollama.com/api/chat
curl http://localhost:11434/api/chat -d '{
  "model": "llama3.2",
  "messages": [
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "Why is the sky blue?"}
  ],
  "stream": false
}'
```

Response:
```json
{
  "model": "llama3.2",
  "created_at": "2023-12-12T14:13:43.416799Z",
  "message": {
    "role": "assistant",
    "content": "The sky appears blue..."
  },
  "done": true,
  "total_duration": 5191566416,
  "load_duration": 2154458,
  "prompt_eval_count": 26,
  "eval_count": 298
}
```

### URLSession async/await POST pattern

```swift
// Source: Apple Developer Documentation — URLSession.data(for:)
// No third-party dependency required

var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.httpBody = try JSONEncoder().encode(body)
request.timeoutIntervalForRequest = 60

let (data, response) = try await URLSession.shared.data(for: request)
// Throws on network failure or timeout — caught by caller
```

### @AppStorage toggle (matches existing autoPasteEnabled pattern)

```swift
// In AppState.swift — mirrors line 16 exactly
@AppStorage("aiProcessingEnabled") var aiProcessingEnabled: Bool = false

// In MenuBarView.swift optionsSection — mirrors line 215 exactly
Toggle("AI text cleanup (Ollama)", isOn: $appState.aiProcessingEnabled)
    .toggleStyle(.checkbox)
```

### Protocol abstraction for provider swap

```swift
// LLMProcessingProvider.swift
protocol LLMProcessingProvider {
    func process(_ text: String) async throws -> String
}

// AppState.swift
private let llmProvider: any LLMProcessingProvider = OllamaProcessingEngine.shared

// Future swap (Phase 5+ / PROV-01):
// private let llmProvider: any LLMProcessingProvider = AnthropicProcessingEngine.shared
```

### Ollama /api/tags — model availability check (for reference; used in Phase 5)

```bash
# Source: https://docs.ollama.com/api/tags
curl http://localhost:11434/api/tags
```

Response contains `models[].name` array — use in Phase 5 availability checking (LLM-03).

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Foundation.Process subprocess (CLI) | URLSession HTTP call | User decision 2026-03-02 | Eliminates PATH, TTY, CLAUDECODE env, pipe deadlock, and empty-stdin-on-large-input pitfalls entirely |
| Anthropic API (original research target) | Ollama local HTTP | User decision 2026-03-02 | No API key, no Keychain, no network dependency — fully local |
| withCheckedThrowingContinuation + DispatchQueue | async/await URLSession natively | N/A — always true for URLSession | No bridging boilerplate needed; URLSession.data(for:) is async by design |

**Deprecated/outdated in this context:**
- ARCHITECTURE.md and SUMMARY.md code patterns (Foundation.Process, CLAUDECODE env stripping, Keychain API key storage): Written for Claude CLI/Anthropic API. Do not use for Ollama integration. The architectural patterns (graceful degradation, @AppStorage toggle, aiProcessing flag) remain valid.

---

## Open Questions

1. **Which Ollama model to default to?**
   - What we know: `llama3.2` is a widely-pulled default; `mistral` and `qwen2.5` are common alternatives. The model name must match exactly what the user has installed.
   - What's unclear: What model(s) the user has pulled. Phase 5 (LLM-03) adds a check, but Phase 4 needs a sensible default to avoid silent failure.
   - Recommendation: Default to `"llama3.2"` and make the model name a `@AppStorage("ollamaModel")` preference (even if no UI exposes it yet). This decouples the default from the implementation and lets Phase 5 build a picker without refactoring.

2. **Which SF Symbol for the AI processing icon?**
   - What we know: `wand.and.stars` and `sparkles` are available macOS 13+. `brain` is available macOS 14+. All are visually distinct from `ellipsis`.
   - What's unclear: Which feels most intuitive in a menu bar context at small size.
   - Recommendation: Use `wand.and.stars` as the primary candidate. Verify at 16pt in SF Symbols app. If it reads poorly at small size, fall back to `sparkles`.

3. **Timeout calibration**
   - What we know: Ollama cold-start (loading model) can be 10-30s. Warm inference for short text is under 2s.
   - What's unclear: Actual p50/p95 for the user's specific machine and model. STATE.md explicitly flags: "Instrument actual Ollama latency during Phase 4 smoke testing to confirm timeout value is appropriate."
   - Recommendation: Default to 60s for Phase 4. Instrument during smoke test. Tighten in Phase 5 based on real observations.

---

## Sources

### Primary (HIGH confidence)

- [Ollama /api/chat documentation](https://docs.ollama.com/api/chat) — endpoint, request/response format, `stream: false` behaviour, system message format. Verified 2026-03-02.
- [Ollama /api/tags documentation](https://docs.ollama.com/api/tags) — model list response format (`models[].name`). Verified 2026-03-02.
- [Ollama GitHub api.md](https://github.com/ollama/ollama/blob/main/docs/api.md) — `/api/generate` and `/api/chat` non-streaming response bodies confirmed. Verified 2026-03-02.
- AppState.swift source (verified 2026-03-02) — exact `autoPasteEnabled` pattern, `stopRecording()` integration point at line 200-210, `menuBarIcon` computed property structure.
- MenuBarView.swift source (verified 2026-03-02) — `optionsSection` structure, Toggle pattern.
- AppError.swift source (verified 2026-03-02) — enum case pattern to replicate for `aiProcessingFailed`.
- Package.swift source (verified 2026-03-02) — no URLSession dependency needed (built-in Foundation), confirms no new package required.

### Secondary (MEDIUM confidence)

- [ollama-swift by mattt](https://github.com/mattt/ollama-swift) — validates Ollama Swift API surface; confirms `/api/chat` with messages array is the correct endpoint for system prompt + user message pattern. MIT, macOS 13+.
- [OllamaKit](https://github.com/kevinhermawan/OllamaKit) — alternative library; confirms `stream: false` is the correct non-streaming flag. v5.0.8, Swift 5.9+.
- [Ollama apidog documentation](https://ollama.apidog.io/chat-request-no-streaming-14808920e0) — non-streaming request/response format cross-verified.

### Tertiary (LOW confidence — contextual only)

- WebSearch results for URLSession async/await patterns — standard Swift documentation; not flagging as LOW for URLSession itself (it's HIGH from Apple docs), but the specific Ollama+Swift integration examples from WebSearch are unverified community articles.

---

## Metadata

**Confidence breakdown:**
- Standard stack (URLSession, Codable): HIGH — native Apple API, well-documented, used throughout the existing codebase (RecordingController uses async/await; ClipboardManager uses Foundation)
- Architecture (protocol, integration point, toggle pattern): HIGH — integration point verified from source; protocol pattern is standard Swift; toggle matches existing `autoPasteEnabled` exactly
- Ollama API format (request/response, `stream: false`): HIGH — verified from official Ollama docs and cross-validated with three independent sources
- Pitfalls: HIGH (streaming default, model mismatch, defer pattern) — verified from official API behaviour and existing project GOTCHAS section in CLAUDE.md; MEDIUM for timeout calibration (empirical, not yet measured)

**Research date:** 2026-03-02
**Valid until:** 2026-04-02 (Ollama API is stable; URLSession patterns are stable; review if Ollama breaks API compatibility)
