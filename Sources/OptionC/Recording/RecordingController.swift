import AVFoundation
import Speech

/// Orchestrates the audio capture and transcription pipeline.
/// Coordinates AudioCaptureManager and TranscriptionEngine to provide
/// a simple start/stop interface for the voice-to-clipboard flow.
@MainActor
class RecordingController: ObservableObject {
    /// Audio capture manager for microphone input
    private let audioCaptureManager = AudioCaptureManager()

    /// Transcription engine for speech recognition
    private let transcriptionEngine = TranscriptionEngine()

    /// Current recognition request for the active session
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    /// Continuation for awaiting transcription completion
    private var transcriptionContinuation: CheckedContinuation<String?, Never>?

    /// The most recent transcribed text (updated with partial results)
    @Published var transcribedText: String = ""

    /// Whether audio capture is currently active
    @Published var isRecording: Bool = false

    /// Request permissions for microphone and speech recognition.
    /// - Returns: true if both permissions are granted, false otherwise
    func requestPermissions() async -> Bool {
        // Request microphone permission
        let micGranted = await AVCaptureDevice.requestAccess(for: .audio)

        // Request speech recognition permission
        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        return micGranted && speechGranted
    }

    /// Start recording audio and transcribing speech.
    /// - Throws: Error if audio capture fails to start
    func startRecording() throws {
        guard !isRecording else { return }

        // Create fresh recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest = request

        // Reset transcribed text
        transcribedText = ""

        // Start transcription (fires completion when done)
        transcriptionEngine.transcribe(
            request: request,
            onPartialResult: { [weak self] partialText in
                Task { @MainActor in
                    self?.transcribedText = partialText
                }
            },
            completion: { [weak self] result in
                Task { @MainActor in
                    guard let self = self else { return }

                    switch result {
                    case .success(let text):
                        self.transcribedText = text
                        self.transcriptionContinuation?.resume(returning: text)
                    case .failure:
                        self.transcriptionContinuation?.resume(returning: nil)
                    }
                    self.transcriptionContinuation = nil
                }
            }
        )

        // Start audio capture
        try audioCaptureManager.startCapture(request: request)
        isRecording = true
    }

    /// Stop recording and return the final transcription.
    /// Critical: Calls endAudio() on request BEFORE stopping capture
    /// to signal the recognizer to finalize transcription.
    /// - Returns: The final transcribed text, or nil if transcription failed
    func stopRecording() async -> String? {
        guard isRecording else { return nil }

        // CRITICAL: End audio on request FIRST to signal finalization
        recognitionRequest?.endAudio()

        // Then stop audio capture
        audioCaptureManager.stopCapture()
        isRecording = false

        // Wait for transcription to complete if not already done
        let finalText: String?
        if !transcribedText.isEmpty {
            // Use existing result if we already have one
            finalText = await withCheckedContinuation { continuation in
                // Check if transcription already completed
                if self.transcriptionContinuation == nil {
                    // Already have final result
                    continuation.resume(returning: self.transcribedText.isEmpty ? nil : self.transcribedText)
                } else {
                    // Wait for transcription completion
                    self.transcriptionContinuation = continuation
                }
            }
        } else {
            // No partial results yet, wait for completion
            finalText = await withCheckedContinuation { continuation in
                self.transcriptionContinuation = continuation
            }
        }

        // Copy to clipboard if we have text
        if let text = finalText, !text.isEmpty {
            try? ClipboardManager.copy(text)
        }

        // Clean up
        recognitionRequest = nil

        return finalText
    }
}
