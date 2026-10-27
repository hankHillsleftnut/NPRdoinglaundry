//
//  AnswerCard.swift
//  V2.you · YO-2's parts: what was found (Paper c:answer/found 1G9Y-0, c:answer/abstained K24-0), its
//  numbered sources (c:source-result/rest 1G9P-0) and "only what's certain" (1G91-0).
//  - The card: background.raised on the raised depth stack, radius.card, padding 20, 8 between lines:
//    "what i found" (Geist 12 medium, text.label), the answer in the inky face at text-xl, then the guess
//    or the closest thing in SF 17, text.secondary. Superscript numbers cite the sources, as Paper draws
//    them (unicode, not mono chips: YO-D4). They are words, not links: a superscript is 3 to 7pt wide, far
//    under a 44pt target, so the numbered source rows below (56 high) are the one way in (QA batch 5;
//    YO-D21). VoiceOver reads the card as one sentence with each citation as "source n".
//  - Sources: "sources" over one grouped panel of REvidenceRow `.number` rows. A row opens its source's
//    page only when one is drawn (the journal entry, YO-3); the others are drawn the same but inert (YO-D7).
//  - "only what's certain": a wash panel (radius.panel, min 56, padding 8 / 16) with a switch; on, the
//    guess line and the source that only backs it fold away.
//
import SwiftUI

struct AnswerCard: View {
    let answer: Flows.Answer
    /// The second line as the page shows it now (nil when hidden by "only what's certain").
    let secondLine: [Flows.Cited]?

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space2) {
            Text("what i found")
                .rText(.labelMedium)
                .foregroundStyle(RColor.textLabel)
            Text(Self.written(answer.headline))
                .rText(.inkEntry)
                .foregroundStyle(RColor.textPrimary)
                .rBalancedLines()
            if let secondLine {
                Text(Self.written(secondLine))
                    .rText(.body)
                    .foregroundStyle(RColor.textSecondary)
                    .rBalancedLines()
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RDimension.space5)
        .rRaised(RDimension.radiusCard)
        // one element: the citations read as "source 1" (a superscript "¹" would read as a bare digit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spoken(answer.headline, secondLine))
    }

    /// What VoiceOver reads for the card: "what i found. after days you run, source 1, and when …".
    static func spoken(_ headline: [Flows.Cited], _ secondLine: [Flows.Cited]?) -> String {
        let read: ([Flows.Cited]) -> String = { runs in
            runs.map { run in run.source.map { "\(run.text), source \($0)" } ?? run.text }.joined()
        }
        return (["what i found.", read(headline)] + (secondLine.map { [read($0)] } ?? [])).joined(separator: " ")
    }

    /// The words with each cited source as a superscript number, as Paper writes them.
    static func written(_ runs: [Flows.Cited]) -> String {
        runs.map { run in run.text + (run.source.map(superscript) ?? "") }.joined()
    }

    /// 1 → "¹" (Paper draws the unicode superscripts).
    static func superscript(_ number: Int) -> String {
        let digits: [Character] = ["⁰", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹"]
        return String(String(number).compactMap { $0.wholeNumberValue.map { digits[$0] } })
    }
}

/// "sources" and the numbered rows (1G97-0): the label 8 above one grouped panel.
struct SourceList: View {
    let sources: [Flows.SourceResult]
    let open: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space1) {
            RSectionLabel(title: "sources")
            REvidenceGroup {
                ForEach(sources) { source in
                    // Paper draws › on every source; one with no page yet is drawn the same, inert (YO-D7)
                    REvidenceRow(leading: .number(source.id), meta: source.meta, words: source.words) {
                        if let id = source.sourceID {
                            open(id)
                        }
                    }
                    .youInert(source.sourceID == nil)
                }
            }
        }
    }
}

/// "only what's certain · hides the 1 guess" with its switch (1G91-0). A tap anywhere on the wash row
/// toggles it (as the switch does); VoiceOver reads it once, as the switch, with the subline as its hint.
struct OnlyCertainRow: View {
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: RDimension.space3) {
            VStack(alignment: .leading, spacing: RDimension.sizeBorderRing) {
                Text("only what's certain")
                    .rText(.textMdMedium)
                    .foregroundStyle(RColor.textPrimary)
                Text(YouModel.onlyCertainSubline)
                    .rText(.metaLine)
                    .foregroundStyle(RColor.textLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(true)
            RSwitch(label: "only what's certain", isOn: $isOn)
                .accessibilityHint(YouModel.onlyCertainSubline)
        }
        .padding(.vertical, RDimension.space2)
        .padding(.horizontal, RDimension.space4)
        .frame(maxWidth: .infinity, minHeight: RDimension.sizeRowDefault)
        .background(RColor.surfaceWash, in: RShape.rect(RDimension.radiusPanel))
        .contentShape(Rectangle())
        .onTapGesture { isOn.toggle() }
    }
}
