//
//  TransformingLoadingPill.swift
//  Retrospect
//
//  Created by Assistant on 1/30/25.
//

import SwiftUI

struct TransformingLoadingPill: View {
    @ObservedObject var viewModel: TranscriptViewModel
    
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    
    // Note: Loading phases are now handled by the ViewModel's enhanced system
    
    var body: some View {
        HStack(spacing: 0) {
            // Circular progress indicator
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 3)
                    .frame(width: 32, height: 32)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: viewModel.currentProgress)
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 32, height: 32)
                    .rotationEffect(Angle(degrees: -90))
                    .animation(.easeInOut(duration: 0.5), value: viewModel.currentProgress)
                
                // Center icon
                Image(systemName: getCurrentPhaseIcon())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .scaleEffect(pulseScale)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseScale)
            }
            .padding(.leading, 16)
            
            // Loading text content
            VStack(spacing: Spacing.sm) {
                // Loading text
                Text(getDisplayText())
                    .font(.geistLabel)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.5), value: viewModel.currentLoadingPhase)
                
                // Reference chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(viewModel.contentReferences, id: \.id) { reference in
                            ReferenceChip(reference: reference)
                        }
                    }
                    .padding(.horizontal, Spacing.sm) // Small padding for scrollable content
                }
            }
            .padding(.horizontal, 12)
            
            Spacer(minLength: 16)
            
            // Animated dots
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 4, height: 4)
                        .scaleEffect(pulseScale)
                        .animation(
                            .easeInOut(duration: 0.8)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: pulseScale
                        )
                }
            }
            .padding(.trailing, 16)
        }
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28) // Pill shape
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            LinearColors.accent,
                            LinearColors.accent.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(
                    color: LinearColors.accent.opacity(0.4),
                    radius: 12,
                    x: 0,
                    y: 6
                )
        )
        .onAppear {
            startAnimations()
        }
        .onChange(of: viewModel.isProcessing) { _, isProcessing in
            if !isProcessing {
                // Progress completion is now handled by the ViewModel's completeProgress() method
                // The ViewModel will automatically set currentProgress to 1.0 and update the phase
            }
        }
    }
    
    private func getDisplayText() -> String {
        // Use enhanced loading phase if available, otherwise fall back to view model status
        if !viewModel.currentLoadingPhase.isEmpty {
            return viewModel.currentLoadingPhase
        } else if !viewModel.processingStatus.isEmpty {
            return viewModel.processingStatus
        } else {
            return "Processing..."
        }
    }
    
    private func getCurrentPhaseIcon() -> String {
        let progress = viewModel.currentProgress
        switch progress {
        case 0..<0.2: return "brain.head.profile"
        case 0.2..<0.4: return "magnifyingglass"
        case 0.4..<0.7: return "waveform"
        case 0.7..<0.9: return "speaker.wave.3"
        default: return "checkmark.circle"
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }
    }
    
    // Note: Progress timing is now handled by the ViewModel's realistic progress system
}

// MARK: - Reference Chip Component

struct ReferenceChip: View {
    let reference: ContentReference
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: reference.type.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(reference.isIncluded ? .white : LinearColors.textSecondary)
            
            Text(reference.name)
                .font(.geistCaption)
                .foregroundColor(reference.isIncluded ? .white : LinearColors.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(reference.isIncluded ? 
                      getBackgroundColor(for: reference.type) : 
                      LinearColors.cardBackground
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(reference.isIncluded ? 
                               Color.clear : 
                               LinearColors.cardBorder, 
                               lineWidth: 1)
                )
        )
        .opacity(reference.isIncluded ? 1.0 : 0.6)
        .scaleEffect(reference.isIncluded ? 1.0 : 0.95)
        .animation(.easeInOut(duration: 0.3), value: reference.isIncluded)
    }
    
    private func getBackgroundColor(for type: ContentReference.ReferenceType) -> Color {
        switch type {
        case .userText: return LinearColors.accent
        case .goals: return LinearColors.successGreen
        case .healthData: return LinearColors.warningRed
        case .document: return Color(red: 0.65, green: 0.45, blue: 0.75) // Warm purple
        case .journal: return Color(red: 0.90, green: 0.60, blue: 0.35) // Warm orange
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Preview with mock view model
        TransformingLoadingPill(
            viewModel: {
                let vm = TranscriptViewModel(openAIService: .shared, textToSpeechService: .shared)
                vm.isProcessing = true
                vm.currentProgress = 0.65
                vm.currentLoadingPhase = "Crafting your personalized podcast..."
                vm.contentReferences = [
                    ContentReference(type: .userText, name: "Your Reflections", isIncluded: true),
                    ContentReference(type: .goals, name: "3 Goals", isIncluded: true),
                    ContentReference(type: .healthData, name: "Health Data", isIncluded: false),
                    ContentReference(type: .document("Work Notes"), name: "Work Notes", isIncluded: true)
                ]
                return vm
            }()
        )
        .padding()
    }
    .background(LinearColors.background)
}