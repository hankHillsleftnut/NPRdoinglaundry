//
//  AnswerRow.swift
//  V2.you: one answer Retro holds about you (Paper YO-5 c:answer-row/rest 1T0Z-0, 1T0L-0, 1T04-0).
//  The question in Geist 12, the answer in SF 17, then how sure: the words, four 6pt dots (lit
//  text.secondary, unlit surface.track, 2 apart) and "· from n things". Padding 12 / 16, 4 between lines.
//  Rows sit in one grouped panel (REvidenceGroup: canvas, radius.panel, the 0.5 edge, 1pt lines).
//  Paper draws a ›, but what a row opens is not drawn (SCREEN-MAP row 91, DISCREPANCIES YO-D10): the row
//  is not a button and shows no › until its page exists. VoiceOver reads it as one line.
//
import SwiftUI

struct AnswerRow: View {
    let answer: Flows.KnownAnswer
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space1) {
            Text(answer.question)
                .rText(.metaLine)
                .foregroundStyle(RColor.textLabel)
            Text(answer.answer)
                .rText(.rowTitle)
                .foregroundStyle(RColor.textPrimary)
                .rBalancedLines()
            // at accessibility sizes the sure line stacks instead of running off the row
            sureLayout {
                Text(answer.howSure.words)
                    .rText(.metaLine)
                    .foregroundStyle(RColor.textLabel)
                HowSureDots(level: answer.howSure.level)
                Text("· from \(answer.restsOn) things")
                    .rText(.metaLine)
                    .foregroundStyle(RColor.textLabel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .padding(.vertical, RDimension.space3)
        .padding(.horizontal, RDimension.space4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spoken(answer))
    }

    private var sureLayout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: RDimension.space1))
            : AnyLayout(HStackLayout(spacing: RDimension.space2))
    }

    /// "what drives you most? building things people use. fairly sure, 3 of 4, from 9 things"
    static func spoken(_ answer: Flows.KnownAnswer) -> String {
        "\(answer.question) \(answer.answer) \(answer.howSure.words), \(answer.howSure.level) of \(Flows.HowSure.scale), from \(answer.restsOn) things"
    }
}

/// Four dots, `level` of them lit (Paper 1T0Z-0: 6pt, radius control, ring gap).
struct HowSureDots: View {
    let level: Int
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: RDimension.sizeBorderRing) {
            ForEach(0 ..< Flows.HowSure.scale, id: \.self) { index in
                Circle()
                    .fill(index < level ? RColor.textSecondary : unlit)
                    .frame(width: RDimension.sizeStepDot, height: RDimension.sizeStepDot)
            }
        }
        .accessibilityHidden(true)
    }

    /// Increase Contrast: the unlit dots take the track's fill so lit and unlit stay apart.
    private var unlit: Color {
        contrast == .increased ? RColor.surfaceTrackFill : RColor.surfaceTrack
    }
}
