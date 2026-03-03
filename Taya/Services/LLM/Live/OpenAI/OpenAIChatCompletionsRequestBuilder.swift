//
//  OpenAIChatCompletionsRequestBuilder.swift
//  Taya
//
//  Builds OpenAI chat completions requests for transcript processing.
//

import Foundation

struct OpenAIChatCompletionsRequestBuilder: OpenAIChatCompletionsRequestBuilding {
    private static let endpoint = "https://api.openai.com/v1/chat/completions"

    // The system prompt that instructs the LLM how to process transcripts.
    private let systemPrompt = """
    You are a voice memory processor for an app called Taya. Users record short voice memos throughout their day — while walking, in bed, at the store. Your job is to turn messy, spoken transcripts into clean, structured memory cards.

    Rules:
    1. The transcript will contain filler words (um, uh, like, so, yeah), false starts, and topic jumps. This is normal. Parse through the noise.
    2. If the transcript contains multiple distinct topics, synthesize them into ONE card. The title should capture the dominant theme or use a compound summary.
    3. Action items are things the user explicitly or implicitly wants to DO. "I need to get eggs" → action item. "She mentioned a book" → action item (look it up). "Remind me to send the deck" → action item.
    4. Category must be exactly one of: Shopping, Learning, Meeting, People, Other. Pick the best fit. If mixed, pick the dominant one.
    5. Mood should be a brief sentiment descriptor: "focused", "scattered but productive", "relaxed", "anxious", "energetic", etc.

    You MUST respond with ONLY valid JSON, no markdown, no code fences, no explanation. The JSON must match this exact schema:
    {
      "title": "short, specific summary (max 8 words)",
      "category": "Shopping | Learning | Meeting | People | Other",
      "action_items": ["specific", "actionable", "tasks"],
      "mood": "sentiment string"
    }
    """

    func makeRequest(apiKey: String, transcript: String) throws -> URLRequest {
        guard let url = URL(string: Self.endpoint) else {
            throw LLMError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody(for: transcript))

        return request
    }

    private func requestBody(for transcript: String) -> [String: Any] {
        [
            "model": "gpt-4o-mini",
            "temperature": 0.3,
            "max_tokens": 300,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "Transcript:\n\"\(transcript)\""]
            ]
        ]
    }
}
