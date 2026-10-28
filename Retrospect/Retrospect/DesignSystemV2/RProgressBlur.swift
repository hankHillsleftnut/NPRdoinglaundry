//
//  RProgressBlur.swift
//  UI0.1: the progressive blur at scroll edges (docs/design/progressive-blur.md, which wins over
//  Paper: Paper fakes it with stacked copies). One blur whose strength rises across a band at
//  the edge, so content softens as it leaves, with no line where the blur starts and no grey.
//
//  iOS 26: the system's soft scroll edge, plus the preset's tint on top.
//  iOS 18: one UIVisualEffectView with its tint removed, masked by an eased ramp (t²), plus the
//  tint. Never the private variable-blur filter, stacked bands or a blurred copy of the content.
//  Reduce Transparency: no blur; the tint only, opaque at the outer edge.
//
import SwiftUI
import UIKit

/// A place across a band, from its inner edge to its outer edge.
enum RBandPosition: Hashable, Sendable {
    /// A fraction of the band: 0 at the inner edge, 1 at the outer edge.
    case fraction(CGFloat)
    /// This many points in from the outer edge, whatever the band's height.
    case fromOuterEdge(CGFloat)

    func resolved(in band: CGFloat) -> CGFloat {
        switch self {
        case let .fraction(value):
            min(max(value, 0), 1)
        case let .fromOuterEdge(points):
            band > 0 ? min(max(1 - points / band, 0), 1) : 0
        }
    }
}

/// How the colour wash over a band runs: clear (at `startOpacity`) until `from`, rising to
/// `endOpacity` by `solidFrom`, then steady to the outer edge. Colours are stored opaque, with
/// their opacities apart, so Reduce Transparency can really end at full strength.
struct RBlurTint: Hashable, Sendable {
    var start: Color
    var startOpacity: Double
    var end: Color
    var endOpacity: Double
    var from: RBandPosition
    var solidFrom: RBandPosition
    /// How the opacity runs between `from` and `solidFrom`.
    var curve: RTintCurve = .straight
}

/// The shape of a tint's rise across its band.
enum RTintCurve: Hashable, Sendable {
    /// Two stops: a straight ramp.
    case straight
    /// `gradient.fadeToCanvas` (principles/gradients.md rule 5): 13 stops on a smoothstep curve, so
    /// there is no visible line where the fade starts or where it reaches the colour.
    case fadeToCanvas

    /// The opacity at each stop, 0 at the start to 1 at the end, evenly spaced.
    var stops: [Double] {
        switch self {
        case .straight:
            [0, 1]
        case .fadeToCanvas:
            // the token's recipe, transcribed (gradients are hand-built Swift: to-swift.mjs leaves them)
            [0, 0.013, 0.057, 0.13, 0.227, 0.341, 0.467, 0.595, 0.719, 0.83, 0.919, 0.978, 1]
        }
    }
}

/// One edge's progressive blur. Presets carry the values from progressive-blur.md as tokens.
struct RProgressiveBlurStyle: Hashable, Sendable {
    var edge: VerticalEdge
    var band: CGFloat
    /// The band on short screens (`layout.compactHeight`); nil keeps `band`.
    var bandCompact: CGFloat?
    var maxRadius: CGFloat
    var saturation: Double
    var tint: RBlurTint?
    /// Draws the blur with the masked material on every iOS, never the system soft edge. For a band
    /// that must sit above a bar: the system edge draws only inside a scroll view's own inset, and a
    /// page that ends at the bar's top has none there.
    var maskedBlur = false

    /// The shell's tab bar (TABBAR.blend, founder 27 Oct: content must never be cut by the bar; it
    /// dissolves into it like the system's bars; tab-bar.md: "starts 90pt above the tabs"). Over
    /// `blur.tabBlend.rise` above where the page ends, the blur ramps t² to `blur.tab.max` (colour
    /// kept: `blur.tab.saturation`) while the canvas eases in on `gradient.fadeToCanvas` to opaque,
    /// the canvas the bar sits on. In the shell every page's `.tabEdge` becomes this
    /// (`\.rShellTabEdge`), so there is one edge, the shell's, and it sits wherever the page's scroll
    /// ends (the bar's top, the journal's composer, the mini-player's room).
    static let tabBarBlend = Self(
        edge: .bottom,
        band: RDimension.blurTabBlendRise,
        bandCompact: RDimension.blurTabBlendRiseCompact,
        maxRadius: RDimension.blurTabMax,
        saturation: RNumber.blurTabSaturation,
        tint: RBlurTint(
            start: RColor.backgroundCanvas,
            startOpacity: 0,
            end: RColor.backgroundCanvas,
            endOpacity: 1,
            from: .fraction(0),
            solidFrom: .fraction(1),
            curve: .fadeToCanvas
        ),
        maskedBlur: true
    )

