import AppKit

/// Errors that can occur during clipboard operations
enum ClipboardError: Error, LocalizedError {
    /// Failed to write text to the clipboard
    case writeFailed
    /// Verification failed - clipboard content doesn't match written text
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .writeFailed:
            return "Failed to write to clipboard"
        case .verificationFailed:
            return "Clipboard verification failed"
        }
    }
}

/// Manages clipboard operations with atomic writes and verification.
/// Ensures transcription text is reliably copied to the system clipboard.
@MainActor
struct ClipboardManager {
    /// Copy text to the system clipboard with verification.
    /// - Parameter text: The text to copy to the clipboard
    /// - Throws: ClipboardError.writeFailed if write fails, ClipboardError.verificationFailed if verification fails
    static func copy(_ text: String) throws {
        let pasteboard = NSPasteboard.general

        // Clear existing clipboard contents
        pasteboard.clearContents()

        // Write text to clipboard
        let success = pasteboard.setString(text, forType: .string)
        guard success else {
            throw ClipboardError.writeFailed
        }

        // Verify by reading back
        guard let readBack = pasteboard.string(forType: .string),
              readBack == text else {
            throw ClipboardError.verificationFailed
        }
    }
}
