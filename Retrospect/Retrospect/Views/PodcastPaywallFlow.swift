import SwiftUI

// MARK: - Exact design tokens (from Figma oehDunVlItAgXdzLNekHon, nodes 285:263 & 303:711)

private enum Pod {
    static let bg = Color(red: 244/255, green: 242/255, blue: 238/255)        // #f4f2ee
    static let mono = Color(red: 158/255, green: 158/255, blue: 158/255)       // #9e9e9e
    static let bubble = Color(red: 234/255, green: 231/255, blue: 227/255)     // #eae7e3
    static let bubbleSymbol = Color(red: 160/255, green: 155/255, blue: 151/255) // #a09b97
    static let blueTop = Color(red: 67/255, green: 183/255, blue: 255/255)     // rgb(67,183,255)
    static let blueBot = Color(red: 40/255, green: 153/255, blue: 223/255)     // rgb(40,153,223)
    static let blueRing = Color(red: 80/255, green: 164/255, blue: 236/255)    // #50a4ec
    static let blueGlow = Color(red: 47/255, green: 179/255, blue: 255/255)    // rgba(47,179,255,.5)
    static let cream = Color(red: 247/255, green: 243/255, blue: 238/255)      // #f7f3ee
    static let creamRing = Color(red: 228/255, green: 219/255, blue: 206/255)  // #e4dbce
    static let pill = Color(red: 249/255, green: 247/255, blue: 245/255)       // #f9f7f5
    static let playGray = Color(red: 198/255, green: 194/255, blue: 190/255)   // #c6c2be
    static let markGray = Color(red: 186/255, green: 184/255, blue: 181/255)   // lifted logo gray
    static let progressFill = Color(red: 158/255, green: 155/255, blue: 151/255)
    static let progressTrack = Color(red: 233/255, green: 231/255, blue: 226/255)

    static func serif(_ s: CGFloat) -> Font { .custom("HedvigLettersSerif-24ptRegular", size: s) }
    static func transcript(_ s: CGFloat) -> Font { OnboardingStyle.titleFont(size: s) }
    static func mono(_ s: CGFloat) -> Font { .system(size: s, weight: .regular, design: .monospaced) }

