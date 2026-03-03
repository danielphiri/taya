//
//  LLMTypes.swift
//  Taya
//
//  Shared LLM contracts and error types.
//

import Foundation

/// Errors surfaced by the LLM layer when network or parsing work fails.
enum LLMError: Error, LocalizedError {
    case apiKeyMissing
    case networkError(String)
    case invalidResponse
    case parseError(String)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "OpenAI API key is not configured."
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from LLM."
        case .parseError(let message):
            return "Failed to parse LLM output: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

/// App-facing transcript processing boundary used by the view model and tests.
protocol LLMProcessing: Sendable {
    func processTranscript(_ transcript: String) async throws -> LLMOutput
}

/// Boundary for loading the configured OpenAI API key.
protocol OpenAIAPIKeyProviding: Sendable {
    func apiKey() throws -> String
}

/// Boundary for executing HTTP requests for LLM processing.
protocol LLMRequestPerforming: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}
