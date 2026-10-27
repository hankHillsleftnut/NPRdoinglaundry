import Foundation
@testable import Retrospect
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct YouModelTests {
    private func asked(_ question: String) async -> YouModel {
        let model = YouModel(data: SampleYou())
        model.query = question
        await model.ask()
        return model
    }

    @Test("at rest: the question waiting is about sam")
    func atRest() async {
        let model = YouModel(data: SampleYou())
        #expect(model.phase == .rest)
        await model.load()
        #expect(model.atRest.questionAbout == "sam")
    }

    @Test("asking Paper's question finds Paper's answer, in place", arguments: [
        "when do i sleep best?", "When do I sleep best", "  when do i sleep best?? ",
    ])
    func found(question: String) async {
        let model = await asked(question)
        #expect(model.answer == SampleYou.sleepAnswer)
        #expect(model.sources.map(\.id) == [1, 2, 3])
        #expect(model.secondLine != nil)
        #expect(model.offersOnlyCertain)
    }

    @Test("anything else finds nothing: no guess, no sources, no switch")
    func nothing() async {
        let model = await asked(SampleYou.unansweredQuestion)
        #expect(model.answer?.kind == .abstained)
        #expect(model.sources.isEmpty)
        #expect(model.secondLine != nil)
        #expect(!model.offersOnlyCertain)
    }

    @Test("asking again from an answer replaces it with the new one (never back to the map)")
    func reask() async {
        let model = await asked(SampleYou.sleepQuestion)
        model.query = SampleYou.unansweredQuestion
        await model.ask()
        #expect(model.answer == SampleYou.nothingFound)
    }

    @Test("an empty field asks nothing")
    func empty() async {
        let model = await asked("   ")
        #expect(model.phase == .rest)
    }

    @Test("only what's certain hides the guess and the source that only backs it")
    func onlyCertain() async {
        let model = await asked(SampleYou.sleepQuestion)
        model.onlyCertain = true
        #expect(model.secondLine == nil)
        #expect(model.sources.map(\.id) == [1, 2])
    }

    @Test("clearing goes back to the map and resets the switch")
    func clear() async {
        let model = await asked(SampleYou.sleepQuestion)
        model.onlyCertain = true
        model.clear()
        #expect(model.phase == .rest)
        #expect(model.query.isEmpty)
        #expect(!model.onlyCertain)
    }

    @Test("only the journal source opens a page (YO-3); the others open nothing yet")
    func sourcePages() {
        #expect(SampleYou.sleepAnswer.sources.map(\.sourceID) == [nil, SampleYou.sleepEntry.id, nil])
    }

    @Test("citations: unicode superscripts as Paper writes them, words not links (the source rows are the way in)")
    func citations() {
        #expect(AnswerCard.superscript(1) == "¹")
        #expect(AnswerCard.superscript(12) == "¹²")
        #expect(AnswerCard.written(SampleYou.sleepAnswer.headline) == "after days you run¹, and when work stops before 9².")
    }

    @Test("YO-1 and YO-2 are registered with their states")
    func registered() {
        #expect(ScreenRegistry.screen("YO-1")?.states == ["rest"])
        #expect(ScreenRegistry.screen("YO-2")?.states == ["found", "nothing"])
    }

    @Test("VoiceOver reads each citation as 'source n', never a bare superscript")
    func spokenCitations() {
        let answer = SampleYou.sleepAnswer
        #expect(AnswerCard.spoken(answer.headline, answer.secondLine) ==
            "what i found. after days you run, source 1, and when work stops before 9, source 2. a guess: weekends help less than you think, source 3.")
        #expect(AnswerCard.spoken(answer.headline, nil) == "what i found. after days you run, source 1, and when work stops before 9, source 2.")
    }

    @Test("the title bar carries Paper's 'list' pill, then your picture (1G7Y-0)")
    func trailing() {
        #expect(YouPage.trailing == [.list, .picture])
    }
}
