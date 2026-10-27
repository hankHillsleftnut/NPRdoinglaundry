//
//  GoalPage.swift
//  V2.goals · GL-2 one goal (Paper 1G3Z-0, slot 16I9-0). A pushed page (no tab bar): the entry bar with
//  back only (Paper's "edit" opens rename mode, which isn't drawn: GL-D9), then a column 24 from the
//  edges, 16 under the bar, 32 between groups: the goal in the inky title over its said line; "did this
//  week · …" over one grouped panel of evidence rows; the pattern guess. "turn off" sits quietly at the
//  foot, centred. Paper's foot is 76 with 32 under the pill measured to the screen edge, so most of that
//  32 is the home indicator's safe area: the pill keeps 8 above the safe area (SE has none, so 8 still
//  holds it off the edge).
//
//  Paper draws › on every evidence row (GL-D8): your own words open their entry when the host can show
//  one (`openEntry`); the others have nothing drawn behind them, so they are plain rows.
//
import SwiftUI

struct GoalPage: View {
    @Bindable var model: GoalModel
    let back: () -> Void
    /// Opens an entry (JR-4) by id; nil while there is nowhere to show one.
    var openEntry: ((String) -> Void)?
    /// After "turn off" the page is gone: the host goes back to GL-1 and reads it again.
    var turnedOff: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: RDimension.space0) {
            RTopBar(variant: .entry(.back(back: back)))
            ScrollView {
                if let detail = model.detail {
                    column(detail)
                }
            }
            .scrollIndicators(.hidden)
            if model.detail != nil {
                foot
            }
        }
        .background(RColor.backgroundCanvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.load() }
        .onChange(of: model.state) { _, state in
            if state == .gone {
                turnedOff()
            }
        }
        .accessibilityIdentifier("goal")
    }

    private func column(_ detail: GoalDetail) -> some View {
        VStack(alignment: .leading, spacing: RDimension.space8) {
            VStack(alignment: .leading, spacing: RDimension.space2) {
                Text(detail.title)
                    .rText(.inkTitle)
                    .foregroundStyle(RColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(detail.saidLine)
                    .rText(.metaLine)
                    .foregroundStyle(RColor.textLabel)
            }
            if !detail.evidence.isEmpty {
                VStack(alignment: .leading, spacing: RDimension.space2) {
                    Text(detail.didHeading)
                        .rText(.labelMedium)
                        .foregroundStyle(RColor.textLabel)
                        .accessibilityAddTraits(.isHeader)
                    REvidenceGroup {
                        ForEach(detail.evidence) { evidence in
                            REvidenceRow(
                                leading: .kind(symbol: evidence.symbol),
                                meta: evidence.meta,
                                words: evidence.words,
                                action: destination(for: evidence)
                            )
                        }
                    }
                }
            } else {
                Text(detail.didHeading)
                    .rText(.labelMedium)
                    .foregroundStyle(RColor.textLabel)
            }
            if let pattern = detail.pattern {
                GoalGuessCard(guess: pattern, padding: .compact) { accepted in
                    Task {
                        await model.answer(pattern, accepted: accepted)
                        AccessibilityNotification.Announcement("guess answered").post()
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, RDimension.spaceScreenMargin)
        .padding(.top, RDimension.space4)
        .padding(.bottom, RDimension.space6)
        .animation(reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.settle, value: detail)
    }

    private func destination(for evidence: GoalEvidence) -> (() -> Void)? {
        guard let entryID = evidence.entryID, let openEntry else { return nil }
        return { openEntry(entryID) }
    }

    /// "turn off" (1G40-0): the neutral pill, centred, 8 above the bottom safe area.
    private var foot: some View {
        RPill(title: "turn off", style: .neutral) {
            Task { await model.turnOff() }
        }
        .accessibilityHint("takes the goal off your list")
        .frame(maxWidth: .infinity)
        .padding(.horizontal, RDimension.spaceScreenMargin)
        .padding(.bottom, RDimension.space2)
    }
}
