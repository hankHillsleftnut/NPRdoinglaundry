//
//  FirstRunScreens+Launcher.swift
//  First run's screens in the launcher (T02): `-Screen first-run -State questions|questions-resume|
//  questions-offline` opens ON-3–9 on `SampleFirstRunData` in that scenario; `-State privacy` opens
//  ON-5 on a silent ~8 s sample read-aloud, after which the page moves on; `-State getting-ready|
//  getting-ready-still` opens ON-10 on the sample listening and episode. Nothing is mounted in the
//  app yet (FR.root): when a page is left it says so in a quiet line.
//
#if DEBUG
import SwiftUI

extension ScreenRegistry {
    static let firstRunScreens: [LaunchableScreen] = [
        LaunchableScreen(
            id: "first-run",
            states: FirstRunScenario.allCases.map(\.rawValue) + PrivacyScenario.allCases.map(\.rawValue)
                + GettingReadyScenario.allCases.map(\.rawValue)
        ) { arguments in
            if let privacy = PrivacyScenario(rawValue: arguments.state) {
                return AnyView(PrivacyLaunch(scenario: privacy))
            }
            if let gettingReady = GettingReadyScenario(rawValue: arguments.state) {
                return AnyView(GettingReadyLaunch(scenario: gettingReady))
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

/// ON-10 on the sample seams, on the real clock: `getting-ready` hears an invented answer and is made
/// about 30 s later; `getting-ready-still` holds Paper's frame. Nothing is mounted after it yet (the
/// tease, ON-11): when it is made the line fills, VoiceOver hears it, and the page stays.
struct GettingReadyLaunch: View {
    let scenario: GettingReadyScenario
    @State private var firstRun = SampleFirstRunData(scenario: .questions)
    @State private var episode: SampleFirstEpisode
    @State private var listening: SampleListening

    init(scenario: GettingReadyScenario) {
        self.scenario = scenario
        _episode = State(initialValue: SampleFirstEpisode(scenario: scenario.episode))
        _listening = State(initialValue: SampleListening(ends: scenario.utteranceEnds, waits: scenario.utteranceEnds))
    }

    var body: some View {
        GettingReadyPageContainer(firstRun: firstRun, episode: episode, listening: listening)
    }
}

#Preview("questions · fresh") { QuestionsLaunch(scenario: .questions) }
#Preview("questions · resume") { QuestionsLaunch(scenario: .questionsResume) }
#Preview("questions · offline") { QuestionsLaunch(scenario: .questionsOffline) }
#Preview("privacy") { PrivacyLaunch(scenario: .privacy) }
#endif
