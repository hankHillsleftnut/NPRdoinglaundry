import SwiftUI

// === FONT PREVIEW TILE ===
// Demonstrates Hedvig title with SF Pro Display subtitle

struct FontPreviewTile: View {
    var body: some View {
        HStack(spacing: 16) {
            // Font Icon
            Image(systemName: "textformat")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(LinearColors.accent)
                .frame(width: 24, height: 24)
            
            // Font Content
            VStack(alignment: .leading, spacing: 4) {
                Text("Font Preview")
                    .font(.custom("HedvigLettersSerif-24ptRegular", size: 18))
                    .foregroundColor(LinearColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Hedvig title with SF Pro Display subtitle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(LinearColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .fill(LinearColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: BorderRadius.card)
                        .stroke(LinearColors.cardBorder, lineWidth: 1)
                )
        )
    }
}

#Preview {
    FontPreviewTile()
        .padding()
        .background(LinearColors.background)
}
