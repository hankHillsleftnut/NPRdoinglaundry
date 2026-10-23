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
    private let scenario: SignInScenario

    init(scenario: SignInScenario) {
        self.scenario = scenario
        _model = State(initialValue: SignInModel.sample(scenario))
    }

    var body: some View {
        SignInScreen(model: model, sampleTaps: true)
            .task {
                // Offline comes back after a few seconds, through the same `watch` the app uses.
                guard scenario == .offline else { return }
                let (changes, continuation) = AsyncStream.makeStream(of: Bool.self)
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    continuation.yield(true)
                    continuation.finish()
                }
                await model.watch(changes)
            }
    }
}

struct SampleTap: Error {}

#Preview("sign in · splash") { SignInLaunch(scenario: .splash) }
#Preview("sign in · returning") { SignInLaunch(scenario: .returning) }
#endif
