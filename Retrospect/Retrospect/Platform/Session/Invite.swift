import Foundation
import Observation

extension Session {
    /// A code as the person has it, made canonical: uppercase, no spaces or
    /// dashes, Crockford base32 with `I`/`L` read as `1` and `O` as `0`, and
    /// exactly 13 characters. Anything else isn't a code and is never sent.
    enum InviteCode {
        static let length = 13
        static let alphabet = Set("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

        static func normalise(_ raw: String) -> String? {
            let cleaned = raw.uppercased().compactMap { character -> Character? in
                switch character {
                case " ", "-": nil
                case "I", "L": "1"
                case "O": "0"
                default: character
                }
            }
            guard cleaned.count == length, cleaned.allSatisfy(alphabet.contains) else { return nil }
            return String(cleaned)
        }
    }

    /// Why the ticket can't be used.
    enum Refusal: Sendable, Equatable {
        case used, expired, invalid
    }

    /// Why the ticket is waiting rather than printed: the code is kept and
    /// the check runs again on the next active scene or connection.
    enum Wait: Sendable, Equatable {
        case offline
        case rateLimited(retryAfterSeconds: Int?)
        case failed
    }

    /// The "you're in" moment: who vouched, and the stub's number and date.
    struct YoureIn: Sendable, Equatable {
        let invitedBy: String?
        let serial: Int?
        let redeemedOn: String?
        /// False for a relaunch between the tear and "begin": shown, not torn again.
        let animate: Bool
    }

    /// What the invite screen shows.
    enum Ticket: Sendable, Equatable {
        /// Nothing to show: no pending code, or the person is already in.
        case none
        /// The code can be redeemed now: the ticket prints with this face.
        case printing(TicketFace)
        /// The code can't be used; the face when the server gave one.
        case refused(TicketFace?, Refusal)
        /// Checked later: the code is kept.
        case waiting(Wait)
        case youreIn(YoureIn)
    }

    /// What a tear came to.
    enum TearOutcome: Sendable, Equatable {
        case yours(YoureIn)
        /// Someone else used it meanwhile; the code is gone.
        case used
        /// It expired, or was never a code; the code is gone.
        case refused(Refusal)
        /// Nothing changed: the code and the tear's key are kept for the next try.
        case offline
        case rateLimited(retryAfterSeconds: Int?)
        case failed
        /// No pending code to redeem.
        case nothingToRedeem
    }

    /// The invite, from a link or a typed code to the tear (PL1.7, amended by
    /// PL1.7d): the code is checked after sign-in and spent only at the tear.
    /// The code lives in the store's pending slot until the tear succeeds and
    /// is never logged; the face is kept only for the screen.
    @MainActor @Observable
    final class InviteCenter {
        private(set) var access: AccessState = .unknown
        private(set) var ticket: Ticket = .none

        private let store: Store
        private let client: Backend.Client
        private let session: Manager
        private let log: any Platform.LogSink
        private let makeKey: @Sendable () -> UUID
        private var tearKey: UUID?
        private var tearing: Task<TearOutcome, Never>?
        private var checking: Task<Void, Never>?
        private var watching: Task<Void, Never>?

        init(store: Store, client: Backend.Client, session: Manager, log: any Platform.LogSink, makeKey: @escaping @Sendable () -> UUID = UUID.init) {
            self.store = store
            self.client = client
            self.session = session
            self.log = log
            self.makeKey = makeKey
        }

        /// Follows the session: `access` tracks it, and a sign-out clears the ticket.
        func start() {
            guard watching == nil else { return }
            let session = session
            watching = Task { [weak self] in
                for await state in session.states() {
                    guard let self else { return }
                    apply(state)
                }
            }
        }

        /// The session's current state, read once (tests, and before `start`).
        func sync() async {
            await apply(session.state)
        }

        // MARK: A code arrives

