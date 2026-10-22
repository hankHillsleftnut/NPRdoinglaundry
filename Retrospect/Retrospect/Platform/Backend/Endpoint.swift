import Foundation

extension Backend {
    enum Method: String, Sendable {
        case get = "GET", post = "POST", put = "PUT", patch = "PATCH", delete = "DELETE"
    }

    /// Every `/v2` path the app calls, as the contract writes it (`:id` for a
    /// parameter). Logs carry these, never a filled-in URL. Grows a case per door,
    /// and each new case gets its fixed line in `Platform.Log.SystemSink`.
    enum PathTemplate: String, Sendable, CaseIterable {
        case meta = "/v2/meta"
        case diagnostics = "/v2/diagnostics"
        case entries = "/v2/entries"
        case authApple = "/v2/auth/apple"
        case authRefresh = "/v2/auth/refresh"
        case authSignout = "/v2/auth/signout"
        case access = "/v2/access"
        case waitlist = "/v2/waitlist"
        case invitesCheck = "/v2/invites/check"
        case invitesRedeem = "/v2/invites/redeem"
        case invitesMine = "/v2/invites/mine"
    }

    /// The body of a request that sends none.
    struct NoBody: Encodable, Sendable {}

    /// One door: what to send and what comes back. The client turns it into a
    /// request and its response into `Response` or a `Backend.Failure`.
    protocol Endpoint: Sendable {
        associatedtype Body: Encodable & Sendable = Backend.NoBody
        associatedtype Response: Decodable & Sendable

        var method: Backend.Method { get }
        var path: Backend.PathTemplate { get }
        /// Values for the template's `:name` parameters, percent-encoded by the client.
        var pathParameters: [String: String] { get }
        var query: [URLQueryItem] { get }
        var body: Body? { get }
        /// False only for the contract's public doors.
        var requiresAuth: Bool { get }
        /// How long one send may take. The client caps it at `Backend.Client.longestTimeout`.
        var timeout: Duration { get }
        /// When to send again (defaults by method and key: `RetryPolicy.default`).
        var retry: Backend.RetryPolicy { get }
        /// Set on every write the contract marks idempotent: the entity's own id.
        var idempotencyKey: UUID? { get }
    }

    /// The doors, one type each.
    enum Endpoints {}
}

extension Backend.Endpoint {
    var pathParameters: [String: String] {
        [:]
    }

    var query: [URLQueryItem] {
        []
    }

    var requiresAuth: Bool {
        true
    }

    var timeout: Duration {
        .seconds(20)
    }

    var idempotencyKey: UUID? {
        nil
    }

    var retry: Backend.RetryPolicy {
        .default(for: method, hasIdempotencyKey: idempotencyKey != nil)
    }
}

extension Backend.Endpoint where Body == Backend.NoBody {
    var body: Body? {
        nil
    }
}
