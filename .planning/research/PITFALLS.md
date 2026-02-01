# Domain Pitfalls: macOS Voice-to-Clipboard Automation

**Domain:** macOS menu bar app with voice transcription automation
**Researched:** 2026-02-01
**Confidence:** HIGH

## Critical Pitfalls

Mistakes that cause rewrites, data loss, or major security/performance issues.

### Pitfall 1: SQLite Database Locking from Voice Memos App

**What goes wrong:** Your app reads from CloudRecordings.db while Voice Memos app is actively writing to it, causing "database is locked" errors (SQLITE_BUSY/SQLITE_LOCKED). Voice Memos holds exclusive locks during recording and transcription writes.

**Why it happens:** SQLite uses file-level locking. When Voice Memos commits transcription data (which can take 10-30s), it holds a RESERVED lock. Concurrent reads from your app trigger SQLITE_BUSY if they arrive during this critical window.

**Consequences:**
- Intermittent failures that users can't reproduce consistently
- Transcription data appears "missing" during lock contention
- App appears broken when Voice Memos is actively used
- Data corruption if you bypass locks incorrectly

**Prevention:**
1. Open database in read-only mode with `SQLITE_OPEN_READONLY` flag
2. Enable WAL (Write-Ahead Logging) mode if possible - allows concurrent reads during writes
3. Set `busy_timeout` to at least 5000ms (5 seconds) to wait for locks
4. Implement exponential backoff retry logic (3-5 attempts)
5. Use `PRAGMA journal_mode=WAL;` to check/enable WAL mode
6. NEVER write to Voice Memos database - treat as read-only

**Detection:**
- SQLITE_BUSY (error code 5) in logs
- Queries returning no results despite recordings existing
- Failures specifically when Voice Memos app is open
- Timeout errors after 5+ seconds

**Phase to address:** Foundation/Phase 1 - Core database access patterns

