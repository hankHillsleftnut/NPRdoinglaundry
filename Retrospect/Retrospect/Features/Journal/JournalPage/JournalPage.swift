//
//  JournalPage.swift
//  P09 JR-1: the journal (docs/team/ui/P09.md; Paper 1FKB-0 on "06 · everything · latest",
//  ios-handoff.md §3). The top bar (C17) with the drawer button and the inky title; the offline
//  line under it when there's no connection; today's brief (C26) anchored under the bar, 12
//  below it, becoming the slim bar as the thread scrolls; the thread in one scroll view, oldest
//  at the top and newest at the bottom (anchored there), 24 between turns, your bubbles (C30.1)
//  with their long-press menu (C20), Retro's lines (C30.2), the one guess (C28), the day label
//  8 above a day's first entry; the voice composer (C14) pinned above the tab bar, mic off until
//  tapped; the top edge blurred under the bar and the bottom under the composer (UI0.1). Loading
//  shows the thread's skeleton after 400ms (C39.1); a failed load shows the error with try again
//  (C39.3) and the composer still works. Margins 24 (20 on SE). The sheet host sits at the page
//  root; the brief's play opens the player sheet (P10 fills it). Data comes only through
//  `Flows.JournalData` (`\.journalData`), sample or live.
//
import SwiftUI

/// Reads the flow from the environment and builds the page on it.
struct JournalPageContainer: View {
    /// The person's local day, `YYYY-MM-DD`.
    let today: String
    /// The drawer button's action (JR-3 is not mounted yet: the app root points it at the account page).
    var openDrawer: () -> Void = {}
    @Environment(\.journalData) private var data

    var body: some View {
        if let data {
            // a new data source or a new day builds a new page and model
            JournalPage(model: model(for: data))
                .id(PageIdentity(data: ObjectIdentifier(data), today: today))
        } else {
            // outside the app (a preview without the seam): nothing to show yet
            RColor.backgroundCanvas.ignoresSafeArea()
        }
    }
}

extension JournalPageContainer {
    private func model(for data: any Flows.JournalData) -> JournalViewModel {
        let model = JournalViewModel(data: data, today: today)
        model.openDrawer = openDrawer
        return model
    }
}

private struct PageIdentity: Hashable {
    let data: ObjectIdentifier
    let today: String
}

