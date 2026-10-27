//
//  PodcastPlayer.swift
//  Retrospect
//
//  The single, shared podcast player. One transcript reader + one transport,
//  used by both the live listening screen (DarkAudioPlayerView) and the
//  onboarding paywall flow (PodcastPaywallFlow). Differences between those two
//  screens are chrome around this core, not separate player implementations.
//

import AVFoundation
import SwiftUI

// MARK: - Theme

struct PodcastPlayerTheme {
    var surface: Color
    var control: Color
    var ink: Color
    var muted: Color

    /// The cream listening surface used across the app (#f4f2ee / #eae7e3 / #9e9e9e).
    static let light = PodcastPlayerTheme(
        surface: Color(red: 244 / 255, green: 242 / 255, blue: 238 / 255),
        control: Color(red: 234 / 255, green: 231 / 255, blue: 227 / 255),
        ink: .black,
        muted: Color(red: 158 / 255, green: 158 / 255, blue: 158 / 255)
    )

    static let dark = PodcastPlayerTheme(
        surface: Color(red: 20 / 255, green: 20 / 255, blue: 22 / 255),
        control: Color.white.opacity(0.10),
        ink: .white,
        muted: Color.white.opacity(0.45)
    )
}

enum PodcastTranscriptTypography {
    case standard
    case onboardingInky

    func font(size: CGFloat) -> Font {
        switch self {
        case .standard:
            return .custom("HedvigLettersSerif-24ptRegular", size: size)
        case .onboardingInky:
            return OnboardingStyle.titleFont(size: size)
        }
    }
}

enum PodcastTranscriptSurfaceStyle {
    case fullScreen
    case transparent
}

// MARK: - Playback abstraction

/// A backend the player can drive. `currentTimeNow` is polled by the view on a
/// timer (matching the existing players), so conformers don't need to publish it;
/// `isPlaying` must be published so the play/pause glyph updates.
@MainActor
protocol PodcastPlayback: ObservableObject {
    var currentTimeNow: TimeInterval { get }
    var playbackDuration: TimeInterval { get }
    var isPlaying: Bool { get }
    /// True when a real audio track is loaded (controls active). False = silent visual.
    var hasAudio: Bool { get }

    func toggle()
    func seek(toProgress progress: Double)
    func skip(_ seconds: TimeInterval)
}

// MARK: - Streaming engine (URL stream, or silent visual when url == nil)

@MainActor
final class StreamingPodcastPlayback: ObservableObject, PodcastPlayback {
    @Published private(set) var isPlaying = false
    /// Fires once when real audio plays through to the end (e.g. after the
    /// listener subscribes and finishes the episode). Used to drive the
    /// post-podcast reflection in the first-podcast finale.
    @Published private(set) var didFinish = false

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private let url: URL?
    private var fadeTask: Task<Void, Never>?

    /// Visual clock used when there is no audio (onboarding tease before audio exists).
    @Published private var visualTime: TimeInterval = 0
    private var visualTask: Task<Void, Never>?
    private let visualDuration: TimeInterval

    @Published private var realCurrentTime: TimeInterval = 0
    @Published private var realDuration: TimeInterval = 1

    init(url: URL?, visualDuration: TimeInterval = 420) {
        self.url = url
        self.visualDuration = visualDuration
    }

    var hasAudio: Bool {
        url != nil
    }

    var currentTimeNow: TimeInterval {
        url == nil ? visualTime : realCurrentTime
    }

    var playbackDuration: TimeInterval {
        url == nil ? visualDuration : realDuration
    }