**Sources:**
- [SQLite File Locking And Concurrency](https://sqlite.org/lockingv3.html)
- [Understanding SQLite Database is Locked Error](https://www.beekeeperstudio.io/blog/how-to-solve-sqlite-database-is-locked-error)
- [SQLite Concurrent Writes and Database Locking](https://tenthousandmeters.com/blog/sqlite-concurrent-writes-and-database-is-locked-errors/)

---

### Pitfall 2: Full Disk Access Permission Loss Bug

**What goes wrong:** macOS has a confirmed bug across Mojave through Ventura that causes apps to spontaneously lose Full Disk Access permission, even though the checkbox remains checked in System Settings. Your app suddenly can't read Voice Memos database despite user having granted access.

**Why it happens:** Corruption in the TCC (Transparency, Consent, and Control) database at `~/Library/Application Support/com.apple.TCC/TCC.db`. System updates, security patches, or even app updates can trigger the bug.

**Consequences:**
- App stops working with no obvious cause to users
- Users blame your app, not macOS
- Standard troubleshooting (recheck permission) doesn't fix it
- Requires advanced terminal commands to repair

**Prevention:**
1. Implement graceful error handling with specific "Full Disk Access required" messaging
2. Check access BEFORE attempting database operations using `FileManager.isReadableFile(atPath:)`
3. Provide clear UI showing permission status in menu bar
4. Include in-app documentation linking to System Settings path
5. Log permission check failures separately from database errors
6. Monitor for `NSFileReadNoPermissionError` and provide user-friendly remediation

**Detection:**
- Permission check passes but file access fails
- Error messages referencing "Operation not permitted"
- Works after toggling FDA off/on or running `sudo tccutil reset All`
- User reports "stopped working after macOS update"

**Phase to address:** Foundation/Phase 1 - Permission handling system

**Sources:**
- [Full Disk Access Bug Across macOS Versions](https://iboysoft.com/wiki/full-disk-access-mac.html)
- [macOS TCC Documentation](https://www.huntress.com/blog/full-transparency-controlling-apples-tcc)
- [TCC Bypass and Security Issues](https://www.sentinelone.com/labs/bypassing-macos-tcc-user-privacy-protections-by-accident-and-design/)

---

### Pitfall 3: Global Hotkey Conflicts and Silent Failures

**What goes wrong:** Your Option-C hotkey either (1) conflicts with existing system/app shortcuts, causing neither to work, or (2) fails silently because you didn't request Accessibility permissions alongside hotkey registration.

**Why it happens:**
- macOS doesn't enforce hotkey uniqueness - last registered wins
- Apps like Figma, Adobe Suite, dev tools heavily use Option+key combos
- `NSEvent.addGlobalMonitorForEventsMatchingMask` returns success but handler never fires without Accessibility permission
- No runtime error - just silently fails

**Consequences:**
- User presses Option-C and nothing happens
- User's existing shortcuts break and they blame your app
- Accessibility permission denial causes silent failure (no error shown)
- Works on developer machine, fails in production

**Prevention:**
1. Use CGEventTap instead of NSEvent for proper global hotkey registration
2. Request Accessibility permission BEFORE registering hotkeys
3. Detect conflicts by testing if hotkey fires after registration
4. Provide UI for customizing the hotkey (don't hardcode Option-C)
5. Check for common conflicts: Figma (Option-C for comments), Adobe apps, developer tools
6. Implement fallback: menu bar click if hotkey fails
7. Use ShortcutRecorder or similar library for proper conflict detection

**Detection:**
- Handler function never called after registration
- Accessibility permission not granted in System Settings
- User reports "hotkey doesn't work" but app is running
- Works with different key combination

**Phase to address:** Foundation/Phase 1 - Hotkey registration system

**Sources:**
- [Global Hotkey Conflicts and Issues](https://github.com/block/goose/issues/6488)
- [NSEvent Global Monitor Limitations](https://github.com/keepassxreboot/keepassxc/issues/3393)
- [Apple Monitoring Events Documentation](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html)
- [Accessibility Permissions for Hotkeys](https://wiki.keyboardmaestro.com/assistance/Accessibility_Permission_Problem)

---

### Pitfall 4: Voice Memos Database Schema Changes Across macOS Versions

**What goes wrong:** Your app queries specific columns in CloudRecordings.db (like `ZTRANSCRIPTTEXT`) that exist in macOS Sonoma but don't exist in Ventura or get renamed in future macOS versions. App crashes or fails on different OS versions.

**Why it happens:** Apple doesn't document the Voice Memos database schema and changes it between major macOS releases. iOS 12 had major schema changes from iOS 10. The database location itself changed from Ventura to Sonoma.

**Consequences:**
- App works on your development machine (macOS Sonoma) but crashes on customer's Ventura
- Silent failures when querying non-existent columns
- Hard to test - requires multiple macOS VMs
- Breaking changes in macOS 27 require emergency updates

**Prevention:**
1. Query schema at runtime using `PRAGMA table_info(ZCLOUDRECORDING)`
2. Use defensive column checks before SELECT queries
3. Maintain version-specific query builders based on detected schema
4. Test on minimum supported macOS version (suggest macOS 13+)
5. Monitor table structure: ZCLOUDRECORDING (main table), ZPATH, ZCUSTOMLABEL, ZDATE, ZDURATION
6. Don't hardcode column names - build queries dynamically after schema detection
7. Have fallback behavior if transcription columns don't exist

**Detection:**
- `no such column` SQLite errors
- Different results on different macOS versions
- Beta testers on macOS 27 reporting crashes
- Missing expected data fields

**Phase to address:** Foundation/Phase 1 - Database schema abstraction layer

**Sources:**
- [Voice Memos Database Structure Research](https://www.researchgate.net/figure/The-database-structure-of-the-Voice-Memos-in-the-iOS-12_fig1_337598372)
- [Voice Memos Location Changes](https://nono.ma/location-of-apple-voice-memos)
- [iOS Voice Memos Forensics](https://forensafe.com/blogs/iOSVoiceMemos.html)

---

### Pitfall 5: NSStatusItem Memory Leaks and Lifecycle Issues

**What goes wrong:** Menu bar item disappears randomly or app consumes increasing memory over time. Declaring `statusItem` inside `didFinishLaunching` causes it to be deallocated, making menu bar icon disappear. Retain cycles prevent cleanup.

**Why it happens:**
- `NSStatusItem` must be retained for lifetime of app
- Declaring as local variable causes automatic deallocation
- Retain cycles in event handlers/closures capturing self
- Menu bar managers like Bartender 6 have known memory leak issues (continuous memory growth)

**Consequences:**
- Menu bar icon vanishes after app launch
- Memory usage grows from 50MB to 500MB+ over hours
- App becomes unresponsive, affects system performance
- Users force quit, report "app is broken"

**Prevention:**
1. Declare `statusItem` as instance variable (optional) outside `didFinishLaunching`
2. Store strong reference: `private var statusItem: NSStatusItem?`
3. Use `[weak self]` in all closures/handlers
4. Test memory usage over extended periods (24+ hours)
5. Profile with Xcode Instruments Memory Graph
6. Enable Malloc Stack Logging in scheme diagnostics
7. Implement proper cleanup in `applicationWillTerminate`

**Detection:**
- Menu bar icon disappears after launch
- Memory usage in Activity Monitor continuously increases
- Memory graph shows strong reference cycles
- Icon reappears after code change to instance variable

**Phase to address:** Foundation/Phase 1 - Menu bar app lifecycle

**Sources:**
- [Building macOS Menu Bar Apps](https://gaitatzis.medium.com/building-a-macos-menu-bar-app-with-swift-d6e293cd48eb)
- [NSStatusItem Lifecycle Issues](https://developer.apple.com/forums/thread/130073)
- [Bartender 6 Memory Leak Performance Issues](https://wpauthorbox.com/how-bartender-6-broke-macos-menu-bar-performance-and-the-uninstall-reset-that-restored-usability/)
- [Memory Leak Debugging](https://developer.apple.com/forums/thread/713062)

---

## Moderate Pitfalls

Mistakes that cause delays, performance issues, or technical debt.

### Pitfall 6: Polling Performance Without DispatchSourceFileSystemObject

**What goes wrong:** Your app polls CloudRecordings.db every 500ms using a Timer, consuming CPU unnecessarily and draining battery. File system changes trigger immediately but your polling interval adds 0-500ms latency.

**Why it happens:** Developers default to simple Timer-based polling instead of file system event monitoring. Clipboard managers use 500ms polling as a pattern, but file system has better APIs.

**Consequences:**
- Continuous CPU usage even when idle
- High "Energy Impact" in Activity Monitor (>20)
- App Nap doesn't engage, preventing power savings
- 500ms average latency detecting new transcriptions
- Battery drain complaints from laptop users

**Prevention:**
1. Use `DispatchSource.makeFileSystemObjectSource` to watch database file
2. Monitor `.write` flag for changes instead of polling
3. Combine with debouncing - wait 100ms after change before reading
4. Fall back to polling only if file monitoring fails
5. Use longer polling interval (5-10s) as backup, not primary mechanism
6. Test energy impact in Activity Monitor (target: <5 when idle)

**Detection:**
- Activity Monitor shows >5% CPU usage when idle
- Energy Impact score >20
- Battery life complaints
- `fileproviderd` high CPU usage (95-100%)

**Phase to address:** Polish/Phase 2 - Performance optimization

**Sources:**
- [macOS File System Performance Issues](https://biggo.com/news/202510081925_macOS_File_System_Performance_Issues)
- [FileProvider Performance Problems](https://discussions.apple.com/thread/254243610)
- [Energy Impact Measurement](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/MonitoringEnergyUsage.html)

---

### Pitfall 7: Transcription Timing and Polling Race Conditions

**What goes wrong:** User records 30-second voice memo, transcription takes 25 seconds to complete, but your app polls every 5 seconds and shows "no transcription available" even after it's done. Or worse - reads partially written transcription data.

**Why it happens:**
- Voice Memos transcription is asynchronous (10-30s delay)
- Database updates aren't atomic from your app's perspective
- Polling interval doesn't align with transcription completion
- No notification system for "transcription complete"

**Consequences:**
- User presses Option-C, gets empty/partial transcription
- Inconsistent behavior - sometimes works, sometimes doesn't
- User has to press Option-C multiple times
- Partial transcription text creates garbage data

**Prevention:**
1. Check both recording existence AND transcription field presence
2. Implement retry logic: if no transcription, wait 2s and check again (max 5 attempts)
3. Show UI feedback: "Transcription in progress..." if recording exists but no text
4. Query `ZDATE` and compare to current time - skip recordings <30s old
5. Use exponential backoff: 1s, 2s, 4s, 8s between checks
6. Consider UX: Option-C on recent recording = poll actively, old recording = immediate failure

**Detection:**
- Empty clipboard after Option-C despite recording existing
- Partial words or sentences in clipboard
- Works 2 minutes after recording, fails 30 seconds after
- Database shows recording but empty transcription column

**Phase to address:** Core Feature/Phase 1-2 - Transcription retrieval logic

**Sources:**
- [Voice Memos Transcription API Speed Tests](https://www.macrumors.com/2025/06/18/apple-transcription-api-faster-than-whisper/)
- [Apple SpeechAnalyzer Documentation](https://developer.apple.com/videos/play/wwdc2025/277/)
- [Voice Memos Transcription Guide](https://videotobe.com/how-to-transcribe-audio-using-voice-memos-app)

---

### Pitfall 8: Pasteboard API Race Conditions

**What goes wrong:** Your app writes transcription to pasteboard, but another clipboard manager (like Maccy) reads it at the same moment, or user pastes before write completes. Clipboard ownership changes unexpectedly.

**Why it happens:**
- Pasteboard API has documented race condition vulnerability
- `NSPasteboard` ownership can change at any time
- Other apps poll clipboard every 500ms
- No transactional guarantees

**Consequences:**
- Intermittent paste failures (paste shows old clipboard content)
- Empty paste events
- Clipboard manager conflicts
- Unreliable user experience

**Prevention:**
1. Write to pasteboard on main thread only (`@MainActor`)
2. Clear pasteboard before writing: `pasteboard.clearContents()`
3. Verify write succeeded: check `pasteboard.string(forType:)` immediately after
4. Implement retry logic (2 attempts) if verification fails
5. Use `NSPasteboard.general` - don't create custom pasteboards
6. Keep write operation atomic - don't interleave with other async work
7. Document incompatibility with clipboard managers if unavoidable

**Detection:**
- User reports "paste doesn't work sometimes"
- Empty paste after successful Option-C
- Works when clipboard manager is quit
- Race condition in logs about ownership changes

**Phase to address:** Core Feature/Phase 1 - Clipboard write implementation

**Sources:**
- [Pasteboard Race Conditions](https://jtanx.github.io/2016/08/19/a-cross-platform-clipboard-library/)
- [macOS Pasteboard API Documentation](https://developer.apple.com/documentation/appkit/nspasteboard)
- [Clipboard Polling in Maccy](https://github.com/p0deje/Maccy)
- [Pasteboard Ownership Timing](https://eclecticlight.co/2020/05/12/cut-copy-paste-inside-the-pasteboard-clipboard/)

---

### Pitfall 9: Swift Concurrency Main Thread Violations

**What goes wrong:** Your async database query updates UI (menu bar status) from background thread, causing crashes or UI glitches. Or blocking main thread with synchronous database reads causes UI freezes.

**Why it happens:**
- Database reads are I/O operations that should be async
- Easy to forget `await` means thread switching
- UI updates require main thread (`@MainActor`)
- Swift 6 strict concurrency catches these, earlier versions don't

**Consequences:**
- Random crashes: "UI API called on background thread"
- Menu bar status shows stale data
- UI freezes during database queries
- Purple warnings in Xcode (Swift 6)

**Prevention:**
1. Mark all UI-updating functions with `@MainActor`
2. Use `Task { @MainActor in }` for UI updates from async contexts
3. Perform database reads in background: `Task.detached { }`
4. Use `await MainActor.run { }` to switch to main thread for UI
5. Enable strict concurrency checking in build settings
6. Test with Thread Sanitizer enabled
7. Never call blocking SQLite operations on main thread

**Detection:**
- Purple runtime warnings in Xcode console
- Crashes with "Main Thread Checker" enabled
- UI freezes during database queries (>100ms)
- Thread Sanitizer violations

**Phase to address:** Foundation/Phase 1 - Async architecture

**Sources:**
- [MainActor Usage in Swift](https://www.avanderlee.com/swift/mainactor-dispatch-main-thread/)
- [Swift Concurrency Best Practices](https://medium.com/@egzonpllana/understanding-concurrency-in-swift-6-with-sendable-protocol-mainactor-and-async-await-5ccfdc0ca2b6)
- [WWDC 2025: Embracing Swift Concurrency](https://developer.apple.com/videos/play/wwdc2025/268/)
- [UI Updates from Async Context](https://forums.swift.org/t/how-to-correctly-update-the-ui-from-an-asynchronous-context/71155)

---

### Pitfall 10: App Sandboxing Prevents Full Disk Access

**What goes wrong:** You enable App Sandbox in Xcode for Mac App Store distribution, but sandboxed apps CANNOT access Voice Memos database even with Full Disk Access permission. TCC denies access regardless.

**Why it happens:**
- App Sandbox restricts access beyond user home directory
- Voice Memos database is in `~/Library/Containers/` (another app's container)
- Sandboxing + entitlements don't override container isolation
- This is a fundamental architectural conflict

**Consequences:**
- Complete rewrite required if you discover this late
- Cannot distribute via Mac App Store with current architecture
- Must distribute as Developer ID signed package instead
- Lost App Store visibility and auto-updates

**Prevention:**
1. **DO NOT enable App Sandbox** for this project
2. Use Developer ID signing instead of Mac App Store distribution
3. Document this limitation in architecture decisions (Phase 0)
4. If App Store required: completely different architecture needed (no direct DB access)
5. Alternative: Use Apple's official APIs when/if they exist (none currently)
6. Test distribution path early (Phase 1, not Phase 3)

**Detection:**
- Full Disk Access granted but file access still fails
- Works in development, fails in distribution build
- Error: "Operation not permitted" despite permissions
- App Sandbox enabled in Entitlements

**Phase to address:** Foundation/Phase 0 - Architecture decision

**Sources:**
- [TCC and App Sandbox Relationship](https://imlzq.com/apple/macos/2024/08/24/Unveiling-Mac-Security-A-Comprehensive-Exploration-of-TCC-Sandboxing-and-App-Data-TCC.html)
- [Sandbox Bypasses and Limitations](https://jhftss.github.io/A-New-Era-of-macOS-Sandbox-Escapes/)
- [Every Unsandboxed App Has Full Disk Access](https://lapcatsoftware.com/articles/FullDiskAccess.html)

---

## Minor Pitfalls

Mistakes that cause annoyance but are easily fixable.

### Pitfall 11: Notarization Delays in 2026

**What goes wrong:** You submit app for notarization and it stays "In Progress" for 24-72+ hours instead of the expected minutes. Blocks release cycles.

**Why it happens:** Starting January 2026, Apple's notarization service has experienced processing delays. Large binaries take 3.5-4.5 hours minimum. Unknown infrastructure issues on Apple's side.

**Consequences:**
- Can't release urgent bug fixes
- Frustrating development workflow
- Users waiting for updates

**Prevention:**
1. Plan for 48-72 hour notarization window
2. Notarize early in release cycle, not day-of
3. Keep binary size small (<50MB if possible)
4. Use `xcrun notarytool wait` to monitor status
5. Have rollback plan if notarization fails
6. Consider staging environment with pre-notarized builds

**Detection:**
- Submission stuck in "In Progress" for >4 hours
- `notarytool info` shows no progress
- Works for small test builds, hangs for production

**Phase to address:** Distribution/Phase 3

**Sources:**
- [Notarization Delays in 2026](https://developer.apple.com/forums/topics/code-signing-topic/code-signing-topic-notarization)
- [Code Signing and Notarization Best Practices](https://www.theslidefactory.com/post/code-signing-notarizing-your-macos-application-for-distribution)

---

### Pitfall 12: Launch Agent Performance Impact

**What goes wrong:** Your menu bar app adds a launch agent to start at login, but users report slow boot times. Your app contributes to the 68% of "background-only" performance complaints.

**Why it happens:**
- Launch agents start before user sees desktop
- Multiple launch agents compound delay
- Users don't remember enabling "Launch at Login"
- macOS penalizes slow-starting agents

**Consequences:**
- Users disable "Launch at Login"
- Negative reviews about "slowing down my Mac"
- Uninstalls without using app
- Contributes to general macOS slowdown perception

**Prevention:**
1. Optimize startup time to <500ms
2. Defer non-critical initialization until after launch
3. Don't enable "Launch at Login" by default - ask user
4. Provide clear UI to disable auto-launch
5. Use `SMAppService` (modern) instead of launch agents (legacy)
6. Lazy-load database connection only when needed
7. Profile startup time with Instruments

**Detection:**
- Startup time >1 second
- Activity Monitor shows high CPU during launch
- User complaints about boot performance
- Launch agent visible in Login Items settings

**Phase to address:** Polish/Phase 2

**Sources:**
- [Managing Startup Apps in macOS 26](https://allthings.how/manage-startup-apps-in-macos-26-to-improve-boot-time/)
- [Launch Agents Performance Study](https://the-sequence.com/macos-ventura-login-background-items)
- [Launch Agents vs Daemons](https://www.hostragons.com/en/blog/macos-auto-start-apps/)

---

### Pitfall 13: Menu Bar Icon Hidden in macOS 26

**What goes wrong:** macOS 26 introduced "Allow in the Menu Bar" setting that lets users hide menu bar items. Your app icon isn't visible and users think it's not running.

**Why it happens:**
- New macOS 26 system preference gives users fine control
- Default behavior varies by system
- Menu bar managers (Bartender, Ice) can also hide icons
- No notification when icon is hidden

**Consequences:**
- Support requests: "app isn't working"
- Users don't know how to trigger Option-C because can't see icon
- Confusion about app running state

**Prevention:**
1. Provide keyboard shortcut (Option-C) that works even if icon hidden
2. Include onboarding explaining icon may be hidden
3. Check for menu bar visibility in first-run experience
4. Document how to show icon in macOS 26 settings
5. Consider alternative indicator (Dock icon badge?)
6. Don't rely solely on menu bar for app presence

**Detection:**
- NSStatusItem created but not visible
- macOS 26+ systems
- Users report "can't find the app"

**Phase to address:** Polish/Phase 2 - macOS 26 compatibility

**Sources:**
- [macOS 26 Menu Bar Changes](https://talk.macpowerusers.com/t/using-macos-26-without-a-menu-bar-manager/43639)
- [Menu Bar UI Consistency Issues](https://www.macobserver.com/news/macos-26-critics/)

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation | Priority |
|-------------|---------------|------------|----------|
| Foundation: Database Access | SQLite locking, schema version differences | Implement read-only mode, WAL, retry logic, schema detection | CRITICAL |
| Foundation: Permissions | FDA permission loss bug, Accessibility for hotkeys | Graceful error handling, status UI, both FDA and Accessibility | CRITICAL |
| Foundation: Hotkey Registration | Silent failures, conflicts with existing apps | Use CGEventTap, permission checks, conflict detection, customizable hotkey | CRITICAL |
| Foundation: Menu Bar Lifecycle | NSStatusItem deallocation, memory leaks | Instance variable storage, weak self in closures, memory profiling | HIGH |
| Foundation: Async Architecture | Main thread violations, blocking I/O | @MainActor annotations, Task.detached for DB, Thread Sanitizer | HIGH |
| Core Feature: Transcription Timing | Polling race conditions, incomplete transcriptions | Retry logic with backoff, recency checks, UI feedback | HIGH |
| Core Feature: Clipboard Writing | Pasteboard race conditions | Main thread only, verify writes, atomic operations | MEDIUM |
| Performance: File Monitoring | CPU/battery drain from polling | Use DispatchSource instead of Timer polling | MEDIUM |
| Distribution: Code Signing | Sandboxing incompatibility, notarization delays | NO sandboxing, Developer ID not App Store, early notarization testing | HIGH |
| Distribution: Launch at Login | Startup performance impact | Optimize to <500ms, don't default to enabled, modern SMAppService | LOW |
| Polish: macOS 26 | Hidden menu bar icons, UI inconsistencies | Keyboard-first UX, onboarding, documentation | LOW |

---

## Testing Checklist

To catch these pitfalls early:

**Foundation Phase:**
- [ ] Test on macOS Ventura, Sonoma, and Sequoia (minimum 2 versions)
- [ ] Test with and without Full Disk Access permission
- [ ] Test with and without Accessibility permission
- [ ] Profile memory with Instruments for 1+ hour runtime
- [ ] Enable Thread Sanitizer and test all async paths
- [ ] Test with Voice Memos app open and actively recording
- [ ] Test SQLite access while Voice Memos is transcribing
- [ ] Run on both Apple Silicon and Intel Macs

**Core Feature Phase:**
- [ ] Test transcription retrieval 0s, 10s, 30s, 60s after recording
- [ ] Test with clipboard manager apps (Maccy, Paste, etc.) running
- [ ] Test hotkey conflicts with Figma, Adobe, VSCode, Xcode
- [ ] Verify clipboard contains correct text after 10 consecutive Option-C presses
- [ ] Test energy impact in Activity Monitor (target: <5 when idle)

**Distribution Phase:**
- [ ] Test Developer ID signed build (NOT App Sandbox enabled)
- [ ] Submit for notarization 48-72 hours before release
- [ ] Test on fresh macOS install (no dev tools)
- [ ] Verify startup time <500ms with Instruments
- [ ] Test menu bar icon visibility on macOS 26

---

## Critical Decision Points

**Architecture (Phase 0):**
- ✅ Developer ID signing, NOT Mac App Store (due to sandboxing)
- ✅ Read-only database access (never write to Voice Memos DB)
- ✅ Support macOS 13+ minimum (2 major versions back)

**Technology (Phase 1):**
- ✅ CGEventTap for hotkeys (NOT NSEvent global monitor)
- ✅ DispatchSource for file monitoring (NOT Timer polling)
- ✅ Swift Concurrency with @MainActor (NOT GCD)
- ✅ WAL mode for SQLite (NOT default journaling)

**UX (Phase 1-2):**
- ✅ Customizable hotkey (NOT hardcoded Option-C)
- ✅ Retry logic for transcriptions (NOT single attempt)
- ✅ Both FDA and Accessibility permissions (NOT just FDA)
- ✅ Keyboard-first UX (NOT menu-bar-only)

---

## Research Gaps

**LOW confidence areas needing validation:**

1. **Transcription completion notification:** Is there an undocumented notification or KVO pattern when Voice Memos completes transcription? Would eliminate polling need.

2. **Official Voice Memos API:** Will Apple release official APIs in macOS 27 for transcription access? Monitor WWDC 2026.

3. **CloudKit sync behavior:** How does iCloud sync affect database locking? Need testing with iCloud enabled/disabled.

4. **Memory leak patterns:** Specific patterns causing Bartender 6-style memory growth need deeper investigation with Instruments allocation tracking.

These should be investigated during relevant phases, not upfront.

---

## Confidence Assessment

| Pitfall Category | Confidence | Basis |
|------------------|-----------|-------|
| SQLite locking issues | HIGH | Official SQLite docs, verified community reports |
| TCC/FDA permission bugs | HIGH | Apple documentation, multiple confirmed reports |
| Hotkey registration failures | HIGH | Developer forums, library documentation, official docs |
| Database schema variations | MEDIUM | Research papers, but limited official documentation |
| Memory leak patterns | MEDIUM | Community reports, need more profiling |
| Pasteboard race conditions | MEDIUM | API documentation acknowledges issue |
| Transcription timing | MEDIUM | Limited official documentation on delays |
| Swift Concurrency issues | HIGH | Official Swift documentation, WWDC content |
| Sandboxing limitations | HIGH | Apple TCC documentation, confirmed incompatibility |
| Notarization delays | MEDIUM | Recent developer reports, may be temporary |
| macOS 26 changes | MEDIUM | Recent articles, subject to change |
| Launch agent performance | MEDIUM | Studies cited, general best practices |

---

**Overall Assessment:** Research is comprehensive for critical pitfalls (database, permissions, hotkeys, architecture). Moderate confidence areas can be validated during implementation phases. All critical architectural decisions have high-confidence supporting evidence.
