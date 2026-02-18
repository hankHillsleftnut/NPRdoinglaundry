//
//  iMessageOnboardingView.swift
//  Retrospect
//
//  iMessage-style onboarding: conversation with "Retrospect", quick-reply responses, auto-timed messages.
//

import SwiftUI
import AuthenticationServices

// Alias design-system chat colors for convenience
private enum iMessageBubble {
    static let incoming = LinearColors.Minimal.chatBubbleIncoming
    static let outgoing = LinearColors.Minimal.chatBubbleOutgoing
    static let outgoingText = LinearColors.Minimal.chatBubbleOutgoingText
}

// MARK: - Data Model

enum ChatMessageSender {
    case retrospect
    case user
}

enum QuickReplyAction: Equatable {
    case advance
    case appleSignIn
    case connectXBookmarks
    case connectGoogleDocs
    case enableHealth
    case enableScreenTime
    case selectPersona(String)
    case addGoal(String)
    case customGoalInput
    case confirmGoals
    case complete
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let sender: ChatMessageSender
    let text: String
    var isSpecial: Bool = false
}

struct QuickReplyItem: Identifiable {
    let id = UUID()
    let label: String
    let action: QuickReplyAction
}

// MARK: - Onboarding Phase

private enum OnboardingPhase: Int, CaseIterable {
    case story = 1
    case privacy = 2
    case auth = 3
    case xBookmarks = 4
    case googleDocs = 5
    case appleHealth = 6
    case screenTime = 7
    case voicePersona = 8
    case goals = 9
    case closing = 10
    
    static let totalPhases = 10
}

// MARK: - Send Button Style (for input bar)

private enum SendButtonStyle: Equatable {
    case `default`
    case apple
    case sparkle
}

// MARK: - iMessage Onboarding View

struct iMessageOnboardingView: View {
    var onComplete: (() -> Void)?
    
    @AppStorage("onboardingCurrentStep") private var persistedStep: Int = 1
    @AppStorage("onboardingSchemaVersion") private var onboardingSchemaVersion: Int = 1
    @State private var phase: OnboardingPhase = .story
    @State private var messages: [ChatMessage] = []
    @State private var showTypingIndicator = false
    @State private var scrollToId: ScrollTarget?
    /// Message IDs that have finished their typing animation — show static text so scroll doesn't re-trigger animation.
    @State private var completedAnimationIds: Set<UUID> = []
    
    private enum ScrollTarget: Hashable {
        case message(UUID)
        case typing
        case bottomPadding
    }
    
    /// Height of the bottom "safe" area so the last message stays above the blur/input. Must match blur + clearance.
    private static let scrollBottomPadding: CGFloat = 120
    @State private var inputBarText = ""
    @FocusState private var isInputFocused: Bool
    
    // Input bar state (auto-fill, send button style, skip link)
    @State private var isAutoFillLocked: Bool = false
    @State private var showSkipLink: Bool = false
    @State private var sendButtonOverride: SendButtonStyle = .default
    
    // Goals multi-turn state (3 user turns + 1 summary)
    @State private var goalsTurn: Int = 1
    @State private var goalTurn1Text: String = ""
    @State private var goalTurn2Text: String = ""
    @State private var goalTurn3Text: String = ""
    @State private var goalTurn2BotMessage: String = ""
    @State private var goalTurn3BotMessage: String = ""
    @State private var extractedGoalsFromConversation: [String] = []
    @State private var isLoadingGoalsReply: Bool = false
    
    static let goalsFirstQuestion = "If you could change one thing about your life in the next year, what would it be?"
    
    // Voice recording for goals brain-dump
    @StateObject private var onboardingAudioManager = AudioRecordingManager()
    
    @StateObject private var apiClient = RetrospectAPIClient.shared
    @StateObject private var xBookmarksService = XBookmarksService.shared
    @StateObject private var googleDocsService = GoogleDocsService.shared
    @StateObject private var screenTimeService = ScreenTimeService.shared
    @StateObject private var goalsManager = GoalsManager.shared
    @AppStorage("healthKitEnabled") private var healthKitEnabled = false
    @AppStorage("voice_persona") private var voicePersona: String = "thoughtful_friend"
    
    @State private var isSigningIn = false
    @State private var signInError: String?
    @State private var appleSignInCoordinator: AppleSignInCoordinator?
    @State private var isConnectingX = false
    @State private var isConnectingGoogle = false
    @State private var googleError: String?
    @State private var isRequestingHealth = false
    @State private var isConnectingScreenTime = false
    @State private var isSavingPersona = false
    
