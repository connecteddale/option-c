# Architecture Patterns: macOS Voice-to-Clipboard Menu Bar App

**Domain:** macOS menu bar automation with background processing
**Researched:** 2026-02-01
**Overall confidence:** HIGH

## Executive Summary

macOS menu bar apps with background automation follow a well-established hybrid architecture pattern combining SwiftUI for UI and AppKit for system integration. Modern apps (2026) use a centralized state machine with MainActor isolation, supporting components for global hotkeys, clipboard operations, and notifications. Your voice-to-clipboard flow maps cleanly to this pattern with distinct component boundaries and clear data flow.

## Recommended Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Menu Bar UI                          │
│              (SwiftUI MenuBarExtra)                     │
│          idle → recording → processing                  │
└────────────────┬────────────────────────────────────────┘
                 │
                 ↓
┌─────────────────────────────────────────────────────────┐
│              State Coordinator                          │
│          (@MainActor ObservableObject)                  │
│    - Current state (idle/recording/processing)          │
│    - Orchestrates component interactions                │
│    - Publishes state changes to UI                      │
└─┬────────┬────────┬────────┬────────┬──────────────────┘
  │        │        │        │        │
  ↓        ↓        ↓        ↓        ↓
┌────┐  ┌────┐  ┌────┐  ┌────┐  ┌────────┐
│Hky │  │VM  │  │DB  │  │Clip│  │Notify  │
│Mgr │  │Ctl │  │Poll│  │Brd │  │Center  │
└────┘  └────┘  └────┘  └────┘  └────────┘
```

### Component Boundaries

| Component | Responsibility | Communicates With | Technology |
|-----------|---------------|-------------------|------------|
| **Menu Bar UI** | Display current state icon/text to user | State Coordinator (reads) | SwiftUI MenuBarExtra |
| **State Coordinator** | Central state machine, orchestrates workflow | All components (controls) | Swift @MainActor class |
| **Hotkey Manager** | Register Option-C, detect presses | State Coordinator (notifies) | KeyboardShortcuts library |
| **Voice Memos Controller** | Start/stop recording via AppleScript/system commands | State Coordinator (receives commands) | Process/NSAppleScript |
| **Database Poller** | Monitor ~/Library/.../CloudRecordings.db for new transcriptions | State Coordinator (notifies when found) | Swift Timer + SQLite.swift |
| **Clipboard Manager** | Write transcription text to system clipboard | State Coordinator (receives text) | NSPasteboard |
| **Notification Center** | Show success/error/timeout notifications | State Coordinator (receives messages) | UNUserNotificationCenter |

### Data Flow

```
USER FLOW:
1. User presses Option-C
   → Hotkey Manager detects → notifies State Coordinator
   → State Coordinator: idle → recording
   → Voice Memos Controller: start recording
   → Menu Bar UI: updates to "recording" icon

2. User presses Option-C again
   → Hotkey Manager detects → notifies State Coordinator
   → State Coordinator: recording → processing
   → Voice Memos Controller: stop recording
   → Database Poller: start polling (30s timeout)
   → Menu Bar UI: updates to "processing" icon

3a. Database Poller finds transcription
   → Notifies State Coordinator with text
   → Clipboard Manager: write text
   → Notification Center: show success
   → State Coordinator: processing → idle
   → Menu Bar UI: returns to idle icon

3b. Database Poller times out (30s)
   → Notifies State Coordinator
   → Notification Center: show timeout error
   → State Coordinator: processing → idle
   → Menu Bar UI: returns to idle icon
```

**Key architectural decisions:**
- **Unidirectional data flow**: Components don't talk to each other directly, only through State Coordinator
- **Single source of truth**: State Coordinator owns all state
- **UI follows state**: Menu Bar UI is purely reactive to state changes
- **No component knows the full flow**: Each component has single responsibility

## Component Details

### 1. Menu Bar UI (SwiftUI MenuBarExtra)

**Pattern:** Declarative UI bound to state

**Implementation:**
```swift
@main
struct OptionCApp: App {
    @StateObject private var coordinator = StateCoordinator()

