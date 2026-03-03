//
//  PersistenceError.swift
//  Taya
//
//  Created by Daniel Phiri on 03/03/2026.
//

import Foundation

/// Errors surfaced by the persistence layer so callers can decide how to react.
enum PersistenceError: LocalizedError {
    case documentsDirectoryUnavailable
    case failedToRead(Error)
    case failedToWrite(Error)

    var errorDescription: String? {
        switch self {
        case .documentsDirectoryUnavailable:
            return "The app documents directory is unavailable."
        case .failedToRead(let error):
            return "Failed to read saved memories: \(error.localizedDescription)"
        case .failedToWrite(let error):
            return "Failed to save memories: \(error.localizedDescription)"
        }
    }
}
