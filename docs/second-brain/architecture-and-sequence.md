# Architecture and sequence

**What to build, in what order, and why that order.** Written 18 October 2026,
after auditing the live system.

The other two documents answer different questions. [goal-specs.md](./goal-specs.md)
says what the product must do. [decision-loop.md](./decision-loop.md) says how a
decision becomes a PR. This one says how the system is actually put together, and
what has to be true before each piece can be built.

It exists because the goal tiers are **product** dependencies, and they are not the
same as **engineering** dependencies. Building in tier order would be wrong.

---

## 0. The problem, and what it demands of the engineering

> "Information is everywhere, but clarity, comprehension and action are nowhere.
> The world is suffering in an abundance of answers."

Taken seriously, that sentence invalidates the instinct this plan was built on.

Every system described in the phases below optimises for **knowing more** — more
sources, more questions answered, higher coverage. But if the pain is abundance
rather than scarcity, then **the product's value is subtraction.** A system that
knows ten thousand things about someone and says the three that matter is the
product. One that knows ten thousand and says four hundred is the disease, built
more efficiently.

This section exists because that distinction has to be enforced in code, not left
to tone.

### Three different failures, not one

Clarity, comprehension and action fail separately:

| Failure | What it feels like | Where it lives |
|---|---|---|
| **Clarity** | I have the facts and they do not cohere | the brief's through-line |
| **Comprehension** | They cohere but I cannot see what they mean for me | patterns, why, hypothesis |
| **Action** | I understand and still do not move | the user journey's question |

The plan below handles comprehension well and action deliberately late. **Clarity
it does not handle at all** — the daily brief is specified as "selection and
framing" with no account of how coherence is produced. That is the largest
unspecified thing in the product, and naming it is the start of fixing it.

### Five foundational commitments

These constrain every phase. They are not features and no goal asks for them.

**1. When uncertain, withhold.**

One rule, applied identically in every layer. Extraction already does it — no
quote, no fact. The rest of the system must too: a pattern below the bar is not
mentioned, a domain below coverage is silent, an item of unclear relevance is
dropped rather than included for the user to skim.

The temptation at every uncertainty is to pass the decision to the person. That is
precisely the disease — it is how an abundance of answers is manufactured. **Every
place the system could hedge instead of deciding is a place it must stay quiet.**

**2. Lineage is structural, not a feature.**

The spec requires that *"how do you know that"* always has a real answer. That is
only true if it is impossible to write a claim without its evidence.

So the chain — said → answer → evidence → fact → span → source row — must be
enforced by schema and by function signature, not by convention. A function that
can write an answer without evidence will eventually be called that way. This
constrains the question store before it is designed, which is why it is here and
not in phase 2.

**3. Reprocessing must be safe and complete.**

Phase 1 pushes 2,024 rows back through the pipeline. Everything derived from
them — facts, patterns, portrait, answers, coverage — has to recompute correctly,
and twice has to equal once.

Facts already have this through `origin_key`. Patterns, portrait and answers do
not. **Replayability is a property the derived layers need before the backlog is
drained**, or the drain produces duplicated patterns and a portrait that drifts.

**4. Layers meet at contracts, not at function calls.**

Three layers are only real if what passes between them is defined:

- **Capture → Interpretation:** a durable row, classified, with a terminal status.
  Interpretation never reads the network or decides retry policy.
- **Interpretation → Expression:** answers with confidence and evidence. Nothing
  else. Expression cannot reach past this into facts or raw content — if it can,
  it will, and the layers fuse again as they did in `runIngest`.

**5. Say less than you know, and measure the gap.**

Coverage rewards knowing. Nothing in this plan rewards restraint, which means
nothing resists the drift toward saying everything.

So a first-class metric: **of what the system knew this morning, what fraction did
it speak?** A healthy figure is small. A figure near one means the product has
become a feed.