    func start() {
        removeTimeObserver()
        removeEndObserver()
        didFinish = false
        fadeTask?.cancel()
        fadeTask = nil
        visualTask?.cancel()
        visualTask = nil

        if let url {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try? AVAudioSession.sharedInstance().setActive(true)
            let item = AVPlayerItem(url: url)
            let p = AVPlayer(playerItem: item)
            player = p
            let interval = CMTime(seconds: 0.2, preferredTimescale: 600)
            timeObserver = p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] t in
                Task { @MainActor in self?.realCurrentTime = CMTimeGetSeconds(t) }
            }
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.isPlaying = false; self?.didFinish = true }
            }
            Task {
                if let d = try? await item.asset.load(.duration) {
                    let secs = CMTimeGetSeconds(d)
                    if secs.isFinite, secs > 0 {
                        self.realDuration = secs
                    }
                }
            }
            p.play()
            isPlaying = true
        } else {
            startVisual()
        }
    }

    func stop() {
        fadeTask?.cancel()
        fadeTask = nil
        player?.pause()
        player?.volume = 1
        player?.seek(to: .zero)
        removeTimeObserver()
        removeEndObserver()
        player = nil
        realCurrentTime = 0
        visualTask?.cancel(); visualTask = nil
        visualTime = 0
        isPlaying = false
    }

    func pauseForPaywall() {
        fadeTask?.cancel()
        fadeTask = nil
        player?.pause()
        player?.volume = 1
        visualTask?.cancel(); visualTask = nil
        isPlaying = false
    }

    func fadeOutForPaywall(duration: TimeInterval) {
        fadeTask?.cancel()
        let safeDuration = max(0.1, duration)

        guard let player else {
            fadeTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(safeDuration * 1_000_000_000))
                guard !Task.isCancelled else { return }
                visualTask?.cancel()
                visualTask = nil
                isPlaying = false
            }
            return
        }

        let startingVolume = player.volume
        let steps = 20
        fadeTask = Task { @MainActor in
            for step in 1 ... steps {
                try? await Task.sleep(nanoseconds: UInt64((safeDuration / Double(steps)) * 1_000_000_000))
                guard !Task.isCancelled else { return }
                player.volume = startingVolume * Float(1 - Double(step) / Double(steps))
            }
            player.pause()
            player.volume = 1
            isPlaying = false
        }
    }

    private func startVisual() {
        visualTask?.cancel()
        isPlaying = true
        visualTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard !Task.isCancelled else { return }
                visualTime = min(visualTime + 0.2, visualDuration)
            }
        }
    }

    // MARK: PodcastPlayback

    func toggle() {
        if url == nil {
            if visualTask == nil {
                startVisual()
            } else {
                visualTask?.cancel(); visualTask = nil; isPlaying = false
            }
            return
        }
        if isPlaying {
            player?.pause(); isPlaying = false
        } else {
            player?.play(); isPlaying = true
        }
    }

    func seek(toProgress progress: Double) {
        let clamped = max(0, min(1, progress))
        if url == nil {
            visualTime = visualDuration * clamped
            return
        }
        player?.seek(to: CMTime(seconds: realDuration * clamped, preferredTimescale: 600))
    }

    func skip(_ seconds: TimeInterval) {
        if url == nil {
            visualTime = max(0, min(visualDuration, visualTime + seconds))
            return
        }
        player?.seek(to: CMTime(seconds: max(0, min(realDuration, realCurrentTime + seconds)), preferredTimescale: 600))
    }

    private func removeTimeObserver() {
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }

    private func removeEndObserver() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    deinit {
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
    }
}

// MARK: - DarkAudioManager conformance (the live listening backend)

extension DarkAudioManager: PodcastPlayback {
    var currentTimeNow: TimeInterval {
        audioPlayer?.currentTime ?? 0
    }

    var playbackDuration: TimeInterval {
        audioPlayer?.duration ?? 0
    }

    var hasAudio: Bool {
        audioPlayer != nil
    }

    func toggle() { togglePlayback() }

    func seek(toProgress progress: Double) { seekTo(progress: progress) }

    func skip(_ seconds: TimeInterval) {
        guard let player = audioPlayer else { return }
        player.currentTime = min(max(player.currentTime + seconds, 0), player.duration)
    }
}

// MARK: - Transcript model (shared sentence segmentation + follow-along reader)

struct PodcastSegment: Identifiable {
    let index: Int
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    var id: String {
        "segment-\(index)"
    }
}

