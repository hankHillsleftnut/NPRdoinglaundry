//
//  InviteScreens+Launcher.swift
//  The invite gate in the launcher (T02): `-Screen PI1 -State promise` and the rest of `InviteScenario.pi1`,
//  on sample data. (PI2's states join in its own PR.)
//
#if DEBUG
import SwiftUI

extension ScreenRegistry {
    static let inviteScreens: [LaunchableScreen] = [
        LaunchableScreen(id: "PI1", states: InviteScenario.pi1.map(\.rawValue)) { arguments in
            AnyView(InviteLaunch(scenario: InviteScenario(rawValue: arguments.state) ?? .promise))
        },
    ]
}

/// The invite page on the sample source for one scenario, the way the app will mount it.
struct InviteLaunch: View {
    @State private var model: InviteModel

    init(scenario: InviteScenario) {
        _model = State(initialValue: InviteModel.sample(scenario))
    }

    var body: some View {
        InviteScreen(model: model, sampleTaps: true)
    }
}

#Preview("invite · promise") { InviteLaunch(scenario: .promise) }
#Preview("invite · typed") { InviteLaunch(scenario: .typed) }
#Preview("invite · used") { InviteLaunch(scenario: .used) }
#endif
