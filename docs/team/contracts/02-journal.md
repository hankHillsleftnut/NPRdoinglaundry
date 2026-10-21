# Contract 02 · The journal

The first full slice: JR-1 (the journal thread, where you send things into your bank, with today's brief on top), JR-2 (today's brief), JR-3 (all entries, in the drawer) and JR-4 (one entry, what Retro took, "not right"). Built on contract 00. Status: **draft for the founder's review**. Every agent field below was read from the agent's code on 21 Oct (`../reference/agent-api-reference.md` §1–§4, §9.3, §10); where the agent can't give what the screen needs, the byte that fixes it is named.

## 1. Shared types

```ts
// A reference to something Retro used or can show. The door maps the agent's kinds onto these.
type SourceRef = {
  kind: "entry" | "fact" | "answer" | "pattern" | "saved" | "turn";   // agent: item→entry, said_today→turn
  id: string;                                                         // UUID (BE1.0 replaces said_today timestamps)
  label?: string;                                                     // a short plain line, when the door can give one cheaply
};

// (A Turn type for Retro's replies arrives with the v2 conversation.)
```

## 2. The journal thread: sending into your bank

**Founder, 21 Oct:** the journal isn't a conversation with Retro yet. You send things into your bank (thoughts, journal entries, voice notes); Retro acknowledges with a short canned line chosen on the phone. No model call, no streaming. A real conversation is v2 and will be rethought.

