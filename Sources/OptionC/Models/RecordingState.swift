/// Represents the current recording state of the app
enum RecordingState {
    /// App is idle, waiting for user to start recording
    case idle
    /// App is actively recording audio
    case recording
    /// App is processing/transcribing the recorded audio
    case processing
}
