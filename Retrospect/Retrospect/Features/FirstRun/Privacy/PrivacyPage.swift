//
//  PrivacyPage.swift
//  PV.privacy, ON-5 (Paper p-J-0 16FA-0, approved "from 05"): the privacy moment between the
//  questions and connect. The progress line at 48%; a quiet back chevron and nothing on the right
//  (no skip); a lock in a raised lit disc inside soft sky rings (screen-rules 3); the inky title,
//  one plain description and the policy link (screen-rules 2); the voice composer in Retro's
//  speaking look. No button (founder, 23 Oct): the page moves on when Retro finishes reading, or
//  at a tap anywhere; VoiceOver users move on with the "move on" action or the magic tap. On a
//  short phone or at accessibility sizes the orb drops its outer ring and the column scrolls.
//  Data and decisions come only through `PrivacyModel`.
//
import SafariServices
import SwiftUI

extension RTextStyle {
    /// A purpose page's one description: the text face at --text-body, card tracking, leading
    /// snug (Paper 1F80-0).
    static let purposeDescription = RTextStyle(
        family: .text,
        size: RDimension.fontSizeBody,
        weight: .regular,
        tracking: RNumber.fontTrackingCard,
        leading: RTextStyle.body.leading,
        relativeTo: .body
    )
}

struct PrivacyPage: View {
    let model: PrivacyModel
    var progress: FlowProgress = PrivacyModel.progress

    @Environment(\.rCompactHeight) private var compactHeight
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    /// Where the progress line is drawn: `from` on the first frame, `to` once the page is up.
    @State private var shownProgress: Double?
    @State private var overflows = false

    /// 20 on the smallest phones (craft 8.4), 24 elsewhere.
    private var margin: CGFloat {
        compactHeight ? RDimension.space5 : RDimension.spaceScreenMargin
    }

    /// A short phone or accessibility text: the orb keeps its lit disc and inner ring only.
    private var compactOrb: Bool {
        compactHeight || dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        VStack(spacing: RDimension.space0) {
            RProgressHairline(fraction: shownProgress ?? (reduceMotion ? progress.to : progress.from))
                .padding(.horizontal, margin)
                .accessibilityIdentifier("privacy.progress")
            topBar
            GeometryReader { proxy in
                ScrollView {
                    column
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentSize.height > geometry.containerSize.height
                } action: { _, now in
                    overflows = now
                }
                .rProgressiveBlur(.tabEdge, active: overflows)
            }
            bottom
        }
        .background(RColor.backgroundCanvas.ignoresSafeArea())
        // a tap anywhere that isn't the back chevron or the link moves on early (buttons win)
        .contentShape(Rectangle())
        .onTapGesture { model.tapAnywhere() }
        .accessibilityAction(.magicTap) { model.moveOn() }
        .task { await model.run() }
        .onAppear {
            shownProgress = progress.to
            AccessibilityNotification.Announcement(PrivacyModel.arrival).post()
        }
        .onDisappear { model.pageLeft() }
        // Switch Control moves as slowly as VoiceOver: it holds the page too
        .onChange(of: voiceOverEnabled || switchControlEnabled, initial: true) { _, running in
            model.voiceOver(running: running)
        }
        .onChange(of: model.isWaitingForVoiceOver) { _, waiting in
            if waiting {
                AccessibilityNotification.Announcement(PrivacyModel.finishedForVoiceOver).post()
            }
        }
        .sheet(isPresented: policyShown) {
            if let url = PrivacyModel.policyURL {
                PolicyBrowser(url: url) { model.policyClosed() }
                    .ignoresSafeArea()
            }
        }
        .accessibilityIdentifier("screen.ON-5")
    }

    // MARK: - Top bar

    /// The quiet back chevron (a 32 wash circle in its 44 hit area, on the margin); nothing on the
    /// right (screen-rules 6).
    private var topBar: some View {
        HStack(spacing: RDimension.space0) {
            RIconButton(symbol: "chevron.left", label: "back", role: .inField) { model.back() }
                .accessibilityIdentifier("privacy.back")
            Spacer(minLength: RDimension.space0)
        }
        // Paper draws the 32 circle on the margin at the 44 box's leading edge; ours is centred in it
        .padding(.horizontal, margin - (RDimension.sizeTouchTarget - RDimension.sizeControlSmall) / 2)
        .frame(minHeight: RDimension.sizeNavBar)
        .padding(.top, compactHeight ? RDimension.space2 : RDimension.space4)
    }

    // MARK: - The column

