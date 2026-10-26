//
//  RSettingsRow.swift
//  M14 C09: the settings row (Paper approvals · part 22 "row 56 · hairline" and part 26
//  "settings rows"; ios-handoff ST-1 to ST-9). One row is one thing you can open or change.
//  Rows sit on the page with no container: min 56, padding 16 / 24, 12 between parts, title
//  SF 17 over a 14 subline 2 apart, and the trailing part centred on the pair. The whole row is
//  the target. Pressed shows surface.subtle at once and fades back over 240ms.
//
import SwiftUI

extension RTextStyle {
    /// Row titles (part 22: --font-text, --text-body, regular, --tracking-card, --leading-snug).
    static let rowTitle = RTextStyle(
        family: .text,
        size: RDimension.fontSizeBody,
        weight: .regular,
        tracking: RNumber.fontTrackingCard,
        leading: 1.3,
        relativeTo: .body
    )
}

struct RSettingsRow: View {
    /// What sits at the trailing edge, and so what the row does.
    enum Trailing {
        /// › opens a page inside the app.
        case nav
        /// value + › opens its picker.
        case value(String)
        /// value + ↕: a quick pick between a few values, chosen in place from the row's own menu
        /// (decision 04; Paper DNO-0 "talk ↕", gate A card 3). VoiceOver hears a pop-up button.
        case pick(String, options: [String], select: (String) -> Void)
        /// ↗ leaves the app (only for links out).
        case external
        /// an ink tick in a 20 slot; titles in a choice group align either way.
        case choice(selected: Bool)
        /// applies at once.
        case toggle(Binding<Bool>)
        /// nothing: the danger row opens its dialog.
        case none
    }

    let title: String
    var subline: String?
    var symbol: String?
    var trailing: Trailing = .nav
    /// A danger row: red-tinted well and danger title. Alone and last in its page.
    var danger = false
    /// The subline says what to do, in status.dangerText.
    var error = false
    /// Dims the row; the subline should say why.
    var disabled = false
    var action: () -> Void = {}

    var body: some View {
        control
            .buttonStyle(RListRowStyle())
            .disabled(disabled)
            // a switch ticks on every change; in a choice group only the newly chosen row ticks,
            // so one choice is one haptic, not one per row that changed
            .sensoryFeedback(RHaptic.select, trigger: selectionState) { _, new in
                !disabled && (isToggle || new == true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(accessibilityValue)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityAddTraits(isToggle ? .isToggle : [])
    }

    /// A quick pick is the row's own menu (so the menu opens in place and VoiceOver announces a pop-up
    /// button); every other row is a button.
    @ViewBuilder private var control: some View {
        if case let .pick(value, options, select) = trailing {
            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        select(option)
                    } label: {
                        if option == value {
                            Label(option, systemImage: "checkmark")
                        } else {
                            Text(option)
                        }
                    }
                }
            } label: {
                rowLabel
            }
            .menuStyle(.button)
        } else {
            Button {
                if case let .toggle(isOn) = trailing {
                    isOn.wrappedValue.toggle()
                }
                action()
            } label: {
                rowLabel
            }
        }
    }

    private var rowLabel: some View {
        HStack(spacing: RDimension.space3) {
            if let symbol {
                RIconWell(
                    symbol: symbol,
                    tint: danger ? RColor.statusDangerText : RColor.iconDefault,
                    fill: danger ? RColor.statusDangerSubtle : RColor.surfaceWash
                )
                .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: RDimension.sizeBorderRing) {
                Text(title)
                    .rText(.rowTitle)
                    .foregroundStyle(titleColor)
                if let subline {
                    Text(subline)
                        .rText(.textMd)
                        .foregroundStyle(sublineColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            trailingView
        }
        .padding(.vertical, RDimension.space4)
        .padding(.horizontal, RDimension.spaceScreenMargin)
        .frame(maxWidth: .infinity, minHeight: RDimension.sizeRowDefault)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var trailingView: some View {
        switch trailing {
        case .nav:
            chevron
        case let .value(value):
            HStack(spacing: RDimension.space1) {
                Text(value)
                    .rText(.textMd)
                    .foregroundStyle(disabled ? RColor.textTertiary : RColor.textSecondary)
                    .accessibilityHidden(true)
                chevron
            }
        case let .pick(value, _, _):
            HStack(spacing: RDimension.space1) {
                Text(value)
                    .rText(.textMd)
                    .foregroundStyle(disabled ? RColor.textTertiary : RColor.textSecondary)
                    .accessibilityHidden(true)
                RSymbol(name: "chevron.up.chevron.down", size: .small, tint: disabled ? RColor.textDisabled : RColor.iconMuted)
            }
        case .external:
            RSymbol(
                name: "arrow.up.right",
                size: .small,
                tint: disabled ? RColor.textDisabled : RColor.iconMuted,
                glyphScale: 0.66 // literal-ok: matches Paper's 8.5pt ↗
            )
        case let .choice(selected):
            RSymbol(name: "checkmark", tint: RColor.inkDefault, weight: .medium)
                .opacity(selected ? 1 : 0)
                .frame(width: RDimension.sizeIconDefault)
        case let .toggle(isOn):
            // TODO(C07): RSwitch replaces this stand-in. The row owns the tap, so the switch
            // only shows the state.
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(RColor.inkDefault)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        case .none:
            EmptyView()
        }
    }

    private var chevron: some View {
        RSymbol(name: "chevron.right", size: .small, tint: disabled ? RColor.textDisabled : RColor.iconMuted)
    }

    private var titleColor: Color {
        if disabled {
            return RColor.textTertiary
        }
        return danger ? RColor.statusDangerText : RColor.textPrimary
    }

    private var sublineColor: Color {
        if disabled {
            return RColor.textTertiary
        }
        return error ? RColor.statusDangerText : RColor.textSecondary
    }

    private var isToggle: Bool {
        if case .toggle = trailing {
            return true
        }
        return false
    }

    private var isSelected: Bool {
        if case let .choice(selected) = trailing {
            return selected
        }
        return false
    }

    /// Changes only for a switch or a choice, so haptic.select fires there and nowhere else.
    private var selectionState: Bool? {
        switch trailing {
        case let .toggle(isOn): isOn.wrappedValue
        case let .choice(selected): selected
        default: nil
        }
    }

    private var accessibilityValue: String {
        switch trailing {
        case let .value(value), let .pick(value, _, _): value
        case let .toggle(isOn): isOn.wrappedValue ? "on" : "off"
        default: ""
        }
    }
}

/// Pressed: surface.subtle at once, back over 240ms; Reduce Motion: no fade (part 22).
/// Every list row presses this way (settings, evidence): Paper's row master draws pressed as
/// surface.subtle (part 22).
struct RListRowStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? RColor.surfaceSubtle : .clear)
            .animation(
                configuration.isPressed || reduceMotion ? nil : RMotion.standard(RNumber.motionDurationPressOut),
                value: configuration.isPressed
            )
    }
}

