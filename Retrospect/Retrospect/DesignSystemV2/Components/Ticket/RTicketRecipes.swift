//
//  RTicketRecipes.swift
//  The invite's gift mesh and wallpaper (board `2HXR-0`, T1 `2I01-0`). Paper's three radial blobs
//  mixed in OKLab, approximated by `RArtworkRecipe` points (the PR shows both). The palette colours
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

extension RArtworkRecipes {
    /// The gift: amber paper with warm light top right, sky pooling bottom left, a breath of red between.
    static func gift(dark: Bool) -> RArtworkRecipe {
        let grain = RArtworkRecipe.Grain(mode: .multi, opacity: 0.12, size: 1.5) // literal-ok: same grain as every mesh recipe
        if dark {
            return RArtworkRecipe(
                base: RTicketPalette.amber900,
                blobs: [
                    .init(color: RTicketPalette.amber500, x: 0.85, y: 0.1, radius: 0.8, weight: 0.9),
                    .init(color: RTicketPalette.sky800, x: 0.15, y: 0.9, radius: 0.7, weight: 0.8),
                    .init(color: RTicketPalette.red700, x: 0.55, y: 0.45, radius: 0.4, weight: 0.45),
                ],
                softness: 0.7, grain: grain
            )
        }
        return RArtworkRecipe(
            base: RTicketPalette.amber50,
            blobs: [
                .init(color: RTicketPalette.amber200, x: 0.85, y: 0.1, radius: 0.8, weight: 1),
                .init(color: RTicketPalette.sky300, x: 0.15, y: 0.9, radius: 0.7, weight: 0.8),
                .init(color: RTicketPalette.red200, x: 0.55, y: 0.45, radius: 0.4, weight: 0.45),
            ],
            softness: 0.7, grain: grain
        )
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
