import Speech

/// Errors that can occur during transcription
enum TranscriptionError: Error, LocalizedError {
    case timeout
    case recognizerUnavailable
    case noSpeechDetected

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Transcription timed out"
        case .recognizerUnavailable:
            return "Speech recognizer is unavailable"
        case .noSpeechDetected:
            return "No speech was detected"
        }
    }
}

/// Handles speech-to-text transcription using SFSpeechRecognizer.
/// Provides timeout handling and offline-only recognition.
@MainActor
class TranscriptionEngine {
    /// Speech recognizer initialized with the user's current locale
    private let speechRecognizer: SFSpeechRecognizer?

    /// Current recognition task for tracking and cancellation
    private var recognitionTask: SFSpeechRecognitionTask?

    /// Timer for handling unresponsive transcription
    private var timeoutTimer: Timer?

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    }

    /// Transcribe audio from a recognition request.
    /// - Parameters:
    ///   - request: The speech recognition request containing audio buffers
    ///   - timeout: Maximum time to wait for final result (default 30 seconds)
    ///   - onPartialResult: Optional callback for intermediate transcription results
    ///   - completion: Called with the final transcription result or error
    func transcribe(
        request: SFSpeechAudioBufferRecognitionRequest,
        timeout: TimeInterval = 30.0,
        onPartialResult: ((String) -> Void)? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Verify recognizer is available
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            completion(.failure(TranscriptionError.recognizerUnavailable))
            return
        }

        // Configure for offline recognition and partial results
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true

        // Start timeout timer
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.cancel()
                completion(.failure(TranscriptionError.timeout))
            }
        }

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }

                // Invalidate timeout on any result
                self.timeoutTimer?.invalidate()
                self.timeoutTimer = nil

                if let error = error {
                    // Clean up on error
                    self.recognitionTask = nil
                    completion(.failure(error))
                    return
                }

                guard let result = result else { return }

                if result.isFinal {
                    // Final result received
                    self.recognitionTask = nil
                    let transcription = result.bestTranscription.formattedString
                    if transcription.isEmpty {
                        completion(.failure(TranscriptionError.noSpeechDetected))
                    } else {
                        completion(.success(transcription))
                    }
                } else {
                    // Partial result - restart timeout timer for another timeout period
                    self.timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
                        Task { @MainActor in
                            self?.cancel()
                            completion(.failure(TranscriptionError.timeout))
                        }
                    }
                    // Report partial result if callback provided
                    onPartialResult?(result.bestTranscription.formattedString)
                }
            }
        }
    }

    /// Cancel the current transcription task and clean up resources.
    func cancel() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}