/// Rows separated by inset hairlines that run to the trailing edge; groups are separated by
/// space (32), never boxed.
struct RSettingsGroup<Content: View>: View {
    var inset: RHairline.Inset = .full
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: .zero) {
            Group(subviews: content) { rows in
                ForEach(rows.indices, id: \.self) { index in
                    rows[index]
                    if index < rows.count - 1 {
                        RHairline(inset: inset)
                            .padding(.leading, RDimension.spaceScreenMargin)
                    }
                }
            }
        }
    }
}

#if DEBUG
struct RSettingsRowGallery: View {
    @State private var autoplay = true
    @State private var download = false
    @State private var voice = "warm"
    @State private var mode = "talk"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space8) {
                RSettingsGroup {
                    RSettingsRow(title: "notifications")
                    RSettingsRow(title: "voice", subline: "how retro sounds when it reads to you", trailing: .value(voice))
                    RSettingsRow(title: "what retro can see", subline: "calendar, voice notes and two more")
                }
                // quick picks (decision 04): value + ↕, chosen in place (ST-1 DNJ-0 "talk or read · talk")
                RSettingsGroup(inset: .afterIcon) {
                    RSettingsRow(title: "talk or read", symbol: "waveform", trailing: .pick(mode, options: ["talk", "read"]) { mode = $0 })
                    RSettingsRow(
                        title: "reading speed",
                        symbol: "speedometer",
                        trailing: .pick("1x", options: ["0.8x", "1x", "1.2x"]) { _ in },
                        disabled: true
                    )
                }
                RSettingsGroup(inset: .afterIcon) {
                    RSettingsRow(title: "calendar", subline: "so your brief knows what today holds", symbol: "calendar")
                    RSettingsRow(title: "health", subline: "sleep and steps, for how your week felt", symbol: "heart")
                }
                RSettingsGroup {
                    RSettingsRow(title: "notifications", disabled: false)
                    RSettingsRow(title: "export your journal", subline: "needs a connection", disabled: true)
                    RSettingsRow(title: "sync now", subline: "couldn't reach the server. try again in a minute", error: true)
                }
                RSettingsGroup {
                    RSettingsRow(title: "autoplay the next episode", subline: "when the current one ends", trailing: .toggle($autoplay))
                    RSettingsRow(title: "download on wi-fi only", subline: "saves your data plan", trailing: .toggle($download))
                }
                RSettingsGroup {
                    ForEach(["warm", "clear", "quiet"], id: \.self) { name in
                        RSettingsRow(title: name, subline: subline(for: name), trailing: .choice(selected: voice == name)) { voice = name }
                    }
                }
                RSettingsGroup {
                    RSettingsRow(title: "privacy policy", subline: "opens in safari", trailing: .external)
                    RSettingsRow(title: "export your journal", subline: "everything you wrote, as text")
                }
                RSettingsRow(
                    title: "delete my account",
                    subline: "removes everything, after a confirmation",
                    symbol: "exclamationmark.circle",
                    trailing: .none,
                    danger: true
                )
            }
            .padding(.vertical, RDimension.space6)
        }
        .background(RColor.backgroundCanvas)
    }

    private func subline(for voice: String) -> String {
        switch voice {
        case "warm": "unhurried, close"
        case "clear": "brisk, plain"
        default: "soft, slower"
        }
    }
}

#Preview("settings rows") { RSettingsRowGallery() }
#endif
