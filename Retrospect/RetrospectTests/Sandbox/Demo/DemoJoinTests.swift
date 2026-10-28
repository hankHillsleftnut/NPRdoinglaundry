import Foundation
@testable import Retrospect
import SwiftUI
import Testing

/// DEMO.app.b: the joins between groups the demo walks, through the app route table (G0). Each join is a
/// page its owning group builds, opened only where a stack above can push it; settings' own rows keep
/// the stack's rule (a page with nothing to show stays shut); back from a page pushed onto the You stack
/// pops only it; the brief card opens the host's sheet instead of the text sheet when the host has one.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct DemoJoinTests {
    @Test("the joins the demo walks are built by their owners: JR-4, ST-1 … ST-9, the JR-2 sheet")
    func builtJoins() {
        #expect(AppRoutes.isBuilt(.entry(id: SampleEntriesData.hereID)))
        for page: AppRoute.SettingsPage in [
            .hub, .dailyBrief, .sources, .source(id: "calendar"), .privacy, .howStraight, .voice, .learned, .account,
        ] {
            #expect(AppRoutes.isBuilt(.settings(page)), "settings \(page) not built")
        }
        #expect(AppRoutes.isBuilt(.brief(id: nil)))
        // not joined yet, so their controls stay plain: GL-2 from YO-3 (the samples' goal has no GL-2 drawn)
        #expect(!AppRoutes.isBuilt(.goal(id: "goal.ship")))
    }

    @Test("every settings stack route maps to its app route and back; ST-1 is the stack's root")
    func settingsRoutesRoundTrip() {
        let routes: [SettingsRoute] = [.dailyBrief, .sources, .source("calendar"), .privacy, .howStraight, .voice, .learned, .account]
        for route in routes {
            #expect(AppDestinations.Settings.route(for: AppDestinations.Settings.page(for: route)) == route)
        }
        #expect(AppDestinations.Settings.route(for: .hub) == nil)
    }

    @Test("your picture opens ST-1 only when a stack can push it")
    func pictureOpensSettings() {
        var pushed: [AppRoute] = []
        #expect(AppRouter().opener(.settings(.hub)) == nil)
        AppRouter(push: { pushed.append($0) }).opener(.settings(.hub))?()
        #expect(pushed == [.settings(.hub)])
    }

    @Test("back from a page on the You stack pops it and anything above it, never the page under it")
    func youStackBack() {
        let navigator = YouNavigator(path: [.source("s1"), .app(.settings(.hub)), .app(.settings(.dailyBrief))])
        navigator.pop(to: .app(.settings(.hub)))
        #expect(navigator.path == [.source("s1")])
        // a late back for a page already gone does nothing
        navigator.pop(to: .app(.settings(.account)))
        #expect(navigator.path == [.source("s1")])
    }

    @Test("the brief card raises the host's sheet when it has one, else the text sheet")
    func briefCardOpensTheSheet() async {
        let hosted = JournalViewModel(data: SampleJournalData(scenario: .full), today: SampleJournalContent.today)
        await hosted.load()
        var opened = 0
        hosted.openBrief = { opened += 1 }
        hosted.open()
        await hosted.play()
        #expect(opened == 2)
        #expect(hosted.playerShown == false)

        let alone = JournalViewModel(data: SampleJournalData(scenario: .full), today: SampleJournalContent.today)
        await alone.load()
        alone.open()
        #expect(alone.playerShown)
    }

    @Test("-DemoTab opens the app on that tab; none or an unknown one is the journal")
    func demoTab() {
        #expect(DemoLaunch.parse(["-DemoTab", "podcasts"]).tab == .podcasts)
        #expect(DemoLaunch.parse(["-DemoTab", "nowhere"]).tab == nil)
        let model = DemoModel(store: MemoryDemoStore(), flowStore: MemoryFlowStore(), launch: DemoLaunch(start: .app, tab: .you), sleep: { _ in })
        #expect(model.startTab == .you)
        #expect(DemoModel(store: MemoryDemoStore(), flowStore: MemoryFlowStore(), launch: DemoLaunch(start: .app), sleep: { _ in }).startTab == .journal)
    }

    @Test("one set of samples per session: every page reads the same seam, a new session has new ones")
    func samplesPerSession() {
        let first = DemoSamples()
        let second = DemoSamples()
        #expect(first.entries !== second.entries)
        #expect(first.settings !== second.settings)
        #expect(first.signOut !== second.signOut)
        #expect(first.signOut.state == .asking(unsent: 0))
    }
}
