# Roadmap: Option-C

## Overview

Option-C delivers voice-to-clipboard automation via a macOS menu bar app. The roadmap follows a foundation-first approach: establish menu bar UI and state management (Phase 1), build the core recording and transcription pipeline (Phase 2), then add production-ready feedback and error handling (Phase 3). Each phase delivers a coherent, testable capability that enables the next.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Foundation & Menu Bar** - Menu bar UI with state visualization and hotkey detection
- [ ] **Phase 2: Core Recording & Transcription** - Voice-to-clipboard workflow (record → transcribe → clipboard)
- [ ] **Phase 3: Feedback & Error Handling** - Production UX with notifications and permission handling

## Phase Details

### Phase 1: Foundation & Menu Bar
**Goal**: User has a functional menu bar app that responds to Option-C and visualizes recording states

**Depends on**: Nothing (first phase)

**Requirements**: MENU-01, MENU-02, MENU-03, MENU-04, MENU-05, CORE-04

**Success Criteria** (what must be TRUE):
  1. App appears in menu bar with visible icon
  2. Icon changes appearance when user presses Option-C (idle → recording state)
  3. Menu dropdown shows current mode (toggle vs push-to-talk)
  4. User can switch between toggle and push-to-talk modes via menu
  5. User can quit app via menu option

**Plans**: 2 plans

Plans:
- [ ] 01-01-PLAN.md — Project setup with MenuBarExtra and state management
- [ ] 01-02-PLAN.md — Hotkey integration and menu content

### Phase 2: Core Recording & Transcription
**Goal**: User can speak into microphone and get transcribed text on clipboard

**Depends on**: Phase 1 (needs state management foundation)

**Requirements**: CORE-01, CORE-02, CORE-03, TRAN-01, TRAN-02, TRAN-03

**Success Criteria** (what must be TRUE):
  1. User can start recording by pressing Option-C (toggle mode)
  2. User can stop recording by pressing Option-C again
  3. User can hold Option-C to record and release to stop (push-to-talk mode)
  4. Audio is transcribed using on-device Speech framework (no internet required)
  5. Transcribed text appears on clipboard automatically when ready

**Plans**: TBD

Plans:
- [ ] TBD (will be defined during plan-phase)

### Phase 3: Feedback & Error Handling
**Goal**: User receives clear feedback on success/failure and understands permission issues

**Depends on**: Phase 2 (needs working recording/transcription to provide feedback on)

**Requirements**: FEED-01, FEED-02, FEED-03, ERRH-01, ERRH-02, ERRH-03

**Success Criteria** (what must be TRUE):
  1. Notification appears when transcription is ready and copied to clipboard
  2. Notification appears if transcription fails (with reason)
  3. App returns to idle state after transcription completes or fails
  4. User sees clear message if microphone permission is missing
  5. User sees clear message if speech recognition permission is missing
  6. Timeout notification appears if no speech detected for 30 seconds

**Plans**: TBD

Plans:
- [ ] TBD (will be defined during plan-phase)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation & Menu Bar | 0/2 | Not started | - |
| 2. Core Recording & Transcription | 0/TBD | Not started | - |
| 3. Feedback & Error Handling | 0/TBD | Not started | - |

---
*Created: 2026-02-01*
*Last updated: 2026-02-01*
