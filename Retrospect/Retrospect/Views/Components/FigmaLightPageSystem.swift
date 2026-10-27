//
//  FigmaLightPageSystem.swift
//  Retrospect
//
//  Shared light surfaces for the Figma-led app shell.
//

import AVFoundation
import SwiftUI

enum FigmaLightTheme {
    static let drawerBackground = Color(red: 228 / 255, green: 228 / 255, blue: 226 / 255)
    static let cardSurface = Color(red: 244 / 255, green: 242 / 255, blue: 238 / 255)
    static let controlSurface = Color(red: 247 / 255, green: 243 / 255, blue: 238 / 255)
    static let rowSurface = Color(red: 234 / 255, green: 231 / 255, blue: 227 / 255)
    static let primaryText = Color(red: 30 / 255, green: 30 / 255, blue: 30 / 255)
    static let mutedText = Color(red: 158 / 255, green: 158 / 255, blue: 158 / 255)
    static let faintText = Color(red: 195 / 255, green: 194 / 255, blue: 190 / 255)
    static let border = Color.white.opacity(0.9)
    static let titleSize: CGFloat = 40

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func title(_ size: CGFloat) -> Font {
        .custom("HedvigLettersSerif-24ptRegular", size: size)
    }
}

struct FigmaLightPageScaffold<Accessory: View, Content: View>: View {
    let title: String
    private let accessory: Accessory
    private let content: Content
    private let hideHeader: Bool

    @Environment(\.dynamicSafeAreaTop) private var dynamicSafeAreaTop
    @Environment(\.sidePanelProgress) private var sidePanelProgress
    @Environment(\.openSidePanel) private var openSidePanel

    init(
        title: String,
        hideHeader: Bool = false,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.hideHeader = hideHeader
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            if !hideHeader {
                header
            } else {
                Spacer().frame(height: dynamicSafeAreaTop)
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(FigmaLightTheme.cardSurface)
    }

    private var header: some View {
        ZStack {
            Text(title)
                .font(.system(size: 18, weight: .regular, design: .monospaced))
                .foregroundColor(FigmaLightTheme.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: 0) {
                Button(action: {
                    HapticManager.shared.playLightImpact()
                    openSidePanel()
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(FigmaLightTheme.faintText)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(FigmaLightTheme.controlSurface)
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 1))
                                .shadow(color: Color.black.opacity(0.16), radius: 4, x: 0, y: 2)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(1 - sidePanelProgress)
                .allowsHitTesting(sidePanelProgress < 0.05)

                Spacer()

                accessory
                    .frame(width: 38, height: 38)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, dynamicSafeAreaTop + 6)
        .padding(.bottom, 10)
    }
}

extension FigmaLightPageScaffold where Accessory == EmptyView {
    init(
        title: String,
        hideHeader: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title: title, hideHeader: hideHeader, accessory: { EmptyView() }, content: content)
    }
}

struct FigmaLightCountPill: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(FigmaLightTheme.mono(13, weight: .medium))
            .foregroundColor(FigmaLightTheme.mutedText)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(FigmaLightTheme.controlSurface)
                    .overlay(Capsule().strokeBorder(FigmaLightTheme.border, lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.14), radius: 4, x: 0, y: 2)
            )
    }
}

struct FigmaLightRowCard<Content: View>: View {
    let cornerRadius: CGFloat
    private let content: Content

    init(cornerRadius: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(FigmaLightTheme.rowSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(FigmaLightTheme.border.opacity(0.75), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.055), radius: 10, x: 0, y: 5)
            )
    }
}

/// A hairline separator between stacked rows inside one `FigmaLightRowCard`,
/// inset to clear a leading icon column.
struct FigmaLightDivider: View {
    var leadingInset: CGFloat = 62

    var body: some View {
        Rectangle()
            .fill(FigmaLightTheme.border.opacity(0.65))
            .frame(height: 0.5)
            .padding(.leading, leadingInset)
    }
}

