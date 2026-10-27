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

    @Test("ST-1's how straight and what i've learned rows open their pages")
    func routes() {
        let data = SampleSettings(sleep: Self.instant)
        #expect(SettingsDestinations.isBuilt(.howStraight, data: data))
        #expect(SettingsDestinations.isBuilt(.learned, data: data))
        #expect(SettingsDestinations.isBuilt(.account, data: data))
    }

    @Test("the trust group registers ST-6 and ST-8 in the launcher")
    func registered() {
        #expect(ScreenRegistry.screen("ST-6")?.states == ["rest"])
        #expect(ScreenRegistry.screen("ST-8")?.states == ["rest"])
    }
}
