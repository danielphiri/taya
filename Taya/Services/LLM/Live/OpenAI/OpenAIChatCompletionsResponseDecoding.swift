//
//  OpenAIChatCompletionsResponseDecoding.swift
//  Taya
//
//  Contracts for decoding OpenAI chat completion responses.
//

import Foundation

protocol OpenAIChatCompletionsResponseDecoding: Sendable {
    func decode(data: Data, response: HTTPURLResponse) throws -> LLMOutput
}
