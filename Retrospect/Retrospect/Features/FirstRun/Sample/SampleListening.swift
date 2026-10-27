//
//  SampleListening.swift
//  QU.followups.a: the simulated ear for the questions page on sample data (founder decision 4). A
//  scripted person, "sam", answers each question out loud: after a beat the words arrive one by one
//  with the voice level moving, then a quiet ends the answer. Q1 says Paper's own words (1F6C-0:
//  "sam." · "i'm in" · "london"); the rest are sample-only lines for the demo (question card QC-4),
//  never product copy. Deterministic: waits go through the injected clock, levels are a fixed
//  pattern, nothing is random and nothing is logged. A word handed over is never heard twice: after
//  mic off the next listen to that question goes on from the next word.
//
import Foundation

@MainActor
final class SampleListening: Flows.Listening {
    typealias Key = Flows.QuestionKey

    /// What sam says to each question, in speaking order (one entry = one word landing).
    static let words: [Key: [String]] = [
        .namePlace: ["sam.", "i'm in", "london"],
        .yearFromNow: ["the", "seed", "is", "raised,", "and", "i", "sleep", "before", "midnight."],
        .careMost: ["my", "sister,", "my", "health,", "and", "the", "team."],
        .onYourMind: ["the", "raise.", "the", "investor", "call", "on", "thursday."],
        .struggle: ["sleep.", "i", "keep", "pushing", "bedtime", "past", "one."],
        .workingOn: ["retrospect.", "it's", "going,", "slower", "than", "i'd", "like."],
        .keepMeaning: ["running", "in", "the", "mornings.", "work", "keeps", "winning."],
        .highLow: ["high:", "the", "first", "demo.", "low:", "losing", "a", "client."],
        .people: ["maya.", "and", "my", "brother;", "i", "should", "call", "him", "more."],
    ]

    /// A beat before the first word: the question has landed and the bars wake.
    static let firstWordAfter: Duration = .milliseconds(700)
    /// One word about every 380 ms (an easy speaking pace), a level tick halfway between.
    static let wordEvery: Duration = .milliseconds(380)
    /// The quiet that ends an answer.
    static let quiet: Duration = .milliseconds(1200)
    /// The bars' pattern while sam talks (0…1), one value per tick.
    static let levels: [Double] = [0.55, 0.8, 0.35, 0.7, 0.5, 0.9, 0.4, 0.65]

    private let clock: any Clock<Duration>
    /// How many of each question's words have been handed over.
    private var spoken: [Key: Int] = [:]

    init(clock: any Clock<Duration> = ContinuousClock()) {
        self.clock = clock
    }

    func hear(_ key: Key) -> AsyncStream<Flows.Heard> {
        let (stream, continuation) = AsyncStream.makeStream(of: Flows.Heard.self)
        let task = Task { [weak self] in
            await self?.speak(key, into: continuation)
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    private func speak(_ key: Key, into continuation: AsyncStream<Flows.Heard>.Continuation) async {
        guard let words = Self.words[key] else {
            // nothing scripted (Paper's quick-answers question): the ear stays open, the bars rest,
            // until the person taps a chip, turns the mic off or leaves
            await waitUntilCancelled()
            return
        }
        var tick = 0
        guard await wait(Self.firstWordAfter) else { return }
        while let next = nextWord(key, of: words) {
            continuation.yield(.level(Self.levels[tick % Self.levels.count]))
            continuation.yield(.word(next))
            tick += 1
            guard await wait(Self.wordEvery / 2) else { return }
            continuation.yield(.level(Self.levels[tick % Self.levels.count]))
            tick += 1
            guard await wait(Self.wordEvery / 2) else { return }
        }
        continuation.yield(.level(nil))
        guard await wait(Self.quiet) else { return }
        continuation.yield(.ended)
    }

    /// The next word not yet handed over for `key`, counted as handed over.
    private func nextWord(_ key: Key, of words: [String]) -> String? {
        let index = spoken[key] ?? 0
        guard words.indices.contains(index) else { return nil }
        spoken[key] = index + 1
        return words[index]
    }

    /// Suspends until the listen is cancelled (an open stream nobody writes to; no clock, no spin).
    private func waitUntilCancelled() async {
        let (open, keep) = AsyncStream.makeStream(of: Void.self)
        for await _ in open {}
        keep.finish()
    }

    /// Waits on the clock; false once the listen was cancelled.
    private func wait(_ duration: Duration) async -> Bool {
        try? await clock.sleep(for: duration)
        return !Task.isCancelled
    }
}
