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
    var onComplete: (() -> Void)?

    @StateObject private var audioManager = AudioRecordingManager()
    @StateObject private var goalsManager = GoalsManager.shared

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

    @State private var typedText: String = ""
    @FocusState private var isTextFieldFocused: Bool

    @State private var contentOpacity: Double = 0
    @State private var micPulse = false
    @State private var processingDotCount = 0
    @State private var processingTimer: Timer?
    @State private var cardRevealed = false

    var body: some View {
        ZStack {
            LinearColors.Minimal.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)

                headerSection

                Spacer()
                    .frame(height: 24)

                if phase == .idle || phase == .recording {
                    preRecordingBody
                        .transition(.opacity)
                } else {
                    postRecordingBody
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                }

                Spacer()

                bottomSection
                    .padding(.horizontal, 28)
                    .padding(.bottom, 50)
            }
            .opacity(contentOpacity)
        }
        .preferredColorScheme(.dark)
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
                    Text("What are your goals?")
                case .processing:
                    Text("Understanding you...")
                case .revealing, .complete:
                    Text("Here's what we heard")
                }
            }
            .font(.custom("EBGaramond12-Italic", size: 36))
            .foregroundColor(LinearColors.Minimal.textPrimary.opacity(0.85))
            .animation(.easeOut(duration: 0.3), value: phase)

            Group {
                switch phase {
                case .idle:
                    Text("Talk or type — tell me everything on your mind.")
                case .recording:
                    Text("Keep going, I'm listening...")
                case .processing:
                    Text("Pulling out what matters most" + String(repeating: ".", count: processingDotCount))
                case .revealing:
                    Text("Swipe through your goals to continue.")
                case .complete:
                    Text("We know what matters to you. Let's go.")
                }
            }
            .font(.system(size: 16, weight: .regular, design: .rounded))
            .foregroundColor(LinearColors.Minimal.textSecondary)
            .animation(.easeOut(duration: 0.3), value: phase)
            .animation(.none, value: processingDotCount)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
    }

    // MARK: - Pre-recording body

    private var preRecordingBody: some View {
        VStack(spacing: 0) {
            transcriptionArea
                .padding(.horizontal, 28)

            Spacer()
                .frame(height: 24)

            micButton
        }
    }

    // MARK: - Post-recording body

    private var postRecordingBody: some View {
        VStack(spacing: 0) {
            if phase == .processing {
                processingView
                    .padding(.horizontal, 28)
                    .transition(.opacity)
            }

            if phase == .revealing || phase == .complete {
                goalsCardStack
                    .padding(.horizontal, 28)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .opacity
                    ))
            }

            if showAcknowledgment {
                acknowledgmentView
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Processing animation

    private var processingView: some View {
        VStack(spacing: 20) {
            ScrollView {
                Text(submittedTranscription)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textSecondary.opacity(0.5))
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 60, maxHeight: 100)

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(LinearColors.Minimal.accent)
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
    }

    private func goalCard(goal: RichGoal, isTop: Bool) -> some View {
        let categoryColor = GoalCategory(from: goal.category).color

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text(goal.category.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(categoryColor.opacity(0.8))
                    .tracking(1.2)

                Spacer()

                RoundedRectangle(cornerRadius: 2)
                    .fill(categoryColor)
                    .frame(width: 24, height: 4)
            }
            .padding(.bottom, 14)

            Text(goal.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, goal.goalDescription.isEmpty ? 0 : 10)

            if !goal.goalDescription.isEmpty {
                Text(goal.goalDescription)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !goal.motivation.isEmpty {
                Divider()
                    .background(LinearColors.Minimal.border.opacity(0.3))
                    .padding(.vertical, 14)

                Text("Why this matters")
                    .font(.custom("EBGaramond12-Italic", size: 14))
                    .foregroundColor(LinearColors.Minimal.textTertiary)
                    .padding(.bottom, 6)

                Text(goal.motivation)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textSecondary.opacity(0.8))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            if isTop {
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "hand.draw")
                            .font(.system(size: 11, weight: .medium))
                        Text("Swipe to continue")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(LinearColors.Minimal.textTertiary.opacity(0.4))
                    Spacer()
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearColors.Minimal.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(categoryColor.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
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
                    .fill(index <= currentCardIndex ? LinearColors.Minimal.accent : LinearColors.Minimal.border.opacity(0.5))
                    .frame(width: index == currentCardIndex ? 8 : 6, height: index == currentCardIndex ? 8 : 6)
                    .animation(.easeOut(duration: 0.2), value: currentCardIndex)
            }
        }
    }

    // MARK: - Acknowledgment

    private var acknowledgmentView: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(LinearColors.Minimal.accent)

            Text(acknowledgmentText)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textPrimary.opacity(0.85))
                .lineSpacing(3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearColors.Minimal.accent.opacity(0.08))
        )
    }

    // MARK: - Transcription area

    private var transcriptionArea: some View {
        VStack(spacing: 0) {
            if audioManager.isRecording {
                ScrollView {
                    if audioManager.currentTranscription.isEmpty {
                        Text("Listening...")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textSecondary)
                    } else {
                        Text(audioManager.currentTranscription)
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                            .lineSpacing(5)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ZStack(alignment: .topLeading) {
                    if typedText.isEmpty {
                        Text("Tap the mic or type/paste what you want to focus on — fitness, relationships, career, sleep, anything.")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                            .lineSpacing(4)
                            .padding(.top, 0)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $typedText)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                        .scrollContentBackground(.hidden)
                        .lineSpacing(5)
                        .focused($isTextFieldFocused)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

        
        }
        .frame(minHeight: 100, maxHeight: 180)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearColors.Minimal.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            audioManager.isRecording ? LinearColors.Minimal.accent.opacity(0.4) :
                            isTextFieldFocused ? LinearColors.Minimal.accent.opacity(0.3) :
                            LinearColors.Minimal.border.opacity(0.3),
                            lineWidth: (audioManager.isRecording || isTextFieldFocused) ? 1.5 : 1
                        )
                )
        )
        .animation(.easeOut(duration: 0.2), value: typedText.isEmpty)
    }

    // MARK: - Mic button

    private var micButton: some View {
        Button(action: toggleRecording) {
            ZStack {
                Circle()
                    .fill(audioManager.isRecording ? Color.red.opacity(0.15) : LinearColors.Minimal.backgroundCard)
                    .frame(width: 80, height: 80)
                    .scaleEffect(audioManager.isRecording && micPulse ? 1.15 : 1.0)

                Circle()
                    .strokeBorder(
                        audioManager.isRecording ? Color.red.opacity(0.6) : LinearColors.Minimal.border.opacity(0.4),
                        lineWidth: 2
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(audioManager.isRecording && micPulse ? 1.15 : 1.0)

                Image(systemName: audioManager.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(audioManager.isRecording ? .red : LinearColors.Minimal.textPrimary)
            }
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
        !typedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var bottomSection: some View {
        VStack(spacing: 14) {
            switch phase {
            case .idle:
                Button(action: {
                    if hasInputText {
                        isTextFieldFocused = false
                        beginProcessing(with: typedText)
                    }
                }) {
                    Text(hasInputText ? "Next" : "Next")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.buttonPrimaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(LinearColors.Minimal.accent.opacity(hasInputText ? 1.0 : 0.3))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!hasInputText)

                Button("Skip for now") { finish() }
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textTertiary)

            case .recording:
                Button(action: {}) {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: LinearColors.Minimal.buttonPrimaryText))
                            .scaleEffect(0.8)
                        Text("Recording...")
                    }
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.buttonPrimaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(LinearColors.Minimal.accent.opacity(0.3))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(true)

            case .processing:
                Button(action: {}) {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: LinearColors.Minimal.buttonPrimaryText))
                            .scaleEffect(0.8)
                        Text("Understanding...")
                    }
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.buttonPrimaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(LinearColors.Minimal.accent.opacity(0.3))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(true)

            case .revealing:
                EmptyView()

            case .complete:
                Button(action: finish) {
                    Text("Get Started")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.buttonPrimaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(LinearColors.Minimal.accent)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Actions

    private func toggleRecording() {
        if audioManager.isRecording {
            audioManager.stopRecording { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(_, let transcription):
                        beginProcessing(with: transcription)
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

        Task {
            let granted = await PodcastNotificationService.shared.requestAuthorization()
            if granted {
                PodcastNotificationService.shared.scheduleAllRecurringNotifications()
            }
        }

        onComplete?()
    }
}
