import SwiftUI
import KeyboardShortcuts
import Carbon.HIToolbox
import Cocoa

/// Centralized state coordinator for the Option-C app
@MainActor
class AppState: ObservableObject {
    /// Current recording state
    @Published var currentState: RecordingState = .idle

    /// User preference for recording mode (persisted)
    @AppStorage("recordingMode") var recordingMode: RecordingMode = .pushToTalk

    /// Whether to automatically paste after copying to clipboard
    @AppStorage("autoPasteEnabled") var autoPasteEnabled: Bool = false

    /// Selected Whisper model for transcription
    @AppStorage("selectedWhisperModel") var selectedWhisperModel: String = "openai_whisper-base"

    /// Whether Whisper model is loaded and ready
    @Published var whisperModelLoaded: Bool = false

    /// Whether Whisper model is currently loading
    @Published var whisperModelLoading: Bool = false

    /// Controller that orchestrates audio capture and transcription
    private let recordingController = RecordingController()

    /// Permission manager for checking and requesting system permissions
    private let permissionManager = PermissionManager()

    /// Current model loading task (cancellable)
    private var modelLoadTask: Task<Void, Never>?

    init() {
        // Register both key down and key up handlers for dual-mode support
        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            self?.handleKeyDown()
        }
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            self?.handleKeyUp()
        }

        // Load Whisper model on startup
        modelLoadTask = Task {
            await loadWhisperModel()
        }
    }

    /// Load the selected Whisper model
    func loadWhisperModel() async {
        whisperModelLoading = true
        whisperModelLoaded = false
        do {
            try await WhisperTranscriptionEngine.shared.loadModel(selectedWhisperModel)
            guard !Task.isCancelled else {
                whisperModelLoading = false
                return
            }
            whisperModelLoaded = true
        } catch {
            guard !Task.isCancelled else {
                whisperModelLoading = false
                return
            }
            print("Failed to load Whisper model: \(error)")
            whisperModelLoaded = false
        }
        whisperModelLoading = false
    }

    /// Change Whisper model — cancels any in-progress download
    func changeWhisperModel(to modelName: String) {
        // Cancel current download/load
        modelLoadTask?.cancel()

        selectedWhisperModel = modelName
        whisperModelLoaded = false
        modelLoadTask = Task {
            await loadWhisperModel()
        }
    }

    /// Track if we need to stop recording when key is released (for push-to-talk)
    private var pendingStopOnKeyUp = false

    /// Whether the app can accept a new recording right now
    private var canStartRecording: Bool {
        guard whisperModelLoaded, !whisperModelLoading else { return false }
        switch currentState {
        case .idle, .success, .error:
            return true
        case .recording, .processing:
            return false
        }
    }

    /// Handle key down event for push-to-talk mode
    func handleKeyDown() {
        guard canStartRecording else { return }

        if recordingMode == .pushToTalk {
            // Push-to-talk: start on key down
            currentState = .idle // Reset from success/error immediately
            pendingStopOnKeyUp = true
            Task { await startRecording() }
        }
        // Toggle mode: do nothing on key down
    }

    /// Handle key up event for toggle mode and push-to-talk release
    func handleKeyUp() {
        switch recordingMode {
        case .toggle:
            // Toggle: flip state on key up
            if canStartRecording {
                currentState = .idle // Reset from success/error immediately
                Task { await startRecording() }
            } else if currentState == .recording {
                Task { await stopRecording() }
            }
            // Ignore during .processing
        case .pushToTalk:
            // Push-to-talk: stop on key up
            if pendingStopOnKeyUp {
                pendingStopOnKeyUp = false
                if currentState == .recording {
                    Task { await stopRecording() }
                } else {
                    // Recording hasn't started yet, mark that we should stop when it does
                    shouldStopAfterStart = true
                }
            }
        }
    }

    /// Flag to stop recording immediately after it starts (key released before recording began)
    private var shouldStopAfterStart = false

    /// Start recording after checking permissions
    private func startRecording() async {
        // Check if Whisper model is loaded
        guard whisperModelLoaded else {
            pendingStopOnKeyUp = false
            shouldStopAfterStart = false
            transitionToError(.recordingFailed(underlying: TranscriptionError.modelNotLoaded))
            return
        }

        // Check microphone permission
        let micResult = await permissionManager.requestMicrophonePermission()
        guard case .success = micResult else {
            pendingStopOnKeyUp = false
            shouldStopAfterStart = false
            if case .failure(let error) = micResult {
                transitionToError(error)
            }
            return
        }

        // Permissions granted, proceed with recording
        do {
            try recordingController.startRecording()
            currentState = .recording

            // Check if key was released while we were starting
            if shouldStopAfterStart {
                shouldStopAfterStart = false
                Task { await stopRecording() }
            }
        } catch {
            pendingStopOnKeyUp = false
            shouldStopAfterStart = false
            transitionToError(.recordingFailed(underlying: error))
        }
    }

    /// Stop recording and process transcription
    private func stopRecording() async {
        currentState = .processing
        NSLog("[OptionC] Processing started")

        do {
            let transcription = try await withTimeout(seconds: 30) {
                NSLog("[OptionC] Calling recordingController.stopRecording")
                let result = await self.recordingController.stopRecording()
                NSLog("[OptionC] Transcription returned: \(result != nil ? "\(result!.prefix(50))..." : "nil")")
                return result
            }

            // Check if we got valid transcription
            guard let rawText = transcription, !rawText.isEmpty else {
                NSLog("[OptionC] No speech detected")
                transitionToError(.noSpeechDetected)
                return
            }

            // Apply text replacements
            let text = TextReplacementManager.shared.apply(to: rawText)

            // Copy to clipboard
            try ClipboardManager.copy(text)
            NSLog("[OptionC] Copied to clipboard")

            // Auto-paste if enabled
            if autoPasteEnabled {
                // Delay to ensure clipboard is ready and the frontmost app has focus
                try? await Task.sleep(for: .milliseconds(500))
                simulatePaste()
            }

            transitionToSuccess(transcription: text)

        } catch AppError.transcriptionTimeout {
            NSLog("[OptionC] Transcription timed out after 30s")
            transitionToError(.transcriptionTimeout)

        } catch let error as AppError {
            NSLog("[OptionC] AppError: \(error)")
            transitionToError(error)

        } catch {
            NSLog("[OptionC] Error: \(error)")
            transitionToError(.recordingFailed(underlying: error))
        }
    }

    /// Whether accessibility permission is currently granted
    var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Request Accessibility permission (shows system prompt if not yet granted)
    func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Simulate Cmd+V keystroke to paste clipboard contents
    private func simulatePaste() {
        guard AXIsProcessTrusted() else {
            NSLog("[OptionC] Paste failed: Accessibility permission not granted")
            requestAccessibilityIfNeeded()
            return
        }

        let source = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode: CGKeyCode = 0x09 // kVK_ANSI_V

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            NSLog("[OptionC] Paste failed: could not create CGEvent")
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cgSessionEventTap)
        usleep(50_000) // 50ms between key down and key up
        keyUp.post(tap: .cgSessionEventTap)
        NSLog("[OptionC] Paste keystroke sent")
    }

    /// Transition to success state with brief icon flash then back to idle
    private func transitionToSuccess(transcription: String) {
        currentState = .success(transcription: transcription)

        Task {
            try? await Task.sleep(for: .milliseconds(750))
            // Only reset if still in success (user may have started a new recording)
            if case .success = currentState {
                currentState = .idle
            }
        }
    }

    /// Transition to error state with brief icon flash then back to idle
    private func transitionToError(_ error: AppError) {
        currentState = .error(error)

        Task {
            try? await Task.sleep(for: .seconds(1))
            // Only reset if still in error (user may have started a new recording)
            if case .error = currentState {
                currentState = .idle
            }
        }
    }

    /// SF Symbol name for the menu bar icon based on current state
    var menuBarIcon: String {
        switch currentState {
        case .idle:
            if whisperModelLoading {
                return "arrow.down.circle"
            }
            return whisperModelLoaded ? "mic" : "mic.slash"
        case .recording:
            return "mic.fill"
        case .processing:
            return "ellipsis"
        case .success:
            return "checkmark"
        case .error:
            return "xmark"
        }
    }
}
