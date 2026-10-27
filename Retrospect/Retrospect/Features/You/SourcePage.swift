//
//  SourcePage.swift
//  V2.you · YO-3 "a source" (Paper 1GAS-0, slot 16IW-0), pushed from a search result. The entry bar (back
//  and "edit", 1GBJ-0; editing: "cancel · edit this entry · save"), then 16 down on the 24 margins and
//  32 between the two blocks: your words in the inky face (REntryWords, 1GBI-0) 8 above the meta line
//  with its ✓ (1GBE-0), and "this supports" (1GAU-0): rows in one grouped panel. "show it in the
//  conversation" (1GBA-0) is hidden until its destination is decided (DISCREPANCIES YO-D9). A row opens
//  its page when one exists in this build (YO-5 here; a goal only when the goals group has GL-2, YO-D14).
//
import SwiftUI

struct SourcePage: View {
    @Bindable var model: SourceModel
    let back: () -> Void
    /// What a "this supports" row opens; nil: nothing yet, so the row isn't a button.
    let open: (Flows.Supported) -> (() -> Void)?

    var body: some View {
        VStack(spacing: RDimension.space0) {
            RTopBar(variant: .entry(bar))
            ScrollView {
                if let entry = model.entry {
                    content(entry)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(RColor.backgroundCanvas)
        .task { await model.load() }
        .accessibilityIdentifier("screen.you.source")
    }

    private var bar: RTopBar.Entry {
        if model.edit.editing {
            .editing(
                canSave: model.canSave,
                cancel: { model.cancelEditing() },
                save: { Task { await model.save() } }
            )
        } else {
            .rest(back: back, edit: { model.beginEditing() })
        }
    }

    private func content(_ entry: Flows.SourceEntry) -> some View {
        VStack(alignment: .leading, spacing: RDimension.space8) {
            VStack(alignment: .leading, spacing: RDimension.space2) {
                REntryWords(text: entry.words, draft: $model.edit.draft, editing: model.edit.editing)
                MetaLine(meta: entry.meta, read: entry.read)
            }
            if !entry.supports.isEmpty {
                VStack(alignment: .leading, spacing: RDimension.space1) {
                    RSectionLabel(title: "this supports")
                    REvidenceGroup {
                        ForEach(entry.supports) { supported in
                            YouNavRow(title: supported.title, subline: supported.subline, action: open(supported))
                        }
                    }
                }
            }
        }
        .padding(.top, RDimension.space4)
        .padding(.horizontal, RDimension.spaceScreenMargin)
        .padding(.bottom, RDimension.spaceScreenMargin)
    }
}

/// "tue 14 oct · 7:40 · written · read" and a 12 ✓ in icon.muted, 4 apart (1GBE-0).
private struct MetaLine: View {
    let meta: String
    let read: Bool

    var body: some View {
        HStack(spacing: RDimension.space1) {
            Text(meta)
                .rText(.metaLine)
                .foregroundStyle(RColor.textLabel)
            if read {
                // Paper's ✓ is a 12 box (1GBF-0), drawn in RSymbol's 16 frame
                RSymbol(name: "checkmark", size: .small, tint: RColor.iconMuted, weight: .medium, glyphScale: 0.62) // literal-ok: 12 of 16 × 0.82
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(meta.replacingOccurrences(of: " · ", with: ", "))
    }
}