`GET /v2/entries/today` → `{ "date": "2026-10-21", "entries": Entry[] }` (the user's local day, oldest first).

`POST /v2/entries` — idempotent (`Idempotency-Key: <clientEntryId>`)
```json
{ "text": "dentist at 3 today, dreading it", "kind": "typed", "clientEntryId": "<uuid>", "createdAt": "2026-10-21T13:02:11.410Z" }
```
→ `{ "entry": Entry }`. Repeating the key returns the same entry.

**The acknowledgement** is not from the server. The app shows one short line from a fixed set after each send (copy to be written with the founder, lowercase, in Retro's voice, never pretending to have understood: for example "got it." / "saved." / "it's in."), picked so the same line doesn't repeat twice in a row. Offline, the line waits until the entry is actually sent; until then your bubble shows "waiting to send".

*Deferred to v2:* `POST /v2/conversation` (buffered reply) and `POST /v2/conversation/stream` (streamed reply), as designed in the plan's deferred bytes.

## 3. Today's brief

```ts
type Brief = {
  id: string;
  date: string;                          // YYYY-MM-DD, the user's local day
  kind: "brief" | "quiet";
  parts: Array<{                          // what's spoken, in order
    text: string;
    why?: string;                         // "here for your goal: …" (v1 items with a why)
    sources: SourceRef[];
    startSeconds?: number;                // when brief audio exists (BE1.3b)
  }>;
  audio?: { url: string; expiresAt: string; durationSeconds: number };   // signed, private (BEA.7, BE1.3b)
  createdAt: string;
};
```
- **Mapping from the agent** (`daily_briefs`): v1 rows → one part per item (`text`, `why`, `sources` from `sourceRef.raw_content_id`). v2 rows → the spoken brief is `through_line`, split into parts at paragraph breaks; the v2 `items` are bookkeeping and are **never** shown (they contain the bare words "pattern" or "answer"). `kind: "quiet"` keeps the agent's line ("nothing new since your last brief. i'll keep listening.").
- `audio` is absent until BE1.3b ships (briefs have no audio today) and absent on quiet days.

`GET /v2/briefs/latest` → `{ "brief": Brief | null, "enabled": true }` (`enabled` is the user's brief switch; off by default, founder 21 Oct).
`GET /v2/briefs?cursor=<opaque>&limit=20` → `{ "briefs": Brief[], "nextCursor": "…" | null }` (no audio in the list).
`PUT /v2/briefs/enabled` `{ "enabled": true }` → `{ "enabled": true }`.

## 4. Guesses (the guess cards)

```ts
type Guess = {
  id: string;
  question: string;                      // always a question
  framework: { name: string; source?: string; wonders?: string };
  rationale?: string;
  status: "offered" | "confirmed" | "declined" | "expired";
  restsOn: Array<SourceRef & { text: string }>;   // the door resolves each {kind,id} to text (the agent gives ids only)
};
```
`GET /v2/guesses` → `{ "guesses": Guess[], "speaking": true }`. `speaking` is the founder's master dial (`product_dials.hypotheses.speak`, off today; decision D11); when false, `guesses` is `[]`.
`POST /v2/guesses/:id` `{ "verdict": "yes" | "no" }` → `{ "status": "confirmed" | "declined" }`. Idempotent: answering an already-answered guess returns its stored status (the agent 404s on a repeat; the door reads state first).
`GET /v2/guesses/:id/why` → `Guess`.

## 5. Entries

```ts
type Entry = {
  id: string;                             // raw_content.id
  kind: "typed" | "voice" | "conversation" | "imported";   // from content_type (text_entry, journal_entry, manual_journal, note → typed; voice_recording, voice_journal → voice; conversation → conversation; everything else the person sent → imported)
  text: string;
  createdAt: string;
  day: string;                            // YYYY-MM-DD local
  reading: "waiting" | "reading" | "read" | "failed";      // processing_status pending | processing | completed | failed
  clientEntryId?: string;                 // the app's Entry.id when it sent one (the outbox key)
};
```
Only the person's own words are listed (the "sent by the person" set in the agent's planner), never records, mail or third-party items.
`GET /v2/entries?cursor=&limit=50&q=` → `{ "entries": Entry[], "nextCursor": … }`. `q` searches the person's own entries only (matched words come back as ranges for highlighting: `matches: [{ start, length }]`).
`GET /v2/entries/:id` → `{ "entry": Entry }`.
`PATCH /v2/entries/:id` `{ "text": "…" }` → `{ "entry": Entry }` (editing re-sends it for reading: "retro is reading it again").
`DELETE /v2/entries/:id` → `{ "deleted": true }`; deleting removes everything taken from it (the founder's rule K7; the door confirms the cascade in BE1.5).

## 6. What Retro took, and "not right"

`GET /v2/entries/:id/took` → 
```json
{ "items": [ { "kind": "fact", "id": "…", "text": "you're training for a half marathon", "sureness": "fairly sure" } ], "reading": "read" }
```
`sureness`: `just a hunch | fairly sure | very sure` from the agent's confidence (thresholds in the contract fixtures: < 0.5, < 0.8, ≥ 0.8; founder to confirm the words). `items` is `[]` with `reading: "waiting"` when nothing has been read yet ("nothing taken yet" fills in on its own).

`POST /v2/corrections` `{ "text": "i stopped running in september", "about": { "kind": "fact", "id": "…" } }` (`about` optional: present when "not right" is tapped on a specific item) → one of:
```json
{ "outcome": "applied", "target": { "kind": "fact", "id": "…", "text": "…" }, "retired": 3, "echo": "got it. i'll stop saying \"training for the half marathon\", and 2 things built on it." }
{ "outcome": "confirm", "candidates": [ { "kind": "answer", "id": "…", "text": "…" } ] }
{ "outcome": "askOwnWords", "target": { … }, "quote": "i am going to run the half in march", "writtenOn": "2026-09-02" }
{ "outcome": "notACorrection" }
```
`POST /v2/corrections/confirm` `{ "kind": "fact", "id": "…", "mode": "wrong" | "changed", "note": "…" }` → `{ "outcome": "applied", "retired": 3, "target": { … }, "echo": "…" }` (the door adds `target` and `echo`, which the agent's confirm route omits, and checks ownership first: BEA.2).
Blocked until **BEA.1** (corrections that touch an answer fail in production today).

## 7. Decisions the founder makes for this contract

1. **Sureness words** (§6): "just a hunch / fairly sure / very sure", and their thresholds.
2. **A corrected claim** stays visible as "noted" (struck through) or disappears.
3. **Message state** (waiting to send, sent): shown on every message, or only the latest and unsent ones.
6. **The acknowledgement lines** Retro shows after you send something (§2).
4. ~~Brief audio~~: **decided 21 Oct, briefs are audio**; `audio` ships with BE1.3b.
5. **Guesses speaking** (D11): turn the `speak` dial on for the beta.

## 8. Fixtures

`fixtures/02/`: `entries.today.json`, `entries.today.empty.json`, `entry.create.request.json`, `entry.create.response.json`, `brief.latest.v1.json`, `brief.latest.v2.json`, `brief.latest.quiet.json`, `brief.latest.none.json`, `briefs.list.json`, `guesses.json`, `guesses.silent.json`, `guess.answer.json`, `entries.list.json`, `entries.search.json`, `entry.json`, `took.json`, `took.waiting.json`, `correction.applied.json`, `correction.confirm.json`, `correction.ask.json`, `correction.not.json`, `error.*.json` for each code the doors can return.
