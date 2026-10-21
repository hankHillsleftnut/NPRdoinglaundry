//
//  RSourceRow.swift
//  M14 C10: the source row (Paper approvals · part 26 c:settings-row/source/{rest,problem,
//  syncing}; the approved journey map's ON-6 rows; ios-handoff ST-3). A place Retrospect can
//  learn from: the source's well, what it is, why it's there (purpose, never permission), and
//  its status in words with a dot (never colour alone), or a raised "connect" pill.
//  The settings row's frame (part 22): min 56, 16 / 24 padding, 12 between parts.
//
import SwiftUI

struct RSourceRow: View {
    enum State: Equatable {
        /// A raised "connect" pill; the only thing to do is connect.
        case notConnected
        case connected
        case syncing
        /// It stopped working: the dot is source.problem and the word says "reconnect".
        case needsAttention
        case unavailable
    }

    /// Settings rows pad 16 above and below (part 26); onboarding's connect list pads 12 (ON-6).
    enum Density { case settings, onboarding }

    let title: String
    /// Why it's there ("so your brief knows your day"), not what it reads.
    let purpose: String
    let symbol: String
    var state: State = .notConnected
    var density: Density = .settings
    var connect: () -> Void = {}
    /// Opens the source's own page; nil where the row only connects (onboarding).
    var open: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: RDimension.space3) {
            RIconWell(symbol: symbol)
                // like the words and the status, the well lets taps through to the row behind it
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            // at accessibility sizes the status or pill moves under the words instead of squeezing them
            let parts = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: RDimension.space2))
                : AnyLayout(HStackLayout(spacing: RDimension.space3))
            parts {
                VStack(alignment: .leading, spacing: RDimension.sizeBorderRing) {
                    Text(title)
                        .rText(.rowTitle)
                        .foregroundStyle(RColor.textPrimary)
                    Text(purpose)
                        .rText(.textMd)
                        .foregroundStyle(RColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .allowsHitTesting(false)
                .accessibilityElement(children: .combine)
                trailing
            }
        }
        .padding(.vertical, density == .settings ? RDimension.space4 : RDimension.space3)
        .padding(.horizontal, RDimension.spaceScreenMargin)
        .frame(maxWidth: .infinity, minHeight: RDimension.sizeRowDefault)
        // the row's own target sits behind the content, so the connect pill keeps its own 44
        .background {
            if let open {
                Button(action: open) { Color.clear.contentShape(Rectangle()) }
                    .buttonStyle(RSourceRowPressStyle())
                    .accessibilityHidden(true)
            }
        }
        .animation(RMotion.standard(RNumber.motionDurationBase), value: state)
        // one element ("calendar, so your brief knows your day, connected"); with the pill showing,
        // the words and the connect button stay two, so connect can be reached on its own
        .accessibilityElement(children: state == .notConnected ? .contain : .combine)
        .accessibilityAddTraits(open == nil || state == .notConnected ? [] : .isButton)
        // a default action only where the row opens something (onboarding rows only connect)
        .modifier(RSourceRowOpenAction(open: open))
    }

    @ViewBuilder private var trailing: some View {
        switch state {
        case .notConnected:
            RPill(title: "connect", symbol: "plus", style: .raised, action: connect)
                .transition(.opacity)
        case .connected:
            RStatusDot(status: .connected).allowsHitTesting(false)
        case .syncing:
            RStatusDot(status: .syncing).allowsHitTesting(false)
        case .needsAttention:
            RStatusDot(status: .problem).allowsHitTesting(false)
        case .unavailable:
            RStatusDot(status: .unavailable).allowsHitTesting(false)
        }
    }
}

/// Pressed: surface.subtle at once, back over 240ms; Reduce Motion: no fade (part 22's row).
/// VoiceOver's double-tap opens the row, and only when there is somewhere to go.
private struct RSourceRowOpenAction: ViewModifier {
    let open: (() -> Void)?

    func body(content: Content) -> some View {
        if let open {
            content.accessibilityAction { open() }
        } else {
            content
        }
    }
}

private struct RSourceRowPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? RColor.surfaceSubtle : .clear)
            .animation(
                configuration.isPressed || reduceMotion ? nil : RMotion.standard(RNumber.motionDurationPressOut),
                value: configuration.isPressed
            )
    }
}

#if DEBUG
struct RSourceRowGallery: View {
    @State private var voiceNotes = RSourceRow.State.notConnected

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space8) {
                RSettingsGroup(inset: .afterIcon) {
                    RSourceRow(title: "calendar", purpose: "so your brief knows your day", symbol: "calendar", state: .connected, open: {})
                    RSourceRow(title: "voice notes", purpose: "in your own words", symbol: "mic", state: voiceNotes, connect: {
                        voiceNotes = .syncing
                        Task {
                            try? await Task.sleep(for: .seconds(RNumber.motionLifeResumeAfter))
                            voiceNotes = .connected
                        }
                    }, open: {})
                    RSourceRow(title: "podcasts", purpose: "what you listen to", symbol: "dot.radiowaves.left.and.right", state: .needsAttention, open: {})
                    RSourceRow(title: "health", purpose: "how you slept, how you moved", symbol: "heart", state: .syncing, open: {})
                    RSourceRow(title: "screen time", purpose: "where your attention went", symbol: "hourglass", state: .unavailable, open: {})
                }
                RSettingsGroup(inset: .afterIcon) {
                    RSourceRow(title: "calendar", purpose: "your days, and who's in them", symbol: "calendar", state: .connected, density: .onboarding)
                    RSourceRow(title: "music", purpose: "what you play, and when", symbol: "music.note", density: .onboarding)
                }
            }
            .padding(.vertical, RDimension.space6)
        }
        .background(RColor.backgroundCanvas)
    }
}

#Preview("source rows") { RSourceRowGallery() }
#endif
