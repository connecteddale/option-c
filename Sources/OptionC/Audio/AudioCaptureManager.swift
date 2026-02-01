import AVFoundation
import Speech

/// Manages microphone audio capture using AVAudioEngine.
/// Streams audio buffers to SFSpeechAudioBufferRecognitionRequest for real-time transcription.
@MainActor
class AudioCaptureManager {
    /// Audio engine instance - created fresh for each recording session
    /// Critical: Must be Optional and nil'd between sessions to avoid state corruption
    private var audioEngine: AVAudioEngine?

    /// Whether audio capture is currently active
    var isCapturing: Bool {
        audioEngine?.isRunning ?? false
    }

    /// Start capturing audio from the microphone and streaming to the recognition request.
    /// - Parameter request: The speech recognition request to stream audio buffers to
    /// - Throws: Error if audio engine fails to start
    func startCapture(request: SFSpeechAudioBufferRecognitionRequest) throws {
        // Create fresh AVAudioEngine instance for each session
        // Reusing instances causes state corruption where tap callback stops firing
        audioEngine = AVAudioEngine()

        guard let audioEngine = audioEngine else {
            return
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap with bufferSize 1024 for low-latency streaming
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            // Guard against captures after stop was called
            guard self?.isCapturing == true else { return }
            // Stream buffer to recognition request
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    /// Stop audio capture and clean up resources.
    /// Must be called before starting a new capture session.
    func stopCapture() {
        // Remove tap before stopping to avoid crashes
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        // Nil out engine for complete deallocation
        audioEngine = nil
    }
}
