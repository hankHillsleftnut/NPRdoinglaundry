//
//  FirstRunScreens+Launcher.swift
//  First run's screens in the launcher (T02): `-Screen first-run -State privacy` opens ON-5 on
//  sample data (a silent ~8 s read-aloud, then the page moves on). Nothing is mounted in the app yet (FR.root): leaving the page shows a
//  quiet line saying which way it went.
//
#if DEBUG
import SwiftUI

extension ScreenRegistry {
    static let firstRunScreens: [LaunchableScreen] = [
        LaunchableScreen(id: "first-run", states: PrivacyScenario.allCases.map(\.rawValue)) { arguments in
            AnyView(PrivacyLaunch(scenario: PrivacyScenario(rawValue: arguments.state) ?? .privacy))
        },
    ]
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

#Preview("privacy") { PrivacyLaunch(scenario: .privacy) }
#endif
