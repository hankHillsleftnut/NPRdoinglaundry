//
//  SettingsDestinations+Trust.swift
//  V2.settings, second half (ST-5 … ST-9): owned by the second settings builder, so the two halves
//  never edit the same file. Each case returns its page once that page is built; until then nil,
//  and ST-1's row for it does nothing (listed in the PR). Account already has a page (P33's
//  AccountPage, the partial ST-9), on a sample sign-out flow.
//
import SwiftUI

extension SettingsDestinations {
    static func trust(_ page: SettingsRoute, in context: Context) -> AnyView? {
        switch page {
        case .account:
            AnyView(SettingsAccountPage(back: context.back))
        default:
            nil
        }
    }
}

/// The existing account page (#173/#184/#188) on a sample flow with nothing waiting.
private struct SettingsAccountPage: View {
    let back: () -> Void
    @State private var flow = SampleSignOutFlow(unsent: 0)

    var body: some View {
        AccountPage(flow: flow, back: back)
            .toolbar(.hidden, for: .navigationBar)
    }
}
