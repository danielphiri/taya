//
//  OpenAIChatCompletionsRequestBuilding.swift
//  Taya
//
//  Contracts for building OpenAI chat completion requests.
//

import Foundation

protocol OpenAIChatCompletionsRequestBuilding: Sendable {
    func makeRequest(apiKey: String, transcript: String) throws -> URLRequest
}
