import SwiftUI

struct AIReflectionStylePicker: View {
    @Binding var selectedType: GenerationType
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(GenerationType.allCases, id: \.self) { type in
                Button(action: {
                    selectedType = type
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: selectedType == type ? "largecircle.fill.circle" : "circle")
                            .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                            .foregroundColor(LinearColors.accent)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(type.displayName)
                                .font(.serifBody)
                                .foregroundColor(LinearColors.textPrimary)
                            
                            Text(type.description)
                                .font(.serifLabel)
                                .foregroundColor(LinearColors.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: BorderRadius.card)
                            .fill(selectedType == type ? LinearColors.accent.opacity(0.1) : LinearColors.inputBackground)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(20)
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
}

struct AIReflectionStylePicker_Previews: PreviewProvider {
    static var previews: some View {
        AIReflectionStylePicker(selectedType: .constant(.goodListener))
            .padding()
    }
} 