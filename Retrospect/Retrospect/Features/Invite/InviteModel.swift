//
//  InviteModel.swift
//  PI1 + PI2: one model for the whole invite moment, so the typed path and the link path end in
//  the same `ready` and the ticket is one instance throughout. It owns the phase and the words,
//  never the network: every door is behind `InviteSource`. Nothing is shown as "yours" before the
//  server said so, and a failed or refused tear keeps the code (the source keeps it).
//
import AuthenticationServices
import Foundation
import Observation

@MainActor @Observable
final class InviteModel {
    /// What the page is doing. One value, so views never cross-fade between "printing" and "ready".
    enum Phase: Equatable {
        /// Signed out, a code waiting (T1).
        case promise
        case signingIn
        /// Signed in, no code: the ticket takes a typed one (T-alt).
        case typed
        /// The check couldn't finish; the code is kept and checked again.
        case waiting(Session.Wait)
        case printing
        case ready
        /// The stub ran to the end; the server hasn't answered yet.
        case sealing
        case torn
        case youreIn
        /// The code can't be used: the ticket shows "already used" / "expired" and no handle.
        case refused(Session.Refusal)
        case suspended
        /// A member opened a link: no page, a toast, the code dropped.
        case alreadyIn
    }

    /// The words under the ticket, other than the phase's own.
    enum Notice: Equatable {
        case signInFailed, wrongCode, rateLimited, typeOffline, typeFailed
        case sealing, sealOffline, sealFailed, justUsed
    }

    enum Waitlist: Equatable {
        case closed, sheet, joining, failed, joined
    }

    private(set) var phase: Phase
    private(set) var notice: Notice?
    private(set) var face: Session.TicketFace?
    private(set) var firstName: String?
    private(set) var youreIn: Session.YoureIn?
    /// The tiles, while typing (C41.4). Never logged.
    private(set) var tiles = ""
    /// The code on a printed stub (a link's), for the tiles. Never logged.
    private(set) var printedCode = ""
    private(set) var codeLocked = false
    private(set) var waitlist: Waitlist = .closed
    /// Whether the ticket prints with the rise (a link) or is simply there (typed, relaunch).
    private(set) var printAnimates = false
    /// "begin" shows once the words have landed.
    private(set) var beginVisible = false
    /// The tear has passed its first hole: "keep going."
    var keepGoing = false

    // Counters the views turn into haptics and the shake (each fires once per change).
    private(set) var wrongCodes = 0
    private(set) var rips = 0
    private(set) var reveals = 0
    private(set) var warnings = 0
    private(set) var confirms = 0

    /// The signed-out preview: who kept a place, when the link's preview was live.
    let preview: Session.TicketFace?
    /// Where the page hands on to ("begin", or a member who is already in).
    var onFinish: () -> Void = {}

    @ObservationIgnored private let source: any InviteSource
    @ObservationIgnored private let sleep: @Sendable (Duration) async -> Void
    @ObservationIgnored private var tearTask: Task<Session.TearOutcome, Never>?
    @ObservationIgnored private var lockTask: Task<Void, Never>?
    @ObservationIgnored private var typedCheck: Task<Void, Never>?

    init(
        phase: Phase,
        source: any InviteSource,
        preview: Session.TicketFace? = nil,
        face: Session.TicketFace? = nil,
        firstName: String? = nil,
        youreIn: Session.YoureIn? = nil,
        sleep: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    ) {
        self.phase = phase
        self.source = source
        self.preview = preview
        self.face = face
        self.firstName = firstName
        self.youreIn = youreIn
        self.sleep = sleep
        beginVisible = phase == .youreIn
    }

    /// Where a relaunch lands: nothing is spent until the stub separates, so any phase before the
    /// tear comes back whole at `ready`; a torn ticket is already yours.
    static func relaunched(_ phase: Phase) -> Phase {
        switch phase {
        case .printing, .ready, .sealing: .ready
        case .torn, .youreIn: .youreIn
        default: phase
        }
    }

    // MARK: Sign in

    func prepareApple(_ request: ASAuthorizationAppleIDRequest) {
        source.prepare(request)
    }

