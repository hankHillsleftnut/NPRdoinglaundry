import SwiftUI

// MARK: - Voice Persona Selection (Onboarding Step)

// Lets the user choose how their weekly podcast should sound.

struct DarkVoicePersonaOnboardingScreen: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onExit: (() -> Void)?

    @State private var selectedPersona: String = "thoughtful_friend"
    @State private var isSaving = false
    @State private var bodyTextAnimating = false
    @State private var dragOffset: CGFloat = 0
    @State private var cardsAppeared = false

    private let personas: [(id: String, name: String, icon: String, description: String, sample: String)] = [
        (
            id: "thoughtful_friend",
            name: "Thoughtful Friend",
            icon: "cup.and.saucer.fill",
            description: "Warm and conversational. Natural laughs, vocal warmth, like catching up over coffee.",
            sample: "[warm tone] This week, something shifted for you... and honestly? [brightening] That's a bigger deal than you might think. [gentle laugh]"
        ),
        (
            id: "wise_mentor",
            name: "Wise Mentor",
            icon: "book.closed.fill",
            description: "Calm and grounded with gravitas. Measured pacing, lets insights land with weight.",
            sample: "[calm, grounded tone] Here's what I want you to sit with... [thoughtful pause] The pattern in your data tells a story you might not have seen yet."
        ),
        (
            id: "energetic_host",
            name: "Energetic Host",
            icon: "bolt.fill",
            description: "Dynamic and engaging. Varied pacing, genuinely curious, celebrates your wins.",
            sample: "[excited, picking up pace] Okay so get this — [leaning in] your data from this week is actually kind of incredible. [genuine laugh] Seriously."
        ),
    ]

    var body: some View {
        ZStack {
            LinearColors.Minimal.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top section with drag bar + progress
                VStack(spacing: 24) {
                    if onExit != nil {
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(LinearColors.Minimal.textTertiary.opacity(0.3))
                            .frame(width: 36, height: 5)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if value.translation.height > 0 {
                                            dragOffset = value.translation.height
                                        }
                                    }
                                    .onEnded { value in
                                        if value.translation.height > 100 {
                                            onExit?()
                                        } else {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                                dragOffset = 0
                                            }
                                        }
                                    }
                            )
                    }

                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(LinearColors.Minimal.textTertiary.opacity(0.2))
                                .frame(height: 3)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(LinearColors.Minimal.accent)
                                .frame(width: geometry.size.width * (CGFloat(currentStep) / CGFloat(totalSteps)), height: 3)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
                        }
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 40)
                }
                .padding(.horizontal, 40)
                .padding(.top, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        HStack(spacing: 6) {
                            Image(systemName: "waveform")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(LinearColors.Minimal.textTertiary)
                            Text("Voice Persona")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(LinearColors.Minimal.textTertiary)
                        }
                        .padding(.top, 32)

                        Text("Choose Your\nPodcast Voice")
                            .font(.custom("HedvigLettersSerif-24ptRegular", size: 34))
                            .foregroundColor(LinearColors.Minimal.textPrimary)

                        Text("This is who speaks to you each week. Pick the voice that feels right.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(LinearColors.Minimal.textSecondary)
                            .opacity(bodyTextAnimating ? 1 : 0.3)
                            .offset(y: bodyTextAnimating ? 0 : 10)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: bodyTextAnimating)

                        // Persona cards
                        VStack(spacing: 12) {
                            ForEach(Array(personas.enumerated()), id: \.element.id) { index, persona in
                                PersonaCard(
                                    name: persona.name,
                                    icon: persona.icon,
                                    description: persona.description,
                                    sample: persona.sample,
                                    isSelected: selectedPersona == persona.id,
                                    onSelect: {
                                        let impact = UIImpactFeedbackGenerator(style: .medium)
                                        impact.impactOccurred(intensity: 0.7)
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedPersona = persona.id
                                        }
                                    }
                                )
                                .opacity(cardsAppeared ? 1 : 0)
                                .offset(y: cardsAppeared ? 0 : 20)
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.8)
                                        .delay(Double(index) * 0.1 + 0.2),
                                    value: cardsAppeared
                                )
                            }
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 40)
                }

                // Continue button
                VStack(spacing: 16) {
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred(intensity: 0.8)
                        saveAndContinue()
                    }) {
                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isSaving ? "Saving..." : "Continue")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearColors.Minimal.accent)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isSaving)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
            .offset(y: dragOffset)
            .opacity(1.0 - (dragOffset / 500))
        }
        .onAppear {
            bodyTextAnimating = true
            cardsAppeared = true
        }
    }

    private func saveAndContinue() {
        // Save locally immediately
        UserDefaults.standard.set(selectedPersona, forKey: "voice_persona")

        guard RetrospectAPIClient.shared.isAuthenticated else {
            onNext()
            return
        }

        isSaving = true
        Task {
            do {
                try await RetrospectAPIClient.shared.setVoicePersona(selectedPersona)
            } catch {
                print("Failed to save persona to backend: \(error.localizedDescription)")
                // Non-blocking — continue anyway, will sync later
            }
            await MainActor.run {
                isSaving = false
                onNext()
            }
        }
    }
}

// MARK: - Persona Card

private struct PersonaCard: View {
    let name: String
    let icon: String
    let description: String
    let sample: String
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isExpanded = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? LinearColors.Minimal.accent.opacity(0.15) : LinearColors.Minimal.backgroundCard)
                            .frame(width: 40, height: 40)

                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(isSelected ? LinearColors.Minimal.accent : LinearColors.Minimal.textTertiary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(LinearColors.Minimal.textPrimary)

                        Text(description)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(LinearColors.Minimal.textSecondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    // Selection indicator
                    ZStack {
                        Circle()
                            .strokeBorder(
                                isSelected ? LinearColors.Minimal.accent : LinearColors.Minimal.textTertiary.opacity(0.3),
                                lineWidth: 2
                            )
                            .frame(width: 22, height: 22)

                        if isSelected {
                            Circle()
                                .fill(LinearColors.Minimal.accent)
                                .frame(width: 12, height: 12)
                        }
                    }
                }

                // Sample text preview (always visible when selected)
                if isSelected {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preview")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                            .textCase(.uppercase)

                        Text(sample)
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundColor(LinearColors.Minimal.textSecondary.opacity(0.8))
                            .lineSpacing(4)
                    }
                    .padding(.top, 4)
                    .padding(.leading, 52) // Align with text, not icon
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearColors.Minimal.backgroundCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isSelected ? LinearColors.Minimal.accent.opacity(0.6) : LinearColors.Minimal.border,
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    DarkVoicePersonaOnboardingScreen(
        currentStep: 8,
        totalSteps: 11,
        onNext: { print("Next") },
        onExit: nil
    )
}
