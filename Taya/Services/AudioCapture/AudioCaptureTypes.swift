//
//  AudioCaptureTypes.swift
//  Taya
//
//  Shared audio capture contracts and value types.
//

import Foundation
import CoreGraphics

/// Errors specific to audio capture.
enum AudioCaptureError: Error, LocalizedError {
    case microphonePermissionDenied
    case speechPermissionDenied
    case recognizerUnavailable
    case audioEngineFailure(String)

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required to record voice memories."
        case .speechPermissionDenied:
            return "Speech recognition permission is required."
        case .recognizerUnavailable:
            return "Speech recognizer is not available on this device."
        case .audioEngineFailure(let message):
            return "Audio engine error: \(message)"
        }
    }
}

/// Result of a completed recording session.
struct RecordingResult {
    let transcript: String
    let duration: TimeInterval
}

@MainActor
/// A single record/transcribe session that streams live UI updates via `AsyncStream`.
protocol AudioCaptureSession: AnyObject {
    var liveTranscriptStream: AsyncStream<String> { get }
    var audioLevelStream: AsyncStream<CGFloat> { get }

    func startRecording() async throws -> RecordingResult
    func stopRecording()
    func cancel()
}

/// Factory-style boundary for permissions and per-capture session creation.
protocol AudioCaptureClient: Sendable {
    @MainActor func makeSession() -> any AudioCaptureSession
    func requestPermissions() async -> Result<Void, AudioCaptureError>
}

/// Boundary for requesting system audio-related permissions.
protocol AudioCapturePermissionRequesting: Sendable {
    func requestPermissions() async -> Result<Void, AudioCaptureError>
}
