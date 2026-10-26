//
//  FirstRunScreens+Launcher.swift
//  First run's screens in the launcher (T02): `-Screen first-run -State questions|questions-resume|
//  questions-offline` opens ON-3–9 on `SampleFirstRunData` in that scenario; `-State privacy` opens
//  ON-5 on a silent ~8 s sample read-aloud, after which the page moves on; `-State connect` opens ON-6
//  on the sample sources (calendar connected). Nothing is mounted in the
//  app yet (FR.root): when a page is left it says so in a quiet line.
//
#if DEBUG
import SwiftUI

extension ScreenRegistry {
    static let firstRunScreens: [LaunchableScreen] = [
        LaunchableScreen(
            id: "first-run",
            states: FirstRunScenario.allCases.map(\.rawValue) + PrivacyScenario.allCases.map(\.rawValue)
                + ConnectScenario.allCases.map(\.rawValue)
        ) { arguments in
            if let privacy = PrivacyScenario(rawValue: arguments.state) {
                return AnyView(PrivacyLaunch(scenario: privacy))
            }
            if let connect = ConnectScenario(rawValue: arguments.state) {
                return AnyView(ConnectLaunch(scenario: connect))
            }
            return AnyView(QuestionsLaunch(scenario: FirstRunScenario(rawValue: arguments.state) ?? .questions))
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

/// ON-5 on the sample read-aloud, on the real clock, the way the host will mount it.
struct PrivacyLaunch: View {
    @State private var model: PrivacyModel?
    @State private var left: String?
    /// One state today; kept so a later state (a real voice, 0.2) is a case, not a new screen.
    let scenario: PrivacyScenario

    var body: some View {
        if let left {
            // stands in for the host's next or previous page (connect ON-6, or the last question)
            Text(left)
                .rText(.textMd)
                .foregroundStyle(RColor.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RColor.backgroundCanvas)
                .accessibilityIdentifier("privacy.left")
        } else if let model {
            PrivacyPage(model: model)
        } else {
            RColor.backgroundCanvas
                .ignoresSafeArea()
                .onAppear { model = makeModel() }
        }
    }

    private func makeModel() -> PrivacyModel {
        PrivacyModel(
            readAloud: SamplePrivacyReadAloud(clock: ContinuousClock()),
            onAdvance: { left = "privacy done" },
            onBack: { left = "back to the questions" }
        )
    }
}

/// ON-6 on the sample sources, the way the host will mount it. Continue, later and back say where
/// they would go in a quiet line (the host's next or previous page isn't mounted here).
struct ConnectLaunch: View {
    @State private var data: SampleConnect
    @State private var left: String?

    init(scenario: ConnectScenario) {
        _data = State(initialValue: SampleConnect(scenario: scenario))
    }

    var body: some View {
        if let left {
            // stands in for getting ready (ON-10) or privacy (ON-5)
            Text(left)
                .rText(.textMd)
                .foregroundStyle(RColor.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RColor.backgroundCanvas)
                .accessibilityIdentifier("connect.left")
        } else {
            ConnectPageContainer(
                data: data,
                onDone: { exit in left = exit == .continued ? "continue: on to getting ready" : "later: on to getting ready" },
                onBack: { left = "back to privacy" }
            )
        }
    }
}

#Preview("questions · fresh") { QuestionsLaunch(scenario: .questions) }
#Preview("questions · resume") { QuestionsLaunch(scenario: .questionsResume) }
#Preview("questions · offline") { QuestionsLaunch(scenario: .questionsOffline) }
#Preview("privacy") { PrivacyLaunch(scenario: .privacy) }
#Preview("connect") { ConnectLaunch(scenario: .connect) }
#endif
