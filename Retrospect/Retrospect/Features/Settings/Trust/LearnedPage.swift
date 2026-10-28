//
//  LearnedPage.swift
//  V2.settings · ST-8 what i've learned (Paper 1GTG-0). One thing retro has learned about how you
//  answer, said plainly: an inky display sentence, what retro does about it, and when it last changed.
//  Static. Too early / off are undrawn (ST-D25): ST-1's row then says "not available yet" and opens
//  nothing (SettingsDestinations+Trust).
//
import SwiftUI

struct LearnedPage: View {
    let data: any Flows.SettingsTrustData
    let back: () -> Void

    var body: some View {
        SettingsPageFrame(title: "what i've learned", back: back) {
            if Self.hasContent(data.learned), let headline = data.learned.headline {
                // Paper 1GTJ-0: three lines 12 apart inside the margin
                VStack(alignment: .leading, spacing: RDimension.space3) {
                    Text(headline)
                        .rText(.inkClaimAsked) // Paper 1GTM-0: inky 2xl, ink card, tracking card, leading tight
                        .foregroundStyle(RColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if let detail = data.learned.detail {
                        Text(detail)
                            .rText(.rowTitle)
                            .foregroundStyle(RColor.textSecondary)
                    }
                    if let changedAt = data.learned.changedAt {
                        Text(Self.changed(changedAt))
                            .rText(.labelMedium)
                            .foregroundStyle(RColor.textLabel)
                    }
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, RDimension.spaceScreenMargin)
            }
        }
    }

    /// Whether there is something to show: Paper draws the page only with its sentence. Anything else
    /// (too early, off, unknown, or learning without a sentence yet) keeps ST-1's row inert.
    static func hasContent(_ learned: Flows.Settings.Learned) -> Bool {
        learned.state == .learning && learned.headline?.isEmpty == false
    }

    /// "last changed on sunday"
    static func changed(_ date: Date) -> String {
        let day = date.formatted(Date.FormatStyle(locale: Locale(identifier: "en_US_POSIX"), calendar: Calendar(identifier: .gregorian)).weekday(.wide))
        return "last changed on \(day.lowercased())"
    }
}

#if DEBUG
#Preview("ST-8 what i've learned") {
    LearnedPage(data: SampleSettings(), back: {})
}
#endif
