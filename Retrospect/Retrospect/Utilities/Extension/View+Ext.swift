//
//  View+Ext.swift
//  Retrospect fina (SwiftUI)
//
//  Created by Shaurya Narang on 5/13/25.
//

import SwiftUI

// MARK: - View Extensions
extension View {
    // MARK: - Card Styling
    func coStarCard() -> some View {
        self
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
    
    // MARK: - Button Style Modifiers
    func coStarPrimaryButton(isDisabled: Bool = false) -> some View {
        self.buttonStyle(CoStarPrimaryButton(isDisabled: isDisabled))
    }
    
    func coStarSecondaryButton(isDisabled: Bool = false) -> some View {
        self.buttonStyle(CoStarSecondaryButton(isDisabled: isDisabled))
    }
    
    func coStarPillButton(isDisabled: Bool = false) -> some View {
        self.buttonStyle(CoStarPillButton(isDisabled: isDisabled))
    }
    
    func coStarMinimalButton(isDisabled: Bool = false) -> some View {
        self.buttonStyle(CoStarMinimalButton(isDisabled: isDisabled))
    }
    
    func coStarIconButton(isDisabled: Bool = false) -> some View {
        self.buttonStyle(CoStarIconButton(isDisabled: isDisabled))
    }
}

// MARK: - Existing Extensions

// Placeholder View Extension
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
