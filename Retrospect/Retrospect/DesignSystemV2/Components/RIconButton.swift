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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RSymbol(name: symbol, size: role.glyph, tint: tint, weight: role.weight)
                .frame(width: role.visible, height: role.visible)
                .background(RColor.surfaceWash, in: Circle())
                .frame(width: max(role.visible, RDimension.sizeControlDefault), height: max(role.visible, RDimension.sizeControlDefault))
                .contentShape(Rectangle())
        }
        .rPress(small: true, haptic: role == .bubble ? RHaptic.press : nil)
        .accessibilityLabel(label)
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
