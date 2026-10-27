//
//  ShellScreens+Launcher.swift
//  V2 lane 0 (plan-v2.md §3): the app shell (tab bar: journal, podcasts, goals, you; the drawer),
//  opened with `-Screen shell -State <state> -Data sample`. Dark: listed here and nowhere in the
//  release root; mounting the shell in the app is a founder-approved wiring PR.
//  `tabs`: journal selected, JR-1 on its full sample. Only tabs with a page are live; podcasts, goals
//  and you are drawn but inert until their lanes add PC-1, GL-1 and YO-1 here (one line each in
//  `pages`, plus a launch state that opens on that tab). The journal's drawer button opens the account
//  page on a sample sign-out flow, as the app root does until the drawer (JR-3) is built.
//  `miniPlayer` (G0b, test state): the same, with a sample episode loaded, so the mini-player floats 12
//  above the bar; tapping it opens the player sheet through the shell's host, over the tab bar (L0-14).
//  `sheet` (G0b, test state): the same with the player sheet already up, to see it cover the bar.
//
#if DEBUG
import SwiftUI

enum ShellScreens: ScreenGroup {
    static let name = "shell"
    static let screens: [LaunchableScreen] = [
        LaunchableScreen(id: "shell", states: ShellScenario.allCases.map(\.rawValue)) { arguments in
            AnyView(ShellLaunch(scenario: ShellScenario(rawValue: arguments.state) ?? .tabs))
        },
    ]
}

/// Which tab the shell opens on. Only tabs with a page get a state (a blank page is never a state).
enum ShellScenario: String, CaseIterable {
    case tabs
    case miniPlayer
    case sheet

    var tab: RTab {
        switch self {
        case .tabs, .miniPlayer, .sheet: .journal
        }
    }
}

/// The shell on sample data: the tabs that have a page, and only those.
struct ShellLaunch: View {
    /// The tabs built so far (their lanes add theirs).
    static let pages: Set<RTab> = [.journal]

    @State private var model: ShellModel
    let scenario: ShellScenario

    init(scenario: ShellScenario) {
        self.scenario = scenario
        _model = State(initialValue: ShellModel(selection: scenario.tab, available: Self.pages))
    }

    var body: some View {
        ShellPage(model: model, miniPlayer: miniPlayer) { tab, _ in
            switch tab {
            case .journal: AnyView(ShellJournalLaunch())
            // not built yet (inert in the bar): their lanes add PC-1, GL-1 and YO-1 here
            case .podcasts, .goals, .you: nil
            }
        }
    }

    private var miniPlayer: AnyView? {
        switch scenario {
        case .tabs: nil
        case .miniPlayer: AnyView(ShellMiniPlayerLaunch(playerShown: false))
        case .sheet: AnyView(ShellMiniPlayerLaunch(playerShown: true))
        }
    }
}

/// JR-1 on its full sample, with the drawer button doing what it does in the app today: it opens the
/// account page (here on a sample sign-out flow, which sends nothing anywhere).
private struct ShellJournalLaunch: View {
    @State private var data = SampleJournalData(scenario: .full)
    @State private var accountShown = false
    @State private var signOut = SampleSignOutFlow(unsent: 0)
    @State private var reportSender = SampleReportSender(scenario: .online)

    var body: some View {
        JournalPageContainer(today: SampleJournalContent.today, openDrawer: { accountShown = true })
            .environment(\.journalData, data)
            .fullScreenCover(isPresented: $accountShown) {
                AccountPage(flow: signOut) { accountShown = false }
                    .environment(\.reportSender, reportSender)
                    // a cover is a new presentation: the account page keeps its own sheet host
                    .environment(\.rSheetHostAbove, false)
            }
    }
}

/// A sample episode loaded: the mini-player over the bar; its body opens the player sheet (through the
/// shell's host, so the sheet covers the bar) and its well pauses and plays.
private struct ShellMiniPlayerLaunch: View {
    @State private var playing = true
    @State private var playerShown: Bool

    init(playerShown: Bool) {
        _playerShown = State(initialValue: playerShown)
    }

    var body: some View {
        RMiniPlayer(
            title: "the week you stopped rushing",
            subline: "chapter 2 · the standup · 8 min left",
            artwork: RArtworkRecipes.weekly,
            phase: playing ? .playing : .paused,
            progress: 0.34,
            open: { playerShown = true },
            well: { playing.toggle() }
        )
        .rSheet(isPresented: $playerShown, detent: .full) {
            ShellPlayerLaunch { playerShown = false }
        }
    }
}

/// The player sheet on the sample episode, its model kept for as long as the sheet is up.
private struct ShellPlayerLaunch: View {
    @State private var model: PlayerSheetModel

    init(collapse: @escaping () -> Void) {
        _model = State(initialValue: PlayerSheetModel(
            playback: SamplePlayback(scenario: .teaseStill, clock: ContinuousClock()),
            transcript: SampleTranscript.tease,
            onCollapse: collapse
        ))
    }

    var body: some View {
        PlayerSheet(model: model)
    }
}

#Preview("shell · tabs") { ShellLaunch(scenario: .tabs) }
#Preview("shell · mini-player") { ShellLaunch(scenario: .miniPlayer) }
#Preview("shell · sheet over the bar") { ShellLaunch(scenario: .sheet) }
#endif
