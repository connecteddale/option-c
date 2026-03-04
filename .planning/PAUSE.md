# Pause State — v1.1 Smart Text Processing

## Where We Are

Milestone v1.1 is code-complete. Both phases (4 and 5) executed successfully. All 13 requirements implemented. App builds and installs.

## What Just Happened

During manual testing, small local Ollama models (llama3.2 3B, llama3.1 8B) proved unreliable with the full formatting rules (times, numbers, currencies). They hallucinate, parrot few-shot examples, or rewrite content instead of cleaning it.

**Decision:** Simplified the system prompt to reliable basics only:
1. Punctuation (commas, full stops, question marks)
2. Capitalisation (sentence starts, proper nouns)
3. Filler word removal (um, uh, er)
4. British English spelling
5. No rephrasing

Changed default model from llama3.2 to llama3.1:8b (more consistent).

**Dropped from prompt** (unreliable on small models):
- 24h time conversion (PROC-02)
- Number formatting under/over 10 (PROC-03)
- Currency symbol conversion (PROC-04)

## What Needs Testing

1. **Run the app with AI toggle ON** — record speech, verify cleanup works
2. **Test with Ollama stopped** — verify warning appears and raw text still reaches clipboard
3. **Test with wrong model name** — verify model-missing warning

## What's Unresolved

PROC-02, PROC-03, PROC-04 are not achievable with small local models. Options for future:
- Add Anthropic API as alternative provider (architecture supports swap)
- Try larger quantised models when hardware allows
- Implement time/number/currency as regex post-processing (deterministic, no LLM needed)

## Resume With

```
/gsd:resume-work
```

Or manually: build, install, test the 3 items above, then `/gsd:verify-work` or `/gsd:complete-milestone`.
