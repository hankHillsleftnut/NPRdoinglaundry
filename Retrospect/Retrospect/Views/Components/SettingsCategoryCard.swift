import SwiftUI

// === SETTINGS CATEGORY CARD - Apple-Inspired Navigation ===
// Clean category cards for main settings navigation with reduced information density

struct SettingsCategoryCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon container
                ZStack {
                    Circle()
                        .fill(LinearColors.accent.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(LinearColors.accent)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                        .foregroundColor(LinearColors.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    Text(subtitle)
                        .font(.serifLabel)
                        .foregroundColor(LinearColors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(LinearColors.textTertiary)
            }
            .padding(Spacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: BorderRadius.card)
                    .fill(LinearColors.cardBackground)
                    .shadow(
                        color: Shadows.cardShadow.color,
                        radius: Shadows.cardShadow.radius,
                        x: Shadows.cardShadow.x,
                        y: Shadows.cardShadow.y
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: BorderRadius.card)
                            .stroke(LinearColors.cardBorder, lineWidth: BorderWidth.standard)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Settings Group Component
struct SettingsGroup<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Group header
            HStack {
                Text(title)
                    .font(.serifLabel)
                    .foregroundColor(LinearColors.textSecondary)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, Spacing.containerMargin)
            
            // Group content
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: BorderRadius.card)
                    .fill(LinearColors.cardBackground)
                    .shadow(
                        color: Shadows.cardShadow.color,
                        radius: Shadows.cardShadow.radius,
                        x: Shadows.cardShadow.x,
                        y: Shadows.cardShadow.y
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: BorderRadius.card)
                            .stroke(LinearColors.cardBorder, lineWidth: BorderWidth.standard)
                    )
            )
            .padding(.horizontal, Spacing.containerMargin)
        }
    }
}

// MARK: - Settings Row Component
struct SettingsRow: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let showChevron: Bool
    let action: (() -> Void)?
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        showChevron: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.showChevron = showChevron
        self.action = action
    }
    
    var body: some View {
        Button(action: action ?? {}) {
            HStack(spacing: 12) {
                // Optional icon
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(LinearColors.accent)
                        .frame(width: 24, height: 24)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.geistBody).kerning(TypographyKerning.bodyKerning)
                        .foregroundColor(LinearColors.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.serifCaption)
                            .foregroundColor(LinearColors.textSecondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Optional chevron
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(LinearColors.textTertiary)
                }
            }
            .padding(.horizontal, Spacing.cardPadding)
            .padding(.vertical, 14)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(action == nil)
    }
}

// MARK: - Settings Toggle Row
struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    let icon: String?
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Optional icon
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(LinearColors.accent)
                    .frame(width: 24, height: 24)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.geistBody).kerning(TypographyKerning.bodyKerning)
                    .foregroundColor(LinearColors.textPrimary)
                    .multilineTextAlignment(.leading)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.serifCaption)
                        .foregroundColor(LinearColors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .scaleEffect(0.9)
        }
        .padding(.horizontal, Spacing.cardPadding)
        .padding(.vertical, 14)
    }
}

#Preview {
    VStack(spacing: 20) {
        SettingsCategoryCard(
            title: "Profile & Personalization",
            subtitle: "AI style and research preferences",
            icon: "person.crop.circle.fill"
        ) {
            print("Tapped Profile")
        }
        
        SettingsGroup(title: "Example Group") {
            SettingsRow(
                title: "Example Setting",
                subtitle: "This is a subtitle",
                icon: "gear",
                showChevron: true
            ) {
                print("Tapped setting")
            }
            
            Divider()
                .background(LinearColors.cardBorder)
            
            SettingsToggleRow(
                title: "Toggle Setting",
                subtitle: "Enable this feature",
                icon: "switch.2",
                isOn: .constant(true)
            )
        }
    }
    .padding()
    .background(LinearColors.background)
}
