//
//  LLMOutput.swift
//  Taya
//
//  Created by Daniel Phiri on 03/03/2026.
//

import Foundation

/// The structured output from the LLM
struct LLMOutput: Codable, Equatable {
    let title: String
    let category: String
    let actionItems: [String]
    let mood: String
    
    enum CodingKeys: String, CodingKey {
        case title
        case category
        case actionItems = "action_items"
        case mood
    }
    
    var resolvedCategory: MemoryCategory {
        MemoryCategory(rawValue: category) ?? .other
    }
}
