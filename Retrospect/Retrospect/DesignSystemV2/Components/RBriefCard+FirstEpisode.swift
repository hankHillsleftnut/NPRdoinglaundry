//
//  RBriefCard+FirstEpisode.swift
//  GR.ready: RBriefCard's `.firstEpisodeMaking` state, drawn here so RBriefCard.swift stays one
//  card (Paper p-J-0 c:brief-card/artwork/making 26ML-0, on ON-10). A raised row, radius.card,
//  padded 12 (16 on the trailing side) with 12 between its parts: the 44 artwork well (radius.panel,
//  sky.500 with amber.300 light top right and sky.800 pooling bottom left, a 1pt glow.primary.rim
//  along its top inside, a 3pt background.raised ring, a 1pt glow.primary.ring outside that and an
//  18pt glow.primary.bloom), then "your first episode" over its plain line, and a 2pt accent line
//  along the bottom edge, 16 in from each side, filled to the share made. Not a button: there is
//  nothing to play yet. Reduce Motion: the line steps without travelling.
//  The well's colours are tokens (color.firstEpisode.base / light / shade, the same in dark, as
//  artwork). Each radial fades its colour to transparent; CSS mixes that premultiplied, so OKLab and
//  sRGB give the same ramp (checked against Paper's export: mean error 3.5/255).
//
import SwiftUI

extension RTextStyle {
    /// The making row's title (Paper 26MQ-0: --font-label, --text-md, medium, leading snug, no tracking).
    static let briefRowTitle = RTextStyle(
        family: .label,
        size: RDimension.fontSizeMd,
        weight: .medium,
        tracking: RNumber.fontTrackingNone,
        leading: RTextStyle.body.leading,
        relativeTo: .subheadline
    )
}

struct RFirstEpisodeMakingCard: View {
    let title: String
    let line: String
    /// The share made, 0…1.
    let progress: Double

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Paper 26MR-0's well.
    static let well: CGFloat = 44 // literal-ok: Paper 26MR-0
    /// Paper's line: 2pt, 16 in from each side, on the bottom edge (26MM-0).
    static let lineHeight: CGFloat = 2 // literal-ok: Paper 26MM-0

    /// What VoiceOver reads: the title, being made, then the line with "~" said as "about".
    static func spoken(title: String, line: String) -> String {
        let said = line
            .replacingOccurrences(of: " · ", with: ", ")
            .replacingOccurrences(of: "~", with: "about ")
            .replacingOccurrences(of: " min", with: " minutes")
        return "\(title), being made, \(said)"
    }

    private var shape: RoundedRectangle {
        RShape.rect(RDimension.radiusCard)
    }

    /// The share made, kept within the line.
    private var share: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        HStack(alignment: .center, spacing: RDimension.space3) {
            RFirstEpisodeWell()
            VStack(alignment: .leading, spacing: RDimension.space1) {
                Text(title)
                    .rText(.briefRowTitle)
                    .foregroundStyle(RColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(line)
                    .rText(.metaLine)
                    .foregroundStyle(RColor.textLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, RDimension.space3)
        .padding(.leading, RDimension.space3)
        .padding(.trailing, RDimension.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Paper clips the card (overflow: clip): the well's bloom stays inside
        .clipShape(shape)
        .rRaised(RDimension.radiusCard)
        // the line goes on after the depth: CSS paints inset strokes under children, so Paper's 2pt
        // line covers the card's 1pt inner edge; masked to the card so its ends stay in the corners
        .overlay(alignment: .bottom) {
            progressLine
                .padding(.horizontal, RDimension.space4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .mask(shape)
        }
        // Increase Contrast: a 1pt control edge so the card holds without its shadow (as the brief card)
        .overlay(shape.strokeBorder(RColor.borderControl, lineWidth: contrast == .increased ? RDimension.sizeBorderDefault : RDimension.space0))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spoken(title: title, line: line))
        .accessibilityValue(Text(share, format: .percent.precision(.fractionLength(0))))
        .accessibilityIdentifier("brief.firstEpisodeMaking")
    }

    /// The 2pt line: border.subtle, filled with accent.default to the share made.
    private var progressLine: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RShape.pill.fill(RColor.borderSubtle)
                RShape.pill
                    .fill(RColor.accentDefault)
                    .frame(width: proxy.size.width * share)
            }
        }
        .frame(height: Self.lineHeight)
        .animation(reduceMotion ? nil : RMotion.move(RNumber.motionDurationReveal), value: progress)
        .accessibilityHidden(true)
    }
}

