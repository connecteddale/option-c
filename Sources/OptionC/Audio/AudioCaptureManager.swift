import AVFoundation
import Speech

/// Manages microphone audio capture using AVAudioEngine.
/// Supports both streaming to SFSpeechRecognizer and collecting samples for WhisperKit.
@MainActor
class AudioCaptureManager {
    /// Audio engine instance - created fresh for each recording session
    /// Critical: Must be Optional and nil'd between sessions to avoid state corruption
    private var audioEngine: AVAudioEngine?

    /// Collected audio samples for WhisperKit (16kHz mono Float)
    private var audioSamples: [Float] = []

    /// Audio converter for resampling to 16kHz
    private var audioConverter: AVAudioConverter?

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

    /// Start capturing audio for WhisperKit transcription (collects samples in memory)
    /// - Throws: Error if audio engine fails to start
    func startCaptureForWhisper() throws {
        // Create fresh AVAudioEngine instance for each session
        audioEngine = AVAudioEngine()
        audioSamples = []

        guard let audioEngine = audioEngine else {
            return
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // WhisperKit expects 16kHz mono audio
        let whisperFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!

        // Create converter if sample rate or channels differ
        if inputFormat.sampleRate != 16000 || inputFormat.channelCount != 1 {
            audioConverter = AVAudioConverter(from: inputFormat, to: whisperFormat)
        }

        // Install tap to collect audio samples
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self, self.isCapturing else { return }

            Task { @MainActor in
                self.processBuffer(buffer, inputFormat: inputFormat, targetFormat: whisperFormat)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    /// Process audio buffer and convert to 16kHz mono if needed
    private func processBuffer(_ buffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat, targetFormat: AVAudioFormat) {
        var samplesToAdd: [Float] = []

        if let converter = audioConverter {
            // Need to convert
            let frameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * 16000.0 / inputFormat.sampleRate) + 1
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else { return }

            var error: NSError?
            var allConsumed = false

            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                if allConsumed {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                allConsumed = true
                outStatus.pointee = .haveData
                return buffer
            }

            if error == nil, let channelData = convertedBuffer.floatChannelData {
                let frames = Int(convertedBuffer.frameLength)
                samplesToAdd = Array(UnsafeBufferPointer(start: channelData[0], count: frames))
            }
        } else {
            // Already in correct format
            if let channelData = buffer.floatChannelData {
                let frames = Int(buffer.frameLength)
                samplesToAdd = Array(UnsafeBufferPointer(start: channelData[0], count: frames))
            }
        }

        audioSamples.append(contentsOf: samplesToAdd)
    }

    /// Get collected audio samples (for WhisperKit transcription)
    func getAudioSamples() -> [Float] {
        return audioSamples
    }

    /// Stop audio capture and clean up resources.
    /// Must be called before starting a new capture session.
    func stopCapture() {
        // Remove tap before stopping to avoid crashes
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        // Nil out engine for complete deallocation
        audioEngine = nil
        audioConverter = nil
    }
}
