//
//  OpenAILLMClient.swift
//  Taya
//
//  OpenAI-backed implementation of the LLM client boundary.
//

import Foundation

/// OpenAI-backed implementation of `LLMClient`.
struct OpenAILLMClient: LLMClient {
    private let apiKeyProvider: any OpenAIAPIKeyProviding
    private let networkClient: any NetworkClient
    private let requestBuilder: any OpenAIChatCompletionsRequestBuilding
    private let responseDecoder: any OpenAIChatCompletionsResponseDecoding

    init(
        apiKeyProvider: any OpenAIAPIKeyProviding = BundleOpenAIAPIKeyProvider(),
        networkClient: any NetworkClient = URLSessionNetworkClient(),
        requestBuilder: any OpenAIChatCompletionsRequestBuilding = OpenAIChatCompletionsRequestBuilder(),
        responseDecoder: any OpenAIChatCompletionsResponseDecoding = OpenAIChatCompletionsResponseDecoder()
    ) {
        self.apiKeyProvider = apiKeyProvider
        self.networkClient = networkClient
        self.requestBuilder = requestBuilder
        self.responseDecoder = responseDecoder
    }

    func processTranscript(_ transcript: String) async throws -> LLMOutput {
        let apiKey = try apiKeyProvider.apiKey()
        let request = try requestBuilder.makeRequest(apiKey: apiKey, transcript: transcript)

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await networkClient.data(for: request)
        } catch {
            throw LLMError.networkError(error.localizedDescription)
        }

        return try responseDecoder.decode(data: data, response: response)
    }
}
