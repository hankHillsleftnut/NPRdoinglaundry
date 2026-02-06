//
//  TerraCottaPillButtonStyle.swift
//  Retrospect fina (SwiftUI)
//
//  Created by Shaurya Narang on 5/13/25.
//
import SwiftUI

// Authentic Terra-Cotta Pill Button Style
struct TerraCottaPillButtonStyle: ButtonStyle {
    var isDisabled: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.serifCaption)
            .foregroundColor(isDisabled ? LinearColors.disabledText : LinearColors.buttonText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isDisabled ? LinearColors.disabledBackground : LinearColors.terraCottaPrimary)
                    .overlay(
                        Capsule()
                            .stroke(
                                isDisabled ? LinearColors.disabledText : LinearColors.warmHighlight,
                                lineWidth: 0.5
                            )
                    )
            )
            .shadow(
                color: isDisabled ? Color.clear : LinearColors.terraCottaDark.opacity(0.3),
                radius: 4,
                x: 0,
                y: 2
            )
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .disabled(isDisabled)
    }
}
