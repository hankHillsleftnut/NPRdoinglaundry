//
//  QuestionsPage.swift
//  P02.min, ON-3–9: the onboarding questions (Paper "05 · the app in order" `col · ON-3–9`,
//  frame ON-4a; offline from 05b ON-4a "offline (answer kept)"). The progress hairline under
//  the status bar (3pt surface.track, ink fill creeping forward each question, never a count;
//  VoiceOver reads "step 3 of 8"); a quiet back chevron top-left and nothing on the right (no
//  skip, founder rule; Paper still draws one); Retro's question in the inky title face; your
//  words under it once sent, inky at 2xl in text.secondary; the offline line under them when a
//  send wasn't kept; the voice composer pinned at the bottom with no mic (typing only; the
//  keyboard's own dictation is how a person talks in 0.1). Each question blur-replaces the last
//  (a cross-fade with Reduce Motion; the M13 type-out is out of scope). Margins 24 (20 on SE).
//  Data comes only through `Flows.FirstRun`, sample or live; the host hears `onDone` once.
//
import SwiftUI

extension RTextStyle {
    /// Your words under the question: the inky card face at --text-2xl, card tracking, leading
    /// snug (Paper `c:onboarding/your-words`).
    static let answerWords = RTextStyle(
        family: .inky(axis: -10),
        size: RDimension.fontSize2xl,
        weight: .regular,
        tracking: RNumber.fontTrackingCard,
        leading: RTextStyle.body.leading,
        relativeTo: .title2
    )
}

/// Builds the page and its model on a `Flows.FirstRun`; `onDone` is called once, when every
/// question is answered and the seam has been told.
struct QuestionsPageContainer: View {
    let data: any Flows.FirstRun
    /// The questions' part of the first run's progress bar.
    var flowRange: ClosedRange<Double> = QuestionsModel.flowProgress
    /// Words kept from an earlier launch (the sample flow's resume); empty for a fresh page.
    var kept: [Flows.QuestionKey: String] = [:]
    /// Each answer the seam kept, for a host that keeps the words.
    var onAnswered: (Flows.QuestionKey, String) -> Void = { _, _ in }
    /// Opened by the next page's back (the sample flow, FLOW.edges): on the last question, words kept.
    var cameBack = false
    var onDone: () -> Void = {}

    var body: some View {
        QuestionsPage(model: model())
            .id(ObjectIdentifier(data))
    }

    private func model() -> QuestionsModel {
        let model = QuestionsModel(data: data, flowRange: flowRange, kept: kept, cameBack: cameBack)
        model.onAnswered = onAnswered
        model.onDone = onDone
        return model
    }
}

struct QuestionsPage: View {
    @State private var model: QuestionsModel
    /// Always muted: there is no recorder in 0.1, so the composer is a text field with the lit send.
    @State private var composerMode: RVoiceComposer.Mode = .muted
    @Environment(\.rCompactHeight) private var compactHeight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: QuestionsModel) {
        _model = State(initialValue: model)
    }

    private var margin: CGFloat {
        compactHeight ? RDimension.spaceListInset : RDimension.spaceScreenMargin
    }

    /// The page's moves: the spring, or a short cross-fade with Reduce Motion.
    private var motion: Animation {
        reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.snappy
    }

    var body: some View {
        VStack(spacing: RDimension.space0) {
            progressBar
            topBar
            ScrollView {
                question
                    .padding(.horizontal, margin)
                    .padding(.top, compactHeight ? RDimension.space6 : RDimension.space8)
                    .padding(.bottom, RDimension.space6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .rProgressiveBlur(.tabEdge)
            .safeAreaInset(edge: .bottom) {
                composer
            }
        }
        .background(RColor.backgroundCanvas)
        // a send that wasn't kept: the error haptic and the offline line read out, once each
        .rErrorHaptic(isFailing: model.offline)
        .rErrorAnnouncement(model.offline ? QuestionsModel.offlineLine : nil, attempt: model.failures)
        // a new question replaced the last: VoiceOver hears it (not on open; the screen reads itself)
        .onChange(of: model.question?.key) {
            if let announcement = model.announcement {
                AccessibilityNotification.Announcement(announcement).post()
            }
        }
        .task { await model.appear() }
        .accessibilityIdentifier("screen.ON-3")
    }

    // MARK: - Progress and the bar

    /// The one global progress bar: 3pt, ink creeping forward over the track.
    private var progressBar: some View {
        RColor.surfaceTrack
            .frame(height: RDimension.sizeProgress)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    RColor.inkDefault
                        .frame(width: proxy.size.width * model.progress)
                }
            }
            .clipShape(RShape.rect(RDimension.radiusSmall))
            .animation(motion, value: model.progress)
            .padding(.horizontal, margin)
            .accessibilityElement()
            .accessibilityLabel(model.stepLabel)
            .accessibilityIdentifier("questions.progress")
    }

    /// The quiet back chevron; nothing on the right.
    private var topBar: some View {
        HStack(spacing: RDimension.space0) {
            // Paper c:top-bar/onboarding: the chevron in a 32 wash circle inside a 44 hit area
            RIconButton(symbol: "chevron.left", label: "back", role: .inField) {
                withAnimation(motion) {
                    model.back()
                }
            }
            .opacity(model.canGoBack ? 1 : 0)
            .allowsHitTesting(model.canGoBack)
            .accessibilityHidden(!model.canGoBack)
            .accessibilityIdentifier("questions.back")
            Spacer(minLength: RDimension.space0)
        }
        // the 44 hit area is centred on its 32 circle; the circle's edge sits on the margin, as in Paper
        .padding(.horizontal, margin - (RDimension.sizeControlDefault - RDimension.sizeControlSmall) / 2)
        .frame(minHeight: RDimension.sizeNavBar)
        .padding(.top, RDimension.space4)
    }

    // MARK: - The question

    @ViewBuilder
    private var question: some View {
        if let current = model.question {
            VStack(alignment: .leading, spacing: RDimension.space6) {
                Text(current.text)
                    .rText(.inkTitle)
                    .foregroundStyle(RColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("questions.question")
                if let answer = model.answer {
                    Text(answer)
                        .rText(.answerWords)
                        .foregroundStyle(RColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("questions.answer")
                }
                if model.offline {
                    Text(QuestionsModel.offlineLine)
                        .rText(.textMd)
                        .foregroundStyle(RColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .rBlurReplace()
                        .accessibilityIdentifier("questions.offline")
                }
            }
            .frame(maxWidth: RDimension.layoutReadingWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(current.key)
            .rBlurReplace()
            // the offline line comes and goes with its own blur; what's around it moves on the spring
            .animation(motion, value: model.offline)
        }
    }

    // MARK: - The composer

    private var composer: some View {
        RVoiceComposer(
            mode: $composerMode,
            text: $model.draft,
            voice: false,
            placeholder: "type your answer…",
            fieldLabel: "your answer"
        ) { text in
            Task { await model.send(text) }
        }
        // the inset proposes the scroll view's height; the bar keeps its own
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, margin)
        .padding(.bottom, RDimension.space2)
        .accessibilityIdentifier("questions.composer")
    }
}
