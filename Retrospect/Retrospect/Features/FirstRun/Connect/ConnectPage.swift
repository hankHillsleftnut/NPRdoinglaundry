//
//  ConnectPage.swift
//  CN.connect, ON-6 (Paper p-J-0 2190-0, "approved · from approvals · ON-6"): Retro asks to get to
//  know you. The progress line at 55%; a quiet back chevron and nothing on the right (no skip); the
//  inky title, one plain line and the knows-you meter; the sources in two groups, "on this iPhone"
//  and "your other apps" (its "see all" hidden until its page is drawn: founder decision 5); the lit
//  "continue" and the text "later" in the thumb zone, both on to getting ready. On a short phone or
//  at accessibility sizes the column scrolls under a progressive blur. Data and decisions come only
//  through `ConnectModel`.
//
import SwiftUI

struct ConnectPage: View {
    let model: ConnectModel
    var progress: FlowProgress = ConnectModel.progress

    @Environment(\.rCompactHeight) private var compactHeight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Where the progress line is drawn: `from` on the first frame, `to` once the page is up.
    @State private var shownProgress: Double?
    @State private var overflows = false

    /// 20 on the smallest phones (craft 8.4), 24 elsewhere.
    private var margin: CGFloat {
        compactHeight ? RDimension.space5 : RDimension.spaceScreenMargin
    }

