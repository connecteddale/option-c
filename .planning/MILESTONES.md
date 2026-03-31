# Milestones: Option-C

## v1.0 — Core Voice-to-Clipboard

**Completed:** 2026-02-01
**Phases:** 1-3 (7 plans total)

**What shipped:**
- Menu bar app with state-driven icon
- Toggle and push-to-talk recording modes
- WhisperKit on-device transcription
- Auto-clipboard with optional auto-paste
- Text replacements post-processing
- Error handling and permission management
- Timeout and auto-reset state transitions

**Post-milestone additions (untracked):**
- WhisperKit model selection (base/large)
- Hallucination filtering
- Auto-capitalisation of line starts
- Self-signed certificate for accessibility trust

## v1.1 — Smart Text Processing

**Completed:** 2026-03-02
**Phases:** 4-5 (4 plans total)

**What shipped:**
- LLMProcessingProvider protocol — swappable AI provider architecture
- OllamaProcessingEngine — Ollama HTTP API integration (localhost:11434)
- AnthropicProcessingEngine — Claude API provider (added post-phase as swap-in)
- AI text cleanup: punctuation, capitalisation, filler removal, British English
- AI toggle in menu bar (default off — user controls latency trade-off)
- Distinct processing icon (wand.and.stars) while AI runs
- Ollama availability checking (/api/tags) with user-facing status messages
- Graceful fallback — raw transcription always reaches clipboard on AI failure
- Provider and model selection persisted via @AppStorage

**Post-milestone stability fix (2026-03-31):**
- WhisperKit actor recreation after transcription timeout — prevents stuck serial queue
- 90s max recording duration cap — prevents large audio arrays overwhelming WhisperKit
- coreaudiod restart tip documented for stuck mic indicator (macOS TCC bug)
