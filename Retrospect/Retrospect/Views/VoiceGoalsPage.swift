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
        Question("What's something you keep meaning to do, but somehow never get around to?",
                 placeholder: "A conversation, habit, project, decision...", ack: true, progress: 0.35),
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
        case 0: return ["Now let's get to know you better.", "Be as honest as you can."]
        case 1: return ["Now let's talk about what you want.", "Don't filter it. Just say the true thing."]
        case 2: return ["Now dream a little bigger\(userName.isEmpty ? "." : ", \(userName).")",
                        "Don't be realistic. Don't hold back.",
                        "Pretend anything is possible."]
        default: return []
        }
    }

    // Welcome lines
    private static let welcomeLines = [
        "Before we begin, I have a few questions for you.",
        "The more honest you are, the more personal Retrospect will feel.",
        "Everything you share is private."
    ]

    // ── State ─────────────────────────────────────────────────────────────
    @State private var phase: FlowPhase = .welcome(0)
    @State private var answers: [String] = Array(repeating: "", count: 18)
    @State private var userName: String = ""
    @State private var inputText: String = ""
    @State private var displayedText: String = ""
    @State private var isStreamingDone: Bool = false
    @State private var progressValue: Double = 0
    @State private var streamTimer: Timer?
    @FocusState private var isInputFocused: Bool

    // Acknowledgment
    @State private var ackText: String = ""
    @State private var ackDisplayed: String = ""
    @State private var ackTimer: Timer?
    @State private var ackDone: Bool = false

    // Bridge accumulation
    @State private var bridgeAccumulated: [String] = []
    @State private var bridgeStreamDone: Bool = false

    // Goal cards (existing system)
    @State private var extractedGoals: [RichGoal] = []
    @State private var currentCardIndex: Int = 0
    @State private var cardOffset: CGSize = .zero
    @State private var cardRotation: Double = 0
    @State private var cardRevealed: Bool = false
    @State private var closingAckText: String = ""
    @State private var showClosingAck: Bool = false
    @State private var processingDotCount: Int = 0
    @State private var processingTimer: Timer?
    @State private var backendNotes: String?

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
            Spacer(minLength: 60)

            VStack(alignment: .leading, spacing: 20) {
                ForEach(0...line, id: \.self) { i in
                    if i < line {
                        Text(Self.welcomeLines[i])
                            .font(OnboardingStyle.titleFont(size: 28))
                            .foregroundColor(OnboardingStyle.primaryText)
                            .tracking(-0.5)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(displayedText)
                            .font(OnboardingStyle.titleFont(size: 28))
                            .foregroundColor(OnboardingStyle.primaryText)
                            .tracking(-0.5)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 28)

            Spacer()

            if isStreamingDone && line == Self.welcomeLines.count - 1 {
                OnboardingPrimaryButton(title: "Continue") {
                    HapticManager.shared.playMediumImpact()
                    startQuestion(0)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 34)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isStreamingDone)
            } else {
                Spacer(minLength: 100)
            }
        }
        .onAppear {
            stream(Self.welcomeLines[line], speed: 0.035) {
                if line < Self.welcomeLines.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation { phase = .welcome(line + 1) }
                        displayedText = ""
                        isStreamingDone = false
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
            // Progress + nav
            topBar(progress: q.progress, showBack: idx > 0, backAction: { goBack(from: idx) })

            // Question text (upper area)
            HStack(alignment: .top) {
                Text(displayedText)
                    .font(OnboardingStyle.titleFont(size: 28))
                    .foregroundColor(OnboardingStyle.primaryText)
                    .tracking(-0.5)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
            .padding(.top, 48)

            Spacer(minLength: 16)

            // Input area
            switch q.inputType {
            case .text:
                inputBar(placeholder: q.placeholder, keyboard: q.keyboardType) {
                    submitAnswer(idx: idx, answer: inputText)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 20)

            case .pillsVertical(let options):
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(options, id: \.self) { opt in
                        pillButton(opt) { submitAnswer(idx: idx, answer: opt) }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 32)
                .opacity(isStreamingDone ? 1 : 0)
                .animation(.easeIn(duration: 0.2), value: isStreamingDone)

            case .pillsGrid(let options):
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(options, id: \.self) { opt in
                        pillButton(opt) { submitAnswer(idx: idx, answer: opt) }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 32)
                .opacity(isStreamingDone ? 1 : 0)
                .animation(.easeIn(duration: 0.2), value: isStreamingDone)
            }
        }
        .onAppear {
            inputText = ""
            displayedText = ""
            isStreamingDone = false
            progressValue = q.progress
            stream(resolvedText, speed: 0.03) {
                // Focus text field after streaming for text-type questions
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
            topBar(progress: q.progress, showBack: true, backAction: { goBack(from: idx) })

            HStack(alignment: .top) {
                Text(ackDisplayed)
                    .font(OnboardingStyle.titleFont(size: 28))
                    .foregroundColor(OnboardingStyle.primaryText)
                    .tracking(-0.5)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
            .padding(.top, 48)

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard ackDone else {
                // Skip to end of streaming on tap
                ackTimer?.invalidate()
                ackDisplayed = ackText
                ackDone = true
                return
            }
            advanceAfterAck(idx: idx)
        }
        .onAppear {
            ackDisplayed = ""
            ackDone = false
            loadAndStreamAck(idx: idx)
        }
    }

    // ── BRIDGE ────────────────────────────────────────────────────────────

    private func bridgeScreen(bIdx: Int, upTo lineIdx: Int) -> some View {
        let lines = bridgeLines(for: bIdx)

        return VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 60)

            VStack(alignment: .leading, spacing: 20) {
                ForEach(0...lineIdx, id: \.self) { i in
                    if i < lineIdx {
                        Text(lines[i])
                            .font(OnboardingStyle.titleFont(size: 28))
                            .foregroundColor(OnboardingStyle.primaryText)
                            .tracking(-0.5)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(displayedText)
                            .font(OnboardingStyle.titleFont(size: 28))
                            .foregroundColor(OnboardingStyle.primaryText)
                            .tracking(-0.5)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 28)

            Spacer()
        }
        .onAppear {
            displayedText = ""
            isStreamingDone = false
            let target = lines[lineIdx]
            stream(target, speed: 0.04) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    if lineIdx < lines.count - 1 {
                        withAnimation { phase = .bridge(bIdx, lineIdx + 1) }
                        displayedText = ""
                        isStreamingDone = false
                    } else {
                        // Bridge done — go to first question after bridge
                        let nextQ = Self.bridgeBefore.first(where: { $0.value == bIdx })?.key ?? 0
                        startQuestion(nextQ)
                    }
                }
            }
        }
    }

    // ── PROCESSING ────────────────────────────────────────────────────────

    private var processingScreen: some View {
        VStack(spacing: 0) {
            topBar(progress: 0.98, showBack: false, backAction: {})

            Spacer(minLength: 60)

            HStack {
                Text("Understanding you\(String(repeating: ".", count: processingDotCount))")
                    .font(OnboardingStyle.titleFont(size: 28))
                    .foregroundColor(OnboardingStyle.primaryText)
                    .tracking(-0.5)
                Spacer()
            }
            .padding(.horizontal, 28)

            Spacer()
        }
        .onAppear { startProcessingDots(); extractGoals() }
        .onDisappear { processingTimer?.invalidate() }
    }

    // ── REVEALING (goal cards) ────────────────────────────────────────────

    private var revealingScreen: some View {
        VStack(spacing: 0) {
            topBar(progress: 0.99, showBack: false, backAction: {})

            if currentCardIndex < extractedGoals.count {
                ZStack {
                    ForEach(Array(extractedGoals.enumerated().reversed()), id: \.element.id) { index, goal in
                        if index >= currentCardIndex && index < currentCardIndex + 3 {
                            let depth = index - currentCardIndex
                            goalCard(goal: goal, isTop: depth == 0)
                                .scaleEffect(depth == 0 ? 1.0 : 1.0 - CGFloat(depth) * 0.04)
                                .offset(y: depth == 0 ? 0 : CGFloat(depth) * 10)
                                .opacity(depth == 0 ? 1.0 : depth == 1 ? 0.5 : 0.25)
                                .zIndex(Double(extractedGoals.count - index))
                                .offset(x: depth == 0 ? cardOffset.width : 0)
                                .rotationEffect(.degrees(depth == 0 ? cardRotation : 0))
                                .gesture(depth == 0 ? cardDragGesture : nil)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)
                .padding(.top, 24)
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
                .padding(.top, 16)

            } else {
                // All cards swiped
                VStack(spacing: 20) {
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
                        .padding(.top, 48)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Spacer()

            if currentCardIndex >= extractedGoals.count {
                OnboardingPrimaryButton(title: "Continue") {
                    HapticManager.shared.playSuccessNotification()
                    withAnimation { phase = .complete }
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
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "hand.draw")
                            .font(OnboardingStyle.bodyFont(size: 11, weight: .medium))
                        Text("Swipe to continue")
                            .font(OnboardingStyle.bodyFont(size: 12, weight: .medium))
                    }
                    .foregroundColor(OnboardingStyle.tertiaryText)
                    Spacer()
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: 380, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(OnboardingStyle.control.opacity(0.82))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(color.opacity(0.15), lineWidth: 1))
                .shadow(color: .black.opacity(0.10), radius: 12, y: 6)
        )
    }

    // ── COMPLETE ──────────────────────────────────────────────────────────

    private var completeScreen: some View {
        VStack(spacing: 0) {
            topBar(progress: 1.0, showBack: false, backAction: {})

            Spacer(minLength: 60)

            HStack {
                Text(displayedText)
                    .font(OnboardingStyle.titleFont(size: 30))
                    .foregroundColor(OnboardingStyle.primaryText)
                    .tracking(-0.5)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(.horizontal, 28)

            Spacer()

            if isStreamingDone {
                OnboardingPrimaryButton(title: "Play Podcast") {
                    HapticManager.shared.playSuccessNotification()
                    finish()
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 34)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: isStreamingDone)
            } else {
                Spacer(minLength: 100)
            }
        }
        .onAppear {
            displayedText = ""
            isStreamingDone = false
            stream("Now let's help you get there.", speed: 0.035) {}
        }
    }

    // ── SHARED SUBVIEWS ───────────────────────────────────────────────────

    private func topBar(progress: Double, showBack: Bool, backAction: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(OnboardingStyle.secondaryText.opacity(0.15))
                        .frame(height: 2)
                    Rectangle()
                        .fill(OnboardingStyle.primaryText.opacity(0.7))
                        .frame(width: geo.size.width * CGFloat(progress), height: 2)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 2)

            // Nav row
            HStack {
                if showBack {
                    Button(action: backAction) {
                        Image(systemName: "chevron.left")
                            .font(OnboardingStyle.bodyFont(size: 16, weight: .medium))
                            .foregroundColor(OnboardingStyle.tertiaryText)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Spacer()
            }
            .frame(height: 44)
            .padding(.horizontal, 28)
        }
    }

    private func inputBar(placeholder: String, keyboard: UIKeyboardType, onSubmit: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            TextField(placeholder, text: $inputText)
                .font(OnboardingStyle.bodyFont(size: 17))
                .foregroundColor(OnboardingStyle.primaryText)
                .keyboardType(keyboard)
                .submitLabel(.done)
                .focused($isInputFocused)
                .onSubmit {
                    let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSubmit()
                }

            Button(action: {
                let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                onSubmit()
            }) {
                Image(systemName: "arrow.right")
                    .font(OnboardingStyle.bodyFont(size: 15, weight: .semibold))
                    .foregroundColor(
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? OnboardingStyle.tertiaryText
                        : OnboardingStyle.secondaryText
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Capsule(style: .continuous)
                .fill(OnboardingStyle.control)
                .overlay(Capsule(style: .continuous)
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

    // ── STREAMING ─────────────────────────────────────────────────────────

    private func stream(_ text: String, speed: Double, onDone: @escaping () -> Void) {
        streamTimer?.invalidate()
        displayedText = ""
        isStreamingDone = false
        let chars = Array(text)
        var i = 0
        streamTimer = Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { t in
            guard i < chars.count else {
                t.invalidate()
                DispatchQueue.main.async {
                    isStreamingDone = true
                    onDone()
                }
                return
            }
            displayedText += String(chars[i])
            i += 1
            HapticManager.shared.playLightImpact()
        }
    }

    private func streamAck(_ text: String) {
        ackTimer?.invalidate()
        ackDisplayed = ""
        ackDone = false
        ackText = text
        let chars = Array(text)
        var i = 0
        ackTimer = Timer.scheduledTimer(withTimeInterval: 0.025, repeats: true) { t in
            guard i < chars.count else {
                t.invalidate()
                DispatchQueue.main.async {
                    ackDone = true
                    // Auto-advance after 2s
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if case .acknowledgment(let idx) = self.phase {
                            self.advanceAfterAck(idx: idx)
                        }
                    }
                }
                return
            }
            ackDisplayed += String(chars[i])
            i += 1
            HapticManager.shared.playLightImpact()
        }
    }

    // ── NAVIGATION ────────────────────────────────────────────────────────

    private func startQuestion(_ idx: Int) {
        streamTimer?.invalidate()
        displayedText = ""
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
            // Q1 gets a simple static ack, rest get Claude
            if idx == 0 {
                ackText = "Welcome, \(trimmed)."
                withAnimation { phase = .acknowledgment(idx) }
            } else {
                ackText = ""
                withAnimation { phase = .acknowledgment(idx) }
            }
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
        if !ackText.isEmpty {
            streamAck(ackText)
            return
        }
        // Generate via Claude
        let q = Self.questions[idx]
        let resolved = q.text.replacingOccurrences(of: "{name}", with: userName)
        ClaudeService.shared.generateOnboardingAcknowledgment(
            question: resolved,
            answer: answers[idx],
            userName: userName
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let text):
                    self.streamAck(text)
                case .failure:
                    self.streamAck("That makes a lot of sense.")
                }
            }
        }
    }

    private func advanceAfterAck(idx: Int) {
        ackTimer?.invalidate()
        advanceFromQuestion(idx)
    }

    private func advanceFromQuestion(_ idx: Int) {
        let nextIdx = idx + 1
        // Check if there's a bridge before the next question
        if let bridgeIdx = Self.bridgeBefore[nextIdx] {
            withAnimation { phase = .bridge(bridgeIdx, 0) }
            displayedText = ""
            isStreamingDone = false
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
            extractedGoals = [RichGoal(title: "Personal growth")]
            finishProcessing()
            return
        }

        Task {
            do {
                let response = try await RetrospectAPIClient.shared.extractAndSaveGoals(text: combined)
                let goals = response.extracted.map { e in
                    RichGoal(
                        title: e.title,
                        goalDescription: e.description,
                        motivation: e.reasoning,
                        category: VoiceGoalsPage.inferCategory(from: e.description)
                    )
                }
                await MainActor.run {
                    extractedGoals = goals.isEmpty ? [RichGoal(title: "Personal growth")] : goals
                    backendNotes = response.processingNotes
                    finishProcessing()
                }
            } catch {
                await MainActor.run {
                    extractedGoals = [RichGoal(title: "Personal growth")]
                    finishProcessing()
                }
            }
        }
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
        goalsManager.addRichGoals(extractedGoals)
        OnboardingContextManager.shared.saveExtractedGoals(extractedGoals)

        let combined = zip(Self.questions, answers)
            .map { q, a in "Q: \(q.text.replacingOccurrences(of: "{name}", with: userName))\nA: \(a)" }
            .filter { !$0.hasSuffix("A: ") }
            .joined(separator: "\n\n")
        UserDefaults.standard.set(combined, forKey: GoalsManager.onboardingProfileContextKey)

        Task {
            let granted = await PodcastNotificationService.shared.requestAuthorization()
            if granted { PodcastNotificationService.shared.scheduleAllRecurringNotifications() }
        }

        onComplete?(extractedGoals, userName)
    }
}
