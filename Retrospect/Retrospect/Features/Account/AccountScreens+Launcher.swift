//
//  AccountScreens+Launcher.swift
//  P33 in the launcher (T02): `-Screen AC-2 -State nothingWaiting|unsent|sending|stuck|offlineUnsent|
//  updateRequired|done` opens the sheet's state over the account page; `-Screen account` is the page.
//
#if DEBUG
import SwiftUI

enum AccountScenario: String, CaseIterable {
    case nothingWaiting, unsent, sending, stuck, offlineUnsent, updateRequired, done
}

extension ScreenRegistry {
    static let accountScreens: [LaunchableScreen] = [
        LaunchableScreen(id: "AC-2", states: AccountScenario.allCases.map(\.rawValue)) { arguments in
            AnyView(SignOutLaunch(scenario: AccountScenario(rawValue: arguments.state) ?? .nothingWaiting))
        },
        LaunchableScreen(id: "account", states: ["rest"]) { _ in
            AnyView(AccountLaunch())
        },
    ]
}

/// The account page on a sample flow with nothing waiting.
struct AccountLaunch: View {
    @State private var flow = SampleSignOutFlow(unsent: 0)

    var body: some View {
        AccountPage(flow: flow) {}
    }
}

/// The sheet open over the account page, in one state, on a flow with the real timing.
struct SignOutLaunch: View {
    @State private var flow: SampleSignOutFlow
    @State private var open = true
    @Environment(\.dynamicTypeSize) private var typeSize
    private let scenario: AccountScenario

    init(scenario: AccountScenario) {
        self.scenario = scenario
        let flow = switch scenario {
        case .nothingWaiting: SampleSignOutFlow(unsent: 0)
        case .unsent: SampleSignOutFlow(unsent: 2)
        case .sending: SampleSignOutFlow(unsent: 2, state: .sending(remaining: 2))
        case .stuck: SampleSignOutFlow(unsent: 2, state: .stuck(remaining: 2, reason: .failed))
        case .offlineUnsent: SampleSignOutFlow(unsent: 1, state: .stuck(remaining: 1, reason: .offline))
        case .updateRequired: SampleSignOutFlow(unsent: 2, state: .stuck(remaining: 2, reason: .updateRequired))
        case .done: SampleSignOutFlow(unsent: 0, state: .done)
        }
        _flow = State(initialValue: flow)
    }

    var body: some View {
        RSheetHost {
            VStack(spacing: RDimension.space0) {
                RTopBar(variant: .settings(title: "account", back: {}))
                Spacer()
            }
            .background(RColor.backgroundCanvas)
            .rSheet(isPresented: $open, detent: SignOutSheet.detent(for: typeSize)) { SignOutSheet(flow: flow) { open = false } }
        }
    }
}

#Preview("sign out · nothing waiting") { SignOutLaunch(scenario: .nothingWaiting) }
#Preview("sign out · unsent") { SignOutLaunch(scenario: .unsent) }
#Preview("sign out · stuck") { SignOutLaunch(scenario: .stuck) }
#endif
