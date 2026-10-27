//
//  SettingsInertRow.swift
//  V2.settings: a row Paper draws whose destination isn't built yet ("manage subscription ↗",
//  "restore purchases" on ST-9). Inert rule: it looks exactly as drawn (no dimming), has no press
//  feedback, is not announced as a button, and VoiceOver reads its value as "not available yet".
//  Same frame as RSettingsRow (A2's SettingsControlFrame). The W4 wiring PR turns each into a real row.
//
import SwiftUI

struct SettingsInertRow: View {
    static let unavailable = "not available yet"

    let title: String
    var subline: String?
    /// Paper's ↗: the row would leave the app.
    var leavesApp = false

    var body: some View {
        SettingsControlFrame(title: title, subline: subline) {
            if leavesApp {
                RSymbol(
                    name: "arrow.up.right",
                    size: .small,
                    tint: RColor.iconMuted,
                    glyphScale: 0.66 // literal-ok: matches RSettingsRow's ↗ (Paper's 8.5pt glyph)
                )
                .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(Self.unavailable)
        .accessibilityRemoveTraits(.isButton)
    }
}