Paired with its companion — of what it did say, how much was worth hearing — this
is the only pair that measures the actual problem. Coverage measures the input;
these measure whether the product solved anything.

---

## 1. The evidence this plan is built on

Measured against production on 18 October 2026, not recalled. Everything here
replaces the numbers quoted earlier in the conversation, several of which were
wrong.

### Content

| | |
|---|---|
| `raw_content` rows | **2,270** |
| ever completed | **221** — 9.7% |
| failed | **2,024** — 89% |
| pending right now | 25 |
| with an embedding | **12** — 0.5% |

### Why the 2,024 failed

| Cause | Rows | Verdict |
|---|---|---|
| `Too Many Requests` | 755 | transient — retryable |
| `credit balance is too low` | 700 | the May billing lapse — retryable |
| HTML error page where JSON expected | 197 | gateway error — retryable |
| `duplicate of an already-queued document` | 144 | **not a failure** |
| `contains no quotable statement` | 42 | **not a failure** |
| other | ~186 | mixed |

**1,652 of 2,024 (82%) are transient infrastructure failures that should succeed
on retry. 186 (9%) were never failures at all** — the pipeline reached the right
answer and recorded it as broken.

### And then the number that matters: it is 23 documents, not 2,024

Measured by running the existing `requeue-failed.ts` in dry-run against
production, after the classifier was corrected.

| | |
|---|---|
| failed rows, main user | 966 |
| classified retryable | 778 |
| **distinct documents after deduplication** | **23** |
| total content | 38,530 characters |
| cost to reprocess all of it | **~$0.46** |

**755 of those 778 rows are duplicates of each other.** A broken importer wrote
the same handful of documents hundreds of times — one of them 264 times in a
single day.

This changes the shape of the problem completely:

- **The drain is trivial.** Under a dollar, minutes of work. It was planned as a
  $25 decision requiring approval. It is not a decision; it is a chore.
- **Very little was actually lost.** The story "2,000 entries died" is true about
  rows and false about content. Twenty-three documents is a bad afternoon, not a
  lost year.
- **Deduplication is a correctness requirement, not an economy.** The promoter
  decides what is a pattern by counting recurrence. Requeuing 264 copies of one
  Tuesday would let a sync bug present itself as a person's defining habit. This
  is the single most dangerous thing in the backlog, and it is not the money.
- **The real failure was never the billing lapse.** It was that a duplicate
  importer ran unchecked and nothing noticed, which is an observability problem —
  the same one phase 0 exists to fix.

By content type: `google_docs` 1,211, `healthkit` 738, `text_entry` 52,
**`journal_entry` 0.** The journal path works. The bulk-import paths broke.

### The retry machinery was never connected to any of it

`attempt_count = 0`, `next_attempt_at = NULL`, and `failure_kind = NULL` for all
2,024 rows. `src/pipelines/retry-policy.ts` exists, is pure, is tested, and
classifies every one of these causes correctly. Nothing ever ran it over the
backlog. The rows are not waiting for a retry — they are invisible to the thing
that would retry them.

### The bank

| | |
|---|---|
| `assertions` | 19 |
| `assertion_evidence` | 19 |
| `assertion_relations` | **0** — supersession has never fired |
| `entities` | 2 |
| `behavior_patterns` | 16, **all `candidate`, 0 live** |
| `behavior_pattern_whys` | 0 |
| `lint_findings` | 0 — 26 checks written, never run |
| `pipeline_run_traces` | 305, of which **190 failed (62%)** |

### Corrections to what I told you earlier

1. **`graph_edges` has 1,091 rows.** I called it dead and replaced. Its
   replacement, `assertion_relations`, has 0. The old graph holds everything; the
   new one holds nothing.
2. **`behavior_pattern_facts` has 19 rows**, not zero.
3. **`identity_inferences` has 326 rows.**
4. `insight_units` (8), `pipeline_runs` (39), `data_sources` (6), `categories`
   (15) all have rows. I described them as dead or empty.
