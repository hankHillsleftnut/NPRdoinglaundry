//
//  RTicketRecipes.swift
//  The invite's gift mesh and wallpaper (board `2HXR-0`, T1 `2I01-0`, T-alt `2IUL-0`). Both are Paper's
//  CSS radial ellipses drawn as they are (SI.fidelity: the shared-radius artwork mesh read as a
//  sweep, not Paper's blobs). The palette colours
//  are not semantic tokens, so they live here, once, with their dark twins; FR0.1 moves them to
//  tokens (docs/team/polish-list.md).
//
import SwiftUI

enum RTicketPalette {
    private static func hex(_ value: UInt32) -> Color {
        // palette.* hex values from design-system/tokens/tokens.json (no semantic token exists)
        Color(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255) // literal-ok: palette hex
    }

    // light: palette.amber.50 / .200, sky.100 / .200 / .300, red.200
    static let amber50 = hex(0xFBF0DA)
    static let amber200 = hex(0xFFC85C)
    static let sky100 = hex(0xD9F0FF)
    static let sky200 = hex(0xB3E1FF)
    static let sky300 = hex(0x7FCDFF)
    static let red200 = hex(0xFF8A84)
    // dark twins: the same hues, a step toward night
    static let amber900 = hex(0x2E2209)
    static let amber500 = hex(0xB7791F)
    static let sky800 = hex(0x165E8C)
    static let sky900 = hex(0x0F3F5E)
    static let sky950 = hex(0x0B2638)
    static let red700 = hex(0x740F0B)
}

/// The gift band (T-alt `2IUL-0`): amber paper with warm light top right, sky pooling bottom left, a
/// breath of red between, drawn as Paper's three CSS ellipses over the amber.50 base, no grain. Each
/// ellipse's radii are shares of the band's width and height (CSS `ellipse 80% 90%`), so the 354 × 132
/// band shows soft blobs, not the left-to-right sweep a shared-radius mesh made of it. Dark has no
/// Paper board: the same geometry with each colour's dark twin.
struct RTicketGift: View {
    /// One CSS radial-gradient: colour (at its strength) at the centre, clear by `fade` of the radius.
    struct Blob: Equatable {
        let strength: Double
        let radiusX: CGFloat
        let radiusY: CGFloat
        let at: UnitPoint
        let fade: CGFloat
    }

    /// Paper's three, in drawing order: amber.200, sky.300 at 80%, red.200 at 45%.
    static let blobs = [
        Blob(strength: 1, radiusX: 0.8, radiusY: 0.9, at: UnitPoint(x: 0.85, y: 0.1), fade: 0.7),
        Blob(strength: 0.8, radiusX: 0.7, radiusY: 0.8, at: UnitPoint(x: 0.15, y: 0.9), fade: 0.75),
        Blob(strength: 0.45, radiusX: 0.45, radiusY: 0.4, at: UnitPoint(x: 0.55, y: 0.45), fade: 1),
    ] // literal-ok: Paper 2IUL-0 gradients

    let width: CGFloat
    let height: CGFloat
    @Environment(\.colorScheme) private var scheme

    private var colors: [Color] {
        scheme == .dark
            ? [RTicketPalette.amber500, RTicketPalette.sky800, RTicketPalette.red700]
            : [RTicketPalette.amber200, RTicketPalette.sky300, RTicketPalette.red200]
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            scheme == .dark ? RTicketPalette.amber900 : RTicketPalette.amber50
            ForEach(Array(zip(Self.blobs, colors).enumerated()), id: \.offset) { _, pair in
                blob(pair.0, color: pair.1)
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .accessibilityHidden(true)
    }

    /// The ellipse fills a frame of its two diameters; the gradient runs from its centre to the
    /// frame's edge (0.5 of the frame), so it is clear at `fade` of each radius.
    private func blob(_ blob: Blob, color: Color) -> some View {
        let tint = color.opacity(blob.strength)
        return Rectangle()
            .fill(EllipticalGradient(
                stops: [.init(color: tint, location: 0), .init(color: tint.opacity(0), location: blob.fade)],
                center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5
            ))
            .frame(width: width * blob.radiusX * 2, height: height * blob.radiusY * 2) // literal-ok: radii to diameters
            .position(x: width * blob.at.x, y: height * blob.at.y)
    }
}

/// The invite wallpaper: the canvas with three soft washes at the top (T1 background).
struct RInviteWallpaper: View {
    /// One wash: an ellipse of colour fading out, centred at a share of the screen.
    struct Wash {
        let color: Color
        let opacity: Double
        let rx: CGFloat
        let ry: CGFloat
        let cx: CGFloat
        let cy: CGFloat
    }

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                RColor.backgroundCanvas
                wash(
                    Wash(color: scheme == .dark ? RTicketPalette.amber500 : RTicketPalette.amber200, opacity: 0.34, rx: 0.65, ry: 0.34, cx: 0.9, cy: 0),
                    in: size
                )
                wash(Wash(color: scheme == .dark ? RTicketPalette.sky800 : RTicketPalette.sky200, opacity: 0.36, rx: 0.7, ry: 0.38, cx: 0, cy: 0.18), in: size)
                wash(Wash(color: scheme == .dark ? RTicketPalette.sky900 : RTicketPalette.sky100, opacity: 0.4, rx: 0.6, ry: 0.26, cx: 0.5, cy: 0.34), in: size)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    /// An ellipse wash fading out by its edge, centred at a share of the screen.
    private func wash(_ spec: Wash, in size: CGSize) -> some View {
        let color = spec.color
        let opacity = spec.opacity
        let radiusX = size.width * spec.rx
        let radiusY = size.height * spec.ry
        // a circular fade squashed to the ellipse, so it fades out smoothly on both axes
        return Rectangle()
            .fill(RadialGradient(colors: [color.opacity(opacity), color.opacity(0)], center: .center, startRadius: 0, endRadius: max(radiusX, 1)))
            .frame(width: radiusX * 2, height: radiusX * 2) // literal-ok: a diameter
            .scaleEffect(x: 1, y: radiusY / max(radiusX, 1))
            .position(x: size.width * spec.cx, y: size.height * spec.cy)
    }
}
