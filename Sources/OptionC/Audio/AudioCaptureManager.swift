@preconcurrency import AVFoundation
import Speech

/// Thread-safe audio sample buffer that can be appended to from any thread.
/// Extracted from AudioCaptureManager so the real-time audio tap callback
/// can write samples without dispatching to MainActor.
private final class AudioSampleBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: [Float] = []

    func append(_ newSamples: [Float]) {
        lock.lock()
        samples.append(contentsOf: newSamples)
        lock.unlock()
    }

    func drain() -> [Float] {
        lock.lock()
        let result = samples
        samples = []
        lock.unlock()
        return result
    }

    func reset() {
        lock.lock()
        samples = []
        lock.unlock()
    }
}

/// Manages microphone audio capture using AVAudioEngine.
/// Supports both streaming to SFSpeechRecognizer and collecting samples for WhisperKit.
@MainActor
class AudioCaptureManager {
    /// Audio engine instance - created fresh for each recording session
    /// Critical: Must be Optional and nil'd between sessions to avoid state corruption
    private var audioEngine: AVAudioEngine?

    /// Thread-safe buffer for collected audio samples (16kHz mono Float).
    /// The audio tap callback appends directly without dispatching to MainActor.
    private let sampleBuffer = AudioSampleBuffer()

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
        sampleBuffer.reset()

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

        // Capture converter reference for the closure — avoids accessing
        // MainActor-isolated self.audioConverter from the audio thread.
        let converter = audioConverter
        let buffer = sampleBuffer

        // Install tap to collect audio samples.
        // The tap callback runs on a real-time audio thread — do the conversion
        // here and append to the thread-safe buffer, avoiding MainActor dispatch.
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { pcmBuffer, _ in
            Self.processBuffer(pcmBuffer, converter: converter, targetFormat: whisperFormat, into: buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    /// Process audio buffer on the audio thread (NOT MainActor).
    /// Converts to 16kHz mono and appends to the thread-safe sample buffer.
    /// Static so it captures no actor-isolated state.
    nonisolated private static func processBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter?,
        targetFormat: AVAudioFormat,
        into sampleBuffer: AudioSampleBuffer
    ) {
        var samplesToAdd: [Float] = []

        if let converter = converter {
            // Need to convert
            let inputFormat = buffer.format
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

        sampleBuffer.append(samplesToAdd)
    }

    /// Get collected audio samples (for WhisperKit transcription)
    func getAudioSamples() -> [Float] {
        return sampleBuffer.drain()
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
