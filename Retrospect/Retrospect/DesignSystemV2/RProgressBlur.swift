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

/// How the colour wash over a band runs, as fractions of the band from its inner edge (0) to
/// its outer edge (1): clear until `from`, rising to full by `solidFrom`, solid to the edge.
struct RBlurTint: Hashable, Sendable {
    var start: Color
    var end: Color
    var from: CGFloat
    var solidFrom: CGFloat
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

    /// Tab screens: above the tab bar. Colour must survive (saturation up), the canvas tint
    /// covers only the bottom of the band, and under the bar itself the page is opaque canvas.
    static let tabEdge = Self(
        edge: .bottom,
        band: RDimension.blurTabBand,
        bandCompact: RDimension.blurTabBandCompact,
        maxRadius: RDimension.blurTabMax,
        saturation: RNumber.blurTabSaturation,
        tint: RBlurTint(
            start: RColor.backgroundCanvas.opacity(0),
            end: RColor.backgroundCanvas.opacity(RNumber.opacityDisabled),
            from: 1 - RDimension.blurTabTint / RDimension.blurTabBand,
            solidFrom: 1
        )
    )

    /// The journal's top edge under the bar; its band grows with scroll (pass `band` from the offset).
    static let journalTop = Self(
        edge: .top,
        band: RDimension.blurJournalTopBand,
        bandCompact: nil,
        maxRadius: RDimension.blurJournalTopMax,
        saturation: 1,
        tint: RBlurTint(start: RColor.backgroundCanvas.opacity(0), end: RColor.backgroundCanvas, from: 0, solidFrom: 1)
    )

    /// The player transcript's top: the sheet colour rises over the band's outer part.
    static let transcriptTop = Self(
        edge: .top,
        band: RDimension.blurTranscriptTopBand,
        bandCompact: RDimension.blurTranscriptTopBandCompact,
        maxRadius: RDimension.blurTranscriptTopMax,
        saturation: 1,
        tint: RBlurTint(
            start: RColor.backgroundRaised.opacity(0),
            end: RColor.backgroundRaised,
            from: 1 - RNumber.blurTranscriptTopTint,
            solidFrom: 1
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
            start: RColor.backgroundRaised.opacity(0),
            end: RColor.backgroundRaised,
            from: 0,
            solidFrom: 1 - RNumber.blurTranscriptBottomTint
        )
    )

    /// The drawer's foot: canvas easing into the underlay.
    static let drawerFoot = Self(
        edge: .bottom,
        band: RDimension.blurDrawerFootBand,
        bandCompact: nil,
        maxRadius: RDimension.blurDrawerFootMax,
        saturation: 1,
        tint: RBlurTint(start: RColor.backgroundCanvas.opacity(0), end: RColor.backgroundUnderlay, from: 0, solidFrom: 1)
    )
}

extension View {
    /// A progressive blur at one edge of this view, usually a scroll view's container.
    /// `active: false` takes the blur away when nothing is under the band (drive it from
    /// `onScrollGeometryChange`), so the edge costs nothing at rest.
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
}

extension EnvironmentValues {
    /// Forces the iOS 18 path on iOS 26, so the two can be compared side by side (the gallery).
    @Entry var rForceBlurFallback = false
}

private struct RProgressiveBlurModifier: ViewModifier {
    let style: RProgressiveBlurStyle
    let active: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.rForceBlurFallback) private var forceFallback
    @State private var compact = false

    private var band: CGFloat {
        compact ? (style.bandCompact ?? style.band) : style.band
    }

    private var useSystemEdge: Bool {
        if #available(iOS 26, *) {
            return !forceFallback
        }
        return false
    }

    func body(content: Content) -> some View {
        content
            .modifier(SystemSoftEdge(edge: style.edge, enabled: useSystemEdge && active && !reduceTransparency))
            .overlay(alignment: style.edge == .top ? .top : .bottom) {
                RBlurBand(
                    style: style,
                    band: band,
                    blur: active && !reduceTransparency && !useSystemEdge,
                    reduceTransparency: reduceTransparency
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .onGeometryChange(for: Bool.self) { $0.size.height < RDimension.layoutCompactHeight } action: { compact = $0 }
    }
}

/// iOS 26's own soft edge on the scroll views inside.
private struct SystemSoftEdge: ViewModifier {
    let edge: VerticalEdge
    let enabled: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26, *), enabled {
            content.scrollEdgeEffectStyle(.soft, for: edge == .top ? .top : .bottom)
        } else {
            content
        }
    }
}

