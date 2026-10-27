@testable import Retrospect
import Testing

/// V2.journal · JR-4: one entry's model on the drawer's sample. The meta line words when, how and
/// where the entry is, as Paper's 05 frames do; a line that didn't send retries; the cut shows no
/// part whose door isn't live.
@MainActor
struct EntryModelTests {
    private func shown(_ id: String) async -> EntryModel {
        let model = EntryModel(id: id, data: SampleEntriesData(scenario: .rest, sendBeat: .zero))
        await model.load()
        return model
    }

    @Test("rest: today, the time, written, read (Paper N51-0)")
    func rest() async {
        let model = await shown(SampleEntries.hereID)
        #expect(model.state == .shown(words: "i think it's the 9am standup. i dread it.", meta: "today · 9:12 · written · read", standing: .read))
    }

    @Test("voice note: yesterday, voice, read, the transcript as the words (Paper N6E-0)")
    func voiceNote() async {
        let model = await shown(SampleEntries.walkID)
        guard case let .shown(words, meta, standing) = model.state else {
            Issue.record("not shown")
            return
        }
        #expect(words.hasPrefix("on the walk home i kept thinking about the offer"))
        #expect(meta == "yesterday · 18:05 · voice · read")
        #expect(standing == .read)
    }

    @Test("nothing taken yet: sent, not read (Paper N7R-0)")
    func nothingTaken() async {
        let model = await shown(SampleEntries.ranID)
        #expect(model.state == .shown(words: "ran 5k without stopping", meta: "today · 8:02 · written · sent", standing: .sent))
    }

    @Test("didn't send: the line says so, and a retry sends it (Paper N9D-0)")
    func retry() async {
        let model = await shown(SampleEntries.trainID)
        #expect(model.state == .shown(
            words: "the train is stuck again, writing this underground",
            meta: "today · 9:40 · didn't send · tap to retry",
            standing: .notSent
        ))
        await model.retry()
        #expect(model.state == .shown(
            words: "the train is stuck again, writing this underground",
            meta: "today · 9:40 · written · sent",
            standing: .sent
        ))
    }

    @Test("an entry that isn't there says so instead of a blank page")
    func missing() async {
        let model = await shown("nope")
        guard case .failed = model.state else {
            Issue.record("expected failed")
            return
        }
    }

    @Test("the cut has no part without a door; drawn turns them on")
    func capabilities() {
        #expect(EntryCapabilities.cut == EntryCapabilities(edit: false, delete: false, took: false))
        #expect(EntryCapabilities.drawn == EntryCapabilities(edit: true, delete: true, took: true))
        let model = EntryModel(id: SampleEntries.hereID, data: SampleEntriesData(scenario: .rest))
        #expect(model.capabilities == .cut)
    }

    @Test("day words: today, yesterday, then the short date")
    func dayWords() {
        #expect(EntryWords.dayLabel("2025-10-21", today: "2025-10-21") == "today")
        #expect(EntryWords.dayLabel("2025-10-20", today: "2025-10-21") == "yesterday")
        #expect(EntryWords.dayLabel("2025-10-14", today: "2025-10-21") == "tue 14 oct")
    }
}
