# Technology Stack

**Project:** Option-C (macOS Voice-to-Clipboard Automation)
**Researched:** 2026-02-01
**Confidence:** MEDIUM

## Executive Summary

The standard 2025-2026 stack for macOS menu bar apps with global hotkeys uses **Swift + SwiftUI** with specific purpose-built libraries for each component. However, **critical constraint discovered**: Direct Voice Memos control and transcription access face significant limitations. Recommend alternative architecture using native recording with Apple's new SpeechAnalyzer API.

## Recommended Stack

### Core Language & Framework
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Swift | 6.1+ | Primary language | Native macOS development, modern concurrency, type safety |
| SwiftUI | 4.0+ (macOS 13+) | UI framework | MenuBarExtra scene for menu bar apps, native integration |
| Xcode | 16.3+ | IDE | Required for Swift 6.1+ and latest APIs |

**Rationale:** Swift 6.1 is the current standard (January 2026) with improved concurrency safety. SwiftUI's MenuBarExtra (introduced macOS Ventura) is the modern approach, replacing older NSStatusBar patterns.

**Confidence:** HIGH (verified via official Apple documentation and GRDB requirements)

### Menu Bar App Framework
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| SwiftUI MenuBarExtra | macOS 13+ | Menu bar interface | Native, simple API for status bar items |
| AppKit (NSStatusBar) | Fallback only | Backward compatibility | Only if supporting macOS 12 or earlier |

**Rationale:** MenuBarExtra is the official Apple approach as of WWDC 2022. NSStatusBar remains available but is legacy approach. For a greenfield project targeting modern macOS (13+), MenuBarExtra is the clear choice.

**Confidence:** HIGH (verified via Apple Developer documentation and multiple 2025 sources)

**What NOT to use:** Don't use pure AppKit/NSStatusBar unless you need macOS 12 support. The SwiftUI approach is simpler and future-proof.

### Global Keyboard Shortcuts
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| KeyboardShortcuts | 2.4.0+ | Global hotkey management | Sandboxed, Mac App Store compatible, battle-tested |

**GitHub:** https://github.com/sindresorhus/KeyboardShortcuts

**Rationale:**
- Fully sandboxed and Mac App Store compatible
- Handles conflict detection with system shortcuts
- SwiftUI and AppKit components included
- Production-tested in apps like Dato, Plash, Lungo
- Active maintenance (latest release Sept 2025)
- Uses Carbon APIs which are stable despite age

**Confidence:** HIGH (verified via GitHub repository and official documentation)

**Alternatives Considered:**
- **HotKey** (soffes/HotKey): Good for hard-coded shortcuts, no UI components, less feature-complete
- **MASShortcut**: Objective-C, more complex, older codebase
- **Custom Carbon API**: Requires significant boilerplate, reinventing the wheel

**What NOT to use:** Don't roll your own Carbon API wrapper. KeyboardShortcuts solves all the edge cases.

### Voice Recording & Transcription
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| AVFoundation | Built-in | Audio recording | Native macOS audio capture |
| SpeechAnalyzer | iOS 26+/macOS 26+ | On-device transcription | Replaces SFSpeechRecognizer, 2.2× faster than Whisper |

