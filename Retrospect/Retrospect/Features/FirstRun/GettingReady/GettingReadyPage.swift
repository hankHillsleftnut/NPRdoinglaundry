//
//  GettingReadyPage.swift
//  GR.ready, ON-10 getting ready (Paper p-J-0 26LG-0, approved "from approvals · M6 end"): Retro
//  asks one more question while it makes the first episode. The progress line at 92%; the bar row
//  under it kept empty (founder decision 10: no back; nothing on the right); the question in the
//  inky title face; your words arriving under it; then, at the foot of the column (c:getting-ready
//  26LV-0), the tilted "going in" chip, the first episode's making row (RBriefCard
//  `.firstEpisodeMaking`) and "keep talking; it all goes in."; the voice composer listening, with
//  the mic-off corner to type instead. When the episode is made the host hears it (the tease, ON-11).
//  On a short phone or at accessibility sizes the column scrolls, with the progressive blur at the
//  composer. Data and decisions come only through `GettingReadyModel`.
//
import SwiftUI

/// Builds the page and its model on the seams; `onReady` is called once, when the episode is made.
struct GettingReadyPageContainer: View {
    let firstRun: any Flows.FirstRun
    let episode: any Flows.FirstEpisode
    let listening: any Flows.Listening
    /// The `this.week` answer kept from an earlier launch (the sample flow's resume).
    var kept: String?
    var onAnswered: (Flows.QuestionKey, String) -> Void = { _, _ in }
    var onReady: () -> Void = {}

    @State private var model: GettingReadyModel?

    var body: some View {
        if let model {
            GettingReadyPage(model: model)
        } else {
            // the model is made once, with the page (SwiftUI may build this view more than once)
            RColor.backgroundCanvas
                .ignoresSafeArea()
                .onAppear { model = makeModel() }
        }
    }

    private func makeModel() -> GettingReadyModel {
        let model = GettingReadyModel(firstRun: firstRun, episode: episode, listening: listening, kept: kept)
        model.onAnswered = onAnswered
        model.onReady = onReady
        return model
    }
}

struct GettingReadyPage: View {
    @Bindable var model: GettingReadyModel
    var progress: FlowProgress = GettingReadyModel.progress

    @Environment(\.rCompactHeight) private var compactHeight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Where the progress line is drawn: `from` on the first frame, `to` once the page is up.
    @State private var shownProgress: Double?
    @State private var overflows = false

    /// 20 on the smallest phones (craft 8.4), 24 elsewhere.
    private var margin: CGFloat {
        compactHeight ? RDimension.space5 : RDimension.spaceScreenMargin
    }

    /// Things arriving and leaving on the page: the standard curve, a short fade with Reduce Motion.
    private var motion: Animation {
        reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.standard(RNumber.motionDurationSlow)
    }

