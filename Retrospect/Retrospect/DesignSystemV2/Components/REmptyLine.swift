//
//  REmptyLine.swift
//  M14 C39.2: the empty state (design-system/components/loading-and-empty.md, reference §C39;
//  Paper G7O-0, the drawer's "nothing yet" and "no results", and M3's E4L-0). Never a blank
//  screen and never an illustration: a 52 raised mark (rEmptyMark) with a 24 glyph in
//  icon.muted, 12 above an SF 17 line in text.secondary (tracking.card) that says what will be
//  here, and an SF 14 text.tertiary line under it (gap 4) that says how it fills; centred,
//  padded 40 / 16, wrapping without a one-word last line. At most one action, as a text
//  button. It arrives with the appear stagger (mark, line, subline) and then stays still.
//
import SwiftUI

struct REmptyLine: View {
    /// One thing the person can do from here, as a plain text button; usually none.
    struct Action {
        let title: String
        let perform: () -> Void
    }

    /// What will be here ("nothing yet. say anything.").
    let line: String
    /// How it fills ("what you say shows up here, by day"); nil for a one-line state.
    var subline: String?
    /// The glyph in the raised mark (an SF Symbol name); nil shows no mark, only the words.
    var symbol: String?
    var action: Action?

    /// What VoiceOver reads: the line, then the subline, as one sentence.
    static func spoken(line: String, subline: String?) -> String {
        subline.map { "\(line) \($0)" } ?? line
    }

    var body: some View {
        VStack(spacing: RDimension.space1) {
            if let symbol {
                RSymbol(name: symbol, size: .large, tint: RColor.iconMuted)
                    .frame(width: RDimension.sizeEmptyMark, height: RDimension.sizeEmptyMark)
                    .rEmptyMark()
                    .padding(.bottom, RDimension.space3 - RDimension.space1)
                    .rAppear(index: 0)
                    .accessibilityHidden(true)
            }
            Text(line)
                .rText(.bodyReading)
                .foregroundStyle(RColor.textSecondary)
                .rAppear(index: 1)
            if let subline {
                Text(subline)
                    .rText(.textMd)
                    .foregroundStyle(RColor.textTertiary)
                    .rAppear(index: 2)
            }
            if let action {
                RButton(title: action.title, variant: .text, action: action.perform)
                    .padding(.top, RDimension.space2)
                    .rAppear(index: 3)
                    .accessibilityIdentifier("empty.action")
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, RDimension.space10)
        .padding(.horizontal, RDimension.space4)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Self.spoken(line: line, subline: subline))
    }
}

#if DEBUG
/// Lab page "empty": the drawer's first day, search with no results, a one-line state, and one
/// with an action. `-DesignLabAutoplay` re-inserts the first so the stagger can be recorded.
struct REmptyLineGallery: View {
    @State private var shown = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space6) {
                caption("drawer · nothing yet (G7O-0)")
                VStack {
                    if shown {
                        REmptyLine(line: "nothing yet. say anything.", subline: "what you say shows up here, by day", symbol: "bubble.left")
                    }
                }
                .frame(maxWidth: .infinity, minHeight: RDimension.sizeIllustration)
                .rWash(RDimension.radiusPanel)
                RPill(title: "again", style: .raised) {
                    shown = false
                    Task {
                        try? await Task.sleep(for: .seconds(RNumber.motionDurationFast))
                        shown = true
                    }
                }
                caption("search · no results")
                REmptyLine(line: "nothing with that word yet", subline: "try another word you might have said", symbol: "magnifyingglass")
                    .rWash(RDimension.radiusPanel)
                caption("one line, no mark")
                REmptyLine(line: "nothing much moved. enjoy the quiet.")
                    .rWash(RDimension.radiusPanel)
                caption("with one action")
                REmptyLine(
                    line: "no goals yet.",
                    subline: "say what you're working toward, or wait and i'll notice.",
                    symbol: "flag",
                    action: .init(title: "say one now") {}
                )
                .rWash(RDimension.radiusPanel)
            }
            .padding(RDimension.spaceScreenMargin)
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-DesignLabAutoplay") else { return }
            for _ in 0 ..< 2 {
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                shown = false
                do { try await Task.sleep(for: .seconds(RNumber.motionDurationFast)) } catch { return }
                shown = true
            }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text).rText(.label).foregroundStyle(RColor.textLabel)
    }
}

#Preview("empty line") { REmptyLineGallery() }
#endif
