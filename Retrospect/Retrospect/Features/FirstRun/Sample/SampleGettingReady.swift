//
//  SampleGettingReady.swift
//  GR.ready: ON-10 on sample data. A silent stand-in for the recogniser: after a breath it "hears"
//  an invented answer one word at a time (each word pending until the next arrives), then the
//  utterance ends and goes in. Nothing is recorded, nothing leaves the phone, nothing is logged.
//
import Foundation

/// The launcher's ON-10 states (`-Screen first-run -State getting-ready|getting-ready-still`).
enum GettingReadyScenario: String, CaseIterable {
    /// Live: words arrive, the answer goes in, the episode is made about 30 s later.
    case gettingReady = "getting-ready"
    /// Paper's frame (26LG-0), held: "thursday" still being heard, the line at 55%, never made.
    case gettingReadyStill = "getting-ready-still"

    /// The episode's sample for this state.
    var episode: Flows.FirstEpisodeScenario {
        switch self {
        case .gettingReady: .makingThenReady
        case .gettingReadyStill: .making
        }
    }

    /// Whether the utterance ends (and goes in) or stays on its last word.
    var utteranceEnds: Bool {
        self == .gettingReady
    }
}

/// Plays one invented utterance per page, word by word, on the injected clock. A second `listen()`
/// (back to talking after typing) hears nothing more: the sample has said its piece.
@MainActor
final class SampleListening: Flows.Listening {
    /// Paper's answer (26MX-0).
    static let utterance = ["the", "investor", "call", "on", "thursday"]
    /// A breath before the first word, then a word about every 380 ms (a calm talker).
    static let firstWordAfter: Duration = .milliseconds(1200)
    static let wordGap: Duration = .milliseconds(380)
    /// The pause that ends an utterance.
    static let endAfter: Duration = .milliseconds(900)

    private let clock: any Clock<Duration>
    /// The words this listen hears (ON-10: Paper's; the questions: the sample person's answer).
    private let words: [String]
    private let ends: Bool
    private let waits: Bool
    private var hasSpoken = false
    private var continuation: AsyncStream<Flows.Heard>.Continuation?

    /// `ends`: the utterance ends and goes in (live); false holds it on the last, pending word.
    /// `waits`: false hands the whole utterance over at once (Paper's still, and tests).
    /// `utterance`: what is heard (QU.followups.a gives each question its own); empty hears nothing
    /// and leaves the ear open until it is stopped.
    init(
        clock: any Clock<Duration> = ContinuousClock(),
        ends: Bool = true,
        waits: Bool = true,
        utterance: [String] = SampleListening.utterance
    ) {
        self.clock = clock
        words = utterance
        self.ends = ends
        self.waits = waits
    }

    func listen() -> AsyncStream<Flows.Heard> {
        stop()
        let (stream, continuation) = AsyncStream<Flows.Heard>.makeStream()
        self.continuation = continuation
        guard !hasSpoken, !words.isEmpty else { return stream }
        hasSpoken = true
        let task = Task { [clock, ends, waits, words] in
            if waits {
                try? await clock.sleep(for: Self.firstWordAfter)
            }
            for count in 1 ... words.count {
                guard !Task.isCancelled else { return }
                if waits || count == words.count {
                    continuation.yield(.partial(Array(words.prefix(count))))
                }
                if waits, count < words.count {
                    try? await clock.sleep(for: Self.wordGap)
                }
            }
            guard ends else { return }
            if waits {
                try? await clock.sleep(for: Self.endAfter)
            }
            guard !Task.isCancelled else { return }
            continuation.yield(.ended)
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    func stop() {
        continuation?.finish()
        continuation = nil
    }
}