5. The failed count is **2,024**, not 2,034.

### What this overturns

The [goal 3 brief](./brief-goal-03-making-meaning.md) says its own most important
unmeasured claim is that the narrow predicate vocabulary is the main cause of the
thin bank.

**That claim is wrong.** 19 assertions came from **221** processed rows, not from
2,270. The dominant loss is upstream of extraction entirely: 89% of everything
written never reached the extractor. Widening the vocabulary before draining the
backlog would be tuning a carburettor on a car with no fuel line.

---

## 2. The spine

Every one of the 25 goals reduces to one loop:

```
sources → grounded facts → answers to the canonical questions → what to say → said
```

And the load-bearing piece is the third one. **The canonical question store is the
central data structure of this product**, because the spec already routes almost
everything through it:

- whether the product may speak at all — the coverage threshold, per domain
- what a source is worth — exactly the questions it answers
- when hypothesis is allowed — critical mass, measured as coverage
- what the test bank asserts — the questions are the expectations
- what the "how well we know you" meter shows — coverage, rendered for the user
- whether a link belongs in a brief — does it bear on a question or goal

Nothing in the codebase has this today. It is the foundational gap, and it is not
any one goal — goals 6, 8, 10, 21, 22, 23 and 24 all assume it exists.

**Design consequence:** facts, patterns and hypotheses are not the product's
output. They are *evidence for an answer*. The question store is what the
expression layer reads, and it is the only thing it reads.

---

## 3. Three layers, separated by how often they change

| Layer | Job | Change rate | Today |
|---|---|---|---|
| **Capture** | get it in, durably, exactly once | rarely | broken — 62% of runs fail |
| **Interpretation** | turn it into grounded answers | constantly | narrow, and entangled |
| **Expression** | decide what to say and say it well | constantly, for unrelated reasons | a 14-day dump |

Interpretation churns because the vocabulary, the domains, the frameworks and the
models will all change repeatedly. Expression churns because tone, length and
modality will. Capture should barely change once correct.

**All three currently live in `runIngest` — one function, 932 lines.** That is the
reason interpretation cannot be iterated safely: every change to what we *think*
risks what we *keep*.

**So the first structural move is a seam, not a feature.** Capture ends when a row
is durably stored and classified. Interpretation starts there and writes answers.
Expression reads answers and nothing else.

---

## 4. The ordering principle

**Order by what unblocks measurement — not by goal tier.**

The decision loop's validation gate requires a number that was declared before the
work. Almost nothing in this system is currently measurable: the drop rate is
computed and discarded, the cost meter was wrong three ways, coverage does not
exist, and failures were unclassified. **The process cannot run until the system
is legible.** That is why instrumentation comes before features, even though no
goal asks for it.

Second principle: **never evaluate a layer on broken input.** Judging
interpretation quality on 9.7% of the data tells you nothing, and would have
sent us to rewrite the extractor when the real fault was a billing lapse in May.

---

## 5. The phases

Each phase has a gate that can fail, and the gate is a number.

### Phase 0 — make the system legible

Nothing downstream can be evaluated until these exist.

