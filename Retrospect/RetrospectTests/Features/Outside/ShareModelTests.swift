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
    /// A ShareData that holds only the FIRST read (and, when `holdSave`, the first save) until the test lets
    /// it go; later calls return at once, so a missing guard fails the count instead of hanging. Counts saves.
    final class SlowShare: ShareData {
        var release: CheckedContinuation<Void, Never>?
        var holdItem = true
        var holdSave = false
        private(set) var saves = 0
        func item() async -> ShareItem {
            if holdItem {
                await holdFirst()
            }
            return SampleShare.paper
        }

        func save(why _: String) async {
            saves += 1
            if holdSave {
                await holdFirst()
            }
        }

        private var held = false

        private func holdFirst() async {
            guard !held else { return }
            held = true
            await withCheckedContinuation { release = $0 }
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

    @Test("a second save while the first is on its way does nothing: saved once")
    func doubleSave() async {
        let data = SlowShare()
        data.holdItem = false
        data.holdSave = true
        let model = ShareModel(data: data)
        await model.load()
        let first = Task { await model.save() }
        while data.release == nil {
            await Task.yield()
        }
        await model.save()
        model.cancel()
        data.release?.resume()
        await first.value
        #expect(data.saves == 1)
        #expect(model.state == .closed(saved: true))
    }
}