**CRITICAL CONSTRAINT:** Direct Voice Memos control is **NOT feasible** via automation:
- No AppleScript dictionary support
- Limited Automator integration (opens but won't record reliably)
- Database access requires Full Disk Access permission
- Transcriptions stored in proprietary format within .m4a files

**Architecture Change Required:** Instead of controlling Voice Memos, build native recording:

1. **AVFoundation** for microphone capture (built-in, no dependencies)
2. **SpeechAnalyzer** for on-device transcription (iOS 26+/macOS 26+)
   - 2.2× faster than Whisper Large V3 Turbo
   - Powers Voice Memos, Notes, Journal internally
   - Available across all Apple platforms
   - On-device processing (privacy-preserving)

**Confidence:** HIGH for AVFoundation, MEDIUM for SpeechAnalyzer (requires macOS 26+, currently in beta)

**Fallback for Pre-macOS 26:**
- Use **SFSpeechRecognizer** (available macOS 10.15+)
- Slower but battle-tested
- Same privacy model (on-device when possible)

**What NOT to use:**
- Don't try to control Voice Memos programmatically (not reliable)
- Don't use Voice Memos database for transcriptions (fragile, permission issues)
- Don't use external transcription APIs (privacy concerns, latency, cost)

### SQLite Database Access
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| GRDB.swift | 7.9.0+ | SQLite ORM & toolkit | Modern, actively maintained, comprehensive features |

**GitHub:** https://github.com/groue/GRDB.swift

**Rationale:**
- Latest release: Dec 13, 2025 (actively maintained)
- Swift 6.1+ and Xcode 16.3+ compatible
- Database observation (reactive updates)
- Robust concurrency support (WAL mode)
- Migration system included
- High-level ORM + low-level SQL access
- Battle-tested in production apps

**Requirements:**
- Swift 6.1+
- macOS 10.15+
- SQLite 3.20.0+ (built into macOS)

**Confidence:** HIGH (verified via GitHub repository, latest release December 2025)

**Alternatives Considered:**
- **SQLite.swift**: Type-safe wrapper, simpler but less feature-complete
- **Native SQLite3 C API**: Maximum control but significant boilerplate
- **Sqlable**: Struct-based models, less mature ecosystem

**What NOT to use:**
- Don't use the raw SQLite3 C API unless you need maximum control (unlikely for this use case)
- Don't use CoreData (overkill for simple local storage, SQLite is lighter)

**Note:** If NOT using Voice Memos database, SQLite might be optional. Consider:
- **UserDefaults** for simple state (recording count, preferences)
- **File-based storage** for audio files
- SQLite only if tracking recording history/metadata

### Clipboard Integration
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| NSPasteboard | Built-in | Clipboard access | Native macOS pasteboard API |

**Implementation:**
```swift
func copyToClipboard(string: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(string, forType: .string)
}
```

**Rationale:**
- Built into AppKit, no dependencies
- Simple, three-line implementation
- Handles all clipboard types

**Privacy Note (macOS 15.4+):** NSPasteboard includes privacy controls. Set `accessBehavior` to handle permission prompts gracefully.

**Confidence:** HIGH (verified via Apple documentation and multiple sources)

**What NOT to use:** No third-party clipboard libraries needed. NSPasteboard is sufficient and standard.

### Notifications
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| UserNotifications | macOS 10.14+ | System notifications | Modern notification framework |

**Rationale:**
- Replaced older NSUserNotification (deprecated)
- Rich notifications (actions, images, sounds)
- Consistent API across Apple platforms
- Swift 6.2 adds concurrency-safe protocols

**Requirements:**
- Request authorization on first use
- Handle notification permissions in Settings

**Confidence:** HIGH (verified via Apple documentation)

**What NOT to use:** Don't use deprecated NSUserNotification. UserNotifications is the current standard.

### Dependency Management
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Swift Package Manager | Built-in | Dependency management | Native, lightweight, CocoaPods is sunsetting |

**CRITICAL:** CocoaPods is being sunset (Dec 2, 2026 becomes read-only). SPM is the official future.

**Rationale:**
- Native Xcode integration
- No pre-install steps (unlike CocoaPods/Ruby)
- Faster CI/CD pipelines
- Simpler setup (no .xcworkspace, no Podfile.lock)
- Official Apple support

**Confidence:** HIGH (verified via multiple sources about CocoaPods sunset)

**What NOT to use:**
- **CocoaPods**: Becoming read-only December 2026
- **Carthage**: Less ecosystem support than SPM

## Installation & Setup

### Package Dependencies

Add to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.4.0"),
    .package(url: "https://github.com/groue/GRDB.swift", from: "7.9.0"), // Optional
]
```

### Minimum macOS Version

**Recommended target:** macOS 13.0 (Ventura)
- MenuBarExtra requires macOS 13+
- SpeechAnalyzer requires macOS 26+ (fallback to SFSpeechRecognizer for 10.15-25)

**Conservative target:** macOS 10.15 (Catalina)
- Use AppKit NSStatusBar instead of MenuBarExtra
- Use SFSpeechRecognizer for transcription
- Broader compatibility but more code

### Required Entitlements

```xml
<!-- Info.plist -->
<key>LSUIElement</key>
<true/> <!-- Hide from Dock -->

<!-- Entitlements -->
<key>com.apple.security.device.audio-input</key>
<true/> <!-- Microphone access -->

