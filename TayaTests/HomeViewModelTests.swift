import Foundation
import Testing
@testable import Taya

@MainActor
struct HomeViewModelTests {
    @Test
    func supportsBackToBackCapturesWhileEarlierLLMWorkRemainsInFlight() async throws {
        let store = MockMemoryCardStore()
        let firstSession = MockAudioCaptureSession(
            result: .success(RecordingResult(transcript: "first capture", duration: 12))
        )
        let secondSession = MockAudioCaptureSession(
            result: .success(RecordingResult(transcript: "second capture", duration: 18))
        )
        let audioClient = MockAudioCaptureClient(
            permissionResult: .success(()),
            sessions: [firstSession, secondSession]
        )
        let llmClient = MockLLMClient()
        let viewModel = HomeViewModel(
            persistence: store,
            audioClient: audioClient,
            llmClient: llmClient
        )

        await viewModel.loadPersistedCards()

        viewModel.startCapture()
        try await waitUntil("first capture starts") {
            firstSession.isAwaitingStop()
        }
        viewModel.stopCapture()

        try await waitUntil("first card enters processing") {
            let requestedTranscripts = await llmClient.requestedTranscriptsSnapshot()
            let firstCard = card(withTranscript: "first capture", in: viewModel.cards)

            return viewModel.processingCount == 1 &&
                requestedTranscripts == ["first capture"] &&
                firstCard?.state == .processing
        }

        viewModel.startCapture()
        try await waitUntil("second capture starts") {
            secondSession.isAwaitingStop()
        }
        viewModel.stopCapture()

        try await waitUntil("second card enters processing") {
            let requestedTranscripts = await llmClient.requestedTranscriptsSnapshot()
            let firstCard = card(withTranscript: "first capture", in: viewModel.cards)
            let secondCard = card(withTranscript: "second capture", in: viewModel.cards)

            return viewModel.processingCount == 2 &&
                requestedTranscripts == ["first capture", "second capture"] &&
                firstCard?.state == .processing &&
                secondCard?.state == .processing
        }

        let firstOutput = LLMOutput(
            title: "Eggs and deck",
            category: "Shopping",
            actionItems: ["Buy eggs", "Send Marcus the deck"],
            mood: "focused"
        )
        let secondOutput = LLMOutput(
            title: "Sarah book follow-up",
            category: "Learning",
            actionItems: ["Look up The Creative Act"],
            mood: "curious"
        )

        await llmClient.succeedNext(with: firstOutput)
        await llmClient.succeedNext(with: secondOutput)

        try await waitUntil("LLM work completes") {
            viewModel.processingCount == 0 &&
            card(withTranscript: "first capture", in: viewModel.cards)?.result == firstOutput &&
            card(withTranscript: "second capture", in: viewModel.cards)?.result == secondOutput &&
            card(withTranscript: "first capture", in: viewModel.cards)?.state == .completed &&
            card(withTranscript: "second capture", in: viewModel.cards)?.state == .completed
        }

        let persistedCards = await store.allCards()
        #expect(persistedCards.count == 2)
        #expect(Set(persistedCards.map(\.transcript)) == Set(["first capture", "second capture"]))
    }

    @Test
    func cancelAllWorkStopsActiveCaptureAndClearsPendingProcessing() async throws {
        let store = MockMemoryCardStore()
        let session = MockAudioCaptureSession(
            result: .success(RecordingResult(transcript: "pending capture", duration: 10))
        )
        let audioClient = MockAudioCaptureClient(
            permissionResult: .success(()),
            sessions: [session]
        )
        let llmClient = MockLLMClient()
        let viewModel = HomeViewModel(
            persistence: store,
            audioClient: audioClient,
            llmClient: llmClient
        )

        await viewModel.loadPersistedCards()

        viewModel.startCapture()
        try await waitUntil("capture starts") {
            session.isAwaitingStop()
        }
        viewModel.stopCapture()

        try await waitUntil("LLM request starts") {
            let pendingRequestCount = await llmClient.pendingRequestCount()
            return viewModel.processingCount == 1 && pendingRequestCount == 1
        }

        viewModel.cancelAllWork()

        try await waitUntil("work cancels") {
            !viewModel.isRecording && viewModel.processingCount == 0
        }

        let persistedCards = await store.allCards()
        #expect(persistedCards.count == 1)
        #expect(persistedCards.first?.state == .processing)
    }

    @Test
    func deletingCardCancelsItsPendingLLMWorkWithoutTouchingOtherCards() async throws {
        let store = MockMemoryCardStore()
        let firstSession = MockAudioCaptureSession(
            result: .success(RecordingResult(transcript: "first capture", duration: 9))
        )
        let secondSession = MockAudioCaptureSession(
            result: .success(RecordingResult(transcript: "second capture", duration: 11))
        )
        let audioClient = MockAudioCaptureClient(
            permissionResult: .success(()),
            sessions: [firstSession, secondSession]
        )
        let llmClient = MockLLMClient()
        let viewModel = HomeViewModel(
            persistence: store,
            audioClient: audioClient,
            llmClient: llmClient
        )

        await viewModel.loadPersistedCards()

        viewModel.startCapture()
        try await waitUntil("first capture starts") {
            firstSession.isAwaitingStop()
        }
        viewModel.stopCapture()

        viewModel.startCapture()
        try await waitUntil("second capture starts") {
            secondSession.isAwaitingStop()
        }
        viewModel.stopCapture()

        try await waitUntil("both LLM requests start") {
            let pendingRequestCount = await llmClient.pendingRequestCount()
            return viewModel.processingCount == 2 && pendingRequestCount == 2
        }

        let firstCard = try #require(card(withTranscript: "first capture", in: viewModel.cards))
        viewModel.deleteCard(firstCard)

        try await waitUntil("deleted card work cancels") {
            let pendingRequestCount = await llmClient.pendingRequestCount()
            return viewModel.processingCount == 1 &&
                pendingRequestCount == 1 &&
                card(withTranscript: "first capture", in: viewModel.cards) == nil &&
                card(withTranscript: "second capture", in: viewModel.cards)?.state == .processing
        }

        let secondOutput = LLMOutput(
            title: "Second result",
            category: "Other",
            actionItems: ["Keep second capture"],
            mood: "clear"
        )
        await llmClient.succeedNext(with: secondOutput)

        try await waitUntil("remaining LLM request completes") {
            viewModel.processingCount == 0 &&
                card(withTranscript: "second capture", in: viewModel.cards)?.result == secondOutput &&
                card(withTranscript: "second capture", in: viewModel.cards)?.state == .completed
        }

        let persistedCards = await store.allCards()
        #expect(persistedCards.count == 1)
        #expect(persistedCards.first?.transcript == "second capture")
    }

