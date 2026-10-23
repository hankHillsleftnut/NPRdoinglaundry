//
//  LiveJournalRoot.swift
//  APP-ROOT: where the journal (JR-1) is mounted on the person's own data. It hands the page the live
//  journal the platform built for them on sign-in (nil for the moment between sign-in and the store opening,
//  when the page shows its empty canvas) and the person's local day, read again whenever the app comes back
//  or the clock changes, which builds a new page and a new load so yesterday never stays up as "today".
//  The drawer button opens the account page (the one place to sign out) until the drawer (JR-3) is mounted.
//
import SwiftUI

struct LiveJournalRoot: View {
    @Environment(Platform.AppEnvironment.self) private var platform
    @Environment(\.scenePhase) private var scenePhase
    @State private var today = Self.day()
    @State private var account = AccountPresenter()

    var body: some View {
        @Bindable var account = account
        JournalPageContainer(today: today, openDrawer: { [account] in account.isShown = true })
            .environment(\.journalData, platform.journalData)
            .fullScreenCover(isPresented: $account.isShown) {
                LiveAccountPage { account.isShown = false }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    comeBack()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                today = Self.day()
            }
    }

    /// The app is in front again: a new day builds a new page (which loads); the same day refreshes the
    /// live data in place (throttled and quiet, in `LiveJournalData.refresh`).
    private func comeBack() {
        let now = Self.day()
        if now == today {
            Task { await platform.journalData?.refresh() }
        } else {
            today = now
        }
    }

    /// The person's local day, `YYYY-MM-DD`: the same day the repository asks the server for.
    static func day(now: Date = Date(), timeZone: TimeZone = .current) -> String {
        Store.Outbox.day(of: now, in: timeZone)
    }
}

/// Whether the account page is up. A class, so the journal's drawer button (built once with the page) always
/// reaches the same state.
@MainActor @Observable
final class AccountPresenter {
    var isShown = false
}