        /// From the router: a code from a link, kept for after sign-in. Not a
        /// code at all → refused without a request; already signed in →
        /// checked now.
        func received(code raw: String) async {
            guard let code = InviteCode.normalise(raw) else {
                ticket = .refused(nil, .invalid)
                return
            }
            do {
                try await store.setPendingInviteCode(code)
            } catch {
                log.record(.keychainWriteFailed(.pendingInvite, status: Self.status(of: error)))
            }
            log.record(.inviteReceived)
            if case .signedIn = await session.state {
                await afterSignIn()
            }
        }

        /// Typed on the invite screen: checked, and kept as the pending code
        /// only when it can be used.
        func type(code raw: String) async {
            guard let code = InviteCode.normalise(raw) else {
                ticket = .refused(nil, .invalid)
                return
            }
            let outcome = await check(code)
            if case .printing = outcome {
                do {
                    try await store.setPendingInviteCode(code)
                } catch {
                    log.record(.keychainWriteFailed(.pendingInvite, status: Self.status(of: error)))
                }
            }
            ticket = outcome
        }

        /// After sign-in (and on every active scene while waiting): a pending
        /// code is checked, never redeemed. The server says whether the person
        /// is already in (then the leftover code is dropped) or already redeemed it.
        func afterSignIn() async {
            if let checking {
                await checking.value
                return
            }
            let task = Task { await checkPending() }
            checking = task
            await task.value
            checking = nil
        }

        /// On the next active scene or connection: only a waiting ticket checks again.
        func retryIfWaiting() async {
            guard case .waiting = ticket else { return }
            await afterSignIn()
        }

        // MARK: The tear

        /// Touch-down on the stub: one key for this tear, reused by a retry.
        func beginTear() {
            if tearKey == nil {
                tearKey = makeKey()
            }
        }

        /// The stub separates: the code is spent, once. A second call while
        /// one is in flight gets the first call's outcome.
        func tear() async -> TearOutcome {
            if let tearing {
                return await tearing.value
            }
            let task = Task { await redeemPending() }
            tearing = task
            let outcome = await task.value
            tearing = nil
            return outcome
        }

        // MARK: Access and the waitlist

        /// `GET /v2/access`: the state, kept with the session.
        func refreshAccess() async throws -> AccessInfo {
            let info = try await client.send(Backend.Endpoints.Access())
            await session.setAccess(info.state)
            access = info.state
            return info
        }

        func joinWaitlist(reason: String?) async throws -> Bool {
            try await client.send(Backend.Endpoints.JoinWaitlist(reason: reason)).onWaitlist
        }

        func myInvites() async throws -> [Invite] {
            try await client.send(Backend.Endpoints.InvitesMine()).invites
        }

        // MARK: Inside

        private func apply(_ state: State) {
            switch state {
            case let .signedIn(_, access):
                self.access = access
            case .signedOut:
                access = .unknown
                ticket = .none
                tearKey = nil
            case .locked:
                break
            }
        }

        private func checkPending() async {
            await sync()
            let pending: String?
            do {
                pending = try await store.pendingInviteCode()
            } catch {
                log.record(.keychainWriteFailed(.pendingInvite, status: Self.status(of: error)))
                return
            }
            guard let pending else {
                if case .waiting = ticket {
                    ticket = .none
                }
                return
            }
            // Every pending code is checked, whatever the access state: the server
            // decides (and answers "yours" before "already in", so a relaunch after
            // the tear whose clear failed still shows you're in). An unknown or
            // suspended state fails closed: the code is kept and checked like a
            // waitlisted person's.
            ticket = await check(pending)
            switch ticket {
            case .refused, .none:
                await clearPending()
            case let .youreIn(youreIn) where !youreIn.animate:
                await clearPending()
            default:
                break
            }
        }

        /// `POST /v2/invites/check`, mapped to what the screen shows.
        private func check(_ code: String) async -> Ticket {
            do {
                let answer = try await client.send(Backend.Endpoints.InviteCheck(code: code))
                if answer.usable, let face = answer.face {
                    log.record(.inviteChecked(.usable))
                    return .printing(face)
                }
                switch answer.reason {
                case .yours:
                    log.record(.inviteChecked(.yours))
                    return .youreIn(YoureIn(invitedBy: answer.face?.from, serial: answer.face?.serial, redeemedOn: nil, animate: false))
                case .alreadyIn:
                    log.record(.inviteChecked(.alreadyIn))
                    return .none
                case .unknown, nil:
                    log.record(.inviteChecked(.unreadable))
                    return .waiting(.failed)
                }
            } catch let failure as Backend.Failure {
                let (ticket, outcome) = Self.ticket(for: failure)
                log.record(.inviteChecked(outcome))
                return ticket
            } catch {
                log.record(.inviteChecked(.failed))
                return .waiting(.failed)
            }
        }

