//
//  YouNavRow.swift
//  V2.you: the rows inside the You tab's grouped panels (Paper YO-1 1G6S-0 / 1G6M-0, YO-3 1GB2-0 / 1GAW-0).
//  Paper names them c:settings-row/nav, but draws them in a panel, not on the page like RSettingsRow
//  (part 22): min 56, padding 12 / 16, 12 between parts, the title SF 14 medium over a Geist 12 subline
//  2 apart, and a 14 › in icon.muted (DISCREPANCIES YO-D22). They sit in an `REvidenceGroup` panel.
//  With an action the row is a button and shows ›; without one (what it opens isn't drawn, YO-D10)
//  it is plain text with no ›. Pressed: surface.subtle, as every list row.
//
import SwiftUI

struct YouNavRow: View {
    let title: String
    let subline: String
    /// nil: the row opens nothing yet, so it isn't a button and shows no ›.
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { label(chevron: true) }
                .buttonStyle(RListRowStyle())
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
        } else {
            label(chevron: false)
                .accessibilityElement(children: .combine)
        }
    }

    private func label(chevron: Bool) -> some View {
        HStack(spacing: RDimension.space3) {
            VStack(alignment: .leading, spacing: RDimension.sizeBorderRing) {
                Text(title)
                    .rText(.textMdMedium)
                    .foregroundStyle(RColor.textPrimary)
                Text(subline)
                    .rText(.metaLine)
                    .foregroundStyle(RColor.textLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            if chevron {
                // Paper draws › at size.icon.chevron 14 in RSymbol's 16 frame (as REvidenceRow)
                RSymbol(
                    name: "chevron.right",
                    size: .small,
                    tint: RColor.iconMuted,
                    glyphScale: RSymbol.defaultGlyphScale * RDimension.sizeIconChevron / RDimension.sizeIconSmall
                )
            }
        }
        .padding(.vertical, RDimension.space3)
        .padding(.horizontal, RDimension.space4)
        .frame(maxWidth: .infinity, minHeight: RDimension.sizeRowDefault)
        .contentShape(Rectangle())
    }
}
