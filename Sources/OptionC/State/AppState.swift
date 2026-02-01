import SwiftUI

/// Centralized state coordinator for the Option-C app
@MainActor
class AppState: ObservableObject {
    /// Current recording state
    @Published var currentState: RecordingState = .idle

    /// User preference for recording mode (persisted)
    @AppStorage("recordingMode") var recordingMode: RecordingMode = .toggle

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
