//
//  WhyUndrawnLines.swift
//  V2.podcasts.b · DEBUG ONLY. PC-3's lines Paper doesn't draw (founder-review lean): "and n more"
//  under the rows when sources are hidden, and "nothing to show yet" when no source can be shown.
//  Founder, 27 Oct: state screens are for testing in the sandbox, never in the product.
//
#if DEBUG
import SwiftUI

struct WhyUndrawnLines: View {
    static let nothingYet = "nothing to show yet"

    let evidenceShown: Bool
    let more: Int

    /// "and 2 more"; nil when every source is shown.
    static func moreLine(_ more: Int) -> String? {
        more > 0 ? "and \(more) more" : nil
    }

    var body: some View {
        if !evidenceShown {
            RSectionLabel(title: "what it rests on")
            REmptyLine(line: Self.nothingYet)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let line = Self.moreLine(more) {
            Text(line)
                .rText(.metaLine)
                .foregroundStyle(RColor.textLabel)
                .padding(.leading, RDimension.space4)
                .accessibilityIdentifier("why.more")
        }
    }
}
#endif