    private let totalSteps = OnboardingPhase.totalPhases
    private let goalSuggestions = [
        "Exercise more", "Better sleep", "Read daily", "Learn something new",
        "Reduce stress", "Eat healthier", "Save money", "Be more present",
        "Improve focus", "Build habits"
    ]
    
    var body: some View {
        ZStack {
            LinearColors.Minimal.chatBarBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                contactHeader
                
                ZStack(alignment: .bottomTrailing) {
                    ZStack(alignment: .bottom) {
                        ScrollViewReader { proxy in
                            ScrollView(.vertical, showsIndicators: false) {
                                LazyVStack(alignment: .leading, spacing: 4) {
                                    Spacer(minLength: 0)
                                        .frame(minHeight: 20)
                                    ForEach(messages) { msg in
                                        ChatBubbleView(
                                            message: msg,
                                            animationCompleted: completedAnimationIds.contains(msg.id),
                                            onAnimationComplete: { completedAnimationIds.insert(msg.id) }
                                        )
                                        .id(ScrollTarget.message(msg.id))
                                    }
                                    if showTypingIndicator {
                                        TypingIndicatorView()
                                            .id(ScrollTarget.typing)
                                    }
                                if phase == .voicePersona {
                                    PersonaCardStack(onSelect: { personaId in
                                        let name = personaDisplayName(personaId)
                                        inputBarText = name
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                            addUserBubble(name)
                                            savePersonaAndAdvance(personaId)
                                        }
                                    })
                                }
                                    Color.clear
                                        .frame(height: Self.scrollBottomPadding)
                                        .id(ScrollTarget.bottomPadding)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16)
                            }
                            .scrollDismissesKeyboard(.interactively)
                            .onChange(of: scrollToId) { _, target in
                                guard let target = target else { return }
                                DispatchQueue.main.async {
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        proxy.scrollTo(target, anchor: .bottom)
                                    }
                                }
                            }
                            .onChange(of: messages.count) { _, _ in
                                scrollToBottom()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { scrollToBottom() }
                            }
                            .onChange(of: showTypingIndicator) { _, _ in
                                scrollToBottom()
                            }
                        }
                        
                        VariableBlurView()
                            .frame(height: 80)
                            .allowsHitTesting(false)
                        
                        LinearGradient(
                            colors: [Color.clear, LinearColors.Minimal.chatBarBackground],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 80)
                        .allowsHitTesting(false)
                    }
                    
                    if messages.count >= 4 || showTypingIndicator {
                        Button(action: {
                            HapticManager.shared.playLightImpact()
                            scrollToBottom()
                        }) {
                            Image(systemName: "chevron.down.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(LinearColors.Minimal.textPrimary.opacity(0.9))
                                .shadow(color: LinearColors.Minimal.shadowLight, radius: 2, x: 0, y: 1)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 8)
                    }
                }
                
                bottomBar
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Migration: a new X bookmarks step was inserted after auth.
            // Preserve prior in-progress onboarding positions from older builds.
            if onboardingSchemaVersion < 2 {
                if persistedStep >= 4 && persistedStep <= 9 {
                    persistedStep += 1
                }
                onboardingSchemaVersion = 2
            }

            let raw = max(1, persistedStep)
            phase = OnboardingPhase(rawValue: raw) ?? .story
            replayMessagesForPhase()
            startOrResumeConversation()
        }
        .alert("Sign-in failed", isPresented: Binding(get: { signInError != nil }, set: { if !$0 { signInError = nil } })) {
            Button("OK") { signInError = nil }
        } message: {
            if let err = signInError { Text(err) }
        }
        .alert("Connection Error", isPresented: Binding(get: { googleError != nil }, set: { if !$0 { googleError = nil } })) {
            Button("OK") { googleError = nil }
        } message: {
            if let err = googleError { Text(err) }
        }
    }
    
    // MARK: - Contact Header (iMessage-style, minimal)
    
    private var contactHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(LinearColors.Minimal.accent)
                Text("Retrospect")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            HStack(spacing: 6) {
                ForEach(1...OnboardingPhase.totalPhases, id: \.self) { step in
                    Circle()
                        .fill(step <= phase.rawValue ? LinearColors.Minimal.accent.opacity(0.9) : LinearColors.Minimal.border)
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.bottom, 12)
        }
        .background(LinearColors.Minimal.chatBarBackground)
    }
    
    // MARK: - Bottom Bar (always input bar + optional skip link)
    
    private var bottomBar: some View {
        VStack(spacing: 0) {
            inputBar
            if showSkipLink {
                Button("or skip") {
                    addUserBubble("Skip for now")
                    advancePhase()
                }
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(LinearColors.Minimal.textTertiary)
                .padding(.top, 6)
                .padding(.bottom, 8)
            }
        }
        .background(LinearColors.Minimal.chatBarBackground)
    }
    
    // MARK: - Input Bar (iMessage-style)
    
    private var inputBar: some View {
        let isAutoFillActive = isAutoFillLocked && !inputBarText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack(alignment: .center, spacing: 10) {
            if phase == .goals {
                Button(action: { toggleVoiceRecording() }) {
                    Image(systemName: onboardingAudioManager.isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(onboardingAudioManager.isRecording ? Color.red : LinearColors.Minimal.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 32, height: 32)
            }
            
            TextField("Message", text: $inputBarText)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(LinearColors.Minimal.textPrimary)
                .focused($isInputFocused)
                .submitLabel(.send)
                .onSubmit { sendInputBarMessage() }
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearColors.Minimal.chatInputField)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(isAutoFillActive ? LinearColors.Minimal.accent : Color.clear, lineWidth: isAutoFillActive ? 2 : 0)
                )
            
            Button(action: {
                if sendButtonOverride == .apple {
                    triggerAppleSignIn()
                } else {
                    sendInputBarMessage()
                }
            }) {
                Group {
                    switch sendButtonOverride {
                    case .default:
                        Image(systemName: "arrow.up.circle.fill")
                    case .apple:
                        Image(systemName: "apple.logo")
                            .font(.system(size: 22, weight: .medium))
                    case .sparkle:
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .medium))
                    }
                }
                .font(.system(size: sendButtonOverride == .default ? 32 : 24))
                .foregroundStyle(
                    (sendButtonOverride == .apple || sendButtonOverride == .sparkle) || !inputBarText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? (sendButtonOverride == .apple ? Color.primary : iMessageBubble.outgoing)
                    : LinearColors.Minimal.textTertiary
                )
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                .scaleEffect(isAutoFillActive ? 1.08 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAutoFillActive)
            }
            .disabled(sendButtonOverride == .default && inputBarText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 56)
    }
    
    private func toggleVoiceRecording() {
        if onboardingAudioManager.isRecording {
            onboardingAudioManager.stopRecording { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success((_, let transcription)):
                        let trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            inputBarText = trimmed
                        }
                    case .failure:
                        break
                    }
                }
            }
        } else {
            onboardingAudioManager.requestPermissions { granted in
                guard granted else { return }
                DispatchQueue.main.async {
                    onboardingAudioManager.startRecording()
                }
            }
        }
    }
    
    /// Auto-fill the input bar with text (e.g. "I'm in", "Sign in with Apple") and set send button style. Optionally show skip link. Animates character-by-character.
    private func autoFillInputBar(text: String, style: SendButtonStyle, showSkip: Bool) {
        isAutoFillLocked = true
        sendButtonOverride = style
        showSkipLink = showSkip
        inputBarText = ""
        let intervalPerChar: Double = 0.03
        let characters = Array(text)
        for (index, char) in characters.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + intervalPerChar * Double(index)) { [self] in
                guard isAutoFillLocked else { return }
                if index < inputBarText.count { return }
                inputBarText = String(characters.prefix(index + 1))
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + intervalPerChar * Double(characters.count) + 0.1) {
            scrollToBottom()
        }
    }
    
    private func sendInputBarMessage() {
        let trimmed = inputBarText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputBarText = ""
        isAutoFillLocked = false
        showSkipLink = false
        sendButtonOverride = .default
        addUserBubble(trimmed)
        HapticManager.shared.playMediumImpact()
        
        switch phase {
        case .story:
            advancePhase()
        case .privacy:
            advancePhase()
        case .auth:
            if trimmed.lowercased().contains("sign in") {
                triggerAppleSignIn()
            }
        case .xBookmarks:
            if trimmed.lowercased().contains("connect")
                || trimmed.lowercased().contains("x")
                || trimmed.lowercased().contains("twitter") {
                connectXBookmarks()
            } else if trimmed.lowercased().contains("skip") {
                advancePhase()
            }
        case .googleDocs:
            if trimmed.lowercased().contains("connect") || trimmed.lowercased().contains("google") {
                connectGoogleDocs()
            } else if trimmed.lowercased().contains("skip") {
                advancePhase()
            }
        case .appleHealth:
            if trimmed.lowercased().contains("enable") || trimmed.lowercased().contains("health") {
                requestHealthAccess()
            } else if trimmed.lowercased().contains("skip") {
                advancePhase()
            }
        case .screenTime:
            if trimmed.lowercased().contains("enable") || trimmed.lowercased().contains("screen time") {
                requestScreenTimeAccess()
            } else if trimmed.lowercased().contains("skip") {
                advancePhase()
            }
        case .voicePersona:
            break
        case .goals:
            if goalsTurn == 4 {
                for g in extractedGoalsFromConversation {
                    goalsManager.addGoal(g)
                }
                if !trimmed.lowercased().contains("perfect") && trimmed.count > 2 {
                    goalsManager.addGoal(trimmed)
                }
                HapticManager.shared.playSuccessNotification()
                phase = .closing
                persistedStep = OnboardingPhase.closing.rawValue
                startOrResumeConversation()
            } else {
                handleGoalsTurnResponse(trimmed)
            }
        case .closing:
            if trimmed.lowercased().contains("start") || trimmed.lowercased().contains("journal") {
                completeOnboarding()
            }
        }
    }
    
    private func handleGoalsTurnResponse(_ text: String) {
        switch goalsTurn {
        case 1:
            goalTurn1Text = text
            goalsTurn = 2
            fetchGoalsReplyAndAppend(
                messages: [
                    ["role": "assistant", "content": Self.goalsFirstQuestion],
                    ["role": "user", "content": text]
                ],
                fallback: fallbackGoalsReplyForTurn(2),
                storeIn: { goalTurn2BotMessage = $0 }
            )
        case 2:
            goalTurn2Text = text
            goalsTurn = 3
            let turn2Bot = goalTurn2BotMessage.isEmpty ? fallbackGoalsReplyForTurn(2) : goalTurn2BotMessage
            fetchGoalsReplyAndAppend(
                messages: [
                    ["role": "assistant", "content": Self.goalsFirstQuestion],
                    ["role": "user", "content": goalTurn1Text],
                    ["role": "assistant", "content": turn2Bot],
                    ["role": "user", "content": text]
                ],
                fallback: fallbackGoalsReplyForTurn(3),
                storeIn: { goalTurn3BotMessage = $0 }
            )
        case 3:
            goalTurn3Text = text
            extractedGoalsFromConversation = extractGoalsFromTurns()
            goalsTurn = 4
            appendGoalsBotMessage(goalsIntroMessages())
            autoFillInputBar(text: "That's perfect", style: .default, showSkip: false)
        default:
            break
        }
    }
    
    private func fallbackGoalsReplyForTurn(_ turn: Int) -> String {
        if turn == 2 {
            let lead = goalTurn1Text.prefix(50)
            let suffix = goalTurn1Text.count > 50 ? "…" : ""
            return "\(lead)\(suffix) — got it. What does that look like day-to-day for you? What would be different?"
        }
        if turn == 3 {
            return "Tell me about a moment recently where you felt closest to — or furthest from — that."
        }
        return "What else matters to you right now?"
    }
    
    private func fetchGoalsReplyAndAppend(messages apiMessages: [[String: Any]], fallback: String, storeIn: @escaping (String) -> Void) {
        showTypingIndicator = true
        isLoadingGoalsReply = true
        scrollToBottom()
        
        ClaudeService.shared.generateOnboardingGoalsReply(conversationMessages: apiMessages) { [self] result in
            DispatchQueue.main.async {
                showTypingIndicator = false
                isLoadingGoalsReply = false
                let replyText: String
                switch result {
                case .success(let text):
                    replyText = text
                    storeIn(text)
                case .failure:
                    replyText = fallback
                    storeIn(fallback)
                }
                let msg = ChatMessage(sender: .retrospect, text: replyText)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    messages.append(msg)
                }
                HapticManager.shared.playSoftImpact()
                scrollToBottomAfterSend()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    isInputFocused = true
                }
            }
        }
    }
    
    private func appendGoalsBotMessage(_ group: [ChatMessage]) {
        guard let msg = group.first else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            messages.append(msg)
        }
        HapticManager.shared.playSoftImpact()
        scrollToBottomAfterSend()
        if phase == .goals {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isInputFocused = true
            }
        }
    }
    
    // MARK: - Conversation Engine
    
    private func replayMessagesForPhase() {
        messages = []
        for p in OnboardingPhase.allCases {
            if p.rawValue < phase.rawValue {
                if p == .goals && phase == .closing {
                    continue
                }
                appendPhaseMessages(for: p, animated: false)
            } else if p == phase {
                break
            }
        }
        completedAnimationIds = Set(messages.map(\.id))
    }
    
    private func appendPhaseMessages(for p: OnboardingPhase, animated: Bool) {
        let newMessages = scriptMessages(for: p)
        for msg in newMessages {
            if !messages.contains(where: { $0.id == msg.id }) {
                messages.append(msg)
            }
        }
    }
    
    private func scriptMessages(for p: OnboardingPhase) -> [ChatMessage] {
        switch p {
        case .story:
            return [
                ChatMessage(sender: .retrospect, text: "I know your dirty little secret."),
                ChatMessage(sender: .retrospect, text: "Notes you never revisit. Content you save and forget. Your life is scattered across a dozen apps."),
                ChatMessage(sender: .retrospect, text: "Retrospect turns all of it into a weekly podcast about your life — so nothing gets lost."),
            ]
        case .privacy:
            return [
                ChatMessage(sender: .retrospect, text: "Before anything — your data is yours. Period."),
                ChatMessage(sender: .retrospect, text: "Everything stays on your device. Encrypted. Private. You choose exactly what Retrospect sees."),
            ]
        case .auth:
            return [
                ChatMessage(sender: .retrospect, text: "Let's make this yours."),
                ChatMessage(sender: .retrospect, text: "Sign in so your reflections and podcasts stay with you across devices."),
            ]
        case .xBookmarks:
            return [
                ChatMessage(sender: .retrospect, text: "Want me to read your X bookmarks too?"),
                ChatMessage(sender: .retrospect, text: "Connect X and I'll pull saved posts into your weekly reflection so your best finds don't disappear."),
            ]
        case .googleDocs:
            return [
                ChatMessage(sender: .retrospect, text: "Your Google Docs are full of unfinished thoughts and half-written ideas."),
                ChatMessage(sender: .retrospect, text: "Connect them, and I'll weave those threads into your weekly reflections — nothing leaves your device."),
            ]
        case .appleHealth:
            return [
                ChatMessage(sender: .retrospect, text: "Your body keeps score even when you don't."),
                ChatMessage(sender: .retrospect, text: "Sleep patterns, activity streaks, mindful minutes — connecting Health lets me spot the patterns you'd miss."),
            ]
        case .screenTime:
            return [
                ChatMessage(sender: .retrospect, text: "This one's interesting — Screen Time."),
                ChatMessage(sender: .retrospect, text: "I can see which apps you spend time on, how often you pick up your phone, and what categories dominate your day."),
                ChatMessage(sender: .retrospect, text: "It helps me notice patterns — like if you're doom-scrolling when stressed, or reaching for your phone when you're avoiding something."),
            ]
        case .voicePersona:
            return [
                ChatMessage(sender: .retrospect, text: "One more thing — who do you want speaking to you each week?"),
            ]
        case .goals:
            return goalsIntroMessages()
        case .closing:
            return [
                ChatMessage(sender: .retrospect, text: "You just told me more about yourself in five minutes than most apps learn in five months."),
                ChatMessage(sender: .retrospect, text: "Every journal entry, every voice note, every stray thought — I'll turn them into something you actually want to hear."),
                ChatMessage(sender: .retrospect, text: "Your first podcast drops after your first week of entries."),
                ChatMessage(sender: .retrospect, text: "Ready when you are."),
            ]
        }
    }
    
    private func goalsIntroMessages() -> [ChatMessage] {
        if goalsTurn == 1 {
            return [ChatMessage(sender: .retrospect, text: Self.goalsFirstQuestion)]
        }
        if goalsTurn == 4 {
            let list = extractedGoalsFromConversation.prefix(3).joined(separator: ", ")
            return [ChatMessage(sender: .retrospect, text: "From what you've told me, it sounds like your focus areas are: \(list). Sound right?")]
        }
        return []
    }
    
    private func extractGoalsFromTurns() -> [String] {
        var combined = [goalTurn1Text, goalTurn2Text, goalTurn3Text]
            .joined(separator: " ")
            .lowercased()
        var goals: [String] = []
        let themes: [(keywords: [String], goal: String)] = [
            (["exercise", "workout", "gym", "fitness", "run", "move"], "Exercise more"),
            (["sleep", "rest", "tired", "energy"], "Better sleep"),
            (["read", "book", "reading"], "Read daily"),
            (["learn", "skill", "study", "course"], "Learn something new"),
            (["stress", "calm", "anxiety", "overwhelm"], "Reduce stress"),
            (["eat", "food", "diet", "healthier"], "Eat healthier"),
            (["money", "save", "spend", "financial"], "Save money"),
            (["present", "moment", "mindful"], "Be more present"),
            (["focus", "concentrate", "distract"], "Improve focus"),
            (["habit", "routine", "consistent"], "Build habits"),
            (["relationship", "friend", "family", "connect"], "Improve relationships"),
            (["career", "work", "job", "professional"], "Career growth"),
            (["creative", "create", "write", "art"], "Creativity"),
        ]
        for (keywords, goal) in themes {
            if keywords.contains(where: { combined.contains($0) }), !goals.contains(goal) {
                goals.append(goal)
            }
        }
        if goals.isEmpty {
            let sentences = goalTurn1Text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 10 }
            goals = sentences.prefix(3).map { String($0.prefix(40)) }
            if goals.isEmpty { goals = ["Personal growth"] }
        }
        return Array(goals.prefix(3))
    }
    
    private func personaDisplayName(_ id: String) -> String {
        switch id {
        case "wise_mentor": return "Wise Mentor"
        case "energetic_host": return "Energetic Host"
        default: return "Thoughtful Friend"
        }
    }
    
    private func startOrResumeConversation() {
        showTypingIndicator = false
        showSkipLink = false
        sendButtonOverride = .default
        isAutoFillLocked = false
        
        switch phase {
        case .story:
            inputBarText = ""
            deliverMessageGroup(scriptMessages(for: .story), typingDuration: 1.2) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    if phase == .story {
                        advancePhase()
                    }
                }
            }
        case .privacy:
            deliverMessageGroup(scriptMessages(for: .privacy), typingDuration: 1.8) {
                autoFillInputBar(text: "I'm in", style: .default, showSkip: false)
            }
        case .auth:
            deliverMessageGroup(scriptMessages(for: .auth), typingDuration: 1.2) {
                autoFillInputBar(text: "Sign in with Apple", style: .apple, showSkip: false)
            }
        case .xBookmarks:
            deliverMessageGroup(scriptMessages(for: .xBookmarks), typingDuration: 1.6) {
                autoFillInputBar(text: "Connect X Bookmarks", style: .default, showSkip: true)
            }
        case .googleDocs:
            deliverMessageGroup(scriptMessages(for: .googleDocs), typingDuration: 1.8) {
                autoFillInputBar(text: "Connect Google Docs", style: .default, showSkip: true)
            }
        case .appleHealth:
            deliverMessageGroup(scriptMessages(for: .appleHealth), typingDuration: 1.8) {
                autoFillInputBar(text: "Enable Apple Health", style: .default, showSkip: true)
            }
        case .screenTime:
            deliverMessageGroup(scriptMessages(for: .screenTime), typingDuration: 2.2) {
                autoFillInputBar(text: "Enable Screen Time", style: .default, showSkip: true)
            }
        case .voicePersona:
            inputBarText = ""
            deliverMessageGroup(scriptMessages(for: .voicePersona), typingDuration: 1.2) { }
        case .goals:
            goalsTurn = 1
            goalTurn1Text = ""
            goalTurn2Text = ""
            goalTurn3Text = ""
            goalTurn2BotMessage = ""
            goalTurn3BotMessage = ""
            inputBarText = ""
            deliverMessageGroup(goalsIntroMessages(), typingDuration: 0.8) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isInputFocused = true
                }
            }
        case .closing:
            deliverMessageGroup(scriptMessages(for: .closing), typingDuration: 2.0) {
                autoFillInputBar(text: "Start Journaling", style: .sparkle, showSkip: false)
            }
        }
    }
    
    private func deliverMessageGroup(_ group: [ChatMessage], typingDuration: Double, then: @escaping () -> Void) {
        let existingIds = Set(messages.map { $0.id })
        let toAppend = group.filter { !existingIds.contains($0.id) }
        guard !toAppend.isEmpty else {
            then()
            return
        }
        
        showTypingIndicator = true
        scrollToBottom()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + typingDuration) {
            showTypingIndicator = false
            var delay: Double = 0
            for (index, msg) in toAppend.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        messages.append(msg)
                    }
                    HapticManager.shared.playSoftImpact()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { scrollToBottom() }
                }
                delay += 0.8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.5) {
                HapticManager.shared.playSelectionChanged()
                then()
                scrollToBottom()
            }
        }
    }
    
    private func scrollToBottom() {
        scrollToId = .bottomPadding
    }
    
    private func scrollToBottomAfterSend() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            scrollToBottom()
        }
    }
    
    private func triggerAppleSignIn() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.email, .fullName]
        let coordinator = AppleSignInCoordinator()
        coordinator.onComplete = { [self] result in
            DispatchQueue.main.async {
                handleAppleSignIn(result: result)
            }
        }
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = coordinator
        controller.presentationContextProvider = coordinator
        controller.performRequests()
        appleSignInCoordinator = coordinator
    }
    
    private func addUserBubble(_ text: String) {
        let msg = ChatMessage(sender: .user, text: text)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            messages.append(msg)
        }
        HapticManager.shared.playMediumImpact()
        scrollToBottomAfterSend()
    }
    
    private func advancePhase() {
        guard let next = OnboardingPhase(rawValue: phase.rawValue + 1) else {
            completeOnboarding()
            return
        }
        persistedStep = next.rawValue
        phase = next
        startOrResumeConversation()
    }
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                signInError = "Invalid credential type"
                return
            }
            let appleUserId = credential.user
            let email = credential.email
            let identityToken = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
            isSigningIn = true
            signInError = nil
            
            Task {
                do {
                    _ = try await apiClient.signIn(
                        appleUserId: appleUserId,
                        email: email,
                        identityToken: identityToken
                    )
                    await MainActor.run {
                        isSigningIn = false
                        HapticManager.shared.playSuccessNotification()
                        addUserBubble("Signed in")
                        messages.append(ChatMessage(sender: .retrospect, text: "Welcome aboard."))
                        advancePhase()
                    }
                } catch {
                    await MainActor.run {
                        isSigningIn = false
                        signInError = error.localizedDescription
                    }
                }
            }
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                signInError = error.localizedDescription
            }
        }
    }
    
    private func connectGoogleDocs() {
        isConnectingGoogle = true
        Task {
            do {
                try await googleDocsService.authenticate()
                await MainActor.run {
                    isConnectingGoogle = false
                    HapticManager.shared.playSuccessNotification()
                    messages.append(ChatMessage(sender: .retrospect, text: "Connected.", isSpecial: true))
                    advancePhase()
                }
            } catch {
                await MainActor.run {
                    isConnectingGoogle = false
                    googleError = "Failed to connect. Please try again."
                    autoFillInputBar(text: "Connect Google Docs", style: .default, showSkip: true)
                }
            }
        }
    }

    private func connectXBookmarks() {
        guard !isConnectingX else { return }
        isConnectingX = true
        Task {
            do {
                let bookmarkCount = try await xBookmarksService.connectAndInitialSync()
                await MainActor.run {
                    isConnectingX = false
                    HapticManager.shared.playSuccessNotification()
                    messages.append(ChatMessage(
                        sender: .retrospect,
                        text: "Connected. Imported \(bookmarkCount) recent bookmarks.",
                        isSpecial: true
                    ))
                    advancePhase()
                }
            } catch {
                await MainActor.run {
                    isConnectingX = false
                    messages.append(ChatMessage(
                        sender: .retrospect,
                        text: "Couldn't connect X right now. You can try again or skip for now."
                    ))
                    autoFillInputBar(text: "Connect X Bookmarks", style: .default, showSkip: true)
                }
            }
        }
    }
    
    private func requestHealthAccess() {
        isRequestingHealth = true
        HealthKitManager.shared.requestAuthorization { success in
            DispatchQueue.main.async {
                isRequestingHealth = false
                if success {
                    healthKitEnabled = true
                    HapticManager.shared.playSuccessNotification()
                    messages.append(ChatMessage(sender: .retrospect, text: "Health access enabled.", isSpecial: true))
                }
                advancePhase()
            }
        }
    }
    
    private func requestScreenTimeAccess() {
        isConnectingScreenTime = true
        Task {
            await screenTimeService.requestAuthorization()
            await MainActor.run {
                isConnectingScreenTime = false
                if screenTimeService.isAuthorized {
                    HapticManager.shared.playSuccessNotification()
                    messages.append(ChatMessage(sender: .retrospect, text: "Screen Time enabled. I'll start noticing your digital patterns.", isSpecial: true))
                } else if let error = screenTimeService.authorizationError {
                    messages.append(ChatMessage(sender: .retrospect, text: "Couldn't connect Screen Time: \(error). You can enable this later in Settings."))
                }
                advancePhase()
            }
        }
    }
    
    private func savePersonaAndAdvance(_ personaId: String) {
        voicePersona = personaId
        UserDefaults.standard.set(personaId, forKey: "voice_persona")
        isSavingPersona = true
        Task {
            if apiClient.isAuthenticated {
                do {
                    try await apiClient.setVoicePersona(personaId)
                } catch {
                    print("Persona sync failed: \(error.localizedDescription)")
                }
            }
            await MainActor.run {
                isSavingPersona = false
                let preview = personaPreviewText(personaId)
                messages.append(ChatMessage(sender: .retrospect, text: preview, isSpecial: true))
                advancePhase()
            }
        }
    }
    
    private func personaPreviewText(_ id: String) -> String {
        switch id {
        case "wise_mentor": return "Calm and grounded. I'll let insights land with weight."
        case "energetic_host": return "Dynamic and engaging. I'll celebrate your wins."
        default: return "Warm and conversational. Like catching up over coffee."
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.removeObject(forKey: "onboardingCurrentStep")
        goalsManager.syncToBackend()
        
        // Schedule recurring notifications now that onboarding is done
        Task {
            let granted = await PodcastNotificationService.shared.requestAuthorization()
            if granted {
                PodcastNotificationService.shared.scheduleAllRecurringNotifications()
            }
        }
        
        onComplete?()
    }
}

