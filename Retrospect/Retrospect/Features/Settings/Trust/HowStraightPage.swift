//
//  HowStraightPage.swift
//  V2.settings · ST-6 how straight i am with you (Paper 1GQM-0). Four choices with a tick on the chosen
//  one, then why retro picked what it picked. Choosing applies at once (haptic.select, from the row) and
//  ST-1's value follows. The "picked by retro" note shows while the choice is retro's (Paper draws
//  only that); after you choose, the note goes (the "yours" look is undrawn: ST-D23).
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
                        trailing: .choice(selected: data.straightness.level == choice)
                    ) {
                        data.setStraightness(choice)
                    }
                    .accessibilityIdentifier("settings.howStraight.\(choice.rawValue)")
                }
            }
            // Paper draws the note only for retro's own pick; once the choice is yours the contract has no
            // reason to show, and the "yours" look is undrawn (ST-D23), so the note goes.
            if data.straightness.source == .picked, let why = data.straightness.why {
                SettingsLabelledGroup(label: "picked by retro") {
                    Text(why)
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
}

#if DEBUG
#Preview("ST-6 how straight") {
    HowStraightPage(data: SampleSettings(), back: {})
}
#endif
