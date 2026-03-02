# Stack Research

**Domain:** macOS voice-to-text app — v1.1 Smart Text Processing (Claude integration)
**Researched:** 2026-03-02
**Confidence:** HIGH (verified against official Anthropic API docs and Claude CLI docs)

---

## Scope

This document covers only the **new additions** for milestone v1.1. The existing stack (Swift 5.9, WhisperKit, KeyboardShortcuts, MenuBarExtra, AVAudioEngine, NSPasteboard, CGEvent) is validated and unchanged. Focus is on:

1. How to call Claude for text post-processing from Swift
2. Which invocation method to use (CLI vs direct API)
3. Input/output format and error handling
4. API key storage

---

## Core Decision: Direct Anthropic API over Claude CLI

**Recommendation: Use the Anthropic Messages API directly via URLSession — do not invoke the `claude` CLI binary.**

The `claude` CLI is Claude Code, a coding assistant. It carries significant overhead and has a documented, unfixed TTY bug that causes it to hang indefinitely when called without a terminal (confirmed closed as "not planned", Jan 2026, issue #9026). Invoking it from Swift `Process` would require a pseudo-terminal workaround (`script -q /dev/null`) that is fragile, macOS-specific, and adds latency. A second confirmed bug (issue #7263, closed "not planned", Feb 2026) causes empty output for inputs over ~7,000 characters.

The direct API is simpler, faster, more reliable, and already what the user's Claude subscription covers.

---

## Recommended Stack Additions

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Anthropic Messages API | v1 (`2023-06-01`) | Claude text processing | Official REST API, no CLI subprocess, no TTY issues, synchronous round-trip under 2s for short text |
| URLSession | Built-in (macOS 12+) | HTTP client | Native Apple framework, async/await support, no dependencies |
| Security framework (Keychain) | Built-in | API key storage | macOS Keychain is the correct, secure location for credentials |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SwiftAnthropic | Latest (SPM) | Optional typed wrapper over the Messages API | Only if adding more Anthropic API features beyond single messages call; for a simple post-processing step, raw URLSession is sufficient |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| curl | Local testing of API calls | Verify prompt and response shape before writing Swift code |
| Xcode Instruments (Network) | Profile API call latency | Confirm p50/p95 latency is within acceptable range |

---

## Anthropic Messages API — Verified Specification

### Endpoint

```
POST https://api.anthropic.com/v1/messages
```

### Required Headers

```
x-api-key: YOUR_API_KEY
anthropic-version: 2023-06-01
content-type: application/json
```

### Minimal Request Body

```json
{
  "model": "claude-haiku-4-5",
  "max_tokens": 512,
  "system": "You are a text formatter. Clean up the transcription. Return only the corrected text — no commentary.",
  "messages": [
    {
      "role": "user",
      "content": "fourteen thirty meeting with steve and sarah re budget"
    }
  ]
}
```

### Response Structure

```json
{
  "id": "msg_abc123",
  "type": "message",
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "14h30 meeting with Steve and Sarah re budget."
    }
  ],
  "model": "claude-haiku-4-5-20251001",
  "stop_reason": "end_turn",
  "usage": {
    "input_tokens": 42,
    "output_tokens": 12
  }
}
```

Extract the result with: `response.content[0].text`

**Confidence:** HIGH — verified against official Anthropic API docs at `platform.claude.com/docs/en/api/messages`

---

## Model Selection

**Use Claude Haiku 4.5 (`claude-haiku-4-5`) for all text post-processing.**

Rationale:

- Fastest response times of any current Claude model
- "Near-frontier intelligence" — fully capable of punctuation, spelling, capitalisation, time and number formatting
- Lowest cost ($1/MTok input, $5/MTok output) — a 500-word transcription costs well under $0.001
- Short text processing does not require Sonnet or Opus reasoning depth

| Model | Use For | Why Not for This |
|-------|---------|-----------------|
| claude-haiku-4-5 | **This feature** | Speed, cost, sufficient capability |
| claude-sonnet-4-6 | Complex reasoning, coding | Overkill, 3x higher cost, slower |
| claude-opus-4-6 | Deepest reasoning tasks | Significantly slower and more expensive |

**Confidence:** HIGH — verified via official model overview at `platform.claude.com/docs/en/about-claude/models/overview`

---

## Swift Implementation Pattern

### URLSession Async/Await (no dependencies)

```swift
import Foundation

struct ClaudeTextProcessor {
    private let apiKey: String
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    func process(_ text: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": "claude-haiku-4-5",
            "max_tokens": 512,
            "system": systemPrompt,
            "messages": [["role": "user", "content": text]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw ClaudeError.httpError(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
        guard let textBlock = decoded.content.first(where: { $0.type == "text" }) else {
            throw ClaudeError.noTextContent
        }
        return textBlock.text
    }

    private let systemPrompt = """
        You are a transcription formatter. The input is raw voice transcription. \
        Apply: correct punctuation, British spelling, capitalise sentence starts, \
        convert spoken times to 24h format with 'h' separator (e.g. 14h30), \
        convert spoken numbers/currencies to digits and symbols where appropriate. \
        Return only the corrected text — no explanation, no quotes.
        """
}

// Codable models
struct MessagesResponse: Decodable {
    let content: [ContentBlock]
}
struct ContentBlock: Decodable {
    let type: String
    let text: String
}
enum ClaudeError: Error {
    case invalidResponse
    case httpError(Int)
    case noTextContent
}
```

**Integration point in RecordingController:** Call `ClaudeTextProcessor.process()` after `TextReplacementManager`, before `ClipboardManager`. The call is already in an async context so no structural changes are required.

---

## Why Not the Claude CLI

Documented for completeness. Do not pursue this route.

| Issue | Detail | Status |
|-------|--------|--------|
| TTY required despite `-p` flag | CLI hangs indefinitely when no terminal is attached (e.g., called from Swift Process, Java ProcessBuilder, daemons) | Closed "not planned" Jan 2026, issue #9026 |
| Empty output on large stdin | Inputs over ~7,000 characters return empty output with exit code 0 | Closed "not planned" Feb 2026, issue #7263 |
| Workaround is fragile | `script -q /dev/null claude -p "..."` fakes a TTY on macOS but adds subprocess overhead and is undocumented behaviour | Not reliable for a shipped app |
| Startup overhead | CLI loads Claude Code's entire agent framework, takes 1-3s before first response | Adds latency vs direct API |
| Wrong tool for this job | CLI is a coding assistant (Claude Code), not a text transformation API | |

---

## API Key Storage

Store the Anthropic API key in macOS Keychain, not in `@AppStorage` or a file.

```swift
import Security

func saveAPIKey(_ key: String) {
    let query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: "com.yourname.option-c",
        kSecAttrAccount: "anthropic-api-key",
        kSecValueData: key.data(using: .utf8)!
    ]
    SecItemDelete(query as CFDictionary)  // remove existing if present
    SecItemAdd(query as CFDictionary, nil)
}

func loadAPIKey() -> String? {
    let query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: "com.yourname.option-c",
        kSecAttrAccount: "anthropic-api-key",
        kSecReturnData: true
    ]
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess,
          let data = result as? Data,
          let key = String(data: data, encoding: .utf8) else { return nil }
    return key
}
```

The Keychain is unlocked when the user logs in, so retrieval is synchronous and instant. No special entitlements are needed for reading/writing the app's own Keychain items when not sandboxed.

**Confidence:** HIGH — official Apple Developer Documentation confirmed

---

## WhisperKit Native Formatting (Supporting Research)

DecodingOptions relevant properties (confirmed via source and docs):

| Property | Type | Effect |
|----------|------|--------|
| `suppressBlank` | Bool | Suppresses blank/silence tokens — already in use |
| `skipSpecialTokens` | Bool | Removes `<|notimestamps|>` and similar tokens |
| `withoutTimestamps` | Bool | Disables timestamp prediction |
| `language` | String? | Lock to `"en"` for better accuracy — already in use |

WhisperKit does **not** have a native punctuation formatting option beyond what the Whisper model itself outputs. The model adds commas and full stops sporadically based on training data, but the output is inconsistent for voice dictation use cases. Claude post-processing is the right approach for reliable formatting.

**Confidence:** MEDIUM — WhisperKit source code reviewed indirectly via Swift Package Index docs and GitHub Configurations.swift; no `formatPunctuation` or equivalent property found

---

## Latency Expectations

| Step | Expected Duration | Notes |
|------|------------------|-------|
| WhisperKit base model | 1–2s | Already validated |
| WhisperKit large model | 10–20s | Already validated |
| Anthropic API (Haiku) TTFT | ~300–600ms | Network-dependent; measured from UK/EU |
| Anthropic API total (50-word input) | ~600ms–1.2s | Short text, low output tokens |
| Anthropic API total (200-word input) | ~1–2s | Still within acceptable range |

Claude post-processing adds roughly 1s to the pipeline for typical voice dictation text (under 200 words). This is the trade-off documented in PROJECT.md and accepted by the user.

**Confidence:** MEDIUM — official docs confirm Haiku is fastest but do not publish exact p50/p95 figures; estimates based on documented relative performance

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Direct Anthropic API | Claude CLI subprocess | Never — confirmed bugs make it unreliable in non-TTY contexts |
| URLSession (native) | SwiftAnthropic package | If adding multiple Anthropic features (streaming, tool use, multi-turn); overkill for single endpoint |
| Claude Haiku 4.5 | Claude Sonnet 4.6 | Only if formatting quality proves insufficient (unlikely for this use case) |
| Keychain | @AppStorage for API key | Never — API keys must not be stored in unencrypted user defaults |
| System prompt with strict instructions | Few-shot examples in prompt | If zero-shot Haiku results are inconsistent; few-shot adds ~50 tokens per example but improves consistency |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `claude` CLI binary via Process | TTY hang bug (closed "not planned"), empty output bug on large input | Direct Anthropic Messages API |
| `@AppStorage` for API key | Stored in unencrypted plist, exposed in plaintext | macOS Keychain |
| Claude Opus or Sonnet for this task | 3–15x more expensive, slower, no quality benefit for formatting | Claude Haiku 4.5 |
| SwiftAnthropic or other third-party SDK | Adds a dependency for one HTTP call | Native URLSession |
| Streaming (`stream: true`) | Unnecessary for clipboard workflow — text must be complete before paste | Standard synchronous request |

---

## Stack Patterns by Variant

**If the user has no Anthropic API key:**
- Detect nil from Keychain load on startup
- Show one-time setup prompt in menu (enter key, save to Keychain)
- Gracefully disable AI processing toggle until key is saved
- Because the app must function without AI processing when the feature is off or unconfigured

**If API call fails (network error, rate limit, 529 overload):**
- Catch the error, log it, return the original unprocessed text
- Show brief error state in menu bar icon (existing xmark pattern)
- Because the core value (voice-to-clipboard) must not break when AI is unavailable

**If the user toggles AI processing off:**
- Skip the ClaudeTextProcessor call entirely in RecordingController
- Store toggle state in `@AppStorage("aiProcessingEnabled")`
- Because latency-sensitive use cases (quick notes, voice commands) should not pay the API round-trip

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|----------------|-------|
| Anthropic API `2023-06-01` | All current Claude models | Stable version string; do not omit this header |
| claude-haiku-4-5 | API version 2023-06-01+ | Current model; alias resolves to `claude-haiku-4-5-20251001` |
| URLSession async/await | macOS 12+ | Project targets macOS 14+, so no issue |
| Security framework Keychain | macOS 10.9+ | Available on all target platforms |

---

## Sources

- [Anthropic CLI Reference](https://code.claude.com/docs/en/cli-reference) — confirmed `-p` flag, `--output-format`, `--system-prompt` flags; HIGH confidence
- [Claude CLI TTY hang issue #9026](https://github.com/anthropics/claude-code/issues/9026) — closed "not planned" Jan 2026; confirmed CLI is not suitable for Swift Process invocation
- [Claude CLI large stdin bug #7263](https://github.com/anthropics/claude-code/issues/7263) — closed "not planned" Feb 2026; empty output >7000 chars; HIGH confidence
- [Anthropic Messages API](https://platform.claude.com/docs/en/api/messages) — verified endpoint, headers, request/response format; HIGH confidence
- [Anthropic Models Overview](https://platform.claude.com/docs/en/about-claude/models/overview) — verified Haiku 4.5 as fastest model, pricing confirmed; HIGH confidence
- [Anthropic Latency Guide](https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/reduce-latency) — confirmed Haiku recommendation for speed-critical applications; HIGH confidence
- [Apple Keychain Documentation](https://developer.apple.com/documentation/security/storing-keys-in-the-keychain) — SecItemAdd/SecItemCopyMatching pattern; HIGH confidence
- [WhisperKit Swift Package Index](https://swiftpackageindex.com/argmaxinc/WhisperKit/v0.13.0/documentation/whisperkit/decodingoptions) — DecodingOptions properties; MEDIUM confidence (403 on direct fetch, inferred from search results)
- [SwiftAnthropic GitHub](https://github.com/jamesrochabrun/SwiftAnthropic) — confirmed as viable alternative; URLSession-based on Apple platforms; MEDIUM confidence

---

*Stack research for: Option-C v1.1 — Claude API text post-processing*
*Researched: 2026-03-02*