    var body: some View {
        VStack(spacing: RDimension.space0) {
            RProgressHairline(fraction: shownProgress ?? (reduceMotion ? progress.to : progress.from))
                .padding(.horizontal, margin)
                .accessibilityIdentifier("connect.progress")
            topBar
            ScrollView {
                column
            }
            .scrollBounceBehavior(.basedOnSize)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentSize.height > geometry.containerSize.height
            } action: { _, now in
                overflows = now
            }
            .rProgressiveBlur(.tabEdge, active: overflows)
            thumbZone
        }
        .background(RColor.backgroundCanvas.ignoresSafeArea())
        // every line box as Paper draws it (whole points; the inky title's tight 33), so the column
        // lands on Paper's numbers instead of drifting half a point per line
        .environment(\.rPaperLineBoxes, true)
        // Paper measures the thumb zone's 32 from the screen's bottom edge, under the home indicator
        .ignoresSafeArea(.container, edges: .bottom)
        .sensoryFeedback(RHaptic.confirm, trigger: model.connections)
        .onAppear {
            shownProgress = progress.to
            AccessibilityNotification.Announcement(ConnectModel.arrival).post()
        }
        .onChange(of: model.connections) {
            if let announcement = model.announcement {
                AccessibilityNotification.Announcement(announcement).post()
            }
        }
        .accessibilityIdentifier("screen.ON-6")
    }

    // MARK: - Top bar

    /// The quiet back chevron (a 32 wash circle in its 44 hit area, on the margin); nothing on the
    /// right (screen-rules 6). Paper 21C7-0.
    private var topBar: some View {
        HStack(spacing: RDimension.space0) {
            RIconButton(symbol: "chevron.left", label: "back", role: .inField) { model.back() }
                .accessibilityIdentifier("connect.back")
            Spacer(minLength: RDimension.space0)
        }
        // Paper draws the 32 circle on the margin at the 44 box's leading edge; ours is centred in it
        .padding(.horizontal, margin - (RDimension.sizeTouchTarget - RDimension.sizeControlSmall) / 2)
        .frame(minHeight: RDimension.sizeNavBar)
        .padding(.top, compactHeight ? RDimension.space2 : RDimension.space4)
    }

    // MARK: - The column (Paper 2196-0)

    private var column: some View {
        VStack(alignment: .leading, spacing: compactHeight ? RDimension.space5 : RDimension.space6) {
            intro
            VStack(alignment: .leading, spacing: RDimension.space4) {
                section(ConnectModel.onThisIphoneLabel, sources: model.onThisIphone, id: "onThisIphone")
                section(ConnectModel.yourOtherAppsLabel, sources: model.yourOtherApps, id: "yourOtherApps")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, compactHeight ? RDimension.space5 : RDimension.space8)
        .padding(.bottom, RDimension.space4)
    }

    /// The title, its one plain line and the meter (Paper 21C0-0).
    private var intro: some View {
        VStack(alignment: .leading, spacing: RDimension.space3) {
            Text(ConnectModel.title)
                .rText(.inkTitle)
                .foregroundStyle(RColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                // Paper 21C6-0 text-wrap: balance (one line on the 17 Pro; two even lines on SE)
                .rBalancedLines()
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("connect.title")
                .rAppear(index: 0)
            Text(ConnectModel.body)
                .rText(.textMd)
                .foregroundStyle(RColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("connect.body")
                .rAppear(index: 1)
            RKnowsYouMeter(fraction: model.knowsYou.fraction, label: model.meterWords)
                .accessibilityIdentifier("connect.meter")
                .rAppear(index: 2)
        }
        .padding(.horizontal, margin)
    }

    /// A section label and its rows, hairlines between them inset after the well and stopping at
    /// the margin (Paper 21AQ-0 / 2198-0). A group with nothing in it isn't drawn.
    @ViewBuilder
    private func section(_ title: String, sources: [Flows.ConnectSource], id: String) -> some View {
        if !sources.isEmpty {
            VStack(alignment: .leading, spacing: RDimension.space0) {
                RSectionLabel(title: title)
                    .padding(.horizontal, margin)
                ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                    if index > 0 {
                        RHairline(inset: .afterIcon)
                            .padding(.horizontal, margin)
                    }
                    row(source)
                }
            }
            .accessibilityIdentifier("connect.section.\(id)")
            .rAppear(index: 3)
        }
    }

    private func row(_ source: Flows.ConnectSource) -> some View {
        RSourceRow(
            title: source.name,
            purpose: source.purpose,
            symbol: source.symbol,
            state: source.state == .connected ? .connected : .notConnected,
            density: .onboarding,
            margin: margin,
            connect: { Task { await model.connect(source.id) } }
        )
        // while another source's connect is out, this pill can't start a second one (VoiceOver: dimmed)
        .disabled(!model.canConnect(source) && source.state != .connected)
        .accessibilityIdentifier("connect.row.\(source.id)")
    }

    // MARK: - The thumb zone (Paper 2191-0)

    /// The lit "continue" and the text "later": both go on to getting ready (founder decision 5).
    /// "continue" appears once the meter reaches `ConnectModel.continueAppearsAtMeter` (founder,
    /// 26 Oct); "later" is always there.
    private var thumbZone: some View {
        VStack(spacing: RDimension.space2) {
            if model.showsContinue {
                RButton(title: ConnectModel.continueTitle) { model.continueOn() }
                    .accessibilityIdentifier("connect.continue")
                    .transition(.rBlurReplace(reduceMotion: reduceMotion))
            }
            RButton(title: ConnectModel.laterTitle, variant: .text) { model.later() }
                .accessibilityIdentifier("connect.later")
        }
        .animation(
            reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.standard(RNumber.motionDurationBase),
            value: model.showsContinue
        )
        .padding(.horizontal, margin)
        .padding(.top, RDimension.space4)
        // 32 above the screen's edge (Paper); a phone with no home indicator keeps a tighter 16
        .padding(.bottom, compactHeight ? RDimension.space4 : RDimension.space8)
    }
}

/// ON-6 with a fresh model for each visit, the way the host and the launcher mount it.
struct ConnectPageContainer: View {
    @State private var model: ConnectModel

    init(
        data: any Flows.Connect,
        onDone: @escaping (ConnectModel.Exit) -> Void,
        onBack: @escaping () -> Void
    ) {
        _model = State(initialValue: ConnectModel(data: data, onDone: onDone, onBack: onBack))
    }

    var body: some View {
        ConnectPage(model: model)
    }
}

#if DEBUG
#Preview("connect · calendar connected") {
    ConnectPageContainer(data: SampleConnect(), onDone: { _ in }, onBack: {})
}
#endif
