//
//  SignInScreens+Launcher.swift
//  PI0 in the launcher (T02): `-Screen PI0 -State splash`, and `-Screen AC-1` for the returning look,
//  on sample data.
//
#if DEBUG
import SwiftUI

extension ScreenRegistry {
    static let signInScreens: [LaunchableScreen] = [
        LaunchableScreen(id: "PI0", states: SignInScenario.allCases.map(\.rawValue)) { arguments in
            AnyView(SignInLaunch(scenario: SignInScenario(rawValue: arguments.state) ?? .splash))
        },
        LaunchableScreen(id: "AC-1", states: SignInScenario.allCases.map(\.rawValue)) { arguments in
            AnyView(SignInLaunch(scenario: SignInScenario(rawValue: arguments.state) ?? .returning))
        },
    ]
}

/// The sign-in page on the sample coordinator, the way the app will mount it.
struct SignInLaunch: View {
    @State private var model: SignInModel

    init(scenario: SignInScenario) {
        _model = State(initialValue: SignInModel.sample(scenario))
    }

    var body: some View {
        SignInScreen(model: model, sampleTaps: true)
    }
}

struct SampleTap: Error {}

#Preview("sign in · splash") { SignInLaunch(scenario: .splash) }
#Preview("sign in · returning") { SignInLaunch(scenario: .returning) }
#endif
