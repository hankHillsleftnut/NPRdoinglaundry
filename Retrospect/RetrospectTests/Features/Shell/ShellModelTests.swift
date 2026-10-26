@testable import Retrospect
import Testing

/// V2 lane 0 · the shell, dark: the launcher opens it on each tab, a re-tap is counted for the page,
/// and it stays out of the release app (ReleaseRouteTableTests fences Features/Shell).
@MainActor
struct ShellModelTests {
    @Test("-Screen shell opens on each tab")
    func launches() {
        let screen = ScreenRegistry.screen("shell")
        #expect(screen?.states == ["tabs", "podcasts", "goals", "you"])
        #expect(ShellScenario.allCases.map(\.tab) == RTab.allCases)
        for state in ShellScenario.allCases.map(\.rawValue) {
            _ = screen?.build(LaunchArguments.parse(["app", "-Screen", "shell", "-State", state]))
        }
    }

    @Test("switching tabs changes the selection; a re-tap is counted for that tab only")
    func reselect() {
        let model = ShellModel()
        #expect(model.selection == .journal)
        model.selection = .goals
        model.reselect(.goals)
        model.reselect(.goals)
        #expect(model.reselects[.goals] == 2)
        #expect(model.reselects[.journal] == nil)
        #expect(model.context(for: .goals) == ShellTabContext(isShown: true, reselects: 2))
        #expect(model.context(for: .journal) == ShellTabContext(isShown: false, reselects: 0))
    }

    @Test("a tab's page is built the first time it is shown, and kept")
    func visited() {
        let model = ShellModel(selection: .podcasts)
        #expect(model.visited == [.podcasts])
        model.selection = .you
        model.selection = .podcasts
        #expect(model.visited == [.podcasts, .you])
    }
}
