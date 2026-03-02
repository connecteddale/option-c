---
phase: 05-formatting-quality-and-error-resilience
plan: 01
subsystem: processing
tags: [ollama, llm, prompt-engineering, british-english, text-formatting]

requires:
  - phase: 04-ollama-engine-and-pipeline-integration
    provides: OllamaProcessingEngine with placeholder prompt and LLMProcessingProvider protocol
provides:
  - Full formatting system prompt with 8 rules, 3 few-shot examples, and injection boundary
  - Configurable Ollama model name via @AppStorage
affects: [05-02, future prompt tuning]

tech-stack:
  added: []
  patterns: ["static system prompt for LLM formatting rules", "@AppStorage for model preference"]

key-files:
  created: []
  modified:
    - Sources/OptionC/Processing/OllamaProcessingEngine.swift
    - Sources/OptionC/State/AppState.swift

key-decisions:
  - "Used static let for systemPrompt since it is constant across all engine instances"
  - "Removed singleton shared property to support configurable model name from AppState"
  - "Computed var llmProvider creates fresh engine on each access — lightweight since URLSession is shared globally"

patterns-established:
  - "Few-shot examples in system prompt for consistent formatting behaviour"
  - "Prompt injection boundary as final line of system prompt"

requirements-completed: [PROC-01, PROC-02, PROC-03, PROC-04, PROC-05, LLM-04]

duration: 3 min
completed: 2026-03-02
---

# Phase 5 Plan 01: Full Formatting Rules Prompt and Model Preference Summary

**Production system prompt with 8 British English formatting rules, 3 few-shot examples, prompt injection boundary, and configurable Ollama model via @AppStorage**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-02T14:22:00Z
- **Completed:** 2026-03-02T14:25:44Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Replaced placeholder system prompt with full formatting rules covering punctuation, capitalisation, filler removal, 24h times, number formatting, currencies, anti-rephrase, and output-only constraint
- Added 3 few-shot examples demonstrating time, currency, and number handling
- Added prompt injection boundary as final line
- Made Ollama model name a user preference via @AppStorage("ollamaModel")
- Changed llmProvider to computed property that creates engine with current model preference

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace placeholder prompt with full formatting rules** - `4866731` (feat)
2. **Task 2: Add @AppStorage ollamaModel and computed llmProvider** - `48194a5` (feat)

## Files Created/Modified
- `Sources/OptionC/Processing/OllamaProcessingEngine.swift` - Full formatting system prompt, removed singleton
- `Sources/OptionC/State/AppState.swift` - @AppStorage ollamaModel, computed llmProvider

## Decisions Made
- Used `private static let` for systemPrompt since the prompt is constant across all instances
- Removed `static let shared` singleton to support configurable model name
- Computed var `llmProvider` creates fresh OllamaProcessingEngine on each access (lightweight, URLSession is shared globally by Foundation)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- System prompt is production-ready with all PROC requirements encoded
- Model name is configurable and persisted
- Ready for Plan 05-02: Ollama availability checking and error resilience UI

---
*Phase: 05-formatting-quality-and-error-resilience*
*Completed: 2026-03-02*
