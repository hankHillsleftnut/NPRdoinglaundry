//
//  GoalsPage.swift
//  V2.goals · GL-1 goals (Paper 1FZO-0, slot 16I1-0). The tab page: the title bar (RTopBar `.title`,
//  "goals"), then one scrolling column 24 from the edges, 12 under the bar, 16 between: Retro's guess
//  first ("questions lead"), the goals, and the quiet ended row. The column fades into the progressive
//  blur above the tab bar (1G0A-0 / 1G09-0: RProgressBlur `.tabEdge`). The tab bar itself is the
//  shell's (or the launcher's stand-in): this page ends at its top.
//
//  Hidden until drawn (no dead controls): the bar's "+" (GL-D1) and the ended row's › (GL-D2).
//
import SwiftUI

struct GoalsPage: View {
    @Bindable var model: GoalsModel
    /// Opens a goal (GL-2); nil while there is nowhere to open it.
    var openGoal: ((GoalSummary) -> Void)?
    /// Which goals have a GL-2 to open; the others are plain cards. No by default (GL-D11).
    var canOpen: (GoalSummary) -> Bool = { _ in false }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: RDimension.space0) {
            // Paper's "+" (1G3K-0) opens an add sheet that isn't drawn: hidden (GL-D1)
            RTopBar(variant: .title(title: "goals", trailing: .none))
            ScrollView {
                if let overview = model.overview {
                    column(overview)
                }
            }
            .scrollIndicators(.hidden)
            .rProgressiveBlur(.tabEdge)
        }
        .background(RColor.backgroundCanvas.ignoresSafeArea())
        .task { await model.load() }
        .accessibilityIdentifier("goals")
    }

    private func column(_ overview: GoalsOverview) -> some View {
        LazyVStack(alignment: .leading, spacing: RDimension.space4) {
            if let guess = overview.guess {
                GoalGuessCard(guess: guess) { accepted in
                    Task { await answer(guess, accepted: accepted) }
                }
                .transition(.opacity)
            }
            ForEach(overview.goals) { goal in
                GoalCard(goal: goal, open: canOpen(goal) ? openGoal.map { open in { open(goal) } } : nil)
                    .transition(.opacity)
            }
            if let ended = overview.endedLine {
                GoalEndedRow(line: ended)
            }
        }
        .padding(.horizontal, RDimension.spaceScreenMargin)
        .padding(.top, RDimension.space3)
        .padding(.bottom, RDimension.space8)
        // an answer or a turn-off lands: the guess leaves, a goal joins or leaves, on the settle spring
        .animation(reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.settle, value: overview)
    }

    private func answer(_ guess: GoalGuess, accepted: Bool) async {
        await model.answer(guess, accepted: accepted)
        AccessibilityNotification.Announcement(accepted ? "added to your goals" : "guess removed").post()
    }
}
