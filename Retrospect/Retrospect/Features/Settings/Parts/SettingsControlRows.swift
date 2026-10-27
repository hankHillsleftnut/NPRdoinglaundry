//
//  SettingsControlRows.swift
//  V2.settings: the two settings rows whose trailing part is its own control (Paper part 26:
//  c:settings-row/switch and c:settings-row/action). Same frame as RSettingsRow (min 56, 16 / 24,
//  12 between parts, SF 17 over a 14 subline 2 apart). RSettingsRow's own `.toggle` still shows the
//  system stand-in (its TODO C07), so the settings pages use RSwitch through this row. At
//  accessibility sizes the control moves under the words instead of squeezing them.
//  Used by ST-2, ST-4 (first half) and ST-5, ST-7 (second half); kept in the settings feature
//  because only settings pages draw them.
//
import SwiftUI

/// A setting that applies at once with a switch; the whole row is the target (Paper c:settings-row/switch).
struct SettingsSwitchRow: View {
    let title: String
    var subline: String?
    @Binding var isOn: Bool
    /// Ticks for taps on the row around the switch (the switch ticks for its own), one haptic per change.
    @State private var rowTick = 0

    var body: some View {
        // VoiceOver: one stop, the switch ("each morning, switch, on"), with the subline as its hint
        SettingsControlFrame(title: title, subline: subline, wordsHidden: true) {
            RSwitch(label: title, isOn: $isOn)
                .accessibilityHint(subline ?? "")
        }
        .background {
            Button {
                isOn.toggle()
                rowTick += 1
            } label: {
                Color.clear.contentShape(Rectangle())
            }
            .buttonStyle(RListRowStyle())
            .accessibilityHidden(true)
        }
        .sensoryFeedback(RHaptic.select, trigger: rowTick)
    }
}

/// A row with one raised pill at its trailing edge: play, sync now, export, sample (Paper c:settings-row/action).
struct SettingsActionRow: View {
    let title: String
    var subline: String?
    let pill: String
    var symbol: String?
    var pending = false
    /// nil while the action has nowhere to go yet: the pill stays as drawn and says so to VoiceOver.
    var action: (() -> Void)?

    var body: some View {
        SettingsControlFrame(title: title, subline: subline) {
            RPill(title: pill, symbol: symbol, style: .raised, pending: pending) { action?() }
                .accessibilityHint(action == nil ? "not available yet" : "")
        }
    }
}

/// The words on the leading side and one control on the trailing side.
struct SettingsControlFrame<Control: View>: View {
    let title: String
    var subline: String?
    /// The control speaks for the row (a switch): the words are not a VoiceOver stop of their own.
    var wordsHidden = false
    @ViewBuilder let control: Control
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let parts = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: RDimension.space2))
            : AnyLayout(HStackLayout(spacing: RDimension.space3))
        parts {
            VStack(alignment: .leading, spacing: RDimension.sizeBorderRing) {
                Text(title)
                    .rText(.rowTitle)
                    .foregroundStyle(RColor.textPrimary)
                if let subline {
                    Text(subline)
                        .rText(.textMd)
                        .foregroundStyle(RColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)
            .accessibilityElement(children: .combine)
            .accessibilityHidden(wordsHidden)
            control
        }
        .padding(.vertical, RDimension.space4)
        .padding(.horizontal, RDimension.spaceScreenMargin)
        .frame(maxWidth: .infinity, minHeight: RDimension.sizeRowDefault)
    }
}
