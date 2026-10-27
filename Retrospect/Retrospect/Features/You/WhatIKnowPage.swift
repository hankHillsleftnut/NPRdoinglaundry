//
//  WhatIKnowPage.swift
//  V2.you · YO-5 "what i know about you" (Paper 1SZX-0, slot 16J8-0): pushed from YO-1. A settings bar
//  (back + the small centred name, 1T1K-0), then 16 down and 32 between blocks on the 24 margins: the
//  "moved this week" wash row (1T1E-0), and one block per area (1T0J-0, 1T02-0, 1SZZ-0): the area's name
//  in the inky card face, 12 above its answers in one grouped panel, or Retro's quiet line when it
//  knows little. Rows open nothing yet (DISCREPANCIES YO-D10). Dark: launcher only.
//
import SwiftUI

struct WhatIKnowPage: View {
    let model: WhatIKnowModel
    let back: () -> Void

    var body: some View {
        VStack(spacing: RDimension.space0) {
            RTopBar(variant: .settings(title: "what i know about you", back: back))
            ScrollView {
                if case let .content(known) = model.state {
                    content(known)
                }
            }
        }
        .background(RColor.backgroundCanvas)
        .task { await model.load() }
        .accessibilityIdentifier("screen.you.whatIKnow")
    }

    private func content(_ known: Flows.WhatIKnow) -> some View {
        VStack(alignment: .leading, spacing: RDimension.space8) {
            if let line = WhatIKnowModel.changedLine(known.changedThisWeek) {
                MovedThisWeekRow(subline: line)
            }
            ForEach(known.areas) { area in
                AreaBlock(area: area)
            }
        }
        .padding(.top, RDimension.space4)
        .padding(.horizontal, RDimension.spaceScreenMargin)
        .padding(.bottom, RDimension.spaceScreenMargin)
    }
}

/// "moved this week" (1T1E-0): a wash row, radius.panel, min 56, padding 8 / 16. What it opens is not
/// drawn, so it shows no › and isn't a button (YO-D10).
private struct MovedThisWeekRow: View {
    let subline: String

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.sizeBorderRing) {
            Text("moved this week")
                .rText(.textMdMedium)
                .foregroundStyle(RColor.textPrimary)
            Text(subline)
                .rText(.metaLine)
                .foregroundStyle(RColor.textLabel)
        }
        .frame(maxWidth: .infinity, minHeight: RDimension.sizeRowDefault, alignment: .leading)
        .padding(.vertical, RDimension.space2)
        .padding(.horizontal, RDimension.space4)
        .background(RColor.surfaceWash, in: RShape.rect(RDimension.radiusPanel))
        .accessibilityElement(children: .combine)
    }
}

/// One area: its name in the inky card face, 12 above its answers or its quiet line (1T0J-0, 1SZZ-0).
private struct AreaBlock: View {
    let area: Flows.KnownArea

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space3) {
            Text(area.title)
                .rText(.inkCard)
                .foregroundStyle(RColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if area.answers.isEmpty {
                if let quiet = area.quietLine {
                    Text(quiet)
                        .rText(.body)
                        .foregroundStyle(RColor.textSecondary)
                        .rBalancedLines()
                }
            } else {
                REvidenceGroup {
                    ForEach(area.answers) { AnswerRow(answer: $0) }
                }
            }
        }
    }
}
