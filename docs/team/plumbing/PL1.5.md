### PL1.5 · Silent refresh (single-flight), sign-out of this device, and the old client's 401    size: M
Place in the tree: product › platform › session › refresh and sign-out
Repo · branch: NPRdoinglaundry · pl/PL1.5-refresh-signout
Needs: PL1.4, backend BE0.4      Unblocks: PL1.7, PL2.2, PL3.x, AC-2 (sign-out with unsent entries)

Why: you stay signed in for as long as you use the app (the 15-minute pass renews quietly), and an expired pass never throws you back to the start, on new or old screens. "Sign out everywhere" is v2 (founder, 21 Oct).

Inputs:
- Contract: 00-platform.md §3 (`POST /v2/auth/refresh { refreshToken }`, `session_revoked`; `POST /v2/auth/signout { refreshToken }`).
- Reference: app-reference.md §2.3 (old `signOut()` at `RetrospectAPIClient.swift:118-128`, callers: the 401 path and `DarkSettingsView.swift:278-284` `fullSignOut`), §2.5 (the old 401 path at `:559-568` signs out and clears the gate), §4 (`OnboardingState.clearSignInGate()` at `:204-206`).

Spec:
- `Platform/Session/Session.swift` (`Session.Manager`, an actor implementing `Backend.TokenProviding`):
  ```swift
  extension Session {
      enum SignOutResult: Sendable, Equatable { case signedOut, hasUnsent(count: Int) }
      actor Manager: Backend.TokenProviding {
          func accessToken() async throws -> String                                // refreshes first if it expires within 60 s
          func refreshAfterUnauthorized(failedToken: String) async throws -> String // single-flight
          func signOut(force: Bool) async -> SignOutResult                          // hasUnsent when the outbox isn't empty and !force
          var state: Session.State { get }                                          // .signedOut, .signedIn(userID: String)
          func states() -> AsyncStream<Session.State>
      }
  }
  ```
- **Single-flight refresh:** the actor holds one `Task<Credentials, Error>?`. A 401 on any `/v2` call calls `refreshAfterUnauthorized`; if a refresh is already running, every caller awaits it; if the failed token is older than the stored one (someone already refreshed), return the stored one without refreshing. The client replays the original request once with the new token. Refresh failure with `sessionRevoked`/`invalidCredentials` → local sign-out (below) and `.unauthenticated` to callers; network failure → keep credentials, surface `.offline`/`.timedOut`.
- **Proactive refresh:** on `scenePhase == .active` (bridge in `RetrospectApp.swift:353-372`, one line: `Task { await platform.session.refreshIfNeeded() }`) and before any request whose token expires within 60 s.
- **Sign-out (this device):** if the outbox has unsent items and `force == false`, return `.hasUnsent(count)` (AC-2 shows "send, then sign out"); otherwise `POST /v2/auth/signout` (best effort; failure doesn't block), clear credentials (keep `hasSignedInBefore`), clear the old items through the mirror, call `OnboardingState.clearSignInGate()` (on the main actor), log out of RevenueCat when PL6 lands, unregister the device token when PL5.1 lands.
- **Bridges to old code** (both one-hook edits, through `Platform.Bridges`, a `@MainActor` enum of optional closures that `Platform.Environment.live()` sets):
  - `RetrospectAPIClient.swift:559-568`: before signing out on a 401, `if let retry = await Platform.Bridges.refreshLegacy?(), retry { return try await request(...same arguments...) }` (once; a second 401 falls through to the old sign-out). So old screens refresh instead of logging people out.
  - `RetrospectAPIClient.swift:118-128` (`signOut()`): also call `Platform.Bridges.legacySignedOut?()` so the old Settings "Log Out" (`DarkSettingsView.swift:155`) signs the new session out too.

Acceptance: an access token that expires mid-session renews without the user noticing, on a new and an old screen; ten requests that all get 401 at once cause one refresh; sign-out with an unsent entry reports it.

Tests (layer 5): "ten concurrent 401s cause exactly one refresh and all ten replay"; "a stale failed token returns the already-refreshed token without a second refresh"; "a revoked refresh token signs out once and clears the gate"; "an offline refresh keeps the credentials"; "a token expiring within 60 s is refreshed before the request"; "sign-out with two unsent entries returns hasUnsent(2) and changes nothing"; "forced sign-out clears credentials but keeps hasSignedInBefore"; "the old client's 401 refreshes and retries once" (old client driven through the stub session).

Proof in the PR: test output; the two bridge diffs.

Watch out: the old client isn't an actor and isn't `@MainActor`; the bridge closures hop explicitly. Never call the old client from new code.
