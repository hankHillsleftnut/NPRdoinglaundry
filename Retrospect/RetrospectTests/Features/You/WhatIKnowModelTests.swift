@testable import Retrospect
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct WhatIKnowModelTests {
    @Test("loads the sample: loading, then Paper's three areas in order")
    func loads() async {
        let model = WhatIKnowModel(data: SampleYou())
        #expect(model.state == .loading)
        await model.load()
        guard case let .content(known) = model.state else {
            Issue.record("expected content")
            return
        }
        #expect(known.areas.map(\.title) == ["work", "health", "family"])
        #expect(known.areas[0].answers.map(\.restsOn) == [9, 14])
        #expect(known.areas[2].answers.isEmpty)
        #expect(known.areas[2].quietLine != nil)
    }

    @Test("the moved row's line: plural, singular, hidden at zero or nil", arguments: [
        (Int?.some(2), String?.some("2 answers changed")),
        (1, "1 answer changed"),
        (0, nil),
        (nil, nil),
    ])
    func changedLine(count: Int?, line: String?) {
        #expect(WhatIKnowModel.changedLine(count) == line)
    }

    @Test("how sure is clamped to the four dots a row draws")
    func clamped() {
        #expect(Flows.HowSure(words: "x", level: 9).level == Flows.HowSure.scale)
        #expect(Flows.HowSure(words: "x", level: -1).level == 0)
    }

    @Test("a row reads as one line: question, answer, how sure, out of four, from n things")
    func spoken() {
        let answer = SampleYou.whatIKnow.areas[0].answers[0]
        #expect(AnswerRow.spoken(answer) == "what drives you most? building things people use. fairly sure, 3 of 4, from 9 things")
    }

    @Test("YO-5 is registered in the you group, dark, with its state")
    func registered() {
        #expect(YouScreens.screens.map(\.id) == ["YO-5"])
        #expect(ScreenRegistry.screen("YO-5")?.states == ["rest"])
    }
}
