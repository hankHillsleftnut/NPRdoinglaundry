@testable import Retrospect
import Testing

/// V2.settings, second half: the sample holds Paper's ST-6 / ST-8 words, choosing applies at once and
/// ST-1 follows, and ST-1's rows open the pages this half has built.
@MainActor
struct SettingsTrustTests {
    private static let instant: @Sendable (Duration) async -> Void = { _ in }

    @Test("ST-6's choices are Paper's, in Paper's order, honest observations chosen by retro")
    func straightnessChoices() {
        let data = SampleSettings(sleep: Self.instant)
        #expect(Flows.Settings.Straightness.allCases.map(\.title) == [
            "just what happened", "gentle questions", "honest observations", "don't hold back",
        ])
        #expect(Flows.Settings.Straightness.allCases.map(\.subline) == [
            "no reading between the lines", "i ask, i don't tell", "i say what i see, kindly", "i say it plainly",
        ])
        #expect(data.straightness == .honestObservations)
        #expect(data.retroPick == .honestObservations)
        #expect(data.retroReason.hasPrefix("i picked honest observations because"))
    }

    @Test("choosing applies at once and ST-1's value follows")
    func choosingFollows() {
        let data = SampleSettings(sleep: Self.instant)
        #expect(data.straightnessName == "honest")
        data.setStraightness(.gentleQuestions)
        #expect(data.straightness == .gentleQuestions)
        #expect(data.straightnessName == "gentle")
        // retro's own pick (and its note) doesn't move when you choose
        #expect(data.retroPick == .honestObservations)
    }

    @Test("every choice has its own short value for ST-1")
    func shortNames() {
        let names = Flows.Settings.Straightness.allCases.map(\.shortName)
        #expect(Set(names).count == names.count)
    }

    @Test("ST-8 reads Paper's three lines")
    func learned() {
        let learned = SampleSettings(sleep: Self.instant).learned
        #expect(learned?.headline == "you answer questions about work most, 8 of 10.")
        #expect(learned?.detail == "you skip ones about family (1 of 5), so i ask those less, and only when you bring it up first.")
        #expect(learned?.changed == "last changed on sunday")
    }

    @Test("ST-5 starts as Paper draws it and its switch applies at once")
    func privacy() async {
        let data = SampleSettings(sleep: Self.instant)
        #expect(data.readsInBackground)
        #expect(data.processedWhere == "europe · named providers")
        data.setReadsInBackground(false)
        #expect(!data.readsInBackground)
        await data.deleteMyData()
        #expect(!data.readsInBackground)
    }

    @Test("ST-7: speed starts at 1×, picks apply, talk or read is ST-1's value")
    func voice() {
        let data = SampleSettings(sleep: Self.instant)
        #expect(data.speed.label == "1×")
        #expect(Flows.Settings.Speed.allCases.map(\.label) == ["0.8×", "1×", "1.25×", "1.5×"])
        data.setSpeed(.faster)
        #expect(data.speed == .faster)
        data.setTalkOrRead(.read)
        #expect(data.talkOrRead == .read)
        #expect(data.voiceName == "warm")
    }

    @Test("ST-1's second-half rows all open their pages")
    func routes() {
        let data = SampleSettings(sleep: Self.instant)
        #expect(SettingsDestinations.isBuilt(.privacy, data: data))
        #expect(SettingsDestinations.isBuilt(.voice, data: data))
        #expect(SettingsDestinations.isBuilt(.howStraight, data: data))
        #expect(SettingsDestinations.isBuilt(.learned, data: data))
        #expect(SettingsDestinations.isBuilt(.account, data: data))
    }

    @Test("the trust group registers ST-5 … ST-8 in the launcher")
    func registered() {
        #expect(ScreenRegistry.screen("ST-5")?.states == ["rest", "delete"])
        #expect(ScreenRegistry.screen("ST-7")?.states == ["rest"])
        #expect(ScreenRegistry.screen("ST-6")?.states == ["rest"])
        #expect(ScreenRegistry.screen("ST-8")?.states == ["rest"])
    }
}
