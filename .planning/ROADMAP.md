# Roadmap: Option-C

## Milestones

- [x] **v1.0 Core Voice-to-Clipboard** - Phases 1-3 (shipped 2026-02-01)
- [ ] **v1.1 Smart Text Processing** - Phases 4-5 (in progress)

## Phases

<details>
<summary>v1.0 Core Voice-to-Clipboard (Phases 1-3) — SHIPPED 2026-02-01</summary>

### Phase 1: Foundation & Menu Bar
**Goal**: User has a functional menu bar app that responds to Option-C and visualizes recording states
**Depends on**: Nothing (first phase)
**Requirements**: MENU-01, MENU-02, MENU-03, MENU-04, MENU-05, CORE-04
**Success Criteria** (what must be TRUE):
  1. App appears in menu bar with visible icon
  2. Icon changes appearance when user presses Option-C (idle -> recording state)
  3. Menu dropdown shows current mode (toggle vs push-to-talk)
  4. User can switch between toggle and push-to-talk modes via menu
  5. User can quit app via menu option
**Plans**: 2 plans

Plans:
- [x] 01-01-PLAN.md — Project setup with MenuBarExtra and state management
- [x] 01-02-PLAN.md — Hotkey integration and menu content

### Phase 2: Core Recording & Transcription
**Goal**: User can speak into microphone and get transcribed text on clipboard
**Depends on**: Phase 1
**Requirements**: CORE-01, CORE-02, CORE-03, TRAN-01, TRAN-02, TRAN-03
**Success Criteria** (what must be TRUE):
  1. User can start recording by pressing Option-C (toggle mode)
  2. User can stop recording by pressing Option-C again
  3. User can hold Option-C to record and release to stop (push-to-talk mode)
  4. Audio is transcribed using on-device Speech framework (no internet required)
  5. Transcribed text appears on clipboard automatically when ready
**Plans**: 2 plans

Plans:
- [x] 02-01-PLAN.md — Audio infrastructure (AudioCaptureManager + TranscriptionEngine)
- [x] 02-02-PLAN.md — Integration and clipboard (RecordingController + AppState wiring)

### Phase 3: Feedback & Error Handling
**Goal**: User receives clear feedback on success/failure and understands permission issues
**Depends on**: Phase 2
**Requirements**: FEED-01, FEED-02, FEED-03, ERRH-01, ERRH-02, ERRH-03
**Success Criteria** (what must be TRUE):
  1. Notification appears when transcription is ready and copied to clipboard
  2. Notification appears if transcription fails (with reason)
  3. App returns to idle state after transcription completes or fails
  4. User sees clear message if microphone permission is missing
  5. User sees clear message if speech recognition permission is missing
  6. Timeout notification appears if no speech detected for 30 seconds
**Plans**: 3 plans

Plans:
- [x] 03-01-PLAN.md — Error types and permission handling (AppError, PermissionManager)
- [x] 03-02-PLAN.md — Notification system (NotificationManager, permission request on launch)
- [x] 03-03-PLAN.md — State machine integration (auto-reset, timeout, wiring)

</details>

### v1.1 Smart Text Processing (In Progress)

**Milestone Goal:** Add intelligent text post-processing via local LLM (Ollama) so transcriptions come back properly formatted — punctuation, 24h times, number formatting, currencies, spelling, capitalisation.

#### Phase 4: Ollama Engine and Pipeline Integration
**Goal**: User can enable AI text cleanup via a menu toggle and see a distinct state while Ollama processes their transcription
**Depends on**: Phase 3
**Requirements**: LLM-01, LLM-02, UX-01, UX-02
**Success Criteria** (what must be TRUE):
  1. User can toggle AI text cleanup on and off from the menu bar dropdown with one click
  2. Menu bar shows a distinct state (different icon or label) while Ollama is processing
  3. When AI is on and Ollama is available, transcription passes through OllamaProcessingEngine before reaching clipboard
  4. When AI is off, the pipeline behaves identically to v1.0 (no change to existing behaviour)
**Plans**: 2 plans

Plans:
- [ ] 04-01-PLAN.md — OllamaProcessingEngine: LLMProcessingProvider protocol, URLSession wrapper, Codable models, AppError case
- [ ] 04-02-PLAN.md — AppState integration: pipeline wiring, aiProcessingEnabled toggle, aiProcessing state, MenuBarView toggle, distinct icon

#### Phase 5: Formatting Quality and Error Resilience
**Goal**: User's transcriptions are correctly formatted across punctuation, times, numbers, and currencies, and the app handles Ollama being unavailable without losing the transcription
**Depends on**: Phase 4
**Requirements**: PROC-01, PROC-02, PROC-03, PROC-04, PROC-05, LLM-03, LLM-04, UX-03, UX-04
**Success Criteria** (what must be TRUE):
  1. Spoken times convert to 24h format (e.g. "quarter past three" becomes "15:15")
  2. Spoken numbers ten and over convert to digits; numbers under ten remain as words
  3. Spoken currencies convert to symbols and figures (e.g. "fifty pounds" becomes "£50")
  4. Transcription has correct punctuation, spelling, and capitalisation after AI processing
  5. If Ollama is not running or model is missing, user sees a clear error message and the raw transcription is still delivered to clipboard
**Plans**: TBD

Plans:
- [ ] 05-01: System prompt — encode all formatting rules (punctuation, times, numbers, currencies, spelling, capitalisation, output-only constraint, prompt injection boundary)
- [ ] 05-02: Availability checking and error resilience — LLM-03 health check before enabling toggle, UX-03 error messaging, UX-04 graceful fallback

## Progress

**Execution Order:**
Phases execute in numeric order: 4 -> 5

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation & Menu Bar | v1.0 | 2/2 | Complete | 2026-02-01 |
| 2. Core Recording & Transcription | v1.0 | 2/2 | Complete | 2026-02-01 |
| 3. Feedback & Error Handling | v1.0 | 3/3 | Complete | 2026-02-01 |
| 4. Ollama Engine and Pipeline Integration | v1.1 | 0/2 | Not started | - |
| 5. Formatting Quality and Error Resilience | v1.1 | 0/2 | Not started | - |

---
*Created: 2026-02-01*
*Last updated: 2026-03-02 (Phase 4 plans created)*
