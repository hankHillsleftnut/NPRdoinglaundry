# Brief — Goal 3, making meaning from data

**Status, 18 October 2026: this is now the Phase 3 brief.** Phase 2 passed its
gate today (28 of 36 questions answered for the founder, every answer
evidenced; 2 of 8 domains confident enough to speak). Task 1 below is done
(migration 116, live). **The addendum at the end has a finding that changes the
order of work, and two decisions for you.**

*Original status: draft for your decision. The gate has not been run, because the test
bank does not exist yet.* Every "gate result" below says what it would take to
answer. That is deliberate — a brief with confident numbers I have not measured
is the failure mode this process exists to prevent.

Format defined in [decision-loop.md](./decision-loop.md).

---

## The requirement

When you write something, the true parts of it should end up in the bank, filed
somewhere it can be found later. Nothing invented. Nothing silently dropped.

## What a user cannot do today

Write about anything other than their personal habits and have it remembered.

Two separate leaks cause this, and they are usually discussed as one:

**The vocabulary leak.** The extractor is nudged toward ten categories, all about
a person's life — goals, feelings, people, things they skipped. A founder writing
about what they are building has no category to land in, so it is dropped. The
documented case is 21 September: five paragraphs in, three facts out. The two
losses were a thought about who the product is for, and a reflection on an old
fear. Both plainly written. Neither ambiguous.

**The length leak.** A journal entry is read up to 16,000 characters. About 2,500
words. Past that the model never sees it. Long dumps — exactly the entries with
the most in them — lose their tail silently.

## Metric declared before the survey

Two numbers, both measured on the test bank:

1. **Recall against expectations** — of the facts the bank says should come out of
   an entry, what fraction do.
2. **False-positive rate** — facts produced that the bank says should not exist.

A method wins by raising (1) without raising (2). Raising both is not a win; it is
a model that has started guessing.

A third number gets recorded but is not a target: **drop rate with reasons.** It
is not currently persisted anywhere, which is why none of this can be answered
today.

---

## Options

### Option A — widen the filing cabinet

**What it is:** keep the truth rule exactly as it is, but give the extractor many
more categories to file into, each with its own downstream treatment. Your own
design, already written up as doc 16 in the agent repo.

**What the user notices:** things you write about work, ideas, and things you have
read stop vanishing. The bank starts holding your thinking, not just your habits.
Search starts returning what you meant.

**What it costs:** one migration, one prompt change. No new dependency, no extra
model call, no added latency.

**How it fails:** more gets banked than gets analysed. The product could start
feeling like it *remembers* more while *understanding* the same amount — because a
work thesis is deliberately banked without being promoted to a pattern about you.
If that gap is not explained in the interface, it reads as the system being
shallow.

**What it forecloses:** very little. Categories are additive, and the design
separates "captured" from "analysed" on purpose.

**Gate result:** no external code required — this is our own design, so questions
1 and 2 are trivially satisfied. Question 3 is unanswered and needs the bank.
**The single most important unmeasured claim in this brief is that the vocabulary
is the main cause of the loss.** It rests on one incident.

---

### Option B — segment long entries instead of truncating them

**What it is:** split a long entry into passages, extract from each, keep every
passage pointed back at the original row. The span rule is unaffected — offsets
still resolve to the real source.

**What the user notices:** long entries stop losing their endings. The thing you
wrote at the bottom of a 4,000-word dump, often the most honest part, survives.

**What it costs:** more model calls per long entry, so ingest gets slower and
dearer on exactly your heaviest writing days.

**How it fails:** a fact that only makes sense across two passages gets missed by
both. Segmenting trades a guaranteed loss at the tail for a subtler loss at the
seams.

**What it forecloses:** nothing. It makes later work easier.

**Gate result:** the table for this **already exists and has never been used** —
`analysis_units`, built in the integrations generation. It currently can only
reference integration items; pointing it at `raw_content` is reportedly one
foreign key. Google's LangExtract is the published implementation of the same
contract and is the thing to measure against, not install. Needs the bank.

---

### Option C — a stronger extraction model

**What it is:** the extractor currently runs on GPT-4o. Swap it for a current
model.

**What the user notices:** subtler things get caught — what you implied rather
than stated.

