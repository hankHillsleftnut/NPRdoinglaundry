//
//  JournalPage.swift
//  P09 JR-1: the journal (docs/team/ui/P09.md; Paper 1FKB-0 on "06 · everything · latest",
//  ios-handoff.md §3). The top bar (C17) with the drawer button and the inky title; the offline
//  line under it when there's no connection; today's brief (C26) anchored under the bar, 12
//  below it, becoming the slim bar as the thread scrolls; the thread in one scroll view, oldest
//  at the top and newest at the bottom (anchored there), 24 between turns, your bubbles (C30.1)
//  with their long-press menu (C20), Retro's lines (C30.2), the one guess (C28), the day label
//  8 above a day's first entry; the voice composer (C14) pinned above the tab bar, with no mic
//  until voice capture exists (`voice`), so its corner is only the lit send; the top edge
//  blurred under the bar and the bottom under the composer (UI0.1). Loading shows the thread's
//  skeleton after 400ms (C39.1); a failed load shows the error with try again (C39.3) and the
//  composer still works. Margins 24 (20 on SE). The sheet host sits at the page
//  root; the brief's play plays it through the one player (`\.playback`, C26.1), and the card's
//  body (or a play with no sound to play) opens the text sheet (P10 fills it). Data comes only
//  through `Flows.JournalData` (`\.journalData`), sample or live.
//
import SwiftUI

/// Reads the flow from the environment and builds the page on it.
struct JournalPageContainer: View {
    /// The person's local day, `YYYY-MM-DD`.
    let today: String
    /// The drawer button's action (JR-3 is not mounted yet: the app root points it at the account page).
    /// Nil draws it inert (first home in the sample flow, FH-Q6 A).
    var openDrawer: (() -> Void)? = {}
    /// ON-13 first home (FH.home): the welcome, the setup recap and the ready first episode.
    var firstDay: FirstDay?
    /// The composer's mic. Off by default: nothing records yet, and a mic that keeps nothing
    /// would lose spoken words (decision 4, no dead controls).
    var voice = false
    @Environment(\.journalData) private var data
    /// The person's player (nil on the sample page: the play opens the text sheet).
    @Environment(\.playback) private var playback

    var body: some View {
        if let data {
            // a new data source, a new player or a new day builds a new page and model
            JournalPage(model: model(for: data))
                .id(PageIdentity(
                    data: ObjectIdentifier(data),
                    player: playback.map { ObjectIdentifier($0) },
                    today: today,
                    firstDay: firstDay != nil
                ))
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
        model.firstDay = firstDay
        model.voice = voice
        model.playback = playback
        return model
    }
}

private struct PageIdentity: Hashable {
    let data: ObjectIdentifier
    let player: ObjectIdentifier?
    let today: String
    /// First home in or out: the host dropping the first day builds a fresh page (FH.home.b).
    let firstDay: Bool
}

struct JournalPage: View {
    @State private var model: JournalViewModel
    @Environment(\.rCompactHeight) private var compactHeight
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
            // inside the host: its request travels up by preference, so a sheet asked for outside
            // the host is never seen (the text sheet never opened before C26.1)
            .rSheet(isPresented: $model.playerShown, detent: .full) {
                playerSheet
            }
        }
        .animation(RMotion.snappy, value: model.isOnline)
        .rOfflineAnnouncement(.page, isOffline: !model.isOnline)
        // M08's land: the confirm haptic once, for the entry this session watched arrive
        .sensoryFeedback(RHaptic.confirm, trigger: model.landed) { old, new in old != new && new != nil }
        .rRetroAnnouncement(landed: model.landed, line: model.landedLine)
        .rErrorHaptic(isFailing: model.failure != nil)
        .rErrorAnnouncement(model.failureLine, attempt: model.loadAttempts)
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
        // C26.1: the starting ring ends when the player answers the tap
        .onChange(of: model.player) { model.notePlayback() }
        .task { await model.loadIfNeeded() }
        .accessibilityIdentifier("screen.JR-1")
    }

    // MARK: - The brief

    @ViewBuilder
    private var briefCard: some View {
        if let firstDay = model.firstDay {
            // ON-13 1FJK-0: the ready first episode in the brief's place, then the welcome (1FJH-0)
            RBriefCard(
                date: "",
                headline: FirstDay.cardTitle,
                state: .firstEpisodeReady(line: firstDay.cardLine, celebrate: firstDay.celebrate),
                play: firstDay.play
            )
            .padding(.horizontal, margin)
            .padding(.top, RDimension.space3)
            .accessibilityIdentifier("journal.brief")
            // at accessibility sizes the welcome scrolls with the thread, so the composer stays on screen
            if !dynamicTypeSize.isAccessibilitySize {
                FirstDayWelcome(name: firstDay.recap.name)
                    .padding(.horizontal, margin)
                    .padding(.top, RDimension.space6)
            }
        } else if let card = model.briefCard {
            RBriefCard(
                date: card.date,
                length: card.length,
                headline: card.headline,
                subline: card.subline,
                state: card.state,
                collapsed: model.collapsed,
                play: { Task { await model.play() } },
                open: model.open,
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
        if let line = model.failureLine {
            RErrorState(message: line) {
                Task { await model.load() }
            }
            .accessibilityIdentifier("journal.error")
        } else if let firstDay = model.firstDay {
            // ON-13 1FIZ-0: the recap at the bottom of the first day, today's entries after it (FH-Q4 A)
            VStack(spacing: RDimension.space5) {
                if dynamicTypeSize.isAccessibilitySize {
                    FirstDayWelcome(name: firstDay.recap.name)
                }
                SetupRecapCard(recap: firstDay.recap)
                threadItems
            }
        } else if model.thread.isEmpty {
            REmptyLine(line: "nothing yet. say anything.", subline: "what you say shows up here, by day", symbol: "bubble.left")
                .accessibilityIdentifier("journal.empty")
        } else {
            threadItems
        }
    }

    private var threadItems: some View {
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
                        answer: { verdict in await model.answer(guess, verdict) }
                    )
                    .accessibilityIdentifier("journal.guess")
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
        RVoiceComposer(mode: $model.composerMode, text: $model.draft, voice: model.voice) { text in
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
/// long-press menu (copy, and "open this entry ›" once the entry page is wired).
private struct JournalMessageRow: View {
    let entry: Flows.Journal.Entry
    let model: JournalViewModel
    @State private var menuOpen = false

    var body: some View {
        RMessageBubble(text: entry.text, delivery: JournalViewModel.delivery(entry)) {
            Task { await model.retry(entry) }
        }
        .rMessageMenu(isPresented: $menuOpen, rows: model.menu(for: entry))
        .accessibilityIdentifier("journal.entry.\(entry.id)")
    }
}
