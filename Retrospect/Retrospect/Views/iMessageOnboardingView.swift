//
//  iMessageOnboardingView.swift
//  Retrospect
//
//  Rebuilt iMessage-style onboarding. State lives in OnboardingState (ObservableObject)
//  owned by DarkOnboardingFlow so it survives view recreation.
//  Sign-in happens on WelcomeSignInPage before this view is shown.
//

import SwiftUI
import Combine

// MARK: - Color aliases

private enum iMessageBubble {
    static let incoming = LinearColors.Minimal.chatBubbleIncoming
    static let outgoing = LinearColors.Minimal.chatBubbleOutgoing
    static let outgoingText = LinearColors.Minimal.chatBubbleOutgoingText
}

// MARK: - Scroll target

private enum ScrollTarget: Hashable {
    case message(UUID)
    case typing
    case bottomPadding
}

// MARK: - iMessageOnboardingView

struct iMessageOnboardingView: View {
    @ObservedObject var state: OnboardingState
    var onComplete: (() -> Void)?

    // MARK: View-local UI state (safe to lose on recreation)

    @State private var scrollTrigger: Int = 0
    @State private var inputBarText: String = ""
    @FocusState private var isInputFocused: Bool

    @StateObject private var onboardingAudioManager = AudioRecordingManager()

    @StateObject private var apiClient = RetrospectAPIClient.shared
    @StateObject private var googleDocsService = GoogleDocsService.shared
    @StateObject private var screenTimeService = ScreenTimeService.shared
    @StateObject private var goalsManager = GoalsManager.shared
    @AppStorage("healthKitEnabled") private var healthKitEnabled = false
    @AppStorage("voice_persona") private var voicePersona: String = "thoughtful_friend"

    // MARK: Body

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                contactHeader

                ZStack(alignment: .bottomTrailing) {
                    ZStack(alignment: .bottom) {
                        scrollArea
                        blurOverlay
                    }
                    scrollToBottomButton
                }

