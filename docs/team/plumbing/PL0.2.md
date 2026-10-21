### PL0.2 · The Platform folder, namespaces and the log sink                size: S
Place in the tree: product › platform foundations › module structure › namespaces and logging
Repo · branch: NPRdoinglaundry · pl/PL0.2-platform-folder
Needs: PL0.1      Unblocks: every Platform byte

Why: the app is one Swift module with 454 type names already taken; every new type nested in a namespace can't collide. And one logging path that can't carry personal content, testable from day one.

Inputs:
- Reference: app-reference.md §15 (all 454 + 74 names; names to avoid).
- Code anchors: `.swiftlint.yml` `included` (DesignSystemV2, Features only); `.swiftformat` (`--swiftversion 5.10`, `--maxwidth 160`, `--self remove`).

Spec:
- Folder `Retrospect/Retrospect/Platform/` with one file per namespace root, each a caseless enum, all `enum X {}` declarations in `Platform/Platform.swift`:
  - `Platform` (the root: environment, launch options, test host), `Backend` (client, endpoints, failures, reachability), `Session` (token store, sign-in, refresh, invite), `Store` (local database, outbox, caches), `Repositories`, `Flows` (the per-flow data protocols, written by the integrator), `Routing` (the router), `Push`, `Billing` (purchases through RevenueCat), `Analytics`, `Media` (audio sources and their refresh).
  - Names checked against app-reference §15: none of these exist today. **Two deliberate choices:** `Billing`, not `Purchases`, because RevenueCat's SDK class is `Purchases` and would collide inside our namespace; and the database type will be `Store.LocalDatabase`, not `Store.Database`, because GRDB's closures take a `Database` parameter and code inside `extension Store` would resolve to ours.
  - A header comment at the top of `Platform.swift` drawing the layering (plan §4) and the rules (namespaces, actors, no singletons, no old-client calls).
- `Platform/Log.swift`: `extension Platform { enum Log {} }` with `Platform.Log.Event` (a closed enum: `requestSent(path: Backend.PathTemplate, status: Int, ms: Int)`, `refreshed`, `refreshFailed(reason: Session.RefreshFailure)`, `outboxDrained(sent: Int, failed: Int)`, …, growing per byte), and `protocol Platform.LogSink: Sendable { func record(_ event: Platform.Log.Event) }`. Production sink: `os.Logger(subsystem: "com.shauryanarang.Retrospect", category: "platform")`, every interpolation `.public` because events carry only enums, counts and path templates. Test sink: an in-memory recorder. **No event case has a `String` associated value**; path templates (`/v2/entries/:id`) are a `RawRepresentable` enum, never a raw URL.
- Lint: ask the integrator to add `Retrospect/Retrospect/Platform` to `.swiftlint.yml` `included` and to the SwiftFormat lint path in `swift-quality.yml` (their PR). Your code must already pass both locally: `swiftlint lint --strict Retrospect/Retrospect/Platform` and `swiftformat --lint Retrospect/Retrospect/Platform`.

Steps: folder → namespace enums → log types → lint locally → tests → PR.

Acceptance:
- The app builds; nothing references the new types yet except tests.
- SwiftLint strict and SwiftFormat lint are clean on `Platform/`.

Tests (layer 5): "a log event has no string payload" (uses `Mirror` over one instance of every case, built by a `CaseIterable`-style test helper, and fails if any child value is a `String` or `URL`); "the recorder sink records events in order".

Proof in the PR: the lint output; the test output.

Watch out:
- Don't name anything `Environment`, `Entry`, `Layout`, `Spacing` or `APIError` at the top level; inside a namespace is fine but avoid shadowing SwiftUI's `Environment` in code that also uses the `@Environment` property wrapper (see PL0.3).