enum PodcastTranscript {
    /// Sentence-segment a script and allocate each segment a slice of `duration`
    /// proportional to its word count (matches the original DarkAudioPlayerView).
    static func segments(from script: String?, duration: TimeInterval) -> [PodcastSegment] {
        guard let script, !script.isEmpty else { return [] }
        let cleaned = script.replacingOccurrences(
            of: "(?m)^\\s*#+\\s*|\\[\\w+(?:\\s\\w+)*\\]|^\\s*[-•]\\s*|^\\s*\\d+\\.\\s*",
            with: "",
            options: .regularExpression
        )
        .replacingOccurrences(of: "\n\n+", with: "\n", options: .regularExpression)

        var results: [String] = []
        cleaned.enumerateSubstrings(in: cleaned.startIndex..., options: .bySentences) { substring, _, _, _ in
            if let s = substring?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                results.append(s)
            }
        }
        if results.isEmpty {
            results = cleaned
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        let totalWords = max(results.reduce(0) { $0 + $1.podWordCount }, 1)
        let safeDuration = duration > 0 ? duration : Double(totalWords) / 2.5
        var cursor: TimeInterval = 0
        return results.enumerated().map { index, text in
            let segDuration = max(1.6, safeDuration * (Double(max(text.podWordCount, 1)) / Double(totalWords)))
            let seg = PodcastSegment(index: index, text: text, startTime: cursor, endTime: cursor + segDuration)
            cursor += segDuration
            return seg
        }
    }

    static func currentIndex(segments: [PodcastSegment], currentTime: TimeInterval, duration: TimeInterval) -> Int {
        guard !segments.isEmpty else { return 0 }
        if let match = segments.first(where: { currentTime >= $0.startTime && currentTime < $0.endTime }) {
            return match.index
        }
        let progress = duration > 0 ? currentTime / duration : 0
        let fallback = Int(progress * Double(segments.count))
        return min(max(fallback, 0), segments.count - 1)
    }
}

private extension String {
    var podWordCount: Int {
        split { $0.isWhitespace || $0.isNewline }.count
    }
}

// MARK: - Shared follow-along transcript reader

struct PodcastTranscriptReader: View {
    let transcript: String?
    let currentTime: TimeInterval
    let duration: TimeInterval
    var theme: PodcastPlayerTheme = .light
    var fontSize: CGFloat = 30
    var horizontalPadding: CGFloat = 38
    var alignment: TextAlignment = .center
    var textAlignment: TextAlignment?
    var topInset: CGFloat = 96
    var bottomInset: CGFloat = 220
    var autoScroll: Bool = true
    var typography: PodcastTranscriptTypography = .standard
    var surfaceStyle: PodcastTranscriptSurfaceStyle = .fullScreen
    var contentOpacity: Double = 1

    private var segments: [PodcastSegment] {
        PodcastTranscript.segments(from: transcript, duration: duration)
    }

    private var currentIndex: Int {
        PodcastTranscript.currentIndex(segments: segments, currentTime: currentTime, duration: duration)
    }

    private var stackAlignment: HorizontalAlignment {
        switch alignment {
        case .center: return .center
        case .trailing: return .trailing
        default: return .leading
        }
    }

