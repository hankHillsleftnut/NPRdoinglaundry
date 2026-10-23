//
//  RBrandWash.swift
//  The first-run wallpaper: the canvas with a warm wash from the top-trailing corner (amber), a cool
//  one from the top-leading corner (sky) and a pale glow behind the middle, all fading out by about
//  40% of the height (Paper splash `1F4Q-0`, AC-1 `1GXR-0`; the board's recipe). The brand palette is
//  not in the semantic tokens, so its few values live here with their dark twins (docs/team/polish-list.md).
//
import SwiftUI

struct RBrandWash: View {
    @Environment(\.colorScheme) private var scheme

    private static func hex(_ value: UInt32) -> Color {
        // palette.* hex values from design-system/tokens/tokens.json (no semantic token exists)
        Color(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255) // literal-ok: palette hex
    }

    private static let amber = (light: hex(0xFFC85C), dark: hex(0xB7791F)) // palette.amber.200 / .500
    private static let sky = (light: hex(0xB3E1FF), dark: hex(0x165E8C)) // palette.sky.200 / .800
    private static let glow = (light: hex(0xD9F0FF), dark: hex(0x0F3F5E)) // palette.sky.100 / .900

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                RColor.backgroundCanvas
                wash(scheme == .dark ? Self.amber.dark : Self.amber.light, 0.34, at: UnitPoint(x: 0.9, y: 0), reach: 0.65, in: size)
                wash(scheme == .dark ? Self.sky.dark : Self.sky.light, 0.36, at: UnitPoint(x: 0, y: 0.18), reach: 0.7, in: size)
                wash(scheme == .dark ? Self.glow.dark : Self.glow.light, 0.4, at: UnitPoint(x: 0.5, y: 0.3), reach: 0.6, in: size)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    /// A soft circle of colour fading out, centred at a share of the screen, squashed to an ellipse.
    private func wash(_ color: Color, _ opacity: Double, at centre: UnitPoint, reach: CGFloat, in size: CGSize) -> some View {
        let radius = size.width * reach
        return Rectangle()
            .fill(RadialGradient(colors: [color.opacity(opacity), color.opacity(0)], center: .center, startRadius: 0, endRadius: radius))
            .frame(width: radius * 2, height: radius * 2) // literal-ok: a diameter
            .scaleEffect(x: 1, y: 0.55) // literal-ok: the washes are wider than tall
            .position(x: size.width * centre.x, y: size.height * centre.y)
    }
}