| | Work | State |
|---|---|---|
| 0.1 | Cost meter priced per model | **PR [#18](https://github.com/hankHillsleftnut/Retrospect-agent/pull/18)** |
| 0.2 | Failure classification + `not_applicable` | **PR #18** |
| 0.3 | Persist the drop rate with its reasons | **PR #18** |
| 0.4 | Question coverage computed per domain | after 2.1 |
| 0.5 | One health report answering "is this working" in one call | **done** — `npm run health`, queued for #18 |
| 0.6 | The withholding ratio — knew versus said (commitment 5) | after 5.1 |
| 0.7 | **Schema as code.** One migration directory, one apply command, production checked against it. See 6a | — |

**Gate:** a single command prints content state, failure breakdown, bank counts,
drop rate and cost per run. Today that takes me writing SQL by hand.

### Phase 1 — make the pipe reliable

You cannot evaluate interpretation on 9.7% of the data.

**Correction, 18 October 2026.** An earlier draft of this section said facts were
idempotent but "patterns, portrait and answers are not," and made replay safety
the first job of the phase. **Checking the code rather than asserting it, that was
wrong on every count:**

- `behavior_patterns` has `UNIQUE (user_id, grouping_key)` and the promoter
  **upserts** on it.
- `behavior_pattern_facts` is keyed `(pattern_id, assertion_id)` and upserts too.
- `behavior_pattern_whys` has no constraint, but the promoter guards it with a
  read-then-write — it only inserts when no live why exists.
- And above all of it, `hasExistingFacts` skips any row that already produced
  facts, marking it complete without reprocessing. **That one guard protects
  everything downstream**: no duplicate observations, insights or inferences,
  because the row never reaches them.

So the system is already replay-safe, and the work this phase needed is far
smaller than planned. What remains is one latent race: the why guard reads then
writes, so two concurrent promoter runs could both see zero and both insert. The
promoter runs serially after ingest today, so this is a latent defect rather than
a live one.

| | Work |
|---|---|
| 1.1 | **Idempotency on `POST /content`** — **done**, NPRdoinglaundry#7 + migration 117 |
| 1.2 | Close the why-insert race — **done**, migration 118, keyed on pattern + mechanism so competing explanations stay possible |
| 1.3 | Drain the backlog — 23 documents, ~$0.46, via the existing `requeue-failed.ts` *(waiting on approval: it writes)* |
| 1.4 | Backfill embeddings — 0.5% coverage *(waiting on approval: it writes and spends)* |
| 1.5 | The 62% failure rate — **resolved**. 80% was the June OpenAI billing lapse; zero failures since 1 Aug. The live residue was two legacy-table bugs, fixed: goal ids now checked, legacy writes can no longer fail a run |

**Gate:** completed share above 90%, embedding coverage above 90%, trace failure
rate under 10%, and submitting the same content twice produces one row.

**The lesson, recorded because it keeps happening.** Three claims in this document
were asserted from reasoning and were wrong when checked: that patterns were not
idempotent, that `graph_edges` was dead, and that the backlog was 2,024 lost
entries. The code and the data were available the whole time. This is step 0 of
the decision loop, and it is not optional.

### Phase 2 — the question store

The spine. Built only once the data it would summarise is actually present.

| | Work |
|---|---|
| 2.1 | Schema: question, current answer, confidence, evidence links, last moved — **with lineage enforced structurally per commitment 2**, so an answer cannot be written without its evidence |
| 2.2 | Derive answers from the existing bank — facts, patterns, portrait |
| 2.3 | Coverage and accuracy computed per domain, reported separately and never merged |
| 2.4 | The 36 questions as data, editable without a deploy |
| 2.5 | Answer derivation idempotent, per commitment 3 |

**Gate:** coverage reported per domain for a real user; every answer traceable all
the way to a source span; no answer without a confidence; **and the write path
makes an unevidenced answer impossible rather than merely discouraged.**

### Phase 3 — widen interpretation

Now the goal 3 brief is testable, because the denominator is real.

| | Work |
|---|---|
| 3.0 | **Decompose `runIngest` first.** Adding domains to a 932-line function makes it 1,100 — **done**, 1,064 → 554 lines, Retrospect-agent #36–#39 (claim-work, legacy-writes, after-reading, batch-outputs) |
| 3.1 | Domain field and the widened vocabulary |
| 3.2 | Segment long entries instead of truncating at 16,000 characters |
| 3.3 | Remove the `goal_candidates` instruction — free, and in the prompt we are already editing |
| 3.4 | Then, separately, try a current model |

**Gate:** recall against the test bank up without false positives up, and drop
rate falling. Measured before and after, on the same rows.

### Phase 4 — one source, end to end

| | Work |
|---|---|
| 4.1 | Google Calendar, complete: OAuth, sync, normalise, facts, answers moved |
| 4.2 | Gmail metadata |
| 4.3 | Gmail sent bodies — the expensive third of the question list |
| 4.4 | Drive and Docs |

**Gate per connector:** named questions move from unanswered to answered. A
connector that moves nothing gets reverted, not kept.

### Phase 5 — expression

| | Work |
|---|---|
| 5.1 | Relevance scoring against goals, stored with its reason |
| 5.2 | **The coherence layer** — the through-line. See the note below; this is the least specified part of the product |
| 5.3 | The daily brief, reading the question store and nothing behind it |
| 5.4 | The weekly episode: careful claims, captivating prose, separate prompt |
| 5.5 | `guardTranscript` wired — it has zero callers today |

**Gate:** an episode you listen to, plus the intermediate dump, per step 7 of the
loop. And the withholding ratio reported: what was known, what was said.

**On 5.2, honestly.** Selection decides *what* is worth saying; coherence decides
*why these things together*. A brief that is five accurate unrelated items is the
abundance problem with better sourcing. This is the clarity failure from section
0, it is the hardest unsolved thing here, and it does not have a design yet. It
gets its own decision brief when phase 5 starts rather than being folded into the
brief's prompt and hoped for.

---

## 6. Non-destructive migration

The requirement is that old code stays until it can be disconnected deliberately.
The pattern that achieves it, in order:

1. **Write both.** New path writes alongside the old one. Nothing is removed.
2. **Switch readers one at a time.** Each reader moving to the new source is its
   own small PR, independently revertible.
3. **Watch for a quiet period.** The old writer still runs; nothing reads it.
4. **Remove the writer last**, only when no reader depends on it.

Applied concretely: `observations`, `insights` and `identity_inferences` keep
being written while the question store fills. The brief reads the question store.
Only when the brief is good do we stop writing the old tables.

**And nothing destructive before then.** The nine droppable tables in the
generations document stay. `graph_edges` especially — it has 1,091 rows and its
replacement has none, so it is the opposite of safe to drop.

---

## 6a. Shipped, and what shipping it found

**18 October 2026.** Two PRs, eight commits:
[Retrospect-agent#18](https://github.com/hankHillsleftnut/Retrospect-agent/pull/18) and
[NPRdoinglaundry#7](https://github.com/hankHillsleftnut/NPRdoinglaundry/pull/7).

Three findings came out of the work itself rather than the plan, and each
changes how this project should be run.

### The backlog's real root cause was one line in the API

When agent ingestion failed, `POST /content` wrote a bare `failed` over the
agent's own retry scheduling — no attempt count, no retry time, no failure kind.
That is the exact signature of all 2,024 stranded rows. The retry system existed,
was tested, and worked; this line hid every failure from it.

It was also wrong on success: it stamped `completed` regardless of what the agent
had done, so a row the agent skipped was marked finished and never processed.

**Fixed by making the agent the only writer of a row's status after upload.** The
handoff now goes through a function that is never given a database client, so it
cannot write status at all.

**The general lesson:** two writers of one field, in two repositories, with no
contract between them. Expect this pattern elsewhere in the codebase. It is worth
auditing for directly rather than waiting to trip over it.

### Migrations are applied by hand, and production has drifted

- `retrospect-main` has not had a migration since `003`. The agent repo holds
  every schema change since, including eight that alter `raw_content`.
- Neither repo has a Supabase project config, and the agent has no migrate
  script. `ALL_second_brain_migrations.sql` looks pasted into the SQL editor.
- **Migration 115 (`content_authorship`) is applied in production but sits in an
  unmerged PR (#16).** The live schema is ahead of `main`.
- This produced a real collision: new work was numbered 115 too, and had to be
  renumbered to 116 and 117 before pushing.

**A reliable product needs one source of truth for its schema.** Added to Phase 0
below as a prerequisite, not a nice-to-have — every migration in this plan is at
risk until it is fixed.

### The backend's tests had never run

Jest was installed with no TypeScript support and could not parse a test file.
CI stayed green through `--passWithNoTests` and the absence of any tests. The
backend now uses `node:test` via `tsx`, matching the agent repo, and CI
typechecks the tests too.

---

## 6b. Retiring the old model

**Founder's direction, 18 October 2026:** observations, insights and identity
inferences are not the right approach, and should be treated as being replaced
rather than extended.

This confirms the existing plan rather than changing it — but it raises the
priority of finishing the replacement. The evidence from one day's work:

| Problem | Evidence |
|---|---|
| Not grounded in anything you said | Row-level links at best, never a quote |
| How false claims reach the portrait | The zero-sleep sentences came from identity inferences |
| Never wrong | 326 identity inferences, **0 ever retired or superseded** |
| The model writes its own references | 23 broken goal-id references; the `"uuid-or-null"` placeholder leak |
| Not measurable | No growing confidence; no answer to "how do you know that" |
| Unbuildable | 3 of the 4 impossible ivfflat indexes are on these tables |

**What replaces them:** grounded facts → patterns that need repetition →
question-store answers carrying evidence and confidence (Phase 2, Option A).

### Who still reads them — the order of retirement

| Reader | Reads | Why it matters |
|---|---|---|
| `pipelines/podcast.ts` | observations, insights | **the episode itself** |
| `agents/cook0-agent.ts` | observations, identity inferences | **rewrites the portrait** |
| `agents/tools/search-insights.ts` | observations, insights | Cook B's search |
| `jobs/weekly-podcast.ts` | insights | weekly trigger |
| `routes/notifications.ts`, `routes/runs.ts` | all three | display, not reasoning |
| `pipelines/integration-evidence.ts` | all four, incl. goal_candidates | never yet run |

Correction to earlier docs: `goal_candidates` is not read by *nothing*. Only
`integration-evidence.ts` reads it, and that code has never executed.

### The non-destructive path

1. Build the question store (Phase 2).
2. Switch readers **one PR at a time**, most important first — podcast, then
   Cook 0. Each switch is independently revertible.
3. Once nothing reasons from them, stop writing them. The legacy writes are
   already best-effort, so stopping them cannot fail a run.
4. Leave the tables standing until a quiet period confirms nothing reads them.
   Drop last.

The zero-sleep cleanup is the first step of this, not a one-off fix: retiring the
identity inferences built on unmeasured data.

---

## 7. Fix before extending

Two places where adding a feature first would make the codebase worse:

**`runIngest`, 932 lines.** It claims leases, fetches context, batches, calls the
model, writes facts, writes four legacy tables, embeds, runs Cook 0, runs the
promoter, patches the portrait, and handles its own failure. Phase 3 adds domains
and segmentation to it. Decompose along the capture/interpretation seam first.

**`POST /content` has no idempotency key.** Every duplicate in the system traces
here, and Phase 1 is about to push 2,024 rows back through the pipeline. Fix the
door before the crowd.

---

## 8. Deliberately not doing yet

Stated so it is a decision rather than an omission:

- **Efficiency and scale.** Explicit founder instruction: great output first,
  efficient code later. Written down so the shortcuts are visible when the time
  comes.
- **Goal 17, acting on the world.** Last. Keeps every credential read-only for
  the whole plan.
- **On-device and privacy architecture.** Deferred. Disclosure is not.
- **Tier C links** — TikTok, anything behind auth. Separate project.
- **The control panel.** After the product, because the dials have to be
  discovered first.

---

## 9. What a reviewer should be able to check

Every PR in this plan should answer all five:

1. Which goal, and which phase step?
2. What number moved, measured before and after?
3. What did it not break — full suite, and the typecheck?
4. What is the user-facing trade-off, if there is one?
5. What is still written to the old path, and what now reads the new one?
