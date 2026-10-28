//
//  BenefitTiles.swift
//  PW.paywall: the six small art tiles at the start of the paywall's benefit rows (Paper ON-12 22Q9-0;
//  founder comments c-qgaf3d, c-nroyoq, c-ga3yqz: "more exciting", "less detailed, more elegant, from
//  the design system", "some off axis"). Each is a 56 raised tile (background.raised, radius.panel,
//  depth.boxShadow.paywall.tile) holding a tiny drawing made only of design-system colours and shapes:
//  no images. Used on one screen, so it lives with the paywall. The drawings' geometry is Paper's,
//  point for point (the numbers below are illustration geometry with their node ids, not layout sizes).
//
import SwiftUI

/// Which drawing a tile holds, in Paper's order.
enum BenefitTileKind: CaseIterable {
    case brief, map, ask, onTrack, podcast, journal
}

struct BenefitTile: View {
    let kind: BenefitTileKind

    var body: some View {
        drawing
            .frame(width: RDimension.sizeBenefitTile, height: RDimension.sizeBenefitTile)
            .background(RColor.backgroundRaised, in: RShape.rect(RDimension.radiusPanel))
            .clipShape(RShape.rect(RDimension.radiusPanel))
            .rBoxShadows(RElevation.boxShadowPaywallTile, radius: RDimension.radiusPanel)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var drawing: some View {
        switch kind {
        case .brief: BriefDrawing()
        case .map: MapDrawing()
        case .ask: AskDrawing()
        case .onTrack: OnTrackDrawing()
        case .podcast: PodcastDrawing()
        case .journal: JournalDrawing()
        }
    }
}

/// Paper's tile geometry (points inside the 56 tile).
private enum Geo {
    // brief 22S5-0: a lit sun (22S8-0) half under the horizon (22S6-0)
    static let skyHeight: CGFloat = 34
    static let sun: CGFloat = 22
    static let sunTop: CGFloat = 23
    static let horizonWidth: CGFloat = 30
    // map 22RT-0: three lines from the centre to three nodes, a lit "you" (22RS-0) on the centre
    static let centre = CGPoint(x: 28, y: 28)
    static let nodes: [(CGPoint, CGFloat)] = [(CGPoint(x: 14, y: 18), 3), (CGPoint(x: 43, y: 21), 3.5), (CGPoint(x: 22, y: 43), 2.5)]
    static let you: CGFloat = 14
    // ask 22RH-0: a sunken field with a typed dash and an accent cursor
    static let fieldWidth: CGFloat = 36
    static let fieldHeight: CGFloat = 14
    static let fieldLead: CGFloat = 6
    static let fieldGap: CGFloat = 3
    static let dash = CGSize(width: 12, height: 2)
    static let cursor = CGSize(width: 1.5, height: 8)
    static let hairCorner: CGFloat = 1
    // on track 22R2-0: three tracks, the middle one lit
    static let trackInset: CGFloat = 13
    static let trackGap: CGFloat = 5
    static let track: CGFloat = 3
    static let trackCorner: CGFloat = 2
    static let fills: [CGFloat] = [22, 26, 12]
    // podcast 22QS-0: a lit play
    static let play: CGFloat = 24
    static let triangle: CGFloat = 10
    // journal 22QE-0: your bubble, Retro's line, Retro's line with an accent dot
    static let journalInset: CGFloat = 11
    static let journalGap: CGFloat = 4
    static let bubble = CGSize(width: 22, height: 9)
    static let line = CGSize(width: 28, height: 2)
    static let shortLine = CGSize(width: 16, height: 2)
    static let dot: CGFloat = 4
}

private let litGradient = LinearGradient(
    colors: [RColor.glowPrimaryGradientTop, RColor.glowPrimaryGradientBottom],
    startPoint: .top,
    endPoint: .bottom
)

private struct BriefDrawing: View {
    var body: some View {
        ZStack(alignment: .top) {
            // the sky clips the sun at the horizon
            Circle()
                .fill(litGradient)
                .frame(width: Geo.sun, height: Geo.sun)
                .rBoxShadows(RElevation.boxShadowPaywallTileGlowSun, radius: Geo.sun / 2)
                .offset(y: Geo.sunTop)
                .frame(width: RDimension.sizeBenefitTile, height: Geo.skyHeight, alignment: .top)
                .clipped()
            RColor.borderStrong
                .frame(width: Geo.horizonWidth, height: RDimension.sizeBorderDefault)
                .clipShape(RShape.rect(Geo.hairCorner))
                .offset(y: Geo.skyHeight)
        }
        .frame(width: RDimension.sizeBenefitTile, height: RDimension.sizeBenefitTile, alignment: .top)
    }
}

private struct MapDrawing: View {
    var body: some View {
        ZStack {
            Canvas { context, _ in
                var lines = Path()
                for (node, _) in Geo.nodes {
                    lines.move(to: Geo.centre)
                    lines.addLine(to: node)
                }
                context.stroke(
                    lines,
                    with: .color(RColor.borderStrong),
                    style: StrokeStyle(lineWidth: RDimension.sizeBorderDefault, lineCap: .round)
                )
                for (node, radius) in Geo.nodes {
                    let dot = CGRect(x: node.x - radius, y: node.y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: dot), with: .color(RColor.surfaceStrong))
                }
            }
            Circle()
                .fill(litGradient)
                .frame(width: Geo.you, height: Geo.you)
                .rBoxShadows(RElevation.boxShadowPaywallTileGlowYou, radius: Geo.you / 2)
        }
    }
}

