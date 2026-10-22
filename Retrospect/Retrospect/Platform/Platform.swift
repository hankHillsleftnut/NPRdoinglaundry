// The new app layer, beside the old one and never mixed with it.
//
//   Features/<Flow>   screens; they read only a Flows protocol, via .environment
//        │
//   Flows             per-flow data protocols (written by the integrator from the contracts)
//   Repositories      cache first, writes through the outbox
//        │                          │
//   Backend           typed client  Store   local database, outbox, caches
//        │
//   Session           token store, sign-in, refresh, invites
//   Routing · Push · Billing · Analytics · Media
//   Platform          the root: environment, launch options, test host, log
//
// Rules:
// - Every new type is nested in one of these namespaces. The module already has
//   about 450 top-level names; a nested name can't collide with any of them.
// - Networking, storage, session and outbox are actors; anything a view observes
//   is @MainActor @Observable; values crossing a boundary are Sendable.
// - No singletons: one Platform.Environment is built at launch and injected.
// - Nothing here calls the old RetrospectAPIClient, and old code never calls in,
//   except at the bridges named in docs/team/app-plumbing-engineer.md §7.

/// The root: environment, launch options, the test host and the log.
enum Platform {}

/// The typed client for the backend's /v2 doors: endpoints, failures, reachability.
enum Backend {}

/// Who you are: the token store, sign-in, refresh and invites.
enum Session {}

/// On the phone first: the local database, the outbox and caches.
/// The database type is `Store.LocalDatabase`, never `Store.Database`, so it
/// can't shadow the `Database` that GRDB passes into its closures.
enum Store {}

/// Cache-first reads and outbox-backed writes, one per flow.
enum Repositories {}

/// The per-flow data protocols the screens read. The integrator writes them.
enum Flows {}

/// Every way into the app: links, widgets, shortcuts, notification taps.
enum Routing {}

/// Push registration.
enum Push {}

/// Purchases through RevenueCat. Not `Purchases`, which is RevenueCat's own class.
enum Billing {}

/// Typed analytics events, counts only.
enum Analytics {}

/// Audio sources: signed links, offline copies and their refresh.
enum Media {}
