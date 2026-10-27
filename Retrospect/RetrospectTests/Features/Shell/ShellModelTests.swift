@testable import Retrospect
import SwiftUI
import Testing

/// V2 lane 0 · the shell, dark: the launcher opens it on the journal, only tabs with a page are live,
/// a re-tap is counted for the page, and it stays out of the release app (ReleaseRouteTableTests,
/// #205, fences Features/Shell).
@MainActor
struct ShellModelTests {
    @Test("-Screen shell opens on a tab with a page: the journal, alone or with the mini-player (G0b)")
    func launches() {
        let screen = ScreenRegistry.screen("shell")
        #expect(screen?.states == ["tabs", "miniPlayer", "sheet"])
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

    @Test("G0b: the shell shows a sheet only when its page is built, and never two at once")
    func sheets() {
        let model = ShellModel()
        for kind in AppSheet.Kind.allCases {
            let sheet = AppRouteTableTests.sample(kind)
            model.present(sheet)
            #expect((model.sheet == sheet) == AppRoutes.isBuilt(sheet), "sheet \(kind.rawValue)")
            let first = model.sheet
            // a second request while one is up waits (RSheetHost never stacks two)
            for other in AppSheet.Kind.allCases.map(AppRouteTableTests.sample) where other != sheet {
                model.present(other)
                #expect(first == nil || model.sheet == first)
            }
            model.dismissSheet()
            #expect(model.sheet == nil)
        }
    }

    @Test("G0b: each presentation is its own; a late close from the last one never takes the next")
    func presentations() {
        let model = ShellModel(sheetIsBuilt: { _ in true })
        model.present(.episode(id: "a"))
        #expect(model.sheet == .episode(id: "a"))
        #expect(model.presentation == 1)
        // never two at once
        model.present(.node(id: "b"))
        #expect(model.sheet == .episode(id: "a"))
        model.dismissSheet(1)
        #expect(model.sheet == nil)
        // the page stays on the panel while it slides away
        #expect(model.presented == .episode(id: "a"))
        // asked for while A is still closing: a new presentation
        model.present(.node(id: "b"))
        #expect(model.presentation == 2)
        // A's close finishing late (its binding set to false) leaves B up
        model.dismissSheet(1)
        #expect(model.sheet == .node(id: "b"))
        model.dismissSheet(2)
        #expect(model.sheet == nil)
    }

    @Test("G0b: a passed-through sheet host clears the mark for what it holds (covers inside keep their sheets)")
    func hostAboveDoesNotLeak() {
        let seen = HostAboveSeen()
        let underShell = RSheetHost { HostAboveProbe(seen: seen) }
            .environment(\.rSheetHostAbove, true)
            .frame(width: 40, height: 40)
        _ = ImageRenderer(content: underShell).uiImage
        #expect(!seen.values.isEmpty && !seen.values.contains(true), "a page inside a passed-through host still sees the shell's host above")
        let alone = HostAboveSeen()
        _ = ImageRenderer(content: RSheetHost { HostAboveProbe(seen: alone) }.frame(width: 40, height: 40)).uiImage
        #expect(!alone.values.isEmpty && !alone.values.contains(true))
        let bare = HostAboveSeen()
        _ = ImageRenderer(content: HostAboveProbe(seen: bare).environment(\.rSheetHostAbove, true)).uiImage
        #expect(!bare.values.isEmpty && !bare.values.contains(false), "the probe reads the mark")
    }
}

/// What the probe saw, each time it was built.
private final class HostAboveSeen {
    var values: [Bool] = []
}

private struct HostAboveProbe: View {
    let seen: HostAboveSeen
    @Environment(\.rSheetHostAbove) private var hostAbove

    var body: some View {
        seen.values.append(hostAbove)
        return Color.clear
    }
}
