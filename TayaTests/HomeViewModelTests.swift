import Testing
@testable import Taya

struct HomeViewModelTests {
    @MainActor
    @Test func loadsCardsFromInjectedPersistence() async throws {
        let expectedCard = MemoryCard(transcript: "Remember this", state: .completed)
        let persistence = MockMemoryCardStore(cards: [expectedCard])
        let viewModel = HomeViewModel(persistence: persistence)

        await viewModel.loadPersistedCards()

        #expect(viewModel.cards == [expectedCard])
    }

    @MainActor
    @Test func processesCaptureWithInjectedAudioAndLLM() async throws {
        let persistence = MockMemoryCardStore()
        let audioSession = MockAudioCaptureSession(
            result: .success(RecordingResult(transcript: "Buy milk and eggs", duration: 3))
        )
        let audioClient = MockAudioCaptureClient(
            permissionResult: .success(()),
            makeSessionHandler: { audioSession }
        )
        let llmService = MockLLMService(
            result: .success(
                LLMOutput(
                    title: "Groceries",
                    category: "Shopping",
                    actionItems: ["Buy milk", "Buy eggs"],
                    mood: "focused"
                )
            )
        )
        let viewModel = HomeViewModel(
            persistence: persistence,
            audioClient: audioClient,
            llmService: llmService
        )

        viewModel.permissionsGranted = true
        viewModel.startCapture()

        for _ in 0..<10 {
            await Task.yield()
        }

        #expect(viewModel.cards.count == 1)
        #expect(viewModel.cards[0].transcript == "Buy milk and eggs")
        #expect(viewModel.cards[0].result?.title == "Groceries")
        #expect(viewModel.cards[0].state == .completed)
        #expect(viewModel.processingCount == 0)
    }
}
