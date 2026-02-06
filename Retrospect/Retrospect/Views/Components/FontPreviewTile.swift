import SwiftUI

// === FONT PREVIEW TILE ===
// Demonstrates EB Garamond title with SF Pro Rounded subtitle

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
                    .font(.custom("EBGaramond12-Regular", size: 18))
                    .foregroundColor(LinearColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("EB Garamond title with SF Pro Rounded subtitle")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
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
