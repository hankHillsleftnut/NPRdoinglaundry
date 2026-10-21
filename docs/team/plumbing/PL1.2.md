### PL1.2 · Retries, timeouts, reachability                                  size: M
Place in the tree: product › platform › backend client › resilience
Repo · branch: NPRdoinglaundry · pl/PL1.2-retries-reachability
Needs: PL1.1      Unblocks: PL2.2 (outbox uses reachability), every Live… type

Why: phones lose signal on trains and in lifts. Reads should quietly try again; writes should never be sent twice by accident; and offline should be known instantly, not after a 20-second spinner.

Inputs: contract 00 §2 (`rateLimited`/`spendLimited` carry `retryAfterSeconds`; `upstreamTimeout` 504, `upstreamUnavailable` 502); backend plan §4 step 6 (reads may retry once on 5xx/timeout; writes never without an idempotency key).

Spec:
- `Platform/Backend/RetryPolicy.swift`:
  ```swift
  extension Backend {
      enum RetryPolicy: Sendable, Equatable {
          case never
          case read(attempts: Int = 3)          // GETs: retry on timeout, 502, 503, 504, transport errors
          case keyedWrite(attempts: Int = 3)    // writes with an idempotency key: same conditions
          static func `default`(for method: Method, hasIdempotencyKey: Bool) -> RetryPolicy
      }
  }
  ```
  Backoff: full jitter, `delay = random(0, min(8 s, 0.5 s × 2^attempt))`, using the injected clock. `rateLimited` / `spendLimited`: retry once after `retryAfter` only when it's ≤ 10 s, else surface it. Never retry 4xx other than 408/429.
- `Platform/Backend/Reachability.swift`:
  ```swift
  extension Backend {
      protocol Reachability: Sendable { var isOnline: Bool { get async }; func changes() -> AsyncStream<Bool> }
      actor PathReachability: Reachability { init(monitor: NWPathMonitor = .init(), queue: DispatchQueue) }
  }
  ```
  `.satisfied` = online; `.unsatisfied` and `.requiresConnection` = offline. The client short-circuits to `.offline` without sending when offline. Expensive or constrained paths are still online.
- Per-endpoint timeout from `Endpoint.timeout` (default 20 s); the client also enforces a hard ceiling of 60 s.

Acceptance: a read that gets 503, 503, 200 returns the value after two retries; an un-keyed POST that gets 503 fails immediately; offline sends nothing.

Tests (layer 5): "a read retries on 503 then succeeds"; "a read gives up after three attempts with the last failure"; "an unkeyed write never retries"; "a keyed write retries with the same Idempotency-Key"; "429 with retryAfter 2 s waits 2 s once"; "429 with retryAfter 60 s surfaces rateLimited"; "backoff delays stay within the jitter bounds" (test clock); "offline short-circuits without a request"; "reachability publishes changes".

Proof in the PR: test output.

Watch out: `NWPathMonitor` must be started on a dedicated queue and cancelled in `deinit`; never block the main actor waiting for it.
