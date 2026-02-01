/// Represents the recording mode preference
enum RecordingMode: String, Codable {
    /// Press once to start, press again to stop
    case toggle
    /// Hold key to record, release to stop
    case pushToTalk
}
