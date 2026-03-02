import Foundation

/// Abstraction over any LLM post-processing backend.
/// OllamaProcessingEngine conforms today. A future AnthropicProcessingEngine
/// conforms without touching AppState.
protocol LLMProcessingProvider {
    func process(_ text: String) async throws -> String
}
