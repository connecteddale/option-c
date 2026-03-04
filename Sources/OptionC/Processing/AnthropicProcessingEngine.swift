import Foundation

enum AnthropicError: Error, LocalizedError {
    case apiKeyMissing
    case invalidResponse
    case httpError(Int, String)
    case emptyOutput

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing: return "Anthropic API key not set"
        case .invalidResponse: return "Invalid response from Anthropic API"
        case .httpError(let code, let msg): return "Anthropic API error \(code): \(msg)"
        case .emptyOutput: return "Anthropic returned empty output"
        }
    }
}

/// Concrete LLM provider that calls the Anthropic Messages API.
/// Uses Claude Haiku for fast, low-cost text cleanup.
final class AnthropicProcessingEngine: LLMProcessingProvider {
    private let apiKey: String
    private let model: String
    private let timeoutSeconds: TimeInterval

    /// Enhanced prompt — Claude handles complex formatting rules reliably.
    private static let systemPrompt = """
        You clean up transcribed speech. Apply these rules and output ONLY the cleaned text.

        Rules:
        1. Add missing punctuation (commas, full stops, question marks).
        2. Capitalise sentence starts and proper nouns only.
        3. Remove filler words: um, uh, er, like, you know.
        4. Use British English spelling.
        5. Format times as 24-hour (e.g. "three thirty pm" → "15:30").
        6. Numbers under 10 as words, 10+ as digits.
        7. Currency with symbols (e.g. "five dollars" → "$5", "ten pounds" → "£10").
        8. Do NOT rephrase or add words. Keep the speaker's exact wording.
        9. Output ONLY the cleaned text. No preamble, no explanation.
        """

    init(apiKey: String, model: String = "claude-haiku-4-5-20251001", timeout: TimeInterval = 30) {
        self.apiKey = apiKey
        self.model = model
        self.timeoutSeconds = timeout
    }

    func process(_ text: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw AnthropicError.apiKeyMissing
        }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = timeoutSeconds

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": Self.systemPrompt,
            "messages": [
                ["role": "user", "content": text]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown"
            NSLog("[OptionC] Anthropic HTTP %d: %@", httpResponse.statusCode, errorBody)
            throw AnthropicError.httpError(httpResponse.statusCode, errorBody)
        }

        let chatResponse = try JSONDecoder().decode(AnthropicMessagesResponse.self, from: data)

        guard let firstContent = chatResponse.content.first else {
            throw AnthropicError.emptyOutput
        }

        let output = firstContent.text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !output.isEmpty else {
            throw AnthropicError.emptyOutput
        }

        return output
    }
}

// MARK: - Codable Models

private struct AnthropicMessagesResponse: Decodable {
    let content: [AnthropicContentBlock]
}

private struct AnthropicContentBlock: Decodable {
    let type: String
    let text: String
}
