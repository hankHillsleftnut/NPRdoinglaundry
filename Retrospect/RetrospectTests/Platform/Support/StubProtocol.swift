import Foundation

/// A `URLProtocol` that answers requests from handlers registered by each test,
/// so no test ever reaches the network.
///
/// Each `URLSession.stubbed()` carries its own id in a header; handlers and the
/// request log are kept per id, so tests running side by side never see each
/// other's stubs. A request with no handler fails with `StubProtocol.Failure`.
final class StubProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    static let sessionHeader = "X-Stub-Session"

    /// URLSession hands a protocol's error back as an `NSError`, so the
    /// message travels in its domain and description.
    enum Failure: Error, CustomStringConvertible, CustomNSError, Equatable {
        case noStub(method: String, url: String)
        case unstubbedSession

        var description: String {
            switch self {
            case let .noStub(method, url): "StubProtocol: no stub registered for \(method) \(url)"
            case .unstubbedSession: "StubProtocol: the request didn't come from URLSession.stubbed()"
            }
        }

        static let errorDomain = "StubProtocol"
        var errorUserInfo: [String: Any] {
            [NSLocalizedDescriptionKey: description]
        }
    }

    private struct Entry {
        var handler: Handler?
        var requests: [URLRequest] = []
    }

    private static let lock = NSLock()
    private static var entries: [String: Entry] = [:]

    /// Answers every request on `session` with `handler`, replacing any earlier one.
    static func register(on session: URLSession, _ handler: @escaping Handler) {
        guard let id = id(of: session) else { return }
        lock.withLock { entries[id, default: Entry()].handler = handler }
    }

    /// Every request `session` sent, in order, with its body read in.
    static func requests(on session: URLSession) -> [URLRequest] {
        guard let id = id(of: session) else { return [] }
        return lock.withLock { entries[id]?.requests ?? [] }
    }

    /// Forgets the session's handler and request log.
    static func clear(_ session: URLSession) {
        guard let id = id(of: session) else { return }
        _ = lock.withLock { entries.removeValue(forKey: id) }
    }

    private static func id(of session: URLSession) -> String? {
        session.configuration.httpAdditionalHeaders?[sessionHeader] as? String
    }

    // MARK: URLProtocol

    override static func canInit(with _: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let recorded = Self.withBody(request)
        do {
            guard let id = recorded.value(forHTTPHeaderField: Self.sessionHeader) else { throw Failure.unstubbedSession }
            let handler = Self.lock.withLock { () -> Handler? in
                Self.entries[id, default: Entry()].requests.append(recorded)
                return Self.entries[id]?.handler
            }
            guard let handler else {
                throw Failure.noStub(method: recorded.httpMethod ?? "GET", url: recorded.url?.absoluteString ?? "")
            }
            let (response, data) = try handler(recorded)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    /// URLSession moves a body into a stream before a protocol sees it; read it
    /// back so tests can assert on what was sent. Upload tasks' bodies never
    /// reach a protocol at all, so code under test sends `httpBody` with `data(for:)`.
    private static func withBody(_ request: URLRequest) -> URLRequest {
        guard request.httpBody == nil, let stream = request.httpBodyStream else { return request }
        var copy = request
        var body = Data()
        let size = 16384
        var buffer = [UInt8](repeating: 0, count: size)
        stream.open()
        defer { stream.close() }
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: size)
            guard read > 0 else { break }
            body.append(buffer, count: read)
        }
        copy.httpBody = body // also drops the spent stream: the two are one property
        return copy
    }
}

extension URLSession {
    /// An ephemeral session whose every request goes to `StubProtocol`, tagged
    /// with an id of its own. Register its answers with `StubProtocol.register(on:_:)`.
    static func stubbed() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        configuration.httpAdditionalHeaders = [StubProtocol.sessionHeader: UUID().uuidString]
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }
}

extension HTTPURLResponse {
    /// A response for stubs: `status` for `request`'s URL, JSON by default.
    static func stub(_ request: URLRequest, status: Int = 200, headers: [String: String] = ["Content-Type": "application/json"]) -> HTTPURLResponse {
        // A URL and an HTTP version always make a response; the initializer is
        // only failable for its Objective-C heritage.
        HTTPURLResponse(url: request.url ?? URL(fileURLWithPath: "/"), statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers) ?? HTTPURLResponse()
    }
}
