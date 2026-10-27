import AVFoundation
import SwiftUI

// MARK: - Optimized Audio Player with Performance Improvements

struct OptimizedAudioPlayerView: View {
    let transcript: String
    let mood: String?
    let generationType: GenerationType?
    @Binding var audioPlayer: AVAudioPlayer?
    @Binding var isPlaying: Bool
    @Binding var isExpanded: Bool

    // Optimized state management
    @State private var currentTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false

    // Performance optimizations
    @State private var cachedDuration: TimeInterval = 0
    @State private var shouldAnimateGradient = false
    @State private var gradientPhase: CGFloat = 0

    /// Cached gradient colors (computed once, not on every render)
    private let staticGradientColors = [
        LinearColors.terraCottaPrimary,
        LinearColors.terraCottaLight,
        LinearColors.warmCharcoal,
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Optimized background - only animate when playing
                if shouldAnimateGradient, isPlaying {
                    optimizedBackgroundGradient
                } else {
                    staticBackgroundGradient
                }

                // Main content
                VStack(spacing: 0) {
                    if isExpanded {
                        expandedView(geometry: geometry)
                    } else {
                        minimizedView
                    }
                }
                .background(contentBackground)
            }
            .gesture(optimizedDragGesture)
            .onAppear {
                setupAudioPlayer()
            }
            .onDisappear {
                cleanupTimer()
            }
            .onChange(of: isPlaying) { _, playing in
                if playing {
                    startTimer()
                    startGradientAnimation()
                } else {
                    stopTimer()
                    stopGradientAnimation()
                }
            }
        }
    }

    // MARK: - Optimized Background Components

    private var optimizedBackgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: staticGradientColors),
            startPoint: UnitPoint(x: 0.5 + cos(gradientPhase) * 0.3, y: 0.5 + sin(gradientPhase) * 0.3),
            endPoint: UnitPoint(x: 0.5 - cos(gradientPhase) * 0.3, y: 0.5 - sin(gradientPhase) * 0.3)
        )
        .opacity(0.1)
        .blur(radius: 15)
        .animation(.linear(duration: 0.1), value: gradientPhase)
    }

    private var staticBackgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: staticGradientColors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .opacity(0.05)
    }

    private var contentBackground: some View {
        ZStack {
            if isExpanded {
                Color.white
                    .edgesIgnoringSafeArea(.all)
                    .opacity(max(0.8, 1.0 - (Double(dragOffset.height) / 500.0)))
            } else {
                BlurView(style: .systemUltraThinMaterial)
                    .edgesIgnoringSafeArea(.all)
            }
        }
    }

    // MARK: - Optimized Gesture Handling

    private var optimizedDragGesture: some Gesture {
        DragGesture()
            .onChanged { gesture in
                if isExpanded {
                    let resistance = max(0.3, 1.0 - (gesture.translation.height / 300.0))
                    dragOffset = CGSize(
                        width: 0,
                        height: max(0, gesture.translation.height * resistance)
                    )
                    isDragging = true
                }
            }
            .onEnded { gesture in
                isDragging = false

                if isExpanded, gesture.translation.height > 100 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded = false
                        dragOffset = .zero
                    }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    // MARK: - View Components

    private var minimizedView: some View {
        HStack(spacing: 12) {
            // Play/Pause Button
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(LinearColors.accent)
            }
            .frame(width: 40, height: 40)
            .background(
                Circle()
                    .fill(LinearColors.cardBackground)
                    .shadow(color: LinearColors.cardShadow, radius: 2, x: 0, y: 1)
            )

            // Title and Progress
            VStack(alignment: .leading, spacing: 4) {
                Text(generationType?.displayName ?? "Your Insights")
                    .font(.serifLabel).fontWeight(.semibold)
                    .foregroundColor(LinearColors.textPrimary)
                    .lineLimit(1)

                ProgressView(value: currentTime, total: cachedDuration)
                    .progressViewStyle(LinearProgressViewStyle(tint: LinearColors.accent))
                    .frame(height: 2)
            }

            // Expand Button
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded = true
                }
            }) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(LinearColors.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(height: 64)
    }

    private func expandedView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 24) {
            // Header with close button
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded = false
                    }
                }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(LinearColors.textSecondary)
                }

                Spacer()

                Text(generationType?.displayName ?? "Your Insights")
                    .font(.serifHeadline).fontWeight(.bold)
                    .foregroundColor(LinearColors.textPrimary)

                Spacer()

                // Placeholder for symmetry
                Color.clear.frame(width: 24, height: 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer()

            // Central play controls
            VStack(spacing: 24) {
                // Large play/pause button
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(LinearColors.buttonText)
                        .frame(width: 80, height: 80)
                        .background(
                            Circle()
                                .fill(LinearColors.accent)
                                .shadow(
                                    color: LinearColors.cardShadow,
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                        )
                }
                .scaleEffect(isDragging ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isDragging)

                // Progress and time
                VStack(spacing: 8) {
                    ProgressView(value: currentTime, total: cachedDuration)
                        .progressViewStyle(LinearProgressViewStyle(tint: LinearColors.accent))
                        .frame(height: 4)

                    HStack {
                        Text(formatTime(currentTime))
                            .font(.serifCaption)
                            .foregroundColor(LinearColors.textSecondary)

                        Spacer()

                        Text(formatTime(cachedDuration))
                            .font(.serifCaption)
                            .foregroundColor(LinearColors.textSecondary)
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()
        }
        .offset(y: dragOffset.height)
    }

    // MARK: - Performance Optimized Methods

    private func setupAudioPlayer() {
        if let player = audioPlayer {
            cachedDuration = player.duration
            currentTime = player.currentTime

            if player.isPlaying {
                startTimer()
                startGradientAnimation()
            }
        }
    }

    private func startTimer() {
        cleanupTimer()

        // Use a more efficient timer with reduced frequency
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let player = audioPlayer {
                currentTime = player.currentTime

                if !player.isPlaying, isPlaying {
                    isPlaying = false
                    stopGradientAnimation()
                }
            }
        }
    }

    private func cleanupTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func stopTimer() {
        cleanupTimer()
    }

    private func startGradientAnimation() {
        guard !shouldAnimateGradient else { return }

        shouldAnimateGradient = true

        // Smooth, low-impact gradient animation
        let animation = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            gradientPhase += 0.02
            if gradientPhase > .pi * 2 {
                gradientPhase = 0
            }
        }

        RunLoop.current.add(animation, forMode: .common)
    }

    private func stopGradientAnimation() {
        shouldAnimateGradient = false
        gradientPhase = 0
    }

    private func togglePlayback() {
        guard let player = audioPlayer else { return }

        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopGradientAnimation()
        } else {
            player.play()
            isPlaying = true
            startGradientAnimation()
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Note: BlurView is already defined in GeneratingLoadingView.swift
