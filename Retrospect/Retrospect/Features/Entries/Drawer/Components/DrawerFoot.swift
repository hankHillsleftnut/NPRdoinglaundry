//
//  DrawerFoot.swift
//  V2.journal (dark) · JR-3: the drawer's foot (Paper c:row/drawer-foot/rest F2M-0, in use 1FOS-0):
//  a 44 row, 12 in, the sliders glyph (20, icon.default), "settings" in Geist 14 medium and the
//  version in Geist 12, text.label. It sits on the drawer's bottom edge: on the home indicator's
//  safe area where there is one (Paper: 32 off the bottom), 16 off the bottom on a home-button
//  phone (build notes). The whole row opens settings.
//
import SwiftUI

struct DrawerFoot: View {
    /// The screen has a bottom safe area (a home indicator): the row sits on it.
    let onHomeIndicator: Bool
    let openSettings: () -> Void

    var body: some View {
        Button(action: openSettings) {
            HStack(spacing: RDimension.space3) {
                RSymbol(name: "slider.horizontal.3", size: .regular)
                Text("settings")
                    .rText(.drawerFootText)
                    .foregroundStyle(RColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(Self.version)
                    .rText(.metaLine)
                    .foregroundStyle(RColor.textLabel)
            }
            .padding(.horizontal, RDimension.space3)
            .frame(minHeight: RDimension.sizeTouchTarget)
            .contentShape(Rectangle())
        }
        .rPress()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("settings")
        .accessibilityValue(Self.version)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("drawer.settings")
        .padding(.horizontal, RDimension.space4)
        // a home-button phone has no bottom inset: keep the row 16 off the edge
        .padding(.bottom, onHomeIndicator ? RDimension.space0 : RDimension.space4)
    }

    /// "v1.0": the app's marketing version, as Paper writes it.
    static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return "v\(short ?? "1.0")"
    }
}

extension RTextStyle {
    /// The drawer foot's "settings" (Paper 1FOU-0: --font-label, --text-md, medium, leading snug).
    static let drawerFootText = RTextStyle(
        family: .label,
        size: RDimension.fontSizeMd,
        weight: .medium,
        tracking: RNumber.fontTrackingNone,
        leading: RTextStyle.metaLine.leading,
        relativeTo: .subheadline
    )
}
