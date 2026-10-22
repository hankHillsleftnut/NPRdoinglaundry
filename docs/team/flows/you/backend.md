# You · backend cards (brain bytes and doors)

The tree for this side: **you** › the map (BE5.5a, BE5.5b, BE5.5c) › one node or claim (BE5.0, BE5.1a, BE5.5c) › "still true" (BE5.3b, BE5.3c) › "same person?" (BE5.1b) › the portrait (BE5.2a, BE5.2b) › what Retro knows (BE5.3a, BE5.3c) › search (BE5.4a, BE5.4b). Contract: [../../contracts/05-you.md](../../contracts/05-you.md). Every door is built with the kit (BE0.1), passes the door suite (BE0.2) and the invite gate (BE0.12). Every agent route gets a two-user PGlite test; every agent change that touches SQL runs its test under `SET ROLE service_role` (testing.md layer 2). Fixtures: the backend validates every `fixtures/05/*.json` response against the door's zod output schema (layer 4).

**Order** (two in review at once at most): BE5.0 → BE5.1a → BE5.1b → BE5.3a → BE5.3b → BE5.3c → BE5.2a → BE5.2b → BE5.5a → BE5.5b → BE5.5c → BE5.4a → BE5.4b. Search goes last on purpose: it's the only expensive door and needs BEA.4's ledger; everything before it is reads with no model calls.

**Phase prerequisites** (all from phase A, merged before phase 5): BEA.1 (writes under the service role), BEA.2 (every query scoped), BEA.4 (spend ledger), BE1.6's sureness constant, BE1.7 (corrections door).

**Migration numbers** below are placeholders (`16a`, `16b`, `16c`); the integrator assigns real numbers in phase-0.md before the first of them starts (phase-0.md's list ends at 157).

**Privacy in every card:** the agent and the door log counts, enum values, ids and durations only. Never a name, label, excerpt, query, answer or sentence. Each card's tests include "no content in logs" (a test sink scanned for the fixtures' words).

---

### BE5.0 · One claim and what it rests on (the claim reader)            size: M
Place in the tree: you › one node or claim › engine › `readClaim`
Repo · branch: agent · `agent/BE5.0-claim-reader`
Needs: BEA.2 (scoped `walkEvidence`, `factsAbout`, `pulls` sub-queries)      Unblocks: BE5.1a, BE5.5c, BE5.3c

Why: whenever Retro shows you something it believes, it can show how sure it is and every piece of your own record behind it, in one consistent shape.

