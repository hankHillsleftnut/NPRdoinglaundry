//
//  LiveAccountPage.swift
//  APP-ROOT / P33: the account page on the real platform. It reads how many entries haven't sent before the
//  page shows (so the sheet opens with the truth), then hands the sign-out sheet the live flow.
//  DG.6.mount: the page's "send a report" uses the live sender on the person's open outbox, rebuilt when that
//  outbox changes (another sign-in) and gone when it closes, so the row is never a dead control.
//  P31.delete: "delete account…" runs the live deletion (Apple's own sheet for a fresh code, then the account door).
//
import SwiftUI

struct LiveAccountPage: View {
    let back: () -> Void
    @Environment(Platform.AppEnvironment.self) private var platform
    @State private var flow: LiveSignOutFlow?
    @State private var deletion: LiveDeleteAccountFlow?
    @State private var reportSender: Platform.Diagnostics.LiveReportSender?

    var body: some View {
        Group {
            if let flow {
                AccountPage(flow: flow, deletion: deletion, back: back)
            } else {
                RColor.backgroundCanvas.ignoresSafeArea()
            }
        }
        .environment(\.reportSender, reportSender)
        .onChange(of: reportKey, initial: true) {
            reportSender = LiveReportMount.sender(for: platform)
        }
        .task {
            if deletion == nil {
                deletion = LiveDeleteAccountFlow.make(platform: platform, apple: Session.SystemAppleReauthorizer())
            }
            if flow == nil {
                flow = await LiveSignOutFlow.make(platform: platform)
            }
        }
    }

    /// What the sender is built from: which outbox is open, and whether someone is signed in.
    private var reportKey: ReportKey {
        ReportKey(outbox: platform.outbox.map(ObjectIdentifier.init), signedIn: LiveReportMount.account(in: platform.sessionState) != nil)
    }

    private struct ReportKey: Equatable {
        let outbox: ObjectIdentifier?
        let signedIn: Bool
    }
}