    var body: some View {
        VStack(spacing: RDimension.space0) {
            RProgressHairline(fraction: shownProgress ?? (reduceMotion ? progress.to : progress.from))
                .padding(.horizontal, margin)
                .accessibilityIdentifier("gettingReady.progress")
            // Paper's bar row (26N2-0): 16 under the line, 44 tall. Its back chevron is not built
            // (founder decision 10: no back while the episode is made); the row keeps the question
            // where every onboarding page puts it.
            Color.clear
                .frame(height: RDimension.sizeNavBar)
                .padding(.top, compactHeight ? RDimension.space2 : RDimension.space4)
                .accessibilityHidden(true)
            GeometryReader { proxy in
                ScrollView {
                    // at least the visible height, so the getting-ready block sits at the foot (Paper's
                    // margin-top: auto); taller (SE, accessibility sizes) and the column scrolls
                    AtLeastHeight(minHeight: proxy.size.height) {
                        column
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentSize.height > geometry.containerSize.height
                } action: { _, now in
                    overflows = now
                }
                .rProgressiveBlur(.tabEdge, active: overflows)
            }
            composer
        }
        .background(RColor.backgroundCanvas.ignoresSafeArea())
        // an answer that wasn't kept: the error haptic, and VoiceOver hears where the words went
        .rErrorHaptic(isFailing: model.isFailing)
        .rErrorAnnouncement(model.isFailing ? QuestionsModel.offlineLine : nil, attempt: model.failures)
        .task { await model.run() }
        .onAppear {
            shownProgress = progress.to
            AccessibilityNotification.Announcement(GettingReadyModel.arrival).post()
        }
        .onDisappear { model.pageLeft() }
        .onChange(of: model.phase) { _, phase in
            if phase == .ready {
                AccessibilityNotification.Announcement(GettingReadyModel.readyAnnouncement).post()
            }
        }
        .accessibilityIdentifier("screen.ON-10")
    }

    // MARK: - The column

    /// The question and your words at the top; the getting-ready block at the foot (Paper 26LU-0:
    /// 32 above, 16 below, 24 between; the block's margin-top is auto).
    private var column: some View {
        VStack(alignment: .leading, spacing: RDimension.space6) {
            Text(GettingReadyModel.question)
                .rText(.inkTitle)
                .foregroundStyle(RColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .modifier(BalancedLines())
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("gettingReady.question")
            if !model.words.isEmpty {
                HeardWords(words: model.words)
                    .transition(.rBlurReplace(reduceMotion: reduceMotion))
            }
            Spacer(minLength: RDimension.space0)
            gettingReady
        }
        // Paper's column is the screen less its margins (354 on the 402 phone), not the reading width
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, margin)
        .padding(.top, compactHeight ? RDimension.space6 : RDimension.space8)
        .padding(.bottom, RDimension.space4)
        .animation(motion, value: model.words.isEmpty)
    }

    /// c:getting-ready (26LV-0): 16 above, 8 below, 12 between; the chip overlaps the card by 4.
    private var gettingReady: some View {
        VStack(alignment: .leading, spacing: RDimension.space3) {
            if let goingIn = model.goingIn {
                GoingInChip(text: goingIn)
                    .padding(.leading, RDimension.space6)
                    .padding(.bottom, -RDimension.space1)
                    .transition(.rBlurReplace(reduceMotion: reduceMotion))
            }
            RBriefCard(
                date: "",
                headline: GettingReadyModel.cardTitle,
                state: .firstEpisodeMaking(line: GettingReadyModel.cardLine, progress: model.episodeProgress),
                play: {}
            )
            Text(GettingReadyModel.keepTalking)
                .rText(.metaLine)
                .foregroundStyle(RColor.textLabel)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, RDimension.space1)
                .accessibilityIdentifier("gettingReady.keepTalking")
        }
        .padding(.top, RDimension.space4)
        .padding(.bottom, RDimension.space2)
        .animation(motion, value: model.goingIn == nil)
    }

    // MARK: - The composer

    /// Listening (Paper 26LI-0), the mic-off corner to type; muted it is the field with the lit send.
    private var composer: some View {
        RVoiceComposer(
            mode: Binding(get: { model.composerMode }, set: { model.setComposerMode($0) }),
            text: $model.draft,
            placeholder: "type your answer…",
            fieldLabel: "your answer"
        ) { text in
            Task { await model.sendTyped(text) }
        }
        // the inset proposes the full height; the bar keeps its own
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, margin)
        // the questions' 8 over the home indicator (ON-3–9, ON-5)
        .padding(.bottom, RDimension.space2)
        .accessibilityIdentifier("gettingReady.composer")
    }
}

/// Lays its one child out at least `minHeight` tall: the child's natural height when that is more,
/// else exactly `minHeight`, proposed to the child so a Spacer inside it takes the rest. (A frame's
/// minHeight inside a ScrollView proposes no height, so the Spacer would get none.)
private struct AtLeastHeight: SwiftUI.Layout {
    let minHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let natural = child.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: proposal.width ?? natural.width, height: max(natural.height, minHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        subviews.first?.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
    }
}

#if DEBUG
#Preview("getting ready · live") { GettingReadyLaunch(scenario: .gettingReady) }
#Preview("getting ready · Paper's frame") { GettingReadyLaunch(scenario: .gettingReadyStill) }
#endif
