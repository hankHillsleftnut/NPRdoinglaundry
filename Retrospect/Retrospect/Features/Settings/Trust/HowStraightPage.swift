//
//  HowStraightPage.swift
//  V2.settings · ST-6 how straight i am with you (Paper 1GQM-0). Four choices with a tick on the chosen
//  one, then why retro picked what it picked. Choosing applies at once (haptic.select, from the row) and
//  ST-1's value follows. Paper draws nothing after you choose (ST-D23), so the "picked by retro" note
//  stays as drawn: it already says "choose another and yours wins".
//
import SwiftUI

struct HowStraightPage: View {
    let data: any Flows.SettingsTrustData
    let back: () -> Void

    var body: some View {
        // Paper 1GQP-0: the choices and the note sit 24 apart
        SettingsPageFrame(title: "how straight i am with you", groupSpacing: RDimension.space6, back: back) {
            RSettingsGroup {
                ForEach(Flows.Settings.Straightness.allCases, id: \.self) { choice in
                    RSettingsRow(
                        title: choice.title,
                        subline: choice.subline,
                        trailing: .choice(selected: data.straightness == choice)
                    ) {
                        data.setStraightness(choice)
                    }
                    .accessibilityIdentifier("settings.howStraight.\(choice.rawValue)")
                }
            }
            SettingsLabelledGroup(label: "picked by retro") {
                Text(data.retroReason)
                    .rText(.textMd)
                    .foregroundStyle(RColor.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, RDimension.spaceScreenMargin)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

#if DEBUG
#Preview("ST-6 how straight") {
    HowStraightPage(data: SampleSettings(), back: {})
}
#endif
