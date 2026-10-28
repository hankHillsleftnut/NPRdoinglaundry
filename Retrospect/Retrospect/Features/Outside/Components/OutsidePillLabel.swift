//
//  OutsidePillLabel.swift
//  V2.outside · the neutral pill's look as a label, not a button (EX-1's goal 1H23-0, EX-4's "play" /
//  "talk" 1H4P-0 / 1H4N-0): surface.wash, a true pill, 32 tall, 12 at the sides, Geist 14 medium. Used
//  where Paper draws the pill but the tap belongs to something else (the widget's own link, a picker
//  not drawn yet), so a Button (RPill) would be a dead control.
//
import SwiftUI

struct OutsidePillLabel: View {
    let title: String
    /// A leading glyph ("play.fill"), 4 before the words.
    var symbol: String?

    var body: some View {
        HStack(spacing: RDimension.space1) {
            if let symbol {
                RSymbol(name: symbol, size: .small)
            }
            Text(title)
                .rText(.pill)
                .foregroundStyle(RColor.textPrimary)
                .lineLimit(1)
        }
        .padding(.leading, symbol == nil ? RDimension.space3 : RDimension.space2)
        .padding(.trailing, RDimension.space3)
        .frame(minHeight: RDimension.sizeControlSmall)
        .background(RColor.surfaceWash, in: RShape.pill)
    }
}
