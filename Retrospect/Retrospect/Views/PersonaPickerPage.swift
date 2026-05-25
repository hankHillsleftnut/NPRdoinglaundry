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
        OnboardingScaffold(
            iconName: "waveform",
            title: "Your podcast host",
            subtitle: "Choose the voice that should reflect your week back to you."
        ) {
            VStack(spacing: 12) {
                ForEach(personas) { persona in
                    personaCard(persona)
                }
            }
            .opacity(contentOpacity)
        } bottom: {
            OnboardingPrimaryButton(
                title: state.isSavingPersona ? "Saving..." : "Continue",
                isLoading: state.isSavingPersona,
                action: saveAndAdvance
            )
        }
        .onAppear {
            selectedPersona = voicePersona
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                contentOpacity = 1
            }
        }
    }

    private func personaCard(_ persona: PersonaOption) -> some View {
        let isSelected = selectedPersona == persona.id

        return OnboardingOptionRow(
            icon: persona.icon,
            title: persona.name,
            subtitle: "\(persona.tagline). \(persona.description)",
            status: nil,
            isSelected: isSelected,
            isLoading: false,
            isDisabled: false
        ) {
            HapticManager.shared.playLightImpact()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedPersona = persona.id
            }
        }
    }

    private func saveAndAdvance() {
        HapticManager.shared.playSuccessNotification()
        voicePersona = selectedPersona
        UserDefaults.standard.set(selectedPersona, forKey: "voice_persona")

        Task {
            await MainActor.run { state.isSavingPersona = true }
            if RetrospectAPIClient.shared.isAuthenticated {
                try? await RetrospectAPIClient.shared.setVoicePersona(selectedPersona)
            }
            await MainActor.run {
                state.isSavingPersona = false
                onComplete()
            }
        }
    }
}
