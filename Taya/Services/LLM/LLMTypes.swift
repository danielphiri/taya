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

/// App-facing boundary for sending transcripts to an LLM backend.
protocol LLMClient: Sendable {
    func processTranscript(_ transcript: String) async throws -> LLMOutput
}

/// Boundary for loading the configured OpenAI API key.
protocol OpenAIAPIKeyProviding: Sendable {
    func apiKey() throws -> String
}
