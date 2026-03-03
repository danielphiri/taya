//
//  HomeView.swift
//  Taya
//
//  Root view: record button at the bottom, memory cards scrolling above.
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var selectedCard: MemoryCard?
    @State private var showPermissionAlert = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            Color(.white)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Card list
                if viewModel.cards.isEmpty && !viewModel.isRecording {
                    emptyState
                } else {
                    cardList
                }
                
                Spacer(minLength: 8)
                
                // Live transcript while recording
                if viewModel.isRecording {
                    liveTranscriptView
                }
                
                // Record button area
                recordArea
            }
        }
        .sheet(item: $selectedCard) { card in
            CardDetailView(card: card)
        }
        .alert("Permission Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "Microphone and speech recognition access are required to capture voice memories.")
        }
        .task {
            await viewModel.loadPersistedCardsIfNeeded()
        }
        .onDisappear {
            viewModel.cancelAllWork()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Taya")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if viewModel.processingCount > 0 {
                    Text("\(viewModel.processingCount) processing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            
            Spacer()
            
            if !viewModel.cards.isEmpty {
                Text("\(viewModel.cards.filter { $0.state == .completed }.count) memories")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.3), value: viewModel.processingCount)
    }
    
    // MARK: - Empty state
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "waveform")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tertiary)
            
            Text("Tap to capture a memory")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Record a thought, idea, or to-do.\nTaya turns it into a structured card.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(40)
    }
    
    // MARK: - Card list
    
    private var cardList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.cards) { card in
                    MemoryCardView(
                        card: card,
                        onRetry: { viewModel.retryCard(card) },
                        onDelete: {
                            withAnimation(.easeOut(duration: 0.3)) {
                                viewModel.deleteCard(card)
                            }
                        }
                    )
                    .onTapGesture {
                        if card.state == .completed {
                            selectedCard = card
                        }
                    }
                    .contextMenu {
                        if card.state == .completed {
                            Button {
                                selectedCard = card
                            } label: {
                                Label("View Details", systemImage: "eye")
                            }
                        }
                        
                        if case .failed = card.state {
                            Button {
                                viewModel.retryCard(card)
                            } label: {
                                Label("Retry", systemImage: "arrow.clockwise")
                            }
                        }
                        
                        Button(role: .destructive) {
                            withAnimation {
                                viewModel.deleteCard(card)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 200)
        }
    }
    
    // MARK: - Live transcript
    
    private var liveTranscriptView: some View {
        VStack(spacing: 4) {
            if !viewModel.liveTranscript.isEmpty {
                Text(viewModel.liveTranscript)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.liveTranscript)
            } else {
                Text("Listening...")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Record area
    
    private var recordArea: some View {
        VStack(spacing: 8) {
            RecordButton(
                isRecording: viewModel.isRecording,
                audioLevel: viewModel.currentAudioLevel
            ) {
                handleRecordTap()
            }
            .padding(.top, 16)
            
            Text(viewModel.isRecording ? "Tap to stop" : "Tap to capture")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.bottom, 30)
    }
    
    // MARK: - Actions
    
    private func handleRecordTap() {
        if viewModel.isRecording {
            viewModel.stopCapture()
        } else {
            Task {
                if !viewModel.permissionsGranted {
                    await viewModel.requestPermissions()
                }

                if viewModel.permissionsGranted {
                    viewModel.startCapture()
                } else {
                    showPermissionAlert = true
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
