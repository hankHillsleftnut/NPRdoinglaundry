//
//  LiveInviteSource.swift
//  The invite screens on the real doors: `Session.InviteCenter` (check, tear, waitlist) and
//  `Session.AppleSignIn`. Built by the app root once it exists (PL1.8); until then the screens run
//  on `SampleInviteSource` through the launcher.
//
import AuthenticationServices
import Foundation

@MainActor
final class LiveInviteSource: InviteSource {
    private let center: Session.InviteCenter
    private let apple: Session.AppleSignIn
    private let onBegin: @MainActor () -> Void
    private let readPendingCode: @Sendable () async -> String?

    init(
        center: Session.InviteCenter,
        apple: Session.AppleSignIn,
        pendingCode: @escaping @Sendable () async -> String? = { nil },
        onBegin: @escaping @MainActor () -> Void
    ) {
        self.center = center
        self.apple = apple
        self.onBegin = onBegin
        readPendingCode = pendingCode
    }

    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        apple.prepare(request)
    }

    func complete(_ result: Result<ASAuthorization, any Error>) async -> InviteSignIn {
        do {
            let outcome = try await apple.complete(result)
            return .signedIn(firstName: outcome.firstName, access: outcome.access)
        } catch let error as Session.SignInError where error == .cancelled {
            return .cancelled
        } catch {
            return .failed
        }
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
