//
//  InviteScreens+Launcher.swift
//  The invite pages in the launcher (T02): `-Screen PI1 -State promise` and `-Screen PI2 -State
//  ready`, on sample data. Both ids open the same page; the state decides what it shows.
//
#if DEBUG
import SwiftUI

extension ScreenRegistry {
    static let inviteScreens: [LaunchableScreen] = [
        LaunchableScreen(id: "PI1", states: InviteScenario.pi1.map(\.rawValue)) { arguments in
            AnyView(InviteLaunch(scenario: InviteScenario(rawValue: arguments.state) ?? .promise))
        },
        LaunchableScreen(id: "PI2", states: InviteScenario.pi2.map(\.rawValue)) { arguments in
            AnyView(InviteLaunch(scenario: InviteScenario(rawValue: arguments.state) ?? .ready))
        },
    ]
}

/// The invite page on the sample source for one scenario, the way the app will mount it.
struct InviteLaunch: View {
    @State private var model: InviteModel
    private let scenario: InviteScenario

    init(scenario: InviteScenario) {
        self.scenario = scenario
        _model = State(initialValue: InviteModel.sample(scenario))
    }

    var body: some View {
        InviteScreen(
            model: model,
            sampleTaps: true,
            printStill: scenario == .printing ? 0.5 : nil,
            tear: scenario == .tearing ? 0.4 : 0
        )
    }
}

#Preview("invite · promise") { InviteLaunch(scenario: .promise) }
#Preview("invite · ready") { InviteLaunch(scenario: .ready) }
#Preview("invite · typed") { InviteLaunch(scenario: .typed) }
#Preview("invite · you're in") { InviteLaunch(scenario: .youreIn) }
#endif
