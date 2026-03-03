//
//  RecordButton.swift
//  Taya
//
//  The primary interaction surface. When recording, flowing waveforms
//  surround the button (matching the splash-screen style) driven by
//  a TimelineView so the phase never stops. When idle, a clean
//  purple-tinted circle with a mic icon.
//

import SwiftUI

struct RecordButton: View {
    let isRecording: Bool
    let audioLevel: CGFloat
    let action: () -> Void
    
    private let buttonSize: CGFloat = 72
    
    /// Purple tint matching the splash screen palette
    private let accentPurple = Color(red: 0.55, green: 0.35, blue: 0.85)
    private let deepPurple   = Color(red: 0.40, green: 0.25, blue: 0.75)
    
    /// Smoothed audio level for fluid visuals
    @State private var smoothLevel: CGFloat = 0
    
    var body: some View {
        ZStack {
            if isRecording {
                // Continuous wave animation driven by TimelineView
                TimelineView(.animation) { timeline in
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    let phase = CGFloat(now.truncatingRemainder(dividingBy: 200)) * .pi
                    
                    RecordingWaveformGroup(
                        phase: phase,
                        audioLevel: smoothLevel,
                        accentColor: accentPurple
                    )
                }
                .transition(.opacity.combined(with: .scale(scale: 0.6)))
            }
            
            // Main button
            recordButtonBody
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.65), value: isRecording)
        .onChange(of: audioLevel) { _, newLevel in
            // Rise quickly so loud sounds register instantly,
            // but fall more slowly for organic decay
            let isRising = newLevel > smoothLevel
            let animation: Animation = isRising
                ? .easeOut(duration: 0.08)
                : .easeOut(duration: 0.28)
            withAnimation(animation) {
                smoothLevel = newLevel
            }
        }
        .onChange(of: isRecording) { _, recording in
            if !recording {
                withAnimation(.easeOut(duration: 0.35)) {
                    smoothLevel = 0
                }
            }
        }
        .onTapGesture {
            let impactFeedback = UIImpactFeedbackGenerator(style: isRecording ? .light : .medium)
            impactFeedback.impactOccurred()
            action()
        }
    }
    
    // MARK: - Button visuals
    
    @ViewBuilder
    private var recordButtonBody: some View {
        if isRecording {
            // Recording state: a translucent purple ring with a rounded stop icon
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(accentPurple.opacity(0.25), lineWidth: 3)
                    .frame(width: buttonSize + 14, height: buttonSize + 14)
                
                // Solid background
                Circle()
                    .fill(
                        .ultraThinMaterial
                    )
                    .frame(width: buttonSize, height: buttonSize)
                    .overlay(
                        Circle()
                            .fill(accentPurple.opacity(0.15))
                    )
                
                // Stop icon – rounded square
                RoundedRectangle(cornerRadius: 6)
                    .fill(accentPurple)
                    .frame(width: 24, height: 24)
            }
            .shadow(color: accentPurple.opacity(0.35), radius: 16, y: 0)
        } else {
            // Idle state: elegant purple-tinted circle with mic icon
            ZStack {
                Circle()
                    .fill(
                        .ultraThinMaterial
                    )
                    .frame(width: buttonSize, height: buttonSize)
                    .overlay(
                        Circle()
                            .fill(accentPurple.opacity(0.1))
                    )
                    .overlay(
                        Circle()
                            .stroke(accentPurple.opacity(0.2), lineWidth: 1.5)
                    )
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(accentPurple)
            }
            .shadow(color: accentPurple.opacity(0.12), radius: 10, y: 4)
        }
    }
}

// MARK: - Wave Group (3 layered flowing waveforms driven by voice level)

private struct RecordingWaveformGroup: View {
    let phase: CGFloat
    let audioLevel: CGFloat
    let accentColor: Color
    
    /// Voice-reactive amplitude: nearly flat when silent, dramatic when loud.
    /// Maps 0…1 audio level → 0.04 … 1.0 amplitude
    private var levelAmp: CGFloat {
        let clamped = min(max(audioLevel, 0), 1)
        // Use a power curve so quiet levels stay small, loud levels bloom
        let curved = pow(clamped, 0.7)
        return 0.04 + curved * 0.96
    }
    
