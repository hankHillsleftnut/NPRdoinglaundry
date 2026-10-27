//
//  EntryPage+Drawn.swift
//  V2.journal J2b: JR-4's drawn parts on the entry page, each behind its `EntryCapabilities` flag.
//  Rest (N51-0): "edit" in the bar; your words and the meta line; 32 under them "what i took from
//  this"; "delete entry" at the foot, 32 off the bottom. Editing (N8R-0): "cancel · edit this entry ·
//  save", the words in the sunken field with the caret, "retro reads it again when you save" 8 under;
//  nothing else; escape cancels the edit. Delete (NAB-0): RDialog over the page, "delete it" pops back
//  (once), and the host plays the warning haptic.
//  "show it in the conversation ›" stays hidden even here (no drawn landing, J-17).
//
import SwiftUI

extension EntryPage {
    /// The bar: back only in the cut; "edit" when editing is on; the editing bar while editing.
    var barVariant: RTopBar.Entry {
        guard let drawn, model.capabilities.edit, case let .shown(words, _, _) = model.state else {
            return .back(back: back)
        }
        let kept = drawn.words(words)
        if drawn.edit.editing {
            return .editing(
                canSave: drawn.canSave(from: kept),
                cancel: { withAnimation(RMotion.standard(RNumber.motionDurationBase)) { drawn.cancelEdit() } },
                save: { withAnimation(RMotion.standard(RNumber.motionDurationBase)) { drawn.save() } }
            )
        }
        return .rest(back: back, edit: { withAnimation(RMotion.standard(RNumber.motionDurationBase)) { drawn.beginEdit(from: kept) } })
    }

    @ViewBuilder
    func drawnContent(_ drawn: EntryDrawnModel, words: String, meta: String, standing: EntryPageModel.Standing) -> some View {
        let kept = drawn.words(words)
        @Bindable var drawn = drawn
        VStack(alignment: .leading, spacing: RDimension.space8) {
            VStack(alignment: .leading, spacing: RDimension.space2) {
                REntryWords(text: kept, draft: $drawn.edit.draft, editing: drawn.edit.editing)
                    .accessibilityIdentifier("entry.words")
                if drawn.edit.editing {
                    Text(EntryDrawnModel.editingNote)
                        .rText(.metaLine)
                        .foregroundStyle(RColor.textLabel)
                        .padding(.top, RDimension.space3)
                } else {
                    metaLine(meta, standing: standing)
                }
            }
            if model.capabilities.took, !drawn.edit.editing {
                TookSectionView(section: drawn.section(for: standing)) { id in drawn.notRight(id) }
            }
        }
        .onAppear { drawn.applyStart(words: kept) }
    }

    /// "delete entry" at the foot, outside the scroll (N52-0: 32 off the screen's bottom edge, the screen
    /// margin each side). Paper measures the 32 from the frame's bottom, so the row reaches into the bottom
    /// safe area (it sits above the home indicator either way; on SE the two are the same).
    @ViewBuilder var deleteRow: some View {
        if let drawn, model.capabilities.delete, !drawn.edit.editing, case .shown = model.state {
            DestructiveRow(title: "delete entry") { drawn.askDelete() }
                .padding(.horizontal, RDimension.spaceScreenMargin)
                .padding(.bottom, RDimension.space8)
                .ignoresSafeArea(.container, edges: .bottom)
                .transition(.opacity)
        }
    }
}

/// The delete dialog and "not right"'s haptic, on the page. Delete's warning haptic belongs to the
/// host that pops the page (it outlives the pop; `EntryScreen.onDelete`).
struct EntryDrawnPresentation: ViewModifier {
    let model: EntryPageModel
    let drawn: EntryDrawnModel?

    func body(content: Content) -> some View {
        if let drawn {
            @Bindable var drawn = drawn
            content
                // the page behind the dialog is out of VoiceOver's reach while it asks (modal)
                .accessibilityHidden(drawn.hidesPageFromVoiceOver)
                .rDialog(isPresented: $drawn.showsDelete) {
                    RDialog(
                        title: EntryDrawnModel.dialogTitle,
                        line: EntryDrawnModel.dialogLine,
                        confirmTitle: EntryDrawnModel.dialogConfirm,
                        confirm: { drawn.confirmDelete() },
                        cancel: { drawn.keep() }
                    )
                }
                .sensoryFeedback(RHaptic.confirm, trigger: drawn.notedCount)
        } else {
            content
        }
    }
}
