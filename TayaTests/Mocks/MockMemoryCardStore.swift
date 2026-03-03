import Foundation
@testable import Taya

actor MockMemoryCardStore: MemoryCardStore {
    var cards: [MemoryCard]
    var loadError: Error?

    init(cards: [MemoryCard] = [], loadError: Error? = nil) {
        self.cards = cards
        self.loadError = loadError
    }

    func loadCards() throws -> [MemoryCard] {
        if let loadError {
            throw loadError
        }
        return cards
    }

    func save(card: MemoryCard) {
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            cards[index] = card
        } else {
            cards.insert(card, at: 0)
        }
    }

    func delete(cardId: UUID) {
        cards.removeAll { $0.id == cardId }
    }

    func allCards() -> [MemoryCard] {
        cards
    }
}
