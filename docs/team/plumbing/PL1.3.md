### PL1.3 · The session store                                               size: M
Place in the tree: product › platform › session › Session.Store (Keychain)
Repo · branch: NPRdoinglaundry · pl/PL1.3-session-store
Needs: PL1.1      Unblocks: PL1.4, PL1.5, PL1.7, PL2.2 (background drain needs the token while locked)

Why: the sign-in token must be readable after the phone's first unlock (so entries send in the background), must never sync to iCloud or move to another device, must vanish if the app is deleted and reinstalled, and must live in exactly one place.

Inputs:
- Reference: app-reference.md §2.6 (old Keychain helpers verbatim: service `com.retrospect.api`, accounts `jwt_token`, `user_id`, `apple_user_id`, no accessibility class, so `WhenUnlocked`), §3 (ElevenLabs reads the same item), §4 (no "signed in before" flag exists).

Spec:
- `Platform/Session/Keychain.swift`: `protocol Session.KeychainBackend: Sendable { func read(_ account: String) throws -> Data?; func write(_ data: Data, account: String) throws; func delete(_ account: String) throws; func deleteAll() throws }`, a real implementation (generic password, service **`com.retrospect.session`**, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` on every write; update via `SecItemUpdate`, add if missing; every `OSStatus` checked and mapped to `Session.KeychainError` with the status code), and a fake for tests.
- `Platform/Session/Store.swift`:
  ```swift
  extension Session {
      struct Credentials: Sendable, Equatable { let accessToken: String; let accessTokenExpiresAt: Date; let refreshToken: String; let userID: String }
      actor Store {
          init(keychain: any KeychainBackend, defaults: UserDefaults, log: any Platform.LogSink)
          func credentials() throws -> Credentials?
          func save(_ credentials: Credentials) throws
          func clearCredentials() throws                 // sign-out: keeps hasSignedInBefore
          var hasSignedInBefore: Bool { get throws }     // durable across sign-out (AC-1)
          func markSignedInBefore() throws
          func pendingInviteCode() throws -> String?     // PL1.7
          func setPendingInviteCode(_ code: String?) throws
          func applyInstallSentinel() throws             // call once at launch, before anything reads
      }
  }
  ```
  Accounts: `access_token`, `access_expires_at` (ISO string), `refresh_token`, `user_id`, `has_signed_in_before`, `pending_invite_code`.
- **Reinstall hygiene, without logging out people who simply update:** Keychain items survive deleting the app; UserDefaults don't. At launch, if the sentinel `platform.installSentinel` is missing:
  - and the old app's UserDefaults are also absent (`hasCompletedOnboarding`, `onboardingSignedIn`, `onboardingCurrentStep` all missing) → this is a fresh install or a reinstall: delete every item in `com.retrospect.session` **and** the old `com.retrospect.api` items, then write the sentinel;
  - otherwise → an update from the old app: write the sentinel and change nothing.
- One place knows the identifiers: this file (the old client and ElevenLabs keep their copies until PL1.4's mirror byte).

Acceptance: credentials round-trip through the real Keychain on the simulator with the right accessibility attribute; an update keeps the old sign-in; a reinstall clears it.

Tests (layer 5, fake Keychain and an isolated UserDefaults suite): "credentials round-trip"; "every write requests AfterFirstUnlockThisDeviceOnly"; "clearCredentials keeps hasSignedInBefore"; "a fresh install wipes both services"; "an update from the old app wipes nothing"; "a Keychain error surfaces its status, never a crash"; one integration test against the real Keychain (simulator) for the accessibility attribute.

Proof in the PR: test output.

Watch out: never log token values or the invite code (the log types can't carry them; don't add a case that could). `has_signed_in_before` is cleared only by the reinstall wipe.
