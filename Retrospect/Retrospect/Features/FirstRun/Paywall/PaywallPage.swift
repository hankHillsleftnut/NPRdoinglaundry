//
//  PaywallPage.swift
//  PW.paywall, ON-12 "the plans are the buttons" (Paper p-J-0 22M4-0, approved "from approvals ·
//  decision 06"), on sample data. Top (22TP-0): the collapsed tease as a paused mini-player and the inky
//  "hear the rest, and one every week." Middle (22MR-0): six benefits that scroll when they don't fit
//  (22Q9-0 "benefits · scroll"). Thumb zone (22M5-0): a 64 fade to the canvas, the two plan buttons and
//  restore · privacy · terms. Founder, 26 Oct night: no "not now" (22ME-0) and no "yearly works out to…"
//  line (22MP-0): both removed, PAPER-UPDATE; restore/privacy/terms do nothing yet; the mini-player's
//  play nudges the lit plan instead of replaying. The thumb zone sits on the bottom safe area (§10).
//
import SwiftUI

struct PaywallPage: View {
    @State private var model: PaywallModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(model: PaywallModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // accessibility text sizes: one scroll for the whole page, so nothing is cut or squeezed
                ScrollView {
                    VStack(spacing: RDimension.space0) {
                        top
                        benefitList
                        decision
                    }
                }
            } else {
                VStack(spacing: RDimension.space0) {
                    top
                    benefits
                    decision
                }
            }
        }
        .background(RColor.backgroundCanvas.ignoresSafeArea())
        .task { await model.load() }
        .accessibilityIdentifier("paywall")
    }

    // MARK: top (22TP-0)

    private var top: some View {
        VStack(alignment: .leading, spacing: RDimension.space6) {
            RMiniPlayer(
                title: model.tease.title,
                subline: model.tease.subline,
                artwork: RArtworkRecipes.weekly,
                phase: .paused,
                progress: model.tease.progress,
                open: nil,
                well: { model.nudge() },
                wellHint: Self.playHint,
                wellHaptic: Self.playTapPressHaptic
            )
            Text(Self.headline)
                .rText(.inkTitle)
                .foregroundStyle(RColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .rBalancedLines()
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.vertical, RDimension.space2)
        .padding(.horizontal, RDimension.spaceScreenMargin)
    }

    // MARK: middle (22MR-0 → 22Q9-0)

    private var benefitList: some View {
        VStack(spacing: RDimension.space1) {
            ForEach(Benefit.paper) { BenefitRow(benefit: $0) }
        }
        .padding(.horizontal, RDimension.spaceScreenMargin)
        .padding(.top, RDimension.space4)
    }

    private var benefits: some View {
        ScrollView {
            benefitList
                // room for the fade, so the last row can scroll clear of it
                .padding(.bottom, RDimension.space16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .frame(maxHeight: .infinity)
    }

    // MARK: thumb zone (22M5-0)

    private var decision: some View {
        VStack(spacing: RDimension.space3) {
            if let offer = model.offer {
                // side by side as Paper draws them; stacked at accessibility text sizes, so no price is cut
                // (the badge keeps its room above the lit plan either way)
                let pair = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: RDimension.space8))
                    : AnyLayout(HStackLayout(spacing: RDimension.space3))
                pair {
                    PlanButton(plan: offer.monthly, lit: false) { choose(.monthly) }
                    PlanButton(plan: offer.yearly, lit: true, saving: offer.saving) { choose(.yearly) }
                        .rNudge(trigger: model.nudges)
                }
                .padding(.top, RDimension.space2)
            }
            links
        }
        .padding(.horizontal, RDimension.spaceScreenMargin)
        .padding(.top, RDimension.space4)
        .background(RColor.backgroundCanvas)
        .overlay(alignment: .top) {
            // 22MQ-0: a 64 fade from nothing to the canvas, above the zone, over the scrolling rows
            LinearGradient(colors: [RColor.backgroundCanvas.opacity(0), RColor.backgroundCanvas], startPoint: .top, endPoint: .bottom)
                .frame(height: RDimension.space16)
                .offset(y: -RDimension.space16)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// restore · privacy · terms (22MB-0, 22M9-0, 22M7-0): drawn, inert (DECISIONS 7; PW-Q5 A).
    private var links: some View {
        // one row as drawn; stacked at accessibility text sizes so no word is cut
        let row = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: RDimension.space0))
            : AnyLayout(HStackLayout(spacing: RDimension.space2))
        return row {
            ForEach(Self.links, id: \.self) { word in
                Text(word)
                    .rText(.metaLine)
                    .foregroundStyle(RColor.textLabel)
                    .fixedSize()
                    .padding(.horizontal, RDimension.space2)
                    .frame(minHeight: RDimension.sizeTouchTarget)
                    .accessibilityLabel(word)
                    .accessibilityValue(Self.notYet)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func choose(_ choice: PaywallModel.Choice) {
        Task { await model.choose(choice) }
    }

    static let headline = "hear the rest, and one every week."
    /// PW-Q9 (founder, 27 Oct): what VoiceOver hears after "play" on the little player, since a tap
    /// nudges the lit plan instead of playing.
    static let playHint = "the rest comes with a plan"
    /// The little player's play gives ONE haptic per tap: the nudge's selection haptic at its peak.
    /// So the well's own press haptic is off here (nil), or a tap would give two.
    static let playTapPressHaptic: SensoryFeedback? = nil
    static let links = ["restore", "privacy", "terms"]
    static let notYet = "not available yet"
}

#if DEBUG
#Preview("paywall") { PaywallPage(model: PaywallModel(paywall: SamplePaywall()) { _ in }) }
#endif