    func appleFinished(_ result: Result<ASAuthorization, any Error>) async {
        guard phase == .promise || phase == .signingIn else { return }
        phase = .signingIn
        notice = nil
        switch await source.complete(result) {
        case .cancelled:
            phase = .promise
        case .failed:
            phase = .promise
            notice = .signInFailed
            warnings += 1
        case let .signedIn(name, access):
            firstName = name
            if access == .suspended {
                phase = .suspended
                return
            }
            await receive(source.ticketAfterSignIn(), access: access, typed: false)
        }
    }

    /// The connection came back, or the person tapped retry: a waiting check runs again.
    func retry() async {
        guard case .waiting = phase else { return }
        await receive(source.ticketAfterSignIn(), access: .waitlisted, typed: false)
    }

    // MARK: A typed code

    /// Whatever the field holds now: normalised onto the tiles; the 13th character checks it.
    func setCode(_ raw: String) {
        guard phase == .typed, !codeLocked else { return }
        let next = TicketCode.tiles(from: raw)
        guard next != tiles else { return }
        tiles = next
        if notice == .wrongCode || notice == .typeFailed || notice == .typeOffline {
            notice = nil
        }
        if next.count == TicketCode.length {
            Task { await submitTyped() }
        }
    }

    func submitTyped() async {
        guard phase == .typed, tiles.count == TicketCode.length else { return }
        // one check at a time: the 13th character already started it
        if let running = typedCheck {
            await running.value
            return
        }
        let code = tiles
        let task = Task { [source] in
            let ticket = await source.type(code: code)
            await receive(ticket, access: .waitlisted, typed: true)
        }
        typedCheck = task
        await task.value
        typedCheck = nil
    }

    // MARK: The ticket is known

    func receive(_ ticket: Session.Ticket, access: Session.AccessState, typed: Bool) async {
        switch ticket {
        case let .printing(face):
            self.face = face
            notice = nil
            if !typed {
                printedCode = await source.pendingCode() ?? ""
            }
            printAnimates = !typed
            phase = typed ? .ready : .printing
            if typed {
                confirms += 1
            }
        case let .refused(face, reason):
            if typed, reason == .invalid {
                await wrongCode()
            } else {
                self.face = face
                if !typed {
                    printedCode = await source.pendingCode() ?? ""
                }
                printAnimates = !typed
                phase = .refused(reason)
            }
        case let .waiting(wait):
            await waiting(wait, typed: typed)
        case let .youreIn(stub):
            youreIn = stub
            phase = .youreIn
            beginVisible = true
        case .none:
            phase = Self.phase(forNoTicket: access, typed: typed)
            beginVisible = phase == .youreIn
        }
    }

    private static func phase(forNoTicket access: Session.AccessState, typed: Bool) -> Phase {
        switch access {
        case .approved: typed ? .alreadyIn : .youreIn
        case .member, .staff: .alreadyIn
        case .suspended: .suspended
        case .waitlisted, .unknown: .typed
        }
    }

    private func waiting(_ wait: Session.Wait, typed: Bool) async {
        guard typed else {
            phase = .waiting(wait)
            return
        }
        switch wait {
        case .offline: notice = .typeOffline
        case let .rateLimited(seconds):
            notice = .rateLimited
            lock(for: .seconds(seconds ?? 60))
        case .failed: notice = .typeFailed
        }
        warnings += 1
    }

    private func wrongCode() async {
        notice = .wrongCode
        wrongCodes += 1
        // the tiles clear right to left, 30ms apart
        while !tiles.isEmpty {
            await sleep(.milliseconds(30))
            tiles.removeLast()
        }
    }

    private func lock(for duration: Duration) {
        codeLocked = true
        lockTask?.cancel()
        lockTask = Task { [weak self, sleep] in
            await sleep(duration)
            guard !Task.isCancelled else { return }
            self?.codeLocked = false
            if self?.notice == .rateLimited {
                self?.notice = nil
            }
        }
    }

    // MARK: The print

    /// A ticket that comes out of the printer: a usable one, or a refused one.
    var isPrinting: Bool {
        switch phase {
        case .printing, .refused: true
        default: false
        }
    }

    func printFinished() {
        guard phase == .printing else { return }
        phase = .ready
    }

