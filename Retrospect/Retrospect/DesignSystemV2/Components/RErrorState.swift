//
//  RErrorState.swift
//  M14 C39.3: what went wrong and "try again" (design-system/components/loading-and-empty.md,
//  reference §C39; Paper legacy c5 "brief card / couldn't load" 20R-0). The message in Geist 12
//  status.dangerText, then the neutral "try again" pill with the retry glyph. It blurs in
//  (`rBlurReplace`) and VoiceOver announces the message. The host fires the error haptic once
//  per error with `.rErrorHaptic(isFailing:)`. The words are never written here: pass the
//  failure's own plain message (contract 00: `error.message` is safe to show as is).
//
import SwiftUI

struct RErrorState: View {
    /// The failure's plain message, from `Backend.Failure`; never copy written in a view.
    let message: String
    let retry: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Paper's 14 between the words and the pill: 8 plus the 6 the pill's 44 hit area adds
        // above its 32 body; at accessibility sizes the pill outgrows 44, so the gap is 16
        VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? RDimension.space4 : RDimension.space2) {
            Text(message)
                .rText(.metaLine)
                .foregroundStyle(RColor.statusDangerText)
                .fixedSize(horizontal: false, vertical: true)
            RPill(title: "try again", symbol: "arrow.clockwise", action: retry)
                .accessibilityIdentifier("error.tryAgain")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rBlurReplace()
        // each time it appears (a retry that fails again included), VoiceOver hears why
        .onAppear { AccessibilityNotification.Announcement(message).post() }
    }
}

extension View {
    /// The error haptic, once per error: it fires when `isFailing` turns true. The host keeps
    /// `isFailing` true through retries that fail again and sets it false only on success, so a
    /// person retrying a broken page doesn't get buzzed every time.
    func rErrorHaptic(isFailing: Bool) -> some View {
        sensoryFeedback(RHaptic.error, trigger: isFailing) { old, new in !old && new }
    }
}

#if DEBUG
/// Lab page "error": the state inside a card, for a network and a server failure, and coming
/// in after a retry. The messages are contract 00's fixtures; "couldn't load today's brief" is
/// Paper's own line on 20R-0.
/// `-DesignLabAutoplay` retries twice (both fail again), for recordings.
struct RErrorStateGallery: View {
    /// The error episode: true from the first failure until a retry works.
    @State private var failing = true
    /// A retry in flight; in the lab every retry fails again.
    @State private var retrying = false

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
                caption("coming in · retries fail again, one buzz")
                VStack(alignment: .leading) {
                    if failing, !retrying {
                        RErrorState(message: "couldn't load today's brief") { retry() }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: RDimension.sizeBriefCardMinHeight, alignment: .topLeading)
                .padding(RDimension.space4)
                .rRaised()
                .rErrorHaptic(isFailing: failing)
                RPill(title: failing ? "it works now" : "break it", style: .raised) { failing.toggle() }
            }
            .padding(RDimension.spaceScreenMargin)
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-DesignLabAutoplay") else { return }
            for _ in 0 ..< 2 {
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                retry()
            }
        }
    }

    private func retry() {
        retrying = true
        Task {
            try? await Task.sleep(for: .seconds(RNumber.motionDurationSlow * 2))
            retrying = false
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text).rText(.label).foregroundStyle(RColor.textLabel)
    }
}

#Preview("error state") { RErrorStateGallery() }
#endif