struct FigmaLightSectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(FigmaLightTheme.mono(13))
            .foregroundColor(FigmaLightTheme.mutedText.opacity(0.82))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FigmaLightInlineEntryReader: View {
    let entry: Entry
    @Binding var activeEntry: Entry?

    @Environment(\.openSidePanel) private var openSidePanel

    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var timer: Timer?

    private var duration: TimeInterval {
        audioPlayer?.duration ?? 0
    }

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header: back button + title + type/date
            HStack(alignment: .top, spacing: 14) {
                Button {
                    HapticManager.shared.playLightImpact()
                    activeEntry = nil
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(FigmaLightTheme.mutedText)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(FigmaLightTheme.controlSurface))
                        .overlay(Circle().strokeBorder(FigmaLightTheme.border, lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.14), radius: 5, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())

                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.displayTitle)
                        .font(FigmaLightTheme.title(36))
                        .foregroundColor(FigmaLightTheme.primaryText.opacity(0.76))
                        .lineLimit(3)
                        .minimumScaleFactor(0.74)

                    HStack(spacing: 8) {
                        Text(entry.type == .voice ? "voice" : "written")
                        Text("•")
                        Text(formatDate(entry.date))
                    }
                    .font(FigmaLightTheme.mono(13))
                    .foregroundColor(FigmaLightTheme.mutedText)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 20)

            // Scrollable text content fills the middle
            ScrollView {
                Text(entry.content.isEmpty ? "No transcription was saved for this entry." : entry.content)
                    .font(FigmaLightTheme.body(18))
                    .foregroundColor(FigmaLightTheme.primaryText.opacity(0.78))
                    .lineSpacing(7)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.bottom, entry.type == .voice && entry.audioURL != nil ? 20 : 120)
            }
            .mask(
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: 18)
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 52)
                }
            )

            // Audio player pinned at the bottom for voice entries
            if entry.type == .voice, entry.audioURL != nil {
                voicePlayer
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
        }
        .onAppear(perform: setupAudioPlayer)
        .onDisappear {
            timer?.invalidate()
            audioPlayer?.stop()
        }
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = abs(value.translation.height)
                    guard vertical < abs(horizontal) else { return }
                    if horizontal > 60 {
                        HapticManager.shared.playLightImpact()
                        activeEntry = nil
                    } else if horizontal < -60 {
                        HapticManager.shared.playLightImpact()
                        openSidePanel()
                    }
                }
        )
    }

    private var voicePlayer: some View {
        FigmaLightRowCard(cornerRadius: 22) {
            VStack(spacing: 12) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(FigmaLightTheme.faintText.opacity(0.28))
                            .frame(height: 4)

                        Capsule()
                            .fill(FigmaLightTheme.mutedText.opacity(0.74))
                            .frame(width: geometry.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)

                HStack {
                    Text(formatTime(currentTime))
                        .font(FigmaLightTheme.mono(12))
                        .foregroundColor(FigmaLightTheme.mutedText)

                    Spacer()

                    Button(action: togglePlayback) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(FigmaLightTheme.primaryText.opacity(0.72))
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(FigmaLightTheme.controlSurface))
                            .overlay(Circle().strokeBorder(FigmaLightTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    Text(formatTime(duration))
                        .font(FigmaLightTheme.mono(12))
                        .foregroundColor(FigmaLightTheme.mutedText)
                }
            }
        }
    }

    private func setupAudioPlayer() {
        guard let audioURL = entry.audioURL else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.prepareToPlay()
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                currentTime = audioPlayer?.currentTime ?? 0
                if let player = audioPlayer, !player.isPlaying, currentTime > 0, currentTime >= duration - 0.1 {
                    isPlaying = false
                }
            }
            if let timer {
                RunLoop.current.add(timer, forMode: .common)
            }
        } catch {
            print("Failed to setup inline entry audio player: \(error.localizedDescription)")
        }
    }

    private func togglePlayback() {
        guard let player = audioPlayer else { return }
        HapticManager.shared.playMediumImpact()
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
