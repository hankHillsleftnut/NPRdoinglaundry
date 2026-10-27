@testable import Retrospect

/// A You seam whose answers the test hands back one at a time, in any order (stale-answer races).
@MainActor
final class SteppedYou: YouData {
    private var pending: [CheckedContinuation<Flows.Answer, Never>?] = []

    func ask(_: String) async -> Flows.Answer {
        await withCheckedContinuation { pending.append($0) }
    }

    /// Yields until `count` questions are waiting.
    func waitForPending(_ count: Int) async {
        while pending.count < count {
            await Task.yield()
        }
    }

    /// Answers the question asked at `index` (0 = the first asked).
    func reply(at index: Int, _ answer: Flows.Answer) {
        pending[index]?.resume(returning: answer)
        pending[index] = nil
    }

    func atRest() async -> Flows.YouAtRest {
        Flows.YouAtRest(questionAbout: nil)
    }

    func whatIKnow() async -> Flows.WhatIKnow {
        Flows.WhatIKnow(changedThisWeek: nil, areas: [])
    }

    func source(id _: String) async -> Flows.SourceEntry? {
        nil
    }
}
