//
//  EntryPage.swift
//  V2.journal (dark) · JR-4 one entry (Paper 1FQX-0; 05 frames N51-0, N6E-0, N7R-0, N9D-0): back,
//  your words in the inky face (REntryWords), and one meta line under them, 8 apart; 16 under the
//  bar, the screen margin each side. A tick follows "read"; "didn't send · tap to retry" is danger
//  text with the retry glyph, and the line retries. The parts the backend can't serve yet are off in
//  the cut (EntryCapabilities): the bar shows back only.
//
import SwiftUI

struct EntryPage: View {
    let model: EntryPageModel
    let back: () -> Void

    var body: some View {
        VStack(spacing: RDimension.space0) {
            RTopBar(variant: .entry(.back(back: back)))
            ScrollView {
                content
                    .padding(.top, RDimension.space4)
                    .padding(.horizontal, RDimension.spaceScreenMargin)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .background(RColor.backgroundCanvas.ignoresSafeArea())
        .accessibilityAction(.escape, back)
        .task { await model.load() }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .loading:
            Color.clear.frame(height: RDimension.sizeTouchTarget)
        case let .failed(reason):
            REmptyLine(line: reason, action: .init(title: "try again") { Task { await model.load() } })
        case let .shown(words, meta, standing):
            VStack(alignment: .leading, spacing: RDimension.space2) {
                REntryWords(text: words, draft: .constant(words))
                    .accessibilityIdentifier("entry.words")
                metaLine(meta, standing: standing)
            }
        }
    }

    @ViewBuilder
    private func metaLine(_ meta: String, standing: EntryPageModel.Standing) -> some View {
        switch standing {
        case .notSent:
            // Paper N9D-0: the retry glyph and the line in danger text; the line retries
            Button {
                Task { await model.retry() }
            } label: {
                HStack(spacing: RDimension.space1) {
                    RSymbol(
                        name: "arrow.clockwise",
                        size: .small,
                        tint: RColor.statusDangerText,
                        glyphScale: 0.6
                    ) // literal-ok: Paper's 12 mark in the 16 frame
                    Text(meta)
                        .rText(.metaLine)
                        .foregroundStyle(RColor.statusDangerText)
                }
                .frame(minHeight: RDimension.sizeTouchTarget)
                .contentShape(Rectangle())
            }
            .rPress(small: true)
            .accessibilityLabel(meta.replacingOccurrences(of: " · ", with: ", "))
            .accessibilityHint("double tap to retry")
            .accessibilityIdentifier("entry.retry")
        default:
            HStack(spacing: RDimension.space1) {
                Text(meta)
                    .rText(.metaLine)
                    .foregroundStyle(RColor.textLabel)
                if standing == .read {
                    // Paper 1FRN-0: a 12 tick after "read"
                    RSymbol(
                        name: "checkmark",
                        size: .small,
                        tint: RColor.iconMuted,
                        weight: .medium,
                        glyphScale: 0.6
                    ) // literal-ok: Paper's 12 tick in the 16 frame
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(meta.replacingOccurrences(of: " · ", with: ", "))
            .accessibilityIdentifier("entry.meta")
        }
    }
}

/// JR-4 as a pushed page: owns its model, so the page keeps its state while the stack redraws.
struct EntryScreen: View {
    @State private var model: EntryPageModel
    let back: () -> Void

    init(id: String, data: any EntriesData, capabilities: EntryCapabilities = .cut, back: @escaping () -> Void) {
        _model = State(initialValue: EntryPageModel(id: id, data: data, capabilities: capabilities))
        self.back = back
    }

    var body: some View {
        EntryPage(model: model, back: back)
    }
}
