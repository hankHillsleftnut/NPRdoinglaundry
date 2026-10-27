@testable import Retrospect
import Testing

/// V2.settings: the sample's values are Paper's, ST-1 follows what the pages change, and every ST-1 row
/// goes where the journey map says (or, while its page isn't built, nowhere).
@MainActor
struct SettingsStackTests {
    private static let instant: @Sendable (Duration) async -> Void = { _ in }

    @Test("the sample starts at Paper's values")
    func paperValues() {
        let data = SampleSettings(sleep: Self.instant)
        #expect(data.brief.isOn)
        #expect(data.brief.time.short == "8:30")
        #expect(data.brief.time.long == "8:30 am")
        #expect(data.brief.length == .standard)
        #expect(data.talkOrRead == .talk)
        #expect(data.voiceName == "warm")
        #expect(data.straightnessName == "honest")
        #expect(data.sources.map(\.name) == ["calendar", "voice notes", "podcasts", "health"])
        #expect(data.sources.map(\.status) == [.connected, .notConnected, .needsYou, .syncing])
    }

    @Test("times read the way the pages show them")
    func times() {
        #expect(Flows.Settings.LocalTime(hour: 0, minute: 5).long == "12:05 am")
        #expect(Flows.Settings.LocalTime(hour: 12, minute: 0).long == "12:00 pm")
        #expect(Flows.Settings.LocalTime(hour: 18, minute: 30).short == "6:30")
    }

    @Test("writes apply at once")
    func writes() {
        let data = SampleSettings(sleep: Self.instant)
        data.setBrief(isOn: false)
        data.setBrief(length: .long)
        data.setBrief(time: Flows.Settings.LocalTime(hour: 7, minute: 0))
        data.setTalkOrRead(.read)
        #expect(!data.brief.isOn)
        #expect(data.brief.length == .long)
        #expect(data.brief.time.long == "7:00 am")
        #expect(data.talkOrRead == .read)
    }

    @Test("ST-1's rows: built pages open (the second half pins its own routes in SettingsTrustTests)")
    func routes() {
        let data = SampleSettings(sleep: Self.instant)
        #expect(SettingsDestinations.isBuilt(.account, data: data))
    }

    @Test("every route has its own row identifier")
    func identifiers() {
        let pages: [SettingsRoute] = [.dailyBrief, .sources, .source("calendar"), .privacy, .howStraight, .voice, .learned, .account]
        #expect(Set(pages.map(SettingsHubPage.identifier)).count == pages.count)
    }

    @Test("the settings group registers ST-1 in the launcher")
    func registered() {
        #expect(ScreenRegistry.screen("ST-1")?.states == ["rest"])
    }
}
