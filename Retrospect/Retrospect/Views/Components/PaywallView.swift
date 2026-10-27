//
//  PaywallView.swift
//  Retrospect
//
//  Created by Assistant on 1/30/25.
//

import SwiftUI

struct PaywallView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedPlan: SubscriptionPlan = .yearly
    @State private var isLoading = false

    private let benefits = [
        PaywallBenefit(
            icon: "brain.head.profile",
            title: "Advanced AI Insights",
            description: "Get deeper, more personalized reflections powered by advanced AI models"
        ),
        PaywallBenefit(
            icon: "doc.richtext",
            title: "Unlimited Transcripts",
            description: "Generate unlimited podcast-style summaries from your daily reflections"
        ),
        PaywallBenefit(
            icon: "waveform",
            title: "Premium Audio Quality",
            description: "High-quality AI voice synthesis with multiple voice options"
        ),
        PaywallBenefit(
            icon: "chart.line.uptrend.xyaxis",
            title: "Progress Tracking",
            description: "Track your personal growth with detailed analytics and insights over time"
        ),
        PaywallBenefit(
            icon: "cloud.fill",
            title: "Cloud Sync",
            description: "Sync your reflections and insights across all your devices seamlessly"
        ),
        PaywallBenefit(
            icon: "sparkles",
            title: "Early Access",
            description: "Be the first to try new features and AI capabilities before anyone else"
        ),
    ]

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    headerSection

                    // Benefits section is now the main feature
                    benefitsSection

                    pricingSection
                    ctaSection
                }
                .padding(.bottom, geometry.safeAreaInsets.bottom + 40)
            }
        }
        .background(paywallBackground)
        .navigationBarHidden(true)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Button(action: {
                    HapticManager.shared.playLightImpact()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.geistBody)
                        .foregroundColor(LinearColors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(LinearColors.cardBackground)
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(LinearColors.cardBorder.opacity(0.5), lineWidth: 1)
                        )
                }

                Spacer()

                // Smaller, subtle premium tag
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.geistCaption)
                        .foregroundColor(LinearColors.accent)

                    Text("Unlock Premium")
                        .geistBodyEmphasis()
                        .foregroundColor(LinearColors.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(LinearColors.accent.opacity(0.1))
                        .overlay(
                            Capsule()
                                .strokeBorder(LinearColors.accent.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, Spacing.containerMargin)
            .padding(.top, Spacing.md)
        }
        .padding(.bottom, Spacing.md)
    }

    // MARK: - Benefits Section

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Premium Features")
                    .geistTitle()
                    .foregroundColor(LinearColors.textPrimary)

                Text("Discover everything you'll unlock with premium access")
                    .geistBody()
                    .foregroundColor(LinearColors.textSecondary)
            }
            .padding(.horizontal, Spacing.containerMargin)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.lg) {
                    ForEach(benefits.indices, id: \.self) { index in
                        EnhancedBenefitCard(benefit: benefits[index])
                    }
                }
                .padding(.horizontal, Spacing.containerMargin)
            }
        }
        .padding(.bottom, Spacing.xxl)
    }

    // MARK: - Pricing Section

    private var pricingSection: some View {
        VStack(spacing: Spacing.lg) {
            Text("Choose Your Plan")
                .geistSubheadline()
                .foregroundColor(LinearColors.textSecondary)

            VStack(spacing: Spacing.md) {
                // Yearly Plan
                PricingCard(
                    plan: .yearly,
                    title: "Yearly",
                    price: "$139.99",
                    period: "per year",
                    savings: "Save 7%",
                    isSelected: selectedPlan == .yearly,
                    onSelect: {
                        HapticManager.shared.playSelectionChanged()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedPlan = .yearly
                        }
                    }
                )

                // Monthly Plan
                PricingCard(
                    plan: .monthly,
                    title: "Monthly",
                    price: "$12.99",
                    period: "per month",
                    savings: nil,
                    isSelected: selectedPlan == .monthly,
                    onSelect: {
                        HapticManager.shared.playSelectionChanged()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedPlan = .monthly
                        }
                    }
                )
            }
            .padding(.horizontal, Spacing.containerMargin)
        }
        .padding(.bottom, Spacing.xl)
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: Spacing.lg) {
            Button(action: startSubscription) {
                HStack(spacing: Spacing.sm) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "crown.fill")
                            .font(.geistBody)
                    }

                    Text(isLoading ? "Processing..." : "Start Premium")
                        .font(.geistBody)
                        .fontWeight(.semibold)
                }
                .foregroundColor(LinearColors.Minimal.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: BorderRadius.button)
                        .fill(LinearColors.accent)
                        .shadow(
                            color: LinearColors.accent.opacity(0.3),
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                )
            }
            .disabled(isLoading)
            .scaleEffect(isLoading ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isLoading)
            .padding(.horizontal, Spacing.containerMargin)

            VStack(spacing: 4) {
                Text("Cancel anytime • No commitments")
                    .font(.serifCaption)
                    .foregroundColor(LinearColors.textSecondary)

                Text("Terms of Service • Privacy Policy")
                    .font(.serifCaption)
                    .foregroundColor(LinearColors.accent)
                    .onTapGesture {
                        // Handle terms/privacy tap
                    }
            }
        }
        .padding(.bottom, Spacing.xl)
    }

    private var paywallBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                LinearColors.cardBackground,
                LinearColors.cardBackground.opacity(0.95),
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .edgesIgnoringSafeArea(.all)
    }

    // MARK: - Actions

    private func startSubscription() {
        HapticManager.shared.playMediumImpact()

        isLoading = true

        // TODO: Implement actual subscription logic here
        // This would typically involve StoreKit integration

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isLoading = false
            // Show success or handle subscription result
        }
    }
}

