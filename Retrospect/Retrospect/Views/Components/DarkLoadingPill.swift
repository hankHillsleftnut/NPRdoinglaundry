//
//  DarkLoadingPill.swift
//  Retrospect
//
//  Loading indicator for podcast generation in dark UI
//

import SwiftUI

struct DarkLoadingPill: View {
    @ObservedObject var viewModel: TranscriptViewModel
    
    @State private var animateGradient = false
    @State private var dotIndex = 0
    
    private var statusText: String {
        // Use the actual status from the view model
        if !viewModel.currentLoadingPhase.isEmpty {
            return viewModel.currentLoadingPhase
        } else if !viewModel.processingStatus.isEmpty {
            return viewModel.processingStatus
        } else if !viewModel.deepResearchProgress.isEmpty {
            return viewModel.deepResearchProgress
        } else {
            return "Processing..."
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Animated gradient circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                LinearColors.Minimal.accent,
                                LinearColors.Minimal.accentLight,
                                LinearColors.Minimal.accent
                            ]),
                            startPoint: animateGradient ? .topLeading : .bottomTrailing,
                            endPoint: animateGradient ? .bottomTrailing : .topLeading
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                    .rotationEffect(.degrees(animateGradient ? 360 : 0))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(statusText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                
                // Animated dots
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(LinearColors.Minimal.accent)
                            .frame(width: 6, height: 6)
                            .opacity(dotIndex == index ? 1.0 : 0.3)
                    }
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearColors.Minimal.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                animateGradient = true
            }
            
            // Dot animation
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    dotIndex = (dotIndex + 1) % 3
                }
            }
        }
    }
}

#Preview {
    ZStack {
        LinearColors.Minimal.background
            .ignoresSafeArea()
        
        DarkLoadingPill(viewModel: TranscriptViewModel(openAIService: .shared, textToSpeechService: .shared))
        .padding()
    }
}

