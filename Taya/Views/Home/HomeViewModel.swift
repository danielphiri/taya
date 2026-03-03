//
//  CaptureEngine.swift
//  Taya
//
//  The concurrency backbone of the app.
//
//  Design decision: CaptureEngine is an @MainActor ObservableObject that
//  owns the published cards array for SwiftUI binding. The actual LLM
//  processing happens in detached Tasks — fire-and-forget background work
//  that writes results back through the engine.
//
//  Why this works for back-to-back captures:
//  - Each recording session creates a NEW MemoryCard with a unique ID immediately
//  - The card is inserted into the UI in .transcribing/.processing state
//  - LLM processing runs in a background Task that captures only the card ID
//  - When the user taps record again, a new card + new Task is created
//  - There is NO shared mutable state between concurrent captures
//  - Each Task independently updates its own card via the actor-isolated PersistenceService
//
//  Scaling to 5+ simultaneous captures: each capture is an independent Task
//  with its own card ID. The only shared resource is the audio hardware
//  (one recording at a time), but LLM calls are fully concurrent.
//

import Foundation
import Combine

@MainActor
final class CaptureEngine: ObservableObject {
    
    // MARK: - Published state
    @Published var cards: [MemoryCard] = []
    @Published var isRecording = false
    @Published var currentAudioLevel: CGFloat = 0.0
    @Published var liveTranscript: String = ""
    @Published var permissionsGranted = false
    @Published var errorMessage: String?
    @Published var processingCount: Int = 0  // number of in-flight LLM calls
    
    // MARK: - Dependencies
    private var audioService: AudioCaptureService?
    private let llmService = LLMService.shared
    private let persistence = PersistenceService.shared
    
    // Track the current recording's card ID
    private var currentCaptureId: UUID?
    private var audioLevelCancellable: AnyCancellable?
    private var transcriptCancellable: AnyCancellable?
    
    // MARK: - Initialization
    
    init() {
        Task {
            await loadPersistedCards()
        }
    }
    
    func loadPersistedCards() async {
        let loaded = await persistence.loadCards()
        self.cards = loaded
    }
    
    // MARK: - Permissions
    
    func requestPermissions() async {
        let result = await AudioCaptureService.requestPermissions()
        switch result {
        case .success:
            permissionsGranted = true
        case .failure(let error):
            permissionsGranted = false
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Recording
    
    func startCapture() {
        guard !isRecording else { return }
        
        // Create a new card immediately — user sees it appear in the list
        let card = MemoryCard(state: .recording)
        currentCaptureId = card.id
        cards.insert(card, at: 0)
        
        isRecording = true
        liveTranscript = ""
        errorMessage = nil
        
        // Create a fresh audio service for this capture
        let audio = AudioCaptureService()
        self.audioService = audio
        
        // Bind audio level and transcript for UI
        audioLevelCancellable = audio.$audioLevel
            .receive(on: RunLoop.main)
            .assign(to: \.currentAudioLevel, on: self)
        
        transcriptCancellable = audio.$liveTranscript
            .receive(on: RunLoop.main)
            .assign(to: \.liveTranscript, on: self)
        
        // Start recording in a Task — the result comes back when stopCapture() is called
        let captureId = card.id
        Task {
            do {
                let result = try await audio.startRecording()
                // Recording finished (stopRecording was called), now process
                await self.handleRecordingCompleted(captureId: captureId, transcript: result.transcript)
            } catch {
                await self.handleRecordingFailed(captureId: captureId, error: error)
            }
        }
    }
    
    func stopCapture() {
        guard isRecording else { return }
        
        audioService?.stopRecording()
        audioLevelCancellable = nil
        transcriptCancellable = nil
        isRecording = false
        currentAudioLevel = 0.0
        
        // Update card state to transcribing
        if let id = currentCaptureId, let idx = cards.firstIndex(where: { $0.id == id }) {
            cards[idx].state = .transcribing
        }
        
        currentCaptureId = nil
        audioService = nil
    }
    
    // MARK: - Processing pipeline
    
    /// Called when recording + transcription is done. Fires off LLM processing.
    private func handleRecordingCompleted(captureId: UUID, transcript: String) async {
        guard let idx = cards.firstIndex(where: { $0.id == captureId }) else { return }
        
        // If transcript is empty, mark as failed
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            cards[idx].state = .failed("No speech detected. Try again.")
            await persistence.save(card: cards[idx])
            return
        }
        
        // Update card with transcript and move to processing state
        cards[idx].transcript = transcript
        cards[idx].state = .processing
        await persistence.save(card: cards[idx])
        
        // Fire off LLM processing — this is the key concurrency moment.
        // This Task runs independently. The user can start a new recording
        // while this is in flight. Each Task captures only its captureId.
        processingCount += 1
        
        Task.detached { [llmService] in
            do {
                let output = try await llmService.processTranscript(transcript)
                await MainActor.run { [weak self] in
                    self?.handleLLMSuccess(captureId: captureId, output: output)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.handleLLMFailure(captureId: captureId, error: error)
                }
            }
        }
    }
    
    private func handleRecordingFailed(captureId: UUID, error: Error) async {
        guard let idx = cards.firstIndex(where: { $0.id == captureId }) else { return }
        cards[idx].state = .failed(error.localizedDescription)
        await persistence.save(card: cards[idx])
    }
    
    private func handleLLMSuccess(captureId: UUID, output: LLMOutput) {
        guard let idx = cards.firstIndex(where: { $0.id == captureId }) else { return }
        cards[idx].result = output
        cards[idx].state = .completed
        processingCount -= 1
        
        Task {
            await persistence.save(card: cards[idx])
        }
    }
    
    private func handleLLMFailure(captureId: UUID, error: Error) {
        guard let idx = cards.firstIndex(where: { $0.id == captureId }) else { return }
        cards[idx].state = .failed(error.localizedDescription)
        processingCount -= 1
        
        Task {
            await persistence.save(card: cards[idx])
        }
    }
    
    // MARK: - Card management
    
    func deleteCard(_ card: MemoryCard) {
        cards.removeAll { $0.id == card.id }
        Task {
            await persistence.delete(cardId: card.id)
        }
    }
    
    func retryCard(_ card: MemoryCard) {
        guard let idx = cards.firstIndex(where: { $0.id == card.id }) else { return }
        let transcript = cards[idx].transcript
        
        guard !transcript.isEmpty else {
            cards[idx].state = .failed("No transcript to retry.")
            return
        }
        
        cards[idx].state = .processing
        cards[idx].result = nil
        processingCount += 1
        
        let captureId = card.id
        Task.detached { [llmService] in
            do {
                let output = try await llmService.processTranscript(transcript)
                await MainActor.run { [weak self] in
                    self?.handleLLMSuccess(captureId: captureId, output: output)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.handleLLMFailure(captureId: captureId, error: error)
                }
            }
        }
    }
}
