### PL5.2 · The typed router: every way into the app, one list             size: M
Place in the tree: product › platform › routing › Routing.Router
Repo · branch: NPRdoinglaundry · pl/PL5.2-router
Needs: PL0.3      Unblocks: PL1.7 (invite links), PL5.3 (notification taps), PL1.4b (Google callback forwarding, if not already landed), the UI engineer's navigation

Why: a link, a widget, a shortcut or a notification always opens the right place, and an invite link lets you in without typing a code.

Inputs:
- Reference: app-reference.md §1.8 (`.onOpenURL` `:373-415`: `start-recording`, `stop-recording`, `integration-connected`), §1.1 (AppDelegate tap handler `:32-47`), §11.1 (string notifications, including `PlayPodcast` with no observer), §11.2 (`shouldStartVoiceRecordingFromShortcut`), §12.1 (URL schemes: `retrospect`, the Google reversed client id).
- Contract 00 §4 (the invite link shape), contract 07 (later: notification payloads).

Spec:
- `Platform/Routing/Destination.swift`:
  ```swift
  extension Routing {
      enum Destination: Sendable, Equatable {
          case invite(code: String)
          case startRecording, stopRecording
          case integrationConnected(provider: String, status: String)   // closed values checked against IntegrationCatalog ids; unknown → dropped
          case brief(id: String?)            // nil = today's
          case entry(id: String)
          case episode(id: String)
          case guess(id: String)
          case settings(Settings.Page)       // a closed enum of pages
          enum Settings { enum Page: String, Sendable { case root, brief, account, subscription, privacy } }
      }
  }
  ```
- `Platform/Routing/Parser.swift`: `static func parse(_ url: URL, inviteHost: String?) -> Destination?`, a pure function:
  - `retrospect://start-recording`, `stop-recording`, `integration-connected?provider=…&status=…`, `brief[/<id>]`, `entry/<id>`, `episode/<id>`, `guess/<id>`, `settings[/<page>]`.
  - `https://<inviteHost>/i/<code>` → `.invite` with the code normalised as PL1.7 (13 Crockford characters after normalising; otherwise nil). Any other path on that host → nil (the site handles it).
  - Ids must be UUIDs; anything else → nil. Unknown hosts → nil and logged `routeUnknown(kind:)` with the host only for `retrospect://`, never the path or query.
  - The Google sign-in callback (`com.googleusercontent.apps.…`) is not a destination: `Routing.Router.open(_:)` hands it to `Session.GoogleSignIn.handle(url)` first.
- `Platform/Routing/Router.swift`: `@MainActor @Observable final class Router { private(set) var pending: Destination?; func open(_ url: URL); func open(_ destination: Destination); func consume() -> Destination? }`. Destinations that need a signed-in, onboarded app wait in `pending` until the root says it's ready (the old `shouldStartVoiceRecordingFromShortcut` pattern, made general); `.invite` goes to `Session.InviteCenter.received(code:)` at once and is never pending.
- **Bridges** (one PR, listed in its body):
  - `RetrospectApp.swift:373-415` `.onOpenURL`: first line `platform.router.open(url)`; the three existing branches stay for old screens, now fed by the router's bridge closure that re-posts the same notifications (`StopVoiceRecordingFromLiveActivity`, `.integrationConnectionChanged` with the same userInfo) and sets the same flags, so old screens see no change.
  - `.onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` added beside it, forwarding `webpageURL` to the router (universal links arrive this way in SwiftUI).
  - The associated domains entitlement is PL1.7's.

Steps: destinations → parser (pure, exhaustive tests) → router + pending → bridges → tests.

Acceptance: every URL the app accepts today still does exactly what it did; an invite link opened cold reaches `InviteCenter`; an unknown link does nothing and doesn't crash.

Tests (layer 5): a table test of every accepted URL → its destination, and of malformed ones → nil (bad ids, extra path parts, wrong host, `http` instead of `https`, an invite code of the wrong length); "integration-connected keeps its exact userInfo for old screens"; "start-recording before onboarding waits in pending and is consumed once"; "an invite link is never pending"; "the Google callback goes to sign-in, not the router"; "no route log line contains a path, query or code".

Proof in the PR: test output; the bridge diff; `xcrun simctl openurl` runs for each old URL with screenshots of the unchanged behaviour.

Watch out: `.onOpenURL` doesn't receive universal links on its own in every case; keep both handlers. Never route on a string from a notification payload without the parser (PL5.3 uses the same parser).
