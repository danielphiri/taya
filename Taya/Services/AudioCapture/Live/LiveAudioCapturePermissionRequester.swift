//
//  LiveAudioCapturePermissionRequester.swift
//  Taya
//
//  Production permission requester backed by AVFoundation and Speech.
//

import AVFoundation
import Speech

struct LiveAudioCapturePermissionRequester: AudioCapturePermissionRequesting {
    func requestPermissions() async -> Result<Void, AudioCaptureError> {
        let microphoneGranted = await requestMicrophonePermission()
        guard microphoneGranted else {
            return .failure(.microphonePermissionDenied)
        }

        let speechStatus = await requestSpeechPermission()
        guard speechStatus == .authorized else {
            return .failure(.speechPermissionDenied)
        }

        return .success(())
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func requestSpeechPermission() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}
