//
//  QuestionsWords.swift
//  QU.followups.a: your words as they are heard (Paper c:onboarding/your-words 1F6R-0 on ON-4a
//  1F6C-0). A wrapping row with spacing-2 between words and no gap between lines; each word is its
//  own text in the inky card face at 2xl, text.secondary (`.answerWords`). A new word blurs in:
//  blur 4 → 0 and opacity 0 → 1 over 200 ms on curve.standard (build notes, part 42; Paper draws
//  the newest word mid-way, 1F6S-0 "word · blurring in"). Reduce Motion: opacity only.
//  VoiceOver reads the row as one line, "your words, …", and hears it grow.
//
import SwiftUI

struct QuestionsWords: View {
    let words: [QuestionsModel.HeardWord]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RFlowLayout(spacing: RDimension.space2) {
            ForEach(words) { word in
                Text(word.text)
                    .rText(.answerWords)
                    .foregroundStyle(RColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(arrival)
            }
        }
        .animation(RMotion.standard(RNumber.motionDurationBase), value: words)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("your words")
        .accessibilityValue(words.map(\.text).joined(separator: " "))
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("questions.heard")
    }

    /// In: blur 4 → 0 with the fade; out (the row clearing) a plain fade.
    private var arrival: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .modifier(
                active: WordArrival(blur: RDimension.motionAppearBlurFrom / 2, opacity: 0),
                identity: WordArrival(blur: 0, opacity: 1)
            ),
            removal: .opacity
        )
    }
}

/// One word landing: blurred and see-through as it arrives, sharp and solid at rest.
private struct WordArrival: ViewModifier {
    let blur: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .blur(radius: blur)
            .opacity(opacity)
    }
}
