@testable import Retrospect
import Testing

/// V2.settings · ST-3 / ST-4: the sources on the sample, what each row opens, and what sync, connect
/// and disconnect leave behind.
@MainActor
struct SourcesTests {
    private static let instant: @Sendable (Duration) async -> Void = { _ in }

    @Test("only a source with its own page drawn opens one (calendar)")
    func routes() {
        let data = SampleSettings(sleep: Self.instant)
        #expect(SettingsDestinations.isBuilt(.sources, data: data))
        #expect(SettingsDestinations.isBuilt(.source("calendar"), data: data))
        for id in ["voice-notes", "podcasts", "health", "nowhere"] {
            #expect(!SettingsDestinations.isBuilt(.source(id), data: data))
        }
    }

    @Test("rows show Paper's four states")
    func rowStates() {
        let states = SampleSettings(sleep: Self.instant).sources.map { SourcesPage.rowState($0.status) }
        #expect(states == [.connected, .notConnected, .needsAttention, .syncing])
    }

    @Test("sync now settles to connected, read just now")
    func sync() async {
        let data = SampleSettings(sleep: Self.instant)
        await data.sync("calendar")
        #expect(data.source("calendar")?.status == .connected)
        #expect(data.source("calendar")?.lastRead == "last read just now")
    }

    @Test("connect turns a source on")
    func connect() async {
        let data = SampleSettings(sleep: Self.instant)
        await data.connect("voice-notes")
        #expect(data.source("voice-notes")?.status == .connected)
    }

    @Test("disconnect leaves the source in the list, offering connect; delete changes nothing shown")
    func disconnectAndDelete() async {
        let data = SampleSettings(sleep: Self.instant)
        await data.deleteData(of: "calendar")
        #expect(data.source("calendar") == SampleSettings.paperSources.first)
        await data.disconnect("calendar")
        #expect(data.source("calendar")?.status == .notConnected)
        #expect(data.sources.count == 4)
        // a disconnected source only offers connect: no page until it's connected again
        #expect(!SettingsDestinations.isBuilt(.source("calendar"), data: data))
    }

    @Test("a disconnect during sync now stays disconnected: the finishing read doesn't bring it back")
    func disconnectDuringSync() async {
        let data = SampleSettings(sleep: { _ in try? await Task.sleep(for: .milliseconds(50)) })
        let reading = Task { await data.sync("calendar") }
        for _ in 0 ..< 100 where data.source("calendar")?.status != .syncing {
            await Task.yield()
        }
        #expect(data.source("calendar")?.status == .syncing)
        await data.disconnect("calendar")
        await reading.value
        #expect(data.source("calendar")?.status == .notConnected)
        #expect(data.source("calendar")?.lastRead == "last read 2 min ago")
    }

    @Test("ST-3 and ST-4 are in the launcher, ST-4 with its two questions")
    func registered() {
        #expect(ScreenRegistry.screen("ST-3")?.states == ["rest"])
        #expect(ScreenRegistry.screen("ST-4")?.states == ["rest", "disconnect", "delete"])
    }
}
