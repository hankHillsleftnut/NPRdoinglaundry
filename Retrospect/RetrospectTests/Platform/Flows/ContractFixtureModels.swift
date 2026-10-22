import Foundation
@testable import Retrospect

/// The response and request shapes the fixture tests decode. Contract 02's use the app's own
/// models; contract 00's are mirrors until PL1.1–PL1.7 land the real ones (which then replace
/// these here, so the same fixtures test them).
extension ContractFixtureTests {
    struct Envelope<Payload: Decodable>: Decodable {
        let success: Bool
        let data: Payload
    }

    struct FailureBody: Decodable {
        let code: String
        let message: String
        let retryAfterSeconds: Int?
    }

    struct FailureEnvelope: Decodable {
        let success: Bool
        let error: FailureBody
    }

    // Contract 02 responses

    struct Today: Decodable {
        let date: String
        let entries: [Journal.Entry]
    }

    struct EntryBody: Decodable {
        let entry: Journal.Entry
    }

    struct EntryPage: Decodable {
        let entries: [Journal.Entry]
        let nextCursor: String?
    }

    struct Deleted: Decodable {
        let deleted: Bool
    }

    struct LatestBrief: Decodable {
        let brief: Journal.Brief?
        let enabled: Bool
    }

    struct BriefPage: Decodable {
        let briefs: [Journal.Brief]
        let nextCursor: String?
    }

    struct Enabled: Decodable {
        let enabled: Bool
    }

    struct Guesses: Decodable {
        let guesses: [Journal.Guess]
        let speaking: Bool
    }

    struct Answer: Decodable {
        let status: Journal.Guess.Status
    }

    // Contract 02 requests

    struct EntryCreate: Decodable {
        let text: String
        let kind: Journal.Entry.Kind
        let clientEntryId: String
        let createdAt: Date
    }

    struct TextOnly: Decodable {
        let text: String
    }

    struct Verdict: Decodable {
        let verdict: Journal.GuessVerdict
    }

    struct About: Decodable {
        let kind: Journal.SourceRef.Kind
        let id: String
    }

    struct Correction: Decodable {
        let text: String
        let about: About?
    }

    struct CorrectionConfirm: Decodable {
        let kind: Journal.SourceRef.Kind
        let id: String
        let mode: Journal.CorrectionMode
        let note: String?
    }

    // Contract 00 responses (mirrors)

    struct AuthUser: Decodable {
        let id: String
        let firstName: String?
        let isNew: Bool
    }

    struct AccessState: Decodable {
        let state: String
    }

    struct Auth: Decodable {
        let accessToken: String
        let refreshToken: String
        let accessTokenExpiresAt: Date
        let user: AuthUser
        let access: AccessState
    }

    struct SignedOut: Decodable {
        let signedOut: Bool
    }

    struct Access: Decodable {
        let state: String
        let onWaitlist: Bool
    }

    struct OnWaitlist: Decodable {
        let onWaitlist: Bool
    }

    struct Received: Decodable {
        let received: Bool
    }

    struct Redeem: Decodable {
        let access: AccessState
        let invitedBy: String?
        /// The spent invite's number and the tear's date (contract 01 §2.3); null when no code was spent.
        let invite: RedeemedInvite?
    }

    struct RedeemedInvite: Decodable {
        let serial: Int
        let redeemedOn: String
    }

    struct Invite: Decodable {
        let id: String
        let link: URL?
        let createdAt: Date
        let state: String
        let usedBy: String?
    }

    struct InvitesMine: Decodable {
        let invites: [Invite]
    }

    struct Meta: Decodable {
        let minVersion: String
        let latestVersion: String
        let serverTime: Date
        let environment: String
    }

    // Contract 00 requests (mirrors)

    struct FullName: Decodable {
        let givenName: String?
        let familyName: String?
    }

    struct AppleSignIn: Decodable {
        let identityToken: String
        let authorizationCode: String
        let rawNonce: String
        let fullName: FullName?
        let email: String?
    }

    struct GoogleSignIn: Decodable {
        let idToken: String
        let rawNonce: String
    }

    struct RefreshToken: Decodable {
        let refreshToken: String
    }

    struct WaitlistReason: Decodable {
        let reason: String?
    }

    struct PublicWaitlist: Decodable {
        let email: String
        let name: String
        let reason: String?
        let website: String
    }

    struct RedeemRequest: Decodable {
        let code: String
    }
}
