import Foundation

/// Errors specific to Ollama HTTP communication and response validation.
enum OllamaError: Error {
    case invalidResponse
    case httpError(Int)
    case emptyOutput
    case outputLengthSuspect
}

/// Status returned by OllamaProcessingEngine availability check.
enum OllamaAvailabilityStatus {
    case available
    case ollamaNotRunning
    case modelNotFound(configured: String)
}

/// Concrete LLM provider that calls Ollama's /api/chat endpoint via URLSession.
/// Uses non-streaming mode (stream: false) to receive a single JSON response.
final class OllamaProcessingEngine: LLMProcessingProvider {
    private let baseURL = URL(string: "http://localhost:11434")!
    private let model: String
    private let timeoutSeconds: TimeInterval

    /// System prompt — simplified for reliable results on small local models.
    private static let systemPrompt = """
        You clean transcribed speech. Apply these rules and output ONLY the cleaned text.

        Rules:
        1. Add missing punctuation (commas, full stops, question marks).
        2. Capitalise sentence starts and proper nouns only.
        3. Remove filler words: um, uh, er.
        4. Use British English spelling.
        5. Do NOT rephrase or add words. Keep the speaker's exact wording.
        6. Output ONLY the cleaned text. No preamble, no explanation.
        """

    init(model: String = "llama3.1:8b", timeout: TimeInterval = 60) {
        self.model = model
        self.timeoutSeconds = timeout
    }

    func process(_ text: String) async throws -> String {
        let url = baseURL.appendingPathComponent("api/chat")

        let request = OllamaChatRequest(
            model: model,
            messages: [
                OllamaMessage(role: "system", content: Self.systemPrompt),
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

    /// Check whether Ollama is running and the configured model is available.
    /// Uses a 5-second timeout (not the 60-second chat timeout).
    func checkAvailability() async -> OllamaAvailabilityStatus {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/tags"))
        request.timeoutInterval = 5  // Short timeout for health check

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return .ollamaNotRunning
            }
            let tagsResponse = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)

            // Normalise model names: /api/tags returns "llama3.2:latest", configured may be "llama3.2"
            let installedBaseNames = tagsResponse.models.map { modelInfo -> String in
                let components = modelInfo.name.split(separator: ":")
                return components.first.map(String.init) ?? modelInfo.name
            }
            let configuredBase = model.split(separator: ":").first.map(String.init) ?? model

            if installedBaseNames.contains(configuredBase) {
                return .available
            } else {
                return .modelNotFound(configured: model)
            }
        } catch {
            // URLError.cannotConnectToHost when Ollama is not running, or any other network error
            return .ollamaNotRunning
        }
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

private struct OllamaTagsResponse: Decodable {
    let models: [OllamaModelInfo]
}

private struct OllamaModelInfo: Decodable {
    let name: String
}
