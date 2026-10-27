import SwiftUI

/// Animated "drawing" loader for the Understanding phase.
///
/// Keeps the REAL brush logo (`retrospect-loading-mark`) and reveals it
/// progressively by clipping it to a wide stroke that sweeps along a
/// hand-authored centerline — the "one line" that draws the face:
/// top → head outline → nose chevron → comma eye. The 180°-rotated
/// counterpart is revealed from the opposite end at the same time (the mark
/// has point symmetry about its center), so both halves draw as mirror
/// counterparts. The whole thing loops draw → un-draw.
///
/// The sweep is driven by `TimelineView(.animation)` rather than a
/// `repeatForever` state animation: the host screen re-renders on its own
/// timers (processing dots, wondering swaps), which re-times an in-flight
/// repeating animation. Clipping inside one `Canvas` also avoids rasterizing a
/// SwiftUI `.mask` layer, plus a `rotationEffect` layer, on every frame.
///
/// The centerline coordinates live in `MarkHalfPath` in the mark's native
/// 112×86 viewBox space, so they're easy to nudge against the art.
struct RetrospectLoadingMark: View {
    /// Width in points; height derives from the 112×86 aspect.
    var width: CGFloat = 132
    /// One full draw (or un-draw) sweep, seconds.
    var duration: Double = 1.7
    /// Reveal-clip stroke width in viewBox units. Must be ≥ the brush
    /// thickness (~7) so the stroke fully uncovers the brush as it passes.
    var revealWidth: CGFloat = 15

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let box = CGSize(width: 112, height: 86)
    private var height: CGFloat {
        width * Self.box.height / Self.box.width
    }

    var body: some View {
        Group {
            if reduceMotion {
                mark(progress: 1)
            } else {
                TimelineView(.animation) { context in
                    mark(progress: Self.sweep(at: context.date, duration: duration))
                }
            }
        }
        .frame(width: width, height: height)
        .accessibilityElement()
        .accessibilityLabel("Loading")
    }

    /// Sinusoidal draw ↔ un-draw across a `2 * duration` cycle. Continuous in
    /// both value and velocity through the loop seam, so the sweep breathes
    /// instead of stopping dead and restarting at every turnaround.
    private static func sweep(at date: Date, duration: Double) -> CGFloat {
        let cycle = max(duration, 0.1) * 2
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle) / cycle
        return CGFloat((1 - cos(t * 2 * .pi)) / 2)
    }

    private func mark(progress: CGFloat) -> some View {
        Canvas { ctx, size in
            let image = ctx.resolve(Image("retrospect-loading-mark"))
            let rect = CGRect(origin: .zero, size: size)
            let style = StrokeStyle(
                lineWidth: revealWidth * size.width / Self.box.width,
                lineCap: .round,
                lineJoin: .round
            )
            let reveal = MarkHalfPath.reveal(in: rect, progress: progress).strokedPath(style)
            // Half B is the same reveal turned 180° about the center, applied to
            // the path rather than the layer so the clip and the image stay in
            // the same coordinate space.
            let halves = [reveal, reveal.applying(MarkHalfPath.pointReflection(in: rect))]

            for half in halves {
                ctx.drawLayer { layer in
                    layer.clip(to: half)
                    layer.draw(image, in: rect)
                }
            }
        }
    }
}

/// One half's centerline in the mark's 112×86 space.
/// `trim(0→1)` traverses it in draw order: frame loop (top → left edge → nose
/// chevron → chin → bottom → right edge → back to top), then the comma eye.
struct MarkHalfPath: Shape {
    func path(in rect: CGRect) -> Path {
        Self.reveal(in: rect, progress: 1)
    }

    /// Trim the outline and the comma eye together. They are disjoint, so the
    /// reveal head does step between them, but the gap is under one reveal
    /// stroke width and the caps overlap: trimming them on separate clocks
    /// measured worse, because the comma's round cap pops in away from the head.
    static func reveal(in rect: CGRect, progress: CGFloat) -> Path {
        var path = outline
        path.addPath(commaEye)
        return path.trimmedPath(from: 0, to: progress).applying(fit(rect))
    }

    /// 180° about the center of `rect` — the mark's symmetry, so the same
    /// centerline serves both halves.
    static func pointReflection(in rect: CGRect) -> CGAffineTransform {
        CGAffineTransform(translationX: rect.width, y: rect.height).rotated(by: .pi)
    }

    static let outline: Path = {
        var path = Path()
        // Head / frame outline — starts at the top.
        path.move(to: CGPoint(x: 30, y: 9))
        path.addLine(to: CGPoint(x: 14, y: 9)) // top-left corner
        path.addLine(to: CGPoint(x: 13, y: 30)) // down the left edge
        path.addLine(to: CGPoint(x: 2, y: 40)) // nose chevron tip (<)
        path.addLine(to: CGPoint(x: 14, y: 52)) // back from the nose
        path.addLine(to: CGPoint(x: 15, y: 68)) // bottom-left corner
        path.addLine(to: CGPoint(x: 44, y: 70)) // along the bottom
        path.addLine(to: CGPoint(x: 46, y: 42)) // up the right edge
        path.addLine(to: CGPoint(x: 47, y: 9)) // top-right corner
        path.addLine(to: CGPoint(x: 30, y: 9)) // close the top
        return path
    }()

    static let commaEye: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 43, y: 16))
        path.addLine(to: CGPoint(x: 24, y: 18))
        path.addCurve(
            to: CGPoint(x: 25, y: 30),
            control1: CGPoint(x: 18, y: 19),
            control2: CGPoint(x: 18, y: 27)
        )
        path.addCurve(
            to: CGPoint(x: 28, y: 23),
            control1: CGPoint(x: 31, y: 32),
            control2: CGPoint(x: 33, y: 25)
        )
        return path
    }()

    private static func fit(_ rect: CGRect) -> CGAffineTransform {
        CGAffineTransform(scaleX: rect.width / 112, y: rect.height / 86)
    }
}

#Preview {
    ZStack {
        Color(white: 0.97).ignoresSafeArea()
        RetrospectLoadingMark(width: 96)
    }
}
