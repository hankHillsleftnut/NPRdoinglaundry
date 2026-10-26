//
//  PlayerSheetHeader.swift
//  PS.sheet.a: the player sheet's header row (Paper ON-11 26PF-0): the 22 mark, the episode's title
//  on one line, and on the right share and collapse as 34 wash circles 8 apart. Share has no drawn
//  destination, so its place is kept empty (QUESTION Q3); collapse hands the sheet back.
//
import SwiftUI

extension RTextStyle {
    /// The player header's title (Paper 26PP-0: Geist text-md medium, leading snug, no tracking).
    static let playerHeaderTitle = RTextStyle(
        family: .label,
        size: RDimension.fontSizeMd,
        weight: .medium,
        tracking: RNumber.fontTrackingNone,
        leading: 1.3,
        relativeTo: .subheadline
    )
}

struct PlayerSheetHeader: View {
    let title: String
    let onCollapse: () -> Void

    /// A 34 circle sits in a 44 hit frame: this much of the frame hangs past the circle on each side,
    /// taken back so the circles land where Paper puts them (8 apart, on the 28 inset, a 34 row).
    private static let overhang = (RDimension.sizeTouchTarget - RDimension.sizePlayerHeaderButton) / 2

    var body: some View {
        HStack(spacing: RDimension.space2) {
            RMark.header
            Text(title)
                .rText(.playerHeaderTitle)
                .foregroundStyle(RColor.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: RDimension.space2)
            HStack(spacing: RDimension.space2 - Self.overhang) {
                // share (26PK-0): no destination drawn yet, so nothing to tap; the place stays
                Color.clear
                    .frame(width: RDimension.sizePlayerHeaderButton, height: RDimension.sizePlayerHeaderButton)
                    .accessibilityHidden(true)
                RIconButton(symbol: "chevron.down", label: "collapse", role: .sheetHeader, action: onCollapse)
                    .accessibilityHint("closes the player")
                    .accessibilityIdentifier("player.collapse")
                    .padding(.vertical, -Self.overhang)
            }
            .padding(.trailing, -Self.overhang)
        }
        .frame(minHeight: RDimension.sizePlayerHeaderButton)
    }
}
