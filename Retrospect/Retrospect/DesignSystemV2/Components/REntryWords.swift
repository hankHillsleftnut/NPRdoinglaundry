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

/// One entry's edit, owned by the page (or its model): the draft is filled from the kept words ONCE,
/// when editing starts, and never again until the next start. The field never writes it on appearing,
/// so a field that scrolls out of a lazy stack and back, or is rebuilt, keeps what you typed.
struct REntryEdit: Equatable {
    private(set) var editing = false
    /// The words being edited; the kept words stay untouched until `save`.
    var draft = ""

    /// Starts editing from the kept words. A second call while editing keeps the draft.
    mutating func begin(from text: String) {
        guard !editing else { return }
        draft = text
        editing = true
    }

    /// Stops editing; the kept words were never touched.
    mutating func cancel() {
        editing = false
    }

    /// Stops editing and hands back the words to keep.
    mutating func save() -> String {
        editing = false
        return draft
    }
}

/// Your words, read or edited in place. The kept words are never touched while editing: the field edits
/// `draft`, which the page fills once when editing starts (`REntryEdit.begin(from:)`). So "cancel" is
/// just leaving editing, and the page's "save" keeps `draft` (the top bar's "cancel · save" belong to the page).
struct REntryWords: View {
    /// The kept words, shown at rest.
    let text: String
    /// The words being edited. The page fills it when editing starts; this view never overwrites it.
    @Binding var draft: String
    var editing = false
    /// VoiceOver's name for the field while editing.
    var fieldLabel = "your words"
    /// Editing starts with the caret in the words (the page passes false to keep the keyboard down).
    var focusOnEdit = true

    @FocusState private var focused: Bool

    var body: some View {
        if editing {
            // no title: it would show as the system placeholder if the words are cleared
            TextField("", text: $draft, axis: .vertical)
                .rText(.inkEntry)
                .foregroundStyle(RColor.textPrimary)
                .tint(RColor.inkDefault)
                .focused($focused)
                .padding(.vertical, RDimension.space3)
                .padding(.horizontal, RDimension.space4)
                .background { REntryWordsField() }
                // the field grows outward, so the words stay where they were at rest
                .padding(.vertical, -RDimension.space3)
                .padding(.horizontal, -RDimension.space4)
                // .task, not .onAppear: the field must be in the responder chain before it can take focus.
                // Focus only: the draft is the page's (seeding it here would wipe typed words on reappearing).
                .task {
                    focused = focusOnEdit
                }
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
                // Paper E31-0: a 14 × 14 chevron (size.icon.chevron), drawn in RSymbol's 16 and laid out at 14
                RSymbol(
                    name: "chevron.right",
                    size: .small,
                    tint: RColor.textLink,
                    weight: .semibold,
                    glyphScale: RSymbol.defaultGlyphScale * Self.chevronSize / RDimension.sizeIconSmall
                )
                .frame(width: Self.chevronSize, height: Self.chevronSize)
            }
            .foregroundStyle(RColor.textLink)
            .frame(minWidth: RDimension.sizeTouchTarget, minHeight: RDimension.sizeTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(RLinkPressStyle())
        .accessibilityAddTraits(.isLink)
    }

    /// The chevron's box (E31-0: 14).
    static let chevronSize = RDimension.sizeIconChevron
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
    @State private var edit = REntryEdit()
    @State private var staticDraft = "i think it's the 9am standup. i dread it, every monday"
    @State private var followed = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space6) {
                Text("entry words · rest").rText(.labelMedium).foregroundStyle(RColor.textSecondary)
                REntryWords(text: "i think it's the 9am standup. i dread it.", draft: .constant(""))
                Text("entry words · editing").rText(.labelMedium).foregroundStyle(RColor.textSecondary)
                REntryWords(text: words, draft: $staticDraft, editing: true, focusOnEdit: false)
                Text("live").rText(.labelMedium).foregroundStyle(RColor.textSecondary)
                REntryWords(text: words, draft: $edit.draft, editing: edit.editing)
                HStack(spacing: RDimension.space3) {
                    RPill(title: edit.editing ? "save" : "edit", style: .raised) {
                        if edit.editing {
                            words = edit.save()
                        } else {
                            edit.begin(from: words)
                        }
                    }
                    if edit.editing {
                        RPill(title: "cancel", style: .neutral) { edit.cancel() }
                    }
                }
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
