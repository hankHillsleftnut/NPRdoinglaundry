//
//  SettingsHubPage.swift
//  V2.settings · ST-1 settings (Paper 1GGA-0). Every setting in one calm list, each with its current
//  value: groups "your brief", "listening", "you", "sources" and an untitled one (privacy, account).
//  Every row has its 32 icon well; hairlines start after the well. Paper's hidden leftovers (a
//  "listening" label over the last group, stray values) are not built (L0-9).
//  ST-D1 (provisional, Q16): "voice" and "how straight i am with you" open their pages (journey map
//  06) and so show › where Paper draws ↕. "talk or read" is the quick pick Paper draws (ST-D2).
//
import SwiftUI

struct SettingsHubPage: View {
    let data: any Flows.SettingsData
    let open: (SettingsRoute) -> Void
    let back: () -> Void

    var body: some View {
        SettingsPageFrame(title: "settings", topPadding: RDimension.space2, back: back) {
            SettingsLabelledGroup(label: "your brief") {
                row("daily brief", symbol: "sun.horizon", trailing: .value(briefValue), opens: .dailyBrief)
            }
            SettingsLabelledGroup(label: "listening") {
                RSettingsGroup(inset: .afterIcon) {
                    row("voice", symbol: "mic", trailing: .value(data.voiceName), opens: .voice)
                    RSettingsRow(
                        title: "talk or read",
                        symbol: "keyboard",
                        trailing: .pick(
                            data.talkOrRead.rawValue,
                            options: Flows.Settings.TalkOrRead.allCases.map(\.rawValue)
                        ) { picked in
                            if let value = Flows.Settings.TalkOrRead(rawValue: picked) {
                                data.setTalkOrRead(value)
                            }
                        }
                    )
                    .accessibilityIdentifier("settings.row.talkOrRead")
                }
            }
            SettingsLabelledGroup(label: "you") {
                RSettingsGroup(inset: .afterIcon) {
                    row("how straight i am with you", symbol: "slider.horizontal.3", trailing: .value(data.straightnessName), opens: .howStraight)
                    row("what i've learned", symbol: "doc.text", trailing: .nav, opens: .learned)
                }
            }
            SettingsLabelledGroup(label: "sources") {
                row("connected sources", symbol: "dot.radiowaves.left.and.right", trailing: .value(sourcesValue), opens: .sources)
            }
            SettingsLabelledGroup {
                RSettingsGroup(inset: .afterIcon) {
                    row("privacy", symbol: "lock", trailing: .nav, opens: .privacy)
                    row("account", symbol: RTab.you.symbol, trailing: .nav, opens: .account)
                }
            }
        }
    }

    /// "8:30 · on"
    private var briefValue: String {
        "\(data.brief.time.short) · \(data.brief.isOn ? "on" : "off")"
    }

    /// "4 · 1 needs you"
    private var sourcesValue: String {
        let needs = data.sources.filter { $0.status == .needsYou }.count
        let count = "\(data.sources.count)"
        return needs == 0 ? count : "\(count) · \(needs) needs you"
    }

    /// A row that opens a page. While that page isn't built yet the row does nothing and says so.
    private func row(_ title: String, symbol: String, trailing: RSettingsRow.Trailing, opens page: SettingsRoute) -> some View {
        let built = SettingsDestinations.isBuilt(page, data: data)
        return RSettingsRow(title: title, symbol: symbol, trailing: trailing) { open(page) }
            .accessibilityHint(built ? "" : "not available yet")
            .accessibilityIdentifier("settings.row.\(SettingsHubPage.identifier(page))")
    }

    static func identifier(_ page: SettingsRoute) -> String {
        switch page {
        case .dailyBrief: "dailyBrief"
        case .sources: "sources"
        case let .source(id): "source.\(id)"
        case .privacy: "privacy"
        case .howStraight: "howStraight"
        case .voice: "voice"
        case .learned: "learned"
        case .account: "account"
        }
    }
}
