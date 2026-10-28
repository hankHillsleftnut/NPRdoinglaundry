//
//  WhyInertFaces.swift
//  V2.podcasts.b · PC-3's controls that Paper draws but that have nothing behind them yet. Consistency
//  rule (DECISIONS.md 27 Oct): drawn exactly as Paper draws them, inert (no press feedback, no
//  dimming), and VoiceOver hears the label with the value "not available yet", the "correct this
//  part" pattern. When a destination exists the page swaps the face for the real control.
//
import SwiftUI

/// A wash pill as Paper draws it: "hear it" (1FY4-0: 32, 12 inline, 4 gap, 14 glyph, Geist sm
/// medium) and "not right" (1FXU-0: 36, 16 inline, 8 gap, 16 glyph, Geist md medium).
struct WhyInertPill: View {
    enum Size {
        case small, medium
    }

    let title: String
    let symbol: String
    var size: Size = .small

    var body: some View {
        HStack(spacing: size == .medium ? RDimension.space2 : RDimension.space1) {
            RSymbol(name: symbol, size: .small, glyphScale: size == .medium ? RSymbol.defaultGlyphScale : Self.smallGlyphScale)
            Text(title)
                .rText(size == .medium ? .playerHeaderTitle : .labelMedium)
                .foregroundStyle(RColor.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, size == .medium ? RDimension.space4 : RDimension.space3)
        .frame(height: size == .medium ? RDimension.sizeControlMedium : RDimension.sizeControlSmall)
        .background(RColor.surfaceWash, in: RShape.pill)
        .fixedSize()
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityValue(WhyThisIsHereModel.notAvailableYet)
    }

    /// Paper's 14 glyph in the 16 frame.
    static let smallGlyphScale: CGFloat = 0.72 // literal-ok: Paper 1FY6-0, 14 of 16 at 0.82
}

/// The header's back as Paper draws it (1FZI-0: a 32 wash circle, the chevron 11.3 tall, the
/// onboarding back's size; founder 26 Oct "Paper's chevron size"), in the 44 frame RIconButton uses.
struct WhyBackFace: View {
    /// The chevron's share of its 20 frame: the same value #199 adds as
    /// `RIconButton.backChevronGlyphScale` (adopt it when #199 merges).
    static let glyphScale: CGFloat = 0.66 // literal-ok: Paper 21CA-0 / 1FZJ-0, 11.3 of SF's 14 at 0.82

    var body: some View {
        RSymbol(name: "chevron.left", size: .regular, glyphScale: Self.glyphScale)
            .frame(width: RDimension.sizeControlSmall, height: RDimension.sizeControlSmall)
            .background(RColor.surfaceWash, in: Circle())
            .frame(width: RDimension.sizeControlDefault, height: RDimension.sizeControlDefault)
            .contentShape(Rectangle())
    }
}
