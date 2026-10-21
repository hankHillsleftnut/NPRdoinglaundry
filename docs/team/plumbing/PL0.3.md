### PL0.3 · Platform.Environment and injection                               size: M
Place in the tree: product › platform foundations › composition root › Platform.Environment
Repo · branch: NPRdoinglaundry · pl/PL0.3-environment
Needs: PL0.2      Unblocks: PL1.x, T02a, every Live… type, the UI engineer's screens (they read the environment)

Why: today every service is a `static let shared` singleton, so nothing can be tested in isolation and nothing can be swapped for sample data. One value built at launch and passed down fixes both.

Inputs:
- Reference: app-reference.md §1.2 (state at :52-75), §1.10 (where the environment goes).
- Code anchors: `RetrospectApp.swift:52` (`@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate`), `:69-74` (the `@StateObject` singletons), `:242` (`.environmentObject(themeManager)` on the ZStack; the two `.fullScreenCover`s at :303 and :325 sit after it, so they inherit what's injected there).

Spec:
- `Platform/Environment.swift`:
  ```swift
  extension Platform {
      @MainActor @Observable
      final class Environment {
          let configuration: Backend.Configuration      // PL1.1
          let log: any Platform.LogSink
          // filled in by later bytes, each optional until its byte lands:
          // session, client, store, outbox, router, billing, analytics, flows
          var updateRequired: Bool = false                // PL1.6
          init(configuration: Backend.Configuration, log: any Platform.LogSink)
          static func live(launch: Platform.LaunchOptions = .current) -> Environment
          static func preview() -> Environment            // stubs only: no network, no disk, no Keychain
      }
  }
  ```
  Later bytes add their members here; each member is a protocol-typed dependency (`any Session.Providing`, …) so tests and previews inject fakes.
- Bridge in `RetrospectApp.swift` (the only edit): `@State private var platform = Platform.Environment.live()` beside :69-74, and `.environment(platform)` immediately after `.environmentObject(themeManager)` at :242. Nothing else reads it yet.
- Views read it with `@Environment(Platform.Environment.self) private var platform`. Inside `extension Platform` (non-view code) never use the SwiftUI `@Environment` wrapper: inside that scope the name resolves to our type.

Steps: type → `preview()` → bridge two lines → tests → PR.

Acceptance:
- The app builds and launches exactly as before (launch screenshot unchanged; no new network calls at launch).
- `Platform.Environment.preview()` builds in a test with the Mac offline.

Tests (layer 5): "the preview environment builds without network, disk or Keychain" (the stub session records zero requests; the fake Keychain records zero reads); "live() uses the production configuration in a release-like launch" (inject launch options).

Proof in the PR: test output; the two-line bridge diff; launch screenshots before and after.

Watch out: `@Observable` classes and SwiftUI's `.environment(_:)` with an object need iOS 17; the app's 18.1 target is fine. Don't make it `ObservableObject`: new code uses Observation throughout.