    static func clock(_ t: Double) -> String {
        guard t.isFinite, t >= 0 else { return "0:00" }
        let s = Int(t); return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Flow

struct PodcastPaywallFlow: View {
    let audioURL: URL?
    let transcript: String
    var teaseSeconds: Double = 10
    var onClose: (() -> Void)? = nil
    var diagnosticsEnabled: Bool = false

    @StateObject private var playback: StreamingPodcastPlayback
    @ObservedObject private var subs = SubscriptionManager.shared
    @State private var showPaywall = false
    @State private var didTease = false
    @State private var teaseStarted = false
    @State private var teaseTask: Task<Void, Never>?

    init(
        audioURL: URL?,
        transcript: String,
        teaseSeconds: Double = 10,
        onClose: (() -> Void)? = nil,
        diagnosticsEnabled: Bool = false
    ) {
        self.audioURL = audioURL
        self.transcript = transcript
        self.teaseSeconds = teaseSeconds
        self.onClose = onClose
        self.diagnosticsEnabled = diagnosticsEnabled
        _playback = StateObject(wrappedValue: StreamingPodcastPlayback(url: audioURL))
    }

    var body: some View {
        ZStack {
            Pod.bg.ignoresSafeArea()

            podcastStage

            #if DEBUG
            if diagnosticsEnabled {
                screenDiagnostics
                    .zIndex(100)
            }
            #endif

            #if DEBUG
            VStack {
                HStack {
                    Button { onClose?() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Pod.mono)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Pod.bubble))
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(.horizontal, 18).padding(.top, 14)
            #endif
        }
        .onAppear {
            resetForPresentation()
        }
        .onDisappear { endPresentation() }
        #if DEBUG
        .onPreferenceChange(PodcastGeometryPreferenceKey.self) { diagnosticFrames = $0 }
        #endif
        .onChange(of: subs.isSubscribed) { subscribed in
            if subscribed {
                withAnimation { showPaywall = false }
                if !playback.isPlaying { playback.toggle() }
            }
        }
    }

    private func resetForPresentation() {
        teaseTask?.cancel()
        playback.stop()
        withoutAnimation {
            showPaywall = false
            didTease = false
            teaseStarted = false
        }
        playback.start()
        startTease()
    }

    private func endPresentation() {
        teaseTask?.cancel()
        teaseTask = nil
        playback.stop()
        withoutAnimation {
            didTease = false
            teaseStarted = false
            showPaywall = false
        }
    }

    private func withoutAnimation(_ updates: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, updates)
    }

    private func startTease() {
        guard !teaseStarted else { return }
        teaseStarted = true
        teaseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(teaseSeconds * 1_000_000_000))
            guard !Task.isCancelled, !didTease, !subs.isSubscribed else { return }
            didTease = true
            playback.pauseForPaywall()
            withAnimation(.smooth(duration: 1.22, extraBounce: 0.02)) { showPaywall = true }
            HapticManager.shared.playSoftImpact()
        }
    }

    // MARK: Player (node 285:263)

    private var podcastStage: some View {
        GeometryReader { geo in
            let base = CGSize(width: 402, height: 874)
            let scale = min(geo.size.width / base.width, geo.size.height / base.height)
            let xInset = (geo.size.width - base.width * scale) / 2
            let yInset = (geo.size.height - base.height * scale) / 2

            ZStack(alignment: .topLeading) {
                let t: CGFloat = showPaywall ? 1 : 0

                podcastSurface(progress: t)
                    .zIndex(0)

                paywallVeil(progress: t)
                    .opacity(t)
                    .zIndex(1)

                miniPlayer
                    .opacity(t)
                    .offset(y: (1 - t) * 112)
                    .position(x: 201, y: 421)
                    .zIndex(2)
                    .allowsHitTesting(showPaywall)

                paywallContent
                    .opacity(t)
                    .offset(y: (1 - t) * 260)
                    .zIndex(3)
                    .allowsHitTesting(showPaywall)
            }
            .frame(width: base.width, height: base.height, alignment: .topLeading)
            .scaleEffect(scale, anchor: .topLeading)
            .offset(x: xInset, y: yInset)
            #if DEBUG
            .overlay {
                if diagnosticsEnabled {
                    GeometryReader { canvasGeo in
                        let global = canvasGeo.frame(in: .global)
                        Color.clear
                            .preference(
                                key: PodcastGeometryPreferenceKey.self,
                                value: [
                                    "stage.size": "\(Int(geo.size.width))x\(Int(geo.size.height))",
                                    "stage.global": Self.frameDescription(geo.frame(in: .global)),
                                    "canvas.global": Self.frameDescription(global)
                                ]
                            )
                    }
                }
            }
            #endif
        }
    }

    #if DEBUG
    @State private var diagnosticFrames: [String: String] = [:]

    private var screenDiagnostics: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 3) {
                Text("screen: \(Self.frameDescription(geo.frame(in: .global)))")
                ForEach(diagnosticFrames.keys.sorted(), id: \.self) { key in
                    Text("\(key): \(diagnosticFrames[key] ?? "")")
                }
            }
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundColor(.white)
            .padding(8)
            .background(Color.black.opacity(0.82))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .allowsHitTesting(false)
        }
    }

    private func diagnosticFrameReader(name: String) -> some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: PodcastGeometryPreferenceKey.self,
                value: [name: Self.frameDescription(geo.frame(in: .global))]
            )
        }
    }

    private static func frameDescription(_ frame: CGRect) -> String {
        "x\(Int(frame.minX)) y\(Int(frame.minY)) w\(Int(frame.width)) h\(Int(frame.height)) midX\(Int(frame.midX))"
    }
    #endif

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    private func podcastSurface(progress t: CGFloat) -> some View {
        let surfaceWidth: CGFloat = 402
        let surfaceHeight: CGFloat = 874
        let surfaceScale = lerp(1, 0.88, t)
        let surfaceX = lerp(201, 201, t)
        let surfaceY = lerp(437, 452, t)
        let corner = lerp(0, 50, t)

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(t > 0.001 ? Pod.cream.opacity(0.18) : Pod.bg)

            onboardingPlayerSurface(progress: t)

            LinearGradient(
                colors: [
                    Pod.bg.opacity(0),
                    Pod.bg.opacity(Double(0.34 + 0.52 * t)),
                    Pod.bg
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: surfaceWidth + 76, height: lerp(360, 360, t))
            .offset(x: -38, y: lerp(374, 288, t))
            .blur(radius: lerp(10, 18, t))
            .allowsHitTesting(false)

            cardLocalProgressiveBlur(width: surfaceWidth, height: surfaceHeight, progress: t)
            .opacity(Double(t))
            .allowsHitTesting(false)
        }
        .frame(width: surfaceWidth, height: surfaceHeight)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color.white.opacity(Double(0.95 * t)), lineWidth: t > 0 ? 1 : 0)
        )
        .shadow(color: .black.opacity(Double(0.2 * t)), radius: 8, y: 4)
        .scaleEffect(surfaceScale)
        .position(x: surfaceX, y: surfaceY)
    }

    private func onboardingPlayerSurface(progress t: CGFloat) -> some View {
        VStack(spacing: 0) {
            PodcastTranscriptReader(
                transcript: transcript,
                currentTime: playback.currentTimeNow,
                duration: playback.playbackDuration,
                theme: .light,
                fontSize: 30,
                horizontalPadding: 0,
                alignment: .center,
                textAlignment: .leading,
                topInset: 112,
                bottomInset: 250,
                autoScroll: true,
                typography: .onboardingInky,
                surfaceStyle: .transparent,
                contentOpacity: Double(1 - (0.82 * t))
            )
            .frame(width: 326)
            .padding(.top, 52)
            #if DEBUG
            .background {
                if diagnosticsEnabled {
                    diagnosticFrameReader(name: "transcript.global")
                }
            }
            #endif

            Spacer(minLength: 18)

            PodcastTransport(
                currentTime: playback.currentTimeNow,
                duration: playback.playbackDuration,
                isPlaying: playback.isPlaying,
                enabled: true,
                theme: .light,
                onSeek: { playback.seek(toProgress: $0) },
                onSkip: { playback.skip($0) },
                onToggle: { playback.toggle() }
            )
            .frame(width: 310)
            .frame(width: 402, alignment: .center)
            .padding(.bottom, 38)
            .opacity(Double(1 - t))
            .allowsHitTesting(t < 0.5)
            #if DEBUG
            .background {
                if diagnosticsEnabled {
                    diagnosticFrameReader(name: "transport.global")
                }
            }
            #endif
        }
        .frame(width: 402, height: 874)
    }

    private func cardLocalProgressiveBlur(width: CGFloat, height: CGFloat, progress t: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(.regularMaterial)
                .opacity(Double(0.22 * t))
                .frame(width: width + 64, height: height * 0.72)
                .offset(x: -32, y: height * 0.24)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black.opacity(0.2), location: 0.18),
                            .init(color: .black, location: 0.54),
                            .init(color: .black.opacity(0.9), location: 0.86),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            LinearGradient(
                stops: [
                    .init(color: Pod.bg.opacity(0), location: 0),
                    .init(color: Pod.bg.opacity(0.28), location: 0.24),
                    .init(color: Pod.bg.opacity(0.82), location: 0.58),
                    .init(color: Pod.bg, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: width + 72, height: height * 0.76)
            .offset(x: -36, y: height * 0.2)

            Rectangle()
                .fill(Pod.bg.opacity(0.94))
                .frame(width: width + 80, height: height * 0.2)
                .offset(x: -40, y: height * 0.79)
                .blur(radius: 22)
        }
    }

    private func paywallVeil(progress t: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .opacity(Double(0.2 * t))
                .frame(width: 470, height: 390)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black.opacity(0.25), location: 0.18),
                            .init(color: .black, location: 0.44),
                            .init(color: .black, location: 0.82),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .position(x: 201, y: 382)

            LinearGradient(
                colors: [
                    Pod.bg.opacity(0),
                    Pod.bg.opacity(0.3),
                    Pod.bg.opacity(0.86),
                    Pod.bg
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 470, height: 520)
            .position(x: 201, y: 400)

            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(Double(0.26 * t))
                .frame(width: 470, height: 330)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black.opacity(0.35), location: 0.18),
                            .init(color: .black, location: 0.52),
                            .init(color: .black.opacity(0.7), location: 0.84),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .position(x: 201, y: 356)

            LinearGradient(
                stops: [
                    .init(color: Pod.bg.opacity(0), location: 0),
                    .init(color: Pod.bg.opacity(0.7), location: 0.18),
                    .init(color: Pod.bg, location: 0.34),
                    .init(color: Pod.bg, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 520, height: 470)
            .position(x: 201, y: 675)
        }
        .allowsHitTesting(false)
    }

    // MARK: Paywall (node 303:711)

    private var paywallContent: some View {
        ZStack(alignment: .topLeading) {
            paywallMark
                .position(x: 48, y: 495)

            Text("Subscribe to finish the podcast and get one every week.")
                .font(Pod.serif(30))
                .tracking(-0.6)
                .foregroundColor(.black)
                .lineSpacing(0)
                .frame(width: 336, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .position(x: 197, y: 606)

            HStack(spacing: 13) {
                bluePriceButton(subs.monthlyPriceString) { Task { await subs.purchase(.monthly) } }
                creamPriceButton(subs.yearlyPriceString) { Task { await subs.purchase(.yearly) } }
            }
            .frame(width: 345, height: 60)
            .position(x: 201, y: 734)

            HStack(spacing: 20) {
                Button("Restore") { Task { await subs.restore() } }
                Button("Privacy notice") { }
            }
            .font(Pod.mono(12))
            .foregroundColor(Pod.mono)
            .opacity(0.9)
            .position(x: 201, y: 812)
        }
    }

    private var paywallMark: some View {
        ZStack {
            Circle()
                .fill(Pod.cream)
                .overlay(Circle().strokeBorder(Color.white, lineWidth: 1))
                .overlay(Circle().strokeBorder(Pod.creamRing.opacity(0.75), lineWidth: 1))
                .shadow(color: .black.opacity(0.24), radius: 7, y: 6)
                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)

            Image("retrospect-loading-mark")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundColor(Pod.markGray)
                .frame(width: 30, height: 28)
        }
        .frame(width: 38, height: 38)
    }

    private var miniPlayer: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Pod.pill)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 1)

            Text("9:20")
                .font(Pod.mono(14))
                .foregroundColor(Pod.mono)
                .frame(width: 52, alignment: .leading)
                .position(x: 50, y: 21)

            scrubber(width: 150, filled: 0.58)
                .position(x: 151, y: 24)

            Image(systemName: "play.fill")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(Pod.playGray)
                .frame(width: 24, height: 24)
                .position(x: 258, y: 21)
        }
        .frame(width: 286, height: 42)
    }

    // MARK: Pieces

    private func scrubber(width: CGFloat?, filled: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Pod.progressTrack).frame(height: 3)
                Capsule().fill(Pod.progressFill)
                    .frame(width: geo.size.width * CGFloat(max(0, min(1, filled))), height: 3)
            }
        }
        .frame(width: width, height: 14)
    }

    private func bluePriceButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if subs.isPurchasing { ProgressView().tint(.white) }
                else {
                    Text(title)
                        .font(Pod.mono(14))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 29, style: .continuous)
                    .fill(LinearGradient(colors: [Pod.blueTop, Pod.blueBot], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 29).strokeBorder(.white.opacity(0.1), lineWidth: 1))
                    .background(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(Pod.blueRing.opacity(0.4), lineWidth: 2)
                    )
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 29, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                            .mask(
                                LinearGradient(colors: [.white, .clear],
                                               startPoint: .top,
                                               endPoint: .bottom)
                            )
                    }
                    .overlay {
                        NoiseTexture(seed: 19, size: 0.5, intensity: 0.2, density: 1, lightColor: .white, darkColor: Pod.blueBot)
                            .clipShape(RoundedRectangle(cornerRadius: 29, style: .continuous))
                            .allowsHitTesting(false)
                    }
                    .shadow(color: Pod.blueGlow.opacity(0.5), radius: 20, y: 0)
                    .shadow(color: .black.opacity(0.15), radius: 7, y: 6)
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(subs.isPurchasing)
    }

    private func creamPriceButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(Pod.mono(14)).foregroundColor(Pod.mono)
                .frame(maxWidth: .infinity).frame(height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 29, style: .continuous)
                        .fill(Pod.cream)
                        .overlay(RoundedRectangle(cornerRadius: 29).strokeBorder(Color.white, lineWidth: 1))
                        .background(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(Pod.creamRing, lineWidth: 2)
                        )
                        .overlay {
                            NoiseTexture(seed: 239, size: 0.5, intensity: 0.045, density: 0.55, lightColor: .white, darkColor: Pod.creamRing)
                                .clipShape(RoundedRectangle(cornerRadius: 29, style: .continuous))
                                .allowsHitTesting(false)
                        }
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 4)
                )
        }
        .buttonStyle(.plain)
        .disabled(subs.isPurchasing)
    }
}

