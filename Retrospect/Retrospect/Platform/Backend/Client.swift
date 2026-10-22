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
    ///
    /// Offline, it fails at once without sending. Otherwise it sends up to the
    /// endpoint's `retry` attempts, waiting a jittered backoff on the injected
    /// clock between them, and gives up with `.offline` if the phone has gone
    /// offline by then. A keyed write resends the same request, key included;
    /// a write without a key is sent once, whatever its endpoint says.
    actor Client {
        private let configuration: Configuration
        private let session: URLSession
        private let tokens: any TokenProviding
        private let reachability: any Reachability
        private let clock: any Clock<Duration>
        private let jitter: @Sendable (Duration) -> Duration
        private let log: any Platform.LogSink
        private let timeZone: @Sendable () -> TimeZone
        private let languages: @Sendable () -> [String]

        init(
            configuration: Configuration,
            session: URLSession = Client.makeSession(),
            tokens: any TokenProviding,
            reachability: any Reachability,
            clock: any Clock<Duration> = ContinuousClock(),
            jitter: @escaping @Sendable (Duration) -> Duration = Client.randomJitter,
            log: any Platform.LogSink,
            timeZone: @escaping @Sendable () -> TimeZone = { .current },
            languages: @escaping @Sendable () -> [String] = { Locale.preferredLanguages }
        ) {
            self.configuration = configuration
            self.session = session
            self.tokens = tokens
            self.reachability = reachability
            self.clock = clock
            self.jitter = jitter
            self.log = log
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

        /// The most any one send may take, whatever the endpoint asks for.
        static let longestTimeout: Duration = .seconds(60)
        /// The least: a sub-second timeout would fail every real send.
        static let shortestTimeout: Duration = .seconds(1)

        /// A duration between zero and `ceiling`, uniformly (full jitter).
        static let randomJitter: @Sendable (Duration) -> Duration = { ceiling in
            var generator = SystemRandomNumberGenerator()
            return fullJitter(ceiling, using: &generator)
        }

        /// Full jitter drawn from `generator` (tests pass a seeded one).
        static func fullJitter(_ ceiling: Duration, using generator: inout some RandomNumberGenerator) -> Duration {
            ceiling * Double.random(in: 0 ... 1, using: &generator)
        }

        func send<E: Endpoint>(_ endpoint: E) async throws -> E.Response {
            guard await reachability.isOnline else { throw Failure(.offline) }
            let token = endpoint.requiresAuth ? try await accessToken() : nil
            let request = try request(for: endpoint, token: token)
            let policy = RetryPolicy.effective(endpoint.retry, method: endpoint.method, hasIdempotencyKey: endpoint.idempotencyKey != nil)
            var attempt = 1
            while true {
                do {
                    let (data, status) = try await load(request, path: endpoint.path)
                    return try decode(E.Response.self, from: data, status: status, path: endpoint.path)
                } catch let failure as Failure {
                    guard let delay = policy.retryDelay(after: failure, attempt: attempt, jitter: jitter) else { throw failure }
                    try await clock.sleep(for: delay)
                    guard await reachability.isOnline else { throw Failure(.offline) }
                    attempt += 1
                }
            }
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
            request.timeoutInterval = TimeInterval(min(max(endpoint.timeout, Self.shortestTimeout), Self.longestTimeout).components.seconds)
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

        /// Sends `request` and logs it, whatever happens: the door, the status (0
        /// when nothing came back) and the time on the injected clock.
        private func load(_ request: URLRequest, path: PathTemplate) async throws -> (Data, Int) {
            var outcome: Result<(Data, URLResponse), any Error> = .failure(Failure(.transport))
            let elapsed = await clock.measure {
                do {
                    outcome = try await .success(session.data(for: request))
                } catch {
                    outcome = .failure(error)
                }
            }
            switch outcome {
            case let .success((data, response as HTTPURLResponse)):
                log.record(.requestSent(path: path, status: response.statusCode, ms: Self.milliseconds(elapsed)))
                return (data, response.statusCode)
            case .success:
                log.record(.requestSent(path: path, status: 0, ms: Self.milliseconds(elapsed)))
                throw Failure(.transport)
            case let .failure(error):
                log.record(.requestSent(path: path, status: 0, ms: Self.milliseconds(elapsed)))
                throw Self.failure(for: error)
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
            case 408: .timedOut
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
