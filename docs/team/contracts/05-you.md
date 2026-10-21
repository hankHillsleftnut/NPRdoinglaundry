# Contract 05 · You

The fifth slice: YO-1 (you, at a glance: the map of the people, themes and goals in your life), its list view (the portrait), YO-2 (search: "ask your life anything"), YO-3 (a source opened from search), YO-4 (one person, theme, goal or claim: what Retro believes, how sure, and why) and YO-5 (what Retro knows about you, by area). Built on contract 00, and it reuses contract 02's `SourceRef`, `Guess`, sureness words and corrections. Status: **draft for the founder's review**. Every agent field below was read from the agent's code at `origin/main` `a886060` (21 Oct); where the agent can't give what the screen needs, the brain byte that adds it is named (cards in `../flows/you/backend.md`).

All doors live under `/v2/you/…` except where contract 02 already owns the shape. Every door takes the user from the token (contract 00), never from the path.

## 0. What the brain has, and what it lacks (21 Oct)

| Screen need | In the brain today | Gap, and the byte that closes it |
|---|---|---|
| People on the map, ranked | `pulls.significantPeople` (`src/brain/pulls.ts:289`), significance in `entities.attributes` | takes the first 50 person rows **before** sorting, so it misses people in a large set; significance is refreshed only when a journal fact touches a person (`write-journal-facts.ts:186`), so contact and calendar people have none. **BE5.1a** |
| Themes on the map | live patterns (`livePatterns`, `behavior_patterns.label`) | no route. **BE5.5a** (founder question 1: what a theme is) |
| Goals on the map | `readUnderstanding().goals` (filters `is_active`) | no route. **BE5.5a** |
| Lines between nodes | nothing | **BE5.5b** (shared evidence between nodes, counted) |
| One person, theme or claim with its evidence | `factsAbout`, `pattern()`, `walkEvidence` (unscoped until BEA.2) | no route; no single read model. **BE5.0**, **BE5.1a** |
| "same person?" questions | `GET /people/:userId/held`, `POST /people/:userId/held/:id` (`src/routes/people.ts`) | exists; English sentence built in the agent, capitalised. The door passes names only. **BE5.1b** |
| The portrait | `buildPortrait` (`src/brain/portrait.ts:122`) | no route; `significant_people`, `open_threads`, `what_changed` always empty; reads `object_value.text` while everything else reads `.raw`. **BE5.2a** |
| What Retro knows, by area | `readUnderstanding` (`src/understanding/read.ts:113`) | no route; questions are written about "they" ("What have they said they want?"). **BE5.3a** |
| "still true" | answers: `record_answer_verdict` exists with no route; facts: nothing | **BE5.3b** |
| Search with a synthesis | `POST /search/answer` (`src/search/answer.ts:74`) | `[n]` markers left inside `summary`; no per-sentence sureness (the "a guess:" sentence and the "only what's certain" switch need it); abstain reasons are capitalised English; item dates use `created_at`, not `content_date`; item sources don't say what they are (journal, calendar, mail); `trustOfItems` isn't user-scoped. **BE5.4a** |
| Opening a source | `GET /search/:userId/source/:kind/:id` | fact evidence lookup not user-scoped (BEA.2); item date from `created_at`. **BE5.4a** |

## 1. Shared types

```ts
// contract 02 §1, reused as is.
type SourceRef = { kind: "entry" | "fact" | "answer" | "pattern" | "saved" | "turn" | "unknown"; id: string; label?: string };

// contract 02 §6: "just a hunch" < 0.5 ≤ "fairly sure" < 0.8 ≤ "very sure". One exported constant in the door (BE1.6's).
type Sureness = "just a hunch" | "fairly sure" | "very sure" | "unknown";

// Where a piece of evidence came from, for the 20pt glyph in its well and the "date · kind" label.
type Via = "journal" | "voice" | "conversation" | "calendar" | "mail" | "health" | "document" | "saved" | "listening" | "other" | "unknown";

// Something on the map, or something YO-4 can open.
type NodeKind = "person" | "theme" | "goal" | "unknown";
type ClaimKind = "fact" | "answer" | "pattern" | "goal" | "unknown";
type NodeRef = { kind: NodeKind; id: string };          // id: entities.id | behavior_patterns.id | goals.id
type ClaimRef = { kind: ClaimKind; id: string };        // id: assertions.id | question_answers.id | behavior_patterns.id | goals.id

// One row of evidence ("what it rests on"): always the person's own record of something.
type Evidence = {
  source: SourceRef;          // kind "entry" for raw_content the person sent, "saved" for a saved link; records (calendar, mail, health) are kind "entry" with via set
  via: Via;
  date?: string;              // YYYY-MM-DD, the user's local day, from coalesce(content_date, created_at)
  excerpt: string;            // ≤ 280 characters, the exact words (assertion_evidence.excerpt, else the start of the content)
  stance: "supports" | "contradicts" | "unknown";
};
```