Inputs:
- Contract: 05 §1 (`Evidence`, `Via`, `Sureness`), §3 (`claim`, `evidence`, `evidenceTotal`)
- Reference: agent-api-reference §9.2 (`readUnderstanding`, registers), §9.3 (`pulls`), §9.4 (`walkEvidence`), §10.2 (`assertions`, `assertion_evidence`), §10.4 (`answer_evidence`, `answer_confidence`)
- Code anchors: `src/brain/lineage.ts:31-64` (`walkEvidence`), `src/brain/pulls.ts:237-277` (`pattern`, `factsFor`), `src/understanding/read.ts:113-135`, `src/search/source.ts:24-30` (how a fact's evidence is read today)

Spec:
- New `src/brain/claim.ts`: `readClaim(userId, ref: { kind: 'fact'|'answer'|'pattern'|'goal'; id }, db = supabase): Promise<ClaimView | null>`:
  ```ts
  interface ClaimView { kind; id; text: string; confidence: number | null; register: 'stated'|'asked';
    sourceCount: number; movedAt: string | null; confirmed: boolean;
    evidence: Array<{ sourceKind: 'raw_content'|'reference_item'; sourceId: string; contentType: string|null; trustClass: string|null;
                      at: string|null; excerpt: string; stance: 'supports'|'contradicts' }>; evidenceTotal: number }
  ```
  - fact: the row must be the user's, `status = 'active'`; text `object_value.raw ?? .normalized ?? .text` (one helper `factText`, exported and used by BE5.2a and search so the three readers agree); confidence from the column; register `stated` when `assertion_kind ∈ (observed, user_confirmed)`, else `asked`; confirmed = `user_confirmed`; evidence from `assertion_evidence` (user-scoped) joined to `raw_content` (`content_type`, `trust_class`, `coalesce(content_date, created_at)`).
  - answer: from `current_answers` / `answer_confidence` (confidence, independent sources), register as `readUnderstanding` decides it (re-use its function, don't copy the rule), confirmed = `user_verdict = 'confirmed'`, evidence from `answer_evidence` where `retired_at is null` (raw_content directly; assertion and pattern evidence walked one step to their raw_content).
  - pattern: `behavior_patterns` (`status = 'live'`), text = label, confidence column, register `stated` when `episode_promotable`, else `asked`; evidence = `factsFor(pattern)` walked to raw_content.
  - goal: `goals` row (`is_active`), text = title, register `stated`, confidence null, evidence = `goal mentions` through `assertions` with predicate `stated_goal` linked to it when present, else `[]`.
  - Excerpts: `assertion_evidence.excerpt` / `answer_evidence.excerpt` when present, else the first 280 characters of the content. Newest first, at most 20, plus `evidenceTotal`.
  - `movedAt`: answers `last_moved_at`; others the newest evidence time.
- Route `GET /claims/:userId/:kind/:id` → `{ claim: ClaimView }` or 404 `{ error: 'not found' }` (also for retired, rejected, or another person's). UUID-validate `id` before any query.
- No model calls. Projection by name on every query (never `select('*')`: `raw_content.embedding` is 3,072 floats).

Steps: `factText` helper → per-kind readers → evidence joins → route → tests.

Acceptance:
- Each of the four kinds returns readable text, a register and its evidence for the owner, and 404 for anyone else.
- A retired or rejected claim is never returned.
- The fact text is the same string search and the portrait show for the same fact.

Tests (layer 1, layer 2 where SQL):
- `a fact returns its text, register and evidence newest first`
- `an inferred fact is in the asked register; an observed one is stated`
- `an answer's register matches readUnderstanding's for the same answer`
- `a pattern's evidence walks through its facts to the entries`
- `a retired fact and a rejected answer are not found`
- `another person's claim is not found and reads none of their evidence` (two users)
- `evidence dates use content_date when it exists`
- `factText reads raw, then normalized, then text`
- `no log line carries an excerpt or a claim's text`

Proof: test output; a local-staging call per kind on a seeded test account (counts and kinds only in the PR).

Watch out: `object_value` has three shapes across writers (§10.2); never assume one. `walkEvidence` follows `claim_edges` to depth 6: cap the walk at 20 sources and count the rest, or a well-supported pattern reads hundreds of rows.

---

### BE5.1a · People: ranked properly, and one person                     size: M
Place in the tree: you › one node or claim › people › engine and routes
Repo · branch: agent · `agent/BE5.1a-people`
Needs: BEA.2, BE5.0      Unblocks: BE5.1b, BE5.2a, BE5.5a, BE5.5c

Why: the people who matter most to you right now are the ones on your map, including the people you see and write to, not only the ones you write about.

Inputs:
- Contract: 05 §2 (people nodes), §3 (person node: headline, mentions, evidence, linked)
- Reference: agent-api-reference §9.3 (`significantPeople` takes 50 before sorting; `factsAbout` interpolation), §10.3 (`entities`)
- Code anchors: `src/brain/pulls.ts:289-310`, `:123-140`; `src/brain/people.ts` (`computeSignificance`, `refreshSignificance`, half-life 60 days); `src/brain/write-journal-facts.ts:186` (the only caller of `refreshSignificance`); `src/people/run-resolution.ts` (calendar and mail people)

Spec:
- `significantPeople`: order by `(attributes->>'significance')::numeric desc nulls last` in SQL, filter by the floor in SQL, then `limit`; `status = 'active'` only (merged people never appear). Keep the signature.
- Significance for everyone: a job `refreshAllSignificance(userId)` (paged, `selectAll`) that recomputes every active person entity for a user, run after each integration sync batch that touched people (the resolution runner) and nightly for users whose last refresh is older than 24 hours (behind the ambient switch: `users.ambient_enabled` false → skipped; the founder's master switch respected). Mentions from calendar attendees and mail count with intensity 0.5 (records weigh less than your own words; evidence_kinds `calendar 0.4`, `mail 0.6`, rounded to one constant `RECORD_MENTION_INTENSITY = 0.5`, written in the PR).
- `GET /people/:userId?limit=10` → `{ people: [{ id, name, significance, mentions, lastMentionedAt, isGuess }] }`; `isGuess` = the person has a pending resolution candidate (`entity_resolution_candidates.status = 'pending'`).
- `GET /people/:userId/:entityId` → `{ person: { id, name, mentions, significance, headline: ClaimView | null, evidence, evidenceTotal, linked: [{ kind, id, label }] , pendingQuestionId } }`:
  - headline: among live facts where the person is subject or object (`factsAbout`, UUID-validated, parameterised), the one with the most evidence rows, ties by newest; read through `readClaim`. None → `null` (never a made-up relationship).
  - evidence: the raw_content rows that mention the person (through those facts' evidence), newest first, ≤ 20.
  - linked: from BE5.5b's shared-evidence function once it lands; until then `[]` (the door's contract allows `[]`).
- Two-user and role tests; no model calls.

Steps: SQL ordering fix → refresh-all job + schedule → list route → person route → tests.

Acceptance:
- With 300 contacts and 5 close people, the 5 come first.
- A person seen only in calendars and mail gets a significance.
- A person with no live fact has `headline: null`.

Tests:
- `significant people are ranked before the limit is applied` (60 people, the most significant is #60 by id)
- `merged people never appear`
- `calendar and mail mentions count at half weight`
- `the nightly refresh skips people whose ambient is off`
- `a person's headline is the best-supported live fact about them`
- `a person with no facts has no headline`
- `another person's entity is not found` (two users)
- `a non-UUID entity id is refused before any query`

Proof: test output; local staging: counts of people with significance before and after the refresh job.

Watch out: `factsAbout` builds a PostgREST `.or()` string; BEA.2 parameterises it, and this byte must not add a new interpolation. The refresh job pages past PostgREST's 1,000-row cap (`selectAll`).

---

### BE5.1b · "Same person?" doors                                         size: S
Place in the tree: you › one node or claim › "same person?" › `GET /v2/you/questions`, `POST /v2/you/questions/:id`
Repo · branch: backend · `be/BE5.1b-you-questions`
Needs: BE0.1, BE0.2, BE0.12, BEA.2, BE5.1a      Unblocks: PL3.6c, P21.2

Why: when Retro isn't sure two names are the same person, it asks you once, and your answer sticks.

Inputs: contract 05 §5; agent `src/routes/people.ts` (`GET /people/:userId/held`, `POST /people/:userId/held/:id`), `src/people/run-resolution.ts:48-67` (`heldPairs`, `answerHeldPair`: throws on a repeat).

Spec:
- `GET /v2/you/questions` → agent `held` → map each pair to `{ id, kind: 'samePerson', inYourWriting, inYourContacts, writingRef?, contactRef? }`; drop the agent's English `question`; drop pairs where either name is null. Agent route extended in a small agent commit to return `leftEntityId`, `rightEntityId` (needed for the refs). ≤ 20, oldest first.
- `POST /v2/you/questions/:id { verdict: 'same'|'different' }` (zod strict): ownership via `entity_resolution_candidates.user_id`; read status first; `accepted` → `{ status: 'linked' }`, `rejected` → `{ status: 'keptApart' }` without calling the agent; else call the agent and map. Bucket `write`; agent timeout 10 s, retry none.
- After `linked`, invalidate the door's map cache for the user.

Tests (door suite, plus): `a pending pair is listed with names only` · `answering twice returns the stored status and calls the agent once` · `another person's question is not found` · `a verdict other than same or different is invalid_request` · `linking clears the cached map` · fixtures `questions.json`, `question.answer.*.json`.

Watch out: `answerHeldPair` merges entities; a wrong "same" is costly. The door never answers on the person's behalf, and no other code path calls it.

---

### BE5.2a · The portrait: every slot from live rows                      size: M
Place in the tree: you › at a glance › the portrait › engine and route
Repo · branch: agent · `agent/BE5.2a-portrait`
Needs: BE5.0 (`factText`), BE5.1a      Unblocks: BE5.2b

Why: a short, current picture of you (what you're working toward, what keeps coming up, who's around you, what changed), where every line traces back to something real, and empty beats stale.

Inputs: contract 05 §4; agent-api-reference §9.1; code `src/brain/portrait.ts:122-145` (`buildPortrait`), `:47-50` (`objectText` reads `.text`), `src/brain/pulls.ts:77-120` (`changedSince`), `src/understanding/answer-moves.ts`.

Spec:
- `objectText` → BE5.0's `factText` (one reader for the human text).
- `significant_people`: `significantPeople({ limit: 6 })` → lines = names, `sourceAssertionIds: []`, a new `sourceEntityIds` array on the block (additive; `patchDocument` ignores it).
- `what_changed`: `changedSince({ since: now − 14 days })`: `became_true` → `new: <factText>`, `retired` with `replacedBy` → `now: <new text>` ; plus answer moves with `isNew` → `new: <answer>`. Lowercase prefixes are data words agreed in this contract; ≤ 6, newest first; each with its id.
- `open_threads` stays empty (no source exists; written in the PR as known).
- Route `GET /portrait/:userId` → `{ portrait: PortraitDocument }` (with block ids so the door can attach refs). No model calls. The agent may memoise per user for 10 minutes in process.

Tests: `every populated line carries the id it came from` · `a slot with nothing live is empty, not stale` · `people lines come from the ranked people` · `what changed shows new and replaced facts from the last two weeks only` · `the portrait reads fact text the same way search does` · two-user test · `no log line carries a line's text`.

Watch out: `patchDocument` must keep `document.active_goals`' shape (its HARD CONSTRAINT comment): don't touch it.

---

### BE5.2b · Portrait door                                                 size: S
Place in the tree: you › at a glance › the portrait › `GET /v2/you/portrait`
Repo · branch: backend · `be/BE5.2b-portrait-door`
Needs: BE5.2a, BE0.1, BE0.2      Unblocks: PL3.6b, UI6.7

Spec: map slots to the contract's names (`current_goals → goals` …), drop unpopulated blocks into `empty`, attach `ref` per line (`sourceAssertionIds[i]` → `{ kind: 'fact' }`, `sourcePatternIds[i]` → `{ kind: 'theme' }`, `sourceEntityIds[i]` → `{ kind: 'person' }`); lines without an id are dropped and counted in the log (they should never exist). Cache per user 1 hour (in-process LRU, 1,000 users); bucket `read`; agent timeout 10 s, retry `read`.

Tests: door suite · `every line has a ref` · `an empty portrait lists all seven slots as empty` · fixtures `portrait.json`, `portrait.empty.json`.

---

### BE5.3a · What Retro knows, by area, in your words                     size: M
Place in the tree: you › what Retro knows › engine, route, second-person questions
Repo · branch: agent · `agent/BE5.3a-understanding`
Needs: BEA.2      Unblocks: BE5.3c, BE5.5a

Why: YO-5 lists what Retro has concluded about you, area by area, phrased to you, and says nothing about areas it hasn't earned the right to speak about.

Inputs: contract 05 §7; agent-api-reference §9.2, §10.4 (36 questions, 8 areas); code `src/understanding/read.ts:113-135`, `supabase/migrations/120_canonical_questions.sql:62-99`.

Spec:
- Migration `16a_question_you_text.sql`: `canonical_questions.you_text text` (nullable), filled for all 36 with second-person, lowercase wording ("what have you said you want?", "who do you talk about when something is hard?"). The PR body lists all 36 side by side for the founder's approval (founder question 8); the migration is additive and re-runnable (`UPDATE … WHERE id = …`).
- `readUnderstanding` adds `youText` to each `AnswerItem` (falls back to `text` only if null, logged as a count).
- Route `GET /understanding/:userId` → `{ understanding: UnderstandingContract }` minus `time` and `shifts` (not used by the app; smaller payload). No model calls.

Tests: `every canonical question has second-person wording` (a migration test) · `answers carry their second-person question` · `silent areas list no answers` · `rejected answers never appear` · two-user test · role test (`SET ROLE service_role` reads the views).

Watch out: `readUnderstanding` filters goals by `is_active`, said-vs-did by `status`: don't "fix" one side here (contract 04's job).

---

### BE5.3b · "Still true": confirming an answer or a fact                 size: M
Place in the tree: you › one node or claim › "still true" › engine and routes
Repo · branch: agent · `agent/BE5.3b-verdicts`
Needs: BEA.1, BEA.2, BE5.0      Unblocks: BE5.3c

Why: when Retro has something right, you can say so in one tap, and it becomes more sure.

Inputs: agent-api-reference §10.4 ("Gap: no agent route exposes `record_answer_verdict`"), §10.2 (`assertion_kind user_confirmed`; writes only through `write_fact`); migration `121_question_answers.sql:338-349`, `124_answers_respect_authorship.sql:177`.

Spec:
- Answers: `POST /understanding/:userId/answers/:id/verdict { verdict: 'confirmed' }` → `record_answer_verdict(user, answer, 'confirmed')` → `{ confirmed: true }`. A repeat returns the same (read `user_verdict` first). `rejected` is **not** accepted here: rejecting goes through corrections (contract 02 §6), which retires and records the rejection.
- Facts: migration `16b_confirm_fact.sql`: `confirm_fact(p_user uuid, p_assertion uuid) returns void`, `SECURITY DEFINER`, checks the row is the user's and active, sets `assertion_kind = 'user_confirmed'`, `updated_at = now()`, records `metadata.confirmed_at`; `REVOKE ALL … FROM PUBLIC, anon, authenticated; GRANT EXECUTE … TO service_role`. Route `POST /facts/:userId/:id/verdict { verdict: 'confirmed' }`.
- Both 404 for another person's or a retired claim. Neither calls a model.

Tests (layers 1 and 2): `confirming an answer records the verdict once` · `confirming a fact makes it user_confirmed` · `the service role can call confirm_fact` (under `SET ROLE service_role`; the BEA.1 lesson) · `confirming another person's claim changes nothing` · `a retired fact can't be confirmed` · `a confirmed answer reads as confirmed in readUnderstanding`.

Watch out: `write_fact` is the only writer of `assertions` by design; `confirm_fact` changes one column and must not bypass `claim_rejections`' triggers (test that a rejected key stays retired).

---

### BE5.3c · Doors: what Retro knows, one node or claim's verdict          size: M
Place in the tree: you › what Retro knows › `GET /v2/you/understanding`; one node › `POST /v2/you/claims/:kind/:id/verdict`
Repo · branch: backend · `be/BE5.3c-understanding-verdict`
Needs: BE5.3a, BE5.3b, BE1.6 (sureness constant), BE0.1, BE0.2      Unblocks: PL3.6c, PL3.6d

Spec:
- `GET /v2/you/understanding`: group answers by `domainId` into the 8 areas in question-store order (`in_the_way → inTheWay`); `question = youText`; `sureness` from BE1.6's constant; `dots` from one exported constant (`< 0.25, < 0.5, < 0.8`); `isGuess = register === 'asked'`; `sourceCount = sources`; `movedThisWeek` from `moves.items`; `moved = { since, answersChanged: moves.items.length }`. Silent areas → `{ silent: true, answers: [] }`. Cache 5 minutes; invalidated by a verdict or a correction for the user.
- `POST /v2/you/claims/:kind/:id/verdict { verdict: 'stillTrue' }`: `kind` ∈ `fact|answer` else `invalid_request`; `Idempotency-Key` required (BE0.0's store); ownership checked in the door first (`assertions.user_id` / `question_answers.user_id`), then the agent route. Bucket `write`, timeout 10 s, retry none (keyed).

Tests: door suite · `areas come in order with silent ones empty` · `dots and sureness follow the constants` · `a verdict is recorded once for ten retries with one key` · `a verdict on another person's claim is not found` · `a pattern or goal verdict is invalid_request` · fixtures `understanding*.json`, `verdict.*.json`.

---

### BE5.5a · The map: which nodes                                         size: M
Place in the tree: you › at a glance › the map › nodes
Repo · branch: agent · `agent/BE5.5a-map-nodes`
Needs: BE5.1a, BE5.3a      Unblocks: BE5.5b

Why: the map shows the people, themes and goals that matter in your life now, ranked by the brain, never decorated.

Inputs: contract 05 §2; founder questions 1 and 3 (leans: themes = live patterns; 10/8/6).

Spec:
- `src/brain/map.ts`: `readMapNodes(userId)`: people = `significantPeople({ minSignificance: 0.1, limit: 10 })` (`isGuess` from BE5.1a); themes = `livePatterns({ limit: 8 })` (weight = confidence, `isGuess = !episode_promotable`); goals = active goals (`is_active`), weight 1, ≤ 6, newest first; counts = totals before the caps. Quotas in one exported constant `MAP_QUOTAS`.
- `waiting`: oldest pending resolution pair, else the first offerable guess (`loadOfferable` + `chooseOffer`, only when the `speak` dial is on), else null.
- Route `GET /map/:userId` → `{ nodes, counts, waiting }` (edges added by BE5.5b). No model calls.

Tests: `the map never has more than the quotas` · `a kind with few nodes is not padded` · `waiting prefers a same-person question` · `with the speak dial off, no guess waits` · `a new account's map is empty` · two-user test.

Watch out: `livePatterns` may include non-promotable patterns only with `includeNonPromotable`; decide which in the PR with the founder's lean (themes include provisional ones, drawn dashed) and test it.

---

### BE5.5b · The map: lines between things                                size: M
Place in the tree: you › at a glance › the map › edges
Repo · branch: agent · `agent/BE5.5b-map-edges`
Needs: BE5.5a, BE5.0      Unblocks: BE5.5c, BE5.1a's `linked`

Why: a line on the map means two things in your life really share moments, counted from your own record.

Spec:
- `sharedEvidence(userId, nodes)`: for each node, its set of raw_content ids (person: evidence of facts about them; theme: `factsFor` → evidence; goal: `stated_goal` facts' evidence plus answers citing it); for each pair, the intersection size. Edge when ≥ 2, `strength = min(1, shared / 6)` (constants exported). Plus a `you` edge per node with `strength = weight`. ≤ 48 node edges, strongest first.
- One query per kind with `in` lists chunked by 300 (PGlite's simulated `MAX_IN_LIST`); no N² database calls (the intersection runs in memory over ≤ 24 sets).
- `linkedTo(userId, ref)` for BE5.1a / the node door: the same function for one node against the map's nodes, ≤ 8.

Tests: `two nodes sharing two entries are linked` · `one shared entry is not a line` · `strength caps at one` · `a map with 24 nodes makes at most four queries` · two-user test.

---

### BE5.5c · Doors: the map and one node                                  size: M
Place in the tree: you › at a glance › `GET /v2/you/map`; one node › `GET /v2/you/nodes/:kind/:id`
Repo · branch: backend · `be/BE5.5c-map-nodes-doors`
Needs: BE5.5b, BE5.1a, BE5.0, BE1.6, BE0.1, BE0.2      Unblocks: PL3.6b, PL3.6c

Spec:
- `GET /v2/you/map`: agent `GET /map/:userId`; map to `MapNode` (`ref.kind`: person/theme/goal), `sureness` via BE1.6's constant (people and goals "very sure"), edges, `waiting` (`aboutLabel` from the node's label, `about` when the pair's writing-side entity is on the map). Cache 5 minutes per user; invalidated by BE5.1b's link and BE5.3c's verdicts.
- `GET /v2/you/nodes/:kind/:id`: `kind` ∈ `person|theme|goal|fact|answer` (else `invalid_request`); UUID check; ownership by the agent's 404 **and** a door-side ownership read (`entities` / `behavior_patterns` / `goals` / `assertions` / `question_answers` `.user_id`). person → agent `GET /people/…/:id`; others → agent `GET /claims/…`; map `ClaimView` to `claim` (sureness, `isGuess = register === 'asked'`, `canConfirm` for fact/answer), evidence to `Evidence` (`via` from `content_type` with one exported table: `journal_entry, text_entry, manual_journal, note → journal`; `voice_journal, voice_recording → voice`; `conversation → conversation`; `calendar, google_calendar → calendar`; `gmail → mail`; `healthkit → health`; `google_docs → document`; `link, shared_link, reference → saved`; `youtube, spotify, apple_music → listening`; else `other`), dates to the user's local day; `question` from the person's pending pair; `kindLabel` per kind (fact/answer → "belief").
- Bucket `read`; agent timeout 10 s, retry `read`.

Tests: door suite · `a person with no fact has no claim and keeps its mentions` · `every content type maps to a via, unknown to other` · `evidence dates are the user's local day` · `another person's node is not found for every kind` · `the map is served from cache until a verdict` · fixtures `map*.json`, `node.*.json`.

---

### BE5.4a · Search: which sentences are sure, and what each source is   size: M
Place in the tree: you › search › engine (sentence sureness, source kinds, abstain codes)
Repo · branch: agent · `agent/BE5.4a-search-sureness`
Needs: BEA.2, BEA.4, BE5.0 (`factText`)      Unblocks: BE5.4b

Why: search writes what it found on top and marks anything less than certain as "a guess:", so "only what's certain" can hide it; every source says what it is and when it happened.

Inputs: contract 05 §6; agent-api-reference §5.1–§5.3; code `src/search/answer.ts:74-112`, `src/search/search.ts`, `src/search/source.ts:14-38`, migration `147_search_saved_by_meaning.sql` (`search_person`).

Spec:
- `searchAndAnswer` result gains, without changing what the writer is asked:
  - `sentences: [{ text, cites, sure }]` for the kept sentences (the `citations()` output, already computed at `:103`); `sure` by the deterministic rule in contract 05 §6 over each cited source's facts: item `trust_class` (`own_words`, `record` → certain; `third_party`, `automated`, null → not), fact `assertion_kind` (`observed`, `user_confirmed` → certain), answer register (via `readUnderstanding`'s rule for that answer), saved → certain. One exported function `sentenceSureness(cites, facts)`, pure, table-tested.
  - `abstainReason`: `nothing_found | not_answered | could_not_write | own_words_only` replacing the reliance on fixed English strings (the strings stay in `summary` for the old callers).
  - each source gains `contentType`, `trustClass` (items), `assertionKind` (facts), `register` (answers), and `date` from `coalesce(content_date, created_at)`.
- `trustOfItems` takes `userId` and filters by it (it doesn't today).
- Migration `16c_search_person_content_date.sql`: `search_person` returns `coalesce(content_date, created_at)` as `happened_at` for items (CREATE OR REPLACE, same signature; the replay test proves the function still compiles and ranks the same on the existing tests).
- `openSource`: item date from `content_date`; fact evidence lookup filtered by `user_id` (if BEA.2 hasn't already).
- Spend: the route records its usage through BEA.4's `recordSpend(userId, 'search', …)` (if BEA.4 didn't already wire search) and checks the cap first (`429 spend_limited`).

Tests: `a sentence citing only an unconfirmed answer is a guess` · `a sentence citing a journal entry is certain` · `a sentence citing only a newsletter is a guess` · `abstaining with no sources is nothing_found` · `all sentences cut is not_answered` · `item dates use content_date` · `trust labels only read the person's rows` (two users) · `a search over the cap is refused and records nothing` · `search costs are recorded` · `no log line carries the query or a sentence`.

Watch out: the writer prompt and guard are tuned (gate runs S1.3, R1.5); this byte must not change them. Check the existing search gate fixtures still pass unchanged.

---

### BE5.4b · Doors: search and opening a source                          size: M
Place in the tree: you › search › `POST /v2/you/search`, `GET /v2/you/sources/:kind/:id`
Repo · branch: backend · `be/BE5.4b-search-doors`
Needs: BE5.4a, BE0.1, BE0.2, BE0.0 (idempotency store), BEA.4      Unblocks: PL3.6e

Spec:
- `POST /v2/you/search`: zod `{ query: string trimmed 1–200, clientSearchId: uuid }`; `Idempotency-Key` required and equal to `clientSearchId`. A result for the same key within 10 minutes is returned from an in-process LRU (keyed by user and key, storing the mapped response and a hash of the query; a different query → `idempotency_mismatch`). The cache holds results in memory only, never written to disk or logs.
- Agent `POST /search/answer` (bucket `expensive`, timeout 30 s, retry none). Map: `outcome = abstained ? 'abstained' : 'found'`; `sentences` with `sure`; `guessCount`; `abstain = { reason, why? }` (`why` only for `own_words_only`, lowercased first letter); sources: `item` → `{ kind: 'entry' }` with `via` from `contentType` (BE5.5c's table), `fact`/`answer`/`saved` kept; `matches` computed in the door (query words of 3+ letters, NFD-folded, case-insensitive, UTF-16 offsets, all occurrences).
- `GET /v2/you/sources/:kind/:id` (`entry|saved`): agent `GET /search/:userId/source/item|saved/:id`; map `title` for records to the `via` word ("calendar", "mail"); for an entry whose `via` is journal/voice/conversation, return it anyway (the app should open JR-4, but the door doesn't refuse). Bucket `read`.
- Logs: door, user id, status, ms, `sources`, `sentences`, `guesses`, `outcome`. Never the query.

Tests: door suite · `a retried search with the same key costs once` · `the same key with another query is idempotency_mismatch` · `the query never appears in a log line or error` · `matches point at the query's words` · `an abstained search keeps its closest sources` · `over the spend cap the search is spend_limited and a read still works` · `another person's source is not found` · fixtures `search.*.json`, `source.*.json`, `error.spend_limited.json`.

Watch out: a search can take 5–10 s on the agent. The door's timeout is 30 s and the app shows "still working" after 8 s (C39.4); never retry automatically on the server side (it would pay twice).
