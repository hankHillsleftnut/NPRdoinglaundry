//
//  FirstDayWelcome.swift
//  FH.home: the welcome under the first episode on first home (Paper ON-13 1FJH-0): the inky
//  "welcome, sam." (display-inky text-3xl, ink title, tracking title, leading tight, text.primary) over
//  one line (font-text text-body, leading normal, text.secondary), spacing-2 apart.
//
import SwiftUI

extension RTextStyle {
    /// The welcome's line (Paper 1FJI-0: --font-text, --text-body, --leading-normal, no tracking).
    static let welcomeLine = RTextStyle(
        family: .text,
        size: RDimension.fontSizeBody,
        weight: .regular,
        tracking: RNumber.fontTrackingNone,
        leading: RTextStyle.bodyReading.leading,
        relativeTo: .body
    )
}

struct FirstDayWelcome: View {
    let name: String?

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space2) {
            Text(FirstDay.welcome(name: name))
                .rText(.inkTitle)
                .foregroundStyle(RColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(FirstDay.welcomeLine)
                .rText(.welcomeLine)
                .foregroundStyle(RColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("firstHome.welcome")
    }
}
