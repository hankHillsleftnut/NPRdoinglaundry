//
//  RIconButton.swift
//  M14 C04: the wash icon button. Three roles from the approved boards: top bar
//  (36, back / close / more), in a field (32, the mic) and bubble (44, share, play).
//  The hit area is never under 44 (button.md accessibility).
//
import SwiftUI

struct RIconButton: View {
    enum Role {
        case topBar, inField, bubble

        var visible: CGFloat {
            switch self {
            case .topBar: RDimension.sizeControlIcon
            case .inField: RDimension.sizeControlSmall
            case .bubble: RDimension.sizeControlDefault
            }
        }
    }

    let symbol: String
    let label: String
    var role: Role = .topBar
    var tint: Color = RColor.iconDefault
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RSymbol(name: symbol, tint: tint)
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
