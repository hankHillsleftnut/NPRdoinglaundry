//
//  YouPage.swift
//  V2.you · the You tab (Paper YO-1 1G5Y-0 at rest, YO-2 1G8E-0 searched; slots 16IK-0, 16IQ-0). One page:
//  the title bar ("you" + your picture, 1G7X-0), then 20 down on the 24 margins, the search field, and
//  either the map (1G6Z-0) and the two rows (1G6L-0), 24 apart, or, once you ask, what was found, its
//  sources and "only what's certain" (1G9Y-0, 1G97-0, 1G91-0), 32 apart. The change is in place: the map
//  gives way with the blur replace (Reduce Motion: a cross-fade). "list" (1G81-0) is hidden: its view is
//  not drawn (DISCREPANCIES YO-D2). The page ends at the tab bar with the tab edge's progressive blur.
//
import SwiftUI

struct YouPage: View {
    @Bindable var model: YouModel
    let navigator: YouNavigator
    /// Opens a named node's sheet (YO-4); nil until the sheet is in this build.
    var openNode: ((String) -> Void)?
    /// Opens the waiting question (YO-4's guess); nil until the sheet is in this build.
    var openQuestion: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: RDimension.space0) {
            RTopBar(variant: .title(
                title: "you",
                trailing: .content([AnyView(YouPicture(action: navigator.opener(elsewhere: YouNavigator.settingsScreenID)))])
            ))
            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: model.answer == nil ? RDimension.space6 : RDimension.space8) {
                        RSearchField(
                            placeholder: "ask anything about yourself",
                            text: $model.query,
                            onSubmit: { Task { await model.ask() } }
                        )
                        Group {
                            if let answer = model.answer {
                                found(answer, reader: reader)
                            } else {
                                rest
                            }
                        }
                        .transition(.rBlurReplace(reduceMotion: reduceMotion))
                    }
                    .padding(.top, RDimension.space5)
                    .padding(.horizontal, RDimension.spaceScreenMargin)
                    .padding(.bottom, RDimension.space8)
                    .animation(reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.snappy, value: model.answer)
                }
                .scrollDismissesKeyboard(.interactively)
                .rProgressiveBlur(.tabEdge)
            }
        }
        .background(RColor.backgroundCanvas)
        .onChange(of: model.query) { _, query in
            // the field's × (or deleting every word) goes back to the map
            if query.isEmpty, model.phase != .rest {
                model.clear()
            }
        }
        .task { await model.load() }
        .accessibilityIdentifier("screen.you")
    }

    // MARK: YO-1 at rest

    private var rest: some View {
        VStack(alignment: .leading, spacing: RDimension.space6) {
            YouMap(open: openNode)
            REvidenceGroup {
                YouNavRow(
                    title: "what i know about you",
                    subline: "every fact and guess, each one you can fix",
                    action: { navigator.push(.whatIKnow) }
                )
                if let about = model.atRest.questionAbout {
                    YouNavRow(title: "one question waiting", subline: "about \(about)", action: openQuestion)
                }
            }
        }
    }

    // MARK: YO-2 found

    private func found(_ answer: Flows.Answer, reader: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: RDimension.space8) {
            AnswerCard(answer: answer, secondLine: model.secondLine) { number in
                model.highlighted = number
                withAnimation(reduceMotion ? nil : RMotion.snappy) {
                    reader.scrollTo(SourceList.rowID(number), anchor: .center)
                }
            }
            if !model.sources.isEmpty {
                SourceList(sources: model.sources, highlighted: $model.highlighted) { id in
                    navigator.push(.source(id))
                }
            }
            if model.offersOnlyCertain {
                OnlyCertainRow(isOn: $model.onlyCertain)
                    .padding(.top, RDimension.space2) // Paper 1G91-0: 8 more than the 32
            }
        }
    }
}

/// Your picture (1G7Z-0): a 36 sky disc with a warm light at its top right, a rim and a hairline. Opens
/// settings only when settings is in this build; otherwise it is a picture, not a button (YO-D14).
private struct YouPicture: View {
    let action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { disc }
                .buttonStyle(.plain)
                .frame(width: RDimension.sizeTouchTarget, height: RDimension.sizeTouchTarget)
                .contentShape(Rectangle())
                .accessibilityLabel("settings")
        } else {
            disc.accessibilityHidden(true)
        }
    }

    private var disc: some View {
        Circle()
            .fill(RColor.mapNodeSelf)
            .overlay {
                // Paper: amber-200 from 80% / 15%, fading by 55%; the palette has no semantic token here,
                // so the map's theme node (amber) stands in (YO-D23)
                Circle().fill(
                    RadialGradient(
                        colors: [RColor.mapNodeTheme, RColor.mapNodeTheme.opacity(0)],
                        center: UnitPoint(x: 0.8, y: 0.15), // literal-ok: Paper 1GAE-0 gradient centre
                        startRadius: RDimension.space0,
                        endRadius: RDimension.sizeControlIcon * 0.55 * 1.4 // literal-ok: Paper fades by 55% of the diagonal
                    )
                )
            }
            .overlay(Circle().strokeBorder(RColor.depthStrokeInnerTop, lineWidth: RDimension.sizeBorderDefault))
            .overlay(Circle().stroke(RColor.depthStrokeOuter, lineWidth: RDimension.sizeBorderHairline))
            .frame(width: RDimension.sizeControlIcon, height: RDimension.sizeControlIcon)
    }
}
