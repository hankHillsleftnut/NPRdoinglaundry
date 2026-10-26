//
//  REntryWords.swift
//  V2 lane 0 · components gaps #5 and #6, the two parts of a single entry's page that JR-4 (one entry)
//  and YO-3 (a source) share (Paper 02 · components, gate A card 5 "entry page" E24-0):
//  - c:entry/words: your own words, in the inky card face. rest E2U-0; editing E44-0 / G8U-0.
//  - c:link/conversation E2Z-0: "show it in the conversation ›", back to where it was said.
//
//  Paper, 1:1:
//  - rest (E2U-0): --font-display-inky, --text-xl, ink card, --tracking-card, --leading-snug, balanced,
//    text.primary (`.inkEntry`). Content keeps its own case.
//  - editing (G8U-0): the same words in a sunken field: surface.washPressed, radius.field (12), inset
//    0 1 2 depth.shadow.sunken and a 0.5 inner depth.stroke.outer; padding 12 × 16. The caret is ink
//    (Paper draws a 2 × 24 ink.default bar; the system caret takes ink.default as its tint).
//  - link (E2Z-0): SF text-md regular in text.link, a 14 chevron in text.link, 4 apart; a 44 row.
//    Blue here is "a link inside text", one of blue's four jobs (screen rules 14).
//
import SwiftUI

extension RTextStyle {
    /// Your words on an entry's page (E2U-0: inky card face, --text-xl, --leading-snug).
    static let inkEntry = RTextStyle(
        family: .inky(axis: -10),
        size: RDimension.fontSizeXl,
        weight: .regular,
        tracking: RNumber.fontTrackingCard,
        leading: 1.3,
        relativeTo: .title2
    )

    /// "show it in the conversation" (E30-0: --font-text, --text-md, regular, --leading-snug).
    static let inlineLink = RTextStyle(
        family: .text,
        size: RDimension.fontSizeMd,
        weight: .regular,
        tracking: RNumber.fontTrackingNone,
        leading: 1.3,
        relativeTo: .subheadline
    )
}

/// Your words, read or edited in place. The page owns the text and whether it is being edited (the top
/// bar's "edit" / "cancel · save").
struct REntryWords: View {
    @Binding var text: String
    var editing = false
    /// VoiceOver's name for the field while editing.
    var fieldLabel = "your words"
    /// Editing starts with the caret in the words (the page passes false to keep the keyboard down).
    var focusOnEdit = true

    @FocusState private var focused: Bool

    var body: some View {
        if editing {
            TextField(fieldLabel, text: $text, axis: .vertical)
                .rText(.inkEntry)
                .foregroundStyle(RColor.textPrimary)
                .tint(RColor.inkDefault)
                .focused($focused)
                .padding(.vertical, RDimension.space3)
                .padding(.horizontal, RDimension.space4)
                .background { REntryWordsField() }
                .onAppear { focused = focusOnEdit }
                .accessibilityLabel(fieldLabel)
        } else {
            Text(text)
                .rText(.inkEntry)
                .foregroundStyle(RColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
}

/// surface.washPressed, radius.field, the sunken inset shade and its 0.5 inner hairline (G8U-0).
private struct REntryWordsField: View {
    var body: some View {
        let shape = RShape.rect(RDimension.radiusField)
        shape.fill(RColor.surfaceWashPressed)
            .overlay(shape.strokeBorder(RColor.depthStrokeOuter, lineWidth: RDimension.sizeBorderHairline))
            .overlay {
                // inset 0 1 2 sunken shade, darkest at the top edge (as rSunken draws it)
                shape.stroke(RColor.depthShadowSunken, lineWidth: RDimension.sizeBorderRing)
                    .blur(radius: RDimension.sizeBorderDefault)
                    .offset(y: RDimension.sizeBorderDefault)
                    .clipShape(shape)
            }
    }
}

/// "show it in the conversation ›": a link back to where the words were said.
struct RConversationLink: View {
    var title = "show it in the conversation"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: RDimension.space1) {
                Text(title)
                    .rText(.inlineLink)
                RSymbol(name: "chevron.right", size: .small, tint: RColor.textLink, weight: .semibold)
            }
            .foregroundStyle(RColor.textLink)
            .frame(minHeight: RDimension.sizeTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(RLinkPressStyle())
        .accessibilityAddTraits(.isLink)
    }
}

/// A link dims to opacity.pressed while held, in 80 and out over 240.
private struct RLinkPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? RNumber.opacityPressed : 1)
            .animation(
                RMotion.standard(configuration.isPressed ? RNumber.motionDurationPressIn : RNumber.motionDurationPressOut),
                value: configuration.isPressed
            )
    }
}

#if DEBUG
/// Lab page "entrywords": Paper's words at rest and editing (E2U-0, G8U-0), a live edit toggle, the link.
struct REntryWordsGallery: View {
    @State private var words = "i think it's the 9am standup. i dread it, every monday"
    @State private var editing = false
    @State private var followed = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space6) {
                Text("entry words · rest").rText(.labelMedium).foregroundStyle(RColor.textSecondary)
                REntryWords(text: .constant("i think it's the 9am standup. i dread it."))
                Text("entry words · editing").rText(.labelMedium).foregroundStyle(RColor.textSecondary)
                REntryWords(text: $words, editing: true, focusOnEdit: false)
                Text("live").rText(.labelMedium).foregroundStyle(RColor.textSecondary)
                REntryWords(text: $words, editing: editing)
                RPill(title: editing ? "done" : "edit", style: .raised) { editing.toggle() }
                Text("link · followed \(followed)×").rText(.labelMedium).foregroundStyle(RColor.textSecondary)
                RConversationLink { followed += 1 }
            }
            .frame(maxWidth: RDimension.layoutReadingWidth, alignment: .leading)
            .padding(RDimension.spaceScreenMargin)
        }
        .background(RColor.backgroundCanvas)
    }
}

#Preview("entry words") { REntryWordsGallery() }
#endif
