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

    // Contract 00 responses (mirrors, until PL1.7's invite types land)

    struct Received: Decodable {
        let received: Bool
    }

    struct Meta: Decodable {
        let minVersion: String
        let latestVersion: String
        let serverTime: Date
        let environment: String
    }

    // Contract 00 requests (mirrors)

    struct GoogleSignIn: Decodable {
        let idToken: String
        let rawNonce: String
    }

    struct PublicWaitlist: Decodable {
        let email: String
        let name: String
        let reason: String?
        let website: String
    }

    // Diagnostics (DG.1): mirrors until DG.5 lands the real report builder.

    struct DiagnosticsReceipt: Decodable {
        let reference: String
    }

    struct DiagnosticsReport: Decodable {
        let reportId: UUID
        let createdAt: Date
        let note: String?
    }

    struct DiagnosticsIds: Decodable {
        let routes: [String]
        let screens: [String]
        let sheets: [String]
        let controls: [String]
        let failures: [String]
    }
}
