import Foundation
@testable import Taya

@MainActor
final class MockAudioCaptureSession: AudioCaptureSession {
    private let result: Result<RecordingResult, Error>
    private(set) var didStopRecording = false
    let liveTranscriptStream: AsyncStream<String>
    let audioLevelStream: AsyncStream<CGFloat>
    private var liveTranscriptContinuation: AsyncStream<String>.Continuation?
    private var audioLevelContinuation: AsyncStream<CGFloat>.Continuation?
    private var recordingContinuation: CheckedContinuation<RecordingResult, Error>?

    init(result: Result<RecordingResult, Error>) {
        self.result = result

        var liveTranscriptContinuation: AsyncStream<String>.Continuation?
        liveTranscriptStream = AsyncStream { continuation in
            liveTranscriptContinuation = continuation
        }
        self.liveTranscriptContinuation = liveTranscriptContinuation

        var audioLevelContinuation: AsyncStream<CGFloat>.Continuation?
        audioLevelStream = AsyncStream { continuation in
            audioLevelContinuation = continuation
        }
        self.audioLevelContinuation = audioLevelContinuation
    }

    func startRecording() async throws -> RecordingResult {
        liveTranscriptContinuation?.yield("partial transcript")
        audioLevelContinuation?.yield(0.6)

        return try await withCheckedThrowingContinuation { continuation in
            recordingContinuation = continuation
        }
    }

    func stopRecording() {
        didStopRecording = true
        audioLevelContinuation?.yield(0)
        completeRecording()
    }

    func cancel() {
        completeRecording()
    }

    func isAwaitingStop() -> Bool {
        recordingContinuation != nil
    }

    private func completeRecording() {
        guard let recordingContinuation else { return }
        self.recordingContinuation = nil

        switch result {
        case .success(let recordingResult):
            recordingContinuation.resume(returning: recordingResult)
        case .failure(let error):
            recordingContinuation.resume(throwing: error)
        }
    }
}

@MainActor
final class MockAudioCaptureClient: AudioCaptureClient {
    let permissionResult: Result<Void, AudioCaptureError>
    private var sessions: [any AudioCaptureSession]

    init(
        permissionResult: Result<Void, AudioCaptureError>,
        sessions: [any AudioCaptureSession]
    ) {
        self.permissionResult = permissionResult
        self.sessions = sessions
    }

    func makeSession() -> any AudioCaptureSession {
        guard !sessions.isEmpty else {
            fatalError("No mock audio sessions are available.")
        }

        return sessions.removeFirst()
    }

    func requestPermissions() async -> Result<Void, AudioCaptureError> {
        permissionResult
    }
}
