//
//  EnhancedSingleLineTextField.swift
//  Retrospect fina (SwiftUI)
//
//  Created by Shaurya Narang on 5/13/25.
//

import SwiftUI

/// Enhanced Single Line Text Field
struct EnhancedSingleLineTextField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: BorderRadius.input)
                .fill(LinearColors.inputBackground)
                .shadow(
                    color: Shadows.inputShadow.color,
                    radius: Shadows.inputShadow.radius,
                    x: Shadows.inputShadow.x,
                    y: Shadows.inputShadow.y
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BorderRadius.input)
                        .stroke(isFocused ? LinearColors.inputFocusBorder : LinearColors.inputBorder, lineWidth: isFocused ? 2 : 1)
                )

            TextField("", text: $text)
                .placeholder(when: text.isEmpty) {
                    Text(placeholder)
                        .font(.serifBody)
                        .foregroundColor(LinearColors.textPlaceholder)
                }
                .padding(.horizontal, Spacing.cardPadding)
                .padding(.vertical, Spacing.md)
                .focused($isFocused)
                .font(.serifBody)
                .foregroundColor(LinearColors.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(height: Spacing.inputHeight)
        .animation(Animations.focusTransition, value: isFocused)
    }
}
