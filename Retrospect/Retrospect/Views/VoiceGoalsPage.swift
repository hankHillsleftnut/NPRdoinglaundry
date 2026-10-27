//
//  VoiceGoalsPage.swift
//  Retrospect
//
//  18-question onboarding flow. Stella-style structure (question at top,
//  input bar above keyboard, no subtitle, no counter) using Retrospect's
//  design system (OnboardingStyle colors, HedvigLettersSerif, existing components).
//

import SwiftUI
import UIKit

// MARK: - Question model

private struct Question {
    let text: String        // may contain {name}
    let placeholder: String
    let keyboardType: UIKeyboardType
    let inputType: InputType
    let hasAcknowledgment: Bool
    let progress: Double

    enum InputType {
        case text
        case pillsVertical([String])
        case pillsGrid([String])
    }

    init(
        _ text: String,
        placeholder: String = "",
        keyboard: UIKeyboardType = .default,
        input: InputType = .text,
        ack: Bool = false,
        progress: Double
    ) {
        self.text = text
        self.placeholder = placeholder
        self.keyboardType = keyboard
        self.inputType = input
        self.hasAcknowledgment = ack
        self.progress = progress
    }
}

// MARK: - Flow phase

private enum FlowPhase: Equatable {
    case welcome(Int)           // line index 0..2
    case question(Int)          // question index 0..17
    case acknowledgment(Int)    // after question index
    case bridge(Int, Int)       // (bridgeIdx, lineIdx)
    case processing
    case revealing
    case complete

    static func == (lhs: FlowPhase, rhs: FlowPhase) -> Bool {
        switch (lhs, rhs) {
        case (.welcome(let a), .welcome(let b)): return a == b
        case (.question(let a), .question(let b)): return a == b
        case (.acknowledgment(let a), .acknowledgment(let b)): return a == b
        case (.bridge(let a, let b), .bridge(let c, let d)): return a == c && b == d
        case (.processing, .processing), (.revealing, .revealing), (.complete, .complete): return true
        default: return false
        }
    }

    var key: String {
        switch self {
        case .welcome(let l): return "w\(l)"
        case .question(let i): return "q\(i)"
        case .acknowledgment(let i): return "a\(i)"
        case .bridge(let b, let l): return "br\(b)l\(l)"
        case .processing: return "proc"
        case .revealing: return "rev"
        case .complete: return "done"
        }
    }
}

// MARK: - VoiceGoalsPage

struct VoiceGoalsPage: View {
    var onComplete: (([RichGoal], String) -> Void)?
    /// Escape hatch for the demo/preview podcast player below — it plays a
    /// placeholder episode with no real goals behind it, so closing it should
    /// drop straight into the app rather than back into a completeScreen with
    /// no further way forward.
    var onDebugGoHome: (() -> Void)?

    // ── Questions ─────────────────────────────────────────────────────────
    private static let questions: [Question] = [
        // Part 1 — Identity (Q1-Q6)
        Question("First, what should I call you?",
                 placeholder: "Your name", ack: true, progress: 0.08),
        Question("Where do you live, {name}?",
                 placeholder: "City, country...", progress: 0.10),
        Question("How old are you?",
                 placeholder: "Your age", keyboard: .numberPad, progress: 0.12),
        Question("What's your gender?",
                 input: .pillsVertical(["Female", "Male", "Non-binary", "Prefer not to say"]), progress: 0.14),
        Question("What is your sexuality?",
                 placeholder: "e.g. Straight, Gay, Bisexual...", progress: 0.16),
        Question("What's your relationship status?",
                 input: .pillsVertical(["Single", "In a relationship", "Married", "It's complicated"]), progress: 0.18),
        // Part 2 — Work (Q7-Q8)
        Question("What do you do for work?",
                 placeholder: "Designer, student, founder...", progress: 0.20),
        Question("How do you feel about it?",
                 input: .pillsVertical(["Love it", "It's fine for now", "I'm ready for something new", "I'm building something on the side"]), progress: 0.22),
        // Part 3 — Depth (bridge 0 before Q9)
        Question("Has there ever been a goal that someone told you that you couldn't achieve?",
                 placeholder: "What was it, and who said it?", ack: true, progress: 0.35),
        Question("If a close friend described you in one honest sentence, what would they say?",
                 placeholder: "The real one, not the polished one.", ack: true, progress: 0.46),
        Question("What's something you've been thinking about lately that you haven't really told anyone?",
                 placeholder: "Whatever keeps coming back when things get quiet.", ack: true, progress: 0.55),
        Question("What's a recent moment, big or small, where you felt most like yourself?",
                 placeholder: "A place, a person, a tiny win.", ack: true, progress: 0.63),
        Question("What would a version of you from a year from now tell you?",
                 placeholder: "What would future-you need you to hear right now?", ack: true, progress: 0.70),
        // Part 4 — Goals (bridge 1 before Q14)
        Question("{name}, what are you hoping changes in your life right now?",
                 placeholder: "Love, confidence, peace, momentum...", ack: true, progress: 0.78),
        Question("Why does this matter so much to you right now?",
                 placeholder: "What happens if nothing changes?", ack: true, progress: 0.84),
        Question("What feels like the biggest thing standing in your way right now?",
                 placeholder: "Doubt, timing, money, fear...", ack: true, progress: 0.89),
        // Part 5 — Dream life (bridge 2 before Q17)
        Question("When you imagine your dream life, where are you living?",
                 placeholder: "New York, London, by the beach, near family...", progress: 0.93),
        Question("What kind of home would you want to live in?",
                 input: .pillsGrid(["Luxury Penthouse", "Beachfront Villa", "Modern Loft", "Cozy Cottage",
                                    "Suburban Mansion", "Farmhouse", "Cabin", "Tiny Home"]), progress: 0.97),
    ]

    // Bridge appears before these question indices
    private static let bridgeBefore: [Int: Int] = [8: 0, 13: 1, 16: 2]

