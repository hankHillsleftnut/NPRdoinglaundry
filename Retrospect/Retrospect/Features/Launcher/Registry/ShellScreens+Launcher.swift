//
//  ShellScreens+Launcher.swift
//  V2 lane 0 (plan-v2.md §3): the app shell (tab bar: journal, podcasts, goals, you; the drawer),
//  opened with `-Screen shell -State <state> -Data sample`. Dark: listed here and nowhere in the
//  release root; mounting the shell in the app is a founder-approved wiring PR.
//  `tabs`: journal selected, JR-1 on its full sample; `podcasts`, `goals`, `you`: that tab selected.
//  Tabs whose screens aren't built show the canvas (their lanes add them here, one line each).
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

/// Which tab the shell opens on.
enum ShellScenario: String, CaseIterable {
    case tabs, podcasts, goals, you

    var tab: RTab {
        switch self {
        case .tabs: .journal
        case .podcasts: .podcasts
        case .goals: .goals
        case .you: .you
        }
    }
}

/// The shell on sample data: each tab's built page, or nothing.
struct ShellLaunch: View {
    @State private var model: ShellModel

    init(scenario: ShellScenario) {
        _model = State(initialValue: ShellModel(selection: scenario.tab))
    }

    var body: some View {
        ShellPage(model: model) { tab, _ in
            switch tab {
            case .journal: AnyView(JournalLaunch(scenario: .full))
            // not built yet: their lanes add PC-1, GL-1 and YO-1 here
            case .podcasts, .goals, .you: nil
            }
        }
    }
}

#Preview("shell · tabs") { ShellLaunch(scenario: .tabs) }
#endif
