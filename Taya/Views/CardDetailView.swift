//
//  CardDetailView.swift
//  Taya
//
//  Expanded view of a completed memory card, showing full transcript.
//

import SwiftUI

struct CardDetailView: View {
    let card: MemoryCard
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title + metadata
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: card.displayCategory.iconName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(categoryColor)
                                .frame(width: 36, height: 36)
                                .background(categoryColor.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.displayCategory.rawValue)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(categoryColor)
                                
                                Text(card.timeAgoString)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            
                            Spacer()
                            
                            if let mood = card.result?.mood {
                                Text(mood)
                                    .font(.caption)
                                    .italic()
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray6))
                                    .clipShape(Capsule())
                            }
                        }
                        
                        Text(card.displayTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    // Action items
                    if let items = card.result?.actionItems, !items.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Action Items")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            
                            ForEach(items, id: \.self) { item in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "circle")
                                        .font(.system(size: 10))
                                        .foregroundStyle(categoryColor)
                                        .padding(.top, 4)
                                    
                                    Text(item)
                                        .font(.body)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6).opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Transcript
                    if !card.transcript.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Original Transcript")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            
                            Text(card.transcript)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                        }
                    }
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
        }
    }
    
    private var categoryColor: Color {
        switch card.displayCategory {
        case .shopping: return .green
        case .learning: return .blue
        case .meeting: return .purple
        case .people: return .orange
        case .other: return .gray
        }
    }
}