    /// Voice-reactive spread: how wide the visible wave area extends.
    /// Maps 0…1 audio level → a scale from ~0.45 (tight) to 1.0 (full width)
    private var spreadFactor: CGFloat {
        let clamped = min(max(audioLevel, 0), 1)
        return 0.45 + clamped * 0.55
    }
    
    /// Phase speed multiplier: waves scroll faster when louder
    private var phaseSpeed: CGFloat {
        let clamped = min(max(audioLevel, 0), 1)
        return 0.4 + clamped * 0.6
    }
    
    /// Opacity reacts to voice level — more visible when louder
    private var levelOpacity: CGFloat {
        let clamped = min(max(audioLevel, 0), 1)
        return 0.15 + clamped * 0.85
    }
    
    var body: some View {
        let adjustedPhase = phase * phaseSpeed
        
        ZStack {
            // Primary wave – most visible
            RecordingFlowingWave(
                phase: adjustedPhase,
                amplitudeScale: levelAmp,
                spreadScale: spreadFactor
            )
            .stroke(
                accentColor.opacity(0.65 * levelOpacity),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )
            .frame(width: 260, height: 70)
            
            // Secondary wave – slightly offset
            RecordingFlowingWave(
                phase: adjustedPhase + 1.5,
                amplitudeScale: levelAmp * 0.75,
                spreadScale: spreadFactor * 0.9
            )
            .stroke(
                accentColor.opacity(0.35 * levelOpacity),
                style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
            )
            .frame(width: 240, height: 56)
            
            // Tertiary wave – ethereal background
            RecordingFlowingWave(
                phase: adjustedPhase + 3.0,
                amplitudeScale: levelAmp * 0.5,
                spreadScale: spreadFactor * 0.8
            )
            .stroke(
                accentColor.opacity(0.15 * levelOpacity),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
            )
            .frame(width: 280, height: 80)
        }
    }
}

// MARK: - Single Flowing Wave (voice-reactive height + spread)

private struct RecordingFlowingWave: Shape {
    var phase: CGFloat
    var amplitudeScale: CGFloat   // 0…1  controls wave height
    var spreadScale: CGFloat      // 0…1  controls how wide the envelope opens
    
    // Animate both amplitude and spread for fluid transitions
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(amplitudeScale, spreadScale) }
        set {
            amplitudeScale = newValue.first
            spreadScale = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let width = rect.width
        let segments = 120
        
        for i in 0...segments {
            let x = width * CGFloat(i) / CGFloat(segments)
            let normalizedX = x / width
            
            // Voice-reactive envelope:
            // - spreadScale controls how much of the width is "active"
            // - When spread is low, only the very center has any wave
            // - When spread is high, the wave extends nearly edge-to-edge
            //
            // We use a Gaussian-like shape centered at 0.5:
            //   exp(-(x-0.5)^2 / (2 * sigma^2))
            // where sigma grows with spreadScale.
            let sigma = 0.12 + spreadScale * 0.38  // tight (0.12) → wide (0.50)
            let distFromCenter = normalizedX - 0.5
            let envelope = exp(-(distFromCenter * distFromCenter) / (2 * sigma * sigma))
            
            // Composite wave — same frequencies as the splash waveform
            let wave1 = sin(normalizedX * 4 * .pi + phase) * 0.5
            let wave2 = sin(normalizedX * 7 * .pi + phase * 1.3) * 0.25
            let wave3 = sin(normalizedX * 11 * .pi + phase * 0.7) * 0.15
            let wave4 = cos(normalizedX * 5.5 * .pi + phase * 1.6) * 0.1
            
            let combinedWave = wave1 + wave2 + wave3 + wave4
            let amplitude = rect.height * 0.45 * amplitudeScale
            let y = midY + combinedWave * amplitude * envelope
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        return path
    }
}

#Preview {
    VStack(spacing: 60) {
        RecordButton(isRecording: false, audioLevel: 0) { }
        RecordButton(isRecording: true, audioLevel: 0.5) { }
    }
}
