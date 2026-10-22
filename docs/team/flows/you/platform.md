# You · Platform cards (live data, store, routes)

The tree for this side: **you** › live data `LiveYouData` › wire models and cached reads (PL3.6a) › map and portrait (PL3.6b) › one node, "still true", "same person?" (PL3.6c) › what Retro knows (PL3.6d) › search (PL3.6e) › routes into You (PL3.6f). Contract: [../../contracts/05-you.md](../../contracts/05-you.md). The outline's PL3.6 (M) was too big for one PR: it splits into six, and PL2.5's "people, portrait, understanding" half is absorbed into PL3.6a (PL2.5 keeps its goals half).

**Before PL3.6a can start:** the integrator writes `Platform/Flows/You.swift` (the protocol the views read, below) from this contract, as they did `Journal.swift`. The shape here is the proposal; the integrator owns the file.

```swift
// Platform/Flows/You.swift (integrator; proposal)
@MainActor protocol YouData: AnyObject, Observable {
  var map: Loadable<YouMap> { get }                      // nodes, edges, waiting, counts
  var newNodeRefs: Set<NodeRef> { get }                  // refs not in the last map seen (M12); cleared by markMapSeen()
  func markMapSeen()
  var portrait: Loadable<Portrait> { get }
  var understanding: Loadable<Understanding> { get }
  func node(_ ref: NodeOrClaimRef) async -> Loadable<NodeDetail>
  func stillTrue(_ claim: ClaimRef) async -> VerdictOutcome         // .confirmed, .queued (offline), .failed(Failure)
  var questions: [SamePersonQuestion] { get }
  func answer(_ question: SamePersonQuestion.ID, _ verdict: SamePersonVerdict) async -> QuestionOutcome
  var search: SearchState { get }                        // .idle, .searching(query, since), .result(SearchResult), .failed(query, Failure)
  func search(_ query: String) async
  func cancelSearch()
  var onlyCertain: Bool { get set }                      // remembered on this phone (founder question 6, lean)
  func source(_ ref: SourceRef) async -> Loadable<OpenedSource>
  var isOnline: Bool { get }
}
```

---

### PL3.6a · You: wire models, fixtures and cached reads                    size: S
Place in the tree: you › live data › wire models and cached reads
Repo · branch: NPRdoinglaundry · `pl/PL3.6a-you-wire`
Needs: PL2.4 (`CachedRead`), PL1.1 (typed client), contract 05 and `fixtures/05/` merged, `Platform/Flows/You.swift` (integrator)      Unblocks: PL3.6b–PL3.6e, UI5.0 (it decodes the same fixtures for its sample shapes)

Why: You opens instantly with what you saw last, even offline, and the app and server agree on every field.

Inputs: contract 05 §1–§8, every `fixtures/05/*.json`; contract 00 §2 (envelope, errors); PL2.4's `CachedRead`; contracts README rules 1–5.

