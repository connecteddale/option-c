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
    /// Supports \n and \t in both find and replace strings.
    func apply(to text: String) -> String {
        var result = text
        // Apply longer find strings first to avoid partial-match conflicts
        let sorted = replacements.sorted { $0.find.count > $1.find.count }
        for r in sorted where !r.find.isEmpty {
            let replaceText = unescape(r.replace)
            let findText = unescape(r.find)
            let words = findText.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if words.count > 1 {
                // Build regex: words separated by any mix of whitespace and punctuation
                let escaped = words.map { NSRegularExpression.escapedPattern(for: $0) }
                let pattern = escaped.joined(separator: "[\\s,;.!?]+")
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    result = regex.stringByReplacingMatches(
                        in: result,
                        range: NSRange(result.startIndex..., in: result),
                        withTemplate: NSRegularExpression.escapedTemplate(for: replaceText)
                    )
                }
            } else {
                result = result.replacingOccurrences(
                    of: findText, with: replaceText, options: .caseInsensitive
                )
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
