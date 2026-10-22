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
    /// One thing Retro says, with an identity that stays put while lines are added (v1: the
    /// entry's client id; v2: the streamed line's id).
    struct Line: Identifiable, Hashable {
        let id: String
        let text: String
    }

    /// What Retro says, a line at a time. v1 passes one acknowledgement.
    let lines: [Line]
    /// True while Retro is still speaking (v2's streaming): each new line blurs in as it lands.
    /// v1 always passes false.
    var arriving = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space0) {
            ForEach(lines) { line in
                Text(line.text)
                    .rText(.bodyReading)
                    .foregroundStyle(RColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // one path: only the transition depends on `arriving`, so a line never
                    // changes identity when streaming ends
                    .transition(arriving ? .rBlurReplace(reduceMotion: reduceMotion) : .identity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // in only when it's added to the thread (a turn landing), never on scrolling back to it
        .transition(reduceMotion
            ? AnyTransition.opacity.animation(RMotion.standard(RNumber.motionDurationFast))
            : AnyTransition.opacity.animation(RMotion.standard(RNumber.motionDurationBase)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("retrospect: \(lines.map(\.text).joined(separator: " "))")
    }
}

extension View {
    /// Announces Retro's acknowledgement once, for the entry this session watched go from sending
    /// to sent. The host passes that entry's id (nil until one lands here) and its line. A thread
    /// loaded already sent, or scrolled back to, never announces: only a change of id does.
    func rRetroAnnouncement(landed clientEntryId: String?, line: String?) -> some View {
        onChange(of: clientEntryId) { _, landed in
            guard landed != nil, let line else { return }
            AccessibilityNotification.Announcement("retrospect: \(line)").post()
        }
    }
}

#if DEBUG
/// Lab page "retro": Retro's acknowledgement at rest, a long reply that wraps, and an
/// acknowledgement landing after a send (sending, then sent a second later).
/// `-DesignLabAutoplay` sends a few times, for recordings.
struct RRetroLineGallery: View {
    @State private var sent = 0
    @State private var sending = false
    /// The entry this session watched go from sending to sent.
    @State private var landed: String?
    private let acknowledgements = Flows.Journal.Acknowledgements.lines

    private var latest: RRetroLine.Line? {
        landed.map { RRetroLine.Line(id: $0, text: acknowledgements[(sent - 1) % acknowledgements.count]) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space6) {
                caption("acknowledgement")
                RRetroLine(lines: [.init(id: "rest", text: acknowledgements[0])])
                caption("a long line fills the column (v2's replies)")
                RRetroLine(lines: [.init(id: "long", text: "third monday like that. what's different about mondays?")])
                caption("landing after a send")
                VStack(alignment: .leading, spacing: RDimension.space2) {
                    if let latest {
                        RRetroLine(lines: [latest])
                            .id(latest.id)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: RDimension.sizeTouchTarget, alignment: .topLeading)
                .rRetroAnnouncement(landed: landed, line: latest?.text)
                RPill(title: "send", style: .raised) { Task { await send() } }
                    .disabled(sending)
            }
            .padding(RDimension.spaceScreenMargin)
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-DesignLabAutoplay") else { return }
            for _ in 0 ..< 3 {
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                await send()
            }
        }
    }

    /// Sending, then sent a second later: only then does the line land.
    private func send() async {
        sending = true
        defer { sending = false }
        do { try await Task.sleep(for: .seconds(1)) } catch { return }
        sent += 1
        landed = "entry-\(sent)"
    }

    private func caption(_ text: String) -> some View {
        Text(text).rText(.label).foregroundStyle(RColor.textLabel)
    }
}

#Preview("retro line") { RRetroLineGallery() }
#endif
