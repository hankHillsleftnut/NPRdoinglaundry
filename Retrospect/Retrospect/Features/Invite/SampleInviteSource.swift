//
//  SampleInviteSource.swift
//  The invite screens on invented data (UI4.0): every door answers from the scenario, on an
//  injected clock, with no network. "Never finishes" is a task that never resolves.
//
import AuthenticationServices
import Foundation

@MainActor
final class SampleInviteSource: InviteSource {
    struct Script {
        var signIn: InviteSignIn = .signedIn(firstName: SampleInvite.firstName, access: .waitlisted)
        var afterSignIn: Session.Ticket = .printing(SampleInvite.face)
        var tear: Session.TearOutcome? = .yours(SampleInvite.youreIn)
        var typedNeverFinishes = false
    }

    private let script: Script
    private let sleep: @Sendable (Duration) async -> Void
    private(set) var tearKeyMade = 0

    init(script: Script = Script(), sleep: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }) {
        self.script = script
        self.sleep = sleep
    }

    func prepare(_: ASAuthorizationAppleIDRequest) {}

    func complete(_: Result<ASAuthorization, any Error>) async -> InviteSignIn {
        await sleep(.milliseconds(800))
        return script.signIn
    }

    func ticketAfterSignIn() async -> Session.Ticket {
        script.afterSignIn
    }

    /// The sample code is usable; anything else is not a code.
    func type(code: String) async -> Session.Ticket {
        if script.typedNeverFinishes {
            await Self.forever()
        }
        return Session.InviteCode.normalise(code) == SampleInvite.code ? .printing(SampleInvite.face) : .refused(nil, .invalid)
    }

    func beginTear() {
        tearKeyMade += 1
    }

    func tear() async -> Session.TearOutcome {
        guard let outcome = script.tear else {
            await Self.forever()
            return .failed
        }
        await sleep(.milliseconds(300))
        return outcome
    }

    func joinWaitlist(reason _: String?) async -> Bool {
        await sleep(.milliseconds(600))
        return true
    }

    func pendingCode() async -> String? {
        SampleInvite.code
    }

    func begin() {}

    /// A task that never resolves (for stills of "sealing").
    private static func forever() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3600))
        }
    }
}

/// What one scenario sets up: the phase and the words, as data (a table, not a switch).
struct InviteSetup {
    var phase: InviteModel.Phase = .ready
    var face: Session.TicketFace? = SampleInvite.face
    var preview: Session.TicketFace? = SampleInvite.face
    var firstName: String? = SampleInvite.firstName
    var tear: Session.TearOutcome? = .yours(SampleInvite.youreIn)
    var notice: InviteModel.Notice?
    var tiles = ""
    var locked = false
    var waitlist: InviteModel.Waitlist = .closed
    var keepGoing = false
    var printAnimates = false
    /// A printed ticket carries the invented code.
    var hasCode = true

    static func of(_ scenario: InviteScenario) -> Self {
        table[scenario] ?? Self()
    }

    private static let typed = Self(phase: .typed, face: nil, hasCode: false)
    private static let stuck = Self(hasCode: true)

    private static let table: [InviteScenario: Self] = [
        .promise: Self(phase: .promise, hasCode: false),
        .promiseNeutral: Self(phase: .promise, preview: nil, hasCode: false),
        .signingIn: Self(phase: .signingIn, hasCode: false),
        .signInFailed: Self(phase: .promise, notice: .signInFailed, hasCode: false),
        .typed: typed,
        .typedWrong: Self(phase: .typed, face: nil, notice: .wrongCode, hasCode: false),
        .typedFilled: Self(phase: .typed, face: nil, tiles: String(SampleInvite.code.prefix(7)), hasCode: false),
        .rateLimited: Self(phase: .typed, face: nil, notice: .rateLimited, locked: true, hasCode: false),
        .waitlistSheet: Self(phase: .typed, face: nil, waitlist: .sheet, hasCode: false),
        .waitlisted: Self(phase: .typed, face: nil, waitlist: .joined, hasCode: false),
        .used: Self(phase: .refused(.used)),
        .expired: Self(phase: .refused(.expired)),
        .offline: Self(phase: .waiting(.offline), hasCode: false),
        .suspended: Self(phase: .suspended, hasCode: false),
        .printing: Self(phase: .printing, printAnimates: true),
        .sealing: Self(tear: nil),
        .tearOffline: Self(tear: .offline),
        .tearRefused: Self(tear: .used),
        .tearing: Self(keepGoing: true),
        .torn: Self(phase: .torn),
        .youreIn: Self(phase: .youreIn),
        .youreInStatic: Self(phase: .youreIn),
        .noName: Self(phase: .youreIn, firstName: nil),
    ]
}

extension InviteModel {
    /// The model for one scenario, on the sample source.
    static func sample(_ scenario: InviteScenario) -> InviteModel {
        let setup = InviteSetup.of(scenario)
        var script = SampleInviteSource.Script()
        script.tear = setup.tear
        let youreIn = setup.phase == .youreIn || setup.phase == .torn
            ? Session.YoureIn(invitedBy: SampleInvite.youreIn.invitedBy, serial: 412, redeemedOn: "2026-10-21", animate: false)
            : nil
        let model = InviteModel(
            phase: setup.phase, source: SampleInviteSource(script: script), preview: setup.preview,
            face: setup.face, firstName: setup.firstName, youreIn: youreIn
        )
        model.applySample(setup)
        return model
    }
}
