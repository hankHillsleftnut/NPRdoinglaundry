//
//  EnhancedTextField.swift
//  Retrospect fina (SwiftUI)
//
//  Created by Shaurya Narang on 5/13/25.
//

import SwiftUI

struct EnhancedTextField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState.Binding var isFocused: InputField?
    let field: InputField
    var showSendButton: Bool = false
    var isSendEnabled: Bool = false
    var onSend: (() -> Void)?

    private var isActive: Bool {
        isFocused == field
    }

    private var isOtherFieldActive: Bool {
        isFocused != nil && isFocused != field
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: BorderRadius.input)
                .fill(LinearColors.inputBackground)
                .shadow(
                    color: Shadows.inputShadow.color,
                    radius: Shadows.inputShadow.radius,
                    x: Shadows.inputShadow.x,
                    y: Shadows.inputShadow.y
                )

            // Separate stroke layer
            RoundedRectangle(cornerRadius: BorderRadius.input)
                .strokeBorder(
                    isActive ? LinearColors.inputFocusBorder :
                        (isOtherFieldActive ? LinearColors.inputBorder.opacity(0.5) : LinearColors.inputBorder),
                    lineWidth: isActive ? 2.0 : 1.0
                )

            Group {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.serifBody)
                        .foregroundColor(LinearColors.textPlaceholder.opacity(isOtherFieldActive ? 0.5 : 1.0))
                        .padding(.horizontal, Spacing.cardPadding)
                        .padding(.vertical, isOtherFieldActive ? Spacing.md : Spacing.cardPadding)
                        .allowsHitTesting(false)
                        .opacity(isActive ? 0.6 : 1)
                        .animation(Animations.focusTransition, value: isFocused)
                }
            }

            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .font(.serifBody)
                .foregroundColor(LinearColors.textPrimary)
                .opacity(isOtherFieldActive ? 0.7 : 1)
                .padding(.horizontal, Spacing.cardPadding)
                .padding(.vertical, isOtherFieldActive ? Spacing.md : Spacing.cardPadding)
                .padding(.trailing, showSendButton ? 52 : 0) // Make room for send button
                .focused($isFocused, equals: field)
                .lineSpacing(TypographySpacing.bodyLineSpacing)

            // Send Button - Bottom Right (overlaid inside text field)
            if showSendButton {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()

                        Button(action: {
                            HapticManager.shared.playMediumImpact()
                            onSend?()
                        }) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(isSendEnabled ? .white : LinearColors.textTertiary)
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            isSendEnabled
                                                ? LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        LinearColors.accent,
                                                        LinearColors.accent.opacity(0.9),
                                                    ]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                                : LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        LinearColors.cardBackground,
                                                        LinearColors.cardBackground,
                                                    ]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                        )
                                        .shadow(
                                            color: isSendEnabled ? LinearColors.accent.opacity(0.3) : Color.black.opacity(0.05),
                                            radius: isSendEnabled ? 8 : 2,
                                            x: 0,
                                            y: isSendEnabled ? 4 : 1
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(
                                            isSendEnabled ? LinearColors.accent.opacity(0.2) : LinearColors.cardBorder,
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(!isSendEnabled)
                        .opacity(isSendEnabled ? 1.0 : 0.5)
                        .scaleEffect(isSendEnabled ? 1.0 : 0.95)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSendEnabled)
                        .padding(.trailing, 12)
                        .padding(.bottom, 12)
                    }
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { gesture in
                    if gesture.translation.height > 0, gesture.translation.width < 100 {
                        isFocused = nil
                        HapticManager.shared.playLightImpact()
                    }
                }
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    if !isActive {
                        HapticManager.shared.playLightImpact()
                    }
                }
        )
        .animation(.spring(response: 0.3), value: isFocused)
        .onChange(of: isFocused) { _, newValue in
            if newValue == field { // Field gained focus
                HapticManager.shared.playFocusChange()
            }
        }
    }
}