Rules that hold everywhere in this contract:
- **Register.** Anything the brain holds below its bar is a guess (`isGuess: true` / `sure: "guess"`), and the app always shows it as a question or with "a guess:", never as a fact (the claim ladder; context.md §3). The register is decided in the brain from counted confidence (`readUnderstanding`'s `stated | asked`), never in the app.
- **No invented data.** A node, line, area or sentence exists only when a live row backs it. Empty means empty.
- **Content never leaves the response.** Doors log counts and enum values only: no names, no queries, no excerpts, no labels (testing.md §2 "no content").

## 2. The map (YO-1)

`GET /v2/you/map` → (bucket `read`, cached per user for 5 minutes in the door)
```ts
{
  "map": {
    "asOf": "2026-10-21T08:00:04.200Z",
    "nodes": MapNode[],          // ≤ 24, best first within each kind
    "edges": MapEdge[],          // ≤ 48
    "waiting": Waiting | null,   // the one thing that "glows quietly" and the "one question waiting" row
    "counts": { "people": 31, "themes": 4, "goals": 3 }   // how many exist, so the list view can say "and 26 more"
  }
}
type MapNode = {
  ref: NodeRef;
  label: string;                 // the person's name as written, the pattern's label, the goal's title
  weight: number;                // 0..1: significance (people), pattern confidence (themes), 1.0 for a stated goal; sizes the orb
  sureness: Sureness;            // for people "very sure" (they exist); themes from confidence; goals "very sure" (you said so)
  isGuess: boolean;              // drawn as a dashed ring (inference.border): an unconfirmed person match, a provisional theme
  lastMovedAt?: string;          // newest evidence; drives nothing on the map, shown on YO-4
};
type MapEdge = { from: string /* "you" or a node id */; to: string /* node id */; strength: number /* 0..1 */ };
type Waiting = { kind: "samePerson" | "guess" | "unknown"; id: string; about?: NodeRef; aboutLabel: string };
```
- **Which nodes** (founder question 1 and 3, leans): people with significance ≥ 0.1 (top 10), live themes (top 8: `behavior_patterns.status = 'live'`), active goals (top 6). A kind with fewer leaves its quota unused; nothing is padded.
- **Positions are not in the contract.** The map is hand-crafted by the founder (build notes, "You map"); the app places nodes on the slot table drawn in Paper (C38.1), in `weight` order per kind.
- **Edges:** every node has an edge to `"you"` with `strength = weight`. Node-to-node edges exist only where two nodes share at least 2 pieces of evidence (BE5.5b), `strength = min(1, shared / 6)`.
- **New nodes (M12)** are found by the app, not the server: the app compares node refs with the last map it cached; a ref not seen before blooms in once.
- `waiting`: the first pending "same person?" question (§5), else the first offered guess from contract 02 §4 (only when `speaking` is true), else `null`.
- Empty (day one): `nodes: []`, `edges: []`, `waiting: null`, counts all 0. The app shows "just you, so far." / "this fills in as you talk to me." (Paper copy).

## 3. One node or claim (YO-4)

`GET /v2/you/nodes/:kind/:id` where `kind` ∈ `person | theme | goal | fact | answer` (bucket `read`). Ownership: the row must be the user's, else `not_found`.
```ts
{ "node": {
  "ref": { "kind": "person", "id": "…" },          // for fact | answer, ref.kind is "unknown" and claim carries the ref
  "kindLabel": "person",                            // the header word: "person" | "theme" | "goal" | "belief"
  "name": "priya",                                  // the header's second word: a name, or a short label (≤ 40 chars)
  "claim": {
    "ref": { "kind": "fact", "id": "…" },
    "text": "priya is your sister",                 // what Retro believes, in plain words; the inky 2xl line
    "sureness": "fairly sure",
    "isGuess": false,
    "sourceCount": 5,                               // "from 5 things": distinct evidence rows
    "movedAt": "2026-10-14T19:02:11.000Z",          // "moved last week" (the app words it relative to today)
    "confirmed": false,                             // the person already said "still true"
    "canConfirm": true                              // false for patterns and goals (no "still true" there)
  } | null,                                         // null: nothing Retro can state yet (a person with mentions but no fact)
  "mentions": 5,                                    // people only: how many times they come up (a count, never invented)
  "evidence": Evidence[],                           // ≤ 20, newest first
  "evidenceTotal": 12,
  "linked": Array<{ ref: NodeRef; label: string }>, // ≤ 8, the chips: nodes sharing evidence (the map's edges)
  "question": SamePersonQuestion | null              // the guess state: "is this the same sam as sam okafor in your contacts?"
} }
```
- **Headline per kind** (BE5.0, BE5.1a): person → the most supported live fact where the person is subject or object (`mentioned_person`, `communicated_with`, …), else `claim: null` and the app shows the name with "comes up 5 times" (a count; no relationship is ever invented: founder question 9); theme → the pattern's label, `sureness` from confidence, `isGuess` when the pattern isn't promotable; goal → the goal's title, `sureness` "very sure", `canConfirm: false`; fact → the fact's human text (`object_value.raw ?? .normalized ?? .text`, the same key everywhere after BE5.2a); answer → the answer text, `isGuess` from `register == "asked"`.
- **"still true"** `POST /v2/you/claims/:kind/:id/verdict` (`kind` ∈ `fact | answer`) `{ "verdict": "stillTrue" }`, header `Idempotency-Key: <uuid>` → `{ "confirmed": true }` (bucket `write`). Repeating it returns the same; confirming someone else's claim is `not_found` and writes nothing. A rejected or retired claim is `not_found`.
- **"not right"** is contract 02 §6 unchanged: `POST /v2/corrections { text, about: claim.ref }` → `confirm`, then `POST /v2/corrections/confirm`. Patterns: `about.kind = "pattern"` is added to contract 02 §6's accepted kinds (BE1.7's door already maps patterns through the agent's correction targeting; the integrator confirms in contract 02 before BE5.3c).
- Opening an evidence row: `source.kind == "entry"` and `via` ∈ journal, voice, conversation → JR-4 (contract 02 `GET /v2/entries/:id`); any other `via` → YO-3 through §6's `GET /v2/you/sources/…`; `saved` → YO-3.

## 4. The portrait (YO-1 list view)

`GET /v2/you/portrait` → (bucket `read`; the agent builds it, no model calls; the door caches it per user for 1 hour)
```ts
{ "portrait": {
  "builtAt": "2026-10-21T08:00:04.200Z",
  "sections": Array<{
    "slot": "goals" | "state" | "tensions" | "people" | "threads" | "selfTalk" | "changed" | "unknown",
    "lines": Array<{ "text": string; "ref"?: NodeRef | ClaimRef }>   // ≤ 6 per section; ref opens YO-4
  }>,
  "empty": Array<"goals" | "state" | "tensions" | "people" | "threads" | "selfTalk" | "changed">
} }
```
- Mapping from `PortraitDocument`: `current_goals → goals`, `current_state → state`, `live_tensions → tensions`, `significant_people → people`, `open_threads → threads`, `self_talk_now → selfTalk` (lines are the person's own words in quotes), `what_changed → changed`. Sections with `populated: false` are listed in `empty` and **not** in `sections`.
- BE5.2a fills `people` (from the fixed `significantPeople`, `"<name>"` lines with the person's ref) and `changed` (from `changedSince` over 14 days and `moves`: "you stopped …", "new: …", lines built only from live rows; each carries its ref). `threads` stays empty until the brain has open threads (not in this contract).
- Section titles are the app's copy (lowercase, founder to approve): goals "what you're working toward", state "how you've been", tensions "what keeps coming up", people "the people around you", selfTalk "how you talk about yourself", changed "what changed lately".

## 5. "Same person?" questions

`GET /v2/you/questions` → `{ "questions": SamePersonQuestion[] }` (bucket `read`, ≤ 20, oldest first)
```ts
type SamePersonQuestion = { id: string; kind: "samePerson"; inYourWriting: string; inYourContacts: string; writingRef?: NodeRef; contactRef?: NodeRef };
```
The app writes the sentence ("is this the same sam as sam okafor in your contacts?"); the agent's English `question` field is dropped.
`POST /v2/you/questions/:id` `{ "verdict": "same" | "different" }` → `{ "status": "linked" | "keptApart" }` (bucket `write`). Idempotent: a repeat returns the stored status (the agent throws "no pending pair" on a repeat; the door reads the row first, as BE1.4 does for guesses). After `same`, the map's two nodes are one; the app refetches the map.

## 6. Search (YO-2) and opening a source (YO-3)

`POST /v2/you/search` (bucket `expensive`; counted against the spend cap by BEA.4; timeout 30 s; retry none)
Header `Idempotency-Key: <clientSearchId>` (a UUID per submitted query): the door keeps the result in memory for 10 minutes per user and key, so a retry after a dropped connection returns the same answer without paying again. Same key with a different query → `idempotency_mismatch`.
```json
{ "query": "when did i stop running", "clientSearchId": "6f1c…" }
```
`query`: trimmed, 1–200 characters. It travels only in the body, never in a URL, a log line or an analytics event.
→
```ts
{ "search": {
  "id": "6f1c…",                              // = clientSearchId
  "query": "when did i stop running",
  "outcome": "found" | "abstained" | "unknown",
  "sentences": Array<{                        // "what i found": 0..5, in the writer's order
    "text": string,                           // citations removed (the agent's citations() helper)
    "cites": number[],                        // source numbers, 1-based, each present in sources
    "sure": "certain" | "guess" | "unknown"   // BE5.4a; "guess" sentences are drawn as "a guess: …" and hidden by "only what's certain"
  }>,
  "guessCount": number,                       // "hides the 1 guess"
  "abstain": { "reason": "nothingFound" | "notAnswered" | "couldNotWrite" | "ownWordsOnly" | "unknown", "why"?: string } | null,
  "sources": Array<{
    "n": number,                              // 1-based; the numbered well and the citation chip
    "source": SourceRef,                      // entry | fact | answer | saved
    "via": Via,
    "date"?: string,                          // YYYY-MM-DD local
    "snippet": string,                        // ≤ 400 characters
    "matches": Array<{ "start": number; "length": number }>   // the query's own words in the snippet (UTF-16 offsets), for accent.text
  }>                                          // ≤ 15
} }
```
- **`sure` (BE5.4a, deterministic, no model call):** a sentence is `certain` when at least one source it cites is the person's own words (`entry` with trust class `own_words`), a record of what happened (`entry` with trust class `record`), an observed or person-confirmed fact, an answer in the `stated` register, or something they saved; otherwise it is a `guess` (it rests only on inferred facts, answers in the `asked` register, or third-party and automated items). Founder question 6.
- **Abstaining:** `outcome: "abstained"`, `sentences: []`, `guessCount: 0`. `reason`: `nothingFound` (no sources: "nothing in your bank speaks to this yet."), `notAnswered` (sources exist but none answers it; the app shows "the closest:" and the sources), `couldNotWrite` (the writer failed twice; sources shown), `ownWordsOnly` (a judgement about the inner state with nothing in their own words; `why` carries the model's one plain sentence, lowercased by the door). The app owns the copy for the first three.
- **All sentences cut by the guard** → `abstained` with `notAnswered` (the agent's own rule, `answer.ts:110`).
- `matches`: computed in the door: each query word of 3+ letters, case- and diacritic-insensitive, all occurrences. Semantic hits may have none; that's fine.

`GET /v2/you/sources/:kind/:id` (`kind` ∈ `entry | saved`; bucket `read`; ownership) → used for records and saved links (own-words entries open JR-4 through contract 02):
```ts
{ "source": {
  "source": SourceRef, "via": Via, "date"?: string,
  "title": string,                            // "calendar", "mail", or a saved link's title
  "body": string,                             // the full text; for a saved link its summary ("" when none)
  "url"?: string,                             // saved links only; opened in Safari, never fetched by the app
  "yourReason"?: string                       // saved links: why you saved it, in your words
} }
```
Facts and answers from search open YO-4 through §3.

## 7. What Retro knows, by area (YO-5)

`GET /v2/you/understanding` → (bucket `read`; door cache 5 minutes)
```ts
{ "understanding": {
  "asOf": "2026-10-21",
  "moved": { "since": "2026-10-14", "answersChanged": 2 },   // from moves; since null → answersChanged 0 and the row is hidden
  "areas": Array<{
    "id": "who" | "want" | "do" | "attention" | "people" | "how" | "inTheWay" | "speak" | "unknown",   // in_the_way → inTheWay
    "silent": boolean,                       // the domain hasn't earned the right to speak: no answers, one warm sentence
    "answers": AnswerRow[]                   // [] when silent
  }>                                         // always the 8 areas, in question-store order
} }
type AnswerRow = {
  id: string;                                // question_answers.id (opens YO-4 as kind "answer")
  questionId: number;
  question: string;                          // second person, from canonical_questions.you_text (BE5.3a): "what have you said you want?"
  answer: string;
  sureness: Sureness;
  dots: 1 | 2 | 3 | 4;                       // confidence < 0.25 → 1, < 0.5 → 2, < 0.8 → 3, else 4 (founder question 7)
  isGuess: boolean;                          // register "asked"
  sourceCount: number;                       // independent sources: "from 3 things"
  confirmed: boolean;
  movedThisWeek: boolean;                    // in moves.items
};
```
Area titles and each silent area's warm sentence are the app's copy (founder to approve), never the brain's third-person labels ("Who they are").

## 8. Errors, limits, idempotency

| Door | Bucket | Idempotency | Errors beyond contract 00 §2 |
|---|---|---|---|
| `GET /v2/you/map` | read | n/a | — |
| `GET /v2/you/nodes/:kind/:id` | read | n/a | `not_found` (not theirs, retired, rejected, or unknown kind is `invalid_request`) |
| `POST /v2/you/claims/:kind/:id/verdict` | write | key required | `not_found` |
| `GET /v2/you/portrait` | read | n/a | — |
| `GET /v2/you/questions` · `POST /v2/you/questions/:id` | read · write | the stored status | `not_found` |
| `POST /v2/you/search` | expensive | key required (10 min replay) | `spend_limited`, `rate_limited`, `upstream_timeout` |
| `GET /v2/you/sources/:kind/:id` | read | n/a | `not_found` |
| `GET /v2/you/understanding` | read | n/a | — |

Enums are closed; unknown values decode as `unknown` and the door logs any value outside the list (contracts rule 5). Reads are never refused for spend (founder rule).

## 9. Decisions the founder makes for this contract

Each has a lean; the plan proceeds on the lean. Full options in `../flows/you/README.md` §8.
1. **What a theme is** on the map: live patterns (lean), content topics, or both.
2. **How live data meets the hand-crafted map:** the founder's slot table, filled by rank (lean).
3. **Node quotas:** 10 people, 8 themes, 6 goals (lean); places later.
4. **YO-3 merged into JR-4** for your own words; YO-3 kept for records and saved links (lean).
5. **Where the portrait lives:** the "list" pill opens it (lean; needs a Paper drawing).
6. **What counts as a guess in search** (the rule in §6), and whether "only what's certain" is remembered (lean: yes, on this phone).
7. **Sureness dots:** four dots by confidence quarter beside the three words (lean).
8. **The 36 questions in second person** (YO-5): the backend engineer drafts, you approve in the PR.
9. **A person with no fact yet:** name plus "comes up n times", never an invented relationship (lean).

## 10. Fixtures

`fixtures/05/`: `map.json`, `map.empty.json`, `node.person.json`, `node.person.nofact.json`, `node.theme.json`, `node.answer.guess.json`, `verdict.request.json`, `verdict.response.json`, `portrait.json`, `portrait.empty.json`, `questions.json`, `question.answer.request.json`, `question.answer.response.json`, `search.request.json`, `search.found.json`, `search.found.certain-only.json`, `search.abstained.nothing.json`, `search.abstained.closest.json`, `source.record.json`, `source.saved.json`, `understanding.json`, `understanding.dayone.json`, `error.not_found.json`, `error.spend_limited.json`, `error.rate_limited.json`, `error.upstream_timeout.json`, `error.idempotency_mismatch.json`, `error.invalid_request.json`. All content is invented ("sam", "priya", "the half marathon"), never a real person's.
