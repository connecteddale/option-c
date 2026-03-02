# Requirements: Option-C

**Defined:** 2026-03-02
**Core Value:** Voice-to-clipboard with a single keyboard shortcut

## v1.1 Requirements

Requirements for milestone v1.1 — Smart Text Processing. Each maps to roadmap phases.

### Text Processing

- [x] **PROC-01**: User's transcription has correct punctuation (commas, semicolons, full stops, question marks)
- [x] **PROC-02**: User's spoken times are converted to standard 24h format (e.g. "quarter past three" becomes "15:15")
- [x] **PROC-03**: User's spoken numbers under 10 remain as words, numbers 10 and over are converted to digits
- [x] **PROC-04**: User's spoken currencies are converted to symbols with figures (e.g. "fifty pounds" becomes "£50")
- [x] **PROC-05**: User's transcription has correct spelling and capitalisation

### LLM Integration

- [x] **LLM-01**: App calls Ollama HTTP API (localhost:11434) with configurable timeout
- [x] **LLM-02**: LLM provider is behind a protocol so Ollama can be swapped for Anthropic API later
- [x] **LLM-03**: App checks Ollama availability and model presence before enabling AI toggle
- [x] **LLM-04**: System prompt encodes all formatting rules (times, numbers, currencies, punctuation, spelling)

### UX

- [x] **UX-01**: User can toggle AI processing on/off via menu bar dropdown
- [x] **UX-02**: Menu bar icon shows distinct state when AI is processing
- [x] **UX-03**: User sees clear error message if Ollama is not running or model is missing
- [x] **UX-04**: If AI processing fails, raw WhisperKit text is delivered to clipboard (never lose transcription)

## Future Requirements

Deferred to future milestones. Tracked but not in current roadmap.

### Provider Options

- **PROV-01**: User can switch between Ollama and Anthropic API as LLM provider
- **PROV-02**: User can configure Anthropic API key via settings

### Advanced Formatting

- **ADVF-01**: AI reformatting modes (formal, code, casual)
- **ADVF-02**: Context awareness (detect focused app, format accordingly)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Anthropic API as primary provider | Ollama first; API is future fallback if quality insufficient |
| Live transcription preview | Complexity not justified |
| History with playback | Not part of text processing milestone |
| Multi-language support | Not needed currently |
| Model fine-tuning | Overkill for formatting task |
| Streaming LLM output | Unnecessary for short transcription text |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| PROC-01 | Phase 5 | Complete |
| PROC-02 | Phase 5 | Complete |
| PROC-03 | Phase 5 | Complete |
| PROC-04 | Phase 5 | Complete |
| PROC-05 | Phase 5 | Complete |
| LLM-01 | Phase 4 | Complete |
| LLM-02 | Phase 4 | Complete |
| LLM-03 | Phase 5 | Complete |
| LLM-04 | Phase 5 | Complete |
| UX-01 | Phase 4 | Complete |
| UX-02 | Phase 4 | Complete |
| UX-03 | Phase 5 | Complete |
| UX-04 | Phase 5 | Complete |

**Coverage:**
- v1.1 requirements: 13 total
- Mapped to phases: 13
- Unmapped: 0

---
*Requirements defined: 2026-03-02*
*Last updated: 2026-03-02 — Phase 4 requirements (LLM-01, LLM-02, UX-01, UX-02) verified complete*
