import SwiftUI
import KeyboardShortcuts

/// Centralized state coordinator for the Option-C app
@MainActor
class AppState: ObservableObject {
    /// Current recording state
    @Published var currentState: RecordingState = .idle

    /// User preference for recording mode (persisted)
    @AppStorage("recordingMode") var recordingMode: RecordingMode = .toggle

    init() {
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            self?.handleHotkeyPress()
        }
    }

    /// Handle Option-C hotkey press - implements state machine transitions
    func handleHotkeyPress() {
        switch currentState {
        case .idle:
            currentState = .recording
        case .recording:
            currentState = .processing
            // Simulate processing completion (will be replaced with real transcription in Phase 2)
            Task {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run {
                    self.currentState = .idle
                }
            }
        case .processing:
            // Ignore hotkey while processing
            break
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
        }
    }
}
