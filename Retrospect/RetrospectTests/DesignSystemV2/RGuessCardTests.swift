@testable import Retrospect
import Testing

/// C28: the guess card sends one verdict at a time and reads cleanly to VoiceOver.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct RGuessCardTests {
    private func card(_ phase: RGuessCard.Phase) -> RGuessCard {
        RGuessCard(
            question: "mondays are harder because of the standup.",
            from: "from your last 3 mondays · calendar",
            sureness: "fairly sure",
            phase: phase,
            answer: { _ in },
            openWhy: {}
        )
    }

    @Test("answering twice while the first answer is on its way sends one verdict")
    func answeringTwiceSendsOnce() async {
        let once = RAnswerOnce()
        var calls = 0
        var release: CheckedContinuation<Void, Never>?
        let first = Task {
            await once.send {
                calls += 1
                await withCheckedContinuation { release = $0 }
            }
        }
        while release == nil {
            await Task.yield()
        }
        await once.send { calls += 1 }
        #expect(calls == 1)
        release?.resume()
        await first.value
        #expect(once.isSending == false)
        await once.send { calls += 1 }
        #expect(calls == 2)
    }

    @Test("VoiceOver says from once, with commas, offered and kept")
    func voiceOverSaysFromOnce() {
        #expect(card(.offered).accessibilityText
            == "a guess: mondays are harder because of the standup. fairly sure. from your last 3 mondays, calendar.")
        #expect(card(.confirmed).accessibilityText
            == "kept: mondays are harder because of the standup. from your last 3 mondays, calendar.")
    }

    @Test("kept, couldn't save and saved on the phone are announced; the rest are not")
    func announcements() {
        #expect(RGuessCard.announcement(for: .confirmed) == "kept")
        #expect(RGuessCard.announcement(for: .failed) == "couldn't save that, try again")
        #expect(RGuessCard.announcement(for: .savedOnPhone(.yes)) == "saved on this phone")
        #expect(RGuessCard.announcement(for: .offered) == nil)
        #expect(RGuessCard.announcement(for: .pending(.yes)) == nil)
        #expect(RGuessCard.announcement(for: .declined) == nil)
    }
}
