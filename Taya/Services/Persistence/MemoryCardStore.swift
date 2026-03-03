//
//  MemoryCardStore.swift
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
