//
//  YouPage.swift
//  V2.you · the You tab (Paper YO-1 1G5Y-0 at rest, YO-2 1G8E-0 searched; slots 16IK-0, 16IQ-0). One page:
//  the title bar ("you" + your picture, 1G7X-0), then 20 down on the 24 margins, the search field, and
//  either the map (1G6Z-0) and the two rows (1G6L-0), 24 apart, or, once you ask, what was found, its
//  sources and "only what's certain" (1G9Y-0, 1G97-0, 1G91-0), 32 apart. The change is in place: the map
//  gives way with the blur replace (Reduce Motion: a cross-fade). "list" (1G81-0) and your picture are
//  drawn as Paper but inert: the list view isn't drawn and settings is another group's screen (YO-D2, YO-D14;
//  DECISIONS 27 Oct consistency rule). The page ends at the tab bar with the tab edge's progressive blur.
//  A named orb opens its sheet (YO-4) through the RSheetHost the tab sits in.
//
import SwiftUI

struct YouPage: View {
    /// What the title bar carries on its right, in Paper's order (1G7Y-0): "list", then your picture.
    enum Trailing: CaseIterable {
        case list, picture

        @MainActor var view: AnyView {
            switch self {
            case .list: AnyView(ListPill())
            case .picture: AnyView(YouPicture())
            }
        }
    }

    static let trailing: [Trailing] = [.list, .picture]

    @Bindable var model: YouModel
    let navigator: YouNavigator

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: RDimension.space0) {
            RTopBar(variant: .title(
                title: "you",
                trailing: .content(Self.trailing.map(\.view))
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
                    .animation(reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.snappy, value: model.onlyCertain)
                }
                .scrollDismissesKeyboard(.interactively)
                .rProgressiveBlur(.tabEdge)
            }
        }
        .background(RColor.backgroundCanvas)
        // YO-4: a node's sheet over the page, at the full detent (a sibling, so it never nests another request)
        .background {
            Color.clear.rSheet(isPresented: $model.sheetOpen, detent: .full) {
                if let node = model.node {
                    NodeSheet(node: node, answer: { answer in Task { await model.answer(answer) } }, close: { model.sheetOpen = false })
                }
            }
        }
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
            YouMap { name in Task { await model.openNode(named: name) } }
            REvidenceGroup {
                YouNavRow(
                    title: "what i know about you",
                    subline: "every fact and guess, each one you can fix",
                    action: { navigator.push(.whatIKnow) }
                )
                if let about = model.atRest.questionAbout {
                    // where it lands (YO-4's guess) is not drawn: not a button (founder 27 Oct, YO-D12)
                    YouNavRow(title: "one question waiting", subline: "about \(about)")
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

/// "list" (1G81-0): a 36 wash capsule, 12 in, Geist 14 medium. Its view isn't drawn: inert (YO-D2).
private struct ListPill: View {
    var body: some View {
        Text("list")
            .rText(.textMdMedium)
            .foregroundStyle(RColor.textPrimary)
            .padding(.horizontal, RDimension.space3)
            .frame(height: RDimension.sizeControlIcon)
            .background(RColor.surfaceWash, in: RShape.pill)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .youInert()
    }
}

/// Your picture (1G7Z-0): a 36 sky disc with a warm light at its top right, a rim and a hairline. Paper
/// says it opens settings (ST-1, another group): it does when a stack above can push ST-1 (the app route
/// table, G0); otherwise it is drawn as Paper but inert (YO-D14).
private struct YouPicture: View {
    @Environment(\.appRouter) private var router

    var body: some View {
        if let open = router.opener(.settings(.hub)) {
            Button(action: open) {
                // the 36 disc, in a 44 target
                disc
                    .frame(width: RDimension.sizeTouchTarget, height: RDimension.sizeTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(RPressStyle())
            // the target's extra 8 overhangs the bar's layout, so the disc sits where Paper draws it
            .padding(-(RDimension.sizeTouchTarget - RDimension.sizeControlIcon) / 2) // literal-ok: half on each side
            .accessibilityLabel("settings")
            .accessibilityIdentifier("you.picture")
        } else {
            disc
                .accessibilityElement()
                .accessibilityLabel("settings")
                .accessibilityAddTraits(.isButton)
                .youInert()
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