#if DEBUG
private struct PodcastGeometryPreferenceKey: PreferenceKey {
    static var defaultValue: [String: String] = [:]

    static func reduce(value: inout [String: String], nextValue: () -> [String: String]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
#endif

private struct NoiseTexture: View {
    let seed: Int
    let size: CGFloat
    let intensity: Double
    let density: Double
    let lightColor: Color
    let darkColor: Color

    var body: some View {
        Canvas { context, size in
            let step: CGFloat = self.size
            let columns = max(1, Int(size.width / step))
            let rows = max(1, Int(size.height / step))

            for row in 0..<rows {
                for column in 0..<columns {
                    let value = hash(column: column, row: row)
                    guard value < density else { continue }

                    let alpha = intensity * (0.28 + hash(column: column + 73, row: row + 41) * 0.72)
                    let color = hash(column: column + 17, row: row + 29) > 0.5 ? lightColor : darkColor
                    let rect = CGRect(
                        x: CGFloat(column) * step,
                        y: CGFloat(row) * step,
                        width: step,
                        height: step
                    )
                    context.fill(Path(rect), with: .color(color.opacity(alpha)))
                }
            }
        }
        .blendMode(.softLight)
    }

    private func hash(column: Int, row: Int) -> Double {
        let n = UInt64(column &* 374_761_393) ^ UInt64(row &* 668_265_263) ^ UInt64(seed &* 2_147_483_647)
        var x = n
        x = (x ^ (x >> 13)) &* 1_274_126_177
        x = x ^ (x >> 16)
        return Double(x % 10_000) / 10_000
    }
}
