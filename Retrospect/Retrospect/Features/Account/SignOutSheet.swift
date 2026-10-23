//
//  SignOutSheet.swift
//  P33 / C48: the sign-out sheet (AC-2). Signing out never loses anything: if something you wrote hasn't
//  sent, it goes first and you see it go. Values from Paper `1GVR-0` (read-only; Paper Desktop open):
//  the sheet's content only (the host draws the raised panel, grabber and scrim), 24 margins, the text
//  block 8 apart, the unsent card 16 below, the actions 32 below and 4 apart. With nothing waiting there
//  is no lit object (a non-event): "sign out" is the secondary button. "sign out anyway" exists only
//  when the flow is stuck.
//
import SwiftUI

extension SignOutSheet {
    /// Full height at accessibility sizes (the words grow; the actions stay visible), half height otherwise.
    static func detent(for size: DynamicTypeSize) -> RSheetDetent {
        size.isAccessibilitySize ? .full : .medium
    }
}

struct SignOutSheet: View {
    let flow: any SignOutFlowing
    var provider = "apple"
    let dismiss: () -> Void
    /// Which button began the sign-out, so the wait keeps its words (the secondary one is not a lit "send").
    @State private var sentFirst = false

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space0) {
            textBlock
            if let card {
                unsentCard(card)
                    .padding(.top, RDimension.space4)
                    .transition(.blurReplace)
            }
            actions
                .padding(.top, RDimension.space8)
        }
        .padding(.horizontal, RDimension.spaceScreenMargin)
        .padding(.top, RDimension.space2)
        .padding(.bottom, RDimension.space10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(RMotion.standard(RNumber.motionDurationBase), value: flow.state)
        .sensoryFeedback(RHaptic.warning, trigger: isStuck) { _, now in now }
        .sensoryFeedback(RHaptic.confirm, trigger: flow.state == .done) { _, now in now }
        .onChange(of: flow.state) { _, now in
            if now == .done {
                dismiss()
            }
            if case let .stuck(remaining, reason) = now {
                AccessibilityNotification.Announcement(Self.stuckTitle(remaining: remaining, reason: reason)).post()
            }
        }
        // A swipe down or a scrim tap closes the sheet without "cancel": that must stop the send too, or a
        // sheet the person put away could still finish and sign them out with nothing on screen.
        .onDisappear { flow.cancel() }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("screen.AC-2")
    }

    // MARK: Words

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: RDimension.space2) {
            Text("sign out?")
                .rText(.displayTitle)
                .foregroundStyle(RColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(body(for: flow.state))
                .rText(.body)
                .foregroundStyle(RColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .id(body(for: flow.state))
                .transition(.blurReplace)
        }
        .padding(.top, RDimension.space5)
    }

    /// "stay safe" is true only for what was sent; with words still on the phone the sheet says so.
    private func body(for state: SignOutState) -> String {
        if case .stuck = state {
            return "some of what you wrote hasn't reached retrospect yet."
        }
        return "your entries, episodes and everything retro knows stay safe. sign back in with \(provider) any time."
    }

    static func unsentTitle(_ count: Int) -> String {
        count == 1 ? "1 entry hasn't sent yet" : "\(count) entries haven't sent yet"
    }

    /// Under the unsent count: what happens to them (Paper `1GVZ-0`, made plural-correct).
    static func unsentLine(_ count: Int) -> String {
        count == 1 ? "it goes first, so nothing is lost." : "they go first, so nothing is lost."
    }

    /// Under the stuck count: what signing out now would cost, or what to do.
    static func stuckLine(remaining: Int, reason: SignOutState.StuckReason) -> String {
        switch reason {
        case .updateRequired:
            remaining == 1 ? "update retrospect and it'll go; signing out now loses it." : "update retrospect and they'll go; signing out now loses them."
        case .offline, .failed: remaining == 1 ? "if you sign out now, it's lost from this phone." : "if you sign out now, they're lost from this phone."
        }
    }

    /// What "sign out anyway" costs, read by VoiceOver with the button (decision 1: name the count).
    static func anywayHint(remaining: Int) -> String {
        remaining == 1 ? "1 unsent entry will be erased from this phone" : "\(remaining) unsent entries will be erased from this phone"
    }

    static func stuckTitle(remaining: Int, reason: SignOutState.StuckReason) -> String {
        switch reason {
        case .updateRequired: remaining == 1 ? "1 entry is waiting for an update" : "\(remaining) entries are waiting for an update"
        case .offline, .failed: remaining == 1 ? "1 entry can't send right now" : "\(remaining) entries can't send right now"
        }
    }

    private struct Card: Equatable {
        let title: String
        let line: String
        let rolls: Int?
        let spins: Bool
    }

    private var card: Card? {
        switch flow.state {
        case let .asking(unsent) where unsent > 0:
            // Paper AC-2 (`1GW1-0`) draws the waiting entry with the spinner, not a warning: nothing is wrong yet.
            Card(title: Self.unsentTitle(unsent), line: Self.unsentLine(unsent), rolls: nil, spins: true)
        case let .sending(remaining):
            Card(title: Self.unsentTitle(remaining), line: Self.unsentLine(remaining), rolls: remaining, spins: true)
        case .signingOut:
            Card(title: "all sent", line: "signing you out…", rolls: nil, spins: true)
        case let .stuck(remaining, reason):
            Card(
                title: Self.stuckTitle(remaining: remaining, reason: reason),
                line: Self.stuckLine(remaining: remaining, reason: reason),
                rolls: nil, spins: false
            )
        default:
            nil
        }
    }

    private func unsentCard(_ card: Card) -> some View {
        HStack(spacing: RDimension.space3) {
            if card.spins {
                RSpinner(diameter: RDimension.sizeIconDefault)
            } else {
                RSymbol(name: "exclamationmark.circle", tint: RColor.statusDanger)
            }
            VStack(alignment: .leading, spacing: RDimension.sizeBorderRing) {
                Text(card.title)
                    .rText(.textMdMedium)
                    .foregroundStyle(RColor.textPrimary)
                    .contentTransition(.numericText(value: Double(card.rolls ?? 0)))
                    .fixedSize(horizontal: false, vertical: true)
                Text(card.line)
                    .rText(.label)
                    .foregroundStyle(RColor.textLabel)
                    .fixedSize(horizontal: false, vertical: true)
                    .id(card.line)
                    .transition(.blurReplace)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, RDimension.space3)
        .padding(.horizontal, RDimension.space4)
        .background(RColor.surfaceWash, in: RShape.rect(RDimension.radiusPanel))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("signout.card")
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: RDimension.space1) {
            switch flow.state {
            case let .asking(unsent):
                if unsent > 0 {
                    RButton(title: "send, then sign out") { sentFirst = true; flow.begin() }
                        .accessibilityIdentifier("signout.confirm")
                } else {
                    RButton(title: "sign out", variant: .secondary) { flow.begin() }
                        .accessibilityIdentifier("signout.confirm")
                }
                cancelButton("cancel", enabled: true)
            case .sending, .signingOut:
                // Sending is always the send button; in .signingOut the secondary "sign out" the person
                // pressed (nothing to send) stays that button, not a lit one.
                let sends: Bool = if case .sending = flow.state {
                    true
                } else {
                    sentFirst
                }
                RButton(title: sends ? "send, then sign out" : "sign out", variant: sends ? .primary : .secondary, status: .pending) {}
                    .accessibilityIdentifier("signout.confirm")
                cancelButton("cancel", enabled: false)
            case let .stuck(remaining, _):
                RButton(title: "wait", variant: .secondary) { flow.cancel(); dismiss() }
                    .accessibilityIdentifier("signout.cancel")
                SignOutAnywayButton(hint: Self.anywayHint(remaining: remaining)) { flow.signOutAnyway() }
            case .done:
                EmptyView()
            }
        }
    }

    private func cancelButton(_ title: String, enabled: Bool) -> some View {
        RButton(title: title, variant: .text) {
            flow.cancel()
            dismiss()
        }
        .disabled(!enabled)
        .accessibilityIdentifier("signout.cancel")
    }

    private var isStuck: Bool {
        if case .stuck = flow.state {
            true
        } else {
            false
        }
    }
}

/// "sign out anyway": a text action in the danger colour. It warns on touch-down, dims to 0.7 while pressed,
/// and is read with what it costs.
private struct SignOutAnywayButton: View {
    let hint: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("sign out anyway")
                .rText(.bodyMedium)
                .frame(minHeight: RDimension.sizeControlDefault)
                .padding(.horizontal, RDimension.space3)
                .contentShape(Rectangle())
        }
        .buttonStyle(AnywayStyle())
        .accessibilityHint(hint)
        .accessibilityIdentifier("signout.anyway")
    }
}

private struct AnywayStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(RColor.statusDangerText)
            .opacity(configuration.isPressed ? RNumber.opacitySourcePressed : 1)
            .animation(RMotion.standard(RNumber.motionDurationPressIn), value: configuration.isPressed)
            .sensoryFeedback(trigger: configuration.isPressed) { _, now in now ? RHaptic.warning : nil }
    }
}
