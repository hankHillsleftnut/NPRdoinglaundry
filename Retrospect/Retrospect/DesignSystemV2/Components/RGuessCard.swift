//
//  RGuessCard.swift
//  M14 C28: the guess card (design-system/components/guess-card.md; Paper "c · conversation"
//  B1B-0, the guess B7Q-0; legacy c6 27H-0 / 27U-0 for confirmed). Retro asks rather than tells:
//  the card looks unfinished until you answer. inference.surface, radius.card, a 1pt dashed
//  inference.border edge, padding 16, 12 between parts: the dot and "a guess", the question in
//  SF 17, where it came from and how sure Retro is, then "that's right" and "not quite".
//  Confirmed, the dash becomes a solid card that settles onto the page and the pills go.
//
import SwiftUI

struct RGuessCard: View {
    enum Verdict: Equatable { case yes, no }

    enum Phase: Equatable {
        case offered
        /// The answer is on its way; the chosen pill turns.
        case pending(Verdict)
        /// "that's right" landed: a solid card, "kept".
        case confirmed
        /// "not quite" landed: the pills go; the composer opens with "actually…" (the page's).
        case declined
        /// Saving the answer failed; the pills stay so it can be sent again.
        case failed
        /// Offline: the answer is kept on the phone and sent later.
        case savedOnPhone(Verdict)
    }

    /// Always a question.
    let question: String
    /// Where it came from: "from your last 3 mondays · calendar".
    let from: String
    /// How sure Retro is: "fairly sure".
    let sureness: String
    let phase: Phase
    let answer: (Verdict) -> Void
    /// Opens "why": what it rests on.
    let openWhy: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isConfirmed: Bool {
        phase == .confirmed || phase == .savedOnPhone(.yes)
    }

    private var showsPills: Bool {
        switch phase {
        case .offered, .pending, .failed: true
        case .confirmed, .declined, .savedOnPhone: false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space3) {
            if !isConfirmed {
                tag.transition(.opacity)
            }
            Text(question)
                .rText(.guessQuestion)
                .foregroundStyle(RColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            whyLine
            if let note {
                Text(note.text).rText(.metaLine).foregroundStyle(note.color).rBlurReplace()
            }
            if showsPills {
                pills.transition(.opacity)
            }
        }
        .padding(RDimension.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(RGuessSurface(confirmed: isConfirmed))
        .animation(reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.settle, value: isConfirmed)
        .animation(RMotion.standard(RNumber.motionDurationFast), value: phase)
        .sensoryFeedback(trigger: phase) { _, new in
            switch new {
            case .confirmed, .savedOnPhone: RHaptic.confirm
            case .declined: RHaptic.select
            case .failed: RHaptic.error
            case .offered, .pending: nil
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityActions {
            if showsPills, !isPending {
                Button("that's right") { answer(.yes) }
                Button("not quite") { answer(.no) }
            }
            Button("why", action: openWhy)
        }
        .rBlurReplace()
    }

    // MARK: - Parts

    /// A 6pt inference.marker dot and "a guess", 8 apart (B80-0).
    private var tag: some View {
        HStack(spacing: RDimension.space2) {
            Circle()
                .fill(RColor.inferenceMarker)
                .frame(width: RDimension.sizeStepDot, height: RDimension.sizeStepDot)
            Text("a guess")
                .rText(.metaLine)
                .foregroundStyle(RColor.textLabel)
        }
    }

    /// "from … · … · fairly sure" (B7Y-0); confirmed, "kept · from …" (27U-0). Tapping it opens why.
    private var whyLine: some View {
        Button(action: openWhy) {
            Group {
                if isConfirmed {
                    Text("kept · \(from)").foregroundStyle(RColor.textLabel)
                } else {
                    Text("\(from) · ").foregroundStyle(RColor.textLabel)
                        + Text(sureness).foregroundStyle(contrast == .increased ? RColor.textPrimary : RColor.textLabel)
                }
            }
            .rText(.metaLine)
            .multilineTextAlignment(.leading)
            // the line keeps Paper's 12 rhythm; its hit area reaches 44 beyond the words
            .contentShape(Rectangle().inset(by: -(RDimension.sizeTouchTarget - RDimension.space4) / 2))
        }
        .buttonStyle(RDimPressStyle())
    }

    /// The line under the why line after an answer that didn't land as usual.
    private var note: (text: String, color: Color)? {
        switch phase {
        case .failed: ("couldn't save that · try again", RColor.statusDangerText)
        case .savedOnPhone: ("saved on this phone", RColor.textLabel)
        default: nil
        }
    }

    private var pills: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: RDimension.space2))
            : AnyLayout(HStackLayout(spacing: RDimension.space2))
        return layout {
            RPill(title: "that's right", symbol: "checkmark", pending: phase == .pending(.yes)) { choose(.yes) }
                .disabled(isPending)
            RPill(title: "not quite", pending: phase == .pending(.no)) { choose(.no) }
                .disabled(isPending)
        }
    }

    private var isPending: Bool {
        if case .pending = phase {
            return true
        }
        return false
    }

    private func choose(_ verdict: Verdict) {
        // one verdict per answer: a second tap before the host moves to pending does nothing
        guard !isPending else { return }
        answer(verdict)
    }

    private var accessibilityText: String {
        let source = from.replacingOccurrences(of: " · ", with: ", ")
        if isConfirmed {
            return "kept: \(question). from \(source)."
        }
        var text = "a guess: \(question). \(sureness). from \(source)."
        if phase == .failed {
            text += " couldn't save that, try again."
        }
        return text
    }
}

extension RTextStyle {
    /// The guess itself (B7Z-0): SF 17, --tracking-card, leading snug.
    static let guessQuestion = RTextStyle(
        family: .text,
        size: RDimension.fontSizeBody,
        weight: .regular,
        tracking: RNumber.fontTrackingCard,
        leading: RTextStyle.textMd.leading,
        relativeTo: .body
    )
}

/// Unanswered: inference.surface with a dashed inference.border edge, no shadow. Confirmed: the
/// raised card (background.raised, its strokes and shadows), so it reads as kept.
private struct RGuessSurface: ViewModifier {
    let confirmed: Bool

