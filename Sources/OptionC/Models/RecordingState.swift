/// Represents the current recording state of the app
enum RecordingState: Equatable {
    /// App is idle, waiting for user to start recording
    case idle
    /// App is actively recording audio
    case recording
    /// App is processing/transcribing the recorded audio
    case processing
    /// Transcription succeeded and was copied to clipboard
    case success(transcription: String)
    /// An error occurred during recording or transcription
    case error(AppError)

    /// Human-readable display name for the current state
    var displayName: String {
        switch self {
        case .idle: return "Ready"
        case .recording: return "Recording..."
        case .processing: return "Processing..."
        case .success: return "Copied!"
        case .error(let error): return error.errorDescription ?? "Error"
        }
    }

    static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.recording, .recording): return true
        case (.processing, .processing): return true
        case (.success(let a), .success(let b)): return a == b
        case (.error, .error): return true // Compare by case, not by associated value
        default: return false
        }
    }
}
