import SwiftUI

struct EntryCard: View {
    let entry: Entry
    let onTap: () -> Void
    let onDelete: (() -> Void)?
    
    init(entry: Entry, onTap: @escaping () -> Void, onDelete: (() -> Void)? = nil) {
        self.entry = entry
        self.onTap = onTap
        self.onDelete = onDelete
    }
    
    var body: some View {
        Button(action: {
            HapticManager.shared.playLightImpact()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header: Title and Type Badge
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.displayTitle)
                            .font(.serifHeadline)
                            .fontWeight(.bold)
                            .foregroundColor(LinearColors.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        // Date & Time
                        Text(formattedDate)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(LinearColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Type Badge
                    typeBadge
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
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
            .overlay(
                RoundedRectangle(cornerRadius: BorderRadius.card)
                    .strokeBorder(LinearColors.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if let onDelete = onDelete {
                Button(role: .destructive, action: {
                    onDelete()
                }) {
                    Label("Delete", systemImage: "trash")
                }
            }
            
            Button(action: {
                shareEntry()
            }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }
    
    private var typeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: badgeIcon)
                .font(.system(size: 10, weight: .medium))
            Text(badgeText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundColor(badgeColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(badgeBackgroundColor)
        )
    }
    
    private var badgeIcon: String {
        switch entry.type {
        case .video:
            return "video.fill"
        case .voice:
            return "waveform"
        case .text:
            return "doc.text.fill"
        }
    }
    
    private var badgeText: String {
        switch entry.type {
        case .video:
            return "Video"
        case .voice:
            return "Voice"
        case .text:
            return "Text"
        }
    }
    
    private var badgeColor: Color {
        switch entry.type {
        case .video:
            return LinearColors.accent
        case .voice:
            return LinearColors.Minimal.iconPurple
        case .text:
            return LinearColors.textPrimary
        }
    }
    
    private var badgeBackgroundColor: Color {
        switch entry.type {
        case .video:
            return LinearColors.accent.opacity(0.15)
        case .voice:
            return LinearColors.Minimal.iconPurple.opacity(0.15)
        case .text:
            return LinearColors.cardBorder.opacity(0.5)
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(entry.date) {
            formatter.timeStyle = .short
            return "Today, \(formatter.string(from: entry.date))"
        } else if calendar.isDateInYesterday(entry.date) {
            formatter.timeStyle = .short
            return "Yesterday, \(formatter.string(from: entry.date))"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: entry.date)
        }
    }
    
    // MARK: - Actions
    private func shareEntry() {
        HapticManager.shared.playLightImpact()
        
        var shareText = entry.displayTitle
        if !entry.content.isEmpty {
            shareText += "\n\n\(entry.content)"
        }
        shareText += "\n\n— Retrospect Journal"
        
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            activityVC.popoverPresentationController?.sourceView = window
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            activityVC.popoverPresentationController?.permittedArrowDirections = []
            rootVC.present(activityVC, animated: true)
        }
    }
}

