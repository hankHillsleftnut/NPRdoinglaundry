//
//  FirstRunScreens+Launcher.swift
//  First run's screens in the launcher (T02): `-Screen first-run -State questions|questions-resume|
//  questions-offline` opens ON-3–9 on `SampleFirstRunData` in that scenario. Nothing is mounted in
//  the app yet (FR.root): when every question is answered the page says so in a quiet line.
//
#if DEBUG
import SwiftUI

extension ScreenRegistry {
    static let firstRunScreens: [LaunchableScreen] = [
        LaunchableScreen(id: "first-run", states: FirstRunScenario.allCases.map(\.rawValue)) { arguments in
            AnyView(QuestionsLaunch(scenario: FirstRunScenario(rawValue: arguments.state) ?? .questions))
        },
    ]
}

/// ON-3–9 on the sample data for one scenario, through the seam, the way the host will mount it.
struct QuestionsLaunch: View {
    @State private var data: SampleFirstRunData
    @State private var done = false

    init(scenario: FirstRunScenario) {
        _data = State(initialValue: SampleFirstRunData(scenario: scenario))
    }

    var body: some View {
        if done {
            // stands in for the host's next page (getting ready, P05.min)
            Text("questions done")
                .rText(.textMd)
                .foregroundStyle(RColor.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RColor.backgroundCanvas)
                .accessibilityIdentifier("questions.done")
        } else {
            QuestionsPageContainer(data: data) { done = true }
        }
    }
}

#Preview("questions · fresh") { QuestionsLaunch(scenario: .questions) }
#Preview("questions · resume") { QuestionsLaunch(scenario: .questionsResume) }
#Preview("questions · offline") { QuestionsLaunch(scenario: .questionsOffline) }
#endif
