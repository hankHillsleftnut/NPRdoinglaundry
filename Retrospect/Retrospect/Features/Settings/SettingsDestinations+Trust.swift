//
//  SettingsDestinations+Trust.swift
//  V2.settings, second half (ST-5 … ST-9): owned by the second settings builder, so the two halves
//  never edit the same file. Each case returns its page once that page is built; until then nil,
//  and ST-1's row for it does nothing (listed in the PR). Account already has a page (P33's
//  AccountPage, the partial ST-9), on a sample sign-out flow. Built: ST-6 how straight, ST-8 what
//  i've learned (B1), ST-5 privacy, ST-7 voice and listening (B2).
//
import SwiftUI

extension SettingsDestinations {
    static func trust(_ page: SettingsRoute, in context: Context) -> AnyView? {
        switch page {
        case .account:
            AnyView(SettingsAccountPage(flow: context.signOut, back: context.back))
        case .privacy:
            trustData(context).map { AnyView(SettingsPrivacyPage(data: $0, back: context.back)) }
        case .voice:
            trustData(context).map { AnyView(VoiceListeningPage(data: $0, back: context.back)) }
        case .howStraight:
            trustData(context).map { AnyView(HowStraightPage(data: $0, back: context.back)) }
        case .learned:
            // too early / off are undrawn (ST-D25): the row stays inert rather than open an empty page
            trustData(context).flatMap { data in
                data.learned.state == .learning ? AnyView(LearnedPage(data: data, back: context.back)) : nil
            }
        case .dailyBrief, .sources, .source:
            // the first half's pages (SettingsDestinations.first)
            nil
        }
    }

    /// The second half's values, when the settings data carries them (the sample does; live data will).
    private static func trustData(_ context: Context) -> (any Flows.SettingsData & Flows.SettingsTrustData)? {
        context.data as? any Flows.SettingsData & Flows.SettingsTrustData
    }
}

/// The existing account page (#173/#184/#188) on the host's sign-out flow, or on a sample flow with
/// nothing waiting when the host has none.
private struct SettingsAccountPage: View {
    let flow: (any SignOutFlowing)?
    let back: () -> Void
    @State private var sample = SampleSignOutFlow(unsent: 0)

    var body: some View {
        AccountPage(flow: flow ?? sample, back: back)
            .toolbar(.hidden, for: .navigationBar)
    }
}