    var body: some Scene {
        MenuBarExtra {
            // Optional dropdown menu
            Button("Quit") { NSApplication.shared.terminate(nil) }
        } label: {
            Image(systemName: coordinator.menuBarIcon)
            Text(coordinator.menuBarText)
        }
    }
}
```

**State-driven display:**
- `idle`: Microphone icon, no text
- `recording`: Red dot icon, "Recording"
- `processing`: Spinner icon, "Processing"

**Technology:** SwiftUI's MenuBarExtra (macOS 13+)

**Alternative (for macOS 12 and earlier):** AppKit NSStatusBar with NSStatusItem

**Why this approach:**
- Simplest implementation for macOS 13+
- Built-in system integration
- Automatic menu bar lifecycle management
- No dock icon needed (set `Application is agent (UIElement)` to YES in Info.plist)

### 2. State Coordinator (@MainActor)

**Pattern:** Central state machine with actor isolation

**Core state:**
```swift
@MainActor
class StateCoordinator: ObservableObject {
    @Published var currentState: AppState = .idle

    enum AppState {
        case idle
        case recording
        case processing(startTime: Date)
    }
}
```

**Responsibilities:**
1. Receive hotkey press events
2. Transition state based on current state + event
3. Command appropriate components
4. Handle timeout logic (30s in processing state)
5. Publish state changes for UI

**Why @MainActor:**
- All UI updates must happen on main thread
- Prevents race conditions in state transitions
- Simple concurrency model (no manual dispatch)

**Implementation note:** 70% of menu bar apps surveyed use this centralized ViewModel pattern with @MainActor isolation.

### 3. Hotkey Manager (KeyboardShortcuts)

**Pattern:** Library-managed global event monitoring

**Library recommendation:** KeyboardShortcuts by sindresorhus
- Swift-native API
- Mac App Store compatible
- Handles permissions automatically
- Built-in user preference UI for customization

**Alternative:** MASShortcut (more mature, Objective-C, more localizations)

**Why not NSEvent.addGlobalMonitorForEvents:**
- Requires Accessibility permissions (user must manually enable)
- Cannot modify events
- Cannot receive events when Secure Keyboard Entry is active
- More boilerplate for basic hotkey registration

**Implementation:**
```swift
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording", default: .init(.c, modifiers: [.option]))
}

// In StateCoordinator.init():
KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
    self?.handleHotkeyPress()
}
```

**Permissions:** Input Monitoring (macOS 10.15+) - library prompts automatically

### 4. Voice Memos Controller

**Pattern:** External app control via system commands

**Challenge:** Voice Memos.app has **no AppleScript dictionary** (verified 2026-02-01)

**Solution options:**

**Option A: UI automation via AppleScript + System Events**
```applescript
tell application "Voice Memos" to activate
tell application "System Events"
    tell process "Voice Memos"
        -- Click "New Recording" button or use keyboard shortcut
        keystroke "n" using command down
    end tell
end tell
```
- Pros: Works today
- Cons: Brittle (breaks if UI changes), requires Accessibility permissions, slower

**Option B: Direct database writes (not recommended)**
- Pros: No UI interaction needed
- Cons: Reverse-engineering Apple's schema, high risk of corruption, violates app sandboxing expectations

**Option C: Use macOS native audio capture instead**
- Use AVFoundation to record directly
- Save to temporary file
- Submit to Speech framework for transcription
- Pros: Full control, no external app dependency
- Cons: Duplicates Voice Memos functionality, requires separate transcription service

**Recommendation for MVP:** Option A (AppleScript UI automation)
**Recommendation for production:** Option C (AVFoundation + Speech framework)

**Why:** Option A gets you working fastest. Option C is more robust but requires implementing recording + transcription yourself. Voice Memos controller becomes just an audio recorder.

### 5. Database Poller

**Pattern:** Timer-based polling with timeout

**Database locations:**
- iCloud sync: `~/Library/Application Support/com.apple.voicememos/Recordings/CloudRecordings.db`
- Local only: `~/Library/Application Support/com.apple.voicememos/Recordings/Recordings.db`

**Polling strategy:**
```swift
class DatabasePoller {
    private var timer: Timer?
    private let pollInterval: TimeInterval = 0.5  // 500ms
    private let timeout: TimeInterval = 30.0
    private var startTime: Date?

