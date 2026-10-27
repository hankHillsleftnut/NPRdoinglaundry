@testable import Retrospect
import Testing

/// V2.goals · GL-2 on the sample: Paper's words, the pattern guess answered in place, and "turn off".
@MainActor
struct GoalModelTests {
    @Test("rest: Paper's title, said line, did heading, three evidence rows and the pattern guess")
    func loadsPaper() async throws {
        let model = GoalModel(goalID: "goal.ship", data: SampleGoals())
        #expect(model.state == .idle)
        await model.load()
        let detail = try #require(model.detail)
        #expect(detail.title == "ship the first version")
        #expect(detail.saidLine == "said 6 times · first on 6 oct · last on monday")
        #expect(detail.didHeading == "did this week · 4 hours")
        #expect(detail.evidence.map(\.meta) == ["tue 14 oct · calendar", "thu 16 oct · calendar", "fri 17 oct · your words"])
        #expect(detail.evidence.map(\.words) == ["2 hours of deep work", "demo with priya", "\"finally fixed the sync bug\""])
        #expect(detail.pattern?.label == "a guess · a pattern")
        #expect(detail.pattern?.question == "you get most done after a late night, then sleep badly the next day.")
    }

    @Test("only your own words can open something (an entry); calendar rows open nothing")
    func evidenceDestinations() async throws {
        let model = GoalModel(goalID: "goal.ship", data: SampleGoals())
        await model.load()
        let detail = try #require(model.detail)
        #expect(detail.evidence.map { $0.entryID != nil } == [false, false, true])
    }

    @Test("answering the pattern guess takes it away, either answer", arguments: [true, false])
    func answerPattern(accepted: Bool) async throws {
        let model = GoalModel(goalID: "goal.ship", data: SampleGoals())
        await model.load()
        let pattern = try #require(model.detail?.pattern)
        await model.answer(pattern, accepted: accepted)
        #expect(model.detail?.pattern == nil)
        #expect(model.detail?.evidence.count == 3)
    }

    @Test("turn off: the page is gone and GL-1 reads the goal off its list")
    func turnOff() async throws {
        let data = SampleGoals()
        let list = GoalsModel(data: data)
        await list.load()
        let model = GoalModel(goalID: "goal.ship", data: data)
        await model.load()
        await model.turnOff()
        #expect(model.state == .gone)
        await list.refresh()
        let overview = try #require(list.overview)
        #expect(!overview.goals.contains { $0.id == "goal.ship" })
        #expect(overview.endedLine == "turned off 3 · merged 1")
    }

    @Test("only the goal Paper draws a GL-2 for opens one")
    func onlyDrawnOpens() async {
        #expect(SampleGoals.drawnDetails == ["goal.ship"])
        let data = SampleGoals()
        for goal in SampleGoals.paper.goals {
            let model = GoalModel(goalID: goal.id, data: data)
            await model.load()
            if SampleGoals.drawnDetails.contains(goal.id) {
                #expect(model.detail?.title == goal.title)
            } else {
                #expect(model.state == .gone)
            }
        }
    }

    @Test("an unknown goal is gone, never a blank page")
    func unknownGoal() async {
        let model = GoalModel(goalID: "goal.nope", data: SampleGoals())
        await model.load()
        #expect(model.state == .gone)
    }

    @Test("GL-2 is registered in the goals group with its one drawn state")
    func registered() {
        let screen = GoalsScreens.screens.first { $0.id == "GL-2" }
        #expect(screen?.states == ["rest"])
    }
}

/// Review on #219: a second turn-off does nothing.
@MainActor
struct GoalPageGuardTests {
    @Test("a second turn off while the first is on its way does nothing: sent once")
    func doubleTurnOff() async {
        let data = SlowGoals()
        let model = GoalModel(goalID: "goal.ship", data: data)
        await model.load()
        let first = Task { await model.turnOff() }
        while data.release == nil {
            await Task.yield()
        }
        await model.turnOff()
        data.release?.resume()
        await first.value
        #expect(data.turnOffs == 1)
        #expect(model.state == .gone)
    }
}
