//
//  FirstRunScreens+Launcher.swift
//  First run's screens in the launcher (T02): `-Screen first-run -State questions|questions-resume|
//  questions-offline|questions-still|questions-quick` opens ON-3–9 on `SampleFirstRunData` in that
//  scenario (still / quick: Paper's listening and quick-answers frames); `-State privacy` opens ON-5
//  on a silent ~8 s sample read-aloud, after which the page moves on; `-State connect|connect-3of6`
//  opens ON-6 on the sample sources (calendar connected, or all three); `-State getting-ready|
//  getting-ready-still` opens ON-10 on the sample listening and episode; `-State paywall|paywall-still|
//  paywall-nudge` opens ON-12 on the sample (dummy) plans. Nothing is mounted in the
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
                + GettingReadyScenario.allCases.map(\.rawValue) + PaywallScenario.allCases.map(\.rawValue)
        ) { arguments in
            if let privacy = PrivacyScenario(rawValue: arguments.state) {
                return AnyView(PrivacyLaunch(scenario: privacy))
            }
            if let connect = ConnectScenario(rawValue: arguments.state) {
                return AnyView(ConnectLaunch(scenario: connect))
            }
            if let gettingReady = GettingReadyScenario(rawValue: arguments.state) {
                return AnyView(GettingReadyLaunch(scenario: gettingReady))
            }
            if let paywall = PaywallScenario(rawValue: arguments.state) {
                return AnyView(PaywallLaunch(scenario: paywall))
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

/// ON-12 on the sample plans. `paywall`: a plan moves on (a quiet line stands in for first home until
/// the flow step lands); `paywall-still`: the same frame, held for the 1:1 comparison (taps stay put);
/// `paywall-nudge`: the still, with the mini-player's play pressed for the nudge film (once, then three quick).
struct PaywallLaunch: View {
    let scenario: PaywallScenario
    @State private var left: PaywallModel.Choice?
    @State private var model: PaywallModel?

    var body: some View {
        if let left {
            Text("paywall done · \(left == .yearly ? "yearly" : "monthly")")
                .rText(.textMd)
                .foregroundStyle(RColor.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RColor.backgroundCanvas)
                .accessibilityIdentifier("paywall.left")
        } else if let model {
            PaywallPage(model: model)
                .task {
                    guard scenario == .paywallNudge else { return }
                    for wait in PaywallScenario.nudgeFilm {
                        try? await Task.sleep(for: wait)
                        model.nudge()
                    }
                }
        } else {
            RColor.backgroundCanvas
                .ignoresSafeArea()
                .onAppear {
                    // the held states answer "cancelled", so a stray tap keeps the plans on screen
                    let paywall = SamplePaywall(answer: scenario == .paywall ? .subscribed : .cancelled)
                    model = PaywallModel(paywall: paywall) { choice in
                        left = choice
                    }
                }
        }
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
#Preview("questions · still (Paper 1F6C-0)") { QuestionsLaunch(scenario: .questionsStill) }
#Preview("questions · quick answers") { QuestionsLaunch(scenario: .questionsQuick) }
#Preview("privacy") { PrivacyLaunch(scenario: .privacy) }
#Preview("connect") { ConnectLaunch(scenario: .connect) }
#Preview("paywall") { PaywallLaunch(scenario: .paywall) }
#endif
