//
//  RBriefCard.swift
//  M14 C26: today's brief at the top of Journal (design-system/components/brief-card.md,
//  reference §C26; Paper master "c · brief card" B17-0 version D B3E-0, part 03's M3 states
//  CEM-0, decision 05 A FT3-0 for the slim bar, JR-1 instance 1FLM-0). One raised card, 342
//  wide (the screen minus its margins), padded 8 with 12 between its two parts: the artwork
//  panel (132 tall, radius.panel, the sky mesh; a wash for a quiet day, an error or offline;
//  the skeleton colour while it's being made) with a small white date label in its corner and
//  the 44 lit play on its seam, the one lit object on Journal; then the headline (ink card,
//  48 kept clear on the trailing side so it never runs under the play) and one plain line.
//  Scrolled, the same view becomes the slim bar (decision 05 A): 8 padding, a 40 thumb, the
//  headline on one line over "today's brief · 2 min", a 36 play, on RMotion.sheet; the artwork
//  and the play are the same instances throughout, so nothing is redrawn mid-motion. Playing
//  changes nothing on the card (founder, 20 Oct: "I still prefer this"). On a short screen
//  (SE) the panel is a 72 band and the subline goes.
//
import SwiftUI

struct RBriefCard: View {
    enum State: Equatable {
        /// Ready: artwork, headline, the lit play.
        case rest
        /// Heard: the headline steps back, "played" in the corner, a quiet replay well.
        case played
        /// The audio is starting: a thin ring turns around the play.
        case starting
        /// Nothing worth saying: the agent's line, a wash panel, no play.
        case quiet
        /// Being made: skeleton panel and bars, "ready by" when the host knows it.
        case making(readyBy: String?)
        /// Couldn't load: the plain message and "try again".
        case error(message: String)
        /// No connection and not downloaded: "it'll be here when you're back online".
        case offline
    }

