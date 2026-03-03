//
//  PersistenceService 2.swift
//  Taya
//
//  Created by Daniel Phiri on 03/03/2026.
//

import Foundation

/// App-facing persistence boundary used by the view model and tests.
protocol MemoryCardStore: Sendable {
    func loadCards() async throws -> [MemoryCard]
    func save(card: MemoryCard) async throws
    func delete(cardId: UUID) async throws
    func allCards() async -> [MemoryCard]
}

/// Thread-safe JSON-backed implementation of `MemoryCardStore`.
///
/// `PersistenceService` keeps an in-memory cache after the first read, while
/// delegating file access and encoding to injectable collaborators for testability.
actor PersistenceService: MemoryCardStore {
    static let shared = PersistenceService()

    private let fileURL: URL
    private let fileStore: any FileStore
    private let codec: MemoryCardCodec
    private var cards: [MemoryCard] = []
    private var isLoaded = false

    init(
        fileURL: URL? = nil,
        fileStore: any FileStore = DiskFileStore(),
        codec: MemoryCardCodec = MemoryCardCodec()
    ) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.fileStore = fileStore
        self.codec = codec
    }

    // MARK: - Public API

    /// Load cards from disk once, then serve subsequent reads from the actor cache.
    func loadCards() throws -> [MemoryCard] {
        if !isLoaded {
            cards = try readFromDisk()
            isLoaded = true
        }
        return cards
    }

    /// Add or update a card, then persist the full collection immediately.
    func save(card: MemoryCard) throws {
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            cards[index] = card
        } else {
            cards.insert(card, at: 0)
        }
        try writeToDisk()
    }

    func delete(cardId: UUID) throws {
        cards.removeAll { $0.id == cardId }
        try writeToDisk()
    }

    func allCards() -> [MemoryCard] {
        cards
    }

    // MARK: - Disk I/O

    private func readFromDisk() throws -> [MemoryCard] {
        guard fileStore.fileExists(at: fileURL) else {
            return []
        }

        do {
            let data = try fileStore.read(from: fileURL)
            return try codec.decodeCards(from: data)
        } catch {
            throw PersistenceError.failedToRead(error)
        }
    }

    private func writeToDisk() throws {
        do {
            let data = try codec.encodeCards(cards)
            try fileStore.write(data, to: fileURL)
        } catch {
            throw PersistenceError.failedToWrite(error)
        }
    }

    private static func defaultFileURL() -> URL {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            preconditionFailure(PersistenceError.documentsDirectoryUnavailable.localizedDescription)
        }
        return documentsDirectory.appendingPathComponent("taya_memories.json")
    }
}