struct JournalPage: View {
    @State private var model: JournalViewModel
    @Environment(\.rCompactHeight) private var compactHeight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: JournalViewModel) {
        _model = State(initialValue: model)
    }

    private var margin: CGFloat {
        compactHeight ? RDimension.spaceListInset : RDimension.spaceScreenMargin
    }

    var body: some View {
        RSheetHost {
            VStack(spacing: RDimension.space0) {
                RTopBar(variant: .journal(title: "journal", collapsed: model.collapsed, openDrawer: model.openDrawer))
                if !model.isOnline {
                    ROfflineLine(copy: .page)
                        .padding(.horizontal, margin - RDimension.space3)
                }
                briefCard
                thread
            }
            .background(RColor.backgroundCanvas)
            .rMenuHost()
        }
        .rSheet(isPresented: $model.playerShown, detent: .full) {
            playerSheet
        }
        .animation(RMotion.snappy, value: model.isOnline)
        .rOfflineAnnouncement(.page, isOffline: !model.isOnline)
        // M08's land: the confirm haptic once, for the entry this session watched arrive
        .sensoryFeedback(RHaptic.confirm, trigger: model.landed) { old, new in old != new && new != nil }
        .rRetroAnnouncement(landed: model.landed, line: model.landedLine)
        .rErrorHaptic(isFailing: model.failure != nil)
        .rErrorAnnouncement(model.failure?.message, attempt: model.loadAttempts)
        // a guess answer that failed: the same haptic and announcement, once per failure
        .rErrorHaptic(isFailing: model.answerFailure != nil)
        .rErrorAnnouncement(
            model.answerFailure.map { $0.message ?? JournalViewModel.answerFailureLine },
            attempt: model.answerFailures
        )
        // a send that saved nothing: the words are back in the box; the same haptic and announcement
        .rErrorHaptic(isFailing: model.sendFailure != nil)
        .rErrorAnnouncement(model.sendFailure.map { _ in JournalViewModel.sendFailureLine }, attempt: model.sendFailures)
        // M08: an entry this session sent turning sent, whenever it happens
        .onChange(of: model.deliveries) { model.noteDeliveries() }
        .task { await model.loadIfNeeded() }
        .accessibilityIdentifier("screen.JR-1")
    }

    // MARK: - The brief

    @ViewBuilder
    private var briefCard: some View {
        if let card = model.briefCard {
            RBriefCard(
                date: card.date,
                length: card.length,
                headline: card.headline,
                subline: card.subline,
                state: card.state,
                collapsed: model.collapsed,
                play: model.play,
                open: model.play,
                retry: { Task { await model.load() } }
            )
            .padding(.horizontal, margin)
            .padding(.top, RDimension.space3)
            .padding(.bottom, RDimension.space3)
            .accessibilityIdentifier("journal.brief")
        }
    }

    // MARK: - The thread

    private var thread: some View {
        ScrollView {
            RLoading(isLoading: model.isLoading) {
                threadContent
            } skeleton: {
                threadSkeleton
            }
            .padding(.horizontal, margin)
            .padding(.vertical, RDimension.space6)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.bottom)
        .scrollDismissesKeyboard(.interactively)
        // the distance to the bottom anchor, in 8pt steps, so scrolling never re-renders per frame
        .onScrollGeometryChange(for: Int.self) { geometry in
            // at rest the thread sits on its bottom anchor: the composer's inset is already
            // inside the offset, so it isn't added again
            let distance = geometry.contentSize.height - geometry.contentOffset.y - geometry.containerSize.height
            return Swift.max(0, Int((distance / RDimension.space2).rounded(.down)))
        } action: { _, steps in
            model.scrollSteps = steps
            withAnimation(reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.snappy) {
                model.collapsed = JournalViewModel.collapsed(distanceToBottom: CGFloat(steps) * RDimension.space2)
            }
        }
        .rProgressiveBlur(topEdge, active: model.collapsed)
        .rProgressiveBlur(.tabEdge)
        .safeAreaInset(edge: .bottom) {
            composer
        }
        .accessibilityIdentifier("journal.thread")
    }

    /// The journal's top edge: its band grows with the scroll, up to the preset's.
    private var topEdge: RProgressiveBlurStyle {
        var style = RProgressiveBlurStyle.journalTop
        style.band = JournalViewModel.topBand(steps: model.scrollSteps)
        return style
    }

    @ViewBuilder
    private var threadContent: some View {
        if let failure = model.failure {
            RErrorState(message: failure.message ?? "retro couldn't be reached. try again.") {
                Task { await model.load() }
            }
            .accessibilityIdentifier("journal.error")
        } else if model.thread.isEmpty {
            REmptyLine(line: "nothing yet. say anything.", subline: "what you say shows up here, by day", symbol: "bubble.left")
                .accessibilityIdentifier("journal.empty")
        } else {
            VStack(spacing: RDimension.space6) {
                ForEach(model.thread) { item in
                    switch item {
                    case let .day(label):
                        Text(label)
                            .rText(.labelMedium)
                            .foregroundStyle(RColor.textLabel)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, RDimension.space2 - RDimension.space6)
                            .accessibilityAddTraits(.isHeader)
                    case let .mine(entry):
                        JournalMessageRow(entry: entry, model: model)
                    case let .retro(entryId, line):
                        RRetroLine(lines: [.init(id: entryId, text: line)])
                    case let .guess(guess):
                        RGuessCard(
                            question: guess.question,
                            from: JournalViewModel.sourceLine(count: guess.restsOn.count),
                            sureness: guess.framework.name,
                            phase: JournalViewModel.phase(guess),
                            answer: { verdict in await model.answer(guess, verdict) },
                            openWhy: {}
                        )
                        .accessibilityIdentifier("journal.guess")
                    }
                }
            }
        }
    }

    /// The thread's shape while it loads: a day label, two of your lines, Retro's line.
    private var threadSkeleton: some View {
        VStack(alignment: .trailing, spacing: RDimension.space6) {
            RSkeleton(bars: [RDimension.layoutControlsWidth - RDimension.space8])
                .frame(maxWidth: RDimension.layoutControlsWidth - RDimension.space8)
            RSkeleton(bars: [nil, RDimension.layoutControlsWidth - RDimension.space12])
            RSkeleton(bars: [RDimension.layoutControlsWidth - RDimension.space16])
                .frame(maxWidth: RDimension.layoutControlsWidth - RDimension.space16)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityIdentifier("journal.skeleton")
    }

    // MARK: - The composer

    private var composer: some View {
        RVoiceComposer(mode: $model.composerMode, text: $model.draft) { text in
            Task { await model.send(text) }
        }
        // the inset proposes the scroll view's height; the bar keeps its own
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, margin)
        .padding(.bottom, RDimension.space2)
        .accessibilityIdentifier("journal.composer")
    }

    // MARK: - The player sheet (P10 fills it)

    private var playerSheet: some View {
        VStack(alignment: .leading, spacing: RDimension.space4) {
            Text("today's brief").rText(.displayTitle).foregroundStyle(RColor.textPrimary)
            ScrollView {
                VStack(alignment: .leading, spacing: RDimension.space4) {
                    ForEach(Array((model.brief?.parts ?? []).enumerated()), id: \.offset) { _, part in
                        Text(part.text)
                            .rText(.bodyReading)
                            .foregroundStyle(RColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .scrollClipDisabled()
            .frame(minHeight: RDimension.space0, maxHeight: .infinity)
            RPill(title: "close", style: .raised) { model.playerShown = false }
                .accessibilityIdentifier("journal.player.close")
        }
        .padding(.bottom, RDimension.spaceScreenMargin)
    }
}

/// One of your entries in the thread: the bubble with its delivery, its retry, and its
/// long-press menu (copy · open this entry ›).
private struct JournalMessageRow: View {
    let entry: Flows.Journal.Entry
    let model: JournalViewModel
    @State private var menuOpen = false

    var body: some View {
        RMessageBubble(text: entry.text, delivery: JournalViewModel.delivery(entry)) {
            Task { await model.retry(entry) }
        }
        .rMessageMenu(isPresented: $menuOpen, rows: [
            RMenuRow(id: "copy", title: "copy", symbol: "doc.on.doc") { model.copy(entry) },
            RMenuRow(id: "open", title: "open this entry", symbol: "arrow.up.right", opensMore: true) { model.openEntry(entry) },
        ])
        .accessibilityIdentifier("journal.entry.\(entry.id)")
    }
}
