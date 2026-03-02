---
phase: 05-formatting-quality-and-error-resilience
status: human_needed
verified: 2026-03-02
requirement_ids: [PROC-01, PROC-02, PROC-03, PROC-04, PROC-05, LLM-03, LLM-04, UX-03, UX-04]
---

# Phase 5: Formatting Quality and Error Resilience — Verification

## Phase Goal
User's transcriptions are correctly formatted across punctuation, times, numbers, and currencies, and the app handles Ollama being unavailable without losing the transcription.

## Success Criteria Verification

### 1. Spoken times convert to 24h format
**Status: PASSED (code)**
- System prompt rule 4 encodes: "Times - convert to 24-hour format"
- Examples: quarter past three = 15:15, half past nine = 09:30, ten to five = 16:50
- 3 few-shot examples demonstrate time conversion
- File: `Sources/OptionC/Processing/OllamaProcessingEngine.swift` lines 34-36

### 2. Spoken numbers ten and over convert to digits; numbers under ten remain as words
**Status: PASSED (code)**
- System prompt rule 5 encodes: "Numbers - keep numbers under 10 as words; convert 10 and over to digits"
- Examples: three stays three, nine stays nine, ten becomes 10, fifteen becomes 15
- File: `Sources/OptionC/Processing/OllamaProcessingEngine.swift` lines 37-39

### 3. Spoken currencies convert to symbols and figures
**Status: PASSED (code)**
- System prompt rule 6 encodes: "Currencies - convert to symbol and digits"
- Examples: fifty pounds = £50, twenty dollars = $20, a hundred euros = €100
- File: `Sources/OptionC/Processing/OllamaProcessingEngine.swift` lines 40-41

### 4. Transcription has correct punctuation, spelling, and capitalisation after AI processing
**Status: PASSED (code)**
- System prompt rule 1: "Fix punctuation - add commas, full stops, and question marks where missing"
- System prompt rule 2: "Fix capitalisation - capitalise sentence starts and proper nouns only"
- System prompt rule 3: "Remove filler words - um, uh, er, like..."
- File: `Sources/OptionC/Processing/OllamaProcessingEngine.swift` lines 31-33

### 5. If Ollama is not running or model is missing, user sees clear error message and raw transcription is still delivered to clipboard
**Status: PASSED (code)**
- `checkAvailability()` queries `/api/tags` with 5s timeout
- Returns `.ollamaNotRunning` or `.modelNotFound(configured:)` with clear user messages
- Warning shows inline in menu bar when AI toggle on but Ollama unavailable
- Graceful fallback in `stopRecording()` preserved: `catch { /* finalText stays as text */ }`
- Files: `OllamaProcessingEngine.swift`, `AppState.swift`, `MenuBarView.swift`

## Requirement Verification

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| PROC-01 | Correct punctuation | PASSED | System prompt rule 1 + few-shot examples |
| PROC-02 | 24h time format | PASSED | System prompt rule 4 + 3 examples |
| PROC-03 | Number formatting (words/digits) | PASSED | System prompt rule 5 + examples |
| PROC-04 | Currency symbols | PASSED | System prompt rule 6 + examples |
| PROC-05 | Correct spelling and capitalisation | PASSED | System prompt rules 1-2 |
| LLM-03 | Check Ollama availability | PASSED | checkAvailability() method with /api/tags |
| LLM-04 | System prompt encodes all rules | PASSED | 8 rules + 3 examples + injection boundary |
| UX-03 | Clear error for Ollama unavailable | PASSED | Inline warning with specific instructions |
| UX-04 | Graceful fallback to raw text | PASSED | try/catch fallback in stopRecording() preserved |

## Must-Have Verification (Plan 05-01)

- [x] System prompt encodes all formatting rules: punctuation, capitalisation, filler removal, 24h times, numbers under/over 10, currencies, anti-rephrase, output-only constraint
- [x] System prompt includes three few-shot examples demonstrating time, currency, number, and filler word handling
- [x] System prompt includes prompt injection boundary instruction as final line
- [x] Model name is stored in @AppStorage so it persists and can be changed without code edits
- [x] OllamaProcessingEngine uses the stored model preference, not a hardcoded default

## Must-Have Verification (Plan 05-02)

- [x] App checks Ollama availability when user enables the AI toggle -- not on app startup
- [x] When Ollama is not running, user sees a warning message with 'ollama serve' instruction in the menu dropdown
- [x] When configured model is not found, user sees a warning message with 'ollama pull' instruction in the menu dropdown
- [x] When Ollama is available and model is present, no warning appears
- [x] If AI processing fails at runtime, raw transcription still reaches clipboard -- existing fallback preserved
- [x] Availability check uses 5-second timeout, not the 60-second chat timeout
- [x] Model name comparison normalises both sides (strips :tag suffix)

## Build Verification

- [x] `swift build` succeeds with no errors or warnings
- [x] No new Package.swift dependencies added

## Human Verification Required

The following items require human testing with a running Ollama instance:

1. **AI formatting quality**: Enable AI toggle with Ollama running. Record speech containing times ("quarter past three"), numbers ("twenty five"), and currencies ("fifty pounds"). Verify output has correct formatting (15:15, 25, £50).

2. **Ollama unavailable warning**: Quit Ollama, enable AI toggle. Verify orange warning appears with "ollama serve" instruction. Start Ollama, disable and re-enable toggle. Verify warning disappears.

3. **Model missing warning**: Change ollamaModel in UserDefaults to a non-existent model, enable AI toggle. Verify warning shows "ollama pull" instruction.

4. **Graceful fallback**: Enable AI toggle with Ollama stopped. Record speech. Verify raw transcription (without AI formatting) reaches clipboard -- no crash, no lost text.

## Score

**Automated checks:** 9/9 requirements passed
**Human checks needed:** 4 items (formatting quality, warning UI, model missing, graceful fallback)

---
*Verified: 2026-03-02*
