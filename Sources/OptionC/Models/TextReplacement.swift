import Foundation

struct TextReplacement: Codable, Identifiable, Equatable {
    var id = UUID()
    var find: String
    var replace: String
}

/// Manages a persisted list of text replacements applied after transcription.
@MainActor
final class TextReplacementManager: ObservableObject {
    static let shared = TextReplacementManager()

    @Published var replacements: [TextReplacement] = [] {
        didSet { save() }
    }

    private let storageKey = "textReplacements"

    private init() {
        load()
    }

    /// Interpret escape sequences like \n and \t in a string.
    private func unescape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\n", with: "\n")
         .replacingOccurrences(of: "\\t", with: "\t")
    }

    /// Apply all replacements to a transcribed string.
    /// For multi-word find phrases, ignores punctuation/whitespace variations
    /// between words (e.g. "dot dot dot" matches "dot, dot, dot").
    /// Structural replacements (containing \n) absorb surrounding punctuation
    /// and whitespace that WhisperKit adds around spoken commands.
    /// Punctuation replacements (e.g. "full stop" → ".") absorb preceding
    /// punctuation to prevent doubling.
    /// Supports \n and \t in both find and replace strings.
    func apply(to text: String) -> String {
        var result = text
        // Apply longer find strings first to avoid partial-match conflicts
        let sorted = replacements.sorted { $0.find.count > $1.find.count }
        for r in sorted where !r.find.isEmpty {
            let replaceText = unescape(r.replace)
            let findText = unescape(r.find)
            let words = findText.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

            let isStructural = replaceText.contains("\n") || replaceText.contains("\t")
            let isPunctuation = !isStructural && !replaceText.isEmpty &&
                replaceText.allSatisfy { ".,;:!?…\"'()-".contains($0) }

            // Build core pattern (the find phrase itself)
            let corePattern: String
            if words.count > 1 {
                let escaped = words.map { NSRegularExpression.escapedPattern(for: $0) }
                corePattern = escaped.joined(separator: "[\\s,;.!?]+")
            } else {
                corePattern = NSRegularExpression.escapedPattern(for: findText)
            }

            if isStructural || isPunctuation {
                // Use regex with punctuation absorption
                let fullPattern: String
                if isStructural {
                    // Absorb leading whitespace + trailing punctuation & whitespace
                    // e.g. "Hello world. New paragraph. Next" → "Hello world.\n\nNext"
                    fullPattern = "\\s*" + corePattern + "[.!?,;:]*\\s*"
                } else {
                    // Absorb one preceding punctuation mark (prevents doubling)
                    // + trailing punctuation & whitespace
                    // e.g. "Hello world. Full stop." → "Hello world."
                    fullPattern = "[.!?,;:]?\\s*" + corePattern + "[.!?,;:]*"
                }

                if let regex = try? NSRegularExpression(pattern: fullPattern, options: .caseInsensitive) {
                    result = regex.stringByReplacingMatches(
                        in: result,
                        range: NSRange(result.startIndex..., in: result),
                        withTemplate: NSRegularExpression.escapedTemplate(for: replaceText)
                    )
                }
            } else if words.count > 1 {
                // Normal multi-word: existing behaviour
                if let regex = try? NSRegularExpression(pattern: corePattern, options: .caseInsensitive) {
                    result = regex.stringByReplacingMatches(
                        in: result,
                        range: NSRange(result.startIndex..., in: result),
                        withTemplate: NSRegularExpression.escapedTemplate(for: replaceText)
                    )
                }
            } else {
                // Normal single-word: simple string replace
                result = result.replacingOccurrences(
                    of: findText, with: replaceText, options: .caseInsensitive
                )
            }
        }

        // Cleanup pass for residual punctuation artifacts
        result = cleanupPunctuation(result)

        // Capitalise the first letter of every line
        result = capitaliseLineStarts(result)

        return result
    }

    /// Fix punctuation artifacts left after replacements.
    private func cleanupPunctuation(_ text: String) -> String {
        var result = text

        // Collapse runs of the same punctuation (e.g. ".." → ".", ",," → ",")
        if let regex = try? NSRegularExpression(pattern: "([.!?,;:])\\1+") {
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        // Collapse same punctuation separated by whitespace (e.g. ". ." → ".")
        if let regex = try? NSRegularExpression(pattern: "([.!?,;:])\\s+\\1") {
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        // Remove orphan punctuation at the start of a line
        if let regex = try? NSRegularExpression(pattern: "\\n[.!?,;:]\\s*") {
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result),
                withTemplate: "\n"
            )
        }

        // Remove orphan punctuation at the very start of the text
        if let regex = try? NSRegularExpression(pattern: "^[.!?,;:]\\s*") {
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        return result
    }

    /// Capitalise the first letter of every line and the start of the text.
    /// Handles lines that begin with optional whitespace.
    private func capitaliseLineStarts(_ text: String) -> String {
        var result = text

        // Capitalise the very first letter of the text
        if let first = result.firstIndex(where: { $0.isLetter }) {
            result.replaceSubrange(first...first, with: String(result[first]).uppercased())
        }

        // Capitalise the first letter after each newline
        if let regex = try? NSRegularExpression(pattern: "\\n(\\s*)(\\p{Ll})") {
            let nsRange = NSRange(result.startIndex..., in: result)
            // Walk matches in reverse so index offsets stay valid
            let matches = regex.matches(in: result, range: nsRange).reversed()
            for match in matches {
                guard let letterRange = Range(match.range(at: 2), in: result) else { continue }
                let upper = String(result[letterRange]).uppercased()
                result.replaceSubrange(letterRange, with: upper)
            }
        }

        // Capitalise the first letter after sentence-ending punctuation (. ! ?)
        if let regex = try? NSRegularExpression(pattern: "([.!?])\\s+(\\p{Ll})") {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: nsRange).reversed()
            for match in matches {
                guard let letterRange = Range(match.range(at: 2), in: result) else { continue }
                let upper = String(result[letterRange]).uppercased()
                result.replaceSubrange(letterRange, with: upper)
            }
        }

        return result
    }

    func add(find: String, replace: String) {
        replacements.append(TextReplacement(find: find, replace: replace))
    }

    func remove(at offsets: IndexSet) {
        replacements.remove(atOffsets: offsets)
    }

    func remove(id: UUID) {
        replacements.removeAll { $0.id == id }
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(replacements) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([TextReplacement].self, from: data)
        else { return }
        replacements = decoded
    }
}
