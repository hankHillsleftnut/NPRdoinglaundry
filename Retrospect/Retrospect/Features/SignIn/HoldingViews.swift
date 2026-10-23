//
//  HoldingViews.swift
//  APP-ROOT: the two plain pages the root can stand on when the journal must not show: the store could not
//  be opened ("try again", never a blank page), and the account is paused. No Paper drawing for either: built
//  from the design system's parts and the app's plain words (the founder's review list names both).
//
import SwiftUI

/// The signed-in person's journal could not be opened on this phone.
struct StoreFailedView: View {
    let retry: () -> Void
    static let message = "couldn't open your journal on this phone."

    var body: some View {
        VStack(spacing: RDimension.space5) {
            Text(Self.message)
                .rText(.bodyReading)
                .foregroundStyle(RColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            RButton(title: "try again", variant: .secondary, action: retry)
                .accessibilityIdentifier("store.retry")
        }
        .padding(.horizontal, RDimension.spaceScreenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RColor.backgroundCanvas.ignoresSafeArea())
        .rErrorHaptic(isFailing: true)
        .onAppear { AccessibilityNotification.Announcement(Self.message).post() }
        .accessibilityIdentifier("newapp.storefailed")
    }
}

/// The account is paused (contract 00: `suspended`). The one thing to do is sign out; with entries not sent
/// it asks first, like every Log Out, and erases only on the person's yes.
struct PausedView: View {
    @Environment(Platform.AppEnvironment.self) private var platform
    @State private var unsent: Int?
    @State private var working = false
    static let message = "your account is paused."

    var body: some View {
        VStack(spacing: RDimension.space5) {
            Text(Self.message)
                .rText(.bodyReading)
                .foregroundStyle(RColor.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            RButton(title: "sign out", variant: .secondary, status: working ? .pending : .rest) { signOut(confirmed: false) }
                .accessibilityIdentifier("paused.signout")
        }
        .padding(.horizontal, RDimension.spaceScreenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RColor.backgroundCanvas.ignoresSafeArea())
        .confirmationDialog(
            unsent.map { Self.unsentTitle($0) } ?? "", isPresented: Binding(get: { unsent != nil }, set: { if !$0 { unsent = nil } }),
            titleVisibility: .visible
        ) {
            Button("sign out and erase them", role: .destructive) { signOut(confirmed: true) }
            Button("stay signed in", role: .cancel) {}
        }
        .accessibilityIdentifier("newapp.paused")
    }

    static func unsentTitle(_ count: Int) -> String {
        count == 1 ? "1 entry hasn't sent yet. signing out erases it from this phone." : "\(count) entries haven't sent yet. signing out erases them from this phone."
    }

    private func signOut(confirmed: Bool) {
        guard !working else { return }
        working = true
        Task {
            if case let .hasUnsent(count) = await platform.logOut(confirmed: confirmed) {
                unsent = count
            }
            working = false
        }
    }
}
