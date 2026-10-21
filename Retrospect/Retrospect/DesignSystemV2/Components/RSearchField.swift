//
//  RSearchField.swift
//  M14 C12: the search field (Paper approvals · part 23 c:search-field/rest and /typed;
//  ios-handoff "50 · search"). Built on RSunkenField, the shared sunken pill a plain field
//  will reuse once Paper draws one. Rest: a 36 mic well first, the placeholder in
//  text.tertiary. Typed: your words in text.primary and a 36 clear slot with a 16 ×.
//  Focus follows iOS (the caret); Paper draws no focus ring, so there is none.
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
    let placeholder: String
    @Binding var text: String
    var submitLabel: SubmitLabel = .search
    var keyboard: UIKeyboardType = .default
    var onSubmit: () -> Void = {}
    /// The mic well: talk instead of typing.
    var onMic: () -> Void = {}

    @FocusState private var focused: Bool

    var body: some View {
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
}

/// A 36 visual in a 44 target (the frame is padded by the hit shape, never the visual),
/// dimmed while pressed.
private struct RFieldSlotStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? RNumber.opacityPressed : 1)
            .contentShape(Rectangle().inset(by: (RDimension.sizeFieldWell - RDimension.sizeTouchTarget) / 2))
    }
}

#if DEBUG
struct RSearchFieldGallery: View {
    @State private var empty = ""
    @State private var typed = "when do i sleep best?"

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space6) {
            Text("search field").rText(.labelMedium).foregroundStyle(RColor.textSecondary)
            RSearchField(placeholder: "ask anything about yourself", text: $empty)
            RSearchField(placeholder: "ask anything about yourself", text: $typed)
        }
        .padding(RDimension.spaceScreenMargin)
    }
}

#Preview("search field") { RSearchFieldGallery() }
#endif
