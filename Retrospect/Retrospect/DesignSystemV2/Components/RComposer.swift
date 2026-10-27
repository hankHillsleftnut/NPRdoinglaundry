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

/// How a writing field grows (C13 composer, C14 voice composer): one line centred at rest,
/// then up to size.composer.maxHeight, then it scrolls inside. Follows Dynamic Type: the same
/// number of lines at every size, and the control beside the words stays on the last line.
struct RFieldGrowth {
    let style: RTextStyle
    /// The field's height at rest, holding one line.
    let restHeight: CGFloat

    private var baseLine: CGFloat {
        style.size * style.leading
    }

    /// Above and below the words: centres one line in the field at rest.
    var textInset: CGFloat {
        (restHeight - baseLine) / 2
    }

    /// One line at this Dynamic Type size.
    func lineHeight(at size: DynamicTypeSize) -> CGFloat {
        style.scaledSize(at: size) * style.leading
    }

    /// The words grow to this, then scroll (six lines of body at every size).
    func maxTextHeight(at size: DynamicTypeSize) -> CGFloat {
        (RDimension.sizeComposerMaxHeight - 2 * textInset) * lineHeight(at: size) / baseLine
    }

    /// The bottom inset that centres a control of this height on the last line.
    func bottomInset(centring control: CGFloat, at size: DynamicTypeSize) -> CGFloat {
        textInset + (lineHeight(at: size) - control) / 2
    }
}

/// The words of a writing field (C13, C14): a vertical TextField that grows per RFieldGrowth,
/// the placeholder fading out in 80ms as the first character lands, an ink caret, and the
/// whole field (not only the line) taking the tap. VoiceOver reads it once, by its label.
struct RGrowingField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let style: RTextStyle
    let growth: RFieldGrowth
    var focused: FocusState<Bool>.Binding

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            // In the layout only while empty, so a long hint wraps (accessibility sizes) rather
            // than truncating; fades out as the first character lands, back in when it empties.
            if text.isEmpty {
                Text(placeholder)
                    .rText(style)
                    .foregroundStyle(contrast == .increased ? RColor.textSecondary : RColor.textPlaceholder)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
            TextField("", text: $text, axis: .vertical)
                .rText(style)
                .frame(maxHeight: growth.maxTextHeight(at: dynamicTypeSize))
                .foregroundStyle(RColor.textPrimary)
                // ink caret: accent.default reads 2.14 : 1 on surface.control (needs 3)
                .tint(RColor.textPrimary)
                .focused(focused)
                .accessibilityLabel(label)
        }
        .animation(RMotion.standard(RNumber.motionDurationInstant), value: text.isEmpty)
        .padding(.vertical, growth.textInset)
        // the whole field focuses, not only the line of text
        .contentShape(Rectangle())
        .onTapGesture { focused.wrappedValue = true }
    }
}

struct RComposer: View {
    /// What VoiceOver calls the field ("add why"). The placeholder is a hint, read only by sight.
    let label: String
    let placeholder: String
    @Binding var text: String
    /// The mic well: talk instead of typing. Nil (V2.outside.a, EX-D10): no voice capture here, so the
    /// mic opens the field and the keyboard's own dictation is the way to talk; never a dead control.
    var onMic: (() -> Void)?

    /// What the mic well does.
    enum MicAction: Equatable {
        /// Hands over to the screen's voice capture (`onMic`).
        case talk
        /// Focuses the field, so the keyboard (and its dictation) comes up.
        case focusField
    }

    var micAction: MicAction {
        onMic == nil ? .focusField : .talk
    }

    /// The mic well's tap: the screen's voice capture when there is one, else focus the field.
    static func micTapped(onMic: (() -> Void)?, focus: () -> Void) {
        if let onMic {
            onMic()
        } else {
            focus()
        }
    }

    @FocusState private var focused: Bool
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// One 17/22.1 line centred in the 48 field.
    private static let growth = RFieldGrowth(style: .body, restHeight: RDimension.sizeControlLarge)
    /// Concentric with the well: its radius plus the 4pt inset. Equals the pill at 48.
    private static let radius = RDimension.sizeComposerWell / 2 + RDimension.space1

    /// Keeps the well centred on the last line as the type grows (4 at the default size).
    private var wellBottomInset: CGFloat {
        max(RDimension.space1, Self.growth.bottomInset(centring: RDimension.sizeComposerWell, at: dynamicTypeSize))
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
                RShape.rect(Self.radius)
                    .strokeBorder(RColor.borderControl, lineWidth: RDimension.sizeBorderDefault)
            }
        }
    }

    private var field: some View {
        RGrowingField(label: label, placeholder: placeholder, text: $text, style: .body, growth: Self.growth, focused: $focused)
    }

    private var micWell: some View {
        Button {
            Self.micTapped(onMic: onMic) { focused = true }
        } label: {
            // Paper's 18 mic, as the search field matches it (C12)
            RSymbol(name: "mic", weight: .medium, glyphScale: 0.74) // literal-ok: 18 × 0.82 in the 20 frame
                .frame(width: RDimension.sizeComposerWell, height: RDimension.sizeComposerWell)
                .background(RColor.surfaceLifted, in: Circle())
                .overlay(Circle().strokeBorder(RColor.depthStrokeOuter, lineWidth: RDimension.sizeBorderHairline))
                .shadow(color: RColor.depthShadowContact, radius: 0.75, y: 1) // literal-ok: Paper's contact shadow 0 1 1.5
                .contentShape(Circle().inset(by: (RDimension.sizeComposerWell - RDimension.sizeTouchTarget) / 2))
        }
        .rPress(small: true)
        .accessibilityLabel(micAction == .talk ? "talk instead" : "dictate")
        .accessibilityHint(micAction == .talk ? "" : "opens the keyboard; use its microphone")
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
