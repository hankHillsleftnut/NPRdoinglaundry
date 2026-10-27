//
//  WhiteSquareButtonStyle.swift
//  Retrospect fina (SwiftUI)
//
//  Created by Shaurya Narang on 5/13/25.
//

import SwiftUI

/// Clean white button style for cool design system
struct WhiteSquareButtonStyle: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: BorderRadius.card)
                    .fill(LinearColors.cardBackground)
                    .shadow(
                        color: Shadows.cardShadow.color,
                        radius: Shadows.cardShadow.radius,
                        x: Shadows.cardShadow.x,
                        y: Shadows.cardShadow.y
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            .opacity(isDisabled ? 0.6 : 1.0)
    }
}
