//
//  REvidenceRow.swift
//  M14 C32: the evidence row (Paper part 41 "why this is here", c:evidence-row/rest 1FYW-0;
//  reference §C32). Wherever Retro says something about you, these rows show where it came
//  from, one source each, in your own words. The settings row's shape: min 56, padding 12 / 16,
//  12 between parts; a 32 kind well, the date and kind in Geist 12 over one line of your words
//  in SF 14, and › to open. Rows press like every list row (RListRowStyle: surface.subtle). Rows sit in one grouped panel (REvidenceGroup), 1pt border.subtle
//  between them, never a stack of cards.
//
//  V2.goals.parts (GL-D8, shared with V2.you YO-D7/YO-D10): a row with nowhere to open (`action: nil`)
//  is the same row without the › and without a button: plain text for VoiceOver, no press. Paper
//  draws › on rows whose destination isn't drawn yet; no dead controls, so those rows say nothing more.
//
import SwiftUI

extension RTextStyle {
    /// Your words: SF 14, --tracking-card, leading snug (1FZ0-0).
    static let evidenceWords = RTextStyle(
        family: .text,
        size: RDimension.fontSizeMd,
        weight: .regular,
        tracking: RNumber.fontTrackingCard,
        leading: RTextStyle.textMd.leading,
        relativeTo: .subheadline
    )
}

struct REvidenceRow: View {
    /// What leads the row: `.kind` is the source's glyph in a wash well; `.number` is a search
    /// citation's number in the same 32 well (YO-2 c:source-result/rest 1G9P-0: mono 12, text.secondary,
    /// radius.default).
    enum Leading {
        case kind(symbol: String)
        case number(Int)
    }

    let leading: Leading
    /// The date and kind, "14 oct · your words".
    let meta: String
    /// One line of your words; truncates at default sizes, the full text is read aloud.
    let words: String
    /// On a tinted parent (a wash card, a sheet) the well lifts to surface.lifted.
    var onTint = false
    /// Opens the source. Nil: nowhere to open yet, so no ›, no button (V2.goals.parts).
    var action: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Whether the row opens something (draws › and is a button).
    var opens: Bool {
        action != nil
    }

