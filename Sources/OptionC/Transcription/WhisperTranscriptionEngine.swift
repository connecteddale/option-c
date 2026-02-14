import Foundation
import WhisperKit

/// Transcription engine using WhisperKit for high-accuracy speech recognition
actor WhisperTranscriptionEngine {
    /// Shared instance
    static let shared = WhisperTranscriptionEngine()

    /// The WhisperKit pipeline
    private var whisperKit: WhisperKit?

    /// Whether the model is currently loading
    private var isLoading = false

    /// Current model name
    private var currentModel: String?

    /// Available Whisper models (smallest to largest)
    static let availableModels = [
        "openai_whisper-tiny",      // ~40MB, fastest, least accurate
        "openai_whisper-base",      // ~150MB, good balance
        "openai_whisper-small",     // ~500MB, better accuracy
        "openai_whisper-medium",    // ~1.5GB, high accuracy
        "openai_whisper-large-v3"   // ~3GB, best accuracy
    ]

    /// Default model for good balance of speed and accuracy
    static let defaultModel = "openai_whisper-base"

    private init() {}

    /// Check if model is loaded and ready
    func isReady() -> Bool {
        return whisperKit != nil && !isLoading
    }

    /// Load a Whisper model (downloads if needed)
    func loadModel(_ modelName: String) async throws {
        // Skip if already loaded
        if currentModel == modelName && whisperKit != nil {
            return
        }

        isLoading = true
        defer { isLoading = false }

        // Initialize WhisperKit with the specified model
        let config = WhisperKitConfig(
            model: modelName,
            computeOptions: ModelComputeOptions(
                audioEncoderCompute: .cpuAndNeuralEngine,
                textDecoderCompute: .cpuAndNeuralEngine
            )
        )

        whisperKit = try await WhisperKit(config)
        currentModel = modelName
    }

    /// Transcribe audio from a file URL
    func transcribe(audioURL: URL) async throws -> String {
        guard let whisperKit = whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }

        let results = try await whisperKit.transcribe(audioPath: audioURL.path)

        // Combine all segments into final text
        let text = results
            .compactMap { $0.text }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return text
    }

    /// Transcribe audio from raw audio samples
    func transcribe(audioSamples: [Float]) async throws -> String {
        guard let whisperKit = whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }

        let options = DecodingOptions(
            language: "en",
            temperature: 0.0,
            usePrefillPrompt: true,
            usePrefillCache: true,
            suppressBlank: true,
            compressionRatioThreshold: 2.4,
            logProbThreshold: -1.0,
            noSpeechThreshold: 0.6
        )

        let results = try await whisperKit.transcribe(
            audioArray: audioSamples,
            decodeOptions: options
        )

        // Combine all segments into final text
        let text = results
            .compactMap { $0.text }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return text
    }
}

/// Errors specific to WhisperKit transcription
enum TranscriptionError: Error, LocalizedError {
    case modelNotLoaded
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Whisper model not loaded"
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        }
    }
}
