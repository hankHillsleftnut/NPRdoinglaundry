//
//  RErrorState.swift
//  M14 C39.3: what went wrong and "try again" (design-system/components/loading-and-empty.md,
//  reference §C39; Paper legacy c5 "brief card / couldn't load" 20R-0). The message in Geist 12
//  status.dangerText, then the neutral "try again" pill with the retry glyph. It blurs in, and
//  the error haptic fires once, the first time it appears. The words are never written here:
//  pass the failure's own plain message (contract 00: `error.message` is safe to show as is).
//
import SwiftUI

extension RTextStyle {
    /// The failure line: Geist 12, leading snug, no tracking (Paper 20R-0).
    static let errorLine = RTextStyle(
        family: .label,
        size: RDimension.fontSizeSm,
        weight: .regular,
        tracking: RNumber.fontTrackingNone,
        leading: RTextStyle.label.leading,
        relativeTo: .caption
    )
}

struct RErrorState: View {
    /// The failure's plain message, from `Backend.Failure`; never copy written in a view.
    let message: String
    let retry: () -> Void

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // the pill's 44 hit area adds 6 above its 32 body, so 8 reads as Paper's 14
        VStack(alignment: .leading, spacing: RDimension.space2) {
            Text(message)
                .rText(.errorLine)
                .foregroundStyle(RColor.statusDangerText)
                .fixedSize(horizontal: false, vertical: true)
            RPill(title: "try again", symbol: "arrow.clockwise", action: retry)
                .accessibilityIdentifier("error.tryAgain")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(transition)
        .onAppear { shown = true }
        // once, when it first appears; a retry that fails again keeps this view, so no repeat
        .sensoryFeedback(RHaptic.error, trigger: shown) { _, now in now }
    }

    /// In on curve.standard 280 with a blur; out on curve.exit 200. Reduce Motion: a 140 fade.
    private var transition: AnyTransition {
        if reduceMotion {
            return AnyTransition.opacity.animation(RMotion.standard(RNumber.motionDurationFast))
        }
        return .asymmetric(
            insertion: AnyTransition(.blurReplace).animation(RMotion.standard(RNumber.motionDurationSlow)),
            removal: AnyTransition(.blurReplace).animation(RMotion.exit(RNumber.motionDurationBase))
        )
    }
}

#if DEBUG
/// Lab page "error": the state inside a card, for a network and a server failure, and coming
/// in after a retry. The messages are contract 00's fixtures; "couldn't load today's brief" is
/// Paper's own line on 20R-0.
/// `-DesignLabAutoplay` swaps it in and out, for recordings.
struct RErrorStateGallery: View {
    @State private var failed = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space6) {
                caption("couldn't load · network (upstream_unavailable)")
                RErrorState(message: "retro couldn't be reached. try again.") {}
                    .padding(RDimension.space4)
                    .rRaised()
                caption("couldn't load · server (internal)")
                RErrorState(message: "something went wrong. try again.") {}
                    .padding(RDimension.space4)
                    .rRaised()
                caption("coming in")
                VStack(alignment: .leading) {
                    if failed {
                        RErrorState(message: "couldn't load today's brief") { failed = false }
                    } else {
                        RPill(title: "fail again", style: .raised) { failed = true }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: RDimension.sizeBriefCardMinHeight, alignment: .topLeading)
                .padding(RDimension.space4)
                .rRaised()
            }
            .padding(RDimension.spaceScreenMargin)
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-DesignLabAutoplay") else { return }
            for _ in 0 ..< 4 {
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                failed.toggle()
            }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text).rText(.label).foregroundStyle(RColor.textLabel)
    }
}

#Preview("error state") { RErrorStateGallery() }
#endif
