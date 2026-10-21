# Plumbing · outline cards

These bytes are later in the queue. Each has its header, place in the tree, needs, why, and what it must decide. Each is written in full (byte-card.md) before its phase starts, because the contracts and the founder's decisions they depend on are still moving (README §5).

---

### PL3.2 · The streamed conversation client                                 size: L · deferred to v2
Place in the tree: product › journal › conversation (v2) › Backend.Stream
Needs: contract 02 v2 (conversation), PL1.5      Unblocks: the v2 conversation
Why: when the journal becomes a real conversation, Retro's reply appears as it's written instead of after a wait.
Founder, 21 Oct: deferred; the conversation is rethought for v2. The shape kept for then: SSE over `URLSession.bytes(for:)`, one JSON object per `data:` line, cancellation tied to the view's task, recovery by refetching the turn (never resending the message).

### PL3.3 · LiveFirstRunData                                                   size: L
Place in the tree: product › first run › live data
Needs: contract 01, PL2.4, PL1.7, PL6.1, backend BE2.1–BE2.5b      Unblocks: first-run wiring, T03
Why: onboarding, "knows you", connecting sources and the first episode run on real data.
Decide when written: which onboarding answers go through the outbox (all of them: they're writes) and how the first-episode job is followed (poll vs push).

### PL3.4 · LivePodcastsData                                                   size: L
Place in the tree: product › podcasts › live data
Needs: contract 03, PL2.4, `Media.Source` (PL3.1b), backend BE3.x      Unblocks: podcasts wiring, T05, X06 (podcasts.json)
Why: episodes, chapters, evidence and feedback on real data, with audio that keeps playing offline.
Decide when written: the episode cache table (metadata in GRDB, audio in Caches with re-download) and the hand-over from the ten `podcasts.json` writers.

### PL3.5 · LiveGoalsData                                                      size: M
Place in the tree: product › goals › live data
Needs: contract 04, PL2.5, PL2.6 (`legacy_goals`), backend BE4.x      Unblocks: goals wiring
Why: your goals, and yes / not quite on them, on real data, reconciled once with the goals you already have.

### PL3.6 · LiveYouData                                                        size: M
Place in the tree: product › you › live data
Needs: contract 05, PL2.5, backend BE5.x      Unblocks: you wiring
Why: people, your portrait, what Retro understands and search on real data.

### PL3.7 · LiveSettingsData                                                   size: L
Place in the tree: product › settings › live data
Needs: contract 06, PL1.5, PL6.2, backend BE6.x, BE0.7, BE0.8      Unblocks: settings wiring, T06
Why: brief settings, voice, preferences, export, delete my data and delete my account work for real.
Decide when written: delete account must sign out, erase the store, the Keychain and RevenueCat's user in one sequence that survives being killed halfway.

### PL4.1 · The analytics facade (no vendor yet)                              size: S
Place in the tree: product › platform › analytics › Analytics.Track
Needs: PL0.2      Unblocks: PL4.2, each flow's instrumentation
Why: we can learn how the app is used without ever sending what anyone wrote.
Kept decision: `Analytics.Event` is a closed enum of screen, action and error events whose associated values are counts, durations, enum cases and ids only; a test asserts no event has a `String` payload. The vendor sink is a later byte (founder's call; analytics later).

### PL4.2 · Crash and error reporting                                         size: M
Place in the tree: product › platform › analytics › crash reporting
Needs: PL4.1, the founder's choice of vendor      Unblocks: R01
Why: when the app crashes for someone, we find out and fix it without seeing their content.
Kept decision: scrubbing on by default (no request bodies, no breadcrumbs with text), DSN from build configuration.

### PL5.1 · Push registration                                                  size: M
Place in the tree: product › platform › push › Push.Registrar
Needs: PL1.5, backend BE2.6 (`POST /v2/devices`), Apple push key (founder)      Unblocks: PL5.3, brief and episode notifications
Why: Retro can tell you when your brief or episode is ready, on the phone you're using.
Kept decisions: `aps-environment` entitlement and `remote-notification` background mode (bridges, listed in the PR); permission asked when the design asks; token sent with sandbox/production; re-register on change; unregister on sign-out (PL1.5 calls it).

### PL5.3 · Notification categories and taps                                  size: M
Place in the tree: product › platform › push › taps → Routing
Needs: PL5.1, PL5.2, contract 07      Unblocks: the "brief is ready" and "episode is ready" moments
Why: tapping a notification opens exactly what it's about.
Kept decisions: categories for episode-ready, brief, check-in; payloads parsed by PL5.2's parser into a `Destination`; the AppDelegate tap handler (`RetrospectApp.swift:32-47`) routes through the router; `ShowPodcastFromNotification` stays as a bridge until old screens retire; the dead `PlayPodcast` post is recorded in the findings log, not fixed here.

### PL6.1 · RevenueCat in the app                                             size: M
Place in the tree: product › platform › billing › Billing.Store
Needs: PL1.5, PL0.4; founder: RevenueCat public iOS key, entitlement name, offering id      Unblocks: PL6.2, P07 (paywall)
Why: you can subscribe, and see the real price in your currency, with the first month free on the yearly plan.
Kept decisions: pinned exact SDK; key from build configuration; `logIn(<our user id>)` after sign-in, `logOut()` at sign-out; `Billing.Store` wraps offering, localized prices, the yearly free month (from `introductoryDiscount`), purchase, restore, and `customerInfo` as a stream; a protocol-backed fake for every state. The founder owns products and prices ($19.99 a month; $199.99 a year with the first month free).

### PL6.2 · One source of entitlement                                        size: S
Place in the tree: product › platform › billing › entitlement
Needs: PL6.1, backend BE2.8      Unblocks: PL6.3, PL3.7
Why: you get what you paid for on every screen, and never anything you didn't.
Kept decisions: the server is the gate for server work; the app shows RevenueCat's `CustomerInfo` and refreshes `GET /v2/entitlement` after purchase or restore; fail closed.

### PL6.3 · Bridge SubscriptionManager                                       size: S
Place in the tree: product › platform › billing › bridges
Needs: PL6.2      Unblocks: retiring the old paywall
Why: the old paywall keeps working, with true prices, until the new one replaces it.
Kept decisions: `SubscriptionManager` becomes a thin adapter over `Billing.Store`; every typed-in price (`SubscriptionManager` $19.99 / $239.99, `PaywallView` $12.99 / $139.99) goes.

### PL7.1 · Privacy manifest                                                 size: S
Place in the tree: product › platform › compliance › PrivacyInfo.xcprivacy
Needs: PL2.0, PL6.1 (their SDK manifests), PL4.x if a vendor is chosen      Unblocks: App Store submission
Why: the App Store accepts the app, and what it says about data is true.
Kept decisions: every required-reason API with the file that uses it; collected data types matching what's actually sent; tracking false; checked against each SDK's own manifest.

### X06 · Retire the old local data                                          size: M
Place in the tree: product › platform › local store › retiring the old store
Needs: PL2.6 confirmed on the founder's phone and in TestFlight, the journal and podcasts ship gates, the founder's go      Unblocks: deleting `FileStorageManager`, `EntryManager`'s file path and `podcasts.json`
Why: one copy of your data on the phone, not two that can disagree.
Decide when written: moving media from `Documents/RetrospectData/` into the store's folder; the single read of `podcasts.json` after its ten writers are gone; deleting the old files only after `LegacyImport.Report.confirmed`; what happens to old entries that never reached the server (founder question).
