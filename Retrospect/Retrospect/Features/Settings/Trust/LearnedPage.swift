//
//  LearnedPage.swift
//  V2.settings · ST-8 what i've learned (Paper 1GTG-0). One thing retro has learned about how you
//  answer, said plainly: an inky display sentence, what retro does about it, and when it last changed.
//  Static. The too-early / nothing-yet state is undrawn (ST-D25): with nothing learned the page shows
//  only its bar.
//
import SwiftUI

extension RTextStyle {
    /// ST-8's display sentence (Paper 1GTM-0: --font-display-inky, --text-2xl, ink card, --tracking-card,
    /// --leading-tight).
    static let learnedHeadline = RTextStyle(
        family: .inky(axis: -10),
        size: RDimension.fontSize2xl,
        weight: .regular,
        tracking: RNumber.fontTrackingCard,
        leading: 1.1,
        relativeTo: .title
    )
}

struct LearnedPage: View {
    let data: any Flows.SettingsTrustData
    let back: () -> Void

    var body: some View {
        SettingsPageFrame(title: "what i've learned", back: back) {
            if let learned = data.learned {
                // Paper 1GTJ-0: three lines 12 apart inside the margin
                VStack(alignment: .leading, spacing: RDimension.space3) {
                    Text(learned.headline)
                        .rText(.learnedHeadline)
                        .foregroundStyle(RColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(learned.detail)
                        .rText(.rowTitle)
                        .foregroundStyle(RColor.textSecondary)
                    Text(learned.changed)
                        .rText(.labelMedium)
                        .foregroundStyle(RColor.textLabel)
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, RDimension.spaceScreenMargin)
            }
        }
    }
}

#if DEBUG
#Preview("ST-8 what i've learned") {
    LearnedPage(data: SampleSettings(), back: {})
}
#endif