<key>NSMicrophoneUsageDescription</key>
<string>Option-C needs microphone access to record voice memos.</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>Option-C transcribes your voice recordings to text.</string>
```

### Sandbox Considerations

**If distributing via Mac App Store:**
- All recommended libraries are sandbox-compatible
- No Full Disk Access required (not using Voice Memos database)
- Microphone permission handled via standard entitlements

## Architecture Recommendation

Based on this stack, recommended architecture:

```
┌─────────────────────────────────────────────┐
│           Menu Bar App (SwiftUI)            │
│  ┌───────────────────────────────────────┐  │
│  │  MenuBarExtra (macOS 13+)             │  │
│  │  or NSStatusBar (fallback)            │  │
│  └───────────────────────────────────────┘  │
│                     │                        │
│         ┌───────────┴───────────┐            │
│         ▼                       ▼            │
│  ┌──────────────┐     ┌──────────────────┐  │
│  │ Hotkey       │     │ Recording State  │  │
│  │ Manager      │     │ Manager          │  │
│  │              │     │                  │  │
│  │ Keyboard     │     │ AVFoundation     │  │
│  │ Shortcuts    │     │ Audio Capture    │  │
│  └──────────────┘     └──────────────────┘  │
│                              │               │
│                              ▼               │
│                     ┌──────────────────┐     │
│                     │ Transcription    │     │
│                     │ Engine           │     │
│                     │                  │     │
│                     │ SpeechAnalyzer   │     │
│                     │ (macOS 26+)      │     │
│                     └──────────────────┘     │
│                              │               │
│                              ▼               │
│                     ┌──────────────────┐     │
│                     │ Clipboard        │     │
│                     │ Manager          │     │
│                     │                  │     │
│                     │ NSPasteboard     │     │
│                     └──────────────────┘     │
│                                              │
│  ┌────────────────────────────────────────┐ │
│  │ Notifications (UserNotifications)      │ │
│  └────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

## Confidence Assessment

| Component | Confidence | Source |
|-----------|------------|--------|
| Swift/SwiftUI | HIGH | Apple official, GRDB requirements |
| MenuBarExtra | HIGH | Apple WWDC 2022, multiple tutorials |
| KeyboardShortcuts | HIGH | GitHub repo, active maintenance |
| AVFoundation | HIGH | Built-in framework, well-documented |
| SpeechAnalyzer | MEDIUM | New API (WWDC 2025), requires macOS 26+ |
| GRDB.swift | HIGH | GitHub repo, Dec 2025 release |
| NSPasteboard | HIGH | Apple documentation |
| UserNotifications | HIGH | Apple documentation |
| SPM over CocoaPods | HIGH | CocoaPods sunset announcement |
| Voice Memos NOT feasible | HIGH | Multiple sources confirm limitations |

## Critical Decision: Voice Memos vs Native Recording

**Finding:** Direct Voice Memos control is NOT reliable for automation:
- No official AppleScript support
- Automator workflows unreliable (opens but won't record)
- Database access requires Full Disk Access (poor UX, security risk)
- Transcription format is proprietary

**Recommendation:** Build native recording using AVFoundation + SpeechAnalyzer
- **Pros:** Full control, better UX, no permission issues, faster transcription
- **Cons:** Need to implement recording UI (minimal work with SwiftUI)

**Confidence:** HIGH (multiple sources confirm Voice Memos limitations)

## Version Update Strategy

**Keep current with:**
- Swift language updates (6.x series)
- Xcode releases (16.x series)
- KeyboardShortcuts minor versions (2.x)
- GRDB.swift minor versions (7.x)

**Monitor for:**
- macOS 26 release (enables SpeechAnalyzer)
- CocoaPods sunset (December 2, 2026)
- MenuBarExtra API improvements

## Sources

**High Confidence (Official/Verified):**
- [GRDB.swift GitHub](https://github.com/groue/GRDB.swift) - Latest: v7.9.0, Dec 13, 2025
- [KeyboardShortcuts GitHub](https://github.com/sindresorhus/KeyboardShortcuts) - Latest: v2.4.0
- [Apple SpeechAnalyzer Documentation](https://developer.apple.com/documentation/speech/speechanalyzer)
- [WWDC 2025 - SpeechAnalyzer](https://developer.apple.com/videos/play/wwdc2025/277/)
- [Apple MenuBarExtra Documentation](https://developer.apple.com/documentation/SwiftUI/Building-and-customizing-the-menu-bar-with-SwiftUI)
- [CocoaPods Sunset Announcement](https://capgo.app/blog/ios-spm-vs-cocoapods-capacitor-migration-guide/)

**Medium Confidence (Community/Recent):**
- [SwiftUI Menu Bar App Tutorials](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/)
- [Voice Memos Automation Limitations](https://fordprior.com/2025/06/02/automating-voice-memo-transcription/)
- [Voice Memos Database Location](https://nono.ma/location-of-apple-voice-memos)
- [macOS Pasteboard Privacy](https://mjtsai.com/blog/2025/05/12/pasteboard-privacy-preview-in-macos-15-4/)

**WebSearch Findings (Multiple Sources):**
- Swift Package Manager replacing CocoaPods (2025-2026)
- SpeechAnalyzer performance benchmarks (2.2× faster than Whisper)
- MenuBarExtra as standard for menu bar apps (macOS 13+)
