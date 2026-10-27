@testable import Retrospect
import Testing

/// V2 lane 0 · the shell, dark: the launcher opens it on the journal, only tabs with a page are live,
/// a re-tap is counted for the page, and it stays out of the release app (ReleaseRouteTableTests,
/// #205, fences Features/Shell).
@MainActor
struct ShellModelTests {
    @Test("-Screen shell has one state per tab with a page: today only the journal")
    func launches() {
        let screen = ScreenRegistry.screen("shell")
        #expect(screen?.states == ["tabs"])
        // no launch state opens on a tab with nothing built (no blank pages)
        for scenario in ShellScenario.allCases {
            #expect(ShellLaunch.pages.contains(scenario.tab), "-State \(scenario.rawValue) opens on an unbuilt tab")
        }
        #expect(ShellLaunch.pages == [.journal])
        for state in ShellScenario.allCases.map(\.rawValue) {
            _ = screen?.build(LaunchArguments.parse(["app", "-Screen", "shell", "-State", state]))
        }
    }

    @Test("a tab with no page is inert: selecting it leaves the selection as it was")
    func unbuiltTabsAreInert() {
        let model = ShellModel(available: [.journal])
        for tab in [RTab.podcasts, .goals, .you] {
            model.select(tab)
            #expect(model.selection == .journal, "\(tab.rawValue) has no page but was selected")
        }
        #expect(model.visited == [.journal])
        #expect(model.context(for: .journal) == ShellTabContext(isShown: true, reselects: 0))
    }

    @Test("asked to open on a tab with no page, the shell opens on the first tab that has one")
    func opensOnABuiltTab() {
        let model = ShellModel(selection: .goals, available: [.journal, .you])
        #expect(model.selection == .journal)
        #expect(model.visited == [.journal])
    }

    @Test("switching tabs changes the selection and tells each page whether it is shown")
    func reselect() {
        let model = ShellModel()
        #expect(model.selection == .journal)
        model.select(.goals)
        model.reselect(.goals)
        model.reselect(.goals)
        #expect(model.reselects[.goals] == 2)
        #expect(model.reselects[.journal] == nil)
        #expect(model.context(for: .goals) == ShellTabContext(isShown: true, reselects: 2))
        #expect(model.context(for: .journal) == ShellTabContext(isShown: false, reselects: 0))
        model.select(.journal)
        #expect(model.context(for: .goals).isShown == false)
        #expect(model.context(for: .journal).isShown)
    }

    @Test("a tab's page is built the first time it is shown, and kept")
    func visited() {
        let model = ShellModel(selection: .podcasts)
        #expect(model.visited == [.podcasts])
        model.select(.you)
        model.select(.podcasts)
        #expect(model.visited == [.podcasts, .you])
    }
}
