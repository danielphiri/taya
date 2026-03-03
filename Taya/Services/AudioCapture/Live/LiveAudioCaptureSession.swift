//
//  LiveAudioCaptureSession.swift
//  Taya
//
//  AVAudioEngine + Speech-backed live audio capture session.
//

import AVFoundation
import CoreGraphics
import Foundation
import Speech

private enum AudioLevelMeter {
    private static let minimumSampleMagnitude: Float = 1e-6
    private static let silenceFloorDecibels: Float = -50
    private static let loudVoiceCeilingDecibels: Float = -6
    
    /// Converts a single live microphone buffer into a UI-friendly loudness value.
    ///
    /// This is called repeatedly during recording, once per incoming audio buffer.
    /// It reads samples from the buffer's first channel, estimates the buffer's
    /// loudness using RMS, converts that to decibels, clamps the result to a
    /// practical speech range, and normalizes it into `0...1` for the level meter.
    ///
    /// - Parameter buffer: A short chunk of live PCM audio captured from the microphone.
    /// - Returns: A normalized loudness value where `0` is silence and `1` is loud speech,
    ///   or `nil` if the buffer does not expose float channel data.
    static func normalizedLevel(from buffer: AVAudioPCMBuffer) -> CGFloat? {
        guard let channelData = buffer.floatChannelData?[0] else { return nil }
        let frames = buffer.frameLength
        
        var sumOfSquares: Float = 0
        for index in 0..<Int(frames) {
            let sample = channelData[index]
            sumOfSquares += sample * sample
        }
        
        let rootMeanSquare = sqrt(sumOfSquares / Float(frames))
        
        // Convert the raw signal into decibels so quiet and loud speech map more naturally.
        let decibelLevel = 20 * log10(max(rootMeanSquare, minimumSampleMagnitude))
        let clampedDecibelLevel = min(
            max(decibelLevel, silenceFloorDecibels),
            loudVoiceCeilingDecibels
        )
        
        // Normalize the clamped speech range into 0...1 for the UI meter.
        let normalizedRange = (clampedDecibelLevel - silenceFloorDecibels)
        / (loudVoiceCeilingDecibels - silenceFloorDecibels)
        
        return CGFloat(normalizedRange)
    }
}

@MainActor
private final class AudioCaptureStreams {
    let liveTranscriptStream: AsyncStream<String>
    let audioLevelStream: AsyncStream<CGFloat>

    private var liveTranscriptContinuation: AsyncStream<String>.Continuation?
    private var audioLevelContinuation: AsyncStream<CGFloat>.Continuation?

    init() {
        var transcriptContinuation: AsyncStream<String>.Continuation?
        liveTranscriptStream = AsyncStream { continuation in
            transcriptContinuation = continuation
        }
        liveTranscriptContinuation = transcriptContinuation

        var levelContinuation: AsyncStream<CGFloat>.Continuation?
        audioLevelStream = AsyncStream { continuation in
            levelContinuation = continuation
        }
        audioLevelContinuation = levelContinuation
    }

    func reset() {
        emitTranscript("")
        emitAudioLevel(0)
    }

    func emitTranscript(_ transcript: String) {
        liveTranscriptContinuation?.yield(transcript)
    }

    func emitAudioLevel(_ level: CGFloat) {
        audioLevelContinuation?.yield(level)
    }
}

@MainActor
/// AVAudioEngine + Speech-backed implementation of a single audio capture session.
final class LiveAudioCaptureSession: AudioCaptureSession {
    let liveTranscriptStream: AsyncStream<String>
    let audioLevelStream: AsyncStream<CGFloat>

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recordingStartTime: Date?
    private var completionContinuation: CheckedContinuation<RecordingResult, Error>?
    private let streams: AudioCaptureStreams
    private var latestTranscript = ""

    init() {
        let streams = AudioCaptureStreams()
        self.streams = streams
        self.liveTranscriptStream = streams.liveTranscriptStream
        self.audioLevelStream = streams.audioLevelStream
    }

    /// Start recording and return the final transcript when `stopRecording()` is called.
    /// Live transcript and audio level updates are emitted through the session streams.
    func startRecording() async throws -> RecordingResult {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw AudioCaptureError.recognizerUnavailable
        }

        let request = try prepareAudioEngine()
        beginRecordingState()

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(throwing: AudioCaptureError.audioEngineFailure("Session deallocated"))
                return
            }

            completionContinuation = continuation
            recognitionTask = makeRecognitionTask(
                recognizer: recognizer,
                request: request
            )
        }
    }

    /// Stop recording. The continuation from `startRecording()` will resume once recognition finishes.
    func stopRecording() {
        tearDownAudioInput()
        recognitionRequest?.endAudio()
        streams.emitAudioLevel(0)
    }

    /// Cancel recording immediately without waiting for final recognition results.
    func cancel() {
        recognitionTask?.cancel()
        finishRecording(with: .failure(AudioCaptureError.audioEngineFailure("Recording cancelled.")))
    }

    private func prepareAudioEngine() throws -> SFSpeechAudioBufferRecognitionRequest {
        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation

        try configureAudioSession()
        installAudioTap(on: engine, request: request)

        engine.prepare()
        try engine.start()

        audioEngine = engine
        recognitionRequest = request
        return request
    }

    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func installAudioTap(
        on engine: AVAudioEngine,
        request: SFSpeechAudioBufferRecognitionRequest
    ) {
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            request.append(buffer)
            self?.emitAudioLevel(from: buffer)
        }
    }

    private func beginRecordingState() {
        recordingStartTime = Date()
        latestTranscript = ""
        streams.reset()
    }

    private func makeRecognitionTask(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                handleRecognitionResult(result)
            }

            if let error {
                handleRecognitionError(error)
            }
        }
    }

    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult) {
        let transcript = result.bestTranscription.formattedString
        latestTranscript = transcript
        streams.emitTranscript(transcript)

        guard result.isFinal else { return }
        finishRecording(with: .success(makeRecordingResult(from: transcript)))
    }

    private func handleRecognitionError(_ error: Error) {
        guard !latestTranscript.isEmpty else {
            finishRecording(with: .failure(AudioCaptureError.audioEngineFailure(error.localizedDescription)))
            return
        }

        finishRecording(with: .success(makeRecordingResult(from: latestTranscript)))
    }

    private func makeRecordingResult(from transcript: String) -> RecordingResult {
        RecordingResult(
            transcript: transcript,
            duration: Date().timeIntervalSince(recordingStartTime ?? Date())
        )
    }

    private func tearDownAudioInput() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
    }

    private func tearDownResources() {
        tearDownAudioInput()
        recognitionRequest = nil
        recognitionTask = nil
        audioEngine = nil
        streams.emitAudioLevel(0)
    }

    private func finishRecording(with result: Result<RecordingResult, Error>) {
        guard let continuation = completionContinuation else { return }
        completionContinuation = nil
        tearDownResources()

        switch result {
        case .success(let recording):
            continuation.resume(returning: recording)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    private func emitAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let normalizedLevel = AudioLevelMeter.normalizedLevel(from: buffer) else { return }
        streams.emitAudioLevel(normalizedLevel)
    }
}