/// The band itself: the masked blur (iOS 18 path) under the tint.
private struct RBlurBand: View {
    let style: RProgressiveBlurStyle
    let band: CGFloat
    let blur: Bool
    let reduceTransparency: Bool

    var body: some View {
        ZStack {
            if blur {
                RMaskedBlur(edge: style.edge, maxRadius: style.maxRadius)
                    .saturation(style.saturation)
            }
            if let tint = tintForBand {
                tintGradient(tint)
            }
        }
        .frame(height: band)
        .frame(maxWidth: .infinity)
    }

    /// With Reduce Transparency the tint carries the edge alone, so it must end opaque.
    private var tintForBand: RBlurTint? {
        guard reduceTransparency else { return style.tint }
        let base = style.tint ?? RBlurTint(start: RColor.backgroundCanvas, end: RColor.backgroundCanvas, from: 0, solidFrom: 1)
        return RBlurTint(start: base.start.opacity(0), end: base.end.opacity(1), from: base.from, solidFrom: base.solidFrom)
    }

    private func tintGradient(_ tint: RBlurTint) -> some View {
        // Stops run from the band's inner edge (0) to its outer edge (1).
        let stops = [
            Gradient.Stop(color: tint.start, location: 0),
            Gradient.Stop(color: tint.start, location: tint.from),
            Gradient.Stop(color: tint.end, location: max(tint.from, tint.solidFrom)),
            Gradient.Stop(color: tint.end, location: 1),
        ]
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

    func makeUIView(context _: Context) -> RMaskedBlurView {
        RMaskedBlurView()
    }

    func updateUIView(_ view: RMaskedBlurView, context _: Context) {
        view.configure(edge: edge, maxRadius: maxRadius)
    }
}

final class RMaskedBlurView: UIView {
    /// The radius the thinnest material blurs at in full. A paused animator scales the effect
    /// down to `maxRadius` from it: public API, unlike the private variable-blur filter.
    private static let materialRadius: CGFloat = 30 // literal-ok: measured strength of .systemUltraThinMaterial
    /// Ramp samples for the mask: enough that no step shows across a 140pt band.
    private static let rampSteps = 12 // literal-ok: mask resolution, not a size

    private let effectView = UIVisualEffectView(effect: nil)
    private let ramp = CAGradientLayer()
    private var animator: UIViewPropertyAnimator?
    private var configured: (edge: VerticalEdge, radius: CGFloat)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        effectView.frame = bounds
        effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(effectView)
        layer.mask = ramp
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("RMaskedBlurView is built in code")
    }

    deinit {
        animator?.stopAnimation(true)
    }

    func configure(edge: VerticalEdge, maxRadius: CGFloat) {
        if let configured, configured.edge == edge, configured.radius == maxRadius {
            return
        }
        configured = (edge, maxRadius)

        animator?.stopAnimation(true)
        effectView.effect = nil
        // The animator never plays: it's paused at a fraction, which sets the blur's strength.
        let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) { [effectView] in // literal-ok: paused
            effectView.effect = UIBlurEffect(style: .systemUltraThinMaterial)
        }
        animator.pausesOnCompletion = true
        animator.fractionComplete = min(1, maxRadius / Self.materialRadius)
        self.animator = animator

        // t from the band's inner edge (0) to its outer edge (1); strength t².
        let steps = (0 ... Self.rampSteps).map { CGFloat($0) / CGFloat(Self.rampSteps) }
        ramp.colors = steps.map { UIColor.black.withAlphaComponent($0 * $0).cgColor }
        ramp.locations = steps.map { NSNumber(value: Double($0)) }
        ramp.startPoint = CGPoint(x: 0.5, y: edge == .bottom ? 0 : 1)
        ramp.endPoint = CGPoint(x: 0.5, y: edge == .bottom ? 1 : 0)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        ramp.frame = bounds
        // The material's colour layers sit above its backdrop: clear them so only the blur remains.
        for subview in effectView.subviews.dropFirst() {
            subview.backgroundColor = .clear
        }
    }
}
