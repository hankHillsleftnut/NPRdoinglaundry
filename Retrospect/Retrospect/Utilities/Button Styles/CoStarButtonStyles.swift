import SwiftUI

// === WARM TERRA-COTTA BUTTON SYSTEM ===
// Organic, warm terra-cotta buttons with cream and white accents

/// === PRIMARY BUTTON (Terra-cotta with white text) ===
struct CoStarPrimaryButton: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.serifButton)
            .foregroundColor(isDisabled ? LinearColors.disabledText : LinearColors.buttonText)
            .padding(.horizontal, Spacing.buttonPaddingH)
            .padding(.vertical, Spacing.buttonPaddingV)
            .background(
                RoundedRectangle(cornerRadius: BorderRadius.button)
                    .fill(isDisabled ? LinearColors.disabledBackground : LinearColors.buttonBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: BorderRadius.button)
                            .stroke(
                                isDisabled ? LinearColors.disabledText : LinearColors.buttonBorder,
                                lineWidth: 1.5
                            )
                    )
            )
            .shadow(
                color: isDisabled ? Color.clear : Shadows.buttonShadow.color,
                radius: Shadows.buttonShadow.radius,
                x: Shadows.buttonShadow.x,
                y: Shadows.buttonShadow.y
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(Animations.buttonPress, value: configuration.isPressed)
            .disabled(isDisabled)
            .onChange(of: configuration.isPressed) { _, newValue in
                if newValue, !isDisabled {
                    HapticManager.shared.playMediumImpact() // Enhanced for primary actions
                }
            }
    }
}

/// === SECONDARY BUTTON (White with terra-cotta border) ===
struct CoStarSecondaryButton: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.serifButton)
            .foregroundColor(isDisabled ? LinearColors.disabledText : LinearColors.buttonSecondaryText)
            .padding(.horizontal, Spacing.buttonPaddingH)
            .padding(.vertical, Spacing.buttonPaddingV)
            .background(
                RoundedRectangle(cornerRadius: BorderRadius.button)
                    .fill(isDisabled ? LinearColors.disabledBackground : LinearColors.buttonSecondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: BorderRadius.button)
                            .stroke(
                                isDisabled ? LinearColors.disabledText : LinearColors.buttonSecondaryBorder,
                                lineWidth: 1.5
                            )
                    )
            )
            .shadow(
                color: isDisabled ? Color.clear : Shadows.inputShadow.color,
                radius: Shadows.inputShadow.radius,
                x: Shadows.inputShadow.x,
                y: Shadows.inputShadow.y
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(Animations.buttonPress, value: configuration.isPressed)
            .disabled(isDisabled)
            .onChange(of: configuration.isPressed) { _, newValue in
                if newValue, !isDisabled {
                    HapticManager.shared.playSoftImpact()
                }
            }
    }
}

/// === PILL BUTTON (Terra-cotta pill shape for tags/chips) ===
struct CoStarPillButton: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.serifCaption)
            .foregroundColor(isDisabled ? LinearColors.disabledText : LinearColors.buttonText)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(isDisabled ? LinearColors.disabledBackground : LinearColors.buttonBackground)
                    .overlay(
                        Capsule()
                            .stroke(
                                isDisabled ? LinearColors.disabledText : LinearColors.buttonBorder,
                                lineWidth: 1
                            )
                    )
            )
            .shadow(
                color: isDisabled ? Color.clear : Shadows.buttonShadow.color,
                radius: Shadows.buttonShadow.radius * 0.7,
                x: Shadows.buttonShadow.x,
                y: Shadows.buttonShadow.y * 0.7
            )
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(Animations.buttonPress, value: configuration.isPressed)
            .disabled(isDisabled)
            .onChange(of: configuration.isPressed) { _, newValue in
                if newValue, !isDisabled {
                    HapticManager.shared.playLightImpact()
                }
            }
    }
}

/// === MINIMAL BUTTON (Text only with cool hover) ===
struct CoStarMinimalButton: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.serifBody)
            .foregroundColor(isDisabled ? LinearColors.disabledText : LinearColors.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: BorderRadius.small)
                    .fill(configuration.isPressed ? LinearColors.pressedState : Color.clear)
            )
            .animation(Animations.buttonPress, value: configuration.isPressed)
            .disabled(isDisabled)
            .onChange(of: configuration.isPressed) { _, newValue in
                if newValue, !isDisabled {
                    HapticManager.shared.playLightImpact()
                }
            }
    }
}

/// === ICON BUTTON (Rounded terra-cotta button for icons) ===
struct CoStarIconButton: ButtonStyle {
    var isDisabled: Bool = false
    var size: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isDisabled ? LinearColors.disabledText : LinearColors.buttonText)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: BorderRadius.button)
                    .fill(isDisabled ? LinearColors.disabledBackground : LinearColors.buttonBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: BorderRadius.button)
                            .stroke(
                                isDisabled ? LinearColors.disabledText : LinearColors.buttonBorder,
                                lineWidth: 1
                            )
                    )
            )
            .shadow(
                color: isDisabled ? Color.clear : Shadows.buttonShadow.color,
                radius: Shadows.buttonShadow.radius * 0.7,
                x: Shadows.buttonShadow.x,
                y: Shadows.buttonShadow.y * 0.7
            )
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(Animations.buttonPress, value: configuration.isPressed)
            .disabled(isDisabled)
            .onChange(of: configuration.isPressed) { _, newValue in
                if newValue, !isDisabled {
                    HapticManager.shared.playLightImpact()
                }
            }
    }
}
