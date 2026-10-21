//
//  RComposer.swift
//  M14 C13: the compact composer (Paper c:composer/compact on "everything · latest", EX-1
//  share sheet "add why (optional)"; the dark file's copy). A 48 sunken field (RSunkenField),
//  a 40 lifted mic well first, then your words in SF 17. No send: the screen's own lit action
//  (save) sends. The Journal bar, where you talk or type to Retro, is the voice composer (C14).
//
//  Growth follows composer.md (Paper draws one line): the field grows with your words up to
//  size.composer.maxHeight, then scrolls inside. The corner is concentric with the well
//  (20 + 4 = 24), so at one line it is the drawn pill and it stays concentric as it grows.
//
import SwiftUI

struct RComposer: View {
    /// What VoiceOver calls the field ("add why"). The placeholder is a hint, read only by sight.
    let label: String
    let placeholder: String
    @Binding var text: String
    /// The mic well: talk instead of typing.
    var onMic: () -> Void = {}

    @FocusState private var focused: Bool
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The inset above and below the words: centres one 17/22.1 line in the 48 field.
    private static let textInset = (RDimension.sizeControlLarge - RTextStyle.body.size * RTextStyle.body.leading) / 2
    /// Concentric with the well: its radius plus the 4pt inset. Equals the pill at 48.
    private static let radius = RDimension.sizeComposerWell / 2 + RDimension.space1

    /// One line of body text at the current Dynamic Type size.
    private var lineHeight: CGFloat {
        RTextStyle.body.scaledSize(at: dynamicTypeSize) * RTextStyle.body.leading
    }

    /// The words grow to this, then scroll: size.composer.maxHeight at the default size (six lines),
    /// the same six lines at larger sizes.
    private var maxTextHeight: CGFloat {
        (RDimension.sizeComposerMaxHeight - 2 * Self.textInset) * lineHeight / (RTextStyle.body.size * RTextStyle.body.leading)
    }

    /// Keeps the well centred on the last line as the type grows (4 at the default size).
    private var wellBottomInset: CGFloat {
        max(RDimension.space1, Self.textInset + (lineHeight - RDimension.sizeComposerWell) / 2)
    }

    var body: some View {
        RSunkenField(spacing: RDimension.space3, alignment: .bottom, radius: Self.radius) {
            micWell
                .padding(.top, RDimension.space1)
                .padding(.bottom, wellBottomInset)
        } content: {
            field
        } trailing: {
            EmptyView()
        }
        .overlay {
            // Increase Contrast: a 1pt border.control ring at rest (composer.md)
            if contrast == .increased {
                RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
                    .strokeBorder(RColor.borderControl, lineWidth: RDimension.sizeBorderDefault)
            }
        }
    }

    private var field: some View {
        TextField("", text: $text, axis: .vertical)
            .rText(.body)
            .frame(maxHeight: maxTextHeight)
            .foregroundStyle(RColor.textPrimary)
            // ink caret: accent.default reads 2.14 : 1 on surface.control (needs 3)
            .tint(RColor.textPrimary)
            .focused($focused)
            .accessibilityLabel(label)
            .overlay(alignment: .topLeading) {
                Text(placeholder)
                    .rText(.body)
                    .lineLimit(1)
                    .foregroundStyle(contrast == .increased ? RColor.textSecondary : RColor.textTertiary)
                    // fades out as the first character lands, back in when the field empties
                    .opacity(text.isEmpty ? 1 : 0)
                    .animation(RMotion.standard(RNumber.motionDurationInstant), value: text.isEmpty)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Self.textInset)
            // the whole field focuses, not only the line of text
            .contentShape(Rectangle())
            .onTapGesture { focused = true }
    }

    private var micWell: some View {
        Button(action: onMic) {
            // Paper's 18 mic, as the search field matches it (C12)
            RSymbol(name: "mic", weight: .medium, glyphScale: 0.74) // literal-ok: 18 × 0.82 in the 20 frame
                .frame(width: RDimension.sizeComposerWell, height: RDimension.sizeComposerWell)
                .background(RColor.surfaceLifted, in: Circle())
                .overlay(Circle().strokeBorder(RColor.depthStrokeOuter, lineWidth: RDimension.sizeBorderHairline))
                .shadow(color: RColor.depthShadowContact, radius: 0.75, y: 1) // literal-ok: Paper's contact shadow 0 1 1.5
                .contentShape(Circle().inset(by: (RDimension.sizeComposerWell - RDimension.sizeTouchTarget) / 2))
        }
        .rPress(small: true)
        .accessibilityLabel("talk instead")
    }
}

#if DEBUG
/// Every state Paper draws (rest with placeholder) plus the typing states composer.md asks for:
/// one line, grown to four, and past size.composer.maxHeight (scrolls inside).
struct RComposerGallery: View {
    @State private var empty = ""
    @State private var oneLine = "for the raise, the bit on angels"
    @State private var threeLines = "for the raise, the bit on angels. the part about warm intros and "
        + "how many to ask before the first yes is the bit i keep forgetting."
    @State private var long = String(
        repeating: "the angels section, the warm intros, and the bit on how to ask twice. ",
        count: 5
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space6) {
                RComposer(label: "add why", placeholder: "for the raise, the bit on angels…", text: $empty)
                RComposer(label: "add why", placeholder: "for the raise, the bit on angels…", text: $oneLine)
                RComposer(label: "add why", placeholder: "for the raise, the bit on angels…", text: $threeLines)
                RComposer(label: "add why", placeholder: "for the raise, the bit on angels…", text: $long)
            }
            .padding(RDimension.spaceScreenMargin)
        }
        .background(RColor.backgroundCanvas)
    }
}

#Preview("composer") { RComposerGallery() }
#endif
