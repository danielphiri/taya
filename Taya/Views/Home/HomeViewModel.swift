//
//  HomeViewModel.swift
//  Taya
//
//  Main screen state and workflow orchestration.
//
//  Responsibilities:
//  - Load persisted cards when the home screen first appears
//  - Request audio permissions only when the user tries to record
//  - Create and update in-progress memory cards for the UI
//  - Manage one live audio capture session at a time
//  - Track in-flight recording and LLM tasks explicitly for cleanup and testing
//  - Send completed transcripts to the injected LLM client without blocking the next capture
//  - Persist card mutations through the injected store boundary
//
//  Architecture notes:
//  - `HomeViewModel` is `@MainActor` because it owns UI-facing state.
//  - Audio capture, LLM access, and persistence are injected behind protocols to
//    keep the workflow testable without hardware, network, or disk.
//  - There is only one active recording session at a time, but multiple LLM tasks can
//    be in flight concurrently after a user finishes back-to-back captures.
//  - Each background unit of work is stored explicitly so the view can cancel it during
//    teardown and tests can observe state transitions deterministically.
//

import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    // MARK: - View State
    var cards: [MemoryCard] = []
    var isRecording = false
    var currentAudioLevel: CGFloat = 0.0
    var liveTranscript = ""
    var permissionsGranted = false
    var errorMessage: String?
    var processingCount: Int {
        llmTasksByCaptureID.count
    }

    // MARK: - Dependencies
    private let persistence: any MemoryCardStore
    private let audioClient: any AudioCaptureClient
    private let llmClient: any LLMClient

    // MARK: - Recording State
    private var audioSession: (any AudioCaptureSession)?
    private var currentCaptureId: UUID?
    private var audioLevelTask: Task<Void, Never>?
    private var transcriptTask: Task<Void, Never>?
    private var recordingTask: Task<Void, Never>?
    private var llmTasksByCaptureID: [UUID: Task<Void, Never>] = [:]
    private var hasLoadedPersistedCards = false

    // MARK: - Initialization
    /// Creates the home screen model with injected service boundaries.
    init(
        persistence: any MemoryCardStore = DiskMemoryCardStore.shared,
        audioClient: any AudioCaptureClient = LiveAudioCaptureClient(),
        llmClient: any LLMClient = OpenAILLMClient()
    ) {
        self.persistence = persistence
        self.audioClient = audioClient
        self.llmClient = llmClient
    }
}

// MARK: - Persistence

extension HomeViewModel {
    func cancelAllWork() {
        cancelActiveCapture()
        cancelAllLLMTasks()
    }

    func loadPersistedCardsIfNeeded() async {
        guard !hasLoadedPersistedCards else { return }
        hasLoadedPersistedCards = true
        await loadPersistedCards()
    }