    // Bridge texts [bridgeIdx][lineIdx]
    private func bridgeLines(for bridgeIdx: Int) -> [String] {
        switch bridgeIdx {
        case 0:
            return ["These next ones go a little deeper.",
                    "There are no right answers, only honest ones."]
        case 1:
            return ["Now, the real reason you're here\(userName.isEmpty ? "." : ", \(userName).")",
                    "What you want. Not what you're supposed to want.",
                    "The thing you'd chase if no one was watching and nothing could go wrong.",
                    "Tell me the truth. I'll hold it."]
        case 2:
            return ["Now dream a little bigger\(userName.isEmpty ? "." : ", \(userName).")",
                    "Don't be realistic. Don't hold back.",
                    "Pretend anything is possible, because with me, it is."]
        default: return []
        }
    }

    // Welcome lines
    private static let welcomeLines = [
        "Before we begin, I have a few questions for you.",
        "The more honest you are, the more personal Retrospect will feel.",
        "Everything you share is private."
    ]

    // ── Layout constants (shared so text always starts in the same place) ──
    private static let titleSize: CGFloat = 28
    private static let textStartGap: CGFloat = 96    // fixed gap below top bar → uniform text start (higher on page)
    private static let horizontalPad: CGFloat = 28
    private static let topBarHeight: CGFloat = 32          // 10pt top pad + 22pt row
    private static let wonderingSlotHeight: CGFloat = 88   // three lines at 21pt + 3pt leading

    // ── State ─────────────────────────────────────────────────────────────
    @State private var phase: FlowPhase = .welcome(0)
    @State private var answers: [String] = Array(repeating: "", count: 18)
    @State private var userName: String = ""
    @State private var inputText: String = ""
    // Streaming reveal: full text is always laid out; only `streamCount` chars are visible.
    // This keeps the layout fixed so words never jump to the next line mid-stream.
    @State private var fullText: String = ""
    @State private var streamCount: Int = 0
    @State private var isStreamingDone: Bool = false
    @State private var streamTimer: Timer?
    @FocusState private var isInputFocused: Bool

    // Acknowledgment
    @State private var ackText: String = ""
    @State private var ackCount: Int = 0
    @State private var ackTimer: Timer?
    @State private var ackDone: Bool = false
    @State private var ackLoading: Bool = false
    @State private var ackDissolving: Bool = false
    @State private var ackDissolveWorkItem: DispatchWorkItem?
    @State private var ackDissolveStart: Date?
    @State private var ackParticles: [AckDissolveParticle] = []
    @State private var ackTextSize: CGSize = .zero
    private static let ackDissolveDuration: TimeInterval = 1.05

    // Synthesized goals — the checklist prunes this set, it never adds to it.
    @State private var extractedGoals: [RichGoal] = []
    @State private var keptGoalIDs: Set<UUID> = []
    @State private var goalsRevealed: Bool = false
    @State private var processingDotCount: Int = 0
    @State private var processingTimer: Timer?
    @State private var wonderings: [String] = []
    @State private var currentWondering: String = ""
    @State private var wonderingIndex: Int = 0
    @State private var wonderingTimer: Timer?
    @State private var backendNotes: String?
    @State private var goalsError: Bool = false
    @State private var showPodcastFlow = false
    @State private var showPodcastLayer = false
    /// Set once the podcast has been opened, so the page can offer a way on.
    /// Without it the page held only "Play Podcast" and closing the player
    /// returned here with nowhere to go.
    @State private var hasOpenedPodcast = false
    @State private var podcastFlowSessionID = UUID()
    @State private var prefetchedEpisode: PodcastEpisode?
    @State private var podcastGenerating = false
    @State private var awaitingPodcast = false

    @StateObject private var goalsManager = GoalsManager.shared