    /// The print isn't replayed: back from the background (or Reduce Motion) it is simply done.
    func skipPrint() {
        printAnimates = false
        printFinished()
    }

    // MARK: The tear

    func tearTouchedDown() {
        guard phase == .ready else { return }
        source.beginTear()
    }

    /// The finger let go before the threshold, or the gesture was cancelled: whole again.
    func tearAbandoned() {
        keepGoing = false
    }

    /// The stub ran to the end (or "tear ticket" was chosen): the code is spent once.
    func commitTear() async {
        guard phase == .ready else { return }
        phase = .sealing
        notice = nil
        let task = Task { await source.tear() }
        tearTask = task
        let slow = Task { [weak self, sleep] in
            await sleep(.milliseconds(400))
            guard !Task.isCancelled, self?.phase == .sealing else { return }
            self?.notice = .sealing
        }
        let outcome = await Self.race(task, limit: .seconds(8), sleep: sleep)
        slow.cancel()
        guard let outcome else {
            // too slow: the stub springs back, the redeem may still land
            springBack(.sealFailed)
            Task { [weak self] in await self?.late(task) }
            return
        }
        await apply(outcome)
    }

    private func late(_ task: Task<Session.TearOutcome, Never>) async {
        let outcome = await task.value
        if case .yours = outcome, phase == .ready || phase == .typed {
            await apply(outcome)
        }
    }

    private func apply(_ outcome: Session.TearOutcome) async {
        switch outcome {
        case let .yours(stub):
            youreIn = stub
            keepGoing = false
            notice = nil
            phase = .torn
            rips += 1
            await sleep(.milliseconds(900))
            phase = .youreIn
            reveals += 1
            await sleep(.milliseconds(400))
            beginVisible = true
        case .used:
            keepGoing = false
            phase = .refused(.used)
            notice = .justUsed
            warnings += 1
        case let .refused(reason):
            keepGoing = false
            phase = .refused(reason)
            warnings += 1
        case .offline:
            springBack(.sealOffline)
        case .rateLimited, .failed, .nothingToRedeem:
            springBack(.sealFailed)
        }
    }

    private func springBack(_ because: Notice) {
        keepGoing = false
        phase = .ready
        notice = because
        warnings += 1
    }

    /// The first of the work and a timer: `nil` when the timer wins. The work keeps running.
    private static func race(
        _ task: Task<Session.TearOutcome, Never>, limit: Duration, sleep: @escaping @Sendable (Duration) async -> Void
    ) async -> Session.TearOutcome? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Session.TearOutcome?, Never>) in
            let done = Platform.Box(false)
            let finish: @Sendable (Session.TearOutcome?) -> Void = { value in
                if done.exchange(true) == false {
                    continuation.resume(returning: value)
                }
            }
            Task { await finish(task.value) }
            Task {
                await sleep(limit)
                finish(nil)
            }
        }
    }

    // MARK: After

    func begin() {
        guard phase == .youreIn, beginVisible else { return }
        source.begin()
        onFinish()
    }

    // MARK: The waitlist

    func openWaitlist() {
        waitlist = .sheet
    }

    func closeWaitlist() {
        if waitlist != .joined {
            waitlist = .closed
        }
    }

    func join(reason: String?) async {
        guard waitlist == .sheet || waitlist == .failed else { return }
        waitlist = .joining
        let trimmed = reason?.trimmingCharacters(in: .whitespacesAndNewlines)
        let joined = await source.joinWaitlist(reason: (trimmed?.isEmpty ?? true) ? nil : trimmed)
        waitlist = joined ? .joined : .failed
        if joined {
            confirms += 1
        } else {
            warnings += 1
        }
    }
}

// MARK: Sample scenarios

extension InviteModel {
    /// What a scenario shows beyond its phase: the words, the tiles, the waitlist.
    func applySample(_ setup: InviteSetup) {
        notice = setup.notice
        tiles = setup.tiles
        codeLocked = setup.locked
        waitlist = setup.waitlist
        keepGoing = setup.keepGoing
        printAnimates = setup.printAnimates
        printedCode = setup.hasCode ? SampleInvite.code : ""
        beginVisible = setup.phase == .youreIn
    }
}
