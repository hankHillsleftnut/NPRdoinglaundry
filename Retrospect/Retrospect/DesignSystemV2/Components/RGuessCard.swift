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
    /// Sends the answer; the card sends one verdict at a time, until this returns.
    let answer: (Verdict) async -> Void
    /// Opens "why": what it rests on.
    let openWhy: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var once = RAnswerOnce()

    private var isConfirmed: Bool {
        phase == .confirmed || phase == .savedOnPhone(.yes)
    }

    /// "not quite" landed (or is kept on the phone): the card steps back to opacity.declined.
    private var isDeclined: Bool {
        phase == .declined || phase == .savedOnPhone(.no)
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
        .modifier(RGuessSurface(confirmed: isConfirmed, increasedContrast: contrast == .increased))
        // one layer, so the surface and the words dim together
        .compositingGroup()
        .opacity(isDeclined ? RNumber.opacityDeclined : 1)
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
            // the same path as a tap: one verdict at a time
            if showsPills, !isPending {
                Button("that's right") { choose(.yes) }
                Button("not quite") { choose(.no) }
            }
            Button("why", action: openWhy)
        }
        .onChange(of: phase) { _, new in
            // once per change, never on appearing
            if let announcement = Self.announcement(for: new) {
                AccessibilityNotification.Announcement(announcement).post()
            }
        }
        .rBlurReplace()
    }

    static func announcement(for phase: Phase) -> String? {
        switch phase {
        case .confirmed: "kept"
        case .failed: "couldn't save that, try again"
        case .savedOnPhone: "saved on this phone"
        case .offered, .pending, .declined: nil
        }
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
            whyText
                .rText(.metaLine)
                .multilineTextAlignment(.leading)
                // the line keeps Paper's 12 rhythm; its hit area reaches 44 beyond the words
                .contentShape(Rectangle().inset(by: -(RDimension.sizeTouchTarget - RDimension.space4) / 2))
        }
        .buttonStyle(RDimPressStyle())
    }

    /// One Text whatever the phase, so confirming changes its words, not its identity.
    private var whyText: Text {
        if isConfirmed {
            return Text("kept · \(from)").foregroundStyle(RColor.textLabel)
        }
        return Text("\(from) · ").foregroundStyle(RColor.textLabel)
            + Text(sureness).foregroundStyle(contrast == .increased ? RColor.textPrimary : RColor.textLabel)
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
            RPill(title: "that's right", symbol: "checkmark", size: .medium, pending: phase == .pending(.yes)) { choose(.yes) }
                .disabled(isPending)
            RPill(title: "not quite", size: .medium, pending: phase == .pending(.no)) { choose(.no) }
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
        Task { await once.send { await answer(verdict) } }
    }

    /// What VoiceOver reads for the whole card (commas, not dots).
    var accessibilityText: String {
        let source = from.replacingOccurrences(of: " · ", with: ", ")
        // the question ends once, whether or not it came with its own stop
        let sentence = question.last.map { ".?!".contains($0) } == true ? question : question + "."
        if isConfirmed {
            // `from` already starts with "from"
            return "kept: \(sentence) \(source)."
        }
        var text = "a guess: \(sentence) \(sureness). \(source)."
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
    /// Increase Contrast: the dash thickens to size.inference.edgeIncreased.
    let increasedContrast: Bool

    private var line: CGFloat {
        increasedContrast ? RDimension.sizeInferenceEdgeIncreased : RDimension.sizeBorderDefault
    }

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
                                style: StrokeStyle(
                                    lineWidth: line,
                                    dash: [RInferenceEdge.dash(around: proxy.size, cornerRadius: RDimension.radiusCard, line: line)]
                                )
                            )
                        }
                    }
                    .opacity(confirmed ? 0 : 1)
            }
        }
    }
}

/// One answer in flight at a time: a second tap (or VoiceOver action) while the first is still
/// being sent does nothing, even before the host has moved the card to pending.
@MainActor
final class RAnswerOnce {
    private(set) var isSending = false

    func send(_ action: () async -> Void) async {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }
        await action()
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
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                    live = verdict == .yes ? .confirmed : .declined
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

    private func card(_ phase: RGuessCard.Phase, answer: @escaping (RGuessCard.Verdict) async -> Void = { _ in }) -> some View {
        RGuessCard(question: question, from: from, sureness: "fairly sure", phase: phase, answer: answer) {}
    }

    private func caption(_ text: String) -> some View {
        Text(text).rText(.label).foregroundStyle(RColor.textLabel)
    }
}

#Preview("guess card") { RGuessCardGallery() }
#endif