    /// Tab screens: above the tab bar. Colour must survive (saturation up), the canvas tint
    /// covers only the bottom of the band, and under the bar itself the page is opaque canvas.
    static let tabEdge = Self(
        edge: .bottom,
        band: RDimension.blurTabBand,
        bandCompact: RDimension.blurTabBandCompact,
        maxRadius: RDimension.blurTabMax,
        saturation: RNumber.blurTabSaturation,
        tint: RBlurTint(
            start: RColor.backgroundCanvas,
            startOpacity: 0,
            end: RColor.backgroundCanvas,
            endOpacity: RNumber.opacityDisabled,
            from: .fromOuterEdge(RDimension.blurTabTint),
            solidFrom: .fraction(1)
        )
    )

    /// The journal's top edge under the bar; its band grows with scroll (pass `band` from the offset).
    static let journalTop = Self(
        edge: .top,
        band: RDimension.blurJournalTopBand,
        bandCompact: nil,
        maxRadius: RDimension.blurJournalTopMax,
        saturation: 1,
        tint: RBlurTint(
            start: RColor.backgroundCanvas,
            startOpacity: 0,
            end: RColor.backgroundCanvas,
            endOpacity: 1,
            from: .fraction(0),
            solidFrom: .fraction(1)
        )
    )

    /// The player transcript's top: the sheet colour rises over the band's outer part.
    static let transcriptTop = Self(
        edge: .top,
        band: RDimension.blurTranscriptTopBand,
        bandCompact: RDimension.blurTranscriptTopBandCompact,
        maxRadius: RDimension.blurTranscriptTopMax,
        saturation: 1,
        tint: RBlurTint(
            start: RColor.backgroundRaised,
            startOpacity: 0,
            end: RColor.backgroundRaised,
            endOpacity: 1,
            from: .fraction(1 - RNumber.blurTranscriptTopTint),
            solidFrom: .fraction(1)
        )
    )

    /// The player transcript's bottom, into the transport: the sheet colour is solid at the edge.
    static let transcriptBottom = Self(
        edge: .bottom,
        band: RDimension.blurTranscriptBottomBand,
        bandCompact: RDimension.blurTranscriptBottomBandCompact,
        maxRadius: RDimension.blurTranscriptBottomMax,
        saturation: 1,
        tint: RBlurTint(
            start: RColor.backgroundRaised,
            startOpacity: 0,
            end: RColor.backgroundRaised,
            endOpacity: 1,
            from: .fraction(0),
            solidFrom: .fraction(1 - RNumber.blurTranscriptBottomTint)
        )
    )

    /// The drawer's foot: canvas easing into the underlay.
    static let drawerFoot = Self(
        edge: .bottom,
        band: RDimension.blurDrawerFootBand,
        bandCompact: nil,
        maxRadius: RDimension.blurDrawerFootMax,
        saturation: 1,
        tint: RBlurTint(
            start: RColor.backgroundCanvas,
            startOpacity: 0,
            end: RColor.backgroundUnderlay,
            endOpacity: 1,
            from: .fraction(0),
            solidFrom: .fraction(1)
        )
    )
}

extension View {
    /// A progressive blur at one edge of this view, usually a scroll view's container.
    /// `active: false` takes the blur away (both paths) when nothing is under the band; drive it
    /// from `onScrollGeometryChange`, so the edge costs nothing at rest.
    func rProgressiveBlur(_ style: RProgressiveBlurStyle, active: Bool = true) -> some View {
        modifier(RProgressiveBlurModifier(style: style, active: active))
    }

    /// Spelled out, for a surface without a preset.
    func rProgressiveBlur(
        edge: VerticalEdge,
        band: CGFloat,
        maxRadius: CGFloat,
        saturation: Double = 1,
        tint: RBlurTint?,
        active: Bool = true
    ) -> some View {
        rProgressiveBlur(
            RProgressiveBlurStyle(edge: edge, band: band, bandCompact: nil, maxRadius: maxRadius, saturation: saturation, tint: tint),
            active: active
        )
    }

