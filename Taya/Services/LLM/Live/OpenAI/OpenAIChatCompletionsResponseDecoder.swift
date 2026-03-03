//
//  OpenAIChatCompletionsResponseDecoder.swift
//  Taya
//
//  Decodes OpenAI chat completion responses into `LLMOutput`.
//

import Foundation

struct OpenAIChatCompletionsResponseDecoder: OpenAIChatCompletionsResponseDecoding {
    func decode(data: Data, response: HTTPURLResponse) throws -> LLMOutput {
        guard (200...299).contains(response.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.serverError("Status \(response.statusCode): \(errorBody)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.invalidResponse
        }

        let cleanedContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleanedContent.data(using: .utf8) else {
            throw LLMError.parseError("Could not encode LLM content as data")
        }

        do {
            return try JSONDecoder().decode(LLMOutput.self, from: jsonData)
        } catch {
            throw LLMError.parseError(
                "JSON decode failed: \(error.localizedDescription). Raw: \(cleanedContent)"
            )
        }
    }
}
