@testable import Retrospect
import Testing

/// V2.outside · EX-1 on the sample: Paper's words, and the two ways the sheet closes.
@MainActor
struct ShareModelTests {
    @Test("ready shows Paper's item: title, source, Retro's read, the goal")
    func ready() async throws {
        let model = ShareModel(data: SampleShare())
        #expect(model.state == .idle)
        await model.load()
        let item = try #require(model.item)
        #expect(item.title == "how to raise a seed round in 2026")
        #expect(item.source == "youtube.com · 40 min video")
        #expect(item.read == "a 40-minute talk on raising a seed round, mostly about angels.")
        #expect(item.goal == "raise the seed")
    }

    @Test("save records the why (trimmed) and closes the sheet")
    func save() async {
        let data = SampleShare()
        let model = ShareModel(data: data, why: "  for the raise, the bit on angels \n")
        await model.load()
        await model.save()
        #expect(model.state == .closed(saved: true))
        #expect(data.saved == "for the raise, the bit on angels")
    }

    @Test("save with no why is still a save")
    func saveWithoutWhy() async {
        let data = SampleShare()
        let model = ShareModel(data: data)
        await model.load()
        await model.save()
        #expect(data.saved == "")
    }

    @Test("cancel closes without saving")
    func cancel() async {
        let data = SampleShare()
        let model = ShareModel(data: data)
        await model.load()
        model.cancel()
        #expect(model.state == .closed(saved: false))
        #expect(data.saved == nil)
    }

    @Test("EX-1 is registered with its two states")
    func registered() {
        #expect(OutsideScreens.screens.first { $0.id == "EX-1" }?.states == ["ready", "typed"])
    }
}
