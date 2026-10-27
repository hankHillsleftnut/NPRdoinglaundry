//
//  GoalEndedRow.swift
//  V2.goals · the quiet row ended goals collapse into (Paper c:goal-row/faded 1G1X-0, part 48 IYZ-0):
//  surface.wash, radius.panel, min 56, padding 12 / 16, "turned off 2 · merged 1" in SF 14 secondary.
//  Paper draws › to the ended list, which isn't drawn yet (GL-D2): no ›, not a button, until it is.
//
import SwiftUI

struct GoalEndedRow: View {
    /// "turned off 2 · merged 1".
    let line: String

    var body: some View {
        Text(line)
            .rText(.textMd)
            .foregroundStyle(RColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, RDimension.space3)
            .padding(.horizontal, RDimension.space4)
            .frame(minHeight: RDimension.sizeRowDefault)
            .background(RColor.surfaceWash, in: RShape.rect(RDimension.radiusPanel))
            .accessibilityLabel(line.replacingOccurrences(of: " · ", with: ", "))
    }
}