                bottomBar
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: onFirstAppear)
        .onReceive(keyboardWillShowPublisher) { info in
            if let frame = info.frame, let duration = info.duration {
                withAnimation(.easeOut(duration: duration)) {
                    state.keyboardHeight = frame.height
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
                    scrollToBottom()
                }
            }
        }
        .onReceive(keyboardWillHidePublisher) { info in
            let duration = info.duration ?? 0.25
            withAnimation(.easeOut(duration: duration)) {
                state.keyboardHeight = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) {
                scrollToBottom()
            }
        }
        .alert("Connection Error", isPresented: Binding(
            get: { state.googleError != nil },
            set: { if !$0 { state.googleError = nil } }
        )) {
            Button("OK") { state.googleError = nil }
        } message: {
            if let err = state.googleError { Text(err) }
        }
    }

    // MARK: - First Appear

    private func onFirstAppear() {
        guard !state.hasStartedConversation else { return }
        state.hasStartedConversation = true
        state.replayMessagesForPhase()
        startOrResumeConversation()
    }

    // MARK: - Keyboard publishers

    private struct KeyboardInfo {
        var frame: CGRect?
        var duration: Double?
    }

    private var keyboardWillShowPublisher: AnyPublisher<KeyboardInfo, Never> {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { notification in
                KeyboardInfo(
                    frame: notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                    duration: notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
                )
            }
            .eraseToAnyPublisher()
    }

    private var keyboardWillHidePublisher: AnyPublisher<KeyboardInfo, Never> {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { notification in
                KeyboardInfo(
                    frame: nil,
                    duration: notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
                )
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            LinearColors.Minimal.background
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.clear,
                    LinearColors.Minimal.background.opacity(0.3),
                    LinearColors.Minimal.background.opacity(0.5),
                    LinearColors.Minimal.background.opacity(0.7)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Scroll Area

    private var scrollArea: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Spacer(minLength: 0)
                        .frame(minHeight: 20)

                    ForEach(state.messages) { msg in
                        ChatBubbleView(
                            message: msg,
                            animationCompleted: state.completedAnimationIds.contains(msg.id),
                            onAnimationComplete: { state.completedAnimationIds.insert(msg.id) }
                        )
                        .id(ScrollTarget.message(msg.id))
                    }

                    if state.showTypingIndicator {
                        TypingIndicatorView()
                            .id(ScrollTarget.typing)
                    }

                    if state.phase == .voicePersona && state.showActionButton {
                        PersonaCardStack(onSelect: { personaId in
                            let name = state.personaDisplayName(personaId)
                            inputBarText = name
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                state.addUserBubble(name)
                                scrollToBottomAfterSend()
                                savePersonaAndAdvance(personaId)
                            }
                        })
                    }

                    if state.phase == .integrations && state.showActionButton {
                        IntegrationCardStack(
                            googleConnected: googleDocsService.isConnected,
                            healthConnected: healthKitEnabled,
                            screenTimeConnected: screenTimeService.isAuthorized,
                            isConnectingGoogle: state.isConnectingGoogle,
                            isRequestingHealth: state.isRequestingHealth,
                            isConnectingScreenTime: state.isConnectingScreenTime,
                            onConnectGoogle: { connectGoogleDocs() },
                            onConnectHealth: { requestHealthAccess() },
                            onConnectScreenTime: { requestScreenTimeAccess() }
                        )
                    }

                    Color.clear
                        .frame(height: state.keyboardHeight > 0
                            ? OnboardingState.scrollBottomPaddingWithKeyboard
                            : OnboardingState.scrollBottomPadding)
                        .id(ScrollTarget.bottomPadding)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: scrollTrigger) { _, _ in
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(ScrollTarget.bottomPadding, anchor: .bottom)
                    }
                }
            }
            .onChange(of: state.messages.count) { _, _ in
                scrollToBottom()
            }
            .onChange(of: state.showTypingIndicator) { _, _ in
                scrollToBottom()
            }
        }
    }

    // MARK: - Blur overlay

    private var blurOverlay: some View {
        ZStack(alignment: .bottom) {
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
    }

    // MARK: - Scroll-to-bottom button

    @ViewBuilder
    private var scrollToBottomButton: some View {
        if state.messages.count >= 4 || state.showTypingIndicator {
            Button(action: {
                HapticManager.shared.playLightImpact()
                scrollToBottom()
            }) {
                Image(systemName: "chevron.down.circle.fill")
                    .font(.generalSans(size: 28, weight: .regular))
                    .foregroundStyle(LinearColors.Minimal.textPrimary.opacity(0.9))
                    .shadow(color: LinearColors.Minimal.shadowLight, radius: 2, x: 0, y: 1)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Contact Header (back button only)

    private var contactHeader: some View {
        HStack(spacing: 0) {
            if state.phase.rawValue > OnboardingPhase.integrations.rawValue && !state.isBusyWithAction {
                Button(action: { goBackPhase() }) {
                    Image(systemName: "chevron.left")
                        .font(.generalSans(size: 16, weight: .medium))
                        .foregroundColor(LinearColors.Minimal.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(LinearColors.Minimal.chatBarBackground)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            if state.phase == .closing {
                pullUpToEnterBar
            } else {
                inputBar

                if state.phase == .integrations && state.showActionButton {
                    Button("Skip all") {
                        state.addUserBubble("Skip for now")
                        scrollToBottomAfterSend()
                        appendSkipIntegrationsAcknowledgment()
                        advancePhase()
                    }
                    .font(.generalSans(size: 14, weight: .regular))
                    .foregroundColor(LinearColors.Minimal.textTertiary)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                } else if state.phase == .goals {
                    Button("or skip") {
                        state.addUserBubble("Skip for now")
                        scrollToBottomAfterSend()
                        let msg = ChatMessage(sender: .retrospect, text: "You can always set goals later.")
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            state.messages.append(msg)
                        }
                        scrollToBottomAfterSend()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            state.phase = .closing
                            state.persistPhase()
                            startOrResumeConversation()
                        }
                    }
                    .font(.generalSans(size: 14, weight: .regular))
                    .foregroundColor(LinearColors.Minimal.textTertiary)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                } else if state.showSkipLink {
                    Button("or skip") {
                        state.addUserBubble("Skip for now")
                        scrollToBottomAfterSend()
                        advancePhase()
                    }
                    .font(.generalSans(size: 14, weight: .regular))
                    .foregroundColor(LinearColors.Minimal.textTertiary)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                }
            }
        }
        .background(LinearColors.Minimal.chatBarBackground)
    }

    // MARK: - Input Bar

    @ViewBuilder
    private var inputBar: some View {
        if state.phase == .integrations && state.showActionButton {
            actionPillButton
        } else {
            regularInputBar
        }
    }

    // MARK: Action Pill (integrations continue)

    private var actionPillButton: some View {
        HStack {
            Spacer(minLength: 20)
            Button(action: actionForCurrentPhase) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.right")
                        .font(.generalSans(size: 20, weight: .medium))
                    Text("Continue")
                        .font(.generalSans(size: 17, weight: .medium))
                }
                .foregroundColor(LinearColors.Minimal.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: BorderRadius.button)
                        .fill(LinearColors.Minimal.inputBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BorderRadius.button)
                        .strokeBorder(LinearColors.Minimal.border.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            Spacer(minLength: 20)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(LinearColors.Minimal.chatBarBackground)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.95)),
            removal: .opacity.combined(with: .scale(scale: 0.95))
        ))
    }

    // MARK: Regular Input Bar

    private var regularInputBar: some View {
        let isAutoFillActive = state.isAutoFillLocked && !inputBarText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return HStack(alignment: .center, spacing: 12) {
            TextField("Share with Retrospect...", text: $inputBarText)
                .font(.generalSans(size: 17, weight: .regular))
                .foregroundColor(LinearColors.Minimal.textPrimary)
                .focused($isInputFocused)
                .submitLabel(.send)
                .onSubmit { sendInputBarMessage() }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: BorderRadius.button)
                        .fill(LinearColors.Minimal.inputBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BorderRadius.button)
                        .strokeBorder(
                            isAutoFillActive ? LinearColors.Minimal.accent.opacity(0.4) : Color.clear,
                            lineWidth: isAutoFillActive ? 1.5 : 0
                        )
                )

            if state.phase == .goals {
                VStack(spacing: 2) {
                    Button(action: { toggleVoiceRecording() }) {
                        Image(systemName: onboardingAudioManager.isRecording ? "mic.fill" : "mic")
                            .font(.generalSans(size: 20, weight: .medium))
                            .foregroundColor(onboardingAudioManager.isRecording ? Color.red : LinearColors.Minimal.textTertiary)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Text("Tap to speak")
                        .font(.generalSans(size: 10, weight: .medium))
                        .foregroundColor(LinearColors.Minimal.textTertiary)
                }
            } else {
                Button(action: { sendInputBarMessage() }) {
                    Group {
                        switch state.sendButtonOverride {
                        case .default:
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.generalSans(size: 24, weight: .medium))
                        case .sparkle:
                            Image(systemName: "sparkles")
                                .font(.generalSans(size: 18, weight: .medium))
                        }
                    }
                    .foregroundStyle(
                        state.sendButtonOverride == .sparkle || !inputBarText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? LinearColors.Minimal.textPrimary
                        : LinearColors.Minimal.textTertiary
                    )
                }
                .disabled(state.sendButtonOverride == .default && inputBarText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(LinearColors.Minimal.chatBarBackground)
    }

    // MARK: Pull-up-to-enter bar

    private var pullUpToEnterBar: some View {
        let progress = min(1.0, state.pullToEnterOffset / OnboardingState.pullToEnterThreshold)
        let atOrOverThreshold = state.pullToEnterOffset >= OnboardingState.pullToEnterThreshold

        return VStack(spacing: 12) {
            Button(action: {
                SpringHapticController.shared.triggerSuccessHaptic()
                completeOnboarding()
            }) {
                Text("Start Journaling")
                    .font(.generalSans(size: 17, weight: .semibold))
                    .foregroundColor(LinearColors.Minimal.buttonPrimaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: BorderRadius.button)
                            .fill(LinearColors.Minimal.accent)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 20)

            RoundedRectangle(cornerRadius: BorderRadius.button)
                .fill(LinearColors.Minimal.textTertiary.opacity(atOrOverThreshold ? 0.7 : 0.3))
                .frame(width: 36, height: 4)
                .padding(.bottom, 4)
                .scaleEffect(atOrOverThreshold ? 1.08 : 1.0)

            Text(atOrOverThreshold ? "Release to start" : "Pull up to start")
                .font(.generalSans(size: 15, weight: .medium))
                .foregroundColor(atOrOverThreshold ? LinearColors.Minimal.textPrimary : LinearColors.Minimal.textSecondary)

            Image(systemName: atOrOverThreshold ? "checkmark.circle.fill" : "chevron.up")
                .font(.generalSans(size: atOrOverThreshold ? 18 : 14, weight: .semibold))
                .foregroundColor(atOrOverThreshold ? LinearColors.Minimal.accent : LinearColors.Minimal.textTertiary)
                .scaleEffect(1.0 + progress * 0.15)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .offset(y: -state.pullToEnterOffset * 0.3)
        .animation(.easeOut(duration: 0.25), value: atOrOverThreshold)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let pullUp = max(0, -value.translation.height)
                    let stretched = min(pullUp, OnboardingState.pullToEnterMaxStretch)
                    state.pullToEnterOffset = stretched

                    if stretched > 0 && !state.pullGestureDidPrepare {
                        SpringHapticController.shared.prepare()
                        SpringHapticController.shared.reset()
                        state.pullGestureDidPrepare = true
                    }
                    if stretched > 0 {
                        SpringHapticController.shared.triggerSpringHaptic(
                            pullDistance: stretched,
                            maxDistance: kSpringHapticMaxPullDistance
                        )
                    }
                }
                .onEnded { value in
                    let pullUp = max(0, -value.translation.height)
                    SpringHapticController.shared.reset()
                    state.pullGestureDidPrepare = false

                    if pullUp >= OnboardingState.pullToEnterThreshold {
                        SpringHapticController.shared.triggerSuccessHaptic()
                        completeOnboarding()
                    } else {
                        SpringHapticController.shared.triggerSnapBack()
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                            state.pullToEnterOffset = 0
                        }
                    }
                }
        )
    }

    // MARK: - Actions

    private func actionForCurrentPhase() {
        HapticManager.shared.playMediumImpact()
        switch state.phase {
        case .integrations:
            state.addUserBubble("Continue")
            scrollToBottomAfterSend()
            state.showActionButton = false
            let anyConnected = googleDocsService.isConnected || healthKitEnabled || screenTimeService.isAuthorized
            if !anyConnected {
                appendSkipIntegrationsAcknowledgment()
            }
            advancePhase()
        default:
            break
        }
    }

    private func appendSkipIntegrationsAcknowledgment() {
        let msg = ChatMessage(sender: .retrospect, text: "No worries — you can connect these anytime in Settings.")
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            state.messages.append(msg)
        }
        scrollToBottomAfterSend()
    }

    // MARK: - Send input

    private func sendInputBarMessage() {
        let trimmed = inputBarText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputBarText = ""
        state.isAutoFillLocked = false
        state.showSkipLink = false
        state.sendButtonOverride = .default
        state.addUserBubble(trimmed)
        scrollToBottomAfterSend()
        HapticManager.shared.playMediumImpact()

        switch state.phase {
        case .integrations:
            break
        case .voicePersona:
            break
        case .goals:
            if state.goalsTurn == 4 {
                for g in state.extractedGoalsFromConversation {
                    goalsManager.addGoal(g)
                }
                if !trimmed.lowercased().contains("perfect") && trimmed.count > 2 {
                    goalsManager.addGoal(trimmed)
                }
                HapticManager.shared.playSuccessNotification()
                state.phase = .closing
                state.persistPhase()
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

    // MARK: - Voice recording

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

    // MARK: - Auto-fill input bar

    private func autoFillInputBar(text: String, style: SendButtonStyle, showSkip: Bool) {
        state.isAutoFillLocked = true
        state.sendButtonOverride = style
        state.showSkipLink = showSkip
        inputBarText = ""
        let intervalPerChar: Double = 0.03
        let characters = Array(text)
        for (index, _) in characters.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + intervalPerChar * Double(index)) { [self] in
                guard state.isAutoFillLocked else { return }
                if index < inputBarText.count { return }
                inputBarText = String(characters.prefix(index + 1))
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + intervalPerChar * Double(characters.count) + 0.1) {
            scrollToBottom()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + intervalPerChar * Double(characters.count) + 0.6) {
            scrollToBottom()
        }
    }

    // MARK: - Conversation Engine

    private func startOrResumeConversation() {
        state.showTypingIndicator = false
        state.showSkipLink = false
        state.sendButtonOverride = .default
        state.isAutoFillLocked = false
        state.showActionButton = false

        switch state.phase {
        case .integrations:
            deliverMessageGroup(state.scriptMessages(for: .integrations), typingDuration: 0.8) {
                showActionButtonAfterMessages()
            }
        case .voicePersona:
            inputBarText = ""
            deliverMessageGroup(state.scriptMessages(for: .voicePersona), typingDuration: 0.8) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    state.showActionButton = true
                }
            }
        case .goals:
            state.goalsTurn = 1
            state.goalTurn1Text = ""
            state.goalTurn2Text = ""
            state.goalTurn2BotMessage = ""
            inputBarText = ""
            deliverMessageGroup(state.goalsIntroMessages(), typingDuration: 0.6) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isInputFocused = true
                }
            }
        case .closing:
            deliverMessageGroup(state.scriptMessages(for: .closing), typingDuration: 1.0) {
                state.pullToEnterOffset = 0
                state.pullGestureDidPrepare = false
            }
        }
    }

    private func deliverMessageGroup(_ group: [ChatMessage], typingDuration: Double, then: @escaping () -> Void) {
        let existingTexts = Set(state.messages.map { "\($0.sender):\($0.text)" })
        let toAppend = group.filter { !existingTexts.contains("\($0.sender):\($0.text)") }
        guard !toAppend.isEmpty else {
            then()
            return
        }

        state.showTypingIndicator = true
        scrollToBottom()

        DispatchQueue.main.asyncAfter(deadline: .now() + typingDuration) {
            state.showTypingIndicator = false
            scrollToBottom()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                var delay: Double = 0
                for msg in toAppend {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            state.messages.append(msg)
                        }
                        HapticManager.shared.playSoftImpact()
                    }
                    delay += OnboardingState.messageUnblurDuration
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.35) {
                    scrollToBottom()
                    HapticManager.shared.playSelectionChanged()
                    then()
                }
            }
        }
    }

    private func showActionButtonAfterMessages() {
        let totalDelay = OnboardingState.messageUnblurDuration + 0.2
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                state.showActionButton = true
            }
            HapticManager.shared.playSelectionChanged()
        }
    }

    private func advancePhase() {
        guard let next = OnboardingPhase(rawValue: state.phase.rawValue + 1) else {
            completeOnboarding()
            return
        }
        state.phase = next
        state.persistPhase()
        startOrResumeConversation()
    }

    private func goBackPhase() {
        guard state.phase.rawValue > OnboardingPhase.integrations.rawValue,
              !state.isBusyWithAction,
              let prev = OnboardingPhase(rawValue: state.phase.rawValue - 1) else { return }
        HapticManager.shared.playLightImpact()
        state.phase = prev
        state.persistPhase()
        state.replayMessagesForPhase()
        startOrResumeConversation()
    }

    private func scrollToBottom() {
        scrollTrigger += 1
    }

    private func scrollToBottomAfterSend() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            scrollToBottom()
        }
    }

    // MARK: - Integrations

    private func connectGoogleDocs() {
        state.isConnectingGoogle = true
        Task {
            do {
                try await googleDocsService.authenticate()
                await MainActor.run {
                    state.isConnectingGoogle = false
                    HapticManager.shared.playSuccessNotification()
                    state.messages.append(ChatMessage(sender: .retrospect, text: "Connected.", isSpecial: true))
                    if state.phase != .integrations { advancePhase() }
                    else { scrollToBottomAfterSend() }
                }
            } catch {
                await MainActor.run {
                    state.isConnectingGoogle = false
                    state.googleError = "Failed to connect. Please try again."
                    state.showActionButton = true
                }
            }
        }
    }

    private func requestHealthAccess() {
        state.isRequestingHealth = true
        HealthKitManager.shared.requestAuthorization { success in
            DispatchQueue.main.async {
                state.isRequestingHealth = false
                if success {
                    healthKitEnabled = true
                    HapticManager.shared.playSuccessNotification()
                    state.messages.append(ChatMessage(sender: .retrospect, text: "Health access enabled.", isSpecial: true))
                    if state.phase != .integrations { advancePhase() }
                    else { scrollToBottomAfterSend() }
                } else if state.phase != .integrations {
                    advancePhase()
                }
            }
        }
    }

    private func requestScreenTimeAccess() {
        state.isConnectingScreenTime = true
        Task {
            await screenTimeService.requestAuthorization()
            await MainActor.run {
                state.isConnectingScreenTime = false
                if screenTimeService.isAuthorized {
                    HapticManager.shared.playSuccessNotification()
                    screenTimeService.startRetroactiveBackfill()
                    state.messages.append(ChatMessage(sender: .retrospect, text: "Screen Time enabled. I'll start noticing your digital patterns.", isSpecial: true))
                    if state.phase != .integrations { advancePhase() }
                    else { scrollToBottomAfterSend() }
                } else {
                    if let error = screenTimeService.authorizationError {
                        state.messages.append(ChatMessage(sender: .retrospect, text: "Couldn't connect Screen Time: \(error). You can enable this later in Settings."))
                    }
                    if state.phase != .integrations { advancePhase() }
                    else { scrollToBottomAfterSend() }
                }
            }
        }
    }

    // MARK: - Goals

    private func handleGoalsTurnResponse(_ text: String) {
        switch state.goalsTurn {
        case 1:
            state.goalTurn1Text = text
            state.goalsTurn = 2
            fetchGoalsReplyAndAppend(
                messages: [
                    ["role": "assistant", "content": OnboardingState.goalsFirstQuestion],
                    ["role": "user", "content": text]
                ],
                fallback: state.fallbackGoalsReplyForTurn(2),
                storeIn: { state.goalTurn2BotMessage = $0 }
            )
        case 2:
            state.goalTurn2Text = text
            state.goalsTurn = 4
            extractGoalsWithClaude()
        default:
            break
        }
    }

    private func fetchGoalsReplyAndAppend(messages apiMessages: [[String: Any]], fallback: String, storeIn: @escaping (String) -> Void) {
        state.showTypingIndicator = true
        state.isLoadingGoalsReply = true
        scrollToBottom()

        let conversation: [OnboardingChatMessage] = apiMessages.compactMap { dict in
            guard let role = dict["role"] as? String,
                  let content = dict["content"] as? String else { return nil }
            return OnboardingChatMessage(role: role, content: content)
        }

        Task {
            let replyText: String
            do {
                replyText = try await apiClient.onboardingGoalsReply(conversation: conversation)
            } catch {
                replyText = fallback
            }
            await MainActor.run {
                state.showTypingIndicator = false
                state.isLoadingGoalsReply = false
                storeIn(replyText)
                let msg = ChatMessage(sender: .retrospect, text: replyText)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    state.messages.append(msg)
                }
                HapticManager.shared.playSoftImpact()
                scrollToBottomAfterSend()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    isInputFocused = true
                }
            }
        }
    }

    private func extractGoalsWithClaude() {
        state.showTypingIndicator = true
        state.isLoadingGoalsReply = true
        scrollToBottom()

        let conversation: [OnboardingChatMessage] = [
            OnboardingChatMessage(role: "assistant", content: OnboardingState.goalsFirstQuestion),
            OnboardingChatMessage(role: "user", content: state.goalTurn1Text),
            OnboardingChatMessage(role: "assistant", content: state.goalTurn2BotMessage.isEmpty ? state.fallbackGoalsReplyForTurn(2) : state.goalTurn2BotMessage),
            OnboardingChatMessage(role: "user", content: state.goalTurn2Text)
        ]

        // Don't persist yet — onboarding completion does the final write.
        // Here we just want the titles so the user can confirm them.
        Task {
            let goalTitles: [String]
            do {
                let extracted = try await apiClient.onboardingGoalsExtract(conversation: conversation, persist: false)
                goalTitles = extracted.map { $0.title }
            } catch {
                goalTitles = state.extractGoalsFromTurnsFallback()
            }
            await MainActor.run {
                state.showTypingIndicator = false
                state.isLoadingGoalsReply = false
                state.extractedGoalsFromConversation = goalTitles
                let list = goalTitles.prefix(3).joined(separator: ", ")
                let summaryMessage = goalTitles.isEmpty
                    ? "Got it. Let's get started."
                    : "From what you've told me, it sounds like your focus areas are: \(list). Sound right?"
                let msg = ChatMessage(sender: .retrospect, text: summaryMessage)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    state.messages.append(msg)
                }
                HapticManager.shared.playSoftImpact()
                scrollToBottomAfterSend()
                autoFillInputBar(text: "That's perfect", style: .default, showSkip: false)
            }
        }
    }

    // MARK: - Persona

    private func savePersonaAndAdvance(_ personaId: String) {
        voicePersona = personaId
        UserDefaults.standard.set(personaId, forKey: "voice_persona")
        state.isSavingPersona = true
        Task {
            if apiClient.isAuthenticated {
                do {
                    try await apiClient.setVoicePersona(personaId)
                } catch {
                    print("Persona sync failed: \(error.localizedDescription)")
                }
            }
            await MainActor.run {
                state.isSavingPersona = false
                let preview = state.personaPreviewText(personaId)
                state.messages.append(ChatMessage(sender: .retrospect, text: preview, isSpecial: true))
                scrollToBottomAfterSend()
                advancePhase()
            }
        }
    }

    // MARK: - Complete

    private func completeOnboarding() {
        state.clearPersistedStep()
        goalsManager.syncToBackend()

        Task {
            let granted = await PodcastNotificationService.shared.requestAuthorization()
            if granted {
                PodcastNotificationService.shared.scheduleAllRecurringNotifications()
            }
        }

        onComplete?()
    }
}

