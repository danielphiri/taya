//
//  MemoryCard.swift
//  Taya
//
//  The core data model for a voice memory capture.
//

import Foundation

/// A single memory card — the unit of persistence
struct MemoryCard: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    var transcript: String
    var state: CaptureState
    var result: LLMOutput?
    
    init(id: UUID = UUID(), createdAt: Date = Date(), transcript: String = "", state: CaptureState = .recording, result: LLMOutput? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.transcript = transcript
        self.state = state
        self.result = result
    }
    
    /// Display title: either the LLM title or a placeholder
    var displayTitle: String {
        result?.title ?? "Processing..."
    }
    
    /// Display category
    var displayCategory: MemoryCategory {
        result?.resolvedCategory ?? .other
    }
    
    var timeAgoString: String {
        let interval = Date().timeIntervalSince(createdAt)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}