    // ── Body ──────────────────────────────────────────────────────────────
    var body: some View {
        ZStack {
            OnboardingStyle.background.ignoresSafeArea()

            Group {
                switch phase {
                case .welcome(let line):
                    welcomeScreen(upTo: line)
                        .id("w\(line)")
                case .question(let idx):
                    questionScreen(idx: idx)
                        .id("q\(idx)")
                case .acknowledgment(let idx):
                    ackScreen(idx: idx)
                        .id("ack\(idx)")
                case .bridge(let bIdx, let lIdx):
                    bridgeScreen(bIdx: bIdx, upTo: lIdx)
                        .id("br\(bIdx)l\(lIdx)")
                case .processing:
                    processingScreen
                        .id("proc")
                case .revealing:
                    revealingScreen
                        .id("rev")
                case .complete:
                    completeScreen
                        .id("done")
                }
            }
            .opacity(showPodcastFlow ? 0 : 1)
            .scaleEffect(showPodcastFlow ? 0.96 : 1)
            .allowsHitTesting(!showPodcastFlow)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: phase.key)

            if showPodcastLayer {
                PodcastPaywallFlow(
                    audioURL: prefetchedEpisode?.audioUrl.flatMap { URL(string: $0) },
                    transcript: prefetchedEpisode?.script ?? Self.demoTranscript,
                    teaseSeconds: 40,
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.45)) {
                            showPodcastLayer = false
                            showPodcastFlow = false
                        }
                    },
                    onDebugGoHome: {
                        showPodcastLayer = false
                        showPodcastFlow = false
                        finish()
                    }
                )
                .id(podcastFlowSessionID)
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: showPodcastFlow)
        .preferredColorScheme(.light)
        .onDisappear {
            streamTimer?.invalidate()
            ackTimer?.invalidate()
            processingTimer?.invalidate()
        }
    }

    // ── WELCOME ───────────────────────────────────────────────────────────

    private func welcomeScreen(upTo line: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar(progress: 0.02, showBack: false, backAction: {}, onSkip: { withAnimation { phase = .complete } })

            Spacer().frame(height: Self.textStartGap)

            multiLineStreamingText(priorLines: Array(Self.welcomeLines.prefix(line)))
                .padding(.horizontal, Self.horizontalPad)

            Spacer()

            if isStreamingDone && line == Self.welcomeLines.count - 1 {
                OnboardingPrimaryButton(title: "Continue") {
                    HapticManager.shared.playMediumImpact()
                    startQuestion(0)
                }
                .padding(.horizontal, Self.horizontalPad)
                .padding(.bottom, 34)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isStreamingDone)
            } else {
                Spacer(minLength: 100)
            }
        }
        .onAppear {
            stream(Self.welcomeLines[line], speed: 0.03) {
                if line < Self.welcomeLines.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                        withAnimation { phase = .welcome(line + 1) }
                    }
                }
            }
        }
    }

    // ── QUESTION ──────────────────────────────────────────────────────────

    private func questionScreen(idx: Int) -> some View {
        let q = Self.questions[idx]
        let resolvedText = q.text.replacingOccurrences(of: "{name}", with: userName)

        return VStack(spacing: 0) {
            topBar(progress: q.progress, showBack: idx > 0, backAction: { goBack(from: idx) }, onSkip: { withAnimation { phase = .complete } })

            Spacer().frame(height: Self.textStartGap)

            streamingText()
                .padding(.horizontal, Self.horizontalPad)

            Spacer(minLength: 16)

            // Input area
            switch q.inputType {
            case .text:
                inputBar(placeholder: q.placeholder, keyboard: q.keyboardType) {
                    submitAnswer(idx: idx, answer: inputText)
                }
                .padding(.horizontal, Self.horizontalPad)
                .padding(.bottom, 20)

            case .pillsVertical(let options):
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(options, id: \.self) { opt in
                        pillButton(opt) { submitAnswer(idx: idx, answer: opt) }
                    }
                }
                .padding(.horizontal, Self.horizontalPad)
                .padding(.bottom, 32)
                .opacity(isStreamingDone ? 1 : 0)
                .animation(.easeIn(duration: 0.2), value: isStreamingDone)

            case .pillsGrid(let options):
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(options, id: \.self) { opt in
                        pillButton(opt) { submitAnswer(idx: idx, answer: opt) }
                    }
                }
                .padding(.horizontal, Self.horizontalPad)
                .padding(.bottom, 32)
                .opacity(isStreamingDone ? 1 : 0)
                .animation(.easeIn(duration: 0.2), value: isStreamingDone)
            }
        }
        .onAppear {
            inputText = ""
            stream(resolvedText, speed: 0.03) {
                if case .text = q.inputType {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isInputFocused = true
                    }
                }
            }
        }
    }

    // ── ACKNOWLEDGMENT ────────────────────────────────────────────────────

    private func ackScreen(idx: Int) -> some View {
        let q = Self.questions[idx]

        return VStack(spacing: 0) {
            topBar(progress: q.progress, showBack: true, backAction: { goBack(from: idx) }, onSkip: { withAnimation { phase = .complete } })

            Spacer().frame(height: Self.textStartGap)

            HStack(alignment: .top) {
                if ackLoading && ackCount == 0 {
                    ThinkingDots()
                } else {
                    ZStack(alignment: .topLeading) {
                        Text(revealAttributed(ackText, count: ackCount))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(ackDissolving ? 0 : 1)
                            .scaleEffect(ackDissolving ? 0.92 : 1.0, anchor: .topLeading)
                            .animation(.easeOut(duration: 0.38), value: ackDissolving)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(key: AckTextSizeKey.self, value: geo.size)
                                }
                            )

                        if ackDissolving, let start = ackDissolveStart {
                            AckParticleField(
                                particles: ackParticles,
                                start: start,
                                duration: Self.ackDissolveDuration
                            )
                            .frame(width: ackTextSize.width, height: ackTextSize.height)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Self.horizontalPad)
            .onPreferenceChange(AckTextSizeKey.self) { ackTextSize = $0 }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Ignore taps while waiting for Claude or mid-dissolve.
            if ackLoading && ackCount == 0 { return }
            if ackDissolving { return }
            guard ackDone else {
                ackTimer?.invalidate()
                ackCount = ackText.count
                ackDone = true
                return
            }
            beginAckDissolve(idx: idx)
        }
        .onAppear {
            ackText = ""
            ackCount = 0
            ackDone = false
            ackLoading = false
            ackDissolving = false
            ackDissolveStart = nil
            ackParticles = []
            loadAndStreamAck(idx: idx)
        }
    }

    // ── BRIDGE ────────────────────────────────────────────────────────────

    private func bridgeScreen(bIdx: Int, upTo lineIdx: Int) -> some View {
        let lines = bridgeLines(for: bIdx)

        return VStack(alignment: .leading, spacing: 0) {
            topBar(progress: questionProgressBeforeBridge(bIdx), showBack: false, backAction: {}, onSkip: { withAnimation { phase = .complete } })

            Spacer().frame(height: Self.textStartGap)

            multiLineStreamingText(priorLines: Array(lines.prefix(lineIdx)))
                .padding(.horizontal, Self.horizontalPad)

            Spacer()
        }
        .onAppear {
            let target = lines[lineIdx]
            stream(target, speed: 0.032) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                    if lineIdx < lines.count - 1 {
                        withAnimation { phase = .bridge(bIdx, lineIdx + 1) }
                    } else {
                        let nextQ = Self.bridgeBefore.first(where: { $0.value == bIdx })?.key ?? 0
                        startQuestion(nextQ)
                    }
                }
            }
        }
    }

    private func questionProgressBeforeBridge(_ bIdx: Int) -> Double {
        let nextQ = Self.bridgeBefore.first(where: { $0.value == bIdx })?.key ?? 0
        return nextQ > 0 ? Self.questions[nextQ - 1].progress : 0.22
    }

    // ── PROCESSING ────────────────────────────────────────────────────────

    private var processingScreen: some View {
        VStack(spacing: 0) {
            topBar(progress: 0.98, showBack: false, backAction: {})

            if goalsError {
                Spacer().frame(height: Self.textStartGap)

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Couldn't read your goals yet.")
                            .font(OnboardingStyle.titleFont(size: Self.titleSize))
                            .foregroundColor(OnboardingStyle.primaryText)
                            .tracking(-0.5)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    Text("Something interrupted the analysis. Let's try again.")
                        .font(OnboardingStyle.bodyFont(size: 15))
                        .foregroundColor(OnboardingStyle.secondaryText)
                }
                .padding(.horizontal, Self.horizontalPad)

                Spacer()

                OnboardingPrimaryButton(title: "Try again") {
                    HapticManager.shared.playSoftImpact()
                    goalsError = false
                    startProcessingDots()
                    startWonderings()
                    extractGoals()
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 34)
            } else {
                VStack(spacing: 24) {
                    RetrospectLoadingMark(width: 96)
                    Text(currentWondering.isEmpty
                         ? "Understanding you\(String(repeating: ".", count: processingDotCount))"
                         : currentWondering)
                        .font(OnboardingStyle.titleFont(size: 21))
                        .foregroundColor(OnboardingStyle.primaryText)
                        .tracking(-0.4)
                        .lineSpacing(3)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        // Reserved slot: wonderings differ in line count, and
                        // without a fixed height every swap re-centers the
                        // stack and slides the mark.
                        .frame(maxWidth: .infinity, minHeight: Self.wonderingSlotHeight)
                        .padding(.horizontal, Self.horizontalPad)
                        .id(currentWondering)
                        .transition(.opacity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Cancels the top bar above, so the block lands on the screen's
                // vertical center rather than the center of the space below it.
                .padding(.bottom, Self.topBarHeight)
            }
        }
        .onAppear { startProcessingDots(); startWonderings(); extractGoals() }
        .onDisappear { processingTimer?.invalidate(); wonderingTimer?.invalidate() }
    }

    // ── REVEALING (goal checklist) ────────────────────────────────────────

    private var revealingScreen: some View {
        VStack(spacing: 0) {
            topBar(progress: 0.99, showBack: false, backAction: {})

            VStack(alignment: .leading, spacing: 10) {
                Text("Here's what I heard")
                    .font(OnboardingStyle.titleFont(size: Self.titleSize))
                    .foregroundColor(OnboardingStyle.primaryText)
                    .tracking(-0.5)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Uncheck anything that isn't yours. I'll watch your life through the rest.")
                    .font(OnboardingStyle.bodyFont(size: 15))
                    .foregroundColor(OnboardingStyle.secondaryText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Self.horizontalPad)
            .padding(.top, 28)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(extractedGoals) { goal in
                        GoalChecklistRow(
                            title: goal.title,
                            isKept: keptGoalIDs.contains(goal.id)
                        ) {
                            toggleGoal(goal)
                        }
                    }
                }
                .padding(.horizontal, Self.horizontalPad)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .opacity(goalsRevealed ? 1 : 0)
            .offset(y: goalsRevealed ? 0 : 14)

            OnboardingPrimaryButton(title: "Continue") {
                HapticManager.shared.playSuccessNotification()
                finish()  // hand off to integrations; closing screen comes after
            }
            .padding(.horizontal, Self.horizontalPad)
            .padding(.bottom, 34)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { goalsRevealed = true }
                HapticManager.shared.playSoftImpact()
            }
        }
    }

    private func toggleGoal(_ goal: RichGoal) {
        HapticManager.shared.playLightImpact()
        withAnimation(.easeOut(duration: 0.18)) {
            if keptGoalIDs.contains(goal.id) {
                keptGoalIDs.remove(goal.id)
            } else {
                keptGoalIDs.insert(goal.id)
            }
        }
    }

    // ── COMPLETE ──────────────────────────────────────────────────────────

    private var completeScreen: some View {
        VStack(spacing: 0) {
            topBar(progress: 1.0, showBack: false, backAction: {})

            Spacer().frame(height: Self.textStartGap)

            streamingText()
                .padding(.horizontal, Self.horizontalPad)

            Spacer()

            if isStreamingDone {
                let preparing = awaitingPodcast && prefetchedEpisode == nil
                OnboardingPrimaryButton(
                    title: preparing ? "Preparing your episode" : "Play Podcast",
                    isLoading: preparing,
                    isDisabled: preparing
                ) {
                    if prefetchedEpisode != nil {
                        presentPodcast()
                    } else {
                        // Prefetch hasn't finished (or failed) — wait for it, then auto-open.
                        awaitingPodcast = true
                        prefetchPodcast()
                    }
                }
                .padding(.horizontal, Self.horizontalPad)
                .padding(.bottom, hasOpenedPodcast ? 10 : 34)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: isStreamingDone)

                if hasOpenedPodcast {
                    Button("Continue") {
                        HapticManager.shared.playSuccessNotification()
                        finish()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(OnboardingStyle.primaryText.opacity(0.8))
                    .padding(.bottom, 30)
                    .transition(.opacity)
                }
            } else {
                Spacer(minLength: 100)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            stream("Now let's help you get there.", speed: 0.035) {}
        }
    }

    // TEMP — placeholder transcript for reviewing the player + paywall screens.
    private static let demoTranscript = """
    There is a version of you that already knows what to do. You have spent the last few weeks moving fast, shipping, and quietly carrying a lot. The body keeps showing up in the data even when you do not mention it. There is a thread here worth pulling, about what you are really building and who you are building it for. Let's sit with that for a moment. Because the thing standing in your way is smaller than it feels right now.
    """

    // ── SHARED SUBVIEWS ───────────────────────────────────────────────────

    private func topBar(progress: Double, showBack: Bool, backAction: @escaping () -> Void, onSkip: (() -> Void)? = nil) -> some View {
        // Back button (left) on the SAME line as the centered, rounded progress bar.
        HStack(spacing: 14) {
            // Left slot — back button or an invisible placeholder to keep the bar centered
            Group {
                if showBack {
                    Button(action: backAction) {
                        Image(systemName: "chevron.left")
                            .font(OnboardingStyle.bodyFont(size: 18, weight: .medium))
                            .foregroundColor(OnboardingStyle.tertiaryText)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Color.clear
                }
            }
            .frame(width: 22, height: 22)

            // Centered progress capsule
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(OnboardingStyle.secondaryText.opacity(0.18))
                    .frame(height: 6)
                GeometryReader { geo in
                    Capsule()
                        .fill(OnboardingStyle.primaryText.opacity(0.75))
                        .frame(width: max(6, geo.size.width * CGFloat(progress)), height: 6)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                }
                .frame(height: 6)
            }

            // Right slot — DEV-ONLY Skip (fast-forward through onboarding). Never ships.
            Group {
                #if DEBUG
                if let onSkip = onSkip {
                    Button("Skip") { onSkip() }
                        .font(OnboardingStyle.bodyFont(size: 14, weight: .medium))
                        .foregroundColor(OnboardingStyle.tertiaryText)
                        .buttonStyle(PlainButtonStyle())
                } else {
                    Color.clear.frame(width: 22, height: 22)
                }
                #else
                Color.clear.frame(width: 22, height: 22)
                #endif
            }
            .fixedSize()
        }
        .padding(.top, 10)
        .padding(.horizontal, 24)
    }

    private func inputBar(placeholder: String, keyboard: UIKeyboardType, onSubmit: @escaping () -> Void) -> some View {
        let isEmpty = inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        // Button sits inset from the corner; outer radius = button radius + inset
        // so the card curve stays concentric with the send circle at every height.
        let sendSize: CGFloat = 32
        let sendInset: CGFloat = 12
        let corner = sendSize / 2 + sendInset

        return ZStack(alignment: .bottomTrailing) {
            // Multi-line input: wraps and grows upward; trailing pad reserves the button.
            TextField(placeholder, text: $inputText, axis: .vertical)
                .font(OnboardingStyle.bodyFont(size: 17))
                .foregroundColor(OnboardingStyle.primaryText)
                .lineLimit(1...6)
                .keyboardType(keyboard)
                .focused($isInputFocused)
                // Text row is at least button-tall so the resting bar is
                // sendSize + 2 * sendInset. That makes `corner` exactly half the
                // height: a true pill at rest, still concentric once expanded.
                .frame(minHeight: sendSize)
                .padding(.leading, 20)
                .padding(.trailing, sendSize + sendInset + 10)
                .padding(.vertical, sendInset)

            // Always bottom-trailing so multi-line growth expands the bar upward
            // while the send control stays in the corner with even padding.
            Button(action: {
                guard !isEmpty else { return }
                onSubmit()
            }) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(isEmpty ? OnboardingStyle.tertiaryText.opacity(0.55) : .white)
                    .frame(width: sendSize, height: sendSize)
                    .background(
                        Circle().fill(isEmpty
                            ? OnboardingStyle.hairline.opacity(0.6)
                            : OnboardingStyle.accent)
                    )
            }
            .disabled(isEmpty)
            .padding(.trailing, sendInset)
            .padding(.bottom, sendInset)
            .animation(.easeOut(duration: 0.15), value: isEmpty)
        }
        .background(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(OnboardingStyle.control)
                .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(OnboardingStyle.hairline, lineWidth: 1))
                .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
        )
    }

    private func pillButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.playMediumImpact()
            action()
        }) {
            Text(title)
                .font(OnboardingStyle.bodyFont(size: 16, weight: .medium))
                .foregroundColor(OnboardingStyle.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(OnboardingStyle.control)
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(OnboardingStyle.hairline, lineWidth: 1))
                        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // ── STREAMING REVEAL HELPERS ──────────────────────────────────────────

    private static let fallbackAcks = [
        "There's a lot underneath that.",
        "I can tell that one matters to you.",
        "That tells me something real about you.",
        "Noted. That's the kind of thing I'll remember.",
        "That's more honest than most people get."
    ]

    /// Builds an AttributedString where the full text is always laid out,
    /// but only the first `count` characters are visible. The rest are clear.
    /// This keeps the line layout fixed so words never reflow mid-stream.
    private func revealAttributed(_ full: String, count: Int) -> AttributedString {
        var attr = AttributedString(full)
        attr.font = .exposure(0, size: Self.titleSize)
        attr.foregroundColor = OnboardingStyle.primaryText
        attr.tracking = -0.5
        if count < full.count {
            let start = attr.index(attr.startIndex, offsetByCharacters: count)
            attr[start..<attr.endIndex].foregroundColor = .clear
        }
        return attr
    }

    /// Single streaming line (questions, complete screen).
    private func streamingText() -> some View {
        HStack(alignment: .top) {
            Text(revealAttributed(fullText, count: streamCount))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    /// Multi-line streaming (welcome + bridge): prior lines shown fully,
    /// current line revealing.
    private func multiLineStreamingText(priorLines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(priorLines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .top) {
                    Text(revealAttributed(line, count: line.count))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
            HStack(alignment: .top) {
                Text(revealAttributed(fullText, count: streamCount))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
    }

    // ── STREAMING ─────────────────────────────────────────────────────────

    private func stream(_ text: String, speed: Double, onDone: @escaping () -> Void) {
        streamTimer?.invalidate()
        fullText = text
        streamCount = 0
        isStreamingDone = false
        let total = text.count
        streamTimer = Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { t in
            guard streamCount < total else {
                t.invalidate()
                DispatchQueue.main.async {
                    isStreamingDone = true
                    onDone()
                }
                return
            }
            streamCount += 1
            HapticManager.shared.playTextStreamTick()
        }
    }

    private func streamAck(_ text: String) {
        ackTimer?.invalidate()
        ackText = text
        ackCount = 0
        ackDone = false
        let total = text.count
        ackTimer = Timer.scheduledTimer(withTimeInterval: 0.025, repeats: true) { t in
            guard ackCount < total else {
                t.invalidate()
                DispatchQueue.main.async {
                    ackDone = true
                    // Give the reader time proportional to the ack's length, with a
                    // generous floor — these reflections are the emotional beat of the
                    // flow and were advancing too fast to actually land.
                    let dwell = min(4.5, max(2.6, Double(total) * 0.022))
                    DispatchQueue.main.asyncAfter(deadline: .now() + dwell) {
                        if case .acknowledgment(let idx) = self.phase, self.ackDone, !self.ackDissolving {
                            self.beginAckDissolve(idx: idx)
                        }
                    }
                }
                return
            }
            ackCount += 1
            HapticManager.shared.playTextStreamTick()
        }
    }

    // ── NAVIGATION ────────────────────────────────────────────────────────

    private func startQuestion(_ idx: Int) {
        streamTimer?.invalidate()
        isStreamingDone = false
        inputText = ""
        withAnimation { phase = .question(idx) }
    }

    private func submitAnswer(idx: Int, answer: String) {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        HapticManager.shared.playMediumImpact()
        isInputFocused = false
        answers[idx] = trimmed

        // Store name from Q1
        if idx == 0 { userName = trimmed }

        let q = Self.questions[idx]
        if q.hasAcknowledgment {
            withAnimation { phase = .acknowledgment(idx) }
        } else {
            advanceFromQuestion(idx)
        }
    }

    private func loadAndStreamAck(idx: Int) {
        if idx == 0 {
            // Static ack for name question
            streamAck("Welcome, \(userName).")
            return
        }
        // Generate via Claude — show thinking dots until it returns
        ackLoading = true
        let q = Self.questions[idx]
        let resolved = q.text.replacingOccurrences(of: "{name}", with: userName)

        // Build prior-answer context so the ack can reference what they said
        // earlier in the flow, not just the current answer.
        var priorParts: [String] = []
        for i in 0..<idx where i < answers.count {
            let a = answers[i].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !a.isEmpty else { continue }
            priorParts.append("Q: \(Self.questions[i].text)\nA: \(a)")
        }
        let priorContext = priorParts.joined(separator: "\n")

        ClaudeService.shared.generateOnboardingAcknowledgment(
            question: resolved,
            answer: answers[idx],
            userName: userName,
            priorContext: priorContext
        ) { result in
            DispatchQueue.main.async {
                self.ackLoading = false
                switch result {
                case .success(let text):
                    self.streamAck(Self.stripMarkdown(text))
                case .failure(let error):
                    // Never fail silently — a generic fallback here is the
                    // difference between "it sees me" and "it's a form".
                    NSLog("[OnboardingAck] q%d failed, using fallback: %@", idx, String(describing: error))
                    self.streamAck(Self.fallbackAcks.randomElement() ?? "I'm taking that in.")
                }
            }
        }
    }

    /// Strip markdown/formatting artifacts so streamed text reads as clean prose.
    private static func stripMarkdown(_ s: String) -> String {
        var out = s
        // Markdown links [text](url) -> text
        if let re = try? NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\([^\\)]+\\)") {
            let range = NSRange(out.startIndex..., in: out)
            out = re.stringByReplacingMatches(in: out, range: range, withTemplate: "$1")
        }
        // Emphasis / heading / code / quote / bullet markers and stray escapes
        for token in ["**", "__", "*", "_", "`", "#", ">", "\\"] {
            out = out.replacingOccurrences(of: token, with: "")
        }
        // Leading list dashes at line starts
        out = out.replacingOccurrences(of: "\n- ", with: "\n")
        if out.hasPrefix("- ") { out = String(out.dropFirst(2)) }
        // Em/en dashes read as artifacts in streamed prose — strip them.
        out = removeDashes(out)
        // Collapse whitespace left behind, trim.
        while out.contains("  ") { out = out.replacingOccurrences(of: "  ", with: " ") }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Remove em/en dashes (and tidy the spacing they leave) so neither streamed
    /// acks nor synthesized goal text ever show a dash. Product rule: no em
    /// dashes anywhere in onboarding copy.
    private static func removeDashes(_ s: String) -> String {
        var out = s
        out = out.replacingOccurrences(of: " — ", with: ", ")
        out = out.replacingOccurrences(of: " – ", with: ", ")
        out = out.replacingOccurrences(of: "—", with: ", ")
        out = out.replacingOccurrences(of: "–", with: ", ")
        while out.contains("  ") { out = out.replacingOccurrences(of: "  ", with: " ") }
        return out
    }

    /// Sanitize backend-synthesized prose (goal title/description/motivation):
    /// strip dashes and trim. Defense-in-depth alongside the agent/Cook 0 prompt.
    static func sanitizeProse(_ s: String) -> String {
        removeDashes(s).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func beginAckDissolve(idx: Int) {
        guard !ackDissolving else { return }
        ackTimer?.invalidate()
        ackDone = true
        ackCount = ackText.count
        ackParticles = Self.seedAckParticles(in: ackTextSize, text: ackText)
        ackDissolveStart = Date()
        ackDissolving = true
        HapticManager.shared.playSoftImpact()

        let workItem = DispatchWorkItem { [self] in
            ackDissolving = false
            ackParticles = []
            ackDissolveStart = nil
            ackDissolveWorkItem = nil
            advanceFromQuestion(idx)
        }
        ackDissolveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.ackDissolveDuration, execute: workItem)
    }

    private static func seedAckParticles(in size: CGSize, text: String) -> [AckDissolveParticle] {
        let w = max(size.width, 120)
        let h = max(size.height, 36)
        // Dense field — enough particles that the words read as dissolving into dust.
        let count = min(520, max(220, text.count * 7))
        return (0..<count).map { i in
            // Bias toward the left/top of the text block so particles read as
            // rising out of the words rather than the empty trailing space.
            let x = CGFloat.random(in: 0...(w * 0.96))
            let y = CGFloat.random(in: 0...h)
            let drift = CGFloat.random(in: -36...36)
            let lift = CGFloat.random(in: -88 ... -22)
            return AckDissolveParticle(
                id: i,
                origin: CGPoint(x: x, y: y),
                velocity: CGPoint(x: drift, y: lift),
                size: CGFloat.random(in: 0.7...2.6),
                delay: Double.random(in: 0...0.38)
            )
        }
    }

    private func advanceFromQuestion(_ idx: Int) {
        let nextIdx = idx + 1
        // Check if there's a bridge before the next question
        if let bridgeIdx = Self.bridgeBefore[nextIdx] {
            isStreamingDone = false
            withAnimation { phase = .bridge(bridgeIdx, 0) }
        } else if nextIdx < Self.questions.count {
            startQuestion(nextIdx)
        } else {
            // All questions done → process goals
            withAnimation { phase = .processing }
        }
    }

    private func goBack(from idx: Int) {
        HapticManager.shared.playLightImpact()
        streamTimer?.invalidate()
        ackTimer?.invalidate()
        ackDissolveWorkItem?.cancel()
        ackDissolveWorkItem = nil
        ackDissolving = false
        ackDissolveStart = nil
        ackParticles = []
        if idx == 0 {
            // Back to welcome
            withAnimation { phase = .welcome(Self.welcomeLines.count - 1) }
        } else {
            startQuestion(idx - 1)
        }
    }

    // ── GOAL EXTRACTION ───────────────────────────────────────────────────

    private func extractGoals() {
        let combined = combinedAnswersText()

        guard !combined.isEmpty else {
            showGoalsError()
            return
        }

        Task {
            do {
                // Deep path: runs the full ingestion + Cook 0 pipeline and returns the
                // synthesized, evidence-grounded goals (active_goals). No shallow one-shot.
                let response = try await RetrospectAPIClient.shared.synthesizeGoals(text: combined)
                let goals = Self.richGoals(from: response)
                await MainActor.run {
                    if goals.isEmpty {
                        NSLog("[GoalSynthesis] pipeline returned 0 goals (notes: %@)", response.processingNotes ?? "none")
                        // Never fabricate a generic goal — surface the failure so the user can retry.
                        showGoalsError()
                    } else {
                        extractedGoals = goals
                        backendNotes = response.processingNotes
                        finishProcessing()
                    }
                }
            } catch {
                NSLog("[GoalSynthesis] failed: %@", error.localizedDescription)
                await MainActor.run { showGoalsError() }
            }
        }
    }

    /// Builds the checklist from the goal rows the backend persisted, so every row
    /// carries its server identity and the checklist can decline by id. `extracted`
    /// only adds the reasoning, matched back by title. Falls back to `extracted`
    /// alone when the backend saved nothing, which keeps the flow working against a
    /// deployment that has not shipped the identity-returning synthesize yet.
    private static func richGoals(from response: GoalExtractionResponse) -> [RichGoal] {
        let reasoningByTitle = Dictionary(
            response.extracted.map { (titleKey($0.title), $0.reasoning) },
            uniquingKeysWith: { first, _ in first }
        )

        guard !response.saved.isEmpty else {
            return response.extracted.map { extracted in
                RichGoal(
                    title: sanitizeProse(extracted.title),
                    goalDescription: sanitizeProse(extracted.description),
                    motivation: sanitizeProse(extracted.reasoning),
                    category: inferCategory(from: extracted.description)
                )
            }
        }

        return response.saved.map { saved in
            let description = saved.description ?? ""
            return RichGoal(
                serverId: saved.id,
                title: sanitizeProse(saved.title),
                goalDescription: sanitizeProse(description),
                motivation: sanitizeProse(reasoningByTitle[titleKey(saved.title)] ?? ""),
                category: inferCategory(from: description)
            )
        }
    }

    private static func titleKey(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func showGoalsError() {
        processingTimer?.invalidate()
        stopWonderings()
        goalsError = true
    }

    private func finishProcessing() {
        processingTimer?.invalidate()
        stopWonderings()
        // The list is a prune, not a pick: everything starts kept.
        keptGoalIDs = Set(extractedGoals.map { $0.id })
        goalsRevealed = false
        withAnimation { phase = .revealing }
        // Prefetch the first podcast NOW, while the user swipes through goal cards,
        // so audio is ready by the time they tap "Play Podcast" (masks 3-5min gen).
        prefetchPodcast()
    }

    // ── FIRST PODCAST (prefetch + present) ────────────────────────────────

    private func prefetchPodcast() {
        guard prefetchedEpisode == nil, !podcastGenerating else { return }
        podcastGenerating = true
        Task {
            do {
                // Shared with the onboarding finale, so only one episode is made.
                let ep = try await FirstPodcastOrchestrator.shared.firstEpisode()
                await MainActor.run {
                    prefetchedEpisode = ep
                    podcastGenerating = false
                    if awaitingPodcast { awaitingPodcast = false; presentPodcast() }
                }
            } catch {
                NSLog("[Podcast] prefetch failed: %@", error.localizedDescription)
                await MainActor.run {
                    podcastGenerating = false
                    // If the user is waiting, open anyway with the fallback transcript
                    // (no audio) rather than trapping them on a spinner.
                    if awaitingPodcast { awaitingPodcast = false; presentPodcast() }
                }
            }
        }
    }

    private func presentPodcast() {
        HapticManager.shared.playSuccessNotification()
        podcastFlowSessionID = UUID()
        hasOpenedPodcast = true
        withAnimation(.easeInOut(duration: 0.34)) { showPodcastFlow = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard showPodcastFlow else { return }
            withAnimation(.easeInOut(duration: 0.45)) { showPodcastLayer = true }
        }
    }

    private func startProcessingDots() {
        processingDotCount = 0
        processingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            processingDotCount = (processingDotCount + 1) % 4
        }
    }

    // ── UNDERSTANDING "WONDERINGS" ────────────────────────────────────────
    // While the heavy synthesis runs, Retrospect "thinks out loud" — grounded
    // self-questions about the person — so the wait reads as a mind working.

    private static let fallbackWonderings = [
        "What are they protecting when they stay this busy?",
        "Is the drive to achieve about proving something, or building it?",
        "What would they reach for if nothing were at stake?",
        "Who are they when no one is watching the metrics?",
        "Is the calm they want rest, or permission to rest?",
        "What did they almost say, then hold back?",
        "Where does the pressure actually come from?",
        "What are they quietly hoping I notice?",
    ]

    private func combinedAnswersText() -> String {
        zip(Self.questions, answers)
            .map { q, a in "Q: \(q.text)\nA: \(a)" }
            .filter { !$0.hasSuffix("A: ") }
            .joined(separator: "\n\n")
    }

    private func startWonderings() {
        let combined = combinedAnswersText()
        guard !combined.isEmpty else {
            wonderings = Self.fallbackWonderings
            beginWonderingCycle()
            return
        }
        ClaudeService.shared.generateOnboardingWonderings(answersText: combined) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let list):
                    let cleaned = list.map { Self.stripMarkdown($0) }.filter { !$0.isEmpty }
                    self.wonderings = cleaned.count >= 3 ? cleaned : Self.fallbackWonderings
                case .failure:
                    self.wonderings = Self.fallbackWonderings
                }
                self.beginWonderingCycle()
            }
        }
    }

    private func beginWonderingCycle() {
        guard !wonderings.isEmpty, case .processing = phase else { return }
        wonderingTimer?.invalidate()
        wonderingIndex = 0
        withAnimation(.easeInOut(duration: 0.5)) { currentWondering = wonderings[0] }
        wonderingTimer = Timer.scheduledTimer(withTimeInterval: 3.8, repeats: true) { _ in
            guard case .processing = self.phase else { self.wonderingTimer?.invalidate(); return }
            self.wonderingIndex = (self.wonderingIndex + 1) % self.wonderings.count
            withAnimation(.easeInOut(duration: 0.5)) {
                self.currentWondering = self.wonderings[self.wonderingIndex]
            }
        }
    }

    private func stopWonderings() {
        wonderingTimer?.invalidate()
        wonderingTimer = nil
        currentWondering = ""
    }

    private static func inferCategory(from description: String) -> String {
        let lower = description.lowercased()
        if lower.contains("fitness") || lower.contains("exercise") || lower.contains("health") || lower.contains("sleep") { return "Health & Fitness" }
        if lower.contains("career") || lower.contains("work") || lower.contains("job") || lower.contains("business") { return "Career & Work" }
        if lower.contains("relationship") || lower.contains("dating") || lower.contains("friend") || lower.contains("family") { return "Relationships" }
        if lower.contains("money") || lower.contains("financial") || lower.contains("saving") { return "Finance" }
        if lower.contains("learn") || lower.contains("skill") || lower.contains("study") { return "Skills & Learning" }
        return "Personal Growth"
    }

    private func finish() {
        let keptGoals = extractedGoals.filter { keptGoalIDs.contains($0.id) }
        let declinedGoals = extractedGoals.filter { !keptGoalIDs.contains($0.id) }

        goalsManager.addRichGoals(keptGoals)
        OnboardingContextManager.shared.saveExtractedGoals(keptGoals)
        declineGoals(declinedGoals)

        let combined = zip(Self.questions, answers)
            .map { q, a in "Q: \(q.text.replacingOccurrences(of: "{name}", with: userName))\nA: \(a)" }
            .filter { !$0.hasSuffix("A: ") }
            .joined(separator: "\n\n")
        UserDefaults.standard.set(combined, forKey: GoalsManager.onboardingProfileContextKey)

        Task {
            let granted = await PodcastNotificationService.shared.requestAuthorization()
            if granted { PodcastNotificationService.shared.scheduleAllRecurringNotifications() }
        }

        onComplete?(keptGoals, userName)
    }

    /// A pruned goal stops being an observational lens but stays in the system as a
    /// pending candidate, so later behavior can bring it back on its own.
    private func declineGoals(_ goals: [RichGoal]) {
        let serverIds = goals.compactMap { $0.serverId }
        guard !serverIds.isEmpty else { return }

        Task {
            for serverId in serverIds {
                do {
                    try await RetrospectAPIClient.shared.declineGoal(serverId: serverId)
                } catch {
                    NSLog("[GoalDecline] %@ failed: %@", serverId, error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Goal checklist row (all goals start kept; tapping prunes one)

private struct GoalChecklistRow: View {
    let title: String
    let isKept: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(title)
                    .font(OnboardingStyle.bodyFont(size: 16, weight: .medium))
                    .foregroundColor(isKept ? OnboardingStyle.primaryText : OnboardingStyle.tertiaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isKept ? "checkmark.circle.fill" : "circle")
                    .font(OnboardingStyle.bodyFont(size: 20, weight: .medium))
                    .foregroundColor(isKept
                        ? OnboardingStyle.success
                        : OnboardingStyle.tertiaryText.opacity(0.55))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(OnboardingStyle.control.opacity(isKept ? 0.78 : 0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(isKept
                                ? OnboardingStyle.primaryText.opacity(0.16)
                                : OnboardingStyle.hairline, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(isKept ? 0.10 : 0.04), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Thinking dots (shown while an LLM acknowledgment is loading)

private struct ThinkingDots: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(OnboardingStyle.primaryText.opacity(phase == i ? 0.75 : 0.25))
                    .frame(width: 9, height: 9)
                    .scaleEffect(phase == i ? 1.0 : 0.7)
                    .animation(.easeInOut(duration: 0.35), value: phase)
            }
        }
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }
}

// MARK: - Ack particle dissolve

private struct AckTextSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

private struct AckDissolveParticle: Identifiable {
    let id: Int
    let origin: CGPoint
    let velocity: CGPoint
    let size: CGFloat
    let delay: Double
}

private struct AckParticleField: View {
    let particles: [AckDissolveParticle]
    let start: Date
    let duration: TimeInterval

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = min(1.0, timeline.date.timeIntervalSince(start) / duration)
            Canvas { context, _ in
                for p in particles {
                    let local = max(0, (t - p.delay) / max(0.001, 1 - p.delay))
                    guard local > 0, local < 1 else { continue }
                    let x = p.origin.x + p.velocity.x * CGFloat(local)
                    let y = p.origin.y + p.velocity.y * CGFloat(local)
                    let opacity = pow(1 - local, 1.4) * 0.9
                    let r = p.size * (1 - CGFloat(local) * 0.5)
                    let rect = CGRect(x: x - r / 2, y: y - r / 2, width: r, height: r)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(OnboardingStyle.primaryText.opacity(opacity))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
