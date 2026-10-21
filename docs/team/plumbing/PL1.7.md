### PL1.7 · The invite gate and invite links, app half                       size: L (split: PL1.7a access and redeem, PL1.7b pending code and auto-apply, PL1.7c your invites)
Place in the tree: product › first run › the invite › Session.Invite
Repo · branch: NPRdoinglaundry · pl/PL1.7a-access, pl/PL1.7b-auto-apply, pl/PL1.7c-your-invites
Needs: PL1.5, PL5.2 (the router parses invite links), contract 00 §4, backend BE0.12; founder: the invite domain      Unblocks: UI4.6, UI4.7 (M14 "you're in"), T03

Why: you get in only through an invite link, and opening the link should feel like being handed a gift: the code applies itself after sign-in, with no typing (founder, 21 Oct).

Inputs:
- Contract: 00-platform.md §4 (`GET /v2/access`, `POST /v2/waitlist`, `POST /v2/invites/redeem { code }` → `{ access { state }, invitedBy }`, errors `invite_invalid | invite_used | invite_expired | rate_limited`, `GET /v2/invites/mine` with three automatic single-use invites and their links).
- Reference: app-reference.md §12.2 (no associated domains entitlement today).

Spec:
- `Platform/Session/Invite.swift`:
  ```swift
  extension Session {
      enum AccessState: String, Sendable, Codable { case waitlisted, approved, member, staff, suspended, unknown }
      enum InviteOutcome: Sendable, Equatable { case youreIn(invitedBy: String?), alreadyIn, invalid, used, expired, rateLimited(retryAfter: Duration?), offline }
      struct Invite: Sendable, Identifiable, Equatable { let id: String; let link: URL?; let createdAt: Date; let state: State; let usedBy: String?; enum State: String, Sendable, Codable { case unused, used, revoked, unknown } }
      @MainActor @Observable final class InviteCenter {
          private(set) var access: AccessState
          private(set) var lastOutcome: InviteOutcome?          // the UI reads this for "you're in" or the error
          func received(code: String)                           // from the router; stores it as pending
          func afterSignIn() async                              // redeems a pending code if waitlisted
          func redeem(typed code: String) async -> InviteOutcome // the typed fallback
          func joinWaitlist(reason: String?) async throws
          func myInvites() async throws -> [Invite]
          func refreshAccess() async
      }
  }
  ```
- Code normalisation: uppercase, strip spaces and dashes, Crockford base32 (no I, L, O, U ambiguity handling: map `I`/`L` → `1`, `O` → `0`), exactly 13 characters, else `.invalid` without a request.
- **Auto-apply:** `received(code:)` stores the normalised code in `Session.Store.setPendingInviteCode` (survives relaunch). After sign-in (`afterSignIn`, called by the sign-in completion), if `access == .waitlisted` and a pending code exists, redeem it automatically; on success, clear it, set `access = .approved`, publish `.youreIn(invitedBy:)`; on `used`/`expired`/`invalid`, clear it and publish the outcome (the invite screen shows it); on `offline`/`rateLimited`, keep it and retry on the next `.active`. A code received while already `approved`/`member` is discarded with `.alreadyIn`.
- Associated domains: add `com.apple.developer.associated-domains` with `applinks:<invite domain>` to `Retrospect/Retrospect.entitlements` (founder supplies the domain; until then the router still handles the code when it arrives some other way).
- The code is never logged, never put in analytics, never in a URL the app builds.

Acceptance: opening an invite link before installing, then signing in, lets the person straight in with no typing; a used link shows the right message; your three invites list with share links.

Tests (layer 5): "a link's code survives relaunch and applies after sign-in"; one per redeem fixture (`youreIn`, `used`, `expired`, `invalid`, `rate_limited`); "offline keeps the code for later"; "a member opening a link gets alreadyIn and nothing is sent"; "codes normalise (dashes, spaces, lowercase, O/0, I/1)"; "no log line contains the code" (scan the recorder sink); "myInvites decodes three invites from the fixture".

Proof in the PR: test output; a local-staging run (integrator) from link to "you're in".

Watch out: redemption needs a signed-in user: never redeem before sign-in, even if the link arrives first.
