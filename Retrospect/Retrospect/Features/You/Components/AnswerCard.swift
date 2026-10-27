//
//  AnswerCard.swift
//  V2.you · YO-2's parts: what was found (Paper c:answer/found 1G9Y-0, c:answer/abstained K24-0), its
//  numbered sources (c:source-result/rest 1G9P-0) and "only what's certain" (1G91-0).
//  - The card: background.raised on the raised depth stack, radius.card, padding 20, 8 between lines:
//    "what i found" (Geist 12 medium, text.label), the answer in the inky face at text-xl, then the guess
//    or the closest thing in SF 17, text.secondary. Superscript numbers cite the sources, as Paper draws
//    them (unicode, not mono chips: YO-D4); each is a link that scrolls to its row and shows it pressed
//    for a beat (YO-D21). VoiceOver reads the answer whole and offers the citations in the links rotor.
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
    let cite: (Int) -> Void

    static let citeScheme = "retro-cite"

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space2) {
            Text("what i found")
                .rText(.labelMedium)
                .foregroundStyle(RColor.textLabel)
            Text(Self.attributed(answer.headline))
                .rText(.inkEntry)
                .foregroundStyle(RColor.textPrimary)
                .tint(RColor.textPrimary)
                .rBalancedLines()
            if let secondLine {
                Text(Self.attributed(secondLine))
                    .rText(.body)
                    .foregroundStyle(RColor.textSecondary)
                    .tint(RColor.textSecondary)
                    .rBalancedLines()
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RDimension.space5)
        .rRaised(RDimension.radiusCard)
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == Self.citeScheme, let number = Int(url.host() ?? "") else { return .systemAction }
            cite(number)
            return .handled
        })
        .accessibilityElement(children: .combine)
    }

    /// The words with each cited source as a superscript number that links to its row.
    static func attributed(_ runs: [Flows.Cited]) -> AttributedString {
        var text = AttributedString()
        for run in runs {
            text += AttributedString(run.text)
            if let source = run.source {
                var mark = AttributedString(superscript(source))
                mark.link = URL(string: "\(citeScheme)://\(source)")
                mark.accessibilityLabel = "source \(source)"
                text += mark
            }
        }
        return text
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
    @Binding var highlighted: Int?
    let open: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func rowID(_ number: Int) -> String {
        "source-\(number)"
    }

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
                    .background(highlighted == source.id ? RColor.surfaceSubtle : .clear)
                    .id(Self.rowID(source.id))
                }
            }
        }
        .task(id: highlighted) {
            // a cited row shows pressed for a beat, then fades back like any pressed row
            guard highlighted != nil else { return }
            try? await Task.sleep(for: .seconds(RNumber.motionDurationReveal))
            withAnimation(reduceMotion ? nil : RMotion.standard(RNumber.motionDurationPressOut)) {
                highlighted = nil
            }
        }
    }
}

/// "only what's certain · hides the 1 guess" with its switch (1G91-0). A tap anywhere on the wash row
/// toggles it (as the switch does); VoiceOver
/// reads it once, as the switch, with the subline as its hint.
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
