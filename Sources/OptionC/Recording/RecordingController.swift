import AVFoundation
import Speech

/// Executes an async operation with a timeout.
/// Uses withThrowingTaskGroup to race the operation against a sleep.
/// - Parameters:
///   - seconds: Maximum time to wait for the operation
///   - operation: The async operation to execute
/// - Returns: The result of the operation
/// - Throws: AppError.transcriptionTimeout if the operation doesn't complete in time
func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Add timeout task
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw AppError.transcriptionTimeout
        }

        // Add actual operation
        group.addTask {
            try await operation()
        }

        // Wait for first to complete
        let result = try await group.next()!

        // Cancel remaining tasks
        group.cancelAll()

        return result
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
