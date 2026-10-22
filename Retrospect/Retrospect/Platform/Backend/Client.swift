import Foundation

extension Backend {
    /// Gives the client an access token, and a new one after a 401. The session
    /// (PL1.5) implements it; until then tests and previews pass their own.
    protocol TokenProviding: Sendable {
        func accessToken() async throws -> String
        func refreshAfterUnauthorized(failedToken: String) async throws -> String
    }

    /// The one way new code talks to the `/v2` doors.
    ///
    /// `send` throws only `Backend.Failure`, with one exception: if the calling
    /// task is cancelled it throws `CancellationError`, so a cancelled caller
    /// stops instead of treating it as a failed request.
    actor Client {
        private let configuration: Configuration
        private let session: URLSession
        private let tokens: any TokenProviding
        private let clock: any Clock<Duration>
        private let log: any Platform.LogSink
        private let diagnostics: (any Platform.Diagnostics.Sink)?
        private let timeZone: @Sendable () -> TimeZone
        private let languages: @Sendable () -> [String]

        init(
            configuration: Configuration,
            session: URLSession = Client.makeSession(),
            tokens: any TokenProviding,
            clock: any Clock<Duration> = ContinuousClock(),
            log: any Platform.LogSink,
            diagnostics: (any Platform.Diagnostics.Sink)? = nil,
            timeZone: @escaping @Sendable () -> TimeZone = { .current },
            languages: @escaping @Sendable () -> [String] = { Locale.preferredLanguages }
        ) {
            self.configuration = configuration
            self.session = session
            self.tokens = tokens
            self.clock = clock
            self.log = log
            self.diagnostics = diagnostics
            self.timeZone = timeZone
            self.languages = languages
        }

        /// Its own ephemeral session: no shared cookies or cache, no waiting for
        /// a connection (the outbox decides when to try again), never a cached answer.
        static func makeSession() -> URLSession {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.waitsForConnectivity = false
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.urlCache = nil
            configuration.httpCookieStorage = nil
            return URLSession(configuration: configuration)
        }

        func send<E: Endpoint>(_ endpoint: E) async throws -> E.Response {
            let token = endpoint.requiresAuth ? try await accessToken() : nil
            let request = try request(for: endpoint, token: token)
            let loaded = await load(request, path: endpoint.path)
            switch loaded {
            case let .failed(error, ms):
                if error is Failure {
                    await record(endpoint, status: 0, ms: ms, code: nil)
                }
                throw error
            case let .answered(data, status, ms):
                do {
                    let response = try decode(E.Response.self, from: data, status: status, path: endpoint.path)
                    await record(endpoint, status: status, ms: ms, code: nil)
                    return response
                } catch let failure as Failure {
                    await record(endpoint, status: status, ms: ms, code: failure.kind.diagnosticsCode)
                    throw failure
                }
            }
        }

        /// The request's diagnostics row (DG.4): the route template, status,
        /// time and the contract code if the door sent one. Never the URL, the
        /// body or the message.
        private func record(_ endpoint: some Endpoint, status: Int, ms: Int, code: Platform.Diagnostics.ErrorCode?) async {
            guard let diagnostics else { return }
            await diagnostics.record(.request(Platform.Diagnostics.Request(
                method: endpoint.method, route: Platform.Diagnostics.Route(endpoint.path), status: status, code: code, ms: ms
            )))
        }

        // MARK: Building the request

        /// The URL request for `endpoint`: its filled-in path, query, headers and body.
        func request(for endpoint: some Endpoint, token: String?) throws -> URLRequest {
            let path = try Self.fill(endpoint.path.rawValue, with: endpoint.pathParameters)
            guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
                throw Failure(.invalidRequest)
            }
            components.percentEncodedPath = path
            components.queryItems = endpoint.query.isEmpty ? nil : endpoint.query
            guard let url = components.url else { throw Failure(.invalidRequest) }

            var request = URLRequest(url: url)
            request.httpMethod = endpoint.method.rawValue
            request.timeoutInterval = TimeInterval(endpoint.timeout.components.seconds)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue(configuration.appVersion, forHTTPHeaderField: "X-App-Version")
            request.setValue(timeZone().identifier, forHTTPHeaderField: "X-Time-Zone")
            request.setValue(Self.acceptLanguage(languages()), forHTTPHeaderField: "Accept-Language")
            if let token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            if let key = endpoint.idempotencyKey {
                request.setValue(key.uuidString.lowercased(), forHTTPHeaderField: "Idempotency-Key")
            }
            if let body = endpoint.body {
                do {
                    request.httpBody = try Coding.encoder.encode(body)
                } catch {
                    throw Failure(.invalidRequest)
                }
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            return request
        }

        /// `/v2/entries/:id` with `["id": "a b"]` → `/v2/entries/a%20b`. Every
        /// parameter is percent-encoded as one path segment; a missing one is a bug.
        static func fill(_ template: String, with parameters: [String: String]) throws -> String {
            let segments = try template.split(separator: "/", omittingEmptySubsequences: false).map { segment -> String in
                guard segment.hasPrefix(":") else { return String(segment) }
                guard let value = parameters[String(segment.dropFirst())],
                      let encoded = value.addingPercentEncoding(withAllowedCharacters: unreserved)
                else {
                    throw Failure(.invalidRequest)
                }
                return encoded
            }
            return segments.joined(separator: "/")
        }

        /// RFC 3986 unreserved characters: everything else in a segment is encoded.
        private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

        /// The device's languages, most preferred first, with falling weights:
        /// `en-GB, fr;q=0.9, de;q=0.8`. At most five.
        static func acceptLanguage(_ languages: [String]) -> String {
            let chosen = languages.prefix(5)
            guard !chosen.isEmpty else { return "en" }
            return chosen.enumerated().map { index, language in
                index == 0 ? language : "\(language);q=0.\(10 - index)"
            }.joined(separator: ", ")
        }

        // MARK: Sending and reading

        private func accessToken() async throws -> String {
            do {
                return try await tokens.accessToken()
            } catch let failure as Failure {
                throw failure
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw Failure(.unauthenticated)
            }
        }

        /// What came back from one send, with the time it took.
        private enum Loaded {
            case answered(Data, status: Int, ms: Int)
            /// A `Failure`, or `CancellationError` when the caller was cancelled.
            case failed(any Error, ms: Int)
        }

        /// Sends `request` and logs it, whatever happens: the door, the status (0
        /// when nothing came back) and the time on the injected clock.
        private func load(_ request: URLRequest, path: PathTemplate) async -> Loaded {
            var outcome: Result<(Data, URLResponse), any Error> = .failure(Failure(.transport))
            let elapsed = await clock.measure {
                do {
                    outcome = try await .success(session.data(for: request))
                } catch {
                    outcome = .failure(error)
                }
            }
            let ms = Self.milliseconds(elapsed)
            switch outcome {
            case let .success((data, response as HTTPURLResponse)):
                log.record(.requestSent(path: path, status: response.statusCode, ms: ms))
                return .answered(data, status: response.statusCode, ms: ms)
            case .success:
                log.record(.requestSent(path: path, status: 0, ms: ms))
                return .failed(Failure(.transport), ms: ms)
            case let .failure(error):
                log.record(.requestSent(path: path, status: 0, ms: ms))
                return .failed(Self.failure(for: error), ms: ms)
            }
        }

        private func decode<Response: Decodable>(_: Response.Type, from data: Data, status: Int, path: PathTemplate) throws -> Response {
            if (200 ..< 300).contains(status), let envelope = try? Coding.decoder.decode(Envelope<Response>.self, from: data) {
                return envelope.data
            }
            if let body = try? Coding.decoder.decode(ErrorBody.self, from: data) {
                let failure = Failure(body)
                if case .unknown = failure.kind {
                    log.record(.unknownErrorCode(path: path))
                }
                throw failure
            }
            throw Failure((200 ..< 300).contains(status) ? .decoding : Self.kind(status: status))
        }

        /// A failure for an error status whose body isn't the contract's. Only
        /// statuses that mean one thing are named; any other 4xx is unknown.
        static func kind(status: Int) -> Failure.Kind {
            switch status {
            case 400: .invalidRequest
            case 401: .unauthenticated
            case 404: .notFound
            case 426: .updateRequired
            case 429: .rateLimited(retryAfter: nil)
            case 502, 503: .upstreamUnavailable
            case 504: .upstreamTimeout
            case 500...: .internal
            default: .unknown(code: "http_\(status)")
            }
        }

        /// What a thrown transport error means. Cancellation stays cancellation.
        static func failure(for error: any Error) -> any Error {
            if error is Failure || error is CancellationError {
                return error
            }
            guard let urlError = error as? URLError else { return Failure(.transport) }
            switch urlError.code {
            case .cancelled: return CancellationError()
            case .timedOut: return Failure(.timedOut)
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff, .callIsActive:
                return Failure(.offline)
            default: return Failure(.transport)
            }
        }

        private static func milliseconds(_ duration: Duration) -> Int {
            let (seconds, attoseconds) = duration.components
            return Int(seconds) * 1000 + Int(attoseconds / 1_000_000_000_000_000)
        }
    }
}