Spec:
- `Platform/Backend/Wire/You.swift`: `Decodable` structs for every response in contract 05, explicit `CodingKeys` only where names differ; every enum has an `unknown` case decoded from any other string (`NodeKind`, `ClaimKind`, `Via`, `Sureness`, slots, areas, `sure`, abstain reasons, waiting kinds); dates through the shared ISO 8601 (milliseconds) decoder; `YYYY-MM-DD` days as a `LocalDay` value type (already in PL2.x; reuse).
- Endpoints in `Platform/Backend/Endpoints/You.swift` (type per route, PL1.1's pattern): `YouMap`, `YouNode(kind:id:)`, `YouClaimVerdict`, `YouPortrait`, `YouQuestions`, `YouQuestionAnswer`, `YouSearch`, `YouSource(kind:id:)`, `YouUnderstanding`.
- `CachedRead` keys and max ages: `you.map` 5 min, `you.portrait` 60 min, `you.understanding` 5 min, `you.node.<kind>.<id>` 5 min (≤ 50 kept, least recently used dropped), `you.questions` 5 min. Search is never cached on disk.
- The store's on-disk cache is in the app's `Caches/Platform/` (purgeable) like PL2.4; the content is the person's own and never leaves the phone.

Steps: wire structs → fixture decode tests → endpoints → cache keys.

Acceptance: every fixture in `fixtures/05/` decodes; an unknown enum value decodes as `unknown` and is counted (not logged).

Tests (layers 4, 5):
- `every contract 05 fixture decodes`
- `an unknown node kind decodes as unknown`
- `an unknown via decodes as unknown and is counted, never logged with its value`
- `a missing optional field and a null decode the same`
- `cached reads use their max ages` (injected clock)

Proof: test output.

Watch out: `Node.ref.kind` is `unknown` for fact and answer nodes by design (contract §3); the claim carries the ref. Don't treat that `unknown` as an error.

---

### PL3.6b · The map and the portrait on real data                          size: M
Place in the tree: you › live data › map and portrait
Repo · branch: NPRdoinglaundry · `pl/PL3.6b-you-map`
Needs: PL3.6a; backend BE5.5c (`/v2/you/map`), BE5.2b (`/v2/you/portrait`)      Unblocks: the You wiring PR (integrator), M12 on live data

Why: your map shows the people, themes and goals the brain really holds, and anything new since you last looked blooms in once.

Spec:
- `LiveYouData.map: Loadable<YouMap>` from `CachedRead("you.map")`: cached value at once, fresh value replaces it; `.failed` keeps the cached value with the error (C38's "couldn't update · showing what's saved").
- **New nodes (M12):** `Platform/Flows/YouMapSeen` persists the set of node refs from the last map the person *saw* (GRDB table `you_map_seen(ref text primary key, seen_at)`, one migration in the store's migrator, PL2.0's pattern). `newNodeRefs` = fresh refs − seen refs, computed only when a seen set exists (the very first map blooms nothing; it lands with the map-open choreography instead). `markMapSeen()` (called by P18 once the bloom has played) writes the current refs in one transaction.
- `portrait: Loadable<Portrait>` from `CachedRead("you.portrait")`, loaded when the list view opens (not with the map).
- Refresh triggers: app foreground after 5 minutes, pull to refresh on YO-1, and after `stillTrue`, `answer(_:_:)` or a correction (contract 02) succeeds.
- `isOnline` mirrors `Backend.Reachability`.

Tests (layer 5):
- `the cached map shows at once and the fresh one replaces it`
- `a failed refresh keeps the cached map and reports the failure`
- `nodes not in the last seen map are new; the first map has none new`
- `marking the map seen clears the new nodes`
- `a confirmed claim refreshes the map`
- `no log line carries a node label`

Proof: test output; a recording of YO-1 on local staging (integrator, test account) with one new node seeded.

Watch out: the seen set must store refs only (kind and UUID), never labels. A merged person (after "same") changes refs: the merged-away ref simply disappears; the survivor is not "new" (it was seen).

---

### PL3.6c · One node, "still true" and "same person?"                     size: M
Place in the tree: you › live data › one node, verdicts, questions
Repo · branch: NPRdoinglaundry · `pl/PL3.6c-you-node`
Needs: PL3.6a, PL2.2 (outbox), PL3.1e (corrections, reused for "not right"); backend BE5.5c, BE5.3c, BE5.1b      Unblocks: P21 on live data

Why: tapping anything on the map shows what Retro believes and why; "still true" and "same person" are saved even when you're offline, exactly once.

Spec:
- `node(_:)` → `GET /v2/you/nodes/:kind/:id` through `CachedRead("you.node.<kind>.<id>")`; `not_found` → `.gone` (the sheet says "this isn't here any more." and closes on dismiss).
- `stillTrue(_:)`: an outbox operation `you.claim.verdict` (PL2.2's operation registry; payload `{ kind, id }`, key = a new UUID stored with it); the node's `claim.confirmed` flips at once (optimistic) and the "still true" pill shows its confirmed state; a refused verdict (`not_found`) reverts and returns `.failed`. Offline → `.queued`, pill confirmed, sends on reconnect once.
- "not right" calls the journal's `correct(text:about:)` / `confirm(…)` from `LiveJournalData` (PL3.1e) with `about = claim.ref`; after `.applied`, the node and map caches are invalidated. No second corrections client.
- `questions` from `CachedRead("you.questions")`; `answer(_:_:)` is an outbox operation `you.question.answer` (idempotent server-side by the stored status), optimistic removal from `questions`, map refetch on success.

Tests:
- `a node opens from cache, then refreshes`
- `a node that's gone reads as gone`
- `still true updates at once and is sent once after ten retries`
- `still true offline waits and sends once when back`
- `a refused still true reverts`
- `not right reuses the journal's correction flow and refreshes the node`
- `answering same removes the question and refreshes the map`
- `no log line or outbox payload in a log carries a claim's text`

Watch out: the outbox payload holds ids only (never claim text), so a crash report or a log of the outbox can't leak content.

---

### PL3.6d · What Retro knows, on real data                                size: S
Place in the tree: you › live data › understanding
Repo · branch: NPRdoinglaundry · `pl/PL3.6d-you-understanding`
Needs: PL3.6a; backend BE5.3c      Unblocks: P22 on live data

Spec: `understanding: Loadable<Understanding>` from `CachedRead("you.understanding")`, loaded when YO-5 opens and refreshed after a verdict or a correction; areas always eight, in order (an `unknown` area is dropped and counted); answer rows keep the server's order.

Tests: `areas arrive in order and an unknown one is dropped` · `a correction refreshes what Retro knows` · `offline shows the cached areas with the offline line` · fixtures `understanding*.json` map to the view models.

---

### PL3.6e · Search on real data                                          size: M
Place in the tree: you › live data › search
Repo · branch: NPRdoinglaundry · `pl/PL3.6e-you-search`
Needs: PL3.6a; backend BE5.4b      Unblocks: P19 on live data

Why: you ask once, the answer comes back with its sources, a dropped connection never pays twice, and "only what's certain" stays the way you left it.

Spec:
- `search(_ query:)`: trims; empty → `.idle`. Cancels any search in flight (`Task` cancellation, the request cancelled with it); a new `clientSearchId` (UUID) per submitted query; `state = .searching(query, since: clock.now)`; on result `.result`; on failure `.failed(query, failure)` with contract 00's mapping (`spend_limited` and `rate_limited` show their messages; `upstream_timeout` and network failures offer "try again", which **re-sends with the same `clientSearchId`**, so a result the server already made is returned free).
- Offline: no request; `.failed(query, .offline)` at once ("search needs a connection").
- Not queued in the outbox (the person is waiting for it) and never cached on disk; the last result is kept in memory while the app runs, so going to YO-4 and back shows it again.
- `onlyCertain`: `@AppStorage`-style storage through `Platform.Preferences` (key `you.search.onlyCertain`, default false); a view filter only, never a new request.
- `source(_:)`: `entry` with `via` journal/voice/conversation → the caller opens JR-4 (this returns `.redirect(.entry(id))`); other entries and saved → `GET /v2/you/sources/…`; fact and answer → `.redirect(.node(...))`.
- The query is never logged, never in analytics, never in a URL or a crash breadcrumb.

Tests:
- `a new search cancels the one in flight`
- `try again re-sends the same client search id`
- `offline fails at once without a request`
- `spend limited shows its message and offers no retry until tomorrow`
- `only certain is remembered across launches` (injected preferences)
- `an own-words source opens the entry, a record opens the source page, a fact opens the node`
- `no log line, event or breadcrumb carries the query` (scan the sinks)

Watch out: a search can take 5–10 s. The view shows "still working" after 8 s (C39.4) from `since`; the platform must not time out before the door's 30 s.

---

### PL3.6f · Routes into You                                               size: S
Place in the tree: you › live data › routes (notifications, widgets, links)
Repo · branch: NPRdoinglaundry · `pl/PL3.6f-you-routes`
Needs: PL5.2 (the router)      Unblocks: P21 from a notification (EX-3 "one question for you" → YO-4), T05c's deep-link step

Why: "one question for you, when you have a minute." opens exactly that question; a link to a person opens them.

Spec:
- `Destination` gains `.you`, `.youNode(NodeOrClaimRef)`, `.youQuestion(id: String)`, `.youSearch` (opens YO-1 with the field focused). Parser: `retrospect://you`, `retrospect://you/node/<kind>/<uuid>`, `retrospect://you/question/<uuid>`, `retrospect://you/search` (no query in links, ever: a query is personal content).
- Kinds and ids validated (closed kinds, UUIDs); anything else is dropped and counted.
- `.youQuestion` resolves through `questions` (and the contract 02 guesses); a question already answered opens YO-1 instead.

Tests: `each You link parses to its destination` · `a bad kind or id is dropped` · `a link never carries a query` (the parser refuses a `q` parameter) · `an answered question opens You`.

Watch out: notification payloads stay content-free (BE2.7): an id and the path, never a name.
