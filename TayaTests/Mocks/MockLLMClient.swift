import Foundation
@testable import Taya

actor MockLLMClient: LLMClient {
    enum Behavior {
        case immediate(Result<LLMOutput, Error>)
        case manual
    }

    private let behavior: Behavior
    private(set) var requestedTranscripts: [String] = []
    private var pendingRequests: [(id: UUID, continuation: CheckedContinuation<LLMOutput, Error>)] = []

    init(result: Result<LLMOutput, Error>) {
        self.behavior = .immediate(result)
    }

    init() {
        self.behavior = .manual
    }

    func processTranscript(_ transcript: String) async throws -> LLMOutput {
        requestedTranscripts.append(transcript)

        switch behavior {
        case .immediate(let result):
            return try result.get()
        case .manual:
            let requestID = UUID()

            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    pendingRequests.append((id: requestID, continuation: continuation))
                }
            } onCancel: {
                Task {
                    await cancelRequest(withID: requestID)
                }
            }
        }
    }

    func succeedNext(with output: LLMOutput) {
        guard !pendingRequests.isEmpty else { return }
        pendingRequests.removeFirst().continuation.resume(returning: output)
    }

    func failNext(with error: Error) {
        guard !pendingRequests.isEmpty else { return }
        pendingRequests.removeFirst().continuation.resume(throwing: error)
    }

    func requestedTranscriptsSnapshot() -> [String] {
        requestedTranscripts
    }

    func pendingRequestCount() -> Int {
        pendingRequests.count
    }

    func cancelAllPendingRequests() {
        let requests = pendingRequests
        pendingRequests.removeAll()

        for request in requests {
            request.continuation.resume(throwing: CancellationError())
        }
    }

    private func cancelRequest(withID requestID: UUID) {
        guard let index = pendingRequests.firstIndex(where: { $0.id == requestID }) else { return }
        let request = pendingRequests.remove(at: index)
        request.continuation.resume(throwing: CancellationError())
    }
}
