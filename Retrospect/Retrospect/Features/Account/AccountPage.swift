//
//  AccountPage.swift
//  P33: the one place to sign out in Beta 1. A minimal account page (decision 1/2): a back bar, who is
//  signed in, and ONE sign-out block (ST-9, Paper `1GU5-0`): a full-width raised button with the
//  sign-out glyph and its caption. The rest of ST-9 (plan, restore, delete account) belongs to later
//  PRs; delete account is App Store 5.1.1(v) and must exist before submission, not before Beta 1.
//  The sign-out button opens the AC-2 sheet; the sheet asks first when entries haven't sent.
//  DG.6.mount: under it, the "send a report" group (DiagnosticsSettingsGroup, plan section 3: "the account
//  page has it too"), shown only when a report sender is in the environment (decision 4: no dead control).
//  No Paper drawing: the group is DG.6's own rows, 24 below the sign-out block (between groups).
//
import SwiftUI

struct AccountPage: View {
    let flow: any SignOutFlowing
    var provider = "apple"
    let back: () -> Void
    @State private var confirming = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.reportSender) private var reportSender

    var body: some View {
        RSheetHost {
            VStack(spacing: RDimension.space0) {
                RTopBar(variant: .settings(title: "account", back: back))
                ScrollView {
                    VStack(spacing: RDimension.space6) {
                        signOutBlock
                        if reportSender != nil {
                            DiagnosticsSettingsGroup()
                        }
                    }
                    .padding(.horizontal, RDimension.spaceScreenMargin)
                    .padding(.top, RDimension.space6)
                }
            }
            .background(RColor.backgroundCanvas)
            .rSheet(isPresented: $confirming, detent: SignOutSheet.detent(for: typeSize)) {
                SignOutSheet(flow: flow, provider: provider) { confirming = false }
            }
            .sendReport(bottomInset: RDimension.spaceScreenMargin)
        }
        .accessibilityIdentifier("screen.account")
    }

    private var signOutBlock: some View {
        VStack(spacing: RDimension.space2) {
            Button { confirming = true } label: {
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
}
