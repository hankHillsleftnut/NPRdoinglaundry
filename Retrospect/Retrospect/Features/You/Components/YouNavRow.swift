//
//  YouNavRow.swift
//  V2.you: the rows inside the You tab's grouped panels (Paper YO-1 1G6S-0 / 1G6M-0, YO-3 1GB2-0 / 1GAW-0).
//  Paper names them c:settings-row/nav, but draws them in a panel, not on the page like RSettingsRow
//  (part 22): min 56, padding 12 / 16, 12 between parts, the title SF 14 medium over a Geist 12 subline
//  2 apart, and a 14 › in icon.muted (DISCREPANCIES YO-D22). They sit in an `REvidenceGroup` panel.
//  Paper draws the › on every one; with no action yet the row is drawn the same but inert (consistency
//  rule 27 Oct). Pressed: surface.subtle, as every list row.
//
import SwiftUI

struct YouNavRow: View {
    let title: String
    let subline: String
    /// nil: what the row opens isn't there yet, so it is drawn as Paper but inert.
    var action: (() -> Void)?

    var body: some View {
        Button { action?() } label: { label }
            .buttonStyle(RListRowStyle())
            .accessibilityElement(children: .combine)
            .youInert(action == nil)
    }

    private var label: some View {
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
            // Paper draws › at size.icon.chevron 14 in RSymbol's 16 frame (as REvidenceRow)
            RSymbol(
                name: "chevron.right",
                size: .small,
                tint: RColor.iconMuted,
                glyphScale: RSymbol.defaultGlyphScale * RDimension.sizeIconChevron / RDimension.sizeIconSmall
            )
        }
        .padding(.vertical, RDimension.space3)
        .padding(.horizontal, RDimension.space4)
        .frame(maxWidth: .infinity, minHeight: RDimension.sizeRowDefault)
        .contentShape(Rectangle())
    }
}
