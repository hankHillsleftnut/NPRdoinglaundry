//
//  DailyBriefPage.swift
//  V2.settings · ST-2 daily brief (Paper 1GJK-0): turn the brief on, choose when it's ready and how
//  long it runs, and see today's. No icon wells. Group 1: "each morning" switch, then "time" as a
//  quick pick (ST-D5: the picker's look isn't drawn). Group 2: "length", the segmented control and
//  its caption (ST-D6: only "standard"'s caption is drawn). Group 3: "play today's" with its pill,
//  which has nowhere to go until the brief sheet (JR-2) is built (ST-D7). Turning the brief off
//  changes only the switch and ST-1's value (ST-D8: no off look is drawn).
//
import SwiftUI

struct DailyBriefPage: View {
    typealias Settings = Flows.Settings
    let data: any Flows.SettingsData
    let back: () -> Void
    /// "play today's": JR-2 over the shell, when the host can raise it; nil: drawn, inert.
    var playToday: (() -> Void)?

    var body: some View {
        SettingsPageFrame(title: "daily brief", back: back) {
            VStack(spacing: RDimension.space0) {
                SettingsSwitchRow(title: "each morning", subline: "a short brief, made from yesterday", isOn: isOn)
                RHairline()
                    .padding(.leading, RDimension.spaceScreenMargin)
                RSettingsRow(
                    title: "time",
                    subline: "your time, \(data.brief.city)",
                    trailing: .pick(data.brief.time.long, options: data.briefTimes.map(\.long)) { picked in
                        if let time = data.briefTimes.first(where: { $0.long == picked }) {
                            data.setBrief(time: time)
                        }
                    }
                )
                .accessibilityIdentifier("dailyBrief.time")
            }
            VStack(alignment: .leading, spacing: RDimension.space0) {
                RSectionLabel(title: "length")
                RSegmented(
                    label: "length",
                    options: Settings.BriefLength.allCases.map { (value: $0, title: $0.rawValue) },
                    selection: length
                )
                .padding(.top, RDimension.space1)
                Text(caption)
                    .rText(.label)
                    .foregroundStyle(RColor.textLabel)
                    .contentTransition(.interpolate)
                    .animation(RMotion.standard(RNumber.motionDurationFast), value: data.brief.length)
                    .padding(.top, RDimension.space2)
            }
            .padding(.horizontal, RDimension.spaceScreenMargin)
            if let today = data.brief.today {
                SettingsActionRow(
                    title: "play today's",
                    subline: "\(today.day) · \(today.minutes) min",
                    pill: "play",
                    symbol: "play.fill",
                    action: playToday
                )
            }
        }
    }

    private var caption: String {
        Self.caption(for: data.brief)
    }

    /// "standard is about 4 minutes."
    static func caption(for brief: Settings.Brief) -> String {
        guard let minutes = brief.minutes[brief.length] else { return "" }
        return "\(brief.length.rawValue) is about \(minutes) \(minutes == 1 ? "minute" : "minutes")."
    }

    private var isOn: Binding<Bool> {
        Binding { data.brief.isOn } set: { data.setBrief(isOn: $0) }
    }

    private var length: Binding<Settings.BriefLength> {
        Binding { data.brief.length } set: { data.setBrief(length: $0) }
    }
}
