import Foundation
@testable import Taya

@MainActor
final class MockAudioCaptureSession: AudioCaptureSession {
    let result: Result<RecordingResult, Error>
    private(set) var didStopRecording = false
    let liveTranscriptStream: AsyncStream<String>
    let audioLevelStream: AsyncStream<CGFloat>
    private var liveTranscriptContinuation: AsyncStream<String>.Continuation?
    private var audioLevelContinuation: AsyncStream<CGFloat>.Continuation?

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
        return try result.get()
    }

    func stopRecording() {
        didStopRecording = true
        audioLevelContinuation?.yield(0)
    }

    func cancel() {}
}

@MainActor
final class MockAudioCaptureClient: AudioCaptureClient {
    let permissionResult: Result<Void, AudioCaptureError>
    let session: any AudioCaptureSession

    init(
        permissionResult: Result<Void, AudioCaptureError>,
        session: any AudioCaptureSession
    ) {
        self.permissionResult = permissionResult
        self.session = session
    }

    func makeSession() -> any AudioCaptureSession {
        session
    }

    func requestPermissions() async -> Result<Void, AudioCaptureError> {
        permissionResult
    }
}
