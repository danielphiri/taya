//
//  LiveAudioCaptureClient.swift
//  Taya
//
//  Audio client that creates live capture sessions.
//

import Foundation

struct LiveAudioCaptureClient: AudioCaptureClient {
    private let permissionRequester: any AudioCapturePermissionRequesting

    init(permissionRequester: any AudioCapturePermissionRequesting = LiveAudioCapturePermissionRequester()) {
        self.permissionRequester = permissionRequester
    }

    @MainActor
    func makeSession() -> any AudioCaptureSession {
        LiveAudioCaptureSession()
    }

    func requestPermissions() async -> Result<Void, AudioCaptureError> {
        await permissionRequester.requestPermissions()
    }
}
