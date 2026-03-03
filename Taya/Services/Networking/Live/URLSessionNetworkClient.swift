//
//  URLSessionNetworkClient.swift
//  Taya
//
//  Network client backed by URLSession.
//

import Foundation

/// App-facing boundary for backend HTTP requests.
protocol NetworkClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionNetworkClient: NetworkClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkClientError.invalidResponse
        }

        return (data, httpResponse)
    }
}
