//
//  AccountScreens+Launcher.swift
//  P33 in the launcher (T02): `-Screen AC-2 -State nothingWaiting|unsent|sending|stuck|offlineUnsent|
//  updateRequired|done` opens the sheet's state over the account page; `-Screen account -State rest|unsent|
//  offline` is the page, from which the whole flow runs on a tap (sign out -> sheet -> send -> close).
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
        LaunchableScreen(id: "account", states: AccountPageScenario.allCases.map(\.rawValue)) { arguments in
            AnyView(AccountLaunch(scenario: AccountPageScenario(rawValue: arguments.state) ?? .rest))
        },
    ]
}

/// The account page's flows: nothing waiting, two unsent that send, two unsent that get stuck offline.
enum AccountPageScenario: String, CaseIterable {
    case rest, unsent, offline
}

/// The account page on a sample flow; tapping "sign out" runs the whole flow with live timing.
struct AccountLaunch: View {
    @State private var flow: SampleSignOutFlow

    init(scenario: AccountPageScenario = .rest) {
        let flow = switch scenario {
        case .rest: SampleSignOutFlow(unsent: 0)
        case .unsent: SampleSignOutFlow(unsent: 2)
        case .offline: SampleSignOutFlow(unsent: 2, script: .offline)
        }
        _flow = State(initialValue: flow)
    }

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
