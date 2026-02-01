import SwiftUI
import KeyboardShortcuts

/// Centralized state coordinator for the Option-C app
@MainActor
class AppState: ObservableObject {
    /// Current recording state
    @Published var currentState: RecordingState = .idle

    /// User preference for recording mode (persisted)
    @AppStorage("recordingMode") var recordingMode: RecordingMode = .toggle

    /// Controller that orchestrates audio capture and transcription
    private let recordingController = RecordingController()

    init() {
        // Register both key down and key up handlers for dual-mode support
        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            self?.handleKeyDown()
        }
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            self?.handleKeyUp()
        }
    }

    /// Handle key down event for push-to-talk mode
    func handleKeyDown() {
        guard currentState == .idle else { return }

        if recordingMode == .pushToTalk {
            // Push-to-talk: start on key down
            Task { await startRecording() }
        }
        // Toggle mode: do nothing on key down
    }

    /// Handle key up event for toggle mode and push-to-talk release
    func handleKeyUp() {
        switch recordingMode {
        case .toggle:
            // Toggle: flip state on key up
            switch currentState {
            case .idle:
                Task { await startRecording() }
            case .recording:
                Task { await stopRecording() }
            case .processing:
                break // Ignore while processing
            }
        case .pushToTalk:
            // Push-to-talk: stop on key up
            if currentState == .recording {
                Task { await stopRecording() }
            }
        }
    }

    /// Start recording after checking permissions
    private func startRecording() async {
        // Check permissions first
        let hasPermissions = await recordingController.requestPermissions()
        guard hasPermissions else {
            // Stay idle if permissions denied (error handling in Phase 3)
            return
        }

        do {
            try recordingController.startRecording()
            currentState = .recording
        } catch {
            // Stay idle if recording fails to start (error handling in Phase 3)
        }
    }

    /// Stop recording and process transcription
    private func stopRecording() async {
        currentState = .processing
        _ = await recordingController.stopRecording()
        currentState = .idle
        // Notification of success/failure is Phase 3
    }

    /// SF Symbol name for the menu bar icon based on current state
    var menuBarIcon: String {
        switch currentState {
        case .idle:
            return "mic.circle"
        case .recording:
            return "mic.circle.fill"
        case .processing:
            return "waveform.circle"
        }
    }
}
