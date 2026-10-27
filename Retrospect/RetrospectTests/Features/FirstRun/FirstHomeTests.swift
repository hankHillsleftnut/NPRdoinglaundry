import Foundation
@testable import Retrospect
import Testing

@MainActor
struct FirstHomeTests {
    private let answers: [Flows.QuestionKey: String] = [
        .namePlace: "sam, in london. moved here last year",
        .yearFromNow: "raise the seed, sleep before midnight",
        .careMost: "my sister",
        .onYourMind: "the round",
        .workingOn: "the app",
        .keepMeaning: "running",
        .highLow: "launch; the flu",
        .people: "priya",
        .thisWeek: "the investor call on thursday!",
    ]

    @Test("the recap is the person's own first sentences, with Paper's prefixes, in Paper's order")
    func recapFromAnswers() {
        let recap = SetupRecap.make(answers: answers)
        #expect(recap.name == "sam")
        #expect(recap.lines == [
            "sam, in london.",
            "wants: raise the seed, sleep before midnight.",
            "this week: the investor call on thursday!",
        ])
        #expect(recap.count == 9)
        #expect(recap.countLine == "9 answers")
    }

    @Test("an unanswered line is left out, never 'wants: .'; blank answers don't count")
    func missingAnswers() {
        let recap = SetupRecap.make(answers: [.namePlace: "Sam.", .yearFromNow: "   ", .people: "priya"])
        #expect(recap.name == "Sam")
        #expect(recap.lines == ["Sam."])
        #expect(recap.count == 2)
        let none = SetupRecap.make(answers: [:])
        #expect(none.name == nil)
        #expect(none.lines.isEmpty)
        #expect(none.countLine == "0 answers")
        #expect(SetupRecap(name: nil, lines: [], count: 1).countLine == "1 answer")
    }

    @Test("the count grows with the questions (a tenth answer counts)")
    func countIsComputed() {
        var more = answers
        more[.howStraight] = "straight"
        #expect(SetupRecap.make(answers: more).count == 10)
    }

    @Test("first sentence and first word")
    func words() {
        #expect(SetupRecap.sentence("one. two.") == "one.")
        #expect(SetupRecap.sentence("  no stop  ") == "no stop.")
        #expect(SetupRecap.sentence("line one\nline two") == "line one.")
        #expect(SetupRecap.sentence("why?") == "why?")
        #expect(SetupRecap.firstWord("sam, in london") == "sam")
        #expect(SetupRecap.firstWord("...") == nil)
    }

    @Test("Paper's still words are verbatim (1FJJ-0, 1FJ6-0, 1FJO-0, 1FJN-0, 1FJI-0)")
    func paperCopy() {
        #expect(FirstDay.welcome(name: SetupRecap.paper.name) == "welcome, sam.")
        #expect(FirstDay.welcome(name: nil) == "welcome.")
        #expect(FirstDay.welcomeLine == "this is your journal. say anything, any time; i'll keep it and find the threads.")
        #expect(FirstDay.recapTitle == "what you told retro while setting up")
        #expect(SetupRecap.paper.countLine == "9 answers")
        #expect(SetupRecap.paper.lines == [
            "sam, in london.", "wants: raise the seed, sleep before midnight.", "this week: the investor call on thursday.",
        ])
        #expect(FirstDay.cardTitle == "your first episode is ready")
        #expect(FirstDay.paperCardLine == "the week you started · 2 min")
    }

    @Test("a short screen shows two recap lines (handoff: SE)")
    func compactLines() {
        let lines = SetupRecap.paper.lines
        #expect(SetupRecapCard.shown(lines, compact: true) == Array(lines.prefix(2)))
        #expect(SetupRecapCard.shown(lines, compact: false) == lines)
    }

    @Test("the ready card plays and says so; it has no date")
    func readyCard() {
        let state = RBriefCard.State.firstEpisodeReady(line: FirstDay.paperCardLine)
        #expect(RBriefCard.hasPlay(state))
        #expect(RBriefCard.label(date: "tue 21 oct", length: "2 min", state: state) == "tue 21 oct")
        #expect(RFirstEpisodeReadyCard.spoken(title: FirstDay.cardTitle, line: FirstDay.paperCardLine)
            == "your first episode is ready, the week you started, 2 minutes")
    }

    @Test("the launcher's first-home states exist")
    func launcherStates() {
        #expect(FirstHomeScenario.allCases.map(\.rawValue) == ["first-home", "first-home-still"])
    }
}