    private var resolvedTextAlignment: TextAlignment {
        textAlignment ?? alignment
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: stackAlignment, spacing: 0) {
                    if segments.isEmpty {
                        Text(transcript ?? "No transcript available.")
                            .font(typography.font(size: fontSize))
                            .foregroundColor(theme.muted)
                            .multilineTextAlignment(resolvedTextAlignment)
                            .lineSpacing(4)
                    } else {
                        ForEach(segments) { segment in
                            PodcastTranscriptLine(
                                segment: segment,
                                currentIndex: currentIndex,
                                ink: theme.ink,
                                muted: theme.muted,
                                fontSize: fontSize,
                                alignment: resolvedTextAlignment,
                                typography: typography
                            )
                            .id(segment.id)
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
                .padding(.top, topInset)
                .padding(.bottom, bottomInset)
                .opacity(contentOpacity)
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .top) {
                if surfaceStyle == .fullScreen {
                    LinearGradient(
                        colors: [theme.surface, theme.surface, theme.surface.opacity(0)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 130)
                    .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottom) {
                if surfaceStyle == .fullScreen {
                    LinearGradient(
                        colors: [theme.surface.opacity(0), theme.surface, theme.surface],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 130)
                    .allowsHitTesting(false)
                }
            }
            .onChange(of: currentIndex) { _, newIndex in
                guard autoScroll else { return }
                withAnimation(.easeInOut(duration: 0.7)) {
                    proxy.scrollTo("segment-\(newIndex)", anchor: .center)
                }
            }
        }
        .textSelection(.enabled)
    }
}

private struct PodcastTranscriptLine: View {
    let segment: PodcastSegment
    let currentIndex: Int
    let ink: Color
    let muted: Color
    let fontSize: CGFloat
    let alignment: TextAlignment
    let typography: PodcastTranscriptTypography

    private var distance: Int {
        segment.index - currentIndex
    }

    var body: some View {
        Text(segment.text)
            .font(typography.font(size: fontSize))
            .foregroundColor(distance == 0 ? ink : muted.opacity(0.48))
            .lineSpacing(3)
            .tracking(-0.6)
            .multilineTextAlignment(alignment)
            .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
            .blur(radius: distance == 0 ? 0 : 1.8)
            .padding(.bottom, 6)
            .animation(.easeInOut(duration: 0.45), value: currentIndex)
    }
}

// MARK: - Shared transport (scrubber + remaining time + ±15 / play-pause bubble)

struct PodcastTransport<Leading: View>: View {
    let currentTime: TimeInterval
    let duration: TimeInterval
    let isPlaying: Bool
    let enabled: Bool
    var theme: PodcastPlayerTheme = .light
    let onSeek: (Double) -> Void
    let onSkip: (TimeInterval) -> Void
    let onToggle: () -> Void
    @ViewBuilder var leadingAccessory: () -> Leading

    @State private var isDragging = false

    private var progress: Double {
        duration > 0 ? min(1, currentTime / duration) : 0
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.muted.opacity(0.22)).frame(height: 3)
                        Capsule().fill(theme.muted.opacity(0.86))
                            .frame(width: geo.size.width * progress, height: 3)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                onSeek(min(max(value.location.x / geo.size.width, 0), 1))
                            }
                            .onEnded { _ in isDragging = false }
                    )
                }
                .frame(height: 18)

                HStack {
                    leadingAccessory()
                    Spacer()
                    Text(Self.clock(max(0, duration - currentTime)))
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(theme.muted)
                }
            }

            HStack(spacing: 20) {
                Button { onSkip(-15) } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 19, weight: .medium)).frame(width: 26, height: 26)
                }
                Button { onToggle() } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .bold))
                        .offset(x: isPlaying ? 0 : 1.5).frame(width: 28, height: 28)
                }
                Button { onSkip(15) } label: {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 19, weight: .medium)).frame(width: 26, height: 26)
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(theme.muted)
            .opacity(enabled ? 1 : 0.42)
            .padding(.horizontal, 24)
            .padding(.vertical, 15)
            .background(Capsule().fill(theme.control))
        }
    }

    static func clock(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "0:00" }
        let total = Int(time)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

extension PodcastTransport where Leading == EmptyView {
    init(
        currentTime: TimeInterval,
        duration: TimeInterval,
        isPlaying: Bool,
        enabled: Bool,
        theme: PodcastPlayerTheme = .light,
        onSeek: @escaping (Double) -> Void,
        onSkip: @escaping (TimeInterval) -> Void,
        onToggle: @escaping () -> Void
    ) {
        self.init(
            currentTime: currentTime,
            duration: duration,
            isPlaying: isPlaying,
            enabled: enabled,
            theme: theme,
            onSeek: onSeek,
            onSkip: onSkip,
            onToggle: onToggle,
            leadingAccessory: { EmptyView() }
        )
    }
}
