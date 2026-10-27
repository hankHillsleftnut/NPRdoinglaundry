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

/// Review on #220: closing wins over a slow read; one save per tap; no save before the item.
@MainActor
struct ShareModelGuardTests {
    /// A ShareData whose read waits until the test lets it go.
    final class SlowShare: ShareData {
        var release: CheckedContinuation<Void, Never>?
        private(set) var saves = 0
        func item() async -> ShareItem {
            await withCheckedContinuation { release = $0 }
            return SampleShare.paper
        }

        func save(why _: String) async {
            saves += 1
        }
    }

    @Test("cancel while the item is loading stays cancelled")
    func cancelDuringLoad() async {
        let data = SlowShare()
        let model = ShareModel(data: data)
        let load = Task { await model.load() }
        while data.release == nil {
            await Task.yield()
        }
        model.cancel()
        data.release?.resume()
        await load.value
        #expect(model.state == .closed(saved: false))
    }

    @Test("save before the item has loaded does nothing")
    func saveBeforeLoad() async {
        let data = SampleShare()
        let model = ShareModel(data: data)
        await model.save()
        #expect(model.state == .idle)
        #expect(data.saved == nil)
    }

    @Test("two saves at once save once")
    func doubleSave() async {
        let data = SampleShare()
        let model = ShareModel(data: data)
        await model.load()
        async let first: Void = model.save()
        async let second: Void = model.save()
        _ = await (first, second)
        #expect(model.state == .closed(saved: true))
    }
}
