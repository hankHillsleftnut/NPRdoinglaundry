//
//  VoiceGoalsPage.swift
//  Retrospect
//
//  Voice brain-dump page for goals.
//  After the user stops recording, goals are deeply extracted via
//  the backend and revealed as swipeable Tinder-style cards.
//

import SwiftUI

struct VoiceGoalsPage: View {
    var onComplete: (([RichGoal]) -> Void)?

    @StateObject private var audioManager = AudioRecordingManager()
    @StateObject private var goalsManager = GoalsManager.shared

    private struct DepthQuestion {
        let prompt: String
        let placeholder: String
    }

    private struct SavedDepthAnswer: Codable {
        let question: String
        let answer: String
    }

    private static let onboardingDepthAnswersKey = "onboarding_depth_answers"
    private static let depthQuestions: [DepthQuestion] = [
        DepthQuestion(
            prompt: "What's something you keep meaning to do, but somehow never get around to?",
            placeholder: "A conversation, habit, project, decision, repair, routine..."
        ),
        DepthQuestion(
            prompt: "If a friend who knows you really well had to describe you in one honest sentence, what would they say?",
            placeholder: "The real sentence, not the polished one."
        ),
        DepthQuestion(
            prompt: "What's something you've been thinking about a lot lately that you haven't really told anyone?",
            placeholder: "Whatever keeps coming back when things get quiet."
        ),
        DepthQuestion(
            prompt: "What's a recent moment, big or small, where you felt most like yourself?",
            placeholder: "A scene, a place, a person, a tiny win. Specific is good."
        ),
        DepthQuestion(
            prompt: "What would you want a version of you from a year from now to tell you?",
            placeholder: "What would future-you know that you need to hear now?"
        )
    ]

    private enum PostRecordPhase: Equatable {
        case idle
        case recording
        case processing
        case revealing
        case complete
    }
    @State private var phase: PostRecordPhase = .idle

    @State private var extractedGoals: [RichGoal] = []
    @State private var currentCardIndex: Int = 0
    @State private var cardOffset: CGSize = .zero
    @State private var cardRotation: Double = 0
    @State private var showAcknowledgment = false
    @State private var acknowledgmentText: String = ""
    @State private var backendProcessingNotes: String?
    @State private var submittedTranscription: String = ""

    @State private var currentQuestionIndex: Int = 0
    @State private var questionAnswers: [String] = Array(repeating: "", count: 5)
    @FocusState private var isTextFieldFocused: Bool

    @State private var contentOpacity: Double = 0
    @State private var micPulse = false
    @State private var processingDotCount = 0
    @State private var processingTimer: Timer?
    @State private var cardRevealed = false

    var body: some View {
        OnboardingScaffold(
            iconName: headerIcon,
            title: headerTitle,
            subtitle: headerSubtitle,
            topSpacing: phase == .revealing || phase == .complete ? 58 : 74
        ) {
            VStack(alignment: .leading, spacing: 18) {
                if phase == .idle || phase == .recording {
                    OnboardingStatusPill(
                        text: phase == .recording ? "Listening" : "Question \(currentQuestionIndex + 1) of \(Self.depthQuestions.count)",
                        systemImage: phase == .recording ? "waveform" : nil
                    )
                    preRecordingBody
                        .transition(.opacity)
                } else {
                    postRecordingBody
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .opacity(contentOpacity)
        } bottom: {
            bottomSection
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: phase)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                contentOpacity = 1
            }
        }
        .onDisappear {
            processingTimer?.invalidate()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                switch phase {
                case .idle, .recording:
                    Text(currentQuestion.prompt)
                case .processing:
                    Text("Understanding you...")
                case .revealing:
                    Text("Here's what we heard")
                case .complete:
                    Text("Now let's help you get there.")
                }
            }
            .font(.custom("HedvigLettersSerif-24ptRegular", size: phase == .idle || phase == .recording ? 30 : 36))
            .foregroundColor(LinearColors.Minimal.textPrimary.opacity(0.85))
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
            .animation(.easeOut(duration: 0.3), value: phase)

            Group {
                switch phase {
                case .idle:
                    Text("Question \(currentQuestionIndex + 1) of \(Self.depthQuestions.count)")
                case .recording:
                    Text("Keep going, I'm listening...")
                case .processing:
                    Text("Pulling out what matters most" + String(repeating: ".", count: processingDotCount))
                case .revealing:
                    Text("Swipe through your goals to continue.")
                case .complete:
                    Text("")
                }
            }
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(LinearColors.Minimal.textSecondary)
            .animation(.easeOut(duration: 0.3), value: phase)
            .animation(.none, value: processingDotCount)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
    }