**What it costs:** more per run. One environment variable to change.

**How it fails:** this is the counter-intuitive one. A stronger model is better at
*inferring*, and inference is precisely what you do not want at the fact layer. It
will propose more claims that are true-ish but not actually said. The span rule
catches them, so the drop rate may go **up** while quality also goes up. Two
things moving at once, in opposite directions, with one counter.

**What it forecloses:** nothing.

**Gate result:** trivial to run. **Recommend running it second, not first**, so
the signal stays readable.

---

### Option D — extract, then have a second pass critique it

**What it is:** a critic model reviews the first pass and removes what it cannot
support.

**What the user notices:** possibly fewer wrong facts. Probably fewer facts.

**What it costs:** doubles the model calls on every ingest.

**How it fails:** the critic shares the extractor's blind spots. It cannot see
what the first pass never considered, which is the actual failure here.

**Gate result: rejected, and I want the reason on the record.** This is the
Chain-of-Verification recommendation I made earlier in this project and had to
withdraw. Self-consistency does not catch confident errors and never checks a
source. The span rule already does the job this would pretend to do.

---

### Option E — do nothing

**What it is:** leave extraction alone and move to another goal.

**What the user notices:** nothing changes. Roughly half of what a founder writes
keeps falling on the floor.

**Why it is named:** because it is the honest baseline, and because every goal
downstream of this one inherits the loss. Patterns built on a bank missing your
work life will be patterns about your gym habits.

---

## Recommendation

**A and B together, then measure, then C.**

They fix two different leaks and neither is a research bet — A is your own written
design, B is a table you already built and never switched on. Together they are
the cheapest large change available in the product right now.

The trade-off you are accepting: a bank that holds noticeably more and explains
only slightly more, until patterns catch up. The product will feel like it
remembers you before it feels like it understands you.

C after, alone, so you can tell what it did.

D stays rejected with the reason recorded.

---

## If you pick this, it splits into

1. **Persist the drop rate.** It is computed on every run and thrown away. Without
   it nothing here can be measured. One commit, no behaviour change.
2. **Build the test bank.** Twenty entries with expectations, per the format in the
   loop doc. Yours to write; I can scaffold it.
3. **Add the domain field.** Migration plus type changes. No extractor change yet.
4. **Widen the prompt** to the new categories, with the analysis routes wired.
5. **Point `analysis_units` at `raw_content`.** The foreign key, nothing else.
6. **Extract per passage** for long entries, and remove the truncation.
7. **Stop writing `goal_candidates`.** Unrelated to this brief, free, and it is in
   the same prompt we are already editing.

Tasks 1 and 2 come before everything. They are what make the rest a measurement
rather than a hope.


---

## Addendum, 18 October 2026 — the bank is almost empty

Measured against production today, for the founder's account:

| | Count |
|---|---|
| Rows of your own writing (journal, voice, text, onboarding, docs) | ~1,460 |
| Facts extracted from all of it | **4**, all from one day (21 Sep) |
| Rows marked `failed` | 1,282 — mostly re-synced copies of 4 Google Docs; ~23 distinct documents (Phase 1.3) |
| Rows marked `completed` | 164 — processed by the *old* model before facts existed, so never turned into facts |

**What this means.** The question store's first pass worked well (28 of 36
answered) because it reads your writing *directly*. The fact layer underneath —
the thing patterns, the researcher's "what's new", and lint all build on — holds
almost nothing. Widening the extractor (this brief) improves a pipe that has
barely run.

**So the order changes:** the test bank first (unchanged), then the extractor
fixes, then **re-extract your history once** with the improved extractor. Doing
the re-extraction before the fixes would spend money producing facts in the
narrow vocabulary that this brief exists to replace.

### Decision 1 — re-extract history once, after the fixes

**Corrected the same day:** counted properly, the ~1,460 rows are **66 distinct
pieces** (~189,000 characters). 76% is work documents — 45% is the Retrospect
"Design Doc" alone — and ~22% is personal writing (29 text entries, 11 voice
notes, 2 journal entries, onboarding). Re-extracting all of it is estimated
**well under $1**, so it falls within the standing approval. **Decided:** run it
once, after the extractor fixes.

