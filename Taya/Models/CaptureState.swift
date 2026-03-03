//
//  CaptureState.swift
//  Taya
//
//  Created by Daniel Phiri on 03/03/2026.
//

import Foundation

/// Represents the processing state of a single capture
enum CaptureState: Codable, Equatable {
    case recording
    case transcribing
    case processing
    case completed
    case failed(String)
}
