import Foundation

extension Session {
    /// Who made the invite (contract 01 §1).
    enum InviteKind: String, Flows.ContractEnum {
        case member, founder, review, unknown
    }

    /// What the ticket prints: never the code, never more of the inviter
    /// than a first name.
    struct TicketFace: Decodable, Sendable, Equatable {
        let from: String?
        let kind: InviteKind
        /// The invite's place in the order invites were made; shown padded to four digits.
        let serial: Int
        /// `YYYY-MM-DD`, the day the invite was made.
        let issuedOn: String
    }

    /// Why a code can't be used by this person (contract 01 §2.2).
    enum CheckReason: String, Flows.ContractEnum {
        /// This person already redeemed it (a relaunch between the tear and "begin").
        case yours
        /// Already approved, a member or staff: nothing to redeem.
        case alreadyIn
        case unknown
    }

    /// `POST /v2/invites/check`'s answer.
    struct InviteCheck: Decodable, Sendable, Equatable {
        let usable: Bool
        let reason: CheckReason?
        let face: TicketFace?
    }

    /// The kept stub: the spent invite's number and the tear's date.
    struct Stub: Decodable, Sendable, Equatable {
        let serial: Int
        /// `YYYY-MM-DD` in the redeemer's time zone.
        let redeemedOn: String
    }

    /// `POST /v2/invites/redeem`'s answer (contract 00 §4, amended by 01 §2.3).
    struct Redeemed: Decodable, Sendable, Equatable {
        let access: Backend.AuthResponse.Access
        let invitedBy: String?
        /// Nil only when no code was spent (an approved, member or staff caller).
        let invite: Stub?
    }

    /// `GET /v2/access`.
    struct AccessInfo: Decodable, Sendable, Equatable {
        let state: AccessState
        let onWaitlist: Bool
    }

    /// `POST /v2/waitlist`'s answer.
    struct OnWaitlist: Decodable, Sendable, Equatable {
        let onWaitlist: Bool
    }

    /// One of a member's three invites (`GET /v2/invites/mine`).
    struct Invite: Decodable, Sendable, Equatable, Identifiable {
        enum State: String, Flows.ContractEnum {
            case unused, used, revoked, unknown
        }

        let id: String
        /// Present while unused; nil once used or revoked.
        let link: URL?
        let createdAt: Date
        let state: State
        let usedBy: String?
    }

    struct InvitesMine: Decodable, Sendable, Equatable {
        let invites: [Invite]
    }
}

extension Backend {
    /// Check and redeem take the same body: the code, as the person has it.
    struct InviteCodeBody: Codable, Sendable, Equatable {
        let code: String
    }

    /// `POST /v2/waitlist`'s body; the reason is optional and short.
    struct WaitlistBody: Codable, Sendable, Equatable {
        let reason: String?
    }
}

extension Backend.Endpoints {
    /// `POST /v2/invites/check` (signed in, open to the waitlisted): what the
    /// ticket would print, spending nothing. Sent once.
    struct InviteCheck: Backend.Endpoint {
        typealias Response = Session.InviteCheck

        let body: Backend.InviteCodeBody?

        init(code: String) {
            body = Backend.InviteCodeBody(code: code)
        }

        var method: Backend.Method {
            .post
        }

        var path: Backend.PathTemplate {
            .invitesCheck
        }
    }

    /// `POST /v2/invites/redeem` (the tear) with the key made at touch-down,
    /// so a retry of a lost answer is the same tear.
    struct InviteRedeem: Backend.Endpoint {
        typealias Response = Session.Redeemed

        let body: Backend.InviteCodeBody?
        let key: UUID

        init(code: String, key: UUID) {
            body = Backend.InviteCodeBody(code: code)
            self.key = key
        }

        var method: Backend.Method {
            .post
        }

        var path: Backend.PathTemplate {
            .invitesRedeem
        }

        var idempotencyKey: UUID? {
            key
        }
    }

    /// `GET /v2/access`.
    struct Access: Backend.Endpoint {
        typealias Response = Session.AccessInfo

        var method: Backend.Method {
            .get
        }

        var path: Backend.PathTemplate {
            .access
        }
    }

    /// `POST /v2/waitlist`: idempotent per user on the server, sent once.
    struct JoinWaitlist: Backend.Endpoint {
        typealias Response = Session.OnWaitlist

        let body: Backend.WaitlistBody?

        init(reason: String?) {
            body = Backend.WaitlistBody(reason: reason)
        }

        var method: Backend.Method {
            .post
        }

        var path: Backend.PathTemplate {
            .waitlist
        }
    }

    /// `GET /v2/invites/mine`: the member's three invites and their links.
    struct InvitesMine: Backend.Endpoint {
        typealias Response = Session.InvitesMine

        var method: Backend.Method {
            .get
        }

        var path: Backend.PathTemplate {
            .invitesMine
        }
    }
}

extension Backend.Endpoints {
    /// `GET /public/invites/:code` (contract 01 §2.1): public, no token. For a live code, the ticket's face; for
    /// a code that is unknown, used, revoked or expired, the same 200 with nothing in it, so a preview never says which.
    struct InvitePreview: Backend.Endpoint {
        struct Preview: Decodable, Sendable, Equatable {
            let live: Bool
            let face: Session.TicketFace?
        }

        typealias Response = Preview

        let code: String

        var method: Backend.Method {
            .get
        }

        var path: Backend.PathTemplate {
            .invitePreview
        }

        var pathParameters: [String: String] {
            ["code": code]
        }

        var requiresAuth: Bool {
            false
        }

        var timeout: Duration {
            .seconds(10)
        }
    }
}
