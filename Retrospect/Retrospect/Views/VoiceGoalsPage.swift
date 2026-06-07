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
                 placeholder: "What was it — and who said it?", ack: true, progress: 0.35),
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
                    "There are no right answers — only honest ones."]
        case 1:
            return ["Now, the real reason you're here\(userName.isEmpty ? "." : ", \(userName).")",
                    "What you want. Not what you're supposed to want.",
                    "The thing you'd chase if no one was watching and nothing could go wrong.",
                    "Tell me the truth. I'll hold it."]
        case 2:
            return ["Now dream a little bigger\(userName.isEmpty ? "." : ", \(userName).")",
                    "Don't be realistic. Don't hold back.",
                    "Pretend anything is possible — because with me, it is."]
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
    @State private var inputFieldHeight: CGFloat = 0
    @FocusState private var isInputFocused: Bool

    // Acknowledgment
    @State private var ackText: String = ""
    @State private var ackCount: Int = 0
    @State private var ackTimer: Timer?
    @State private var ackDone: Bool = false
    @State private var ackLoading: Bool = false

    // Goal cards (existing system)
    @State private var extractedGoals: [RichGoal] = []
    @State private var agreedGoals: [RichGoal] = []   // swiped right = agree
    @State private var currentCardIndex: Int = 0
    @State private var cardOffset: CGSize = .zero
    @State private var cardRotation: Double = 0
    @State private var cardRevealed: Bool = false
    @State private var closingAckText: String = ""
    @State private var showClosingAck: Bool = false
    @State private var processingDotCount: Int = 0
    @State private var processingTimer: Timer?
    @State private var backendNotes: String?
    @State private var goalsError: Bool = false
    @State private var showPodcastFlow = false
    @State private var podcastFlowSessionID = UUID()

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
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: phase.key)
        }
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
                    Text(revealAttributed(ackText, count: ackCount))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Self.horizontalPad)

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Ignore taps while waiting for Claude.
            if ackLoading && ackCount == 0 { return }
            guard ackDone else {
                ackTimer?.invalidate()
                ackCount = ackText.count
                ackDone = true
                return
            }
            advanceAfterAck(idx: idx)
        }
        .onAppear {
            ackText = ""
            ackCount = 0
            ackDone = false
            ackLoading = false
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

            Spacer().frame(height: Self.textStartGap)

            if goalsError {
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
                    extractGoals()
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 34)
            } else {
                HStack {
                    Text("Understanding you\(String(repeating: ".", count: processingDotCount))")
                        .font(OnboardingStyle.titleFont(size: Self.titleSize))
                        .foregroundColor(OnboardingStyle.primaryText)
                        .tracking(-0.5)
                    Spacer()
                }
                .padding(.horizontal, Self.horizontalPad)

                Spacer()
            }
        }
        .onAppear { startProcessingDots(); extractGoals() }
        .onDisappear { processingTimer?.invalidate() }
    }

    // ── REVEALING (goal cards) ────────────────────────────────────────────

    private var revealingScreen: some View {
        VStack(spacing: 0) {
            topBar(progress: 0.99, showBack: false, backAction: {})

            if currentCardIndex < extractedGoals.count {
                // Top label
                HStack {
                    Text("Your goals are ready")
                        .font(OnboardingStyle.bodyFont(size: 13, weight: .semibold))
                        .foregroundColor(OnboardingStyle.secondaryText)
                        .tracking(0.4)
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.top, 6)

                // Full-page goal cards
                ZStack {
                    ForEach(Array(extractedGoals.enumerated().reversed()), id: \.element.id) { index, goal in
                        if index >= currentCardIndex && index < currentCardIndex + 3 {
                            let depth = index - currentCardIndex
                            goalCard(goal: goal, isTop: depth == 0)
                                .scaleEffect(depth == 0 ? 1.0 : 1.0 - CGFloat(depth) * 0.04)
                                .offset(y: depth == 0 ? 0 : CGFloat(depth) * 10)
                                .opacity(depth == 0 ? 1.0 : depth == 1 ? 0.6 : 0.35)
                                .zIndex(Double(extractedGoals.count - index))
                                .offset(x: depth == 0 ? cardOffset.width : 0)
                                .rotationEffect(.degrees(depth == 0 ? cardRotation : 0))
                                .gesture(depth == 0 ? cardDragGesture : nil)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .opacity(cardRevealed ? 1 : 0)
                .scaleEffect(cardRevealed ? 1 : 0.92)

                // Dot indicator
                HStack(spacing: 6) {
                    ForEach(0..<extractedGoals.count, id: \.self) { i in
                        Circle()
                            .fill(i <= currentCardIndex
                                  ? OnboardingStyle.primaryText.opacity(0.65)
                                  : OnboardingStyle.tertiaryText.opacity(0.35))
                            .frame(width: i == currentCardIndex ? 8 : 6,
                                   height: i == currentCardIndex ? 8 : 6)
                            .animation(.easeOut(duration: 0.2), value: currentCardIndex)
                    }
                }
                .padding(.top, 14)

                // Bottom instruction label
                VStack(spacing: 4) {
                    Text("Take a look at these goals.")
                        .font(OnboardingStyle.bodyFont(size: 14, weight: .medium))
                        .foregroundColor(OnboardingStyle.secondaryText)
                    Text("Swipe right to agree, left to disagree.")
                        .font(OnboardingStyle.bodyFont(size: 12))
                        .foregroundColor(OnboardingStyle.tertiaryText)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 30)

            } else {
                Spacer()

                if showClosingAck {
                    HStack {
                        Text(closingAckText)
                            .font(OnboardingStyle.titleFont(size: 26))
                            .foregroundColor(OnboardingStyle.primaryText)
                            .tracking(-0.5)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .padding(.horizontal, 28)
                }

                Spacer()

                OnboardingPrimaryButton(title: "Continue") {
                    HapticManager.shared.playSuccessNotification()
                    finish()  // hand off to integrations; closing screen comes after
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 34)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { cardRevealed = true }
                HapticManager.shared.playSoftImpact()
            }
        }
    }

    private var cardDragGesture: some Gesture {
        DragGesture()
            .onChanged { v in
                cardOffset = v.translation
                cardRotation = Double(v.translation.width / 20)
            }
            .onEnded { v in
                if abs(v.translation.width) > 110 {
                    let dir: CGFloat = v.translation.width > 0 ? 1 : -1
                    // Right = agree (keep), left = disagree (drop)
                    if dir > 0, currentCardIndex < extractedGoals.count {
                        agreedGoals.append(extractedGoals[currentCardIndex])
                    }
                    withAnimation(.easeOut(duration: 0.28)) {
                        cardOffset = CGSize(width: dir * 500, height: 0)
                        cardRotation = Double(dir * 25)
                    }
                    HapticManager.shared.playSoftImpact()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        currentCardIndex += 1
                        cardOffset = .zero
                        cardRotation = 0
                        if currentCardIndex >= extractedGoals.count {
                            HapticManager.shared.playSuccessNotification()
                            buildClosingAck()
                            withAnimation(.easeIn(duration: 0.3).delay(0.1)) { showClosingAck = true }
                        }
                    }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        cardOffset = .zero; cardRotation = 0
                    }
                }
            }
    }

    private func goalCard(goal: RichGoal, isTop: Bool) -> some View {
        let color = GoalCategory(from: goal.category).color
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(goal.category.uppercased())
                    .font(OnboardingStyle.bodyFont(size: 11, weight: .semibold))
                    .foregroundColor(OnboardingStyle.secondaryText)
                    .tracking(1.2)
                Spacer()
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 24, height: 4)
            }
            .padding(.bottom, 14)

            Text(goal.title)
                .font(OnboardingStyle.titleFont(size: 22))
                .foregroundColor(OnboardingStyle.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, goal.goalDescription.isEmpty ? 0 : 10)

            if !goal.goalDescription.isEmpty {
                Text(goal.goalDescription)
                    .font(OnboardingStyle.bodyFont(size: 15))
                    .foregroundColor(OnboardingStyle.secondaryText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !goal.motivation.isEmpty {
                Divider().background(OnboardingStyle.tertiaryText.opacity(0.18)).padding(.vertical, 14)
                Text("Why this matters")
                    .font(OnboardingStyle.bodyFont(size: 13, weight: .medium))
                    .foregroundColor(OnboardingStyle.tertiaryText)
                    .padding(.bottom, 6)
                Text(goal.motivation)
                    .font(OnboardingStyle.bodyFont(size: 14))
                    .foregroundColor(OnboardingStyle.secondaryText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            if isTop {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.left")
                        Text("Disagree")
                    }
                    .foregroundColor(OnboardingStyle.tertiaryText)
                    Spacer()
                    HStack(spacing: 5) {
                        Text("Agree")
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(OnboardingStyle.secondaryText)
                }
                .font(OnboardingStyle.bodyFont(size: 12, weight: .medium))
            }
        }
        .padding(26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(OnboardingStyle.control)
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(color.opacity(0.18), lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
        )
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
                OnboardingPrimaryButton(title: "Play Podcast") {
                    HapticManager.shared.playSuccessNotification()
                    podcastFlowSessionID = UUID()
                    showPodcastFlow = true
                }
                .padding(.horizontal, Self.horizontalPad)
                .padding(.bottom, 34)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: isStreamingDone)
            } else {
                Spacer(minLength: 100)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            stream("Now let's help you get there.", speed: 0.035) {}
        }
        .fullScreenCover(isPresented: $showPodcastFlow) {
            // TEMP transcript keeps the podcast + paywall screens reviewable before
            // the real first-podcast audio/transcript are wired in.
            PodcastPaywallFlow(
                audioURL: nil,
                transcript: Self.demoTranscript,
                onClose: { showPodcastFlow = false }
            )
            .id(podcastFlowSessionID)
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
        // Single-line baseline ≈ font line height + vertical padding. Above that = expanded.
        let isExpanded = inputFieldHeight > 64
        let corner: CGFloat = isExpanded ? 22 : max(26, inputFieldHeight / 2)

        return HStack(alignment: isExpanded ? .bottom : .center, spacing: 10) {
            // Multi-line input: wraps and grows up to 5 lines, never scrolls horizontally
            TextField(placeholder, text: $inputText, axis: .vertical)
                .font(OnboardingStyle.bodyFont(size: 17))
                .foregroundColor(OnboardingStyle.primaryText)
                .lineLimit(1...6)
                .keyboardType(keyboard)
                .focused($isInputFocused)

            // Bare arrow — no bubble. Tucks to the trailing edge with equal inset.
            Button(action: {
                guard !isEmpty else { return }
                onSubmit()
            }) {
                Image(systemName: "arrow.up")
                    .font(OnboardingStyle.bodyFont(size: 20, weight: .semibold))
                    .foregroundColor(isEmpty ? OnboardingStyle.tertiaryText.opacity(0.45) : OnboardingStyle.accent)
            }
            .disabled(isEmpty)
            .padding(.bottom, isExpanded ? 2 : 0)
            .animation(.easeOut(duration: 0.15), value: isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, isExpanded ? 14 : 12)
        .background(
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(OnboardingStyle.control)
                    .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(OnboardingStyle.hairline, lineWidth: 1))
                    .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
                    .onChange(of: geo.size.height) { _, h in inputFieldHeight = h }
                    .onAppear { inputFieldHeight = geo.size.height }
            }
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
        "Noted — that's the kind of thing I'll remember.",
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                        if case .acknowledgment(let idx) = self.phase, self.ackDone {
                            self.advanceAfterAck(idx: idx)
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
        ClaudeService.shared.generateOnboardingAcknowledgment(
            question: resolved,
            answer: answers[idx],
            userName: userName
        ) { result in
            DispatchQueue.main.async {
                self.ackLoading = false
                switch result {
                case .success(let text):
                    self.streamAck(Self.stripMarkdown(text))
                case .failure:
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
        // Collapse whitespace left behind, trim.
        while out.contains("  ") { out = out.replacingOccurrences(of: "  ", with: " ") }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func advanceAfterAck(idx: Int) {
        ackTimer?.invalidate()
        advanceFromQuestion(idx)
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
        if idx == 0 {
            // Back to welcome
            withAnimation { phase = .welcome(Self.welcomeLines.count - 1) }
        } else {
            startQuestion(idx - 1)
        }
    }

    // ── GOAL EXTRACTION ───────────────────────────────────────────────────

    private func extractGoals() {
        let combined = zip(Self.questions, answers)
            .map { q, a in "Q: \(q.text)\nA: \(a)" }
            .filter { !$0.hasSuffix("A: ") }
            .joined(separator: "\n\n")

        guard !combined.isEmpty else {
            showGoalsError()
            return
        }

        Task {
            do {
                // Deep path: runs the full ingestion + Cook 0 pipeline and returns the
                // synthesized, evidence-grounded goals (active_goals). No shallow one-shot.
                let response = try await RetrospectAPIClient.shared.synthesizeGoals(text: combined)
                let goals = response.extracted.map { e in
                    RichGoal(
                        title: e.title,
                        goalDescription: e.description,
                        motivation: e.reasoning,
                        category: VoiceGoalsPage.inferCategory(from: e.description)
                    )
                }
                await MainActor.run {
                    if goals.isEmpty {
                        // Never fabricate a generic goal — surface the failure so it's visible.
                        showGoalsError()
                    } else {
                        extractedGoals = goals
                        backendNotes = response.processingNotes
                        finishProcessing()
                    }
                }
            } catch {
                await MainActor.run { showGoalsError() }
            }
        }
    }

    private func showGoalsError() {
        processingTimer?.invalidate()
        goalsError = true
    }

    private func finishProcessing() {
        processingTimer?.invalidate()
        currentCardIndex = 0
        cardOffset = .zero
        cardRotation = 0
        cardRevealed = false
        showClosingAck = false
        withAnimation { phase = .revealing }
    }

    private func buildClosingAck() {
        let categories = Set(extractedGoals.map { $0.category.lowercased() })
        if categories.contains(where: { $0.contains("health") || $0.contains("fitness") }) && categories.contains(where: { $0.contains("career") || $0.contains("work") }) {
            closingAckText = "Body and ambition. We'll keep you honest on both."
        } else if extractedGoals.count >= 3 {
            closingAckText = "You've got a clear picture of where you're headed."
        } else {
            closingAckText = "Got it — we know what matters to you."
        }
    }

    private func startProcessingDots() {
        processingDotCount = 0
        processingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            processingDotCount = (processingDotCount + 1) % 4
        }
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
        // Save the goals the user agreed with (swiped right); fall back to all if none.
        let chosenGoals = agreedGoals.isEmpty ? extractedGoals : agreedGoals
        goalsManager.addRichGoals(chosenGoals)
        OnboardingContextManager.shared.saveExtractedGoals(chosenGoals)

        let combined = zip(Self.questions, answers)
            .map { q, a in "Q: \(q.text.replacingOccurrences(of: "{name}", with: userName))\nA: \(a)" }
            .filter { !$0.hasSuffix("A: ") }
            .joined(separator: "\n\n")
        UserDefaults.standard.set(combined, forKey: GoalsManager.onboardingProfileContextKey)

        Task {
            let granted = await PodcastNotificationService.shared.requestAuthorization()
            if granted { PodcastNotificationService.shared.scheduleAllRecurringNotifications() }
        }

        onComplete?(chosenGoals, userName)
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
