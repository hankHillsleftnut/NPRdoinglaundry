@testable import Retrospect
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SourceModelTests {
    private func loaded(_ data: SampleYou = SampleYou()) async -> SourceModel {
        let model = SourceModel(sourceID: SampleYou.sleepEntry.id, data: data)
        await model.load()
        return model
    }

    @Test("loads Paper's entry; an unknown id is gone")
    func loads() async {
        let model = await loaded()
        #expect(model.entry == SampleYou.sleepEntry)
        let missing = SourceModel(sourceID: "nope", data: SampleYou())
        await missing.load()
        #expect(missing.state == .gone)
    }

    @Test("edit starts from the kept words; save lights only for a real, non-empty change")
    func canSave() async {
        let model = await loaded()
        model.beginEditing()
        #expect(model.edit.editing)
        #expect(model.edit.draft == SampleYou.sleepEntry.words)
        #expect(!model.canSave)
        model.edit.draft = "   "
        #expect(!model.canSave)
        model.edit.draft = "went to bed at 10."
        #expect(model.canSave)
    }

    @Test("save keeps the new words, on the page and in the sample")
    func save() async {
        let data = SampleYou()
        let model = await loaded(data)
        model.beginEditing()
        model.edit.draft = "went to bed at 10. "
        await model.save()
        #expect(!model.edit.editing)
        #expect(model.entry?.words == "went to bed at 10.")
        #expect(await data.source(id: SampleYou.sleepEntry.id)?.words == "went to bed at 10.")
    }

    @Test("cancel leaves the words as they were")
    func cancel() async {
        let model = await loaded()
        model.beginEditing()
        model.edit.draft = "something else"
        model.cancelEditing()
        #expect(!model.edit.editing)
        #expect(model.entry?.words == SampleYou.sleepEntry.words)
    }

    @Test("the launcher's editing state opens with the edit begun")
    func startsEditing() async {
        let model = SourceModel(sourceID: SampleYou.sleepEntry.id, data: SampleYou(), startsEditing: true)
        await model.load()
        #expect(model.edit.editing)
    }

    @Test("this supports: an answer opens YO-5; a goal (another group) opens nothing yet")
    func opener() {
        let entry = SampleYou.sleepEntry
        let navigator = YouNavigator()
        navigator.opener(for: entry.supports[0])?()
        #expect(navigator.path == [.whatIKnow])
        #expect(navigator.opener(for: entry.supports[1]) == nil)
        navigator.pop()
        #expect(navigator.path.isEmpty)
    }

    @Test("the page loads once: coming back keeps saved words")
    func loadsOnce() async {
        let model = await loaded()
        model.beginEditing()
        model.edit.draft = "went to bed at 10."
        await model.save()
        await model.load()
        #expect(model.entry?.words == "went to bed at 10.")
    }

    @Test("YO-3 is registered with rest and editing")
    func registered() {
        #expect(ScreenRegistry.screen("YO-3")?.states == ["rest", "editing"])
    }
}
