import Foundation

/// Errors specific to Ollama HTTP communication and response validation.
enum OllamaError: Error {
    case invalidResponse
    case httpError(Int)
    case emptyOutput
    case outputLengthSuspect
}

/// Concrete LLM provider that calls Ollama's /api/chat endpoint via URLSession.
/// Uses non-streaming mode (stream: false) to receive a single JSON response.
final class OllamaProcessingEngine: LLMProcessingProvider {
    static let shared = OllamaProcessingEngine()

    private let baseURL = URL(string: "http://localhost:11434")!
    private let model: String
    private let timeoutSeconds: TimeInterval

    /// Placeholder system prompt -- Phase 5 will tune formatting rules.
    private let systemPrompt = "You are a transcription cleanup engine. Fix punctuation and capitalisation. Return ONLY the cleaned text. No explanation, no preamble, no quotes."

    init(model: String = "llama3.2", timeout: TimeInterval = 60) {
        self.model = model
        self.timeoutSeconds = timeout
    }

    func process(_ text: String) async throws -> String {
        let url = baseURL.appendingPathComponent("api/chat")

        let request = OllamaChatRequest(
            model: model,
            messages: [
                OllamaMessage(role: "system", content: systemPrompt),
                OllamaMessage(role: "user", content: text)
            ],
            stream: false
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = timeoutSeconds

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw OllamaError.httpError(httpResponse.statusCode)
        }

        let chatResponse = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        let output = chatResponse.message.content.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !output.isEmpty else {
            throw OllamaError.emptyOutput
        }

        // Output length guard: reject suspiciously long responses
        if output.count > text.count * 3 && output.count > 200 {
            NSLog("[OptionC] Output length suspect: input=%d, output=%d", text.count, output.count)
            throw OllamaError.outputLengthSuspect
        }

        return output
    }
}

// MARK: - Codable Models

private struct OllamaChatRequest: Encodable {
    let model: String
    let messages: [OllamaMessage]
    let stream: Bool
}

private struct OllamaMessage: Codable {
    let role: String
    let content: String
}

private struct OllamaChatResponse: Decodable {
    let message: OllamaMessage
    let done: Bool
}
