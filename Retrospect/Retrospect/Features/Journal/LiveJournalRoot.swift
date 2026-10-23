//
//  LiveJournalRoot.swift
//  PL5.2: where the journal (JR-1) is mounted on the person's own data. The app root shows this
//  where the signed-in, unlocked person lands: it hands the page the live journal the platform
//  built for them on sign-in (nil for the moment between sign-in and the store opening, when
//  the page shows its empty canvas) and the person's local day. The day is read again whenever
//  the app comes back or the clock changes (midnight, a new time zone), which builds a new page
//  and a new load, so yesterday's thread never stays up as "today".
//
import SwiftUI

struct LiveJournalRoot: View {
    @Environment(Platform.AppEnvironment.self) private var platform
    @Environment(\.scenePhase) private var scenePhase
    @State private var today = Self.day()

    var body: some View {
        JournalPageContainer(today: today)
            .environment(\.journalData, platform.journalData)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    today = Self.day()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                today = Self.day()
            }
    }

    /// The person's local day, `YYYY-MM-DD`: the same day the repository asks the server for.
    static func day(now: Date = Date(), timeZone: TimeZone = .current) -> String {
        Store.Outbox.day(of: now, in: timeZone)
    }
}