    /// Reads the window's height once at the root and tells every view below whether the screen
    /// is short (`layout.compactHeight`), from the first frame. Apply it at the app's root.
    func rReadsScreenHeight() -> some View {
        GeometryReader { proxy in
            let height = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            // Fill the reader and centre, as the root laid out before it was wrapped.
            self.frame(maxWidth: .infinity, maxHeight: .infinity)
                .environment(\.rCompactHeight, height < RDimension.layoutCompactHeight)
        }
    }
}

extension EnvironmentValues {
    /// A short screen (iPhone SE): compact bands and tighter rhythm. Set by `rReadsScreenHeight()`.
    @Entry var rCompactHeight = false
    /// Forces the iOS 18 path on iOS 26, so the two can be compared side by side (the gallery).
    @Entry var rForceBlurFallback = false
    /// Set by the shell: what a page's `.tabEdge` draws inside it (the shell's `tabBarBlend`, which
    /// ends opaque at the bar). nil outside the shell, where `.tabEdge` is itself.
    @Entry var rShellTabEdge: RProgressiveBlurStyle?
}

private struct RProgressiveBlurModifier: ViewModifier {
    let requested: RProgressiveBlurStyle
    let active: Bool

    init(style: RProgressiveBlurStyle, active: Bool) {
        requested = style
        self.active = active
    }

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.rForceBlurFallback) private var forceFallback
    @Environment(\.rCompactHeight) private var compact
    @Environment(\.rShellTabEdge) private var shellTabEdge

    /// The tab edge inside the shell is the shell's; every other style is its own.
    private var style: RProgressiveBlurStyle {
        requested == .tabEdge ? (shellTabEdge ?? requested) : requested
    }

    private var band: CGFloat {
        compact ? (style.bandCompact ?? style.band) : style.band
    }

    private var systemEdgeAvailable: Bool {
        if #available(iOS 26, *) {
            return true
        }
        return false
    }

    func body(content: Content) -> some View {
        let blurs = active && !reduceTransparency
        let usesSystemEdge = systemEdgeAvailable && !forceFallback && !style.maskedBlur
        content
            .modifier(SystemSoftEdge(edge: style.edge, shown: blurs && usesSystemEdge))
            .overlay(alignment: style.edge == .top ? .top : .bottom) {
                RBlurBand(
                    style: style,
                    band: band,
                    blur: blurs && !usesSystemEdge,
                    reduceTransparency: reduceTransparency
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
    }
}

/// iOS 26's own soft edge on the scroll views inside. The style is always applied and only
/// shown or hidden, so the content's identity (and its scroll position) never changes.
private struct SystemSoftEdge: ViewModifier {
    let edge: VerticalEdge
    let shown: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            let edges: Edge.Set = edge == .top ? .top : .bottom
            content
                .scrollEdgeEffectStyle(.soft, for: edges)
                .scrollEdgeEffectHidden(!shown, for: edges)
        } else {
            content
        }
    }
}

/// The band itself: the masked blur (iOS 18 path) under the tint. The blur view stays in place
/// and only switches its effect off, so nothing is rebuilt as the band activates.
private struct RBlurBand: View {
    let style: RProgressiveBlurStyle
    let band: CGFloat
    let blur: Bool
    let reduceTransparency: Bool

    var body: some View {
        ZStack {
            RMaskedBlur(edge: style.edge, maxRadius: style.maxRadius, active: blur)
                .saturation(blur ? style.saturation : 1)
            if let tint = tintForBand {
                tintGradient(tint)
            }
        }
        .frame(height: band)
        .frame(maxWidth: .infinity)
    }

    /// With Reduce Transparency the tint carries the edge alone, so it must end fully opaque.
    private var tintForBand: RBlurTint? {
        guard reduceTransparency else { return style.tint }
        var tint = style.tint ?? RBlurTint(
            start: RColor.backgroundCanvas,
            startOpacity: 0,
            end: RColor.backgroundCanvas,
            endOpacity: 1,
            from: .fraction(0),
            solidFrom: .fraction(1)
        )
        tint.endOpacity = 1
        return tint
    }