    /// The date, already worded ("tue 21 oct").
    let date: String
    /// The length, already worded ("2 min"); nil when there is nothing to play.
    var length: String?
    /// The brief's headline; for a quiet day, the agent's line.
    let headline: String
    /// One plain line of what's in it.
    var subline: String?
    var state: State = .rest
    /// The slim bar (scrolled), driven by the same flag as the top bar.
    var collapsed = false
    /// Plays today's brief (or plays it again).
    let play: () -> Void
    /// Opens the player paused at the start (the card body).
    var open: () -> Void = {}
    /// Reloads the brief after an error.
    var retry: () -> Void = {}

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.rCompactHeight) private var compactHeight

    /// The artwork panel's height (Paper B3E-0: 132; the SE page pass: a 72 band).
    static let panelHeight: CGFloat = 132
    static let panelHeightCompact: CGFloat = 72
    /// The play well overhangs the panel's seam by half its height.
    static var playOverhang: CGFloat {
        RDimension.sizeControlDefault / 2
    }

    /// The panel's corner line: the date, then the length or "played".
    static func label(date: String, length: String?, state: State) -> String {
        switch state {
        case .played: "\(date) · played"
        case .rest, .starting: length.map { "\(date) · \($0)" } ?? date
        case .quiet, .making, .error, .offline: date
        }
    }

    /// Whether the card has a play (lit, starting, or the replay well).
    static func hasPlay(_ state: State) -> Bool {
        switch state {
        case .rest, .starting, .played: true
        case .quiet, .making, .error, .offline: false
        }
    }

    /// What VoiceOver reads for the card.
    static func spoken(length: String?, headline: String, state: State) -> String {
        switch state {
        case .rest, .starting: "today's brief, \(headline)" + (length.map { ", \($0)" } ?? "")
        case .played: "today's brief, \(headline), played"
        case .quiet: "today's brief, \(headline)"
        case let .making(readyBy): "today's brief, being made" + (readyBy.map { ", ready by \($0)" } ?? "")
        case let .error(message): "today's brief, \(message)"
        case .offline: "today's brief, it'll be here when you're back online"
        }
    }

    /// A control sits under the words: the play at accessibility sizes, the retry on an error.
    private var controlsUnderWords: Bool {
        guard !collapsed else { return false }
        if case .error = state {
            return true
        }
        return accessibilitySize && Self.hasPlay(state)
    }

    private var accessibilitySize: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var panelHeight: CGFloat {
        compactHeight ? Self.panelHeightCompact : Self.panelHeight
    }

    private var radius: CGFloat {
        collapsed ? RDimension.radiusPanel : RDimension.radiusCard
    }

    private var shape: RoundedRectangle {
        RShape.rect(radius)
    }

    var body: some View {
        let layout = collapsed
            ? AnyLayout(HStackLayout(alignment: .center, spacing: RDimension.space3))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: RDimension.space3))
        Button(action: open) {
            layout {
                panel
                words
            }
            .padding(RDimension.space2)
            // room under the words for the play (accessibility sizes) or the try-again pill (error)
            .padding(.bottom, controlsUnderWords ? RDimension.sizeControlDefault + RDimension.space2 : RDimension.space0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(shape)
            // inside the label, so the press scales the card with its shadows and the shadows
            // see one opaque card, not the words on their own
            .rRaised(radius)
            // Increase Contrast: a 1pt control edge so the shape holds without its shadow (CEM-0 "increase contrast")
            .overlay(shape.strokeBorder(RColor.borderControl, lineWidth: contrast == .increased ? RDimension.sizeBorderDefault : RDimension.space0))
        }
        .buttonStyle(RCardPressStyle())
        .overlay(alignment: collapsed ? .trailing : (accessibilitySize ? .bottomTrailing : .topTrailing)) {
            // one play instance: on the seam, beside the words when collapsed, under them at accessibility sizes
            playWell
                .padding(.trailing, collapsed ? RDimension.space2 : RDimension.space2 + RDimension.space4)
                .padding(.bottom, accessibilitySize && !collapsed ? RDimension.space2 + RDimension.space2 : RDimension.space0)
                .offset(y: collapsed || accessibilitySize ? RDimension.space0 : RDimension.space2 + panelHeight - Self.playOverhang)
        }
        // the retry is its own control, never nested in the card's button
        .overlay(alignment: .bottomLeading) {
            if case let .error = state, !collapsed {
                RPill(title: "try again", symbol: "arrow.clockwise", action: retry)
                    .padding(.leading, RDimension.space2 + RDimension.space2)
                    .padding(.bottom, RDimension.space2 + RDimension.space2)
                    .accessibilityIdentifier("brief.tryAgain")
            }
        }
        .animation(reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.sheet, value: collapsed)
        .animation(reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.reveal, value: state)
        // the brief becoming ready: once, as making ends (motion-moments "becoming ready")
        .sensoryFeedback(RHaptic.reveal, trigger: state) { old, new in
            if case .making = old {
                return Self.hasPlay(new)
            }
            return false
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Self.spoken(length: length, headline: headline, state: state))
        .accessibilityHint("double tap to open")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - The panel

    /// The artwork (or a wash, or the skeleton colour), with the date in its corner. The same
    /// `RArtwork` instance becomes the 40 thumb when collapsed.
    private var panel: some View {
        let width = collapsed ? RDimension.sizeArtworkRow : nil
        let height = collapsed ? RDimension.sizeArtworkRow : panelHeight
        let corner = collapsed ? RDimension.radiusDefault : RDimension.radiusPanel
        return ZStack(alignment: .topLeading) {
            RShape.rect(corner)
                .fill(panelFill)
            RArtwork(recipe: RArtworkRecipes.morning, width: width ?? RDimension.layoutReadingWidth, height: height, cornerRadius: corner)
                .opacity(showsArtwork ? 1 : 0)
                .frame(maxWidth: .infinity)
                .clipShape(RShape.rect(corner))
            Text(Self.label(date: date, length: length, state: state))
                .rText(.briefLabel)
                .foregroundStyle(showsArtwork ? RColor.glowPrimaryForeground : RColor.textLabel)
                .padding(.leading, RDimension.space4)
                .padding(.top, RDimension.space3)
                .opacity(collapsed ? 0 : 1)
                .accessibilityHidden(true)
        }
        .frame(width: width, height: height)
        .frame(maxWidth: collapsed ? RDimension.sizeArtworkRow : .infinity)
        .clipShape(RShape.rect(corner))
        .accessibilityHidden(true)
    }

    private var showsArtwork: Bool {
        switch state {
        case .rest, .starting, .played: true
        case .quiet, .making, .error, .offline: false
        }
    }

    private var panelFill: Color {
        switch state {
        case .making: RColor.surfaceSkeleton
        case .rest, .starting, .played, .quiet, .error, .offline: RColor.surfaceWash
        }
    }

    // MARK: - The words

    private var words: some View {
        VStack(alignment: .leading, spacing: collapsed ? RDimension.sizeBorderRing : RDimension.space2) {
            switch state {
            case let .making(readyBy):
                if !collapsed {
                    skeletonBar(share: RBriefCard.makingBarShares[0])
                    skeletonBar(share: RBriefCard.makingBarShares[1])
                }
                Text(readyBy.map { "your brief is being made · ready by \($0)" } ?? "your brief is being made")
                    .rText(.briefLabel)
                    .foregroundStyle(RColor.textLabel)
                    .fixedSize(horizontal: false, vertical: true)
            case let .error(message):
                headlineText(message, colour: RColor.statusDangerText, style: .briefLabel)
            case .offline:
                headlineText("it'll be here when you're back online", colour: RColor.textLabel, style: .briefLabel)
            case .rest, .starting, .played, .quiet:
                headlineText(headline, colour: state == .played ? RColor.textSecondary : RColor.textPrimary, style: collapsed ? .inkRow : .inkCard)
                    .lineLimit(collapsed ? 1 : nil)
                if collapsed {
                    Text(length.map { "today's brief · \($0)" } ?? "today's brief")
                        .rText(.metaLine)
                        .foregroundStyle(RColor.textLabel)
                        .lineLimit(1)
                } else if let subline, !compactHeight {
                    Text(subline)
                        .rText(.textMd)
                        .foregroundStyle(RColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(collapsed ? RDimension.space0 : RDimension.space2)
        // 48 clear on the trailing side so the headline never runs under the play (Paper B3E-0)
        .padding(.trailing, collapsed ? RDimension.sizeControlMedium + RDimension.space3 : (accessibilitySize ? RDimension.space0 : RDimension.space12))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Paper's two skeleton bars on the making card: 260 and 180 of the 326 panel width.
    static let makingBarShares: [Double] = [0.8, 0.55] // literal-ok: the bars' designed proportions

    private func headlineText(_ text: String, colour: Color, style: RTextStyle) -> some View {
        Text(text)
            .rText(style)
            .foregroundStyle(colour)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func skeletonBar(share: Double) -> some View {
        GeometryReader { proxy in
            RShape.pill
                .fill(RColor.surfaceSkeleton)
                .frame(width: proxy.size.width * share)
        }
        .frame(height: RDimension.sizeIconDefault)
        .accessibilityHidden(true)
    }

    // MARK: - The play

    /// The lit play on the seam (the one lit object), the starting ring around it, or the quiet
    /// replay well once played. It stays one instance and only changes face, so becoming ready
    /// lights it in place.
    private var playWell: some View {
        let size = collapsed ? RDimension.sizeControlMedium : RDimension.sizeControlDefault
        let hasPlay = Self.hasPlay(state)
        return Button(action: play) {
            ZStack {
                RSymbol(name: "play.fill", size: collapsed ? .small : .regular, tint: RColor.glowPrimaryForeground, glyphScale: RSymbol.playGlyphScale)
                    .opacity(state == .played ? 0 : 1)
                RSymbol(name: "arrow.clockwise", size: collapsed ? .small : .regular)
                    .opacity(state == .played ? 1 : 0)
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle().inset(by: -(RDimension.sizeControlDefault - size) / 2))
        }
        .buttonStyle(RPlayWellStyle(played: state == .played))
        .overlay {
            startingRing
                .opacity(state == .starting ? 1 : 0)
        }
        .compositingGroup()
        .opacity(hasPlay ? 1 : 0)
        .scaleEffect(hasPlay ? 1 : RNumber.motionScalePressSmall)
        .allowsHitTesting(hasPlay)
        .accessibilityHidden(!hasPlay)
        .accessibilityLabel(state == .played ? "play today's brief again" : "play today's brief")
        .accessibilityValue(state == .starting ? "starting" : "")
        .accessibilityIdentifier("brief.play")
    }

    /// A quarter ring, 6 outside the play, turning once per motion.duration.spin while the
    /// audio starts (CEM-0 "starting"). Under Reduce Motion it holds still.
    private var startingRing: some View {
        RStartingRing(diameter: (collapsed ? RDimension.sizeControlMedium : RDimension.sizeControlDefault) + RDimension.space3)
    }
}

/// The play glyph: the shipped triangle is centred by its ink, so no nudge (Paper part 03).
extension RSymbol {
    static let playGlyphScale: CGFloat = 0.8 // literal-ok: the 18 glyph in the 44 well, as drawn
}

// MARK: - Press styles

/// The card body: 0.98 on touch down (80ms), back on snappy; no haptic.
private struct RCardPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? RNumber.motionScalePress : 1)
            .animation(configuration.isPressed ? RMotion.standard(RNumber.motionDurationPressIn) : RMotion.snappy, value: configuration.isPressed)
    }
}

/// The play well: lit (pressed gradient, 0.94, the `press` haptic) or, once played, the raised
/// replay well (0.94, no haptic).
private struct RPlayWellStyle: ButtonStyle {
    let played: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .background {
                ZStack {
                    Color.clear.rLit(RDimension.radiusControl, pressed: pressed).opacity(played ? 0 : 1)
                    Color.clear.rSecondary(RDimension.radiusControl, pressed: pressed).opacity(played ? 1 : 0)
                }
            }
            .scaleEffect(pressed && !reduceMotion ? RNumber.motionScalePressSmall : 1)
            .animation(pressed ? RMotion.standard(RNumber.motionDurationPressIn) : RMotion.snappy, value: pressed)
            .sensoryFeedback(trigger: pressed) { _, down in
                down && !played ? RHaptic.press : nil
            }
    }
}

/// The starting ring: a 2pt quarter arc in accent.border, no track, turning once per
/// motion.duration.spin.
private struct RStartingRing: View {
    let diameter: CGFloat
    @State private var turning = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .inset(by: RDimension.sizeBorderRing / 2)
            .trim(from: 0, to: 0.25)
            .stroke(RColor.accentBorder, style: StrokeStyle(lineWidth: RDimension.sizeBorderRing, lineCap: .round))
            .rotationEffect(.degrees(turning ? 360 : 0))
            .frame(width: diameter, height: diameter)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(RMotion.spin) {
                    turning = true
                }
            }
            .accessibilityHidden(true)
    }
}

