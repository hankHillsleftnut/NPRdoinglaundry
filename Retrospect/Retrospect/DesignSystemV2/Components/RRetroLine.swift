//
//  RRetroLine.swift
//  M14 C30.2: Retro's words in the thread (design-system/components/message.md "theirs";
//  Paper c:message/theirs/rest 1FL9-0, arriving C53-0). No bubble, mark, avatar or name: SF 17,
//  --tracking-card, leading normal, text.primary, straight on the page at the leading margin and
//  the full column wide, wrapping where lines naturally fill (Text's own wrapping; SwiftUI has no
//  line-break strategy to set). In v1 it's one canned
//  acknowledgement, shown only after the entry is sent; it fades in once, over 200ms.
//
import SwiftUI

struct RRetroLine: View {
    /// What Retro says, a line at a time. v1 passes one acknowledgement.
    let lines: [String]
    /// True while Retro is still speaking (v2's streaming): each new line blurs in as it lands.
    /// v1 always passes false.
    var arriving = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space0) {
            // a line's place is its identity: lines are only ever appended, and two lines can
            // say the same words
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .rText(.bodyReading)
                    .foregroundStyle(RColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(RLineArrival(arriving: arriving))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // in only when it's added to the thread (a turn landing), never on scrolling back to it
        .transition(reduceMotion
            ? AnyTransition.opacity.animation(RMotion.standard(RNumber.motionDurationFast))
            : AnyTransition.opacity.animation(RMotion.standard(RNumber.motionDurationBase)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("retrospect: \(lines.joined(separator: " "))")
    }
}

/// v2's streamed lines: each one blurs in as it's added (`rBlurReplace`); v1 lines just sit.
private struct RLineArrival: ViewModifier {
    let arriving: Bool

    func body(content: Content) -> some View {
        if arriving {
            content.rBlurReplace()
        } else {
            content
        }
    }
}

extension View {
    /// Announces Retro's newest line once, when it first appears (a new acknowledgement), never
    /// again on scrolling. Put it on the thread with the latest line.
    func rRetroAnnouncement(latest line: String?) -> some View {
        onChange(of: line) { old, new in
            if let new, new != old {
                AccessibilityNotification.Announcement("retrospect: \(new)").post()
            }
        }
    }
}

#if DEBUG
/// Lab page "retro": Retro's acknowledgement at rest, a long reply that wraps, and an
/// acknowledgement landing after a send. `-DesignLabAutoplay` sends a few times, for recordings.
struct RRetroLineGallery: View {
    @State private var sent = 0
    private let acknowledgements = ["got it.", "saved.", "it's in.", "kept."]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space6) {
                caption("acknowledgement")
                RRetroLine(lines: ["got it."])
                caption("a long line fills the column (v2's replies)")
                RRetroLine(lines: ["third monday like that. what's different about mondays?"])
                caption("landing after a send")
                VStack(alignment: .leading, spacing: RDimension.space2) {
                    if sent > 0 {
                        RRetroLine(lines: [acknowledgements[(sent - 1) % acknowledgements.count]])
                            .id(sent)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: RDimension.sizeTouchTarget, alignment: .topLeading)
                .rRetroAnnouncement(latest: sent > 0 ? acknowledgements[(sent - 1) % acknowledgements.count] : nil)
                RPill(title: "send", style: .raised) { sent += 1 }
            }
            .padding(RDimension.spaceScreenMargin)
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-DesignLabAutoplay") else { return }
            for _ in 0 ..< 3 {
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                sent += 1
            }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text).rText(.label).foregroundStyle(RColor.textLabel)
    }
}

#Preview("retro line") { RRetroLineGallery() }
#endif