    private var currentQuestion: DepthQuestion {
        Self.depthQuestions[min(currentQuestionIndex, Self.depthQuestions.count - 1)]
    }

    private var headerIcon: String {
        switch phase {
        case .idle, .recording: return "text.bubble"
        case .processing: return "sparkles"
        case .revealing, .complete: return "checkmark.seal"
        }
    }

    private var headerTitle: String {
        switch phase {
        case .idle, .recording:
            return currentQuestion.prompt
        case .processing:
            return "Understanding you."
        case .revealing:
            return "Here's what we heard."
        case .complete:
            return "Now let's help you get there."
        }
    }

    private var headerSubtitle: String {
        switch phase {
        case .idle:
            return "Answer however you naturally would. Type it, or use your voice and let Retrospect turn it into text."
        case .recording:
            return "Keep going. Your voice is becoming the answer for this question."
        case .processing:
            return "Pulling out the signals that should shape your first podcast."
        case .revealing:
            return "Swipe through the goals Retrospect found before we create your first episode."
        case .complete:
            return ""
        }
    }

    private var currentAnswerBinding: Binding<String> {
        Binding(
            get: {
                guard questionAnswers.indices.contains(currentQuestionIndex) else { return "" }
                return questionAnswers[currentQuestionIndex]
            },
            set: { newValue in
                guard questionAnswers.indices.contains(currentQuestionIndex) else { return }
                questionAnswers[currentQuestionIndex] = newValue
            }
        )
    }

    // MARK: - Pre-recording body

    private var preRecordingBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            transcriptionArea

