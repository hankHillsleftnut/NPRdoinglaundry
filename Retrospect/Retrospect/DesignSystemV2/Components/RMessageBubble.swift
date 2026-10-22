//
//  RMessageBubble.swift
//  M14 C30.1: your message in the thread (design-system/components/message.md "mine"; Paper
//  c:message/mine/rest 1FLH-0, part 08's states grid C3A-0, not sent C5U-0). A warm wash
//  bubble (message.mine, no shadow) on the trailing side, radius.message 18 on three corners
//  and size.border.inset 4 on the bottom-trailing one, padding 12/16, SF 17 with
//  tracking.card and leading snug in text.primary. It hugs its words up to 0.8 of the column
//  and never past 280 (Paper's 264 bubble on the 342 column; founder, 20 Oct: "why is the line
//  width in these messages so short?"). Sending, it sits at opacity.pending with no spinner
//  and no word. Under it, only when there is something to say: "will send when you're back
//  online" (grey, offline glyph) or "not sent · tap to retry" (status.dangerText, retry glyph),
//  4 below, blur-replacing in and out. Nothing on a sent message: Paper draws no receipts.
//  The thread owns the turn spacing, the day labels and the M08 lift's namespace (passed in
//  as `lift`); the flow owns the delivery state (the host maps the entry's outbox state).
//
import SwiftUI

struct RMessageBubble: View {
    /// Where the entry is on its way to the server, from the flow's `Entry.Delivery`.
    enum Delivery: Equatable {
        /// Safely in: no status line.
        case sent
        /// On its way: the bubble sits at opacity.pending, nothing under it.
        case sending
        /// Offline, saved on the phone: "will send when you're back online", grey.
        case waiting
        /// Didn't send: "not sent · tap to retry"; the status line retries.
        case notSent
    }

    /// The line under the bubble, when there is one.
    enum Status: Equatable {
        case waiting, notSent

        init?(_ delivery: Delivery) {
            switch delivery {
            case .sent, .sending: return nil
            case .waiting: self = .waiting
            case .notSent: self = .notSent
            }
        }

        /// Paper's words (C3A-0 "offline" and "not sent").
        var text: String {
            switch self {
            case .waiting: "will send when you're back online"
            case .notSent: "not sent · tap to retry"
            }
        }

        var symbol: String {
            switch self {
            case .waiting: "wifi.slash"
            case .notSent: "arrow.clockwise"
            }
        }

        var colour: Color {
            switch self {
            case .waiting: RColor.textLabel
            case .notSent: RColor.statusDangerText
            }
        }
    }

    /// The M08 lift: the thread owns the namespace and passes it with the entry's id, so the
    /// bubble is the destination of the composer's words. Nil everywhere else (loaded threads).
    struct Lift {
        let id: String
        let namespace: Namespace.ID
    }

    /// Your words, exactly as you wrote or said them.
    let text: String
    var delivery: Delivery = .sent
    var lift: Lift?
    /// Sends it again (the host's retry for this entry); only used when it didn't send.
    var retry: () -> Void = {}

    /// The column the bubble sits in, measured from the row it fills.
    @State private var columnWidth: CGFloat = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var contrast

    /// Widest share of the column a bubble takes (message.md: "~80% of the column").
    static let widestShare: CGFloat = 0.8
    /// And never wider than this, however wide the column (message.md: "280 on 17 Pro").
    static let widestPoints: CGFloat = 280

    /// The bubble's widest frame: 0.8 of the column, never past 280. At accessibility text
    /// sizes it takes the full column (message.md; Paper c:message/mine/ax3).
    static func maxWidth(column: CGFloat, accessibilitySize: Bool) -> CGFloat {
        guard !accessibilitySize else { return .infinity }
        guard column > 0 else { return widestPoints }
        return min(widestPoints, column * widestShare)
    }

