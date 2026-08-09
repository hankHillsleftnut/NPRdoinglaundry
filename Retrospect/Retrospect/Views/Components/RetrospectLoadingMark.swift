import SwiftUI

/// Animated "drawing" loader for the Understanding phase.
///
/// Keeps the REAL brush logo (`retrospect-loading-mark`) and reveals it
/// progressively by masking it with a wide stroke that sweeps along a
/// hand-authored centerline — the "one line" that draws the face:
/// top → head outline → nose chevron → comma eye. The 180°-rotated
/// counterpart is revealed from the opposite end at the same time (the mark
/// has point symmetry about its center), so both halves draw as mirror
/// counterparts. The whole thing loops draw → un-draw.
///
/// The centerline coordinates live in `MarkHalfPath` in the mark's native
/// 112×86 viewBox space, so they're easy to nudge against the art.
struct RetrospectLoadingMark: View {
    /// Width in points; height derives from the 112×86 aspect.
    var width: CGFloat = 132
    /// One full draw (or un-draw) sweep, seconds.
    var duration: Double = 1.7
    /// Reveal-mask stroke width in viewBox units. Must be ≥ the brush
    /// thickness (~7) so the stroke fully uncovers the brush as it passes.
    var revealWidth: CGFloat = 15

    @State private var progress: CGFloat = 0

    private static let box = CGSize(width: 112, height: 86)
    private var height: CGFloat { width * Self.box.height / Self.box.width }

    var body: some View {
        Image("retrospect-loading-mark")
            .resizable()
            .scaledToFit()
            .frame(width: width, height: height)
            .mask(revealMask)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    progress = 1
                }
            }
            .accessibilityLabel("Loading")
    }

    private var revealMask: some View {
        GeometryReader { geo in
            let w = revealWidth * geo.size.width / Self.box.width
            let style = StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round)
            ZStack {
                // Half A — draws from the top.
                MarkHalfPath()
                    .trim(from: 0, to: progress)
                    .stroke(style: style)
                // Half B — same centerline rotated 180° about the rect center,
                // so trim(0→progress) starts at the opposite corner.
                MarkHalfPath()
                    .trim(from: 0, to: progress)
                    .stroke(style: style)
                    .rotationEffect(.degrees(180))
            }
        }
    }
}

/// One half's centerline in the mark's 112×86 space.
/// `trim(0→1)` traverses it in draw order: frame loop (top → left edge → nose
/// chevron → chin → bottom → right edge → back to top), then the comma eye.
struct MarkHalfPath: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 112, sy = rect.height / 86
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }

        var path = Path()
        // Head / frame outline — starts at the top.
        path.move(to: p(30, 9))
        path.addLine(to: p(14, 9))     // top-left corner
        path.addLine(to: p(13, 30))    // down the left edge
        path.addLine(to: p(2, 40))     // nose chevron tip (<)
        path.addLine(to: p(14, 52))    // back from the nose
        path.addLine(to: p(15, 68))    // bottom-left corner
        path.addLine(to: p(44, 70))    // along the bottom
        path.addLine(to: p(46, 42))    // up the right edge
        path.addLine(to: p(47, 9))     // top-right corner
        path.addLine(to: p(30, 9))     // close the top

        // Comma eye.
        path.move(to: p(43, 16))
        path.addLine(to: p(24, 18))
        path.addCurve(to: p(25, 30), control1: p(18, 19), control2: p(18, 27))
        path.addCurve(to: p(28, 23), control1: p(31, 32), control2: p(33, 25))
        return path
    }
}

#Preview {
    ZStack {
        Color(white: 0.97).ignoresSafeArea()
        RetrospectLoadingMark()
    }
}
