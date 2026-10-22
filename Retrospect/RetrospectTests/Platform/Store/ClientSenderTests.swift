import Foundation
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ClientSenderTests {
    private struct Tokens: Backend.TokenProviding {
        func accessToken() async throws -> String { "token" }
        func refreshAfterUnauthorized(failedToken _: String) async throws -> String { "token" }
    }

    private let session = URLSession.stubbed()
    private let recorder = Platform.Log.Recorder()

    private func sender() -> Store.ClientSender {
        Store.ClientSender(client: Backend.Client(
            configuration: .resolve(.local, info: ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "42"], isRelease: false),
            session: session, tokens: Tokens(), reachability: ManualReachability(), clock: TestClock(), log: recorder
        ))
    }

    private func row() throws -> Store.OutboxRow {
        let id = "00000000-0000-4000-8000-000000000901"
        let body = try Backend.Endpoints.CreateEntry.Body(
            text: "dentist at 3", kind: .typed, clientEntryID: #require(UUID(uuidString: id)), createdAt: Date(timeIntervalSince1970: 1_792_569_000)
        )
        return try Store.OutboxRow(
            id: id, operation: .entryCreate, entityID: id, payload: Backend.Coding.encoder.encode(body), attempts: 2,
            nextAttemptAt: Date(timeIntervalSince1970: 1_792_569_604), status: .inFlight, lastErrorCode: nil,
            createdAt: Date(timeIntervalSince1970: 1_792_569_604)
        )
    }

    @Test("the stored bytes go out as the body, with the row's id as the Idempotency-Key, and the answer comes back as ids")
    func theStoredBytesGoOutWithTheKey() async throws {
        defer { StubProtocol.clear(session) }
        let row = try row()
        StubProtocol.register(on: session) { request in
            try (HTTPURLResponse.stub(request, status: 201), Fixtures.data("02", "entry.create.response"))
        }

        let result = try await sender().send(row)

        let request = try #require(StubProtocol.requests(on: session).first)
        #expect(request.value(forHTTPHeaderField: "Idempotency-Key") == row.id)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/v2/entries")
        #expect(request.httpBody == row.payload)
        #expect(result.serverID != nil)
        #expect(result.reading != nil)
    }

    @Test("a door's refusal comes back as the backend failure, for the drainer to settle")
    func aRefusalComesBackAsTheFailure() async throws {
        defer { StubProtocol.clear(session) }
        let row = try row()
        StubProtocol.register(on: session) { request in
            try (HTTPURLResponse.stub(request, status: 409), Fixtures.data("00", "error.idempotency_mismatch"))
        }

        await #expect(throws: Backend.Failure(.idempotencyMismatch)) { _ = try await sender().send(row) }
    }

    @Test("a payload that doesn't decode is an invalid request, never sent")
    func anUndecodablePayloadIsAnInvalidRequest() async throws {
        defer { StubProtocol.clear(session) }
        var row = try row()
        row.payload = Data("not json".utf8)

        await #expect(throws: Backend.Failure(.invalidRequest)) { _ = try await sender().send(row) }
        #expect(StubProtocol.requests(on: session).isEmpty)
    }
}
