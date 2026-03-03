//
//  MemoryCardView.swift
//  Taya
//
//  Displays a single memory card with state-aware presentation.
//  Cards in processing state show a shimmer/skeleton. Failed cards show retry.
//

import SwiftUI

struct MemoryCardView: View {
    let card: MemoryCard
    let onRetry: () -> Void
    let onDelete: () -> Void
    
    @State private var shimmerOffset: CGFloat = -200
    @State private var appeared = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch card.state {
            case .recording:
                recordingState
            case .transcribing:
                skeletonState(label: "Transcribing...")
            case .processing:
                skeletonState(label: "Processing with AI...")
            case .completed:
                completedState
            case .failed(let message):
                failedState(message: message)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
    
    // MARK: - Recording state
    
    private var recordingState: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .opacity(shimmerOpacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                        shimmerOffset = 200
                    }
                }
            
            Text("Recording...")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }
    
    private var shimmerOpacity: Double {
        return 0.4 + 0.6 * abs(sin(Double(shimmerOffset) * .pi / 400.0))
    }
    
    // MARK: - Skeleton / processing state
    
    private func skeletonState(label: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Skeleton lines
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(height: 16)
                .frame(maxWidth: 200)
                .shimmering()
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(height: 12)
                .frame(maxWidth: 140)
                .shimmering()
        }
        .padding(20)
    }
    
    // MARK: - Completed state
    
    private var completedState: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: category icon + title
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: card.displayCategory.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(categoryColor)
                    .frame(width: 32, height: 32)
                    .background(categoryColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(card.displayTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    
                    HStack(spacing: 6) {
                        Text(card.displayCategory.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(categoryColor)
                        
                        Text("·")
                            .foregroundStyle(.tertiary)
                        
                        Text(card.timeAgoString)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        
                        if let mood = card.result?.mood {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(mood)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .italic()
                        }
                    }
                }
                
                Spacer()
            }
            
            // Action items
            if let items = card.result?.actionItems, !items.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(categoryColor.opacity(0.5))
                                .frame(width: 5, height: 5)
                                .padding(.top, 6)
                            
                            Text(item)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(.leading, 42)
            }
        }
        .padding(20)
    }
    
    // MARK: - Failed state
    
    private func failedState(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 14))
                
                Text("Capture failed")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            
            HStack(spacing: 12) {
                Button(action: onRetry) {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                
                Button(action: onDelete) {
                    Label("Dismiss", systemImage: "xmark")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
        }
        .padding(20)
    }
    
    // MARK: - Helpers
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemBackground))
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

// MARK: - Shimmer modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.4),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: phase)
                    .onAppear {
                        phase = -geo.size.width
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            phase = geo.size.width * 1.5
                        }
                    }
                }
            )
            .clipped()
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

#Preview {
    let sampleCard = MemoryCard(
        transcript: "Test transcript",
        state: .completed,
        result: LLMOutput(
            title: "Grocery run & follow-up with Sarah",
            category: "Shopping",
            actionItems: [
                "Get organic eggs from Whole Foods",
                "Look up 'The Creative Act' book",
                "Send Marcus the deck before Thursday"
            ],
            mood: "scattered but productive"
        )
    )
    
    ScrollView {
        VStack(spacing: 16) {
            MemoryCardView(card: sampleCard, onRetry: {}, onDelete: {})
            MemoryCardView(card: MemoryCard(state: .processing), onRetry: {}, onDelete: {})
            MemoryCardView(card: MemoryCard(state: .failed("Network timeout")), onRetry: {}, onDelete: {})
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
