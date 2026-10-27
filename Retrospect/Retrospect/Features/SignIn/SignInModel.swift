//
//  SignInModel.swift
//  PI0: the sign-in page's state. Two looks of one page: the splash for a phone that has never signed
//  in, and "welcome back" for one that has (docs/design/ios-build-notes.md, AC-1 trigger). It owns
//  what is true (signing in, failed, offline) and nothing else; every door is behind
//  `SignInCoordinating`. A dismissed sheet changes nothing; a failure keeps the button and says so.
//
import AuthenticationServices
import Foundation
import Observation

@MainActor @Observable
final class SignInModel {
    /// The splash (first time on this phone) or welcome back (signed in here before).
    enum Look: Equatable {
        case splash, returning
    }

    enum Phase: Equatable {
        case rest
        /// Apple said yes and the server is answering; on welcome back this is "restoring".
        case signingIn
        case failed
    }

    /// Welcome back can become the splash once ("new here? get started", AC-1 `1GY6-0`); never back.
    private(set) var look: Look
    private(set) var phase: Phase
    private(set) var isOnline: Bool
    /// Counts of failures and successes, for the haptics (each fires once per change).
    private(set) var failures = 0
    private(set) var arrivals = 0

    /// Where the page hands on: the stage follows the access state (PL1.9). Contract: the root replaces this
    /// page when this fires. The phase deliberately stays `.signingIn` (the wait holds through the swap and a
    /// second hand-off is ignored); a root that keeps the page mounted must make a new model.
    var onSignedIn: (_ firstName: String?, _ access: Session.AccessState) -> Void = { _, _ in }

    @ObservationIgnored private let coordinator: any SignInCoordinating

    init(look: Look, coordinator: any SignInCoordinating, phase: Phase = .rest, isOnline: Bool = true) {
        self.look = look
        self.coordinator = coordinator
        self.phase = phase
        self.isOnline = isOnline
    }

    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        coordinator.prepare(request)
    }

    /// Apple's sheet closed. Only a usable credential starts the sign-in; a dismissed sheet is silent.
    func appleFinished(_ result: Result<ASAuthorization, any Error>) async {
        guard phase != .signingIn else { return }
        phase = .signingIn
        switch await coordinator.complete(result) {
        case .cancelled:
            phase = .rest
        case .failed:
            phase = .failed
            failures += 1
        case let .signedIn(name, access):
            arrivals += 1
            onSignedIn(name, access)
        }
    }

    /// AC-1's "new here? get started": welcome back becomes the splash, the first-run start (founder,
    /// 27 Oct). From rest or a failure only: while Apple's answer is being checked the page holds still.
    /// The failure goes with the look (it belonged to the welcome-back try); the connection stays.
    func startFresh() {
        guard look == .returning, phase != .signingIn else { return }
        look = .splash
        phase = .rest
    }

    /// AC-1 `1GY6-0` draws the link where the splash has its legal line (`1F53-0`); welcome back has no
    /// legal line in Paper, and the splash it opens carries it.
    var offersNewHere: Bool {
        look == .returning
    }

    /// The link can be pressed when `startFresh` would act (not while signing in).
    var newHereEnabled: Bool {
        phase != .signingIn
    }

    /// Follows the phone's connection: offline, the button rests disabled with the reason.
    func watch(_ changes: AsyncStream<Bool>) async {
        for await online in changes {
            isOnline = online
        }
    }

    func setOnline(_ online: Bool) {
        isOnline = online
    }

    // MARK: Words

    var title: String {
        look == .splash ? Self.splashTitle : "welcome back."
    }

    /// The line under the title. It becomes the wait while signing in.
    var line: String {
        phase == .signingIn ? waitLine : restLine
    }

    /// The line at rest and the wait that replaces it. The page lays out room for the taller of
    /// the two, so the title never moves when one becomes the other.
    var restLine: String {
        look == .splash ? Self.splashLine : "sign in to pick up where you left off."
    }

    var waitLine: String {
        look == .splash ? "signing you in…" : "bringing back your entries and episodes…"
    }

    /// The one line above the button after a failure (the same words on both looks: AC-1's
    /// approved board in Paper and the handoff say "nothing is lost").
    var failure: String? {
        phase == .failed ? Self.failureLine : nil
    }

    static let failureLine = "that didn't work. nothing is lost; try again."

    var buttons: RSignInButtons.State {
        if phase == .signingIn {
            return .pending
        }
        return isOnline ? .rest : .disabled(reason: Self.offlineReason)
    }

    static let offlineReason = "connect to sign in"

    /// The splash's promise and line are "an experiment" (the founder's tag): one place to change them.
    static let splashTitle = "everything about you, finally connected."
    static let splashLine = "retrospect gets to know you, and tells you what it sees."
    static let legal = "by continuing you agree to the terms · privacy"
    static let newHere = "new here? get started"
}