extension RTextStyle {
    /// The panel's corner date and the making line (Paper B3E-0: --font-label, --text-sm,
    /// medium, no tracking).
    static let briefLabel = RTextStyle(
        family: .label,
        size: RDimension.fontSizeSm,
        weight: .medium,
        tracking: RNumber.fontTrackingNone,
        leading: 1.3,
        relativeTo: .caption
    )
    /// The slim bar's one-line headline (decision 05 A: the ink card face at --text-md).
    static let inkRow = RTextStyle(
        family: .inky(axis: -10),
        size: RDimension.fontSizeMd,
        weight: .regular,
        tracking: RNumber.fontTrackingCard,
        leading: 1.1,
        relativeTo: .subheadline
    )
}

#if DEBUG
/// Lab page "brief": the card in every state, the slim bar, and becoming ready.
/// `-DesignLabAutoplay` collapses and opens the card, then makes a brief ready, for recordings.
struct RBriefCardGallery: View {
    @State private var collapsed = false
    @State private var live: RBriefCard.State = .making(readyBy: "8:30")
    @State private var pressed: RBriefCard.State = .rest
    private let headline = "three things moved since yesterday"
    private let subline = "the planning call, the canal walk, and a shorter night."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space6) {
                caption("rest (B3E-0, 1FLM-0) · play starts · starting ring")
                RBriefCard(date: "tue 21 oct", length: "2 min", headline: headline, subline: subline, state: pressed) {
                    Task { await start() }
                }
                caption("played")
                RBriefCard(date: "tue 21 oct", length: "2 min", headline: headline, subline: subline, state: .played) {}
                caption("quiet day")
                RBriefCard(date: "tue 21 oct", headline: "nothing much moved. enjoy the quiet.", state: .quiet) {}
                caption("being made → ready (tap \"make it ready\")")
                RBriefCard(date: "tue 21 oct", length: "2 min", headline: headline, subline: subline, state: live) {}
                RPill(title: live == .rest ? "make it again" : "make it ready", style: .raised) {
                    live = live == .rest ? .making(readyBy: "8:30") : .rest
                }
                caption("couldn't load · offline")
                RBriefCard(date: "tue 21 oct", headline: headline, state: .error(message: "couldn't load today's brief"), play: {})
                RBriefCard(date: "tue 21 oct", headline: headline, state: .offline) {}
                caption("slim bar (decision 05 A) · toggles with the top bar")
                RBriefCard(date: "tue 21 oct", length: "2 min", headline: headline, subline: subline, collapsed: collapsed) {}
                RPill(title: collapsed ? "open" : "collapse", style: .raised) { collapsed.toggle() }
                    .accessibilityIdentifier("brief.collapse")
            }
            .padding(RDimension.spaceScreenMargin)
        }
        // `-DesignLabAnchor center|bottom` opens on the middle or lower states, for more screenshots
        .defaultScrollAnchor(Self.anchor)
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-DesignLabAutoplay") else { return }
            for pause in [1.5, 1.5] {
                do { try await Task.sleep(for: .seconds(pause)) } catch { return }
                collapsed.toggle()
            }
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            live = .rest
        }
    }

    /// Where the page opens: `-DesignLabAnchor center` or `bottom`, else the top.
    private static var anchor: UnitPoint {
        switch UserDefaults.standard.string(forKey: "DesignLabAnchor") {
        case "center": .center
        case "bottom": .bottom
        default: .top
        }
    }

    /// Starting for a moment, then back to rest (the player takes over from here).
    private func start() async {
        pressed = .starting
        do { try await Task.sleep(for: .seconds(1.5)) } catch { return }
        pressed = .rest
    }

    private func caption(_ text: String) -> some View {
        Text(text).rText(.label).foregroundStyle(RColor.textLabel)
    }
}

#Preview("brief card") { RBriefCardGallery() }
#endif
