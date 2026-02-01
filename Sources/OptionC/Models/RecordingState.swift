/// Represents the current recording state of the app
enum RecordingState {
    /// App is idle, waiting for user to start recording
    case idle
    /// App is actively recording audio
    case recording
    /// App is processing/transcribing the recorded audio
    case processing

    /// Human-readable display name for the current state
    var displayName: String {
        switch self {
        case .idle: return "Ready"
        case .recording: return "Recording..."
        case .processing: return "Processing..."
        }
    }
}
