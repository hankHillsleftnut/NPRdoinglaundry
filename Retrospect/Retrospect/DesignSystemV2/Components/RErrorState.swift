//
//  RErrorState.swift
//  M14 C39.3: what went wrong and "try again" (design-system/components/loading-and-empty.md,
//  reference §C39; Paper legacy c5 "brief card / couldn't load" 20R-0). The message in Geist 12
//  status.dangerText, then the neutral "try again" pill with the retry glyph. It blurs in
//  (`rBlurReplace`). The host owns the feedback: `.rErrorHaptic(isFailing:)` buzzes once per
//  error and `.rErrorAnnouncement(_:attempt:)` tells VoiceOver each time an attempt fails. The
//  failure's words are never written here: pass its own plain message (contract 00:
//  `error.message` is safe to show as is). Only the pill's "try again" is this view's.
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
    }
}

extension View {
    /// The error haptic, once per error: it fires when `isFailing` turns true. The host keeps
    /// `isFailing` true through retries that fail again and sets it false only on success, so a
    /// person retrying a broken page doesn't get buzzed every time.
    func rErrorHaptic(isFailing: Bool) -> some View {
        sensoryFeedback(RHaptic.error, trigger: isFailing) { old, new in !old && new }
    }

    /// Announces the failure's message to VoiceOver once per failed attempt: the host counts its
    /// attempts and passes the message while it's failing (nil once it works).
    func rErrorAnnouncement(_ message: String?, attempt: Int) -> some View {
        onChange(of: attempt) {
            if let message {
                AccessibilityNotification.Announcement(message).post()
            }
        }
    }
}

#if DEBUG
/// Lab page "error": the state inside a card, for a network and a server failure, and coming
/// in after a retry. The messages are contract 00's fixtures; "couldn't load today's brief" is
/// Paper's own line on 20R-0.
/// `-DesignLabAutoplay` retries twice (both fail again), for recordings.
struct RErrorStateGallery: View {
    /// The error episode: true from the first failure until a retry works. It starts false and
    /// the first load fails in `.task`, so the first failure buzzes as on a real page.
    @State private var failing = false
    /// A retry in flight; in the lab every retry fails again.
    @State private var retrying = false
    /// Failed attempts so far (the first load counts), for the announcement.
    @State private var attempts = 0

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
                .rErrorAnnouncement(failing ? "couldn't load today's brief" : nil, attempt: attempts)
                RPill(title: failing ? "it works now" : "break it", style: .raised) {
                    failing.toggle()
                    if failing {
                        attempts += 1
                    }
                }
            }
            .padding(RDimension.spaceScreenMargin)
        }
        .task {
            // the first load fails
            failing = true
            attempts += 1
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
            attempts += 1
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text).rText(.label).foregroundStyle(RColor.textLabel)
    }
}

#Preview("error state") { RErrorStateGallery() }
#endif
