//
//  LiveInviteSource.swift
//  The invite screens on the real doors: `Session.InviteCenter` (check, tear, waitlist) and
//  `Session.AppleSignIn`. Built by the app root once it exists (PL1.8); until then the screens run
//  on `SampleInviteSource` through the launcher.
//
import Foundation

@MainActor
final class LiveInviteSource: InviteSource {
    private let center: Session.InviteCenter
    private let onBegin: @MainActor () -> Void
    private let readPendingCode: @Sendable () async -> String?

    init(
        center: Session.InviteCenter,
        pendingCode: @escaping @Sendable () async -> String? = { nil },
        onBegin: @escaping @MainActor () -> Void
    ) {
        self.center = center
        self.onBegin = onBegin
        readPendingCode = pendingCode
    }

    func ticketAfterSignIn() async -> Session.Ticket {
        await center.afterSignIn()
        return center.ticket
    }

    func type(code: String) async -> Session.Ticket {
        await center.type(code: code)
        return center.ticket
    }

    func beginTear() {
        center.beginTear()
    }

    func tear() async -> Session.TearOutcome {
        await center.tear()
    }

    func joinWaitlist(reason: String?) async -> Bool {
        await (try? center.joinWaitlist(reason: reason)) ?? false
    }

    func pendingCode() async -> String? {
        await readPendingCode()
    }

    func begin() {
        onBegin()
    }
}
