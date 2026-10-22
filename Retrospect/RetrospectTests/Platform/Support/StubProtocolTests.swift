import Foundation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct StubProtocolTests {
    private let url = URL(string: "https://stub.invalid/v2/meta")!

    @Test("a stubbed session returns the registered response")
    func aStubbedSessionReturnsTheRegisteredResponse() async throws {
        let session = URLSession.stubbed()
        defer { StubProtocol.clear(session) }
        StubProtocol.register(on: session) { request in
            (HTTPURLResponse.stub(request, status: 201), Data(#"{"ok":true}"#.utf8))
        }

        let (data, response) = try await session.data(from: url)

        #expect((response as? HTTPURLResponse)?.statusCode == 201)
        #expect(data == Data(#"{"ok":true}"#.utf8))
        #expect(StubProtocol.requests(on: session).map(\.url) == [url])
    }

    @Test("a request with no registered stub fails loudly")
    func aRequestWithNoRegisteredStubFailsLoudly() async throws {
        let session = URLSession.stubbed()
        defer { StubProtocol.clear(session) }

        let error = await #expect(throws: (any Error).self) { try await session.data(from: url) }

        let reported = try #require(error as NSError?)
        #expect(reported.domain == StubProtocol.Failure.errorDomain)
        #expect(reported.localizedDescription == StubProtocol.Failure.noStub(method: "GET", url: url.absoluteString).description)
        #expect(reported.localizedDescription.contains("no stub registered for GET https://stub.invalid/v2/meta"))
    }

    @Test("two stubbed sessions never see each other's stubs or requests")
    func twoStubbedSessionsNeverSeeEachOthersStubs() async throws {
        let first = URLSession.stubbed()
        let second = URLSession.stubbed()
        defer {
            StubProtocol.clear(first)
            StubProtocol.clear(second)
        }
        StubProtocol.register(on: first) { (HTTPURLResponse.stub($0), Data("first".utf8)) }
        StubProtocol.register(on: second) { (HTTPURLResponse.stub($0), Data("second".utf8)) }

        let (firstData, _) = try await first.data(from: url)
        let (secondData, _) = try await second.data(from: url)

        #expect(firstData == Data("first".utf8))
        #expect(secondData == Data("second".utf8))
        #expect(StubProtocol.requests(on: first).count == 1)
        #expect(StubProtocol.requests(on: second).count == 1)
    }

    @Test("the request log keeps the method, headers and body that were sent")
    func theRequestLogKeepsWhatWasSent() async throws {
        let session = URLSession.stubbed()
        defer { StubProtocol.clear(session) }
        StubProtocol.register(on: session) { (HTTPURLResponse.stub($0), Data()) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("key-1", forHTTPHeaderField: "Idempotency-Key")
        let body = Data(#"{"text":"invented"}"#.utf8)
        request.httpBody = body

        _ = try await session.data(for: request)

        let sent = try #require(StubProtocol.requests(on: session).first)
        #expect(sent.httpMethod == "POST")
        #expect(sent.value(forHTTPHeaderField: "Idempotency-Key") == "key-1")
        #expect(sent.httpBody == body)
    }

    @Test("a cleared session has no stub and no log")
    func aClearedSessionHasNoStubAndNoLog() async throws {
        let session = URLSession.stubbed()
        StubProtocol.register(on: session) { (HTTPURLResponse.stub($0), Data()) }
        _ = try await session.data(from: url)

        StubProtocol.clear(session)

        #expect(StubProtocol.requests(on: session).isEmpty)
        await #expect(throws: (any Error).self) { try await session.data(from: url) }
        StubProtocol.clear(session)
    }
}