    @Test
    func retryingFailedCardWhileAnotherCardIsProcessingKeepsWorkIsolated() async throws {
        let store = MockMemoryCardStore()
        let firstSession = MockAudioCaptureSession(
            result: .success(RecordingResult(transcript: "first capture", duration: 14))
        )
        let secondSession = MockAudioCaptureSession(
            result: .success(RecordingResult(transcript: "second capture", duration: 16))
        )
        let audioClient = MockAudioCaptureClient(
            permissionResult: .success(()),
            sessions: [firstSession, secondSession]
        )
        let llmClient = MockLLMClient()
        let viewModel = HomeViewModel(
            persistence: store,
            audioClient: audioClient,
            llmClient: llmClient
        )

        await viewModel.loadPersistedCards()

        viewModel.startCapture()
        try await waitUntil("first capture starts") {
            firstSession.isAwaitingStop()
        }
        viewModel.stopCapture()

        viewModel.startCapture()
        try await waitUntil("second capture starts") {
            secondSession.isAwaitingStop()
        }
        viewModel.stopCapture()

        try await waitUntil("both captures enter processing") {
            let pendingRequestCount = await llmClient.pendingRequestCount()
            return viewModel.processingCount == 2 && pendingRequestCount == 2
        }

        struct RetryFailure: LocalizedError {
            var errorDescription: String? { "Initial LLM failure" }
        }

        await llmClient.failNext(with: RetryFailure())

        try await waitUntil("first card fails while second keeps processing") {
            let pendingRequestCount = await llmClient.pendingRequestCount()
            return viewModel.processingCount == 1 &&
                card(withTranscript: "first capture", in: viewModel.cards)?.state == .failed("Initial LLM failure") &&
                card(withTranscript: "second capture", in: viewModel.cards)?.state == .processing &&
                pendingRequestCount == 1
        }

        let failedCard = try #require(card(withTranscript: "first capture", in: viewModel.cards))
        viewModel.retryCard(failedCard)

        try await waitUntil("retry starts alongside existing processing") {
            let pendingRequestCount = await llmClient.pendingRequestCount()
            let requestedTranscripts = await llmClient.requestedTranscriptsSnapshot()
            return viewModel.processingCount == 2 &&
                pendingRequestCount == 2 &&
                requestedTranscripts == ["first capture", "second capture", "first capture"] &&
                card(withTranscript: "first capture", in: viewModel.cards)?.state == .processing &&
                card(withTranscript: "second capture", in: viewModel.cards)?.state == .processing
        }

        let secondOutput = LLMOutput(
            title: "Second result",
            category: "Meeting",
            actionItems: ["Follow up on second capture"],
            mood: "calm"
        )
        let retriedFirstOutput = LLMOutput(
            title: "Retried first result",
            category: "Other",
            actionItems: ["Finish first capture"],
            mood: "resolved"
        )

        await llmClient.succeedNext(with: secondOutput)
        await llmClient.succeedNext(with: retriedFirstOutput)

        try await waitUntil("retry and existing processing both complete") {
            viewModel.processingCount == 0 &&
                card(withTranscript: "first capture", in: viewModel.cards)?.result == retriedFirstOutput &&
                card(withTranscript: "second capture", in: viewModel.cards)?.result == secondOutput &&
                card(withTranscript: "first capture", in: viewModel.cards)?.state == .completed &&
                card(withTranscript: "second capture", in: viewModel.cards)?.state == .completed
        }

        let persistedCards = await store.allCards()
        #expect(persistedCards.count == 2)
        #expect(
            persistedCards.first(where: { $0.transcript == "first capture" })?.result == retriedFirstOutput
        )
        #expect(
            persistedCards.first(where: { $0.transcript == "second capture" })?.result == secondOutput
        )
    }

    private func card(withTranscript transcript: String, in cards: [MemoryCard]) -> MemoryCard? {
        cards.first(where: { $0.transcript == transcript })
    }

    private func waitUntil(
        _ description: String,
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        condition: @escaping @MainActor () async -> Bool
    ) async throws {
        let timeout = Duration.nanoseconds(Int64(timeoutNanoseconds))
        let start = ContinuousClock.now

        while true {
            if await condition() {
                return
            }

            if start.duration(to: ContinuousClock.now) >= timeout {
                Issue.record("Timed out waiting for \(description)")
                throw TimeoutError()
            }

            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

private struct TimeoutError: Error {}
