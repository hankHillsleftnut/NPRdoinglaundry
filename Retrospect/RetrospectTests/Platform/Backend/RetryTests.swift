import Foundation
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct RetryTests {
    private struct Write: Backend.Endpoint {
        typealias Response = Backend.Meta
        var key: UUID?
        /// What the endpoint asks for; nil keeps the default.
        var requestedRetry: Backend.RetryPolicy?

        var retry: Backend.RetryPolicy {
            requestedRetry ?? .default(for: method, hasIdempotencyKey: key != nil)
        }

        var method: Backend.Method {
            .post
        }

        var path: Backend.PathTemplate {
            .meta
        }

        var body: Backend.NoBody? {
            Backend.NoBody()
        }

        var idempotencyKey: UUID? {
            key
        }

        var requiresAuth: Bool {
            false
        }

        var timeout: Duration {
            .seconds(300)
        }
    }

    private struct NoTokens: Backend.TokenProviding {
        func accessToken() async throws -> String { "t" }
        func refreshAfterUnauthorized(failedToken _: String) async throws -> String { "t" }
    }

    private let session = URLSession.stubbed()
    private let clock = TestClock()
    private let reachability = ManualReachability()
    private let recorder = Platform.Log.Recorder()

    private func client() -> Backend.Client {
        Backend.Client(
            configuration: .resolve(.local, info: [:], isRelease: false),
            session: session,
            tokens: NoTokens(),
            reachability: reachability,
            clock: clock,
            jitter: { _ in .zero },
            log: recorder
        )
    }

    /// Answers in turn with each status (200 serves the meta fixture), then repeats the last.
    private func serve(_ statuses: [Int], body: Data? = nil) throws {
        let meta = try Fixtures.data("00", "meta")
        let counter = Counter()
        StubProtocol.register(on: session) { request in
            let status = statuses[min(counter.next(), statuses.count - 1)]
            return (HTTPURLResponse.stub(request, status: status), status == 200 ? meta : body ?? Data())
        }
    }

    private func rateLimited(after seconds: Int) -> Data {
        Data(#"{"success":false,"error":{"code":"rate_limited","message":"Too many tries.","retryAfterSeconds":\#(seconds)}}"#.utf8)
    }

    @Test("a read retries on 503 then succeeds")
    func aReadRetriesOn503ThenSucceeds() async throws {
        defer { StubProtocol.clear(session) }
        try serve([503, 503, 200])

        let meta = try await client().send(Backend.Endpoints.Meta())

        #expect(meta.minVersion == "1.0 (40)")
        #expect(StubProtocol.requests(on: session).count == 3)
    }

    @Test("a read gives up after three attempts with the last failure")
    func aReadGivesUpAfterThreeAttempts() async throws {
        defer { StubProtocol.clear(session) }
        try serve([503, 502, 504])

        await #expect(throws: Backend.Failure(.upstreamTimeout)) { _ = try await client().send(Backend.Endpoints.Meta()) }
        #expect(StubProtocol.requests(on: session).count == 3)
    }

    @Test("a 500 or a 4xx is never retried", arguments: [500, 400, 404, 401])
    func a500OrA4xxIsNeverRetried(_ status: Int) async throws {
        defer { StubProtocol.clear(session) }
        try serve([status, 200])

        await #expect(throws: Backend.Failure.self) { _ = try await client().send(Backend.Endpoints.Meta()) }
        #expect(StubProtocol.requests(on: session).count == 1)
    }

    @Test("an unkeyed write is sent once even when its endpoint asks for retries")
    func anUnkeyedWriteCannotOptIntoRetries() async throws {
        defer { StubProtocol.clear(session) }
        try serve([503, 200])

        await #expect(throws: Backend.Failure(.upstreamUnavailable)) { _ = try await client().send(Write(key: nil, requestedRetry: .keyedWrite())) }
        #expect(StubProtocol.requests(on: session).count == 1)
    }

    @Test("a connection lost mid-flight is retried for a read and a keyed write", arguments: [false, true])
    func aConnectionLostMidFlightIsRetried(_ isWrite: Bool) async throws {
        defer { StubProtocol.clear(session) }
        let meta = try Fixtures.data("00", "meta")
        let counter = Counter()
        StubProtocol.register(on: session) { request in
            if counter.next() == 0 {
                throw URLError(.networkConnectionLost)
            }
            return (HTTPURLResponse.stub(request, status: 200), meta)
        }

        if isWrite {
            _ = try await client().send(Write(key: UUID()))
        } else {
            _ = try await client().send(Backend.Endpoints.Meta())
        }

        #expect(StubProtocol.requests(on: session).count == 2)
    }

    @Test("a connection lost mid-flight on an unkeyed write is not retried")
    func aConnectionLostOnAnUnkeyedWriteIsNotRetried() async throws {
        defer { StubProtocol.clear(session) }
        StubProtocol.register(on: session) { _ in throw URLError(.networkConnectionLost) }

        await #expect(throws: Backend.Failure(.offline)) { _ = try await client().send(Write(key: nil)) }
        #expect(StubProtocol.requests(on: session).count == 1)
    }

    @Test("still offline after the backoff, the client gives up without resending")
    func stillOfflineAfterTheBackoffGivesUp() async throws {
        defer { StubProtocol.clear(session) }
        let reachability = reachability
        StubProtocol.register(on: session) { _ in
            reachability.set(online: false)
            throw URLError(.notConnectedToInternet)
        }

        await #expect(throws: Backend.Failure(.offline)) { _ = try await client().send(Backend.Endpoints.Meta()) }
        #expect(StubProtocol.requests(on: session).count == 1)
    }

    @Test("an unkeyed write never retries")
    func anUnkeyedWriteNeverRetries() async throws {
        defer { StubProtocol.clear(session) }
        try serve([503, 200])

        await #expect(throws: Backend.Failure(.upstreamUnavailable)) { _ = try await client().send(Write(key: nil)) }
        #expect(StubProtocol.requests(on: session).count == 1)
    }

    @Test("a keyed write retries with the same Idempotency-Key and body")
    func aKeyedWriteRetriesWithTheSameKey() async throws {
        defer { StubProtocol.clear(session) }
        try serve([503, 200])
        let key = UUID()

        _ = try await client().send(Write(key: key))

        let sent = StubProtocol.requests(on: session)
        #expect(sent.count == 2)
        #expect(Set(sent.map { $0.value(forHTTPHeaderField: "Idempotency-Key") }) == [key.uuidString.lowercased()])
        #expect(sent[0].httpBody == sent[1].httpBody)
    }

    @Test("429 with retryAfter 2 s waits 2 s once, then succeeds")
    func a429WithAShortRetryAfterWaitsOnce() async throws {
        defer { StubProtocol.clear(session) }
        try serve([429, 200], body: rateLimited(after: 2))
        let start = clock.now
        let client = client()

        let send = Task { try await client.send(Backend.Endpoints.Meta()) }
        try await Self.waitUntil { clock.pendingSleeps == 1 }
        clock.advance(by: .seconds(1))
        #expect(clock.pendingSleeps == 1)
        clock.advance(by: .seconds(1))
        _ = try await send.value

        #expect(start.duration(to: clock.now) == .seconds(2))
        #expect(StubProtocol.requests(on: session).count == 2)
    }

    @Test("429 twice with a short retryAfter retries only once")
    func a429TwiceRetriesOnlyOnce() async throws {
        defer { StubProtocol.clear(session) }
        try serve([429, 429, 200], body: rateLimited(after: 0))

        await #expect(throws: Backend.Failure(.rateLimited(retryAfter: .seconds(0)))) { _ = try await client().send(Backend.Endpoints.Meta()) }
        #expect(StubProtocol.requests(on: session).count == 2)
    }

    @Test("429 with retryAfter 60 s surfaces rateLimited")
    func a429WithALongRetryAfterSurfaces() async throws {
        defer { StubProtocol.clear(session) }
        try serve([429, 200], body: rateLimited(after: 60))

        await #expect(throws: Backend.Failure(.rateLimited(retryAfter: .seconds(60)))) { _ = try await client().send(Backend.Endpoints.Meta()) }
        #expect(StubProtocol.requests(on: session).count == 1)
    }

    @Test("backoff delays stay within the jitter bounds", arguments: 1 ... 6)
    func backoffDelaysStayWithinTheJitterBounds(_ attempt: Int) {
        let policy = Backend.RetryPolicy.read(attempts: 10)
        let ceiling = Backend.RetryPolicy.backoffCeiling(attempt: attempt)

        let low = policy.retryDelay(after: Backend.Failure(.transport), attempt: attempt) { _ in .zero }
        let high = policy.retryDelay(after: Backend.Failure(.transport), attempt: attempt) { $0 }
        var generator = SeededGenerator(seed: UInt64(attempt))
        let drawn = (0 ..< 200).compactMap { _ in
            policy.retryDelay(after: Backend.Failure(.transport), attempt: attempt) { Backend.Client.fullJitter($0, using: &generator) }
        }

        #expect(low == .zero)
        #expect(high == min(.seconds(8), .milliseconds(500) * (1 << attempt)))
        #expect(ceiling <= .seconds(8))
        #expect(drawn.count == 200)
        #expect(drawn.allSatisfy { $0 >= .zero && $0 <= ceiling })
        #expect(Set(drawn).count > 100)
    }

    @Test("the backoff waits on the injected clock between sends")
    func theBackoffWaitsOnTheInjectedClock() async throws {
        defer { StubProtocol.clear(session) }
        try serve([503, 200])
        let client = Backend.Client(
            configuration: .resolve(.local, info: [:], isRelease: false), session: session, tokens: NoTokens(),
            reachability: reachability, clock: clock, jitter: { $0 }, log: recorder
        )

        let send = Task { try await client.send(Backend.Endpoints.Meta()) }
        try await Self.waitUntil { clock.pendingSleeps == 1 }
        #expect(StubProtocol.requests(on: session).count == 1)
        clock.advance(by: .seconds(1))
        _ = try await send.value

        #expect(StubProtocol.requests(on: session).count == 2)
    }

    @Test("offline short-circuits without a request")
    func offlineShortCircuitsWithoutARequest() async throws {
        defer { StubProtocol.clear(session) }
        try serve([200])
        reachability.set(online: false)

        await #expect(throws: Backend.Failure(.offline)) { _ = try await client().send(Backend.Endpoints.Meta()) }
        #expect(StubProtocol.requests(on: session).isEmpty)
        #expect(recorder.events.isEmpty)
    }

    @Test("the effective policy keeps an unkeyed write at never, whatever it asks for")
    func theEffectivePolicyKeepsUnkeyedWritesAtNever() {
        for method in [Backend.Method.post, .put, .patch, .delete] {
            #expect(Backend.RetryPolicy.effective(.keyedWrite(), method: method, hasIdempotencyKey: false) == .never)
            #expect(Backend.RetryPolicy.effective(.read(), method: method, hasIdempotencyKey: false) == .never)
            #expect(Backend.RetryPolicy.effective(.keyedWrite(), method: method, hasIdempotencyKey: true) == .keyedWrite())
        }
        #expect(Backend.RetryPolicy.effective(.read(), method: .get, hasIdempotencyKey: false) == .read())
    }

    @Test("defaults: reads retry, keyed writes retry, unkeyed writes never")
    func defaultPolicies() {
        #expect(Backend.RetryPolicy.default(for: .get, hasIdempotencyKey: false) == .read())
        #expect(Backend.RetryPolicy.default(for: .post, hasIdempotencyKey: true) == .keyedWrite())
        #expect(Backend.RetryPolicy.default(for: .post, hasIdempotencyKey: false) == .never)
        #expect(Backend.RetryPolicy.default(for: .delete, hasIdempotencyKey: false) == .never)
        #expect(Backend.Endpoints.Meta().retry == .read())
    }

    @Test("a long endpoint timeout is capped at sixty seconds")
    func aLongEndpointTimeoutIsCapped() async throws {
        let request = try await client().request(for: Write(key: nil), token: nil)
        #expect(request.timeoutInterval == 60)
    }

    /// Yields until `condition` holds. No deadline of its own: the suite's
    /// time limit ends a wait that never comes true.
    private static func waitUntil(_ condition: () -> Bool) async throws {
        while !condition() {
            try Task.checkCancellation()
            await Task.yield()
        }
    }
}

/// SplitMix64: the same numbers for the same seed.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func next() -> Int {
        lock.withLock {
            defer { value += 1 }
            return value
        }
    }
}
