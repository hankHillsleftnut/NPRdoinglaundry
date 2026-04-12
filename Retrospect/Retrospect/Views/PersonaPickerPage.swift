//
//  PersonaPickerPage.swift
//  Retrospect
//
//  Full-page persona selection for onboarding.
//  Shows three podcast host voices as vertical cards with richer
//  descriptions, then saves the choice and advances.
//

import SwiftUI

struct PersonaPickerPage: View {
    @ObservedObject var state: OnboardingState
    var onComplete: () -> Void

    @AppStorage("voice_persona") private var voicePersona: String = "thoughtful_friend"
    @State private var selectedPersona: String = "thoughtful_friend"
    @State private var contentOpacity: Double = 0

    private struct PersonaOption: Identifiable {
        let id: String
        let name: String
        let icon: String
        let tagline: String
        let description: String
    }

    private let personas: [PersonaOption] = [
        PersonaOption(
            id: "thoughtful_friend",
            name: "Thoughtful Friend",
            icon: "cup.and.saucer",
            tagline: "Warm and conversational",
            description: "Like catching up over coffee. Gentle, reflective, and genuinely curious about your week."
        ),
        PersonaOption(
            id: "wise_mentor",
            name: "Wise Mentor",
            icon: "graduationcap",
            tagline: "Calm and grounded",
            description: "Thoughtful and steady. Good for big-picture reflection — insights that land with weight."
        ),
        PersonaOption(
            id: "energetic_host",
            name: "Energetic Host",
            icon: "bolt",
            tagline: "Dynamic and direct",
            description: "Upbeat and motivating. Celebrates your wins and keeps the energy high."
        ),
    ]

    var body: some View {
        ZStack {
            LinearColors.Minimal.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Your podcast host")
                        .font(.custom("EBGaramond12-Italic", size: 36))
                        .foregroundColor(LinearColors.Minimal.textPrimary.opacity(0.85))

                    Text("Choose the voice that speaks to you each week.")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)

                Spacer()
                    .frame(height: 32)

                VStack(spacing: 12) {
                    ForEach(personas) { persona in
                        personaCard(persona)
                    }
                }
                .padding(.horizontal, 28)

                Spacer()

                Button(action: saveAndAdvance) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.buttonPrimaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(LinearColors.Minimal.accent)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 28)
                .padding(.bottom, 50)
            }
            .opacity(contentOpacity)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            selectedPersona = voicePersona
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                contentOpacity = 1
            }
        }
    }

    private func personaCard(_ persona: PersonaOption) -> some View {
        let isSelected = selectedPersona == persona.id

        return Button {
            HapticManager.shared.playLightImpact()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedPersona = persona.id
            }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? LinearColors.Minimal.accent.opacity(0.15) : LinearColors.Minimal.backgroundCard)
                        .frame(width: 48, height: 48)

                    Image(systemName: persona.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isSelected ? LinearColors.Minimal.accent : LinearColors.Minimal.textSecondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(persona.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textPrimary)

                    Text(persona.tagline)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(isSelected ? LinearColors.Minimal.accent.opacity(0.8) : LinearColors.Minimal.textTertiary)

                    Text(persona.description)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textSecondary.opacity(0.7))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(LinearColors.Minimal.accent)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearColors.Minimal.backgroundCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isSelected ? LinearColors.Minimal.accent.opacity(0.5) : LinearColors.Minimal.border.opacity(0.3),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func saveAndAdvance() {
        HapticManager.shared.playSuccessNotification()
        voicePersona = selectedPersona
        UserDefaults.standard.set(selectedPersona, forKey: "voice_persona")

        Task {
            if RetrospectAPIClient.shared.isAuthenticated {
                try? await RetrospectAPIClient.shared.setVoicePersona(selectedPersona)
            }
        }

        onComplete()
    }
}
