//
//  SplashScreenView.swift
//  Taya
//
//  Animated launch screen with flowing waveform on gradient background.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var phase: CGFloat = 0
    @State private var waveOpacity: Double = 1
    @State private var appearing = false
    
    var body: some View {
        ZStack {
            // Gradient background matching the launch image style
            LinearGradient(
                colors: [
                    Color("launch_background_color"),
                    Color("gradient_dark_color")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Flowing waveform
            FlowingWaveform(phase: phase)
                .stroke(
                    Color.white.opacity(0.9),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )
                .frame(height: 80)
                .opacity(waveOpacity)
                .padding(.horizontal, 40)
            
            // Subtle secondary wave behind the main one
            FlowingWaveform(phase: phase + 1.5)
                .stroke(
                    Color.white.opacity(0.3),
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                )
                .frame(height: 60)
                .opacity(waveOpacity)
                .padding(.horizontal, 50)
            
            // Third ethereal wave
            FlowingWaveform(phase: phase + 3.0)
                .stroke(
                    Color.white.opacity(0.15),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
                )
                .frame(height: 100)
                .opacity(waveOpacity)
                .padding(.horizontal, 30)
            
            // App name below waveform
            VStack {
                Spacer()
                
                Text("Taya")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .tracking(8)
                    .opacity(appearing ? 1 : 0)
                    .offset(y: appearing ? 0 : 10)
                
                Spacer().frame(height: 120)
            }
        }
        .onAppear {
            // Start flowing wave animation
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
            
            // Fade in app name
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                appearing = true
            }
        }
    }
}

// MARK: - Flowing Waveform Shape

struct FlowingWaveform: Shape {
    var phase: CGFloat
    
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let width = rect.width
        let segments = 120
        
        for i in 0...segments {
            let x = width * CGFloat(i) / CGFloat(segments)
            let normalizedX = x / width
            
            // Envelope: taper the ends, strong in center
            let envelope = sin(normalizedX * .pi)
            
            // Composite wave: multiple frequencies for organic feel
            let wave1 = sin(normalizedX * 4 * .pi + phase) * 0.5
            let wave2 = sin(normalizedX * 7 * .pi + phase * 1.3) * 0.25
            let wave3 = sin(normalizedX * 11 * .pi + phase * 0.7) * 0.15
            let wave4 = cos(normalizedX * 5.5 * .pi + phase * 1.6) * 0.1
            
            let combinedWave = wave1 + wave2 + wave3 + wave4
            let amplitude = rect.height * 0.45
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
    SplashScreenView()
}