    func body(content: Content) -> some View {
        // both surfaces stay in place and cross-fade, so confirming never re-creates the card
        content.background {
            ZStack {
                Color.clear
                    .rRaised(RDimension.radiusCard)
                    .opacity(confirmed ? 1 : 0)
                RShape.rect(RDimension.radiusCard)
                    .fill(RColor.inferenceSurface)
                    .overlay {
                        GeometryReader { proxy in
                            RShape.rect(RDimension.radiusCard).strokeBorder(
                                RColor.inferenceBorder,
                                style: StrokeStyle(lineWidth: RDimension.sizeBorderDefault, dash: [Self.evenDash(around: proxy.size)])
                            )
                        }
                    }
                    .opacity(confirmed ? 0 : 1)
            }
        }
    }

    /// The nearest dash to size.inference.dash that closes evenly around the card (as RTag does).
    private static func evenDash(around size: CGSize) -> CGFloat {
        let line = RDimension.sizeBorderDefault
        let width = size.width - line
        let height = size.height - line
        let radius = min(RDimension.radiusCard, min(width, height) / 2)
        let perimeter = 2 * (width + height) - 2 * radius * (4 - .pi)
        let pairs = max(1, (perimeter / (2 * RDimension.sizeInferenceDash)).rounded())
        return perimeter / (2 * pairs)
    }
}

/// A tappable line: it dims to opacity.sourcePressed while held.
private struct RDimPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? RNumber.opacitySourcePressed : 1)
            .animation(
                RMotion.standard(configuration.isPressed ? RNumber.motionDurationPressIn : RNumber.motionDurationPressOut),
                value: configuration.isPressed
            )
    }
}

#if DEBUG
/// Lab page "guess": every phase, and one card to answer. `-DesignLabAutoplay` answers it
/// ("that's right", pending, then confirmed), for recordings.
struct RGuessCardGallery: View {
    @State private var live: RGuessCard.Phase = .offered

    private let question = "Mondays are harder because of the 9am standup, not the work itself."
    private let from = "from your last 3 mondays · calendar"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space4) {
                caption("live")
                card(live) { verdict in
                    live = .pending(verdict)
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        live = verdict == .yes ? .confirmed : .declined
                    }
                }
                RPill(title: "ask again", style: .raised) { live = .offered }
                caption("offered")
                card(.offered)
                caption("pending")
                card(.pending(.yes))
                caption("couldn't save")
                card(.failed)
                caption("offline")
                card(.savedOnPhone(.no))
                caption("declined")
                card(.declined)
                caption("confirmed")
                card(.confirmed)
            }
            .padding(RDimension.spaceScreenMargin)
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-DesignLabAutoplay") else { return }
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            live = .pending(.yes)
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            live = .confirmed
        }
    }

    private func card(_ phase: RGuessCard.Phase, answer: @escaping (RGuessCard.Verdict) -> Void = { _ in }) -> some View {
        RGuessCard(question: question, from: from, sureness: "fairly sure", phase: phase, answer: answer) {}
    }

    private func caption(_ text: String) -> some View {
        Text(text).rText(.label).foregroundStyle(RColor.textLabel)
    }
}

#Preview("guess card") { RGuessCardGallery() }
#endif
