### PL1.1 · The typed client core                                           size: L (split: PL1.1a types and envelope, PL1.1b the actor and headers)
Place in the tree: product › platform › backend client › Backend.Client
Repo · branch: NPRdoinglaundry · pl/PL1.1a-client-types, pl/PL1.1b-client-actor
Needs: PL0.3, contract 00 merged with fixtures      Unblocks: PL1.2–PL1.7, every Live… type

Why: one typed, testable way to talk to the `/v2` doors, so every screen gets real errors it can explain instead of "Server error: HTTP 500: …", and nothing can send a malformed body.

Inputs:
- Contract: 00-platform.md §1 (headers), §2 (envelopes and the closed error-code list), §5 (`GET /v2/meta`); contracts/README.md rules 1–6 (camelCase, ISO dates with milliseconds, optional = absent or null, closed enums with `unknown`, fixtures on both sides).
- Reference: app-reference.md §2.1 (old base URL, DEBUG override key `devAPIBaseURL`), §2.5 (old request function: what not to copy), §2.7 (`JSONDecoder.apiDecoder` is a module-wide extension: don't redeclare or reuse it; `APIError` exists: don't reuse the name).

Spec:
- `Platform/Backend/Configuration.swift`:
  ```swift
  extension Backend {
      enum Environment: String, Sendable, CaseIterable { case production, staging, local }
      struct Configuration: Sendable, Equatable {
          let environment: Backend.Environment
          let baseURL: URL                 // production: https://retrospect-api.onrender.com ; staging: the Render staging URL (unset until Render staging exists, so `staging` resolves to `local`) ; local: http://localhost:3000 (simulator) or the Mac's LAN address (device, DEBUG developer setting)
          let appVersion: String           // "1.0 (42)" from CFBundleShortVersionString and CFBundleVersion
          static func resolve(_ launch: Platform.LaunchOptions, bundle: Bundle = .main) -> Configuration
      }
  }
  ```
  Release builds resolve to `production` only (compile-time, as in T02a).
- `Platform/Backend/Endpoint.swift`:
  ```swift
  extension Backend {
      enum Method: String, Sendable { case get = "GET", post = "POST", put = "PUT", patch = "PATCH", delete = "DELETE" }
      enum PathTemplate: String, Sendable { case meta = "/v2/meta" /* grows per byte; each case is the contract path with :params */ }
      struct NoBody: Encodable, Sendable {}
      protocol Endpoint: Sendable {
          associatedtype Body: Encodable & Sendable = Backend.NoBody
          associatedtype Response: Decodable & Sendable
          var method: Backend.Method { get }
          var path: Backend.PathTemplate { get }
          var pathParameters: [String: String] { get }      // default [:]
          var query: [URLQueryItem] { get }                  // default []
          var body: Body? { get }                            // default nil
          var requiresAuth: Bool { get }                     // default true
          var timeout: Duration { get }                      // default .seconds(20)
          var retry: Backend.RetryPolicy { get }             // default by method (PL1.2)
          var idempotencyKey: UUID? { get }                  // default nil
      }
  }
  ```
- `Platform/Backend/Envelope.swift`: `Backend.Envelope<T: Decodable>` decoding `{ success: true, data }`, and `Backend.ErrorBody` decoding `{ success: false, error: { code, message, retryAfterSeconds? } }`.
- `Platform/Backend/Failure.swift`: `enum Backend.Failure: Error, Sendable, Equatable` with one case per contract code (`invalidRequest`, `invalidCredentials`, `unauthenticated`, `sessionRevoked`, `inviteRequired`, `suspended`, `notFound`, `idempotencyMismatch`, `updateRequired`, `rateLimited(retryAfter: Duration?)`, `spendLimited(retryAfter: Duration?)`, `upstreamTimeout`, `upstreamUnavailable`, `internal`), the invite codes (`inviteInvalid`, `inviteUsed`, `inviteExpired`), plus client-side cases (`offline`, `timedOut`, `decoding`, `transport`), and `unknown(code: String)` for a code outside the list (logged as `unknownCode` with no text). Each case has `var message: String` (the server's plain-words message when present, else a default line written in the contract's voice) and `var isRetryable: Bool`.
- `Platform/Backend/Coding.swift`: `Backend.Coding.decoder` / `.encoder`: default (camelCase) keys, dates ISO 8601 with and without fractional seconds on decode, with milliseconds on encode. Never `convertFromSnakeCase` (contract rule 1).
- `Platform/Backend/Client.swift`:
  ```swift
  extension Backend {
      protocol TokenProviding: Sendable { func accessToken() async throws -> String; func refreshAfterUnauthorized(failedToken: String) async throws -> String }  // implemented by Session (PL1.5); a stub until then
      actor Client {
          init(configuration: Configuration, session: URLSession, tokens: any TokenProviding, reachability: any Reachability, clock: any Clock<Duration>, log: any Platform.LogSink)
          func send<E: Endpoint>(_ endpoint: E) async throws -> E.Response     // throws only Backend.Failure
      }
  }
  ```
  Builds `URLRequest` (path parameters percent-encoded; query items; JSON body with `Content-Type`), sets headers from contract 00 §1 (`Authorization` when `requiresAuth`, `X-App-Version`, `X-Time-Zone: TimeZone.current.identifier`, `Accept-Language` from `Locale.preferredLanguages`, `Idempotency-Key` when set), applies `timeoutInterval` from the endpoint, decodes the envelope, maps HTTP + body to `Backend.Failure`. 401 handling is PL1.5's (here it surfaces `.unauthenticated`). Every request logs `requestSent(path:status:ms:)`: the path template, never the filled-in URL.
- `Platform/Backend/Endpoints/Meta.swift`: `Backend.Endpoints.Meta: Endpoint` → `Backend.Meta { minVersion: String, latestVersion: String, serverTime: Date, environment: Backend.Environment }`, public.
- The URLSession: one `URLSessionConfiguration.ephemeral` per client (no shared cookies or cache), `waitsForConnectivity = false`, `requestCachePolicy = .reloadIgnoringLocalCacheData`.

Steps: PL1.1a (configuration, endpoint protocol, envelope, failure, coding, Meta, decoding tests) → PL1.1b (the actor, headers, mapping, tests with the stub) → PR each.

Acceptance:
- `Backend.Client.send(Meta())` against a stub serving `fixtures/00/meta.json` returns the decoded value; against each `fixtures/00/error.*.json` it throws the matching `Backend.Failure`.
- Every header in contract 00 §1 is present on an authenticated request and `Authorization` is absent on a public one.
- No call anywhere goes through `RetrospectAPIClient`.

Tests (layers 4–5): "meta decodes from its fixture"; one test per error fixture ("error.invite_required decodes to inviteRequired"); "an unknown error code decodes to unknown and logs no text"; "a 500 with a non-JSON body maps to internal"; "a malformed success body maps to decoding"; "authenticated requests carry the five headers"; "public requests carry no Authorization"; "path parameters are percent-encoded"; "dates decode with and without fractional seconds"; "the log records the path template, never the URL".

Proof in the PR: test output; a list of the contract-00 codes and their `Backend.Failure` cases.

Watch out:
- Swift 5 mode: typed `throws(Backend.Failure)` isn't used; the client documents and tests that it throws only `Backend.Failure` (a test sends every failure path and asserts the type).
- Don't copy the old client's `[String: Any]` bodies, its global sign-out, or its 480 s timeout.
- `X-Time-Zone` must be the IANA identifier (`TimeZone.current.identifier`), not an abbreviation.
