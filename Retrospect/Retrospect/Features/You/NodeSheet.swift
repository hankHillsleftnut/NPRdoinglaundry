//
//  NodeSheet.swift
//  V2.you · YO-4 "a node" (Paper 1GC2-0, slot 16J2-0): the sheet over the map, at the full detent (its top
//  under the status bar, as drawn), in RSheetHost's panel (grabber, 28 inset). Its header (1GDV-0): the
//  node's kind and name in Geist 14 medium on one line, and a 34 wash chevron-down that closes the sheet
//  (no mark, no share: the player's header is not reused, YO-D15). 24 down, then 32 between blocks:
//  - a person: the belief (RClaim stated, 1GDS-0); "what it rests on" over evidence rows (1GCY-0) that
//    open nothing yet, so they show no › (YO-D10); "linked" chips (1GCR-0, static: YO-D16); and at the
//    foot (1GCF-0, 16 above) "still true" and "not right". "still true" keeps it and closes; "not right"
//    is disabled with a reason, as "correct this part" (corrections are not drawn, YO-D11).
//  The guess state is not drawn, so not built (founder 27 Oct, YO-D12).
//
import SwiftUI

struct NodeSheet: View {
    let node: Flows.Node
    let answer: (Flows.NodeAnswer) -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space0) {
            header
            ScrollView {
                belief
                    .padding(.top, RDimension.space6)
                    .padding(.bottom, RDimension.space4)
            }
            .scrollBounceBehavior(.basedOnSize)
            pills
                .padding(.top, RDimension.space4)
                .padding(.bottom, RDimension.space10)
        }
        .accessibilityIdentifier("sheet.you.node")
    }

    private var header: some View {
        HStack(spacing: RDimension.space2) {
            Text(node.header)
                .rText(.playerHeaderTitle)
                .foregroundStyle(RColor.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            RIconButton(symbol: "chevron.down", label: "close", role: .sheetHeader, action: close)
        }
        .padding(.top, RDimension.space1)
    }

    private var belief: some View {
        VStack(alignment: .leading, spacing: RDimension.space8) {
            RClaim(kind: .stated, text: node.belief, meta: node.meta)
            if !node.restsOn.isEmpty {
                VStack(alignment: .leading, spacing: RDimension.space1) {
                    RSectionLabel(title: "what it rests on")
                    REvidenceGroup {
                        ForEach(node.restsOn) { evidence in
                            REvidenceRow(
                                leading: .kind(symbol: evidence.kind.symbol),
                                meta: evidence.meta,
                                words: evidence.words,
                                onTint: true,
                                action: nil
                            )
                        }
                    }
                }
            }
            if !node.linked.isEmpty {
                VStack(alignment: .leading, spacing: RDimension.space1) {
                    RSectionLabel(title: "linked")
                    LinkedChips(titles: node.linked)
                }
            }
        }
    }

    private var pills: some View {
        HStack(spacing: RDimension.space2) {
            RPill(title: "still true", symbol: "checkmark") { answer(.stillTrue) }
            RPill(title: "not right", symbol: "exclamationmark.bubble", disabledReason: "corrections come later") {}
                .accessibilityValue("not available yet")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// "work", "ship the first version" (1GCR-0): wash capsules 32 high, 12 in, SF 14 medium, 8 apart,
/// in one row, or stacked when they don't fit (large type). What a chip opens is not drawn, so they are
/// words, not buttons (YO-D16).
private struct LinkedChips: View {
    let titles: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: RDimension.space2) { chips }
            VStack(alignment: .leading, spacing: RDimension.space2) { chips }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("linked: \(titles.joined(separator: ", "))")
    }

    private var chips: some View {
        ForEach(titles, id: \.self) { title in
            Text(title)
                .rText(.textMdMedium)
                .foregroundStyle(RColor.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, RDimension.space3)
                .frame(minHeight: RDimension.sizeControlSmall)
                .background(RColor.surfaceWash, in: RShape.pill)
        }
    }
}
