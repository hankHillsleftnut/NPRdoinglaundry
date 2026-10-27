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
        #expect(data.straightness.level == .honestObservations)
        #expect(data.straightness.source == .picked)
        #expect(data.straightness.why?.hasPrefix("i picked honest observations because") == true)
    }

    @Test("choosing applies at once and ST-1's value follows")
    func choosingFollows() {
        let data = SampleSettings(sleep: Self.instant)
        #expect(data.straightnessName == "honest")
        data.setStraightness(.gentleQuestions)
        #expect(data.straightness == Flows.Settings.StraightnessSetting(level: .gentleQuestions, source: .yours, why: nil))
        #expect(data.straightnessName == "gentle")
        // handing it back to retro restores retro's pick and its reason
        data.setStraightness(nil)
        #expect(data.straightness.source == .picked)
        #expect(data.straightness.level == .honestObservations)
        #expect(data.straightness.why != nil)
    }

    @Test("every choice has its own short value for ST-1")
    func shortNames() {
        let names = Flows.Settings.Straightness.allCases.map(\.shortName)
        #expect(Set(names).count == names.count)
    }

    @Test("ST-8 reads Paper's three lines")
    func learned() {
        let learned = SampleSettings(sleep: Self.instant).learned
        #expect(learned.state == .learning)
        #expect(learned.headline == "you answer questions about work most, 8 of 10.")
        #expect(learned.detail == "you skip ones about family (1 of 5), so i ask those less, and only when you bring it up first.")
        #expect(learned.changedAt.map(LearnedPage.changed) == "last changed on sunday")
    }

    @Test("what i've learned opens nothing while it's too early or off (undrawn)")
    func learnedNotYet() {
        let data = SampleSettings(sleep: Self.instant)
        for state in [Flows.Settings.Learned.State.tooEarly, .off, .unknown] {
            data.trust.learned = Flows.Settings.Learned(state: state, headline: nil, detail: nil, changedAt: nil)
            #expect(!SettingsDestinations.isBuilt(.learned, data: data))
        }
    }

    @Test("ST-5 starts as Paper draws it and its switch applies at once")
    func privacy() async throws {
        let data = SampleSettings(sleep: Self.instant)
        #expect(data.ambient == Flows.Settings.Ambient(enabled: true, effective: true, pausedForEveryone: false))
        #expect(SettingsPrivacyPage.processedWhere == "europe · named providers")
        try await data.setAmbient(enabled: false)
        #expect(!data.ambient.enabled)
        #expect(!data.ambient.effective)
        try await data.deleteMyData()
        #expect(!data.ambient.enabled)
    }

    @Test("paused for everyone: your switch stays yours, but nothing reads")
    func pausedForEveryone() async throws {
        let data = SampleSettings(sleep: Self.instant)
        data.trust.ambient.pausedForEveryone = true
        try await data.setAmbient(enabled: true)
        #expect(data.ambient.enabled)
        #expect(!data.ambient.effective)
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

    @Test("ST-9 reads Paper's plan line and its delete changes nothing in the sample")
    func account() async throws {
        let data = SampleSettings(sleep: Self.instant)
        let plan = try #require(data.plan)
        #expect(plan.name == "yearly")
        #expect(AccountSettingsPage.renewal(plan) == "renews on 3 march · $239.99")
        try await data.deleteAccount()
        #expect(data.plan == plan)
    }

    @Test("ST-9's undrawn rows are inert: not buttons, no press style, value 'not available yet'")
    func inertRows() {
        #expect(SettingsInertRow.unavailable == "not available yet")
        for row in [SettingsInertRow(title: "restore purchases"), SettingsInertRow(title: "manage subscription", leavesApp: true)] {
            let shape = String(describing: type(of: row.body))
            #expect(!shape.contains("Button"))
            #expect(!shape.contains("RListRowStyle"))
        }
    }

    @Test("the trust group registers ST-5 … ST-8 in the launcher")
    func registered() {
        #expect(ScreenRegistry.screen("ST-5")?.states == ["rest", "delete"])
        #expect(ScreenRegistry.screen("ST-7")?.states == ["rest"])
        #expect(ScreenRegistry.screen("ST-9")?.states == ["rest", "delete"])
        // the shipping account page keeps its own launcher entry
        #expect(ScreenRegistry.screen("account") != nil)
        #expect(ScreenRegistry.screen("ST-6")?.states == ["rest"])
        #expect(ScreenRegistry.screen("ST-8")?.states == ["rest"])
    }
}