    /// Orb, then the words, centred in the space between the bar and the composer (Paper 1F7X-0).
    private var column: some View {
        VStack(spacing: compactHeight ? RDimension.space6 : RDimension.space8) {
            PrivacyOrb(compact: compactOrb)
                .rAppear(index: 0)
            VStack(spacing: RDimension.space3) {
                Text(PrivacyModel.title)
                    .rText(.inkTitle)
                    .foregroundStyle(RColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityAction(named: PrivacyModel.moveOnAction) { model.moveOn() }
                    .accessibilityIdentifier("privacy.title")
                    .rBalancedLines()
                    .rAppear(index: 1)
                Text(PrivacyModel.body)
                    .rText(.purposeDescription)
                    .foregroundStyle(RColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAction(named: PrivacyModel.moveOnAction) { model.moveOn() }
                    .accessibilityIdentifier("privacy.body")
                    .rBalancedLines()
                    .rAppear(index: 2)
                if PrivacyModel.policyURL != nil {
                    policyLink
                        .rAppear(index: 3)
                }
            }
            .frame(maxWidth: RDimension.layoutReadingWidth)
        }
        .padding(.horizontal, margin)
        // Paper 1F7X-0 pads below only, so the column sits a little above the middle
        .padding(.bottom, compactHeight ? RDimension.space6 : RDimension.space8)
    }

    private var policyLink: some View {
        Button(PrivacyModel.policyLink) { model.openPolicy() }
            .rText(.textMd)
            .foregroundStyle(RColor.textLink)
            .multilineTextAlignment(.center)
            .frame(minHeight: RDimension.sizeTouchTarget)
            .padding(.horizontal, RDimension.space3)
            .contentShape(Rectangle())
            .rPress(small: true)
            .accessibilityRemoveTraits(.isButton)
            .accessibilityAddTraits(.isLink)
            .accessibilityHint("opens in a browser sheet")
            .accessibilityIdentifier("privacy.policy")
    }

    // MARK: - The composer

    /// Retro speaking (Paper 1F7K-0). A tap on the bar ("double-tap to cut in" for VoiceOver) moves
    /// on, like a tap anywhere; so does its mic-off corner (there is nothing to type on this page),
    /// so VoiceOver calls the corner "move on".
    private var bottom: some View {
        RVoiceComposer(
            mode: composerMode,
            text: .constant(""),
            onInterrupt: { model.tapAnywhere() },
            speakingCornerLabel: PrivacyModel.moveOnAction
        )
        // the inset proposes the full height; the bar keeps its own
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAction(named: PrivacyModel.moveOnAction) { model.moveOn() }
        .accessibilityIdentifier("privacy.composer")
        .padding(.horizontal, margin)
        // Paper 1F7J-0: nothing above the bar; below it, the questions' 8 over the home indicator
        .padding(.bottom, RDimension.space2)
    }

    private var composerMode: Binding<RVoiceComposer.Mode> {
        Binding(
            get: { .speaking },
            set: { mode in
                if mode != .speaking {
                    model.tapAnywhere()
                }
            }
        )
    }

    private var policyShown: Binding<Bool> {
        Binding(
            get: { model.isPolicyOpen },
            set: { shown in
                if !shown {
                    model.policyClosed()
                }
            }
        )
    }
}

// MARK: - The orb

/// The lock in a raised lit disc inside two soft sky rings (Paper 1F82-0 / 1F83-0 / 1F84-0):
/// a 176 radial wash with a wide sky glow, a 128 ring with a top highlight and a sky shadow under
/// it, and the 76 lit disc. Compact keeps the ring and the disc. Decorative: hidden from VoiceOver.
struct PrivacyOrb: View {
    var compact = false

    private static let outer: CGFloat = 176 // literal-ok: Paper 1F82-0
    private static let ring: CGFloat = 128 // literal-ok: Paper 1F83-0
    private static let disc: CGFloat = 76 // literal-ok: Paper 1F84-0

    var body: some View {
        ZStack {
            if !compact {
                outerWash
            }
            ring
            disc
        }
        .frame(width: compact ? Self.ring : Self.outer, height: compact ? Self.ring : Self.outer)
        .accessibilityHidden(true)
    }

    /// Paper's radial (farthest corner): orb.washCentre easing to orb.washEdge by 62%, then
    /// nothing, over the wide orb.glow (0 0 70 −10).
    private var outerWash: some View {
        Circle()
            .fill(RadialGradient(
                stops: [
                    .init(color: RColor.orbWashCentre, location: 0),
                    .init(color: RColor.orbWashEdge, location: 0.62), // literal-ok: Paper stop position
                    .init(color: .clear, location: 1),
                ],
                center: .center,
                startRadius: 0,
                endRadius: Self.outer / 2 * 2.squareRoot() // literal-ok: farthest corner of the box
            ))
            .frame(width: Self.outer, height: Self.outer)
            .background {
                OutsideGlow(
                    diameter: Self.outer,
                    color: RColor.orbGlow,
                    blur: 35, // literal-ok: Paper blur 70
                    spread: -10, // literal-ok: Paper spread
                    y: 0
                )
            }
    }

    /// The ring (Paper 1F83-0): inset 0 1 0 depth.stroke.innerTop, inset 0.5 orb.ringEdge, and
    /// orb.ringShadow cast below it (0 14 34 −10).
    private var ring: some View {
        InsetShadow(diameter: Self.ring, color: RColor.depthStrokeInnerTop, blur: 0, y: RDimension.sizeBorderDefault)
            .overlay {
                Circle().strokeBorder(RColor.orbRingEdge, lineWidth: RDimension.sizeBorderHairline)
            }
            .frame(width: Self.ring, height: Self.ring)
            .background {
                OutsideGlow(
                    diameter: Self.ring,
                    color: RColor.orbRingShadow,
                    blur: 17, // literal-ok: Paper blur 34
                    spread: -10, // literal-ok: Paper spread
                    y: 14 // literal-ok: Paper offset
                )
            }
    }

    /// The one lit object on the page (Paper 1F84-0), its box-shadows one for one: the primary
    /// gradient; inset rim 0 1.5 0, edge 0 −1 1.5, bloom 0 0 14; an outer 1 ring; halos 0 0 26 −2
    /// and 0 12 28 −8. Then Paper's own lock, keyhole and all (1F85-0, 30 on the 24 grid).
    private var disc: some View {
        Circle()
            .fill(LinearGradient(
                colors: [RColor.glowPrimaryGradientTop, RColor.glowPrimaryGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            ))
            .overlay { InsetShadow(diameter: Self.disc, color: RColor.glowPrimaryBloomLit, blur: 7, y: 0) } // literal-ok: Paper blur 14
            .overlay { InsetShadow(diameter: Self.disc, color: RColor.glowPrimaryEdge, blur: 0.75, y: -1) } // literal-ok: Paper 0 −1 1.5
            .overlay { InsetShadow(diameter: Self.disc, color: RColor.glowPrimaryRim, blur: 0, y: 1.5) } // literal-ok: Paper 0 1.5 0
            .overlay {
                Circle()
                    .inset(by: -RDimension.sizeBorderDefault / 2)
                    .stroke(RColor.glowPrimaryRing, lineWidth: RDimension.sizeBorderDefault)
            }
            .frame(width: Self.disc, height: Self.disc)
            .background {
                ZStack {
                    OutsideGlow(diameter: Self.disc, color: RColor.glowPrimaryHalo, blur: 13, spread: -2, y: 0) // literal-ok: Paper 0 0 26 −2
                    OutsideGlow(diameter: Self.disc, color: RColor.glowPrimaryHalo, blur: 14, spread: -8, y: 12) // literal-ok: Paper 0 12 28 −8
                }
            }
            .overlay {
                Image("privacy-lock")
                    .renderingMode(.template)
                    .resizable()
                    .foregroundStyle(RColor.glowPrimaryForeground)
                    .frame(width: Self.lock, height: Self.lock)
            }
    }

    private static let lock: CGFloat = 30 // literal-ok: Paper 1F85-0
}

/// A CSS inset box-shadow on a circle: everything outside a copy of the circle moved by `y`,
/// blurred, and seen only inside the circle (a crescent for an offset, a soft inner bloom for none).
private struct InsetShadow: View {
    let diameter: CGFloat
    let color: Color
    let blur: CGFloat
    let y: CGFloat

    var body: some View {
        // the shadow comes from outside the circle: room for the blur and the offset
        let canvas = diameter + 4 * blur + 2 * abs(y) + 2 // literal-ok: geometry
        Rectangle()
            .fill(color)
            .frame(width: canvas, height: canvas)
            .mask {
                Rectangle()
                    .overlay {
                        Circle()
                            .frame(width: diameter, height: diameter)
                            .offset(y: y)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
            }
            .blur(radius: blur)
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
            .allowsHitTesting(false)
    }
}

/// A CSS outer box-shadow: a blurred, spread and offset copy of the circle, drawn only outside it
/// (CSS never paints an outer shadow under the box), so the inside of a ring stays clear.
private struct OutsideGlow: View {
    let diameter: CGFloat
    let color: Color
    let blur: CGFloat
    let spread: CGFloat
    let y: CGFloat

    var body: some View {
        // room for the blur on every side, and the offset
        let canvas = diameter + 4 * blur + 2 * abs(y) // literal-ok: geometry
        let shadow = diameter + 2 * spread // literal-ok: geometry
        Circle()
            .fill(color)
            .frame(width: shadow, height: shadow)
            .offset(y: y)
            .blur(radius: blur)
            .frame(width: canvas, height: canvas)
            .mask {
                Rectangle()
                    .overlay {
                        Circle()
                            .frame(width: diameter, height: diameter)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
            }
            .allowsHitTesting(false)
    }
}

// MARK: - The policy sheet

/// The privacy policy in Safari's own reader, as a sheet. Done (or a swipe down) closes it.
private struct PolicyBrowser: UIViewControllerRepresentable {
    let url: URL
    let onDone: () -> Void

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .done
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_: SFSafariViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDone: onDone)
    }

    @MainActor
    final class Coordinator: NSObject, @MainActor SFSafariViewControllerDelegate {
        let onDone: () -> Void

        init(onDone: @escaping () -> Void) {
            self.onDone = onDone
        }

        func safariViewControllerDidFinish(_: SFSafariViewController) {
            onDone()
        }
    }
}