            micButton
        }
    }

    // MARK: - Post-recording body

    private var postRecordingBody: some View {
        VStack(spacing: 18) {
            if phase == .processing {
                processingView
                    .transition(.opacity)
            }

            if phase == .revealing || phase == .complete {
                goalsCardStack
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .opacity
                    ))
            }

            if showAcknowledgment {
                acknowledgmentView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Processing animation

    private var processingView: some View {
        VStack(spacing: 20) {
            ScrollView {
                Text(submittedTranscription)
                    .font(OnboardingStyle.bodyFont(size: 15))
                    .foregroundColor(OnboardingStyle.secondaryText.opacity(0.65))
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 60, maxHeight: 100)

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(OnboardingStyle.secondaryText)
                        .frame(width: 8, height: 8)
                        .scaleEffect(processingDotCount % 3 == i ? 1.3 : 0.7)
                        .opacity(processingDotCount % 3 == i ? 1.0 : 0.4)
                        .animation(.easeInOut(duration: 0.4), value: processingDotCount)
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Tinder-style goal card stack

    private var goalsCardStack: some View {
        VStack(spacing: 14) {
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
                                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentCardIndex)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .opacity(cardRevealed ? 1 : 0)
                .scaleEffect(cardRevealed ? 1 : 0.92)

                cardProgressIndicator
            }
        }
        .frame(height: 370)
    }

    private func goalCard(goal: RichGoal, isTop: Bool) -> some View {
        let categoryColor = GoalCategory(from: goal.category).color

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text(goal.category.uppercased())
                    .font(OnboardingStyle.bodyFont(size: 11, weight: .semibold))
                    .foregroundColor(OnboardingStyle.secondaryText)
                    .tracking(1.2)

                Spacer()

                RoundedRectangle(cornerRadius: 2)
                    .fill(categoryColor)
                    .frame(width: 24, height: 4)
            }
            .padding(.bottom, 14)

            Text(goal.title)
                .font(OnboardingStyle.titleFont(size: 24))
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
                Divider()
                    .background(OnboardingStyle.tertiaryText.opacity(0.18))
                    .padding(.vertical, 14)

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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(OnboardingStyle.control.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(categoryColor.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.10), radius: 12, y: 6)
        )
    }

    private var cardDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                cardOffset = value.translation
                cardRotation = Double(value.translation.width / 20)
            }
            .onEnded { value in
                let threshold: CGFloat = 120
                if abs(value.translation.width) > threshold {
                    let flyDirection: CGFloat = value.translation.width > 0 ? 1 : -1
                    withAnimation(.easeOut(duration: 0.3)) {
                        cardOffset = CGSize(width: flyDirection * 500, height: 0)
                        cardRotation = Double(flyDirection * 25)
                    }
                    HapticManager.shared.playSoftImpact()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        currentCardIndex += 1
                        cardOffset = .zero
                        cardRotation = 0

                        if currentCardIndex >= extractedGoals.count {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                showAcknowledgment = true
                                phase = .complete
                            }
                            HapticManager.shared.playSuccessNotification()
                        }
                    }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        cardOffset = .zero
                        cardRotation = 0
                    }
                }
            }
    }

    private var cardProgressIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<extractedGoals.count, id: \.self) { index in
                Circle()
                    .fill(index <= currentCardIndex ? OnboardingStyle.primaryText.opacity(0.65) : OnboardingStyle.tertiaryText.opacity(0.35))
                    .frame(width: index == currentCardIndex ? 8 : 6, height: index == currentCardIndex ? 8 : 6)
                    .animation(.easeOut(duration: 0.2), value: currentCardIndex)
            }
        }
    }

    // MARK: - Acknowledgment

    private var acknowledgmentView: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(OnboardingStyle.bodyFont(size: 16, weight: .medium))
                .foregroundColor(OnboardingStyle.secondaryText)

            Text(acknowledgmentText)
                .font(OnboardingStyle.bodyFont(size: 15, weight: .medium))
                .foregroundColor(OnboardingStyle.primaryText)
                .lineSpacing(3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(OnboardingStyle.control.opacity(0.68))
        )
    }

    // MARK: - Transcription area

    private var transcriptionArea: some View {
        Group {
            if audioManager.isRecording {
                ScrollView {
                    Text(audioManager.currentTranscription.isEmpty ? "Listening..." : audioManager.currentTranscription)
                        .font(OnboardingStyle.bodyFont(size: audioManager.currentTranscription.isEmpty ? 16 : 17, weight: audioManager.currentTranscription.isEmpty ? .medium : .regular))
                        .foregroundColor(audioManager.currentTranscription.isEmpty ? OnboardingStyle.tertiaryText : OnboardingStyle.primaryText)
                        .lineSpacing(5)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                }
                .frame(minHeight: 148, maxHeight: 190)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(OnboardingStyle.control.opacity(0.72))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(Color.red.opacity(0.18), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                )
            } else {
                OnboardingTextInput(
                    text: currentAnswerBinding,
                    placeholder: currentQuestion.placeholder,
                    minHeight: 148
                )
            }
        }
        .animation(.easeOut(duration: 0.2), value: currentAnswerText.isEmpty)
    }

    // MARK: - Mic button

    private var micButton: some View {
        Button(action: toggleRecording) {
            HStack(spacing: 9) {
                Image(systemName: audioManager.isRecording ? "stop.fill" : "mic.fill")
                    .font(OnboardingStyle.bodyFont(size: 16, weight: .medium))
                    .foregroundColor(audioManager.isRecording ? Color.red.opacity(0.75) : OnboardingStyle.secondaryText)

                Text(audioManager.isRecording ? "Stop recording" : "Speak answer")
                    .font(OnboardingStyle.bodyFont(size: 14, weight: .medium))
                    .foregroundColor(OnboardingStyle.secondaryText)

                if audioManager.isRecording {
                    Circle()
                        .fill(Color.red.opacity(0.55))
                        .frame(width: 7, height: 7)
                        .scaleEffect(micPulse ? 1.25 : 0.75)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                Capsule(style: .continuous)
                    .fill(OnboardingStyle.control.opacity(0.62))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(OnboardingStyle.hairline, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onChange(of: audioManager.isRecording) { _, recording in
            if recording {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    micPulse = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    micPulse = false
                }
            }
        }
    }

    // MARK: - Bottom section

    private var hasInputText: Bool {
        !currentAnswerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var currentAnswerText: String {
        guard questionAnswers.indices.contains(currentQuestionIndex) else { return "" }
        return questionAnswers[currentQuestionIndex]
    }

    private var bottomSection: some View {
        VStack(spacing: 14) {
            switch phase {
            case .idle:
                OnboardingPrimaryButton(
                    title: currentQuestionIndex == Self.depthQuestions.count - 1 ? "Finish" : "Next",
                    isDisabled: !hasInputText
                ) {
                    if hasInputText {
                        isTextFieldFocused = false
                        submitCurrentAnswer()
                    }
                }

                Button("Skip for now") { finish() }
                    .font(OnboardingStyle.bodyFont(size: 14))
                    .foregroundColor(OnboardingStyle.tertiaryText)
                    .buttonStyle(PlainButtonStyle())

            case .recording:
                OnboardingPrimaryButton(title: "Recording...", isLoading: true, isDisabled: true) {}

            case .processing:
                OnboardingPrimaryButton(title: "Understanding...", isLoading: true, isDisabled: true) {}

            case .revealing:
                EmptyView()

            case .complete:
                OnboardingPrimaryButton(title: "Play Podcast", action: finish)
            }
        }
    }

    // MARK: - Actions

    private func toggleRecording() {
        if audioManager.isRecording {
            audioManager.stopRecording { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let recording):
                        let transcription = recording.1
                        if questionAnswers.indices.contains(currentQuestionIndex) {
                            questionAnswers[currentQuestionIndex] = transcription
                        }
                        submitCurrentAnswer()
                    case .failure:
                        break
                    }
                }
            }
        } else {
            audioManager.requestPermissions { granted in
                guard granted else { return }
                DispatchQueue.main.async {
                    phase = .recording
                    audioManager.startRecording()
                }
            }
        }
    }

    private func submitCurrentAnswer() {
        guard questionAnswers.indices.contains(currentQuestionIndex) else { return }
        questionAnswers[currentQuestionIndex] = questionAnswers[currentQuestionIndex]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if currentQuestionIndex < Self.depthQuestions.count - 1 {
            HapticManager.shared.playLightImpact()
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                currentQuestionIndex += 1
            }
        } else {
            saveOnboardingDepthAnswers()
            beginProcessing(with: combinedOnboardingAnswersText())
        }
    }

    private func beginProcessing(with rawTranscription: String) {
        phase = .processing
        startProcessingDots()
        HapticManager.shared.playSoftImpact()

        let transcription = rawTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
        submittedTranscription = transcription
        guard !transcription.isEmpty else {
            extractedGoals = [RichGoal(title: "Personal growth")]
            finishProcessing()
            return
        }

        Task {
            do {
                let response = try await RetrospectAPIClient.shared.extractAndSaveGoals(text: transcription)

                let goals = response.extracted.map { extracted in
                    RichGoal(
                        title: extracted.title,
                        goalDescription: extracted.description,
                        motivation: extracted.reasoning,
                        category: Self.inferCategory(from: extracted.description)
                    )
                }

                await MainActor.run {
                    extractedGoals = goals.isEmpty ? extractGoalsFallback(from: transcription) : goals
                    backendProcessingNotes = response.processingNotes
                    finishProcessing()
                }
            } catch {
                print("Backend goal extraction failed, using fallback: \(error.localizedDescription)")
                await MainActor.run {
                    extractedGoals = extractGoalsFallback(from: transcription)
                    finishProcessing()
                }
            }
        }
    }

    private func combinedOnboardingAnswersText() -> String {
        zip(Self.depthQuestions, questionAnswers)
            .map { question, answer in
                """
                Q: \(question.prompt)
                A: \(answer.trimmingCharacters(in: .whitespacesAndNewlines))
                """
            }
            .joined(separator: "\n\n")
    }

    private func saveOnboardingDepthAnswers() {
        let savedAnswers = zip(Self.depthQuestions, questionAnswers).map { question, answer in
            SavedDepthAnswer(
                question: question.prompt,
                answer: answer.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        if let data = try? JSONEncoder().encode(savedAnswers) {
            UserDefaults.standard.set(data, forKey: Self.onboardingDepthAnswersKey)
        }
        UserDefaults.standard.set(combinedOnboardingAnswersText(), forKey: GoalsManager.onboardingProfileContextKey)

        let answers = zip(Self.depthQuestions, questionAnswers).map { question, answer in
            OnboardingAnswer(
                question: question.prompt,
                answer: answer.trimmingCharacters(in: .whitespacesAndNewlines),
                answeredAt: Date()
            )
        }
        OnboardingContextManager.shared.saveDepthAnswers(answers)
    }

    private static func inferCategory(from description: String) -> String {
        let lower = description.lowercased()
        if lower.contains("fitness") || lower.contains("exercise") || lower.contains("health") || lower.contains("gym") || lower.contains("sleep") || lower.contains("body") {
            return "Health & Fitness"
        } else if lower.contains("career") || lower.contains("work") || lower.contains("job") || lower.contains("professional") || lower.contains("business") {
            return "Career & Work"
        } else if lower.contains("relationship") || lower.contains("dating") || lower.contains("friend") || lower.contains("family") || lower.contains("partner") {
            return "Relationships"
        } else if lower.contains("money") || lower.contains("financial") || lower.contains("income") || lower.contains("saving") || lower.contains("debt") {
            return "Finance"
        } else if lower.contains("learn") || lower.contains("skill") || lower.contains("study") || lower.contains("read") || lower.contains("course") {
            return "Skills & Learning"
        }
        return "Personal Growth"
    }

    private func finishProcessing() {
        processingTimer?.invalidate()
        processingTimer = nil

        buildAcknowledgment()

        withAnimation {
            phase = .revealing
        }
        revealCardStack()
    }

    private func revealCardStack() {
        currentCardIndex = 0
        cardOffset = .zero
        cardRotation = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                cardRevealed = true
            }
            HapticManager.shared.playSoftImpact()
        }
    }

    private func buildAcknowledgment() {
        if let notes = backendProcessingNotes, !notes.isEmpty {
            // Truncate long processing notes to a single line for the UI
            let firstSentence = notes.components(separatedBy: ". ").first ?? notes
            acknowledgmentText = firstSentence.hasSuffix(".") ? firstSentence : firstSentence + "."
            return
        }

        let categories = Set(extractedGoals.map { $0.category.lowercased() })
        let hasHealth = categories.contains(where: { $0.contains("health") || $0.contains("fitness") })
        let hasCareer = categories.contains(where: { $0.contains("career") || $0.contains("work") })
        let hasRelationships = categories.contains(where: { $0.contains("relationship") })

        if hasHealth && hasCareer {
            acknowledgmentText = "Body and ambition — we'll keep you honest on both."
        } else if hasHealth {
            acknowledgmentText = "Taking care of yourself first. We'll help you stay on track."
        } else if hasCareer {
            acknowledgmentText = "Big ambitions. We'll make sure you don't lose sight of them."
        } else if hasRelationships {
            acknowledgmentText = "The people around you matter. We'll help you show up for them."
        } else if extractedGoals.count >= 3 {
            acknowledgmentText = "You've got a clear picture of where you're headed. Let's go."
        } else {
            acknowledgmentText = "Got it — we know what matters to you. Let's make it happen."
        }
    }

    // MARK: - Processing dots animation

    private func startProcessingDots() {
        processingDotCount = 0
        processingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            processingDotCount = (processingDotCount + 1) % 4
        }
    }

    // MARK: - Fallback extraction (produces RichGoals from keywords)

    private func extractGoalsFallback(from text: String) -> [RichGoal] {
        let lower = text.lowercased()
        var goals: [RichGoal] = []
        let themes: [(keywords: [String], title: String, category: String)] = [
            (["exercise", "workout", "gym", "fitness", "run", "move", "stronger"], "Exercise more", "Health & Fitness"),
            (["sleep", "rest", "tired", "energy"], "Better sleep", "Health & Fitness"),
            (["read", "book", "reading"], "Read daily", "Skills & Learning"),
            (["learn", "skill", "study", "course"], "Learn something new", "Skills & Learning"),
            (["stress", "calm", "anxiety", "peaceful"], "Reduce stress", "Personal Growth"),
            (["eat", "food", "diet", "healthier"], "Eat healthier", "Health & Fitness"),
            (["money", "save", "spend", "budget"], "Save money", "Finance"),
            (["present", "mindful"], "Be more present", "Personal Growth"),
            (["focus", "concentrate", "distract"], "Improve focus", "Personal Growth"),
            (["habit", "routine", "discipline"], "Build habits", "Personal Growth"),
        ]
        for (keywords, title, category) in themes {
            if keywords.contains(where: { lower.contains($0) }) {
                goals.append(RichGoal(title: title, category: category))
            }
        }
        if goals.isEmpty {
            goals = [RichGoal(title: "Personal growth", category: "Personal Growth")]
        }
        return Array(goals.prefix(4))
    }

    // MARK: - Finish

    private func finish() {
        HapticManager.shared.playSuccessNotification()

        var goalsToSave = extractedGoals
        if goalsToSave.isEmpty {
            let transcription = audioManager.currentTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
            if !transcription.isEmpty {
                goalsToSave = extractGoalsFallback(from: transcription)
            }
        }

        goalsManager.addRichGoals(goalsToSave)
        OnboardingContextManager.shared.saveExtractedGoals(goalsToSave)

        Task {
            let granted = await PodcastNotificationService.shared.requestAuthorization()
            if granted {
                PodcastNotificationService.shared.scheduleAllRecurringNotifications()
            }
        }

        onComplete?(goalsToSave)
    }
}
