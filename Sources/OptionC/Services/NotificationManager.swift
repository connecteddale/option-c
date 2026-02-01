import UserNotifications

/// Manages system notifications for transcription success, errors, and timeout feedback.
/// Uses UNUserNotificationCenter for modern macOS notification delivery.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    /// Requests notification permission from the user.
    /// - Returns: `true` if authorization was granted, `false` otherwise.
    @discardableResult
    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    /// Shows a success notification when transcription is ready and copied to clipboard.
    /// - Parameter transcription: The transcribed text to preview in the notification body.
    func showSuccess(transcription: String) {
        let content = UNMutableNotificationContent()
        content.title = "Transcription Ready"
        content.subtitle = "Copied to clipboard"
        content.body = transcription.count > 100
            ? String(transcription.prefix(100)) + "..."
            : transcription
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Shows an error notification with the error description and recovery suggestion.
    /// - Parameter error: The AppError to display to the user.
    func showError(_ error: AppError) {
        let content = UNMutableNotificationContent()
        content.title = error.errorDescription ?? "Error"
        content.body = error.recoverySuggestion ?? "Please try again"
        content.sound = .defaultCritical

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Shows a timeout notification when no speech was detected within the recording period.
    func showTimeout() {
        let content = UNMutableNotificationContent()
        content.title = "No Speech Detected"
        content.body = "Recording timed out after 30 seconds. Please try again."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }
}
