//
//  NetworkTypes.swift
//  Taya
//
//  Shared networking contracts and error types.
//

import Foundation

enum NetworkClientError: Error, LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from the server."
        }
    }
}