    var body: some View {
        if let action {
            Button(action: action) {
                row
            }
            .buttonStyle(RListRowStyle())
            // one element: "14 oct, your words, <the full excerpt>, button"
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityText)
        } else {
            row
                // one element, read as text: "14 oct, your words, <the full excerpt>"
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityText)
        }
    }

    /// What VoiceOver reads for the row, either way: "14 oct, your words, <the full excerpt>".
    var accessibilityText: String {
        let lead = if case let .number(number) = leading {
            "source \(number), "
        } else {
            ""
        }
        return "\(lead)\(meta.replacingOccurrences(of: " · ", with: ", ")), \(words)"
    }

    private var row: some View {
        HStack(spacing: RDimension.space3) {
            leadingView
            VStack(alignment: .leading, spacing: RDimension.sizeBorderRing) {
                Text(meta)
                    .rText(.metaLine)
                    .foregroundStyle(RColor.textLabel)
                Text(words)
                    .rText(.evidenceWords)
                    .foregroundStyle(RColor.textPrimary)
                    // one line, ellipsis; at accessibility sizes two, never clipped mid-glyph
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            if opens {
                // Paper draws › at size.icon.chevron 14 in RSymbol's 16 frame
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

    @ViewBuilder private var leadingView: some View {
        switch leading {
        case let .kind(symbol):
            RIconWell(
                symbol: symbol,
                fill: onTint ? RColor.surfaceLifted : RColor.surfaceWash,
                // Paper draws the glyph at size.icon.inWell 18 in RSymbol's 20 frame
                glyphScale: RSymbol.defaultGlyphScale * RDimension.sizeIconInWell / RDimension.sizeIconDefault
            )
            .accessibilityHidden(true)
        case let .number(number):
            // a figure that counts, so mono (screen rules 4): the voice length's face
            Text(String(number))
                .rText(.voiceLength)
                .foregroundStyle(RColor.textSecondary)
                .frame(width: RDimension.sizeSourceIcon, height: RDimension.sizeSourceIcon)
                .background(onTint ? RColor.surfaceLifted : RColor.surfaceWash, in: RShape.rect(RDimension.radiusDefault))
                .accessibilityHidden(true)
        }
    }
}

/// One grouped panel of evidence rows (part 41): background.canvas, radius.panel, a 0.5
/// depth.stroke.outer edge, and a 1pt border.subtle line between rows (not a 0.5 hairline).
/// Increase Contrast: the line becomes border.strong.
struct REvidenceGroup<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RShape.rect(RDimension.radiusPanel)
        VStack(spacing: RDimension.space0) {
            Group(subviews: content) { rows in
                ForEach(rows) { row in
                    if row.id != rows.first?.id {
                        (contrast == .increased ? RColor.borderStrong : RColor.borderSubtle)
                            .frame(height: RDimension.sizeBorderDefault)
                            .accessibilityHidden(true)
                    }
                    row
                }
            }
        }
        .background(RColor.backgroundCanvas)
        .clipShape(shape)
        .overlay(shape.stroke(RColor.depthStrokeOuter, lineWidth: RDimension.sizeBorderHairline))
    }
}

#if DEBUG
/// Lab page "evidence": part 41's three rows, a long excerpt, a tinted parent.
struct REvidenceRowGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space6) {
                VStack(alignment: .leading, spacing: RDimension.space2) {
                    caption("what it rests on")
                    REvidenceGroup {
                        REvidenceRow(leading: .kind(symbol: "doc.text"), meta: "14 oct · your words", words: "up at 6:40, a long focused morning") {}
                        REvidenceRow(leading: .kind(symbol: "doc.text"), meta: "16 oct · your words", words: "\"felt sharp before anyone was online\"") {}
                        REvidenceRow(leading: .kind(symbol: "calendar"), meta: "17 oct · calendar", words: "ran at 7, then shipped the deck") {}
                    }
                }
                VStack(alignment: .leading, spacing: RDimension.space2) {
                    caption("a long excerpt truncates")
                    REvidenceGroup {
                        REvidenceRow(
                            leading: .kind(symbol: "doc.text"),
                            meta: "16 oct · your words",
                            words: "\"felt sharp before anyone was online, then the afternoon went to meetings again\""
                        ) {}
                    }
                }
                VStack(alignment: .leading, spacing: RDimension.space2) {
                    caption("nowhere to open yet: no ›, not a button")
                    REvidenceGroup {
                        REvidenceRow(leading: .kind(symbol: "calendar"), meta: "tue 14 oct · calendar", words: "2 hours of deep work")
                        REvidenceRow(leading: .kind(symbol: "doc.text"), meta: "fri 17 oct · your words", words: "\"finally fixed the sync bug\"") {}
                    }
                }
                VStack(alignment: .leading, spacing: RDimension.space2) {
                    caption("search citations (YO-2)")
                    REvidenceGroup {
                        REvidenceRow(leading: .number(1), meta: "apple health · 14 nights", words: "you slept 40 min longer after a run")
                        REvidenceRow(leading: .number(2), meta: "journal · 3 entries", words: "\"stopped at 8, slept like a rock\"") {}
                    }
                }
                VStack(alignment: .leading, spacing: RDimension.space2) {
                    caption("on a tinted parent")
                    REvidenceGroup {
                        REvidenceRow(leading: .kind(symbol: "calendar"), meta: "17 oct · calendar", words: "ran at 7, then shipped the deck", onTint: true) {}
                    }
                    .padding(RDimension.space4)
                    .background(RColor.surfaceWash, in: RShape.rect(RDimension.radiusCard))
                }
            }
            .padding(RDimension.spaceScreenMargin)
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text).rText(.label).foregroundStyle(RColor.textLabel)
    }
}

#Preview("evidence row") { REvidenceRowGallery() }
#endif
