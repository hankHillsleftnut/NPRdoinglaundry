import SwiftUI

struct OnboardingPrivacyPage: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        OnboardingScaffold(
            iconName: "lock.fill",
            title: "How we think about privacy.",
            subtitle: "You choose what Retrospect can access. Your onboarding answers and connected sources are used to create reflections and podcasts for you, and only after you give permission."
        ) {
            VStack(alignment: .leading, spacing: 18) {
                privacyPoint(
                    icon: "checkmark.seal",
                    title: "Permission first",
                    body: "Google Docs, Health, and Screen Time stay off until you explicitly connect them."
                )

                privacyPoint(
                    icon: "sparkles",
                    title: "Used for your podcast",
                    body: "When you ask Retrospect to generate an episode, relevant onboarding context may be sent to our backend so the podcast can feel personal."
                )

                privacyPoint(
                    icon: "slider.horizontal.3",
                    title: "Always adjustable",
                    body: "You can skip sources during onboarding and change them later in Settings."
                )
            }
        } bottom: {
            OnboardingPrimaryButton(title: "Understood") {
                HapticManager.shared.playLightImpact()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    state.markPrivacyAcknowledged()
                }
            }
        }
    }

    private func privacyPoint(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(OnboardingStyle.bodyFont(size: 15, weight: .medium))
                .foregroundColor(OnboardingStyle.tertiaryText)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(OnboardingStyle.bodyFont(size: 15, weight: .medium))
                    .foregroundColor(OnboardingStyle.primaryText)

                Text(body)
                    .font(OnboardingStyle.bodyFont(size: 14))
                    .foregroundColor(OnboardingStyle.secondaryText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    OnboardingPrivacyPage(state: OnboardingState())
}
