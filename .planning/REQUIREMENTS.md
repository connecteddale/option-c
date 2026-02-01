# Requirements: Option-C

**Defined:** 2026-02-01
**Core Value:** Voice-to-clipboard with a single keyboard shortcut

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Core Recording

- [ ] **CORE-01**: User can start recording by pressing Option-C
- [ ] **CORE-02**: User can stop recording by pressing Option-C again (toggle mode)
- [ ] **CORE-03**: User can hold Option-C to record and release to stop (push-to-talk mode)
- [ ] **CORE-04**: User can switch between toggle and push-to-talk modes via menu

### Menu Bar

- [ ] **MENU-01**: App appears in menu bar with icon
- [ ] **MENU-02**: Icon visually changes when recording (idle → recording)
- [ ] **MENU-03**: Icon visually changes when processing transcription (recording → processing)
- [ ] **MENU-04**: Menu shows current mode (toggle/push-to-talk)
- [ ] **MENU-05**: Menu allows quitting the app

### Transcription

- [ ] **TRAN-01**: Audio is transcribed using on-device Speech framework
- [ ] **TRAN-02**: Transcription runs offline (no internet required)
- [ ] **TRAN-03**: Transcription text is copied to clipboard automatically

### Feedback

- [ ] **FEED-01**: Notification appears when transcription is ready
- [ ] **FEED-02**: Notification appears if transcription fails
- [ ] **FEED-03**: App returns to idle state after completion

### Error Handling

- [ ] **ERRH-01**: App handles missing microphone permission gracefully
- [ ] **ERRH-02**: App handles missing speech recognition permission gracefully
- [ ] **ERRH-03**: App shows timeout error if no speech detected for 30 seconds

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Differentiators

- **DIFF-01**: Live transcription preview (text appears as user speaks)
- **DIFF-02**: Context awareness (detect focused app, format accordingly)
- **DIFF-03**: AI reformatting modes (formal, code, casual)
- **DIFF-04**: History with playback (review past transcriptions)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Multi-language support | User doesn't need it; can add later if requested |
| File transcription | This is a clipboard tool, not a transcription service |
| Cloud sync / accounts | Privacy-first, local-only approach |
| Audio storage | Delete after transcription; no history in v1 |
| Voice commands | Conflicts with macOS Voice Control |
| Custom notification sounds | Keep it minimal, use system defaults |
| Dock icon | Menu bar only, invisible until needed |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CORE-01 | TBD | Pending |
| CORE-02 | TBD | Pending |
| CORE-03 | TBD | Pending |
| CORE-04 | TBD | Pending |
| MENU-01 | TBD | Pending |
| MENU-02 | TBD | Pending |
| MENU-03 | TBD | Pending |
| MENU-04 | TBD | Pending |
| MENU-05 | TBD | Pending |
| TRAN-01 | TBD | Pending |
| TRAN-02 | TBD | Pending |
| TRAN-03 | TBD | Pending |
| FEED-01 | TBD | Pending |
| FEED-02 | TBD | Pending |
| FEED-03 | TBD | Pending |
| ERRH-01 | TBD | Pending |
| ERRH-02 | TBD | Pending |
| ERRH-03 | TBD | Pending |

**Coverage:**
- v1 requirements: 18 total
- Mapped to phases: 0
- Unmapped: 18 ⚠️

---
*Requirements defined: 2026-02-01*
*Last updated: 2026-02-01 after initial definition*