/// The 44 artwork well, its box-shadows one for one (Paper 26MR-0): inset 0 1 0 glow.primary.rim;
/// 0 0 0 3 background.raised; 0 0 0 4 glow.primary.ring; 0 0 18 glow.primary.bloom. Decorative.
struct RFirstEpisodeWell: View {
    private static let size = RFirstEpisodeMakingCard.well
    /// The raised ring (3) and the glow ring outside it (1 more).
    private static let raisedRing: CGFloat = 3 // literal-ok: Paper spread 3
    private static let glowRing: CGFloat = 4 // literal-ok: Paper spread 4
    private static let bloom: CGFloat = 9 // literal-ok: Paper blur 18 (SwiftUI radius is half)
    /// The rings' boxes: a spread grows the box by its width on every side.
    private static let raisedRingSize = size + 2 * raisedRing // literal-ok: geometry
    private static let glowRingSize = size + 2 * glowRing // literal-ok: geometry

    var body: some View {
        let shape = RShape.rect(RDimension.radiusPanel)
        ZStack {
            shape.fill(RColor.firstEpisodeBase)
            // radial-gradient(circle farthest-corner at 85% 10%, amber.300 0%, transparent 55%)
            shape.fill(RadialGradient(
                stops: [
                    .init(color: RColor.firstEpisodeLight, location: 0),
                    .init(color: RColor.firstEpisodeLight.opacity(0), location: 1),
                ],
                center: UnitPoint(x: 0.85, y: 0.1), // literal-ok: Paper gradient centre
                startRadius: 0,
                endRadius: Self.size * 0.55 * Self.farthest(0.85, 0.1) // literal-ok: Paper stop 55%
            ))
            // radial-gradient(circle farthest-corner at 0% 100%, sky.800 0%, transparent 80%)
            shape.fill(RadialGradient(
                stops: [
                    .init(color: RColor.firstEpisodeShade, location: 0),
                    .init(color: RColor.firstEpisodeShade.opacity(0), location: 1),
                ],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: Self.size * 0.8 * Self.farthest(0, 1) // literal-ok: Paper stop 80%
            ))
            // the rim: the top inner edge catches the light
            shape.strokeBorder(RColor.glowPrimaryRim, lineWidth: RDimension.sizeBorderDefault)
                .mask(alignment: .top) { Rectangle().frame(height: RDimension.sizeBorderDefault) }
        }
        .frame(width: Self.size, height: Self.size)
        .background {
            ZStack {
                shape.fill(RColor.glowPrimaryBloom)
                    .frame(width: Self.size, height: Self.size)
                    .blur(radius: Self.bloom)
                RShape.rect(RDimension.radiusPanel + Self.glowRing)
                    .fill(RColor.glowPrimaryRing)
                    .frame(width: Self.glowRingSize, height: Self.glowRingSize)
                RShape.rect(RDimension.radiusPanel + Self.raisedRing)
                    .fill(RColor.backgroundRaised)
                    .frame(width: Self.raisedRingSize, height: Self.raisedRingSize)
            }
        }
        .accessibilityHidden(true)
    }

    /// CSS `farthest-corner` from a centre at (x, y) in a unit square: the distance to the far corner.
    private static func farthest(_ x: Double, _ y: Double) -> Double {
        let dx = max(x, 1 - x)
        let dy = max(y, 1 - y)
        return (dx * dx + dy * dy).squareRoot()
    }
}
