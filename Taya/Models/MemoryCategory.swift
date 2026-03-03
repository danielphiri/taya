//
//  MemoryCategory.swift
//  Taya
//
//  Created by Daniel Phiri on 03/03/2026.
//

import Foundation

/// Categories that the LLM can assign to a memory
enum MemoryCategory: String, Codable, CaseIterable {
    case shopping = "Shopping"
    case learning = "Learning"
    case meeting = "Meeting"
    case people = "People"
    case other = "Other"
    
    var iconName: String {
        switch self {
        case .shopping: return "cart.fill"
        case .learning: return "book.fill"
        case .meeting: return "person.2.fill"
        case .people: return "person.fill"
        case .other: return "square.grid.2x2.fill"
        }
    }
}
