import AuthenticationServices
import Foundation
@testable import Retrospect
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SignInCoordinatorTests {
    /// Apple's side, with live timing: `complete` waits until the test lets the server answer.
    @MainActor
    private final class SlowApple: Session.AppleSigningIn {
        var answer: Result<Session.SignInOutcome, any Error> = .success(
            Session.SignInOutcome(userID: "user-a", firstName: "sam", isNew: true, access: .waitlisted)
        )
        private(set) var prepares = 0
        private(set) var completes = 0
        private var waiting: CheckedContinuation<Void, Never>?
        var holds = false

        func prepare(_: ASAuthorizationAppleIDRequest) { prepares += 1 }

        func complete(_: Result<ASAuthorization, any Error>) async throws -> Session.SignInOutcome {
            completes += 1
            if holds {
                await withCheckedContinuation { waiting = $0 }
            }
            return try answer.get()
        }

        func release() {
            waiting?.resume()
            waiting = nil
        }
    }

    private struct AppleBroke: Error {}

    private func coordinator(_ apple: SlowApple) -> Session.SignInCoordinator {
        Session.SignInCoordinator(apple: apple, log: Platform.Log.Recorder())
    }

    private func settle(_ condition: () -> Bool) async {
        for _ in 0 ..< 200 where !condition() {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(2))
        }
    }

    @Test("signing in shows signingIn while the server is asked, then idle with the outcome; the session takes over from there")
    func signingInThenIdle() async {
        let apple = SlowApple()
        apple.holds = true
        let c = coordinator(apple)

        c.finish(.failure(AppleBroke()))
        await settle { c.phase == .signingIn }
        #expect(c.phase == .signingIn)

        apple.release()
        await settle { c.phase == .idle }
        #expect(c.phase == .idle)
        #expect(c.outcome?.userID == "user-a" && c.outcome?.access == .waitlisted)
    }

    @Test("a second tap while a sign-in is running does nothing")
    func aSecondTapIsIgnored() async {
        let apple = SlowApple()
        apple.holds = true
        let c = coordinator(apple)
        c.finish(.failure(AppleBroke()))
        await settle { c.phase == .signingIn }

        c.finish(.failure(AppleBroke()))
        await Task.yield()
        apple.release()
        await settle { c.phase == .idle }

        #expect(apple.completes == 1)
    }

    @Test("a dismissed Apple sheet is quiet: idle, no failure")
    func cancelledIsQuiet() async {
        let apple = SlowApple()
        apple.answer = .failure(Session.SignInError.cancelled)
        let c = coordinator(apple)

        await c.complete(.failure(AppleBroke()))

        #expect(c.phase == .idle)
        #expect(c.outcome == nil)
    }

    @Test("failures: the server's words pass through, a refused save asks to unlock, the rest is a plain try again; a new try starts clean")
    func failures() async {
        let apple = SlowApple()
        let c = coordinator(apple)

        apple.answer = .failure(Backend.Failure(.inviteRequired, message: "you need an invite."))
        await c.complete(.failure(AppleBroke()))
        #expect(c.phase == .failed(Flows.Failure(.inviteRequired, message: "you need an invite.")))

        apple.answer = .failure(Backend.Failure(.offline))
        await c.complete(.failure(AppleBroke()))
        #expect(c.phase == .failed(Flows.Failure(.network)))

        apple.answer = .failure(Session.KeychainError(status: -25308))
        await c.complete(.failure(AppleBroke()))
        if case let .failed(failure) = c.phase {
            #expect(failure.message?.contains("unlock") == true)
        } else {
            Issue.record("expected a failure")
        }

        apple.answer = .failure(Session.SignInError.notPrepared)
        await c.complete(.failure(AppleBroke()))
        #expect(c.phase == .failed(Flows.Failure(.unknown)))

        c.dismissFailure()
        #expect(c.phase == .idle)
    }
}
