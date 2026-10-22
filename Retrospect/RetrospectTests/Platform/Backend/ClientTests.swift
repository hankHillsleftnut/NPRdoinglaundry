import Foundation
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ClientTests {
    private struct Tokens: Backend.TokenProviding {
        var token = "token-1"
        var fails: (any Error)?

        func accessToken() async throws -> String {
            if let fails {
                throw fails
            }
            return token
        }

        func refreshAfterUnauthorized(failedToken _: String) async throws -> String {
            token
        }
    }

    /// A write with a body, a key and a path parameter. Its template is the
    /// meta path, since the enum only has real doors; the tests that need a
    /// parameter use `fill` directly.
    private struct Write: Backend.Endpoint {
        struct Payload: Encodable, Sendable {
            let text: String
            let sentAt: Date
        }

        typealias Response = Backend.Meta
        let key: UUID
        var method: Backend.Method {
            .post
        }

        var path: Backend.PathTemplate {
            .meta
        }

        var body: Payload? {
            Payload(text: "invented", sentAt: Date(timeIntervalSince1970: 1_792_569_604.2))
        }

        var idempotencyKey: UUID? {
            key
        }

        var query: [URLQueryItem] {
            [URLQueryItem(name: "limit", value: "20")]
        }

        var timeout: Duration {
            .seconds(7)
        }
    }

    private let session = URLSession.stubbed()
    private let recorder = Platform.Log.Recorder()
    private let configuration = Backend.Configuration.resolve(.local, info: ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "42"], isRelease: false)

    private func client(tokens: Tokens = Tokens()) -> Backend.Client {
        Backend.Client(
            configuration: configuration,
            session: session,
            tokens: tokens,
            reachability: ManualReachability(),
            clock: TestClock(),
            jitter: { _ in .zero },
            log: recorder,
            timeZone: { TimeZone(identifier: "America/Los_Angeles") ?? .gmt },
            languages: { ["en-GB", "fr"] }
        )
    }

    private func serve(status: Int = 200, _ data: Data) {
        StubProtocol.register(on: session) { (HTTPURLResponse.stub($0, status: status), data) }
    }

    /// Runs `body` and returns the error it threw, failing unless it is a `Backend.Failure`.
    private func failure(_ body: () async throws -> Void) async -> Backend.Failure? {
        do {
            try await body()
            Issue.record("expected a failure")
            return nil
        } catch let failure as Backend.Failure {
            return failure
        } catch {
            Issue.record("threw \(type(of: error)), not Backend.Failure")
            return nil
        }
    }

    // MARK: Success

    @Test("meta is fetched and decoded from its fixture")
    func metaIsFetchedAndDecoded() async throws {
        defer { StubProtocol.clear(session) }
        try serve(Fixtures.data("00", "meta"))

        let meta = try await client().send(Backend.Endpoints.Meta())

        #expect(meta.latestVersion == "1.1 (55)")
        let sent = try #require(StubProtocol.requests(on: session).first)
        #expect(sent.url?.absoluteString == "http://localhost:3000/v2/meta")
        #expect(sent.httpMethod == "GET")
    }

    // MARK: Failures

    @Test("every error fixture sent with its status throws the matching failure", arguments: FailureTests.errorFixtures)
    func everyErrorFixtureThrowsTheMatchingFailure(_ fixture: String) async throws {
        defer { StubProtocol.clear(session) }
        let parts = fixture.split(separator: "/").map(String.init)
        let data = try Fixtures.data(parts[0], parts[1])
        let body = try Backend.Coding.decoder.decode(Backend.ErrorBody.self, from: data)
        serve(status: 400, data)

        let thrown = await failure { _ = try await client().send(Backend.Endpoints.Meta()) }

        #expect(thrown == Backend.Failure(body))
        #expect(thrown?.message == body.message)
    }

    @Test("a 500 with a body that isn't JSON maps to internal")
    func a500WithANonJSONBodyMapsToInternal() async {
        defer { StubProtocol.clear(session) }
        serve(status: 500, Data("<html>bad gateway</html>".utf8))

        let thrown = await failure { _ = try await client().send(Backend.Endpoints.Meta()) }

        #expect(thrown?.kind == .internal)
    }

    @Test("statuses without a contract body map to what they mean", arguments: [
        (400, Backend.Failure.Kind.invalidRequest), (401, .unauthenticated), (404, .notFound), (426, .updateRequired),
        (408, .timedOut), (429, .rateLimited(retryAfter: nil)), (502, .upstreamUnavailable), (503, .upstreamUnavailable), (504, .upstreamTimeout),
        (500, .internal), (418, .unknown(code: "http_418")),
    ])
    func statusesWithoutAContractBody(_ status: Int, _ kind: Backend.Failure.Kind) async {
        defer { StubProtocol.clear(session) }
        serve(status: status, Data())

        let thrown = await failure { _ = try await client().send(Backend.Endpoints.Meta()) }

        #expect(thrown?.kind == kind)
    }

    @Test("a malformed success body maps to decoding")
    func aMalformedSuccessBodyMapsToDecoding() async {
        defer { StubProtocol.clear(session) }
        serve(Data(#"{"success":true,"data":{"minVersion":"1.0 (1)"}}"#.utf8))

        let thrown = await failure { _ = try await client().send(Backend.Endpoints.Meta()) }

        #expect(thrown?.kind == .decoding)
    }

    @Test("with the network down the failure is offline, and the request is logged with no status")
    func withTheNetworkDownTheFailureIsOffline() async {
        defer { StubProtocol.clear(session) }
        StubProtocol.register(on: session) { _ in throw URLError(.notConnectedToInternet) }

        let thrown = await failure { _ = try await client().send(Backend.Endpoints.Meta()) }

        #expect(thrown?.kind == .offline)
        #expect(recorder.events == [.requestSent(path: .meta, status: 0, ms: 0)])
    }

    @Test("transport errors map to offline, timed out or transport", arguments: [
        (URLError.Code.networkConnectionLost, Backend.Failure.Kind.offline),
        (.dataNotAllowed, .offline),
        (.timedOut, .timedOut),
        (.cannotConnectToHost, .transport),
        (.secureConnectionFailed, .transport),
    ])
    func transportErrorsMap(_ code: URLError.Code, _ kind: Backend.Failure.Kind) async {
        defer { StubProtocol.clear(session) }
        StubProtocol.register(on: session) { _ in throw URLError(code) }

        let thrown = await failure { _ = try await client().send(Backend.Endpoints.Meta()) }

        #expect(thrown?.kind == kind)
    }

    @Test("a token that can't be had fails as unauthenticated, before anything is sent")
    func aTokenThatCantBeHadFailsAsUnauthenticated() async {
        defer { StubProtocol.clear(session) }
        serve(Data())
        let client = client(tokens: Tokens(fails: URLError(.unknown)))

        let thrown = await failure { _ = try await client.send(Write(key: UUID())) }

        #expect(thrown?.kind == .unauthenticated)
        #expect(StubProtocol.requests(on: session).isEmpty)
    }

    @Test("a token provider's own failure passes through")
    func aTokenProvidersOwnFailurePassesThrough() async {
        let client = client(tokens: Tokens(fails: Backend.Failure(.sessionRevoked)))

        let thrown = await failure { _ = try await client.send(Write(key: UUID())) }

        #expect(thrown?.kind == .sessionRevoked)
    }

    @Test("a cancelled transfer throws cancellation, not a failure")
    func aCancelledTransferThrowsCancellation() async {
        defer { StubProtocol.clear(session) }
        StubProtocol.register(on: session) { _ in throw URLError(.cancelled) }

        await #expect(throws: CancellationError.self) { _ = try await client().send(Backend.Endpoints.Meta()) }
    }

    // MARK: Headers and body

    @Test("authenticated requests carry the five headers")
    func authenticatedRequestsCarryTheFiveHeaders() async throws {
        defer { StubProtocol.clear(session) }
        try serve(Fixtures.data("00", "meta"))
        let key = UUID()

        _ = try await client().send(Write(key: key))

        let sent = try #require(StubProtocol.requests(on: session).first)
        #expect(sent.value(forHTTPHeaderField: "Authorization") == "Bearer token-1")
        #expect(sent.value(forHTTPHeaderField: "X-App-Version") == "1.0 (42)")
        #expect(sent.value(forHTTPHeaderField: "X-Time-Zone") == "America/Los_Angeles")
        #expect(sent.value(forHTTPHeaderField: "Accept-Language") == "en-GB, fr;q=0.9")
        #expect(sent.value(forHTTPHeaderField: "Idempotency-Key") == key.uuidString.lowercased())
        #expect(sent.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(sent.httpMethod == "POST")
        #expect(sent.timeoutInterval == 7)
        #expect(sent.url?.query == "limit=20")
        #expect(sent.httpBody.flatMap { String(bytes: $0, encoding: .utf8) } == #"{"sentAt":"2026-10-21T08:00:04.200Z","text":"invented"}"#)
    }

    @Test("public requests carry no Authorization and no body headers")
    func publicRequestsCarryNoAuthorization() async throws {
        defer { StubProtocol.clear(session) }
        try serve(Fixtures.data("00", "meta"))

        _ = try await client(tokens: Tokens(fails: URLError(.unknown))).send(Backend.Endpoints.Meta())

        let sent = try #require(StubProtocol.requests(on: session).first)
        #expect(sent.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(sent.value(forHTTPHeaderField: "Content-Type") == nil)
        #expect(sent.value(forHTTPHeaderField: "Idempotency-Key") == nil)
        #expect(sent.value(forHTTPHeaderField: "X-App-Version") == "1.0 (42)")
        #expect(sent.value(forHTTPHeaderField: "X-Time-Zone") == "America/Los_Angeles")
    }

    @Test("path parameters are percent-encoded as one segment each")
    func pathParametersArePercentEncoded() throws {
        #expect(try Backend.Client.fill("/v2/entries/:id", with: ["id": "a b/c?d"]) == "/v2/entries/a%20b%2Fc%3Fd")
        #expect(try Backend.Client.fill("/v2/guesses/:id/answer", with: ["id": "7f0c"]) == "/v2/guesses/7f0c/answer")
        #expect(try Backend.Client.fill("/v2/meta", with: [:]) == "/v2/meta")
    }

    @Test("a missing path parameter is an invalid request")
    func aMissingPathParameterIsAnInvalidRequest() {
        #expect(throws: Backend.Failure(.invalidRequest)) { try Backend.Client.fill("/v2/entries/:id", with: [:]) }
    }

    @Test("Accept-Language lists at most five languages with falling weights")
    func acceptLanguageListsAtMostFive() {
        #expect(Backend.Client.acceptLanguage([]) == "en")
        #expect(Backend.Client.acceptLanguage(["a", "b", "c", "d", "e", "f"]) == "a, b;q=0.9, c;q=0.8, d;q=0.7, e;q=0.6")
    }

    // MARK: Logging

    @Test("the log records the path template and status, never the URL")
    func theLogRecordsThePathTemplate() async throws {
        defer { StubProtocol.clear(session) }
        try serve(Fixtures.data("00", "meta"))

        _ = try await client().send(Backend.Endpoints.Meta())

        #expect(recorder.events == [.requestSent(path: .meta, status: 200, ms: 0)])
    }

    @Test("an unknown error code is logged as a kind, with no text")
    func anUnknownErrorCodeIsLoggedWithNoText() async {
        defer { StubProtocol.clear(session) }
        serve(status: 400, Data(#"{"success":false,"error":{"code":"brand_new","message":"invented words"}}"#.utf8))

        let thrown = await failure { _ = try await client().send(Backend.Endpoints.Meta()) }

        #expect(thrown?.kind == .unknown(code: "brand_new"))
        #expect(recorder.events == [.requestSent(path: .meta, status: 400, ms: 0), .unknownErrorCode(path: .meta)])
    }

    @Test("the client's own session shares nothing and never waits or caches")
    func theClientsOwnSessionSharesNothing() {
        let configuration = Backend.Client.makeSession().configuration
        #expect(configuration.waitsForConnectivity == false)
        #expect(configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
        #expect(configuration.urlCache == nil)
        #expect(configuration.httpCookieStorage == nil)
    }
}