    private var status: Status? {
        Status(delivery)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: RDimension.space1) {
            // the spacer takes what the words don't, so the bubble hugs short lines and wraps
            // long ones inside the cap
            HStack(spacing: RDimension.space0) {
                Spacer(minLength: RDimension.space0)
                bubble
            }
            .frame(maxWidth: Self.maxWidth(column: columnWidth, accessibilitySize: dynamicTypeSize.isAccessibilitySize))
            if let status {
                RMessageStatusLine(status: status, retry: retry)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .background {
            Color.clear.onGeometryChange(for: CGFloat.self) { $0.size.width } action: { columnWidth = $0 }
        }
        .animation(RMotion.standard(RNumber.motionDurationFast), value: delivery)
        // once per failure: a retry that fails again goes through sending first, so it buzzes again
        .sensoryFeedback(RHaptic.error, trigger: delivery == .notSent) { old, new in !old && new }
        .accessibilityElement(children: .contain)
    }

    private var bubble: some View {
        Text(text)
            .rText(.messageMine)
            .foregroundStyle(RColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, RDimension.space3)
            .padding(.horizontal, RDimension.space4)
            .background(RColor.messageMine, in: Self.shape)
            // Increase Contrast: a 1pt edge so the shape holds without the wash (C3A-0 "increase contrast")
            .overlay(Self.shape.strokeBorder(RColor.borderControl, lineWidth: contrast == .increased ? RDimension.sizeBorderDefault : RDimension.space0))
            .compositingGroup()
            .opacity(delivery == .sending ? RNumber.opacityPending : 1)
            .rLift(lift)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("you: \(text)")
    }

    /// The bubble's corners: radius.message on three, size.border.inset on the one on your
    /// side, each set on its own (message.md), in the token corner style. Shared with the
    /// voice note (`RVoiceBubble`).
    static var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: RDimension.radiusMessage,
            bottomLeadingRadius: RDimension.radiusMessage,
            bottomTrailingRadius: RDimension.sizeBorderInset,
            topTrailingRadius: RDimension.radiusMessage,
            style: RCorner.style
        )
    }

    /// What VoiceOver reads: the same words with a comma for the dot.
    static func spoken(_ text: String) -> String {
        text.replacingOccurrences(of: " · ", with: ", ")
    }
}

/// The line under a bubble of yours (text or voice): grey while it waits, danger when it didn't
/// send. The not-sent line is the retry; the waiting line is only words. It blur-replaces in
/// and out.
struct RMessageStatusLine: View {
    let status: RMessageBubble.Status
    var retry: () -> Void = {}

    var body: some View {
        switch status {
        case .waiting:
            line
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(RMessageBubble.spoken(status.text))
                .rBlurReplace()
        case .notSent:
            // a button only where a tap does something: the line is the retry
            Button(action: retry) {
                line
                    // a 44 hit area around a 16 line, without moving the thread's rhythm
                    .contentShape(Rectangle().inset(by: -RDimension.space4))
            }
            .buttonStyle(RStatusPressStyle())
            .accessibilityLabel("not sent")
            .accessibilityHint("double tap to retry")
            .accessibilityIdentifier("message.retry")
            .rBlurReplace()
        }
    }

    private var line: some View {
        // the glyph takes the label's font, so it sits on the baseline and grows with Dynamic Type
        HStack(alignment: .firstTextBaseline, spacing: RDimension.space1) {
            Image(systemName: status.symbol)
                .imageScale(.small)
                .accessibilityHidden(true)
            Text(status.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .rText(.metaLine)
        .foregroundStyle(status.colour)
        .multilineTextAlignment(.trailing)
    }
}

/// Tap "not sent": the line dims to opacity.pending on touch down (in 80ms) and comes back on
/// release (snappy). No scale, no haptic: it's a line, not a control that moves.
private struct RStatusPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? RNumber.opacityPending : 1)
            .animation(
                configuration.isPressed
                    ? RMotion.standard(RNumber.motionDurationPressIn)
                    : RMotion.snappy,
                value: configuration.isPressed
            )
    }
}

