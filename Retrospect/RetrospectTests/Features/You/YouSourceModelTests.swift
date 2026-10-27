@testable import Retrospect
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct YouSourceModelTests {
    @Test("loads Paper's entry once; an unknown id is gone")
    func loads() async {
        let model = YouSourceModel(sourceID: SampleYou.sleepEntry.id, data: SampleYou())
        await model.load()
        #expect(model.entry == SampleYou.sleepEntry)
        await model.load()
        #expect(model.entry == SampleYou.sleepEntry)
        let missing = YouSourceModel(sourceID: "nope", data: SampleYou())
        await missing.load()
        #expect(missing.state == .gone)
    }

    @Test("this supports: an answer opens YO-5; a goal (another group) has nothing behind it yet")
    func opener() {
        let entry = SampleYou.sleepEntry
        let navigator = YouNavigator()
        navigator.opener(for: entry.supports[0])?()
        #expect(navigator.path == [.whatIKnow])
        #expect(navigator.opener(for: entry.supports[1]) == nil)
        navigator.pop()
        #expect(navigator.path.isEmpty)
    }

    @Test("YO-3 is registered with its drawn state")
    func registered() {
        #expect(ScreenRegistry.screen("YO-3")?.states == ["rest"])
    }
}
