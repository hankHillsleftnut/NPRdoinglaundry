//
//  JournalScreens+Launcher.swift
//  The journal's screens in the launcher (T02): `-Screen journal -State <JournalScenario>`
//  opens JR-1 on `SampleJournalData` in that scenario. The design lab's "journal" page reads
//  the same `-State`, so the page can be opened headlessly before the app root's hook exists.
//
#if DEBUG
import SwiftUI

extension ScreenRegistry {
    static let journalScreens: [LaunchableScreen] = [
        LaunchableScreen(id: "journal", states: JournalScenario.allCases.map(\.rawValue)) { arguments in
            AnyView(JournalLaunch(scenario: JournalScenario(rawValue: arguments.state) ?? .full))
        },
        LaunchableScreen(id: "JR-1", states: JournalScenario.allCases.map(\.rawValue)) { arguments in
            AnyView(JournalLaunch(scenario: JournalScenario(rawValue: arguments.state) ?? .full))
        },
    ]
}

/// JR-1 on the sample data for one scenario, through the seam, the way the app will mount it.
struct JournalLaunch: View {
    @State private var data: SampleJournalData

    init(scenario: JournalScenario) {
        _data = State(initialValue: SampleJournalData(scenario: scenario))
    }

    var body: some View {
        JournalPageContainer(today: SampleJournalContent.today)
            .environment(\.journalData, data)
    }
}

/// Lab page "journal": JR-1 in the scenario `-State` names (default `full`).
struct JournalLabPage: View {
    var body: some View {
        let arguments = LaunchArguments.parse(ProcessInfo.processInfo.arguments)
        if arguments.unknown.isEmpty {
            JournalLaunch(scenario: JournalScenario(rawValue: arguments.state) ?? .full)
        } else {
            // a flag the lab can't honour is shown, not ignored
            ScreenLauncher()
        }
    }
}

#Preview("journal · full") { JournalLaunch(scenario: .full) }
#Preview("journal · day one") { JournalLaunch(scenario: .dayOne) }
#endif
