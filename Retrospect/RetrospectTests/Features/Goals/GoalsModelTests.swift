@testable import Retrospect
import Testing

/// V2.goals · GL-1 on the sample: Paper's words, and every edge the page has (SCREEN-MAP rows 92-95b).
@MainActor
struct GoalsModelTests {
    @Test("idle until read, then rest with Paper's guess, three goals and the ended row")
    func loadsPaper() async throws {
        let model = GoalsModel(data: SampleGoals())
        #expect(model.state == .idle)
        await model.load()
        let overview = try #require(model.overview)
        #expect(overview.guess?.label == "a guess · a goal?")
        #expect(overview.guess?.question == "you keep saying you want to see your family more. is that a goal?")
        #expect(overview.goals.map(\.title) == ["ship the first version", "sleep before midnight", "run twice a week"])
        #expect(overview.goals.map(\.said.label) == ["6 times", "3 times", "2 times"])
        #expect(overview.goals.map { $0.did?.label } == ["4 hours", "1 night", nil])
        #expect(overview.goals.map(\.line) == [
            "you work on it most on tuesdays.",
            "late nights cluster before demos.",
            "9 days in. i'll know more next week.",
        ])
        #expect(overview.endedLine == "turned off 2 · merged 1")
    }

    @Test("Paper's bar widths: 80/60, 45/15, 30 and too early")
    func barWidths() {
        let goals = SampleGoals.paper.goals
        #expect(goals.map(\.said.fraction) == [0.8, 0.45, 0.3])
        #expect(goals.map { $0.did?.fraction } == [0.6, 0.15, nil])
    }

    @Test("yes: the guess leaves and a too-early goal joins the list")
    func yes() async throws {
        let model = GoalsModel(data: SampleGoals())
        await model.load()
        let guess = try #require(model.overview?.guess)
        await model.answer(guess, accepted: true)
        let overview = try #require(model.overview)
        #expect(overview.guess == nil)
        #expect(overview.goals.last?.title == "see your family more")
        #expect(overview.goals.last?.did == nil)
        #expect(overview.goals.last?.line == "just started. i'll know more in two weeks.")
        #expect(overview.goals.count == 4)
    }

    @Test("a second yes while the first is on its way does nothing: the answer is sent once")
    func doubleYes() async throws {
        let data = SlowGoals()
        let model = GoalsModel(data: data)
        await model.load()
        let guess = try #require(model.overview?.guess)
        let first = Task { await model.answer(guess, accepted: true) }
        while data.release == nil {
            await Task.yield()
        }
        await model.answer(guess, accepted: true)
        data.release?.resume()
        await first.value
        #expect(data.answers == 1)
    }

    @Test("not quite: the guess leaves, the goals stay as they were")
    func notQuite() async throws {
        let model = GoalsModel(data: SampleGoals())
        await model.load()
        let guess = try #require(model.overview?.guess)
        await model.answer(guess, accepted: false)
        let overview = try #require(model.overview)
        #expect(overview.guess == nil)
        #expect(overview.goals == SampleGoals.paper.goals)
    }

    @Test("turn off: the goal leaves and the ended row counts it")
    func turnOff() async throws {
        let data = SampleGoals()
        let model = GoalsModel(data: data)
        await model.load()
        _ = await data.turnOff("goal.sleep")
        await model.refresh()
        let overview = try #require(model.overview)
        #expect(!overview.goals.contains { $0.id == "goal.sleep" })
        #expect(overview.endedLine == "turned off 3 · merged 1")
    }

    @Test("nothing ended: no ended row")
    func noEndedRow() {
        let overview = GoalsOverview(guess: nil, goals: [], turnedOff: 0, merged: 0)
        #expect(overview.endedLine == nil)
    }

    @Test("a bar's share is kept inside the track")
    func clamp() {
        #expect(GoalBar.clamped(-0.2) == 0)
        #expect(GoalBar.clamped(0.6) == 0.6)
        #expect(GoalBar.clamped(1.4) == 1)
    }

    @Test("the said/did slots are Paper's 28 and 64, the track 4")
    func slots() {
        #expect(RDimension.sizeGoalLabel == 28)
        #expect(RDimension.sizeGoalCount == 64)
        #expect(RDimension.sizeGoalTrack == 4)
    }

    @Test("GL-1 is registered in the goals group with its one drawn state")
    func registered() {
        let screen = GoalsScreens.screens.first { $0.id == "GL-1" }
        #expect(screen?.states == ["rest"])
    }
}

/// A GoalsData whose answer waits until the test lets it go, and counts how often it was asked.
@MainActor
final class SlowGoals: GoalsData {
    private let sample = SampleGoals()
    var release: CheckedContinuation<Void, Never>?
    private(set) var answers = 0
    private(set) var turnOffs = 0

    func overview() async -> GoalsOverview {
        await sample.overview()
    }

    func detail(_ goalID: String) async -> GoalDetail? {
        await sample.detail(goalID)
    }

    func answer(guess guessID: String, accepted: Bool) async -> GoalsOverview {
        answers += 1
        await withCheckedContinuation { release = $0 }
        return await sample.answer(guess: guessID, accepted: accepted)
    }

    func turnOff(_ goalID: String) async -> GoalsOverview {
        turnOffs += 1
        await withCheckedContinuation { release = $0 }
        return await sample.turnOff(goalID)
    }
}
