//
//  NodeSheet.swift
//  V2.you · YO-4 "a node" (Paper 1GC2-0, slot 16J2-0): the sheet over the map, at the full detent (its top
//  under the status bar, as drawn), in RSheetHost's panel (grabber, 28 inset). Its header (1GDV-0): the
//  node's kind and name in Geist 14 medium on one line, and a 34 wash chevron-down that closes the sheet
//  (no mark, no share: the player's header is not reused, YO-D15). 24 down, then 32 between blocks:
//  - a person: the belief (RClaim stated, 1GDS-0); "what it rests on" over evidence rows (1GCY-0) that
//    open nothing yet, so they are drawn with their › but inert (YO-D10); "linked" chips (1GCR-0, static: YO-D16); and at the
//    foot (1GCF-0, 16 above) "still true" and "not right". "still true" keeps it and closes; "not right"
//    is drawn as Paper but inert, as "correct this part" (corrections are not drawn, YO-D11).
//  The guess state is not drawn, so not built (founder 27 Oct, YO-D12).
//
import SwiftUI

extension RTextStyle {
    /// YO-4's belief (Paper 1GDU-0): the inky title face (ink-title exposure, tracking-title, leading-tight)
    /// at text-2xl, one step under the claim part's 3xl, so its lines break where Paper's do (QA batch 7).
    static let inkNodeBelief = RTextStyle(
        family: .inky(axis: -20),
        size: RDimension.fontSize2xl,
        weight: .regular,
        tracking: RNumber.fontTrackingTitle,
        leading: 1.1,
        relativeTo: .title
    )
}

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
                .padding(.bottom, Self.footInset)
        }
        .accessibilityIdentifier("sheet.you.node")
    }

    /// Paper 1GCD-0: the pills end 40 above the sheet's bottom edge. The sheet host already keeps its
    /// content above the home indicator (34 on iPhone 17 Pro, 0 on SE), so only the rest is added here:
    /// 6 on a phone with a home indicator, 40 on one without (QA batch 5: it was 38 too high).
    @MainActor static var footInset: CGFloat {
        let indicator = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow?.safeAreaInsets.bottom ?? 0
        // the pill draws 36 inside its 44 target, so 4 of the 40 are already the target's own margin
        return max(RDimension.space0, RDimension.space10 - RDimension.space1 - indicator)
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
            RClaim(kind: .stated, text: node.belief, meta: node.meta, statedStyle: .inkNodeBelief)
            if !node.restsOn.isEmpty {
                VStack(alignment: .leading, spacing: RDimension.space1) {
                    RSectionLabel(title: "what it rests on")
                    REvidenceGroup {
                        ForEach(node.restsOn) { evidence in
                            REvidenceRow(
                                leading: .kind(symbol: evidence.kind.symbol),
                                meta: evidence.meta,
                                // Paper draws the 32 wash well behind each glyph (1GCZ-0), as on the canvas
                                // panel anywhere else: not the lifted well (that one vanished, QA batch 5)
                                words: evidence.words
                            ) {}
                                // Paper draws ›; where it leads isn't drawn: inert (YO-D10, DECISIONS 27 Oct)
                                .youInert()
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
            RPill(title: "still true", symbol: "checkmark", size: .medium) { answer(.stillTrue) }
            // Paper's c:icon/correct (1GCI-0): a speech bubble with a line, the same as PC-3's "not right"
            // (one icon, one size app-wide, DECISIONS 27 Oct). Corrections aren't drawn: inert, not dimmed.
            RPill(title: "not right", symbol: "text.bubble", size: .medium) {}
                .youInert()
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
