//
//  AccountScreens+Launcher.swift
//  P33 in the launcher (T02): `-Screen AC-2 -State nothingWaiting|unsent|sending|stuck|offlineUnsent|
//  updateRequired|done` opens the sheet's state over the account page; `-Screen account -State rest|unsent|
//  offline` is the page, from which the whole flow runs on a tap (sign out -> sheet -> send -> close), and
//  "send a report" opens the report sheet on a sample sender (DG.6.mount).
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
        LaunchableScreen(id: "account-delete", states: DeleteAccountScenario.allCases.map(\.rawValue)) { arguments in
            AnyView(DeleteAccountLaunch(scenario: DeleteAccountScenario(rawValue: arguments.state) ?? .rest))
        },
    ]
}

/// P31.delete in the launcher (`-Screen account-delete -State <name>`): the dialog at rest, with unsent entries,
/// pending, with its error line, offline, and the goodbye. "delete my account" runs the sample flow from there.
enum DeleteAccountScenario: String, CaseIterable {
    case rest, unsent, pending, error, offline, goodbye
}

/// The account page with the delete dialog (or the goodbye) in one state, on a sample flow.
struct DeleteAccountLaunch: View {
    @State private var signOut = SampleSignOutFlow(unsent: 0)
    @State private var deletion: SampleDeleteAccountFlow

    init(scenario: DeleteAccountScenario) {
        let deletion = switch scenario {
        case .rest: SampleDeleteAccountFlow(state: .asking)
        case .unsent: SampleDeleteAccountFlow(unsent: 2, state: .asking)
        case .pending: SampleDeleteAccountFlow(state: .pending)
        case .error: SampleDeleteAccountFlow(script: .fails, state: .failed(.notNow))
        case .offline: SampleDeleteAccountFlow(isOnline: false, state: .asking)
        case .goodbye: SampleDeleteAccountFlow(state: .goodbye)
        }
        _deletion = State(initialValue: deletion)
    }

    var body: some View {
        AccountPage(flow: signOut, deletion: deletion) {}
    }
}

/// The account page's flows: nothing waiting, two unsent that send, two unsent that get stuck offline.
enum AccountPageScenario: String, CaseIterable {
    case rest, unsent, offline
}

/// The account page on a sample flow; tapping "sign out" runs the whole flow with live timing. "send a
/// report" opens the sheet on a sample sender (offline in the offline state), which sends nothing anywhere.
struct AccountLaunch: View {
    @State private var flow: SampleSignOutFlow
    @State private var reportSender: SampleReportSender
    @State private var deletion: SampleDeleteAccountFlow

    init(scenario: AccountPageScenario = .rest) {
        _deletion = State(initialValue: SampleDeleteAccountFlow(unsent: scenario == .rest ? 0 : 2, isOnline: scenario != .offline))
        let flow = switch scenario {
        case .rest: SampleSignOutFlow(unsent: 0)
        case .unsent: SampleSignOutFlow(unsent: 2)
        case .offline: SampleSignOutFlow(unsent: 2, script: .offline)
        }
        _flow = State(initialValue: flow)
        _reportSender = State(initialValue: SampleReportSender(scenario: scenario == .offline ? .offline : .online))
    }

    var body: some View {
        AccountPage(flow: flow, deletion: deletion) {}
            .environment(\.reportSender, reportSender)
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
#Preview("delete account · rest") { DeleteAccountLaunch(scenario: .rest) }
#Preview("delete account · goodbye") { DeleteAccountLaunch(scenario: .goodbye) }
#endif
