//
//  GoalGuessCard.swift
//  V2.goals · the guess as the goals screens draw it (GL-1 c:goal-card/guess 1G35-0, GL-2
//  "c:claim/asked · a pattern" 1G45-0). Integrator 26 Oct (GL-D5): build the plain card the screens draw,
//  not the components page's dashed one (RClaim .asked, IYO-0); the mismatch is the founder's to settle.
//  surface.wash, radius.card, 12 between parts: a 32 well (background.canvas, radius.control, a 0.5
//  outer line) holding the guess glyph in accent.text, beside "a guess · a goal?"; the question in the
//  inky card face; then "yes" and "not quite", two equal 44 raised buttons 8 apart, 4 below the question.
//  GL-1 pads it 16 top / 20 sides and bottom, GL-2 16 all round (`padding`). Answering hands the verdict
//  up; the page takes the card away (the answered look isn't drawn).
//
import SwiftUI

struct GoalGuessCard: View {
    enum Padding {
        /// GL-1: 16 top, 20 sides and bottom.
        case card
        /// GL-2: 16 all round.
        case compact
    }

    let guess: GoalGuess
    var padding: Padding = .card
    let answer: (_ accepted: Bool) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space3) {
            HStack(spacing: RDimension.space2) {
                RIconWell(
                    symbol: "sparkles",
                    tint: RColor.accentText,
                    fill: RColor.backgroundCanvas,
                    glyphScale: RSymbol.defaultGlyphScale * RDimension.sizeIconInWell / RDimension.sizeIconDefault
                )
                .clipShape(RShape.rect(RDimension.radiusControl))
                .overlay(RShape.rect(RDimension.radiusControl).stroke(RColor.depthStrokeOuter, lineWidth: RDimension.sizeBorderHairline))
                .accessibilityHidden(true)
                Text(guess.label)
                    .rText(.claimGuessLabel)
                    .foregroundStyle(RColor.textLabel)
            }
            Text(guess.question)
                .rText(.inkCard)
                .foregroundStyle(RColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            answers
                .padding(.top, RDimension.space1)
        }
        .padding(.top, RDimension.space4)
        .padding([.horizontal, .bottom], padding == .card ? RDimension.space5 : RDimension.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RColor.surfaceWash, in: RShape.rect(RDimension.radiusCard))
        .accessibilityElement(children: .contain)
    }

    private var answers: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: RDimension.space2))
            : AnyLayout(HStackLayout(spacing: RDimension.space2))
        return layout {
            Button("yes") { answer(true) }
                .buttonStyle(GoalAnswerStyle())
            Button("not quite") { answer(false) }
                .buttonStyle(GoalAnswerStyle())
        }
    }
}

/// One of a guess's two answers (1G39-0 / 1G37-0): the raised pill's paper look (`rSecondaryPaper`),
/// stretched to half the row and 44 tall, the words in SF 14 semibold.
private struct GoalAnswerStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .rText(.goalAnswer)
            .foregroundStyle(RColor.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, RDimension.space4)
            .frame(maxWidth: .infinity, minHeight: RDimension.sizeNavBar)
            .rSecondaryPaper(pressed: pressed)
            .scaleEffect(pressed && !reduceMotion ? RNumber.motionScalePressSmall : 1)
            .animation(RMotion.standard(pressed ? RNumber.motionDurationPressIn : RNumber.motionDurationPressOut), value: pressed)
            .contentShape(RShape.rect(RDimension.radiusControl))
    }
}
