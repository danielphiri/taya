//
//  MemoryCardCodec.swift
//  Taya
//
//  Created by Daniel Phiri on 03/03/2026.
//

import Foundation

/// Encodes and decodes the on-disk JSON representation of memory cards.
struct MemoryCardCodec: Sendable {
    func decodeCards(from data: Data) throws -> [MemoryCard] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([MemoryCard].self, from: data)
    }

    func encodeCards(_ cards: [MemoryCard]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(cards)
    }
}
