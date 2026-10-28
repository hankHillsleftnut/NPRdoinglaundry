//
//  VoiceListeningPage.swift
//  V2.settings · ST-7 voice and listening (Paper 1GS3-0). The one voice behind every show, with its
//  sample pill; how fast briefs and episodes play, picked in place; and talk or read, the same value
//  as ST-1's quick pick. Undrawn, so provisional: the sample's playback (the pill is inert and says
//  "not available yet") and the speeds other than 1× (ST-D24).
//
import SwiftUI

struct VoiceListeningPage: View {
    typealias Settings = Flows.Settings
    let data: any Flows.SettingsData & Flows.SettingsTrustData
    let back: () -> Void

    var body: some View {
        SettingsPageFrame(title: "voice and listening", back: back) {
            RSettingsGroup {
                SettingsActionRow(
                    title: "voice",
                    subline: "\(data.voiceName) · one voice behind every show",
                    pill: "sample",
                    symbol: "play.fill"
                )
                RSettingsRow(
                    title: "speed",
                    subline: "for briefs and episodes",
                    trailing: .pick(data.speed.label, options: Settings.Speed.allCases.map(\.label)) { picked in
                        if let speed = Settings.Speed.allCases.first(where: { $0.label == picked }) {
                            data.setSpeed(speed)
                        }
                    }
                )
                .accessibilityIdentifier("voice.speed")
            }
            // Paper 1GS6-0: label, 8, the segmented control, 8, the caption
            VStack(alignment: .leading, spacing: RDimension.space0) {
                RSectionLabel(title: "talk or read")
                RSegmented(
                    label: "talk or read",
                    options: Settings.TalkOrRead.allCases.map { (value: $0, title: $0.rawValue) },
                    selection: Binding { data.talkOrRead } set: { data.setTalkOrRead($0) }
                )
                .padding(.top, RDimension.space1)
                Text("talk: retro speaks its replies. read: words only.")
                    .rText(.label)
                    .foregroundStyle(RColor.textLabel)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, RDimension.space2)
            }
            .padding(.horizontal, RDimension.spaceScreenMargin)
        }
    }
}

#if DEBUG
#Preview("ST-7 voice and listening") {
    VoiceListeningPage(data: SampleSettings(), back: {})
}
#endif
