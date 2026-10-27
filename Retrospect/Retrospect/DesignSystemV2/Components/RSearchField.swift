//
//  RSearchField.swift
//  M14 C12: the search field (Paper approvals · part 23 c:search-field/rest and /typed;
//  ios-handoff "50 · search"). Built on RSunkenField, the shared sunken pill a plain field
//  will reuse once Paper draws one. Rest: a 36 mic well first, the placeholder in
//  text.placeholder. Typed: your words in text.primary and a 36 clear slot with a 16 ×.
//  Focus follows iOS (the caret); Paper draws no focus ring, so there is none.
//  Journal look (V2.journal, Paper c:search-field/journal/rest 1FQT-0, /typing N0X-0): the drawer's
//  36 field, a translucent sunken wash (surface.washPressed, the sunken shade, a 0.5 inner stroke),
//  a 16 magnifier in icon.muted, the words in SF 17 (tracking.card), and a 20 wash circle with a
//  12 × once there are words. No mic: the drawer searches what you wrote.
//
import SwiftUI

/// The sunken field: 48 tall, a true pill, surface.control with the sunken shade and a 0.5
/// inner hairline (rSunken), 4 padding, 8 between its parts. Dynamic Type grows the height.
/// The composer (C13) sets a wider gap, bottom alignment and a concentric corner, so it can grow.
struct RSunkenField<Leading: View, Content: View, Trailing: View>: View {
    var spacing: CGFloat = RDimension.space2
    var alignment: VerticalAlignment = .center
    var radius: CGFloat = RDimension.radiusControl
    @ViewBuilder let leading: Leading
    @ViewBuilder let content: Content
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(alignment: alignment, spacing: spacing) {
            leading
            content
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.horizontal, RDimension.space1)
        .frame(minHeight: RDimension.sizeControlLarge)
        .rSunken(radius)
    }
}

struct RSearchField: View {
    enum Look {
        /// 48, sunken, the mic well first (part 23).
        case standard
        /// The drawer's 36 wash field with a magnifier (JR-3).
        case journal
    }

    let placeholder: String
    @Binding var text: String
    var submitLabel: SubmitLabel = .search
    var keyboard: UIKeyboardType = .default
    var onSubmit: () -> Void = {}
    /// The mic well: talk instead of typing.
    var onMic: () -> Void = {}
    var look: Look = .standard

    @FocusState private var focused: Bool

    var body: some View {
        switch look {
        case .standard: standard
        case .journal: journal
        }
    }

    private var standard: some View {
        RSunkenField {
            Button(action: onMic) {
                // Paper's mark sits in an 18 box at a medium weight
                RSymbol(name: "mic", weight: .medium, glyphScale: 0.74) // literal-ok: 18 × 0.82 in the 20 frame
                    .frame(width: RDimension.sizeFieldWell, height: RDimension.sizeFieldWell)
                    .background(RColor.surfaceWash, in: Circle())
            }
            .buttonStyle(RFieldSlotStyle())
            .accessibilityLabel("talk instead")
        } content: {
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(RColor.textPlaceholder))
                .rText(.body)
                .foregroundStyle(RColor.textPrimary)
                .tint(RColor.textPrimary)
                .lineLimit(1)
                .focused($focused)
                .submitLabel(submitLabel)
                .keyboardType(keyboard)
                .onSubmit(onSubmit)
                .accessibilityLabel(placeholder)
                .accessibilityAddTraits(.isSearchField)
        } trailing: {
            if !text.isEmpty {
                Button {
                    text = ""
                    focused = true
                } label: {
                    // Paper's × is an 8pt mark in its 16 box
                    RSymbol(name: "xmark", size: .small, tint: RColor.iconMuted, weight: .medium, glyphScale: 0.62) // literal-ok: 8pt mark
                        .frame(width: RDimension.sizeFieldWell, height: RDimension.sizeFieldWell)
                }
                .buttonStyle(RFieldSlotStyle())
                .accessibilityLabel("clear")
                .transition(.opacity)
            }
        }
        .animation(RMotion.standard(RNumber.motionDurationFast), value: text.isEmpty)
    }

    /// Paper 1FQT-0 / N0X-0: 36 tall in a 44 tap area, 12 inline, 8 between the parts.
    private var journal: some View {
        let shape = RShape.rect(RDimension.radiusControl)
        return HStack(spacing: RDimension.space2) {
            RSymbol(name: "magnifyingglass", size: .small, tint: RColor.iconMuted, weight: .medium)
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(RColor.textTertiary))
                .rText(.entryWords)
                .foregroundStyle(RColor.textPrimary)
                .tint(RColor.inkDefault)
                .lineLimit(1)
                .focused($focused)
                .submitLabel(submitLabel)
                .keyboardType(keyboard)
                .onSubmit(onSubmit)
                .accessibilityLabel(placeholder)
                .accessibilityAddTraits(.isSearchField)
            if !text.isEmpty {
                Button {
                    text = ""
                    focused = true
                } label: {
                    // Paper N0Y-0: a 20 wash circle holding a 12 ×
                    RSymbol(name: "xmark", size: .small, weight: .semibold, glyphScale: 0.62) // literal-ok: 10pt mark in its 16 box
                        .frame(width: RDimension.sizeIconDefault, height: RDimension.sizeIconDefault)
                        .background(RColor.surfaceWashPressed, in: Circle())
                }
                .buttonStyle(RFieldSlotStyle(visual: RDimension.sizeIconDefault))
                .accessibilityLabel("clear")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, RDimension.space3)
        .frame(minHeight: RDimension.sizeSearchField)
        .background(RColor.surfaceWashPressed, in: shape)
        .overlay(shape.strokeBorder(RColor.depthStrokeOuter, lineWidth: 0.5))
        .overlay(alignment: .top) {
            // inset 0 1 2 sunken shade, darkest at the top edge
            shape.stroke(RColor.depthShadowSunken, lineWidth: 2).blur(radius: 1).offset(y: 1).clipShape(shape)
        }
        .frame(minHeight: RDimension.sizeTouchTarget)
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .animation(RMotion.standard(RNumber.motionDurationFast), value: text.isEmpty)
    }
}

/// A 36 visual in a 44 target (the frame is padded by the hit shape, never the visual),
/// dimmed while pressed.
private struct RFieldSlotStyle: ButtonStyle {
    /// The drawn size; the hit shape grows it to 44.
    var visual: CGFloat = RDimension.sizeFieldWell

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? RNumber.opacityPressed : 1)
            .contentShape(Rectangle().inset(by: (visual - RDimension.sizeTouchTarget) / 2))
    }
}

#if DEBUG
struct RSearchFieldGallery: View {
    @State private var empty = ""
    @State private var typed = "when do i sleep best?"
    @State private var journalEmpty = ""
    @State private var journalTyped = "standup"

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space6) {
            Text("search field").rText(.labelMedium).foregroundStyle(RColor.textSecondary)
            RSearchField(placeholder: "ask anything about yourself", text: $empty)
            RSearchField(placeholder: "ask anything about yourself", text: $typed)
            Text("journal (the drawer)").rText(.labelMedium).foregroundStyle(RColor.textSecondary)
            RSearchField(placeholder: "search your journal", text: $journalEmpty, look: .journal)
            RSearchField(placeholder: "search your journal", text: $journalTyped, look: .journal)
        }
        .padding(RDimension.spaceScreenMargin)
    }
}

#Preview("search field") { RSearchFieldGallery() }
#endif