    private func tintGradient(_ tint: RBlurTint) -> some View {
        let from = tint.from.resolved(in: band)
        let solidFrom = max(from, tint.solidFrom.resolved(in: band))
        // Stops run from the band's inner edge (0) to its outer edge (1); between `from` and
        // `solidFrom` the curve's stops are spread evenly (two for linear, 13 for fadeToCanvas).
        let curve = tint.curve.stops
        let ramp = curve.enumerated().map { index, opacity in
            let t = curve.count > 1 ? CGFloat(index) / CGFloat(curve.count - 1) : 1
            // the start colour sits only at the ramp's first stop, as it did with two stops
            let color = index == 0 ? tint.start : tint.end
            return Gradient.Stop(
                color: color.opacity(tint.startOpacity + (tint.endOpacity - tint.startOpacity) * opacity),
                location: from + (solidFrom - from) * t
            )
        }
        let stops = [Gradient.Stop(color: tint.start.opacity(tint.startOpacity), location: 0)]
            + ramp
            + [Gradient.Stop(color: tint.end.opacity(tint.endOpacity), location: 1)]
        return LinearGradient(
            stops: stops,
            startPoint: style.edge == .bottom ? .top : .bottom,
            endPoint: style.edge == .bottom ? .bottom : .top
        )
    }
}

/// One blur view, masked by the eased ramp blur(t) = max × t², so the first third of the band
/// stays almost sharp. The material's own tint and vibrancy are cleared so it only blurs
/// (a tinted material turns the edge grey, which the founder flagged as wrong).
private struct RMaskedBlur: UIViewRepresentable {
    let edge: VerticalEdge
    let maxRadius: CGFloat
    let active: Bool

    func makeUIView(context _: Context) -> RMaskedBlurView {
        RMaskedBlurView()
    }

    func updateUIView(_ view: RMaskedBlurView, context _: Context) {
        view.configure(edge: edge, maxRadius: active ? maxRadius : 0)
    }
}

final class RMaskedBlurView: UIView {
    /// The radius the thinnest material blurs at in full, **assumed** (not measured; the gallery
    /// checks it against the spec). A paused animator scales the effect down to `maxRadius` from
    /// it: public API, unlike the private variable-blur filter.
    private static let materialRadius: CGFloat = 30 // literal-ok: assumed material strength
    /// Ramp samples for the mask: enough that no step shows across a 140pt band.
    private static let rampSteps = 12 // literal-ok: mask resolution, not a size

    private let effectView = UIVisualEffectView(effect: nil)
    private let ramp = CAGradientLayer()
    private var animator: UIViewPropertyAnimator?
    private var edge: VerticalEdge = .bottom
    private var maxRadius: CGFloat = 0
    private var configured = false
    private var foregroundObserver: NSObjectProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        effectView.frame = bounds
        effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(effectView)
        layer.mask = ramp
        // Paused animators are dropped when the app goes to the background; arm it again.
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.arm() }
        }
        // Light and dark rebuild the material's layers, tint included: clear it again.
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: RMaskedBlurView, _: UITraitCollection) in
            view.arm()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("RMaskedBlurView is built in code")
    }

    deinit {
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
        animator?.stopAnimation(true)
    }

    func configure(edge: VerticalEdge, maxRadius: CGFloat) {
        guard !configured || edge != self.edge || maxRadius != self.maxRadius else { return }
        configured = true
        self.edge = edge
        self.maxRadius = maxRadius

        // t from the band's inner edge (0) to its outer edge (1); strength t².
        let steps = (0 ... Self.rampSteps).map { CGFloat($0) / CGFloat(Self.rampSteps) }
        ramp.colors = steps.map { UIColor.black.withAlphaComponent($0 * $0).cgColor }
        ramp.locations = steps.map { NSNumber(value: Double($0)) }
        ramp.startPoint = CGPoint(x: 0.5, y: edge == .bottom ? 0 : 1)
        ramp.endPoint = CGPoint(x: 0.5, y: edge == .bottom ? 1 : 0)
        arm()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            arm()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        ramp.frame = bounds
        clearMaterialTint()
    }

    /// Sets the blur's strength: a paused animator at `maxRadius / materialRadius`, or no
    /// effect at all when the band is inactive.
    private func arm() {
        animator?.stopAnimation(true)
        animator = nil
        effectView.effect = nil
        guard maxRadius > 0 else { return }
        // The animator never plays: it's paused at a fraction, which sets the blur's strength.
        let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) { [effectView] in // literal-ok: paused
            effectView.effect = UIBlurEffect(style: .systemUltraThinMaterial)
        }
        animator.pausesOnCompletion = true
        animator.fractionComplete = min(1, maxRadius / Self.materialRadius)
        self.animator = animator
        clearMaterialTint()
    }

    /// The material's colour layers sit above its backdrop: clear them so only the blur remains.
    private func clearMaterialTint() {
        for subview in effectView.subviews.dropFirst() {
            subview.backgroundColor = .clear
        }
    }
}
