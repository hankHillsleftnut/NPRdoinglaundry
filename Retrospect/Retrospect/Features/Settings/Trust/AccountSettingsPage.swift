//
//  AccountSettingsPage.swift
//  V2.settings · ST-9 account (Paper 1GU5-0), the whole page as drawn, built BESIDE the shipping
//  AccountPage (Features/Account, on the release path with live sign-out): the integrator held that
//  lease (ST-D27), so nothing there changes. The W4 wiring PR folds this into AccountPage under review,
//  with delete wired to the live deletion. Dark: reachable only from the launcher and ST-1's stack.
//  "your plan": the plan and when it renews (information, not a control); "manage subscription ↗" and
//  "restore purchases" are inert and say "not available yet" (ST-D26, decision 7). Sign out opens the
//  built AC-2 sheet on a sample flow. "delete account…" sits alone at the bottom and opens the dialog
//  with provisional words (ST-D26); nothing after it is drawn, so confirming closes it.
//
import SwiftUI

struct AccountSettingsPage: View {
    let data: any Flows.SettingsTrustData
    let flow: any SignOutFlowing
    var provider = "apple"
    let back: () -> Void
    @State private var signingOut = false
    @State private var deleting: Bool
    @State private var status = RDialog.Status.rest
    @Environment(\.dynamicTypeSize) private var typeSize

    init(
        data: any Flows.SettingsTrustData,
        flow: any SignOutFlowing,
        deleting: Bool = false,
        back: @escaping () -> Void
    ) {
        self.data = data
        self.flow = flow
        self.back = back
        _deleting = State(initialValue: deleting)
    }

    var body: some View {
        RSheetHost {
            SettingsPageFrame(title: "account", back: back) {
                SettingsLabelledGroup(label: "your plan") {
                    RSettingsGroup {
                        if let plan = data.plan {
                            // information only: Paper draws no trailing part, so it isn't a button
                            SettingsControlFrame(title: plan.name, subline: Self.renewal(plan)) { EmptyView() }
                            RSettingsRow(title: "manage subscription", subline: "in apple settings", trailing: .external)
                                .accessibilityHint("not available yet")
                                .accessibilityIdentifier("account.manage")
                        }
                        // always there: whoever sees no plan here is who needs it (the no-plan look is undrawn, ST-D26)
                        RSettingsRow(title: "restore purchases", trailing: .none)
                            .accessibilityHint("not available yet")
                            .accessibilityIdentifier("account.restore")
                    }
                }
                signOutBlock
                    // Paper 1GUH-0: 24 more above the sign-out block, inside the margin
                    .padding(.top, RDimension.space6)
                    .padding(.horizontal, RDimension.spaceScreenMargin)
            } danger: {
                RSettingsRow(
                    title: "delete account…",
                    subline: "your entries, episodes and everything retro knows",
                    symbol: "exclamationmark.circle",
                    trailing: .none,
                    danger: true
                ) {
                    status = .rest
                    deleting = true
                }
                .accessibilityIdentifier("account.delete")
            }
            .background {
                Color.clear.rSheet(isPresented: $signingOut, detent: SignOutSheet.detent(for: typeSize)) {
                    SignOutSheet(flow: flow, provider: provider) { signingOut = false }
                }
            }
            .rDialog(isPresented: $deleting) {
                RDialog(
                    title: "delete your account?",
                    line: "this removes your entries, episodes and everything retro knows. it can't be undone.",
                    confirmTitle: "delete account",
                    status: status
                ) {
                    Task { await confirmDelete() }
                } cancel: {
                    deleting = false
                }
            }
        }
        .accessibilityIdentifier("screen.settings.account")
    }

    /// Paper 1GUK-0 / 1GUJ-0: the full-width raised sign-out button and its caption (as AccountPage draws it).
    private var signOutBlock: some View {
        VStack(spacing: RDimension.space2) {
            Button { signingOut = true } label: {
                HStack(spacing: RDimension.space2) {
                    RSymbol(name: "rectangle.portrait.and.arrow.right", tint: RColor.iconDefault)
                    Text("sign out")
                        .rText(.bodyMedium)
                        .foregroundStyle(RColor.textPrimary)
                }
                .frame(maxWidth: .infinity, minHeight: RDimension.sizeRowDefault)
                .padding(.horizontal, RDimension.space4)
                .rRaised(RDimension.radiusControl)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("account.signout")
            Text("signed in with \(provider). your entries stay; sign back in any time.")
                .rText(.label)
                .foregroundStyle(RColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// "renews on 3 march · $239.99"
    static func renewal(_ plan: Flows.Settings.Plan) -> String {
        let style = Date.FormatStyle(locale: Locale(identifier: "en_US_POSIX"), calendar: Calendar(identifier: .gregorian))
        let day = plan.renewsOn.formatted(style.day(.defaultDigits))
        let month = plan.renewsOn.formatted(style.month(.wide)).lowercased()
        return "renews on \(day) \(month) · \(plan.price)"
    }

    private func confirmDelete() async {
        // a second tap before the dialog re-renders does nothing
        guard status != .pending else { return }
        status = .pending
        do {
            try await data.deleteAccount()
            status = .rest
            deleting = false
        } catch {
            // provisional words, as the RDialog gallery's (ST-D26)
            status = .error(message: "retro couldn't be reached. try again.")
        }
    }
}

#if DEBUG
#Preview("ST-9 account") {
    AccountSettingsPage(data: SampleSettings(), flow: SampleSignOutFlow(unsent: 0), back: {})
}
#endif
