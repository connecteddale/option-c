import Foundation

/// Centralized error types for Option-C with user-friendly messages and recovery suggestions.
enum AppError: Error, LocalizedError {
    case microphonePermissionDenied
    case speechRecognitionPermissionDenied
    case noSpeechDetected
    case transcriptionTimeout
    case recordingFailed(underlying: Error)
    case clipboardWriteFailed
    case aiProcessingFailed(underlying: Error)
    case ollamaNotRunning
    case ollamaModelMissing(model: String)

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access required"
        case .speechRecognitionPermissionDenied:
            return "Speech recognition access required"
        case .noSpeechDetected:
            return "No speech detected"
        case .transcriptionTimeout:
            return "Transcription timed out"
        case .recordingFailed:
            return "Recording failed"
        case .clipboardWriteFailed:
            return "Failed to copy to clipboard"
        case .aiProcessingFailed:
            return "AI text cleanup failed"
        case .ollamaNotRunning:
            return "Ollama is not running"
        case .ollamaModelMissing:
            return "AI model not found"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Enable microphone access in System Settings > Privacy & Security > Microphone"
        case .speechRecognitionPermissionDenied:
            return "Enable speech recognition in System Settings > Privacy & Security > Speech Recognition"
        case .noSpeechDetected:
            return "Try speaking louder or closer to the microphone"
        case .transcriptionTimeout:
            return "Try a shorter recording or check your internet connection"
        case .recordingFailed(let underlying):
            return "Recording error: \(underlying.localizedDescription). Try restarting the app."
        case .clipboardWriteFailed:
            return "Could not write to clipboard. Try again or restart the app."
        case .aiProcessingFailed(let underlying):
            return "Check that Ollama is running (ollama serve). The raw transcription was copied to clipboard. Error: \(underlying.localizedDescription)"
        case .ollamaNotRunning:
            return "Start Ollama with: ollama serve. Raw transcription was copied to clipboard."
        case .ollamaModelMissing(let model):
            return "Pull the model with: ollama pull \(model). Raw transcription was copied to clipboard."
        }
    }
}
