import AVFoundation
import Speech

/// Status of a system permission.
enum PermissionStatus {
    case granted
    case denied
    case notDetermined
    case restricted
}

/// Manages microphone and speech recognition permission checks and requests.
@MainActor
final class PermissionManager {

    // MARK: - Microphone Permission

    /// Checks the current microphone permission status.
    func checkMicrophonePermission() -> PermissionStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }

    /// Requests microphone permission if not already determined.
    /// - Returns: Success if permission granted, failure with AppError if denied.
    func requestMicrophonePermission() async -> Result<Void, AppError> {
        let currentStatus = checkMicrophonePermission()

        switch currentStatus {
        case .granted:
            return .success(())
        case .denied, .restricted:
            return .failure(.microphonePermissionDenied)
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if granted {
                return .success(())
            } else {
                return .failure(.microphonePermissionDenied)
            }
        }
    }

    // MARK: - Speech Recognition Permission

    /// Checks the current speech recognition permission status.
    func checkSpeechRecognitionPermission() -> PermissionStatus {
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }

    /// Requests speech recognition permission if not already determined.
    /// - Returns: Success if permission granted, failure with AppError if denied.
    func requestSpeechRecognitionPermission() async -> Result<Void, AppError> {
        let currentStatus = checkSpeechRecognitionPermission()

        switch currentStatus {
        case .granted:
            return .success(())
        case .denied, .restricted:
            return .failure(.speechRecognitionPermissionDenied)
        case .notDetermined:
            let newStatus = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }

            if newStatus == .authorized {
                return .success(())
            } else {
                return .failure(.speechRecognitionPermissionDenied)
            }
        }
    }
}
