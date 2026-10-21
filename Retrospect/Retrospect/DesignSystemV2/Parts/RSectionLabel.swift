//
//  RSectionLabel.swift
//  M14 S13: the section label above a group of rows ("on this iPhone", "your other
//  apps · see all"). Geist 12 medium, text.label, +0.01em, lowercase, 4pt above its
//  rows (settings-row.md; ON-6 and ST-3 boards).
//
import SwiftUI

struct RSectionLabel: View {
    let title: String
    /// An optional trailing link, e.g. "see all".
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .rText(.labelMedium)
                .foregroundStyle(RColor.textLabel)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: RDimension.space3)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .rText(.labelMedium)
                        .foregroundStyle(RColor.textLink)
                        // 44pt hit area around 12pt text without changing the label's layout (craft 1.7)
                        .contentShape(Rectangle().inset(by: -(RDimension.sizeTouchTarget - RDimension.fontSizeSm) / 2))
                }
                .rPress(small: true)
            }
        }
        .padding(.bottom, RDimension.space1)
    }
}

#if DEBUG
#Preview("section label") {
    VStack(alignment: .leading, spacing: RDimension.space6) {
        RSectionLabel(title: "on this iPhone")
        RSectionLabel(title: "your other apps", actionTitle: "see all") {}
    }
    .padding(RDimension.spaceScreenMargin)
}
#endif