private struct AskDrawing: View {
    var body: some View {
        HStack(spacing: Geo.fieldGap) {
            RColor.iconMuted
                .frame(width: Geo.dash.width, height: Geo.dash.height)
                .clipShape(RShape.rect(Geo.hairCorner))
            RColor.accentDefault
                .frame(width: Geo.cursor.width, height: Geo.cursor.height)
                .clipShape(RShape.rect(Geo.hairCorner))
        }
        .padding(.leading, Geo.fieldLead)
        .frame(width: Geo.fieldWidth, height: Geo.fieldHeight, alignment: .leading)
        .background(RColor.surfaceControl, in: RShape.pill)
        .rBoxShadows(RElevation.boxShadowPaywallTileField, radius: Geo.fieldHeight / 2)
    }
}

private struct OnTrackDrawing: View {
    var body: some View {
        VStack(spacing: Geo.trackGap) {
            ForEach(Array(Geo.fills.enumerated()), id: \.offset) { index, fill in
                RColor.surfaceTrack
                    .frame(height: Geo.track)
                    .overlay(alignment: .leading) {
                        (index == 1 ? RColor.accentDefault : RColor.surfaceTrackFill)
                            .frame(width: fill)
                    }
                    .clipShape(RShape.rect(Geo.trackCorner))
            }
        }
        .padding(.horizontal, Geo.trackInset)
    }
}

private struct PodcastDrawing: View {
    var body: some View {
        Image(systemName: "play.fill")
            .resizable()
            .scaledToFit()
            .frame(width: Geo.triangle, height: Geo.triangle)
            .foregroundStyle(RColor.glowPrimaryForeground)
            .frame(width: Geo.play, height: Geo.play)
            .background(litGradient, in: Circle())
            .rBoxShadows(RElevation.boxShadowPaywallTileGlowPlay, radius: Geo.play / 2)
    }
}

private struct JournalDrawing: View {
    var body: some View {
        VStack(spacing: Geo.journalGap) {
            RColor.surfaceControl
                .frame(width: Geo.bubble.width, height: Geo.bubble.height)
                .clipShape(RShape.pill)
                .frame(maxWidth: .infinity, alignment: .trailing)
            RColor.iconMuted
                .frame(width: Geo.line.width, height: Geo.line.height)
                .clipShape(RShape.rect(Geo.hairCorner))
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: Geo.fieldGap) {
                RColor.iconMuted
                    .frame(width: Geo.shortLine.width, height: Geo.shortLine.height)
                    .clipShape(RShape.rect(Geo.hairCorner))
                Circle()
                    .fill(RColor.accentDefault)
                    .frame(width: Geo.dot, height: Geo.dot)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Geo.journalInset)
    }
}
