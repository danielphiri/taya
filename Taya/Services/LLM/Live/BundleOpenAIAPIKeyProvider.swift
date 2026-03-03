//
//  BundleOpenAIAPIKeyProvider.swift
//  Taya
//
//  Production API key provider backed by the app bundle.
//

import Foundation

struct BundleOpenAIAPIKeyProvider: OpenAIAPIKeyProviding {
    func apiKey() throws -> String {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
              !apiKey.isEmpty else {
            throw LLMError.apiKeyMissing
        }

        return apiKey
    }
}
