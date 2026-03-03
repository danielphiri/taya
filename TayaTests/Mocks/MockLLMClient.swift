import Foundation
@testable import Taya

struct MockLLMClient: LLMClient {
    let result: Result<LLMOutput, Error>

    func processTranscript(_ transcript: String) async throws -> LLMOutput {
        try result.get()
    }
}
