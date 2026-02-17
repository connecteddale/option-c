import AVFoundation
import Speech

/// Thread-safe flag ensuring a continuation is resumed exactly once.
private final class TimeoutState: @unchecked Sendable {
    private var completed = false
    private let lock = NSLock()

    func tryComplete() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if completed { return false }
        completed = true
        return true
    }
}

/// Executes an async operation with a hard timeout.
/// Uses independent Tasks so the timeout fires even if the operation blocks.
/// The operation continues running in the background but its result is discarded.
func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
        let state = TimeoutState()

        // Operation task
        Task {
            do {
                let result = try await operation()
                if state.tryComplete() {
                    continuation.resume(returning: result)
                }
            } catch {
                if state.tryComplete() {
                    continuation.resume(throwing: error)
                }
            }
        }

        // Timeout task
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            if state.tryComplete() {
                continuation.resume(throwing: AppError.transcriptionTimeout)
            }
        }
    }
}

/// Orchestrates the audio capture and transcription pipeline.
/// Uses WhisperKit for high-accuracy transcription.
@MainActor
class RecordingController: ObservableObject {
    /// Audio capture manager for microphone input
    private let audioCaptureManager = AudioCaptureManager()

    /// The most recent transcribed text
    @Published var transcribedText: String = ""

    /// Whether audio capture is currently active
    @Published var isRecording: Bool = false

    /// Whether WhisperKit model is loaded
    @Published var isModelLoaded: Bool = false

    /// Current Whisper model being used
    @Published var currentModel: String = ""

    /// Load WhisperKit model (downloads if needed)
    func loadModel(_ modelName: String) async throws {
        try await WhisperTranscriptionEngine.shared.loadModel(modelName)
        isModelLoaded = true
        currentModel = modelName
    }

    /// Start recording audio for WhisperKit transcription
    /// - Throws: Error if audio capture fails to start
    func startRecording() throws {
        guard !isRecording else { return }

        // Reset transcribed text
        transcribedText = ""

        // Start audio capture for WhisperKit
        try audioCaptureManager.startCaptureForWhisper()
        isRecording = true
    }

    /// Stop recording and return the transcription from WhisperKit
    /// - Returns: The transcribed text, or nil if transcription failed
    func stopRecording() async -> String? {
        guard isRecording else { return nil }

        // Get collected audio samples
        let samples = audioCaptureManager.getAudioSamples()

        // Stop audio capture
        audioCaptureManager.stopCapture()
        isRecording = false

        // Check if we have enough audio (at least 0.5 seconds at 16kHz)
        guard samples.count > 8000 else {
            return nil
        }

        // Transcribe with WhisperKit
        do {
            let text = try await WhisperTranscriptionEngine.shared.transcribe(audioSamples: samples)
            transcribedText = text
            return text.isEmpty ? nil : text
        } catch {
            print("WhisperKit transcription error: \(error)")
            return nil
        }
    }
}