// MARK: - Unblur Text Reveal

private struct TypingRevealText: View {
    let fullText: String
    let textColor: Color
    var onComplete: (() -> Void)? = nil

    private static let unblurDuration: Double = 0.7

    @State private var blurRadius: CGFloat = 20
    @State private var opacity: Double = 0.3
    @State private var hasCompleted: Bool = false

    var body: some View {
        Text(fullText)
            .font(.sentient(size: 17, weight: .regular))
            .foregroundColor(textColor)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(6)
            .blur(radius: blurRadius)
            .opacity(opacity)
            .onAppear {
                guard !hasCompleted else { return }
                hasCompleted = true

                withAnimation(.easeOut(duration: Self.unblurDuration)) {
                    blurRadius = 0
                    opacity = 1.0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + Self.unblurDuration) {
                    onComplete?()
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
        if message.sender == .retrospect {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    if message.isSpecial {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.generalSans(size: 14, weight: .regular))
                                .foregroundColor(LinearColors.Minimal.success)
                        }
                        .padding(.bottom, 2)
                    }
                    if animationCompleted {
                        Text(message.text)
                            .font(.sentient(size: 17, weight: .regular))
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(6)
                    } else {
                        TypingRevealText(
                            fullText: message.text,
                            textColor: LinearColors.Minimal.textPrimary,
                            onComplete: onAnimationComplete
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 60)
            }
            .padding(.vertical, 4)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .bottom)),
                removal: .opacity
            ))
        } else {
            HStack(alignment: .bottom, spacing: 8) {
                Spacer(minLength: 60)
                HStack(alignment: .center, spacing: 0) {
                    Text(message.text)
                        .font(.generalSans(size: 16, weight: .regular))
                        .foregroundColor(iMessageBubble.outgoingText)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: BorderRadius.button)
                        .fill(iMessageBubble.outgoing)
                )
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.96).combined(with: .move(edge: .bottom))),
                removal: .opacity
            ))
        }
    }
}

