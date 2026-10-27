//
//  RIconButton.swift
//  M14 C04: the wash icon button. Three roles from the approved boards: top bar
//  (36, back / close / more), in a field (32, the mic) and bubble (44, share, play); and the
//  player sheet's header (34, share / collapse, PS.sheet.a).
//  The hit area is never under 44 (button.md accessibility).
//
import SwiftUI

struct RIconButton: View {
    enum Role {
        case topBar, inField, bubble
        /// The player sheet's header (share, collapse): a 34 circle (Paper ON-11 26PK-0 / 26PH-0)
        /// with an 18 glyph at stroke weight (player.md: stroke 2 on the 24 grid).
        case sheetHeader

        var visible: CGFloat {
            switch self {
            case .topBar: RDimension.sizeControlIcon
            case .inField: RDimension.sizeControlSmall
            case .bubble: RDimension.sizeControlDefault
            case .sheetHeader: RDimension.sizePlayerHeaderButton
            }
        }

        var glyph: RIconSize {
            // Paper 26PI-0's glyph box is 18 (size.icon.inWell)
            self == .sheetHeader ? .inWell : .regular
        }

        var weight: Font.Weight {
            self == .sheetHeader ? .semibold : .regular
        }
    }

    let symbol: String
    let label: String
    var role: Role = .topBar
    var tint: Color = RColor.iconDefault
    /// The glyph's share of its 20 frame (RSymbol).
    var glyphScale: CGFloat = RSymbol.defaultGlyphScale
    let action: () -> Void

    /// The onboarding back chevron at Paper's size: 11.3pt tall in the 20 frame (ON-6 `21CA-0`;
    /// founder, 26 Oct: "Paper's chevron size, not larger"). SF's chevron at the default scale is 14.
    static let backChevronGlyphScale: CGFloat = 0.66 // literal-ok: Paper 21CA-0, 11.3 of SF's 14 at 0.82

    /// The quiet back chevron of the onboarding pages (questions, privacy, connect): a 32 wash
    /// circle in a 44 hit area, the chevron at Paper's size.
    static func onboardingBack(action: @escaping () -> Void) -> Self {
        Self(symbol: "chevron.left", label: "back", role: .inField, glyphScale: backChevronGlyphScale, action: action)
    }

    var body: some View {
        Button(action: action) {
            Self.face(symbol: symbol, role: role, tint: tint, glyphScale: glyphScale)
        }
        .rPress(small: true, haptic: role == .bubble ? RHaptic.press : nil)
        .accessibilityLabel(label)
    }

    /// The wash circle and its glyph in the 44 hit frame: the button's face, also worn by system
    /// controls that need their own button (the player header's ShareLink).
    static func face(
        symbol: String,
        role: Role,
        tint: Color = RColor.iconDefault,
        glyphScale: CGFloat = RSymbol.defaultGlyphScale
    ) -> some View {
        RSymbol(name: symbol, size: role.glyph, tint: tint, weight: role.weight, glyphScale: glyphScale)
            .frame(width: role.visible, height: role.visible)
            .background(RColor.surfaceWash, in: Circle())
            .frame(width: max(role.visible, RDimension.sizeControlDefault), height: max(role.visible, RDimension.sizeControlDefault))
            .contentShape(Rectangle())
    }
}

#if DEBUG
#Preview("icon buttons") {
    HStack(spacing: RDimension.space4) {
        RIconButton(symbol: "chevron.left", label: "back") {}
        RIconButton(symbol: "mic", label: "talk", role: .inField) {}
        RIconButton(symbol: "play.fill", label: "play", role: .bubble) {}
    }
    .padding(RDimension.spaceScreenMargin)
}
#endif