        private static func ticket(for failure: Backend.Failure) -> (Ticket, InviteCheckOutcome) {
            switch failure.kind {
            case .inviteUsed: (.refused(nil, .used), .used)
            case .inviteExpired: (.refused(nil, .expired), .expired)
            case .inviteInvalid: (.refused(nil, .invalid), .invalid)
            case .offline, .timedOut, .transport: (.waiting(.offline), .offline)
            case let .rateLimited(retryAfter): (.waiting(.rateLimited(retryAfterSeconds: retryAfter.map { Int($0.components.seconds) })), .rateLimited)
            default: (.waiting(.failed), .failed)
            }
        }

        private func redeemPending() async -> TearOutcome {
            let pending: String?
            do {
                pending = try await store.pendingInviteCode()
            } catch {
                log.record(.keychainWriteFailed(.pendingInvite, status: Self.status(of: error)))
                return .failed
            }
            guard let pending else { return .nothingToRedeem }
            beginTear()
            guard let key = tearKey else { return .failed }
            do {
                let answer = try await client.send(Backend.Endpoints.InviteRedeem(code: pending, key: key))
                await clearPending()
                tearKey = nil
                await session.setAccess(answer.access.state)
                access = answer.access.state
                let youreIn = YoureIn(
                    invitedBy: answer.invitedBy, serial: answer.invite?.serial, redeemedOn: answer.invite?.redeemedOn, animate: true
                )
                ticket = .youreIn(youreIn)
                log.record(.inviteTorn(.yours))
                return .yours(youreIn)
            } catch let failure as Backend.Failure {
                return await torn(failure)
            } catch {
                log.record(.inviteTorn(.failed))
                return .failed
            }
        }

        private func torn(_ failure: Backend.Failure) async -> TearOutcome {
            switch failure.kind {
            case .inviteUsed:
                await clearPending()
                tearKey = nil
                ticket = .refused(nil, .used)
                log.record(.inviteTorn(.used))
                return .used
            case .inviteExpired:
                await clearPending()
                tearKey = nil
                ticket = .refused(nil, .expired)
                log.record(.inviteTorn(.refused))
                return .refused(.expired)
            case .inviteInvalid:
                await clearPending()
                tearKey = nil
                ticket = .refused(nil, .invalid)
                log.record(.inviteTorn(.refused))
                return .refused(.invalid)
            case .offline, .timedOut, .transport:
                log.record(.inviteTorn(.offline))
                return .offline
            case let .rateLimited(retryAfter):
                log.record(.inviteTorn(.rateLimited))
                return .rateLimited(retryAfterSeconds: retryAfter.map { Int($0.components.seconds) })
            default:
                // A bug state (a mismatched key) or a server failure: the code is
                // kept, and the next touch-down makes a fresh key.
                tearKey = nil
                log.record(.inviteTorn(.failed))
                return .failed
            }
        }

        private func clearPending() async {
            do {
                try await store.setPendingInviteCode(nil)
            } catch {
                log.record(.keychainWriteFailed(.pendingInvite, status: Self.status(of: error)))
            }
        }

        private static func status(of error: any Error) -> OSStatus {
            (error as? KeychainError)?.status ?? errSecInternalError
        }
    }

    /// What a check came to, for the log.
    enum InviteCheckOutcome: Sendable, Equatable {
        case usable, yours, alreadyIn, used, expired, invalid, offline, rateLimited, failed, unreadable
    }

    /// What a tear came to, for the log.
    enum InviteTearOutcome: Sendable, Equatable {
        case yours, used, refused, offline, rateLimited, failed
    }
}