// MARK: - Persona Card Stack

private struct PersonaCardStack: View {
    let onSelect: (String) -> Void

    private let personas: [(id: String, name: String, icon: String, description: String, detail: String)] = [
        ("thoughtful_friend", "Thoughtful Friend", "cup.and.saucer", "Warm and curious", "Like catching up over coffee; gentle and reflective."),
        ("wise_mentor", "Wise Mentor", "graduationcap", "Calm and grounded", "Thoughtful and steady; good for big-picture reflection."),
        ("energetic_host", "Energetic Host", "bolt", "Dynamic and direct", "Upbeat and motivating; great for energy and momentum."),
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(personas, id: \.id) { p in
                Button(action: { onSelect(p.id) }) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: p.icon)
                            .font(.generalSans(size: 18, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.accent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(p.name)
                                .font(.generalSans(size: 16, weight: .medium))
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                            Text(p.description)
                                .font(.generalSans(size: 14, weight: .regular))
                                .foregroundColor(LinearColors.Minimal.textSecondary)
                            Text(p.detail)
                                .font(.generalSans(size: 13, weight: .regular))
                                .foregroundColor(LinearColors.Minimal.textTertiary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: BorderRadius.button)
                            .fill(LinearColors.Minimal.backgroundCard)
                            .overlay(
                                RoundedRectangle(cornerRadius: BorderRadius.button)
                                    .strokeBorder(LinearColors.Minimal.border.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 8)
    }
}

// MARK: - Integration Card Stack

private struct IntegrationCardStack: View {
    let googleConnected: Bool
    let healthConnected: Bool
    let screenTimeConnected: Bool
    let isConnectingGoogle: Bool
    let isRequestingHealth: Bool
    let isConnectingScreenTime: Bool
    let onConnectGoogle: () -> Void
    let onConnectHealth: () -> Void
    let onConnectScreenTime: () -> Void

    private let rows: [(id: String, icon: String, title: String, subtitle: String)] = [
        ("google", "doc.text.fill", "Google Docs", "Your notes and docs"),
        ("health", "heart.fill", "Apple Health", "Sleep, activity, mindfulness"),
        ("screentime", "chart.bar.fill", "Screen Time", "App usage patterns"),
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows, id: \.id) { row in
                let (connected, loading) = stateFor(row.id)
                Button(action: { actionFor(row.id)() }) {
                    HStack(spacing: 12) {
                        Image(systemName: row.icon)
                            .font(.generalSans(size: 18, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.accent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                                .font(.generalSans(size: 16, weight: .medium))
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                            Text(row.subtitle)
                                .font(.generalSans(size: 14, weight: .regular))
                                .foregroundColor(LinearColors.Minimal.textSecondary)
                        }
                        Spacer()
                        if loading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: LinearColors.Minimal.textTertiary))
                                .scaleEffect(0.8)
                        } else if connected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.generalSans(size: 20, weight: .medium))
                                .foregroundColor(LinearColors.Minimal.success)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: BorderRadius.button)
                            .fill(LinearColors.Minimal.backgroundCard)
                            .overlay(
                                RoundedRectangle(cornerRadius: BorderRadius.button)
                                    .strokeBorder(LinearColors.Minimal.border.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(loading || connected)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func stateFor(_ id: String) -> (connected: Bool, loading: Bool) {
        switch id {
        case "google": return (googleConnected, isConnectingGoogle)
        case "health": return (healthConnected, isRequestingHealth)
        case "screentime": return (screenTimeConnected, isConnectingScreenTime)
        default: return (false, false)
        }
    }

    private func actionFor(_ id: String) -> () -> Void {
        switch id {
        case "google": return onConnectGoogle
        case "health": return onConnectHealth
        case "screentime": return onConnectScreenTime
        default: return {}
        }
    }
}

// MARK: - Variable Blur

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

// MARK: - Typing Indicator

private struct TypingIndicatorView: View {
    @State private var animating = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
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
            .padding(.vertical, 8)
            Spacer(minLength: 60)
        }
        .onAppear { animating = true }
    }
}

// MARK: - Preview

#Preview {
    DarkOnboardingFlow(onComplete: {})
}