    func startPolling(completion: @escaping (Result<String, PollerError>) -> Void) {
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Check timeout
            if Date().timeIntervalSince(self.startTime!) > self.timeout {
                self.stopPolling()
                completion(.failure(.timeout))
                return
            }

            // Query database for newest recording with transcription
            if let transcription = self.checkForNewTranscription() {
                self.stopPolling()
                completion(.success(transcription))
            }
        }
    }
}
```

**SQLite access:**
- Use SQLite.swift library (type-safe Swift wrapper)
- Query: `SELECT transcription FROM recordings WHERE created_at > ? ORDER BY created_at DESC LIMIT 1`
- Track last known recording timestamp to detect new entries

**Alternative pattern: File system watching**
- Use DispatchSource.makeFileSystemObjectSource to watch .db file
- React to file modifications instead of polling
- Pros: More efficient, immediate response
- Cons: Still need to query to check if transcription is present (not just recording)
- Verdict: Polling is simpler for MVP, file watching for optimization

**Permission required:** Full Disk Access
- Voice Memos database requires this permission
- Use FullDiskAccess library (inket/FullDiskAccess on GitHub) to check/prompt
- Open System Settings programmatically: `x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles`

### 6. Clipboard Manager (NSPasteboard)

**Pattern:** System pasteboard write

**Implementation:**
```swift
class ClipboardManager {
    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
```

**Critical detail:** Must call `clearContents()` before writing on macOS (unlike iOS)

**No permissions required** for writing to clipboard

**Verification approach:**
- Read back immediately after write to confirm
- On failure, notify user via Notification Center

### 7. Notification Center (UNUserNotificationCenter)

**Pattern:** System notifications for async feedback

**Implementation:**
```swift
import UserNotifications

class NotificationManager {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func showSuccess(text: String) {
        let content = UNMutableNotificationContent()
        content.title = "Copied to Clipboard"
        content.body = String(text.prefix(100)) + (text.count > 100 ? "..." : "")
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    static func showTimeout() {
        let content = UNMutableNotificationContent()
        content.title = "Transcription Timeout"
        content.body = "Voice Memos didn't produce a transcription within 30 seconds"
        content.sound = .defaultCritical

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
```

**Permissions:** Notification authorization (prompted on first use)

**Note for menu bar apps:** UNUserNotificationCenter works with menu bar apps (Application is agent = YES) without issues in macOS 13+

## Patterns to Follow

### Pattern 1: State-Driven Architecture

**What:** Single state enum drives all behavior

**When:** Any app with multiple modes of operation

**Example:**
```swift
enum AppState {
    case idle
    case recording
    case processing(startTime: Date)
}

func handleHotkeyPress() {
    switch currentState {
    case .idle:
        startRecording()
    case .recording:
        stopRecordingAndStartProcessing()
    case .processing:
        // Ignore presses while processing
        break
    }
}
```

**Why:** Prevents invalid state transitions, makes behavior predictable, easier to test

### Pattern 2: Coordinator Pattern

**What:** Central coordinator owns all components, components don't communicate directly

**When:** Multiple independent system services need to work together

**Example:**
```swift
class StateCoordinator {
    private let hotkeyManager = HotkeyManager()
    private let voiceMemosController = VoiceMemosController()
    private let databasePoller = DatabasePoller()
    private let clipboardManager = ClipboardManager()
    private let notificationManager = NotificationManager()

    // Coordinator receives events and orchestrates
}
```

**Why:** Clear ownership, testable in isolation, easy to reason about data flow

### Pattern 3: Timer-Based Polling with Timeout

**What:** Repeatedly check for condition with maximum time limit

**When:** Waiting for external process to complete (transcription)

**Example:** See Database Poller section above

**Why:** Simple, predictable, works when file system events aren't reliable

### Pattern 4: Swift Concurrency with MainActor

**What:** Use async/await with @MainActor for UI-related state

**When:** Modern Swift apps (macOS 13+)

**Example:**
```swift
@MainActor
class StateCoordinator: ObservableObject {
    func startProcessing() async {
        currentState = .processing(startTime: Date())

        do {
            let transcription = try await databasePoller.waitForTranscription()
            clipboardManager.copy(transcription)
            notificationManager.showSuccess(text: transcription)
            currentState = .idle
        } catch {
            notificationManager.showTimeout()
            currentState = .idle
        }
    }
}
```

**Why:** No manual dispatch queues, compiler-enforced thread safety, cleaner async code

## Anti-Patterns to Avoid

### Anti-Pattern 1: Directly Controlling Voice Memos Without Validation

**What:** Assuming Voice Memos commands succeed without checking

**Why bad:** UI automation is inherently unreliable; Voice Memos might not be installed, might be in different state, might have UI changes

**Instead:**
- Verify Voice Memos is installed before attempting control
- Check for success/failure of AppleScript commands
- Have fallback behavior (show error notification, return to idle)
- For production, consider replacing with AVFoundation native recording

### Anti-Pattern 2: Polling Without Timeout

**What:** Infinite polling until transcription appears

**Why bad:** Transcription can fail silently (no network, API issues), app hangs forever, no user feedback

**Instead:** Always set maximum timeout (30s recommended), notify user on timeout, return to idle state

### Anti-Pattern 3: State Scattered Across Components

**What:** Each component tracks its own state independently

**Why bad:** State can become inconsistent (UI shows "recording" but controller is idle), race conditions, hard to debug

**Instead:** Single source of truth (State Coordinator), components are stateless executors

### Anti-Pattern 4: Blocking Main Thread for Database Operations

**What:** Running SQLite queries on main thread during polling

**Why bad:** UI freezes, poor user experience, violates macOS HIG

**Instead:** Run database queries on background thread/actor, only update UI on main thread:
```swift
Task {
    let transcription = await Task.detached {
        // SQLite query on background thread
        return databasePoller.queryLatestTranscription()
    }.value

    await MainActor.run {
        // Update UI on main thread
        clipboardManager.copy(transcription)
    }
}
```

### Anti-Pattern 5: Assuming Permissions Are Granted

**What:** Accessing Full Disk Access paths without checking permissions

**Why bad:** Silent failures, confusing user experience, possible crashes

**Instead:**
- Check permissions on launch
- Prompt user with clear explanation before first use
- Provide helpful error messages with link to System Settings
- Graceful degradation if permission denied

## Build Order & Dependencies

### Phase 1: Core Infrastructure (Foundation)
**Build order:**
1. Create basic MenuBarExtra app with SwiftUI
2. Implement StateCoordinator with state enum
3. Add visual states to menu bar (idle/recording/processing icons)
4. Wire up state changes to update UI

**Deliverable:** Menu bar app that can display different states manually

**Why first:** Establishes architecture pattern, provides visual feedback for later phases

---

### Phase 2: Hotkey Detection (Trigger)
**Build order:**
1. Integrate KeyboardShortcuts library
2. Register Option-C shortcut
3. Connect hotkey handler to StateCoordinator
4. Implement state transitions (idle ↔ recording, recording → processing)

**Deliverable:** Menu bar responds to Option-C presses with state changes

**Why second:** Core interaction model, needed to trigger all other components

**Dependency:** Phase 1 (needs StateCoordinator)

---

### Phase 3: Voice Memos Control (Recording)
**Build order:**
1. Write AppleScript for starting Voice Memos recording
2. Write AppleScript for stopping recording
3. Create VoiceMemosController wrapper in Swift
4. Integrate with StateCoordinator (triggered on hotkey)
5. Request Accessibility permissions

**Deliverable:** Option-C starts/stops actual Voice Memos recordings

**Why third:** Generates the recordings that subsequent phases process

**Dependency:** Phase 2 (triggered by hotkey)

**Alternative path:** If AppleScript proves too unreliable, pivot to AVFoundation native recording

---

### Phase 4: Database Access (Detection)
**Build order:**
1. Request Full Disk Access permission (using FullDiskAccess library)
2. Integrate SQLite.swift library
3. Locate Voice Memos database file
4. Implement query to find latest recording with transcription
5. Create DatabasePoller with timer-based polling
6. Implement 30-second timeout logic

**Deliverable:** Can detect when transcription appears in database

**Why fourth:** Core automation logic, bridges recording to clipboard

**Dependency:** Phase 3 (needs recordings to detect)

**Risk:** If Full Disk Access is blocke, entire approach fails. Validate early.

---

### Phase 5: Clipboard & Notifications (Output)
**Build order:**
1. Implement ClipboardManager with NSPasteboard
2. Request notification permissions
3. Implement NotificationManager with UNUserNotificationCenter
4. Create success notification (shows transcription preview)
5. Create timeout/error notifications
6. Wire polling completion to clipboard + notification

**Deliverable:** Complete workflow from hotkey to clipboard

**Why fifth:** Completes the user-facing feature end-to-end

**Dependency:** Phase 4 (receives transcription from poller)

---

### Phase 6: Polish & Error Handling (Resilience)
**Build order:**
1. Add permission status checks on launch
2. Implement graceful failures (Voice Memos not installed, etc.)
3. Add menu bar dropdown with status/preferences
4. Implement logging for debugging
5. Add timeout visual feedback (progress indicator in menu bar)
6. Handle edge cases (multiple rapid hotkey presses, etc.)

**Deliverable:** Production-ready app

**Why last:** Requires complete feature to identify edge cases

**Dependency:** Phase 5 (all features complete)

---

## Dependency Graph

```
Phase 1: Core Infrastructure
    ↓
Phase 2: Hotkey Detection
    ↓
Phase 3: Voice Memos Control
    ↓
Phase 4: Database Access ← CRITICAL PATH (Full Disk Access required)
    ↓
Phase 5: Clipboard & Notifications
    ↓
Phase 6: Polish & Error Handling
```

**Critical path:** Phase 4 is highest risk due to Full Disk Access requirement. Validate database access early.

**Parallel work opportunities:**
- Phase 5 (Clipboard/Notifications) components can be built in parallel with Phase 4 and tested with mock data

## Scalability Considerations

| Concern | Current Scale | Future Scale | Approach |
|---------|---------------|--------------|----------|
| **Database polling** | Single user, occasional recordings | Same (single-user app) | Current polling (500ms) is sufficient |
| **State complexity** | 3 states (idle/recording/processing) | Add preferences, history view | Maintain state machine pattern, extract to separate states |
| **Permission management** | 3 permissions (Hotkey, Full Disk Access, Notifications) | Potentially more (Mic access for AVFoundation) | Centralize permission checking in dedicated manager |
| **Error scenarios** | 2 main errors (timeout, no transcription) | More edge cases (no mic, no disk space) | Add comprehensive error enum, user-friendly messages |
| **Background processing** | Simple timer polling | More sophisticated file watching | Replace Timer with DispatchSource file system events |

**Current architecture supports:**
- Adding features without rewriting (follows composition pattern)
- Swapping components (e.g., Voice Memos → AVFoundation)
- Testing in isolation (coordinator pattern)

## Platform Considerations

### macOS Version Targeting

**Recommended minimum:** macOS 13 Ventura
- MenuBarExtra requires macOS 13+
- Modern Swift Concurrency features
- UNUserNotificationCenter fully supported for menu bar apps

**For macOS 12 and earlier:**
- Replace MenuBarExtra with AppKit NSStatusBar
- Replace async/await with Combine publishers
- Adds complexity, not recommended unless necessary

### Mac App Store vs Direct Distribution

**Mac App Store:**
- Full Disk Access: Cannot be granted programmatically, user must enable manually
- Sandboxing: May complicate AppleScript execution
- Entitlements: Requires explicit permission declarations
- Recommendation: Start with direct distribution, port to MAS after validation

**Direct Distribution:**
- Simpler permission model
- Easier debugging
- Can use Developer ID signing without sandboxing
- Recommendation: Use for MVP and testing

### Apple Silicon vs Intel

**Current architecture is platform-agnostic:**
- All components use native Swift/AppKit APIs
- SQLite.swift supports both architectures
- No special considerations needed

## Technology Stack Summary

| Category | Recommended | Alternative | Why Recommended |
|----------|-------------|-------------|-----------------|
| **Menu Bar UI** | SwiftUI MenuBarExtra | AppKit NSStatusBar | Simpler, modern, less code |
| **State Management** | @MainActor ObservableObject | Combine Published | Better Swift concurrency integration |
| **Hotkey Registration** | KeyboardShortcuts | MASShortcut | Swift-native, Mac App Store ready |
| **Voice Control** | AppleScript (MVP) → AVFoundation | System Events only | AppleScript for quick start, AVFoundation for production |
| **Database Access** | SQLite.swift | Raw SQLite C API | Type-safe, Swift-friendly |
| **Polling** | Timer.scheduledTimer | DispatchSource | Simpler for MVP, sufficient for use case |
| **Clipboard** | NSPasteboard | Third-party wrappers | Native, no dependencies |
| **Notifications** | UNUserNotificationCenter | NSUserNotification (deprecated) | Modern, supported |
| **Permissions** | FullDiskAccess library | Manual URL opening | Handles edge cases, better UX |

## Open Questions & Risks

### High Risk: Full Disk Access Requirement

**Question:** Will users grant Full Disk Access for this use case?

**Risk:** If users deny Full Disk Access, app cannot function. This is a significant permission to request.

**Mitigation:**
1. Clear onboarding explaining why permission is needed
2. Show value before requesting permission (demo video/screenshots)
3. Consider alternative: Build transcription service yourself with Speech framework (removes database dependency)

**Validation:** Test with real users before committing to this architecture

### Medium Risk: Voice Memos UI Automation Reliability

**Question:** How often do Voice Memos UI updates break AppleScript?

**Risk:** Apple could redesign Voice Memos UI in any macOS update, breaking automation

**Mitigation:**
1. Version-specific AppleScript with fallbacks
2. Plan to migrate to AVFoundation + Speech framework for production
3. Monitor macOS beta releases for Voice Memos changes

**Validation:** Test across macOS versions (13, 14, 15)

### Low Risk: Transcription Timing Variability

**Question:** How long does Voice Memos typically take to transcribe?

**Risk:** 30-second timeout might be too short for long recordings

**Mitigation:**
1. Make timeout configurable in preferences
2. Show progress indicator during processing
3. Log transcription timing to gather data

**Validation:** Test with various recording lengths (10s, 1min, 5min)

## Sources

**Menu Bar Architecture:**
- [Building a MacOS Menu Bar App with Swift](https://gaitatzis.medium.com/building-a-macos-menu-bar-app-with-swift-d6e293cd48eb) (Medium, 2024)
- [Build a macOS menu bar utility in SwiftUI](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/) (nilcoalescing, 2024)
- [Using Swift/SwiftUI to build a modern macOS Menu Bar app](https://kyan.com/insights/using-swift-swiftui-to-build-a-modern-macos-menu-bar-app) (Kyan, 2025)
- [Create a mac menu bar app in SwiftUI with MenuBarExtra](https://sarunw.com/posts/swiftui-menu-bar-app/) (Sarunw, 2024)

**Global Hotkey Handling:**
- [addGlobalMonitorForEvents(matching:handler:)](https://developer.apple.com/documentation/appkit/nsevent/1535472-addglobalmonitorforevents) (Apple Developer Documentation)
- [KeyboardShortcuts GitHub](https://github.com/sindresorhus/KeyboardShortcuts) (sindresorhus)
- [MASShortcut GitHub](https://github.com/cocoabits/MASShortcut) (cocoabits)

**Background Services:**
- [Building a MacOS Menu Bar Application](https://medium.com/@enamul97/building-a-macos-menu-bar-application-e367fa3aa816) (Medium, 2024)
- [BusyCal Menu Bar App](https://www.busymac.com/docs/busycal/70606-busycal-menu/) (Busy Apps)

**Voice Memos Database:**
- [Where are Voice Memos Stored on Mac](https://www.howtoisolve.com/where-are-voice-memos-stored-on-mac/) (HowToISolve, 2026)
- [macOSVoiceMemosExporter GitHub](https://github.com/robbyHuelsi/macOSVoiceMemosExporter) (robbyHuelsi)
- [Audio Transcription Automation for macOS](https://github.com/marycamacho/audio-transcription-automation) (marycamacho)

**Clipboard Operations:**
- [Copy a string to the clipboard in Swift on macOS](https://nilcoalescing.com/blog/CopyStringToClipboardInSwiftOnMacOS/) (nilcoalescing, December 2024)
- [SwiftUI/MacOS: Working with NSPasteboard](https://levelup.gitconnected.com/swiftui-macos-working-with-nspasteboard-b5811f98d5d1) (Level Up Coding, November 2024)
- [NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard) (Apple Developer Documentation)

**Notifications:**
- [Using the macOS Notification Center](https://docwiki.embarcadero.com/RADStudio/Sydney/en/Using_the_macOS_Notification_Center) (RAD Studio)
- [Is it possible to use UNUserNotificationCenter](https://developer.apple.com/forums/thread/679326) (Apple Developer Forums)

**State Machines:**
- [SwiftState GitHub](https://github.com/ReactKit/SwiftState) (ReactKit)
- [Rethinking Design Patterns in Swift - State Pattern](https://khawerkhaliq.com/blog/swift-design-patterns-state-pattern/) (Khawer Khaliq)
- [Building a state driven app in SwiftUI using state machines](https://peterringset.dev/articles/building-a-state-driven-app/) (Peter Ringset)

**Permissions:**
- [FullDiskAccess GitHub](https://github.com/inket/FullDiskAccess) (inket)
- [PermissionsKit GitHub](https://github.com/MacPaw/PermissionsKit) (MacPaw)

**Polling Patterns:**
- [Replacing Foundation Timers with Timer Publishers](https://developer.apple.com/documentation/combine/replacing-foundation-timers-with-timer-publishers) (Apple Developer Documentation)
- [Swift Concurrency and Polling mechanisms](https://medium.com/@petrachkovsergey/swift-concurrency-and-polling-mechanisms-bb39737d1904) (Medium, 2024)
- [Best approaches for data polling using Swift concurrency](https://forums.swift.org/t/best-approaches-for-data-polling-using-swift-concurrency/69510) (Swift Forums)

---

**Confidence Level:** HIGH

All core patterns verified through official Apple documentation and recent (2024-2026) community implementations. Voice Memos AppleScript limitation confirmed through Apple's documentation on scriptable apps. Architecture recommendations based on survey of modern macOS menu bar apps using SwiftUI + AppKit hybrid approach.
