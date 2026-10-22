import Foundation
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct FailureTests {
    /// Every error fixture of the Beta 1 contracts (00 and 02), and the kind it must map to.
    private static let expected: [String: Backend.Failure.Kind] = [
        "invalid_request": .invalidRequest,
        "invalid_credentials": .invalidCredentials,
        "unauthenticated": .unauthenticated,
        "session_revoked": .sessionRevoked,
        "invite_required": .inviteRequired,
        "suspended": .suspended,
        "not_found": .notFound,
        "idempotency_mismatch": .idempotencyMismatch,
        "update_required": .updateRequired,
        "rate_limited": .rateLimited(retryAfter: .seconds(60)),
        "spend_limited": .spendLimited(retryAfter: nil),
        "upstream_timeout": .upstreamTimeout,
        "upstream_unavailable": .upstreamUnavailable,
        "internal": .internal,
        "invite_invalid": .inviteInvalid,
        "invite_used": .inviteUsed,
        "invite_expired": .inviteExpired,
    ]

    static var errorFixtures: [String] {
        ["00", "02"].flatMap { contract in
            let folder = Fixtures.root.appendingPathComponent(contract)
            let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
            return names.filter { $0.hasPrefix("error.") && $0.hasSuffix(".json") }.sorted().map { "\(contract)/\($0.dropLast(5))" }
        }
    }

    @Test("there are error fixtures to check")
    func thereAreErrorFixturesToCheck() {
        #expect(Self.errorFixtures.count >= 25)
    }

    @Test("every error fixture decodes to its own failure, with its message", arguments: errorFixtures)
    func everyErrorFixtureDecodesToItsOwnFailure(_ fixture: String) throws {
        let parts = fixture.split(separator: "/").map(String.init)
        let data = try Fixtures.data(parts[0], parts[1])
        let body = try Backend.Coding.decoder.decode(Backend.ErrorBody.self, from: data)

        let failure = Backend.Failure(body)

        let code = try #require(parts[1].split(separator: ".").last.map(String.init))
        #expect(body.code == code)
        let kind = try #require(Self.expected[code], "no expected kind for \(code)")
        if case .rateLimited = kind {
            #expect(failure.kind == .rateLimited(retryAfter: body.retryAfterSeconds.map { .seconds($0) }))
        } else if case .spendLimited = kind {
            #expect(failure.kind == .spendLimited(retryAfter: body.retryAfterSeconds.map { .seconds($0) }))
        } else {
            #expect(failure.kind == kind)
        }
        #expect(failure.message == body.message)
    }

    @Test("a retry-after becomes a duration")
    func aRetryAfterBecomesADuration() {
        let failure = Backend.Failure(Backend.ErrorBody(code: "rate_limited", message: nil, retryAfterSeconds: 60))
        #expect(failure.kind == .rateLimited(retryAfter: .seconds(60)))
        #expect(failure.flowFailure.kind == .rateLimited(retryAfterSeconds: 60))
    }

    @Test("an unknown error code decodes to unknown, keeping the code")
    func anUnknownErrorCodeDecodesToUnknown() {
        let failure = Backend.Failure(Backend.ErrorBody(code: "brand_new_code", message: "invented"))
        #expect(failure.kind == .unknown(code: "brand_new_code"))
        #expect(failure.flowFailure.kind == .unknown)
        #expect(!failure.isRetryable)
    }

    @Test("failures are equal by kind, not by message")
    func failuresAreEqualByKind() {
        #expect(Backend.Failure(.notFound, message: "one") == Backend.Failure(.notFound, message: "two"))
        #expect(Backend.Failure(.notFound) != Backend.Failure(.internal))
    }

    @Test("only failures that sending again can fix are retryable")
    func onlyFailuresThatSendingAgainCanFixAreRetryable() {
        let retryable: [Backend.Failure.Kind] = [
            .rateLimited(retryAfter: nil),
            .upstreamTimeout,
            .upstreamUnavailable,
            .internal,
            .offline,
            .timedOut,
            .transport,
        ]
        let final: [Backend.Failure.Kind] = [
            .invalidRequest, .invalidCredentials, .unauthenticated, .sessionRevoked, .inviteRequired, .suspended, .notFound,
            .idempotencyMismatch, .updateRequired, .spendLimited(retryAfter: nil), .inviteInvalid, .inviteUsed, .inviteExpired,
            .decoding, .unknown(code: "x"),
        ]
        #expect(retryable.allSatisfy { Backend.Failure($0).isRetryable })
        #expect(final.allSatisfy { !Backend.Failure($0).isRetryable })
    }

    @Test("screens get the flow failure for each kind", arguments: [
        (Backend.Failure.Kind.offline, Flows.Failure.Kind.network),
        (.timedOut, .network),
        (.transport, .network),
        (.internal, .server),
        (.upstreamTimeout, .server),
        (.upstreamUnavailable, .server),
        (.decoding, .server),
        (.notFound, .notFound),
        (.updateRequired, .updateRequired),
        (.unauthenticated, .signedOut),
        (.sessionRevoked, .signedOut),
        (.inviteRequired, .inviteRequired),
        (.suspended, .suspended),
        (.invalidRequest, .invalid),
        (.idempotencyMismatch, .invalid),
        (.spendLimited(retryAfter: .seconds(5)), .spendLimited(retryAfterSeconds: 5)),
        (.invalidCredentials, .invalidCredentials),
        (.inviteInvalid, .inviteInvalid),
        (.inviteUsed, .inviteUsed),
        (.inviteExpired, .inviteExpired),
        (.unknown(code: "x"), .unknown),
    ])
    func screensGetTheFlowFailure(_ kind: Backend.Failure.Kind, _ expected: Flows.Failure.Kind) {
        #expect(Backend.Failure(kind, message: "invented").flowFailure.kind == expected)
    }

    @Test("invite and sign-in failures reach the screen, and none of them is worth retrying")
    func inviteAndSignInFailuresReachTheScreen() {
        let kinds: [Flows.Failure.Kind] = [.invalidCredentials, .inviteInvalid, .inviteUsed, .inviteExpired]
        #expect(kinds.allSatisfy { !Flows.Failure($0).isRetryable })
        #expect(Backend.Failure(Backend.ErrorBody(code: "invite_used", message: "that one's been used")).flowFailure.message == "that one's been used")
    }

    @Test("a phone-side failure carries no message to the screen")
    func aPhoneSideFailureCarriesNoMessage() {
        #expect(Backend.Failure(.offline).flowFailure.message == nil)
        #expect(Backend.Failure(.notFound, message: "gone").flowFailure.message == "gone")
    }
}