// MARK: - Benefit Card

struct BenefitCard: View {
    let benefit: PaywallBenefit

    var body: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(LinearColors.accent.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: benefit.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(LinearColors.accent)
            }

            VStack(spacing: 6) {
                Text(benefit.title)
                    .font(.geistBody)
                    .fontWeight(.semibold)
                    .foregroundColor(LinearColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(benefit.description)
                    .font(.serifCaption)
                    .foregroundColor(LinearColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(width: 160)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .fill(LinearColors.cardBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .strokeBorder(LinearColors.cardBorder.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Enhanced Benefit Card (Larger, More Prominent)

struct EnhancedBenefitCard: View {
    let benefit: PaywallBenefit

    var body: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                LinearColors.accent.opacity(0.2),
                                LinearColors.accent.opacity(0.1),
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .strokeBorder(LinearColors.accent.opacity(0.3), lineWidth: 1)
                    )

                Image(systemName: benefit.icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(LinearColors.accent)
            }

            VStack(spacing: Spacing.sm) {
                Text(benefit.title)
                    .geistBodyEmphasis()
                    .foregroundColor(LinearColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(benefit.description)
                    .geistCaption()
                    .foregroundColor(LinearColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
        }
        .frame(width: 200)
        .padding(Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            LinearColors.cardBackground,
                            LinearColors.cardBackground.opacity(0.98),
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(
                    color: Shadows.cardShadow.color,
                    radius: Shadows.cardShadow.radius,
                    x: Shadows.cardShadow.x,
                    y: Shadows.cardShadow.y
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .strokeBorder(LinearColors.cardBorder.opacity(0.6), lineWidth: 1)
        )
    }
}

// MARK: - Pricing Card

struct PricingCard: View {
    let plan: SubscriptionPlan
    let title: String
    let price: String
    let period: String
    let savings: String?
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.geistBody)
                            .fontWeight(.semibold)
                            .foregroundColor(LinearColors.textPrimary)

                        if let savings {
                            Text(savings)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(LinearColors.accent)
                                )
                        }
                    }

                    Text(period)
                        .font(.serifCaption)
                        .foregroundColor(LinearColors.textSecondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Text(price)
                        .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                        .foregroundColor(LinearColors.textPrimary)

                    ZStack {
                        Circle()
                            .fill(isSelected ? LinearColors.accent : LinearColors.cardBorder.opacity(0.3))
                            .frame(width: 20, height: 20)

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                        }
                    }
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: BorderRadius.card)
                    .fill(LinearColors.cardBackground)
                    .shadow(color: Color.black.opacity(isSelected ? 0.1 : 0.05), radius: isSelected ? 6 : 4, x: 0, y: isSelected ? 3 : 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BorderRadius.card)
                    .strokeBorder(
                        isSelected ? LinearColors.accent : LinearColors.cardBorder.opacity(0.5),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Models

struct PaywallBenefit {
    let icon: String
    let title: String
    let description: String
}

enum SubscriptionPlan: String, CaseIterable {
    case monthly
    case yearly

    var identifier: String {
        switch self {
        case .monthly: return "com.retrospect.premium.monthly"
        case .yearly: return "com.retrospect.premium.yearly"
        }
    }
}
