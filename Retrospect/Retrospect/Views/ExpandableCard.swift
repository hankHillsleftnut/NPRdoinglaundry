//
//  ExpandableCard.swift
//  Retrospect fina (SwiftUI)
//
//  Created by Shaurya Narang on 5/13/25.
//

import SwiftUI

struct ExpandableCard: View {
    let title: String
    let content: String
    @State private var isExpanded: Bool = true
    @State private var contentHeight: CGFloat = .zero
    @State private var chevronRotation: Double = 180

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.3)) {
                    isExpanded.toggle()
                    chevronRotation = isExpanded ? 180 : 0
                }
            }) {
                HStack {
                    Text(title)
                        .font(.geistTitle).kerning(TypographyKerning.titleKerning)
                        .foregroundColor(LinearColors.primaryText)

                    Spacer()

                    Image(systemName: "chevron.down.circle.fill")
                        .foregroundColor(LinearColors.accent)
                        .font(.system(size: 20, weight: .semibold))
                        .rotationEffect(.degrees(chevronRotation))
                }
            }

            if isExpanded {
                // Content
                Text(.init(content))
                    .font(.geistBody).kerning(TypographyKerning.bodyKerning)
                    .foregroundColor(LinearColors.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .transition(
                        .asymmetric(
                            insertion: AnyTransition.opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .top)),
                            removal: AnyTransition.opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .top))
                        )
                    )
                    .padding(.vertical, 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .fill(LinearColors.inputBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 5)
                .scaleEffect(isExpanded ? 1 : 0.98)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isExpanded)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isExpanded)
    }
}