private extension View {
    /// Takes part in the M08 lift when the thread passes one; otherwise the bubble as it is.
    /// The lift is fixed at init (a loaded entry never gains one), so this never changes identity
    /// at runtime.
    @ViewBuilder
    func rLift(_ lift: RMessageBubble.Lift?) -> some View {
        if let lift {
            matchedGeometryEffect(id: lift.id, in: lift.namespace)
        } else {
            self
        }
    }
}

extension RTextStyle {
    /// Your words in a bubble (Paper 1FLH-0: --font-text, --text-body, --tracking-card,
    /// --leading-snug): reading tracking on a snug line, between `.body` and `.bodyReading`.
    static let messageMine = RTextStyle(
        family: .text,
        size: RDimension.fontSizeBody,
        weight: .regular,
        tracking: RNumber.fontTrackingCard,
        leading: 1.3,
        relativeTo: .body
    )
}

#if DEBUG
/// Lab page "message": your bubble in every state, then a send that lands and a send that
/// fails and is retried. `-DesignLabAutoplay` runs both sends in turn, for recordings.
struct RMessageBubbleGallery: View {
    /// The entry sent from the lab's composer stand-in.
    @State private var sent: RMessageBubble.Delivery = .sent
    @State private var sentShown = false
    /// The entry whose send fails; its retry lands.
    @State private var failed: RMessageBubble.Delivery = .notSent
    @State private var attempts = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space6) {
                caption("sent · hugs short words, wraps long ones (1FLH-0)")
                VStack(alignment: .trailing, spacing: RDimension.space2) {
                    RMessageBubble(text: "yes")
                    RMessageBubble(text: "dentist at 3 today, dreading it")
                    RMessageBubble(text: "walked the long way home by the canal. felt lighter after.")
                }
                caption("sending · opacity.pending, no spinner, no word")
                RMessageBubble(text: "notes from the planning call: ship the first version friday", delivery: .sending)
                caption("offline · waits on the phone")
                RMessageBubble(text: "lunch outside for once. twenty minutes, no phone.", delivery: .waiting)
                caption("not sent · tap the line to retry")
                RMessageBubble(text: "cooked instead of ordering in. small win.", delivery: .notSent)
                caption("a send that lands")
                VStack(alignment: .trailing, spacing: RDimension.space2) {
                    if sentShown {
                        RMessageBubble(text: "can't stop running through the friday demo in my head.", delivery: sent)
                            .transition(.opacity.animation(RMotion.standard(RNumber.motionDurationFast)))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: RDimension.sizeTouchTarget, alignment: .topTrailing)
                RPill(title: "send", style: .raised) { Task { await send() } }
                    .disabled(sent == .sending)
                caption("a send that fails · retry lands (attempt \(attempts))")
                RMessageBubble(text: "good call with sam about the launch plan", delivery: failed) { Task { await retryFailed() } }
                RPill(title: "fail it again", style: .raised) { Task { await failAgain() } }
                    .disabled(failed == .sending)
            }
            .padding(RDimension.spaceScreenMargin)
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-DesignLabAutoplay") else { return }
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            await send()
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            await failAgain()
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            await retryFailed()
        }
    }

    /// Sending for a second, then sent.
    private func send() async {
        sent = .sending
        sentShown = true
        do { try await Task.sleep(for: .seconds(1)) } catch { return }
        sent = .sent
    }

    /// A retry that lands: sending, then sent.
    private func retryFailed() async {
        attempts += 1
        failed = .sending
        do { try await Task.sleep(for: .seconds(1)) } catch { return }
        failed = .sent
    }

    /// A send (or retry) that fails again: sending, then not sent, with the buzz.
    private func failAgain() async {
        attempts += 1
        failed = .sending
        do { try await Task.sleep(for: .seconds(1)) } catch { return }
        failed = .notSent
    }

    private func caption(_ text: String) -> some View {
        Text(text).rText(.label).foregroundStyle(RColor.textLabel)
    }
}

#Preview("message bubble") { RMessageBubbleGallery() }
#endif