// MARK: - Word-by-Word Reveal (typing animation for incoming messages; runs once, then onComplete marks as done)

private struct TypingRevealText: View {
    let fullText: String
    let textColor: Color
    var onComplete: (() -> Void)? = nil
    let intervalPerWord: Double = 0.06
    
    @State private var revealedWordCount: Int = 0
    @State private var words: [String] = []
    @State private var hasCompleted: Bool = false
    
    var body: some View {
        let displayed = words.prefix(revealedWordCount).joined(separator: " ")
        Text(displayed)
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(textColor)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(2)
            .onAppear {
                guard !hasCompleted else { return }
                words = fullText.split(separator: " ", omittingEmptySubsequences: true)
                    .map { String($0) }
                guard !words.isEmpty else {
                    onComplete?()
                    return
                }
                for index in 1...words.count {
                    DispatchQueue.main.asyncAfter(deadline: .now() + intervalPerWord * Double(index)) {
                        guard !hasCompleted else { return }
                        revealedWordCount = index
                        if index == words.count {
                            hasCompleted = true
                            onComplete?()
                        }
                    }
                }
            }
    }
}

// MARK: - Chat Bubble View

private struct ChatBubbleView: View {
    let message: ChatMessage
    let animationCompleted: Bool
    let onAnimationComplete: () -> Void
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.sender == .user { Spacer(minLength: 60) }
            bubbleContent
            if message.sender == .retrospect { Spacer(minLength: 60) }
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.96).combined(with: .move(edge: .bottom))),
            removal: .opacity
        ))
    }
    
    private var bubbleContent: some View {
        HStack(alignment: .center, spacing: 6) {
            if message.sender == .retrospect && message.isSpecial {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(LinearColors.Minimal.success)
            }
            if message.sender == .retrospect && !message.isSpecial {
                if animationCompleted {
                    Text(message.text)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                } else {
                    TypingRevealText(
                        fullText: message.text,
                        textColor: LinearColors.Minimal.textPrimary,
                        onComplete: onAnimationComplete
                    )
                }
            } else {
                Text(message.text)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(message.sender == .user ? iMessageBubble.outgoingText : LinearColors.Minimal.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(bubbleBackground)
    }
    
    @ViewBuilder private var bubbleBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(message.sender == .user ? iMessageBubble.outgoing : iMessageBubble.incoming)
    }
}

// MARK: - Persona Card Stack (voice persona selection in message area)

private struct PersonaCardStack: View {
    let onSelect: (String) -> Void
    
    private let personas: [(id: String, name: String, icon: String, description: String, sample: String)] = [
        ("thoughtful_friend", "Thoughtful Friend", "cup.and.saucer", "Warm and curious. Like catching up over coffee.", "I noticed something interesting in what you shared this week..."),
        ("wise_mentor", "Wise Mentor", "graduationcap", "Calm and grounded. Insights that land with weight.", "Let's look at what's really driving this pattern..."),
        ("energetic_host", "Energetic Host", "bolt", "Dynamic and direct. Celebrates wins, challenges comfort zones.", "Okay, let's talk about that breakthrough moment!"),
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(personas, id: \.id) { p in
                Button(action: { onSelect(p.id) }) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: p.icon)
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(LinearColors.Minimal.accent)
                                .frame(width: 32, alignment: .center)
                            Text(p.name)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                        }
                        Text(p.description)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textSecondary)
                        Text(p.sample)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .italic()
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearColors.Minimal.backgroundCard)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(LinearColors.Minimal.border, lineWidth: 0.5)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Variable Blur (progressive blur toward bottom, iMessage-style)

private struct VariableBlurView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        let blur = UIBlurEffect(style: .systemThinMaterialDark)
        let view = UIVisualEffectView(effect: blur)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let gradient = CAGradientLayer()
        gradient.colors = [UIColor.clear.cgColor, UIColor.white.cgColor]
        gradient.locations = [0, 1]
        view.layer.mask = gradient
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        guard let mask = uiView.layer.mask as? CAGradientLayer else { return }
        mask.frame = uiView.bounds
    }
}

// MARK: - Apple Sign-In Coordinator (programmatic ASAuthorizationController)

private class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var onComplete: ((Result<ASAuthorization, Error>) -> Void)?
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        onComplete?(.success(authorization))
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onComplete?(.failure(error))
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? UIWindow()
        }
        return window
    }
}

// MARK: - Typing Indicator

private struct TypingIndicatorView: View {
    @State private var animating = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(LinearColors.Minimal.textTertiary)
                        .frame(width: 6, height: 6)
                        .offset(y: animating ? -4 : 0)
                        .animation(
                            .easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(iMessageBubble.incoming)
            )
            Spacer(minLength: 60)
        }
        .onAppear { animating = true }
    }
}

#Preview {
    iMessageOnboardingView(onComplete: {})
}
