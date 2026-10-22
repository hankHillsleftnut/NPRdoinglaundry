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

    @Test("the entry answer's server createdAt and day come back with the ids")
    func theAnswersDatesComeBack() async throws {
        defer { StubProtocol.clear(session) }
        StubProtocol.register(on: session) { request in
            try (HTTPURLResponse.stub(request, status: 201), Fixtures.data("02", "entry.create.response"))
        }

        let result = try await sender().send(row())

        #expect(result.day == "2026-10-21")
        #expect(try abs(#require(result.createdAt).timeIntervalSince(Date(timeIntervalSince1970: 1_792_587_731.41))) < 0.001)
    }

    @Test("a guess answer goes to POST /v2/guesses/:id with its verdict and the row's id as the key, and writes nothing back")
    func aGuessAnswerGoesToItsDoor() async throws {
        defer { StubProtocol.clear(session) }
        let key = "00000000-0000-4000-8000-000000000777"
        let row = try Store.OutboxRow(
            id: key, operation: .guessAnswer, entityID: "guess 1", payload: Backend.Coding.encoder.encode(Backend.Endpoints.AnswerGuess.Body(verdict: .yes)),
            attempts: 0, nextAttemptAt: Date(timeIntervalSince1970: 1_792_569_604), status: .inFlight, lastErrorCode: nil,
            createdAt: Date(timeIntervalSince1970: 1_792_569_604)
        )
        StubProtocol.register(on: session) { request in
            try (HTTPURLResponse.stub(request, status: 200), Fixtures.data("02", "guess.answer"))
        }

        let result = try await sender().send(row)

        let request = try #require(StubProtocol.requests(on: session).first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/v2/guesses/guess%201" || request.url?.path == "/v2/guesses/guess 1")
        #expect(request.value(forHTTPHeaderField: "Idempotency-Key") == key)
        #expect(request.httpBody == row.payload)
        #expect(result == Store.OutboxSendResult())
    }

    @Test("a queued report goes to POST /v2/diagnostics with its id as the key, the stored bytes as the body, and its reference comes back")
    func aReportGoesToItsDoor() async throws {
        defer { StubProtocol.clear(session) }
        let report = try JSONDecoder.contract.decode(Platform.Diagnostics.Report.self, from: Fixtures.data("00", "diagnostics.request"))
        let payload = try Backend.Coding.encoder.encode(report)
        let row = Store.OutboxRow(
            id: report.reportId, operation: .diagnosticsSend, entityID: report.reportId, payload: payload, attempts: 0,
            nextAttemptAt: Date(timeIntervalSince1970: 1_792_569_604), status: .inFlight, lastErrorCode: nil,
            createdAt: Date(timeIntervalSince1970: 1_792_569_604)
        )
        StubProtocol.register(on: session) { request in
            try (HTTPURLResponse.stub(request, status: 200), Fixtures.data("00", "diagnostics.response"))
        }

        let result = try await sender().send(row)

        let request = try #require(StubProtocol.requests(on: session).first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/v2/diagnostics")
        #expect(request.value(forHTTPHeaderField: "Idempotency-Key") == report.reportId)
        #expect(request.httpBody == payload)
        #expect(result.reference == "r-7KQ2")
        #expect(result.serverID == nil)
    }

    @Test("a stored report that no longer decodes, or whose id isn't its row's, is refused without a request")
    func aBrokenReportIsNotSent() async throws {
        defer { StubProtocol.clear(session) }
        let report = try JSONDecoder.contract.decode(Platform.Diagnostics.Report.self, from: Fixtures.data("00", "diagnostics.request"))
        let at = Date(timeIntervalSince1970: 1_792_569_604)
        let garbled = Store.OutboxRow(
            id: report.reportId, operation: .diagnosticsSend, entityID: report.reportId, payload: Data("{}".utf8), attempts: 0,
            nextAttemptAt: at, status: .inFlight, lastErrorCode: nil, createdAt: at
        )
        let mismatched = try Store.OutboxRow(
            id: "00000000-0000-4000-8000-000000000555", operation: .diagnosticsSend, entityID: report.reportId,
            payload: Backend.Coding.encoder.encode(report), attempts: 0, nextAttemptAt: at, status: .inFlight, lastErrorCode: nil, createdAt: at
        )

        for row in [garbled, mismatched] {
            await #expect(throws: Backend.Failure.self) { try await sender().send(row) }
        }

        #expect(StubProtocol.requests(on: session).isEmpty)
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
