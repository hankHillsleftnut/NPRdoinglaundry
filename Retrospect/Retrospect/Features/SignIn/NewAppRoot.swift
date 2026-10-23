//
//  NewAppRoot.swift
//  PL1.4b / PL5.2: the app's root on the new backend. What shows comes from the new session's state
//  and nothing else: a blank page while it is still being read (or the phone is locked), the sign-in
//  screen when nobody is signed in, the journal when someone is. If the signed-in person's store can't
//  be opened, it says so and offers a retry, instead of a page that never loads.
//
import SwiftUI

struct NewAppRoot: View {
    @Environment(Platform.AppEnvironment.self) private var platform

    var body: some View {
        Group {
            switch platform.sessionState {
            case .signedIn:
                if platform.storeOpenFailed {
                    StoreFailedView { platform.retryOpeningStore() }
                } else {
                    LiveJournalRoot()
                }
            case let .signedOut(_, reason):
                SignInGateView(endedByServer: reason == .revoked)
            case .locked, nil:
                RColor.backgroundCanvas.ignoresSafeArea()
            }
        }
        .animation(RMotion.snappy, value: platform.sessionState)
    }
}

private struct StoreFailedView: View {
    let retry: () -> Void

    var body: some View {
        VStack(spacing: RDimension.space4) {
            Text("couldn't open your journal on this phone.")
                .rText(.bodyReading)
                .foregroundStyle(RColor.textPrimary)
                .multilineTextAlignment(.center)
            Button("try again", action: retry)
                .rText(.bodyReading)
                .accessibilityIdentifier("store.retry")
        }
        .padding(.horizontal, RDimension.spaceScreenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RColor.backgroundCanvas)
    }
}
