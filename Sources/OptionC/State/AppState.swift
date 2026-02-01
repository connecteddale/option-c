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

    /// Permission manager for checking and requesting system permissions
    private let permissionManager = PermissionManager()

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
            case .processing, .success, .error:
                break // Ignore while processing or in transient states
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
        // Check microphone permission
        let micResult = await permissionManager.requestMicrophonePermission()
        guard case .success = micResult else {
            if case .failure(let error) = micResult {
                transitionToError(error)
            }
            return
        }

        // Check speech recognition permission
        let speechResult = await permissionManager.requestSpeechRecognitionPermission()
        guard case .success = speechResult else {
            if case .failure(let error) = speechResult {
                transitionToError(error)
            }
            return
        }

        // Permissions granted, proceed with recording
        do {
            try recordingController.startRecording()
            currentState = .recording
        } catch {
            transitionToError(.recordingFailed(underlying: error))
        }
    }

    /// Stop recording and process transcription
    private func stopRecording() async {
        currentState = .processing

        do {
            // Wrap transcription in 30-second timeout
            let transcription = try await withTimeout(seconds: 30) {
                await self.recordingController.stopRecording()
            }

            // Check if we got valid transcription
            guard let text = transcription, !text.isEmpty else {
                transitionToError(.noSpeechDetected)
                return
            }

            // Transcription already copied to clipboard by RecordingController
            transitionToSuccess(transcription: text)

        } catch AppError.transcriptionTimeout {
            // Timeout gets specific notification
            NotificationManager.shared.showTimeout()
            currentState = .idle

        } catch let error as AppError {
            transitionToError(error)

        } catch {
            transitionToError(.recordingFailed(underlying: error))
        }
    }

    /// Transition to success state with notification and auto-reset to idle
    private func transitionToSuccess(transcription: String) {
        currentState = .success(transcription: transcription)
        NotificationManager.shared.showSuccess(transcription: transcription)

        Task {
            try? await Task.sleep(for: .seconds(2))
            currentState = .idle
        }
    }

    /// Transition to error state with notification and auto-reset to idle
    private func transitionToError(_ error: AppError) {
        currentState = .error(error)
        NotificationManager.shared.showError(error)

        Task {
            try? await Task.sleep(for: .seconds(3))
            currentState = .idle
        }
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
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.circle"
        }
    }
}
