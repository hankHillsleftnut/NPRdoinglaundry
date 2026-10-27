import Foundation
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct EndpointTests {
    @Test("meta is a public GET with no body, no key and the default timeout")
    func metaIsAPublicGet() {
        let meta = Backend.Endpoints.Meta()

        #expect(meta.method == .get)
        #expect(meta.path == .meta)
        #expect(meta.path.rawValue == "/v2/meta")
        #expect(!meta.requiresAuth)
        #expect(meta.body == nil)
        #expect(meta.idempotencyKey == nil)
        #expect(meta.pathParameters.isEmpty)
        #expect(meta.query.isEmpty)
        #expect(meta.timeout == .seconds(20))
    }

    @Test("send report is an authenticated POST keyed by the report id, with a long timeout")
    func sendReportIsAPostKeyedByTheReportID() throws {
        let id = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000d1"))
        let report = Platform.Diagnostics.Report(
            reportID: id, createdAt: Date(timeIntervalSince1970: 1_792_569_604), note: nil,
            environment: Platform.Diagnostics.Environment(sources: .init(
                info: nil, osVersion: OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0), machine: "arm64",
                locale: Locale(identifier: "en_US"), timeZone: .gmt, contentSize: .large, reduceMotion: false, voiceOver: false,
                network: .unknown, freeDiskBytes: nil
            )),
            account: .init(provider: .apple, access: .member, entitlement: .trial),
            events: [], network: [], outbox: .empty, failures: [], performance: .none, crashes: []
        )
        let send = Backend.Endpoints.SendReport(report: report)

        #expect(send.method == .post)
        #expect(send.path == .diagnostics)
        #expect(send.path.rawValue == "/v2/diagnostics")
        #expect(send.requiresAuth)
        #expect(send.body == report)
        #expect(send.idempotencyKey == id)
        #expect(send.timeout == .seconds(60))
    }

    @Test("the auth doors: apple and refresh are public POSTs, signout needs the token; refresh and signout wait ten seconds")
    func theAuthDoors() {
        let apple = Backend.Endpoints.AppleSignIn(.init(identityToken: "t", authorizationCode: "c", rawNonce: "n", firstAuthorization: nil))
        let refresh = Backend.Endpoints.Refresh(refreshToken: "r")
        let signOut = Backend.Endpoints.SignOut(refreshToken: "r")

        #expect(apple.method == .post && apple.path.rawValue == "/v2/auth/apple" && !apple.requiresAuth)
        #expect(refresh.method == .post && refresh.path.rawValue == "/v2/auth/refresh" && !refresh.requiresAuth)
        #expect(signOut.method == .post && signOut.path.rawValue == "/v2/auth/signout" && signOut.requiresAuth)
        #expect(refresh.timeout == .seconds(10))
        #expect(signOut.timeout == .seconds(10))
        #expect(refresh.body == Backend.RefreshTokenBody(refreshToken: "r"))
        #expect(signOut.body == Backend.RefreshTokenBody(refreshToken: "r"))
        #expect([apple.idempotencyKey, refresh.idempotencyKey, signOut.idempotencyKey].allSatisfy { $0 == nil }, "sign-in and refresh are sent once")
    }

    @Test("the invite doors: check and redeem are authenticated POSTs with the code; only redeem carries the tear's key")
    func theInviteDoors() {
        let key = UUID()
        let check = Backend.Endpoints.InviteCheck(code: "7KQ2M9XD4RTAB")
        let redeem = Backend.Endpoints.InviteRedeem(code: "7KQ2M9XD4RTAB", key: key)

        #expect(check.method == .post && check.path.rawValue == "/v2/invites/check" && check.requiresAuth)
        #expect(check.idempotencyKey == nil, "a check is sent once and spends nothing")
        #expect(redeem.method == .post && redeem.path.rawValue == "/v2/invites/redeem" && redeem.requiresAuth)
        #expect(redeem.idempotencyKey == key)
        #expect(redeem.body == Backend.InviteCodeBody(code: "7KQ2M9XD4RTAB"))
        #expect(Backend.Endpoints.Access().path.rawValue == "/v2/access")
        #expect(Backend.Endpoints.JoinWaitlist(reason: nil).body == Backend.WaitlistBody(reason: nil))
        #expect(Backend.Endpoints.InvitesMine().method == .get)
    }

    @Test("answer guess is a keyed POST to /v2/guesses/:id with the verdict as its body")
    func answerGuessIsAKeyedPost() throws {
        let key = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000777"))
        let answer = Backend.Endpoints.AnswerGuess(guessID: "g1", content: .init(verdict: .no), key: key)

        #expect(answer.method == .post)
        #expect(answer.path == .guessByID)
        #expect(answer.path.rawValue == "/v2/guesses/:id")
        #expect(answer.pathParameters == ["id": "g1"])
        #expect(answer.requiresAuth)
        #expect(answer.idempotencyKey == key)
        #expect(try #require(String(data: Backend.Coding.encoder.encode(answer.body), encoding: .utf8)) == #"{"verdict":"no"}"#)
    }

    @Test("delete account is an authenticated DELETE to /v2/account, sent once, with the word and Apple's code")
    func deleteAccountIsAnAuthenticatedDeleteSentOnce() throws {
        let delete = Backend.Endpoints.DeleteAccount(appleAuthorizationCode: "c0de.fake.0000")

        #expect(delete.method == .delete)
        #expect(delete.path == .account)
        #expect(delete.path.rawValue == "/v2/account")
        #expect(delete.requiresAuth)
        #expect(delete.idempotencyKey == nil)
        #expect(delete.retry == .never)
        #expect(Backend.RetryPolicy.effective(delete.retry, method: .delete, hasIdempotencyKey: false).attempts == 1)
        #expect(delete.timeout == .seconds(30))
        let body = try #require(String(data: Backend.Coding.encoder.encode(delete.body), encoding: .utf8))
        #expect(body == #"{"appleAuthorizationCode":"c0de.fake.0000","confirm":"delete"}"# || body ==
            #"{"confirm":"delete","appleAuthorizationCode":"c0de.fake.0000"}"#)
    }

    @Test("the account door and the public preview are the doors a report never names")
    func theUnrecordedDoors() {
        #expect(Backend.unrecordedPaths == [.invitePreview, .account])
    }

    @Test("every path template is a /v2 path")
    func everyPathTemplateIsAV2Path() {
        #expect(Backend.PathTemplate.allCases.allSatisfy { $0.rawValue.hasPrefix("/v2/") || $0 == .invitePreview })
    }

    @Test("the library is an authenticated GET to /v2/podcasts; cursor and limit go in the query only when given")
    func theLibraryIsAGetWithItsPage() {
        let first = Backend.Endpoints.PodcastLibrary()
        let next = Backend.Endpoints.PodcastLibrary(cursor: "MjAyNi0xMC0xMQ", limit: 20)

        #expect(first.method == .get && first.path == .podcasts && first.path.rawValue == "/v2/podcasts" && first.requiresAuth)
        #expect(first.query.isEmpty)
        #expect(next.query == [URLQueryItem(name: "cursor", value: "MjAyNi0xMC0xMQ"), URLQueryItem(name: "limit", value: "20")])
        #expect(first.idempotencyKey == nil && first.retry == .read())
        #expect(Backend.Endpoints.PodcastLibrary(limit: 100).query == [URLQueryItem(name: "limit", value: "50")], "the door refuses more than 50")
        #expect(Backend.Endpoints.PodcastLibrary(limit: 0).query == [URLQueryItem(name: "limit", value: "1")])
    }

    @Test("one episode is an authenticated GET to /v2/episodes/:id with the id as its parameter")
    func episodeByIDIsAGetWithItsID() {
        let episode = Backend.Endpoints.EpisodeByID(id: "0b6f3a52-6c1e-4d0a-9b1e-2f7c0d4e9a01")

        #expect(episode.method == .get)
        #expect(episode.path == .episodeByID && episode.path.rawValue == "/v2/episodes/:id")
        #expect(episode.pathParameters == ["id": "0b6f3a52-6c1e-4d0a-9b1e-2f7c0d4e9a01"])
        #expect(episode.requiresAuth && episode.idempotencyKey == nil)
    }

    @Test("an onboarding answer is a POST keyed by its clientEntryId, retried with the same key, sent as the contract writes it")
    func anOnboardingAnswerIsKeyedByItsClientEntryID() throws {
        let id = try #require(UUID(uuidString: "B1F0C6A2-4C1E-4A57-9D34-0F8F6F2E1A02"))
        let body = Backend.Endpoints.OnboardingAnswer.Body(
            questionKey: .highLow, text: "", given: .skipped, clientEntryID: id, createdAt: Date(timeIntervalSince1970: 1_792_588_180)
        )
        let answer = Backend.Endpoints.OnboardingAnswer(body: body)

        #expect(answer.method == .post)
        #expect(answer.path == .onboardingAnswers && answer.path.rawValue == "/v2/onboarding/answers")
        #expect(answer.requiresAuth)
        #expect(answer.idempotencyKey == id, "the key is the answer's own id, so a retry can't make a second answer")
        #expect(answer.retry == .keyedWrite())
        let json = try #require(String(data: Backend.Coding.encoder.encode(answer.body), encoding: .utf8))
        #expect(json ==
            #"{"clientEntryId":"b1f0c6a2-4c1e-4a57-9d34-0f8f6f2e1a02","createdAt":"2026-10-21T13:09:40.000Z","given":"skipped","questionKey":"high.low","text":""}"#)
    }

    @Test("onboarding complete is an authenticated POST with an empty object as its body and no key")
    func onboardingCompleteIsAPostWithAnEmptyBody() throws {
        let complete = Backend.Endpoints.OnboardingComplete()

        #expect(complete.method == .post)
        #expect(complete.path == .onboardingComplete && complete.path.rawValue == "/v2/onboarding/complete")
        #expect(complete.requiresAuth && complete.idempotencyKey == nil)
        let body = try #require(complete.body)
        #expect(try #require(String(data: Backend.Coding.encoder.encode(body), encoding: .utf8)) == "{}")
    }
}
