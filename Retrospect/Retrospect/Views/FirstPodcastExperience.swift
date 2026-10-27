//
//  FirstPodcastExperience.swift
//  Retrospect
//
//  The end-of-onboarding finale, as one self-contained sequence:
//    learning ritual  →  first podcast + paywall  →  post-podcast reflection  →  done
//
//  Generation runs while the learning ritual plays (masking the cook). Every
//  exit — finishing the podcast OR backing out of the paywall — funnels through
//  a single `onComplete`, which the app uses to drop the user on the home screen.
//

import SwiftUI

struct FirstPodcastExperience: View {
    /// The generated episode (ready by the time the ritual finishes).
    let transcript: String
    let audioURL: URL?
    /// Gates the ritual's grand dissolve — it won't finish until the podcast exists.
    var podcastReady: Bool
    /// Fired once when the whole finale is over (any path) → go home.
    var onComplete: () -> Void
    /// DEBUG-only: show stage-skip controls so the finale can be walked without
    /// real audio / a real subscription.
    var debugControls: Bool = false
    var startAtPaywall: Bool = false

    private enum Stage { case learning, podcast, reflection }
    @State private var stage: Stage = .learning

    private let cream = Color(red: 0.929, green: 0.918, blue: 0.886)

    /// Generation can come back with nothing to read or play (the agent pipeline
    /// failed, or returned an empty episode). The player has no exit of its own in
    /// release builds, so entering it empty would strand the user.
    private var hasEpisode: Bool {
        audioURL != nil || !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            cream.ignoresSafeArea()

            switch stage {
            case .learning:
                LearningAboutYouView(podcastReady: podcastReady) {
                    if hasEpisode {
                        advance(to: .podcast)
                    } else {
                        onComplete()
                    }
                }
                .transition(.opacity)

            case .podcast:
                PodcastPaywallFlow(
                    audioURL: audioURL,
                    transcript: transcript,
                    onClose: { onComplete() }, // backed out without subscribing → home
                    onFinished: { advance(to: .reflection) }, // subscribed + finished → reflect
                    startWithPaywall: startAtPaywall,
                    onDebugGoHome: onComplete
                )
                .transition(.opacity)

            case .reflection:
                FirstReflectionView(
                    onSubmit: { text in saveReflection(text); onComplete() },
                    onSkip: { onComplete() }
                )
                .transition(.opacity)
            }

            #if DEBUG
            if debugControls {
                VStack {
                    Spacer()
                    Button("skip stage →") {
                        switch stage {
                        case .learning: advance(to: .podcast)
                        case .podcast: advance(to: .reflection)
                        case .reflection: onComplete()
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.black.opacity(0.12), in: Capsule())
                    .padding(.bottom, 8)
                }
            }
            #endif
        }
        .animation(.easeInOut(duration: 0.7), value: stage)
        .onAppear {
            if startAtPaywall {
                stage = .podcast
            }
        }
    }

    private func advance(to next: Stage) {
        withAnimation(.easeInOut(duration: 0.7)) { stage = next }
    }

    private func saveReflection(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Save as the user's first journal entry — already wired to sync into the
        // ingestion pipeline, so their first words shape the model from day one.
        let entry = Entry(type: .text, content: trimmed, aiGeneratedTitle: "First reflection")
        EntryManager.shared.addEntry(entry)
    }
}

// MARK: - Reflection step

struct FirstReflectionView: View {
    var onSubmit: (String) -> Void
    var onSkip: () -> Void

    @State private var text = ""
    @FocusState private var focus: InputField?

    private let cream = Color(red: 0.929, green: 0.918, blue: 0.886)
    private let ink = Color(red: 0.1, green: 0.09, blue: 0.08)

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            cream.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()

                Text("How was your first podcast?")
                    .font(.custom("HedvigLettersSerif-24ptRegular", size: 30))
                    .multilineTextAlignment(.center)
                    .foregroundColor(ink)
                    .padding(.horizontal, 36)

                EnhancedTextField(
                    placeholder: "Reflect…",
                    text: $text,
                    isFocused: $focus,
                    field: .reflections,
                    showSendButton: true,
                    isSendEnabled: canSend,
                    onSend: {
                        if canSend {
                            onSubmit(text)
                        }
                    }
                )
                .frame(height: 200)
                .padding(.horizontal, 24)

                Button("Skip") { onSkip() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ink.opacity(0.45))

                Spacer()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { focus = .reflections }
        }
    }
}

#if DEBUG
/// Walk the whole finale on device without real onboarding/audio: `-FirstPodcastFinale`.
struct FirstPodcastFinaleDebugHost: View {
    @State private var done = false
    @State private var key = 0
    private let mockTranscript = """
    There is a version of you that already knows what to do. The last few weeks you moved fast and carried a lot quietly. Let's sit with that for a moment, because it matters more than you have let yourself admit.
    """
    var body: some View {
        ZStack {
            FirstPodcastExperience(
                transcript: mockTranscript,
                audioURL: nil,
                podcastReady: true,
                onComplete: { done = true },
                debugControls: true
            )
            .id(key)
            if done {
                VStack(spacing: 16) {
                    Text("✓ onboarding complete → home").font(.system(size: 18, weight: .semibold))
                    Button("Replay") { done = false; key += 1 }
                }
                .padding(24)
                .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}
#endif
