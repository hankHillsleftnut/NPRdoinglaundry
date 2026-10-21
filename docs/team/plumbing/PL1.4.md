### PL1.4 · Sign in with Apple and Google, v2, with a nonce; keep old screens signed in    size: L (split: PL1.4a Apple, PL1.4b Google, PL1.4c the legacy mirror and upgrade)
Place in the tree: product › platform › session › sign-in
Repo · branch: NPRdoinglaundry · pl/PL1.4a-apple, pl/PL1.4b-google, pl/PL1.4c-legacy-mirror
Needs: PL1.3, contract 00 §3, backend BE0.4 (v2 sign-in) and BE2.4 (Google)      Unblocks: PL1.5, PL1.7, P01/P32 sign-in screens

Why: sign in with Apple or Google (founder, 21 Oct), safely (a nonce stops replayed tokens), and without logging out anyone who's already using the app.

Inputs:
- Contract: 00-platform.md §3 (`POST /v2/auth/apple { identityToken, authorizationCode, rawNonce, fullName, email }`, `POST /v2/auth/google { idToken, rawNonce }`, response `{ accessToken, refreshToken, accessTokenExpiresAt, user { id, firstName, isNew }, access { state } }`).
- Reference: app-reference.md §1.3 (`isGoogleConfigured` at `RetrospectApp.swift:133-138` treats the shipped `GIDClientID` as a placeholder), §2.2 (old sign-in, callers `WelcomeSignInPage.swift:~199`, `BackendAuthGateView.swift:109`), §2.6 (old Keychain), §3 (`ElevenlabsService.swift:81-101` reads `com.retrospect.api/jwt_token`), §12.1 (`GIDClientID`, URL types).
- Founder action: the Google **sign-in** OAuth client id (basic scopes), separate from the Docs/Drive connector's client.

Spec:
- `Platform/Session/Nonce.swift`: `Session.Nonce.make() -> (raw: String, hashed: String)`: 32 bytes from `SecRandomCopyBytes`, base64url raw, SHA-256 hex hashed (CryptoKit).
- `Platform/Session/AppleSignIn.swift` (the seam with the UI engineer's `SignInWithAppleButton`):
  ```swift
  extension Session {
      @MainActor final class AppleSignIn {
          func prepare(_ request: ASAuthorizationAppleIDRequest)   // sets scopes [.fullName, .email] and request.nonce = hashed
          func complete(_ result: Result<ASAuthorization, Error>) async throws -> SignInOutcome
      }
      struct SignInOutcome: Sendable { let userID: String; let firstName: String?; let isNew: Bool; let access: Session.AccessState }
  }
  ```
  `complete` sends `identityToken` and `authorizationCode` (both UTF-8 from the credential), `rawNonce`, and `fullName`/`email` only when Apple provided them (first authorization only); saves credentials; marks signed in before. A cancelled Apple sheet throws `Session.SignInError.cancelled` (the UI shows nothing).
- `Platform/Session/GoogleSignIn.swift`: `Session.GoogleSignIn.signIn(presenting: UIViewController) async throws -> SignInOutcome` using GoogleSignIn's nonce-taking `signIn(withPresenting:hint:additionalScopes:nonce:)` with **only** `openid email profile`; sets `GIDSignIn.sharedInstance.configuration` to the sign-in client id just before the call (the Docs connector sets its own; the two must not share a configuration). `onOpenURL` must forward Google's callback to `GIDSignIn.sharedInstance.handle(url)`: done through the router (PL5.2) if it has landed, otherwise a one-line bridge in `RetrospectApp.swift:373` (before the `retrospect` scheme guard), noted in the PR.
- `Platform/Session/LegacyMirror.swift` (PL1.4c, the bridge that keeps old screens working while they exist):
  - After every successful sign-in or refresh, write the current access token and user id into the **old** items (`com.retrospect.api` / `jwt_token`, `user_id`, and `apple_user_id` for Apple) with `AfterFirstUnlockThisDeviceOnly`, and set the old client's published `isAuthenticated`/`currentUserId` on the main actor, so `RetrospectAPIClient`, `ElevenLabsService` and the root ladder (`RetrospectApp.swift:211`, `!hasUsableBackendAuth`) keep working.
  - **Upgrade on first launch:** if the new store is empty but the old `jwt_token` exists (an existing user on the new build), exchange it once for a v2 pair (**needs a contract 00 amendment: `POST /v2/auth/upgrade` with the old token as Bearer → the same sign-in response**; see questions). If the exchange fails with `invalidCredentials`/`sessionRevoked`, leave the old token alone (old screens keep working until it expires) and show sign-in only when a new screen needs a v2 session.
- `ElevenlabsService.swift:81-101` needs no code change: it keeps reading the mirrored old item. The PR says so explicitly.

Steps: PL1.4a (nonce, Apple, tests) → PL1.4b (Google, tests) → PL1.4c (mirror, upgrade, bridge notes) → PR each.

Acceptance: on the simulator with local staging, Apple sign-in (sandbox Apple ID) returns credentials, the old app screens still load data, speech still works; Google sign-in works with the founder's client id; an existing signed-in build updated to this one stays signed in.

Tests (layer 5): "a nonce's hash is the SHA-256 of the raw value"; "Apple completion sends identityToken, authorizationCode, rawNonce and the name only on first authorization" (request body asserted against `fixtures/00/auth-apple.request.json`); "a cancelled Apple sheet throws cancelled and sends nothing"; "the auth response saves credentials and marks signed in before"; "the mirror writes the old items with the new accessibility"; "an existing old token is upgraded once"; "a failed upgrade leaves the old token in place"; "Google sign-in sends the ID token and raw nonce".

Proof in the PR: test output; a staging run (integrator) with both providers; a screenshot showing an old screen still loading after a v2 sign-in.

Watch out:
- Apple sends `fullName` and `email` once, ever: send them on that first completion or they're gone.
- Keep the old `signInAsDevTestUser` path untouched (DEBUG tools use it).
- `GIDSignIn.sharedInstance` is global: set its configuration immediately before each sign-in, and let the Docs connector do the same.