The composition sharpens the recommendation: three-quarters of the writing is
about what the founder is building, which the current ten-category vocabulary
has nowhere to file. Option A matters most for this user.

### Decision 2 — where the test bank lives

The test bank is 20 of *your real entries*, each with the facts that should
come out of it. That is your private writing.

- **Recommended: a local, git-ignored folder.** Never committed, never leaves
  your Mac except when a test run sends one entry to the model — as ingestion
  already does. Only you and I can run it.
- In the (private) repo: shareable with a future engineer, but your journal
  would then live in git history permanently.

**I can draft it** — pick 20 entries spanning work, feelings, people, health and
long documents, and write the facts I think should come out of each. You then
correct my expectations, which is the only part that has to be you: the bank
is only as good as its claim to know what *should* come out.

---

## Baseline, measured 18 October 2026

Today's extractor (gpt-4o, the ten-category prompt) against the draft test bank —
20 of the founder's entries, expectations not yet corrected by the founder:

| | |
|---|---|
| **Recall** | **26 of 49 expected facts = 53%** |
| **False positives** | **9** — 7 from someone else's documents (Farza, Ladder), 2 judged on the founder's own writing |
| Quotes that don't exist in the source | 5 of 68 (dropped by the span check, as designed) |

Where it fails, in order of size:

1. **Long writing.** The May 29 essay: **3 of 11** facts, though it is 11,136
   characters — under the 16,000 cap. Not truncation: the extractor simply
   stops early on long, multi-topic writing.
2. **Someone else's words.** 7 false claims about the founder from Farza's
   post and Ladder's brief. PR #16 (authorship labels in the prompt) targets
   exactly this and is not yet merged — the next measurement shows whether it
   works.
3. **Opinion writing.** The March essay review: **0 of 3** — the extractor has
   no category for "what I believe".
4. **Feelings in rough speech.** The angry voice note: 1 of 4.

What it already does well: the onboarding answers (5/6), short entries (100%),
and nothing at all from gibberish or import errors.

**The 2 false positives on the founder's own writing are possibly the judge
being strict** ("making a product for SF tech bros" judged as "is an SF tech
bro"). The founder's corrections to the bank settle this.

Cost of the run: $0.42 (one extractor call and one judge call per entry).
Re-runnable with `npm run bank:score`.

### What this changes about the recommendation

The extractor still asks for the *old* model first — identity inferences,
observations, insights, goal candidates — and fact candidates are one section
among five. **Recommendation added: make the extractor facts-only** (Option F),
with the legacy outputs dropped from the prompt once nothing reads them
(architecture §6b). It is likely the cheapest single recall gain — a model
asked for one thing does it better than a model asked for five — and it
measurably retires the old framework rather than working around it.

---

## Re-check, 18 October 2026 — the vocabulary leak is mostly closed

This brief assumed the narrow ten-category vocabulary was the main cause of lost
facts. Facts-only reading on Sonnet 5.5 (decided above) changed that. Across its
two test-bank runs it misses **4 and 7 of 49** expected facts:

| Entry | Missed | Cause |
|---|---|---|
| Design presentation script (Google Doc) | "leads the brand and one hero feature", "wants to stop having to explain design", "first and only designer" | **Authorship unknown** — the doc isn't known to be yours, so claims about you are held back on purpose. Fixed by you telling me which Google Docs you wrote. |
| May 31 note (many names) | "shared the idea with Ayush, Rameez and Khaled" | People listed in passing |
| May 31 long dump | 2 facts (meeting Evis Drenova; posting on video platforms) | Long, multi-topic; varies run to run |
| Apr 19 voice note | "going through a metamorphosis" | Missed in one run only |

None are misses for lack of a category: work, beliefs and opinion writing now
come through (the March essay went from 0 of 3 to found).

**What this changes.** Step 3–4 (domain field, widened prompt) are no longer a
recall fix. Their remaining value is *filing*: routing each fact to the
question-store domain it informs. That is worth doing only once the question
store reads facts directly rather than raw writing — which it does not yet.
**Recommendation: defer 3.1 until then.** The biggest remaining recall gain is
free: tell me which Google Docs you wrote.

Cost of this check: $0 (re-read of saved results).