    func loadPersistedCards() async {
        do {
            cards = try await persistence.loadCards()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persistCard(_ card: MemoryCard) async {
        do {
            try await persistence.save(card: card)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Permissions

extension HomeViewModel {
    func requestPermissions() async {
        let result = await audioClient.requestPermissions()
        switch result {
        case .success:
            permissionsGranted = true
        case .failure(let error):
            permissionsGranted = false
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Recording

extension HomeViewModel {
    func startCapture() {
        guard !isRecording else { return }

        let card = createRecordingCard()
        prepareRecordingUI()

        let session = audioClient.makeSession()
        audioSession = session

        bindAudioStreams(from: session)
        beginRecording(for: card, using: session)
    }

    func stopCapture() {
        guard isRecording else { return }

        audioSession?.stopRecording()
        stopStreamingAudioUpdates()

        isRecording = false
        currentAudioLevel = 0.0
        markCurrentCardAsTranscribing()

        currentCaptureId = nil
        audioSession = nil
    }

    private func createRecordingCard() -> MemoryCard {
        let card = MemoryCard(state: .recording)
        currentCaptureId = card.id
        cards.insert(card, at: 0)
        return card
    }

    private func prepareRecordingUI() {
        isRecording = true
        liveTranscript = ""
        errorMessage = nil
        currentAudioLevel = 0.0
    }

    private func bindAudioStreams(from session: any AudioCaptureSession) {
        stopStreamingAudioUpdates()

        audioLevelTask = Task { [weak self] in
            guard let self else { return }
            for await audioLevel in session.audioLevelStream {
                if Task.isCancelled { break }
                currentAudioLevel = audioLevel
            }
        }

        transcriptTask = Task { [weak self] in
            guard let self else { return }
            for await transcript in session.liveTranscriptStream {
                if Task.isCancelled { break }
                liveTranscript = transcript
            }
        }
    }

    private func beginRecording(
        for card: MemoryCard,
        using session: any AudioCaptureSession
    ) {
        let captureId = card.id

        recordingTask = Task { [weak self] in
            guard let self else { return }

            do {
                let result = try await session.startRecording()
                guard !Task.isCancelled else { return }
                await handleRecordingCompleted(captureId: captureId, transcript: result.transcript)
            } catch {
                if error is CancellationError {
                    return
                }

                await handleRecordingFailed(captureId: captureId, error: error)
            }

            clearRecordingTaskIfNeeded(for: captureId)
        }
    }

    private func stopStreamingAudioUpdates() {
        audioLevelTask?.cancel()
        transcriptTask?.cancel()
        audioLevelTask = nil
        transcriptTask = nil
    }

    private func markCurrentCardAsTranscribing() {
        guard let captureId = currentCaptureId,
              let index = indexOfCard(withId: captureId) else { return }

        cards[index].state = .transcribing
    }

    private func clearRecordingTaskIfNeeded(for captureId: UUID) {
        guard currentCaptureId != captureId else { return }
        recordingTask = nil
    }

    private func cancelActiveCaptureIfNeeded(for captureId: UUID) {
        guard currentCaptureId == captureId else { return }
        cancelActiveCapture()
    }

    private func cancelActiveCapture() {
        audioSession?.cancel()
        recordingTask?.cancel()
        recordingTask = nil
        stopStreamingAudioUpdates()
        currentCaptureId = nil
        audioSession = nil
        isRecording = false
        currentAudioLevel = 0.0
        liveTranscript = ""
    }
}

// MARK: - Recording Results

extension HomeViewModel {
    private func handleRecordingCompleted(captureId: UUID, transcript: String) async {
        recordingTask = nil

        guard let index = indexOfCard(withId: captureId) else { return }

        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            cards[index].state = .failed("No speech detected. Try again.")
            await persistCard(cards[index])
            return
        }

        cards[index].transcript = transcript
        cards[index].state = .processing
        await persistCard(cards[index])

        enqueueLLMRequest(for: captureId, transcript: transcript)
    }

    private func handleRecordingFailed(captureId: UUID, error: Error) async {
        recordingTask = nil

        guard let index = indexOfCard(withId: captureId) else { return }

        cards[index].state = .failed(error.localizedDescription)
        await persistCard(cards[index])
    }
}

// MARK: - LLM Processing

extension HomeViewModel {
    private func enqueueLLMRequest(for captureId: UUID, transcript: String) {
        llmTasksByCaptureID[captureId]?.cancel()
        llmTasksByCaptureID[captureId] = Task(priority: .userInitiated) { [weak self, llmClient] in
            do {
                let output = try await llmClient.processTranscript(transcript)
                guard !Task.isCancelled else { return }
                self?.handleLLMSuccess(captureId: captureId, output: output)
            } catch {
                if error is CancellationError {
                    self?.finishLLMTask(for: captureId)
                    return
                }

                self?.handleLLMFailure(captureId: captureId, error: error)
            }
        }
    }

    private func handleLLMSuccess(captureId: UUID, output: LLMOutput) {
        guard let index = indexOfCard(withId: captureId) else { return }

        cards[index].result = output
        cards[index].state = .completed
        finishLLMTask(for: captureId)

        Task {
            await persistCard(cards[index])
        }
    }

    private func handleLLMFailure(captureId: UUID, error: Error) {
        guard let index = indexOfCard(withId: captureId) else { return }

        cards[index].state = .failed(error.localizedDescription)
        finishLLMTask(for: captureId)

        Task {
            await persistCard(cards[index])
        }
    }

    private func finishLLMTask(for captureId: UUID) {
        llmTasksByCaptureID[captureId] = nil
    }

    private func cancelLLMTask(for captureId: UUID) {
        llmTasksByCaptureID[captureId]?.cancel()
        llmTasksByCaptureID[captureId] = nil
    }

    private func cancelAllLLMTasks() {
        for captureId in llmTasksByCaptureID.keys {
            llmTasksByCaptureID[captureId]?.cancel()
        }
        llmTasksByCaptureID.removeAll()
    }
}

// MARK: - Card Management

extension HomeViewModel {
    func deleteCard(_ card: MemoryCard) {
        cancelActiveCaptureIfNeeded(for: card.id)
        cancelLLMTask(for: card.id)
        cards.removeAll { $0.id == card.id }

        Task {
            do {
                try await persistence.delete(cardId: card.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func retryCard(_ card: MemoryCard) {
        guard let index = indexOfCard(withId: card.id) else { return }
        let transcript = cards[index].transcript

        guard !transcript.isEmpty else {
            cards[index].state = .failed("No transcript to retry.")
            return
        }

        cards[index].state = .processing
        cards[index].result = nil
        enqueueLLMRequest(for: card.id, transcript: transcript)
    }
}

// MARK: - Utilities

extension HomeViewModel {
    private func indexOfCard(withId id: UUID) -> Int? {
        cards.firstIndex(where: { $0.id == id })
    }
}
