# Brief — Phase 2, the question store

**Decided 18 October 2026: Option A, as amended below.** Step 4 of the
[decision loop](./decision-loop.md).

## The decision, in your words and mine

You said: once onboarding and integrations are in, make a best guess at all 36;
then keep researching the data ambiently, reflecting on it and growing confidence
as evidence builds. That is Option A's store with two additions:

1. **A first pass at every question**, right after onboarding and integrations
   connect. Thin evidence is allowed; it just means low confidence, and a
   low-confidence answer is held quietly, never said aloud.
2. **An ambient researcher.** A recurring job that re-reads the person's data
   question by question, looking for stronger or contradicting evidence, and
   moves confidence up or down. It spends most effort on the questions that are
   weakest and matter most.

**One line held from A:** every guess must point to *something* it rests on, even
an onboarding answer. A question with genuinely nothing behind it records "no
basis yet" rather than an invented guess. That keeps "how do you know that?"
always answerable.

---

*The original brief follows, unchanged.*
Everything in this brief was surveyed at high effort and then **checked against
the code and production** before being written here. Where a claim was checked,
it says so.

---

## The requirement

The product needs a place where its current best answer to each of the
[36 canonical questions](./canonical-questions.md) lives — what you want, what you
avoid, who matters, how you're doing — each with a confidence that grows as
evidence accumulates, and each traceable to the exact words or records it came
from.

It's the spine. Whether the product may speak about a part of your life, what a
data source is worth, when it's allowed to wonder aloud, and what the "how well do
we know you" meter shows — all of it reads from here. Nothing in the codebase
does this today.

## What the product can't do today

Answer the questions honestly. Measured against your account:

| | Questions |
|---|---|
| Answered with real evidence behind them | **2 of 36** |
| Confident enough to speak about | **0 of 36** |
| If your existing writing were processed | roughly 10–14 (estimate) |
| Answered by the current portrait, with **no** evidence at all | 20 or more |

That last row is the problem in one line. The portrait the podcast reads answers
twenty-odd questions about you, fluently, with nothing behind them — and some of
what it says is false.

### The finding that matters more than the schema

Checked against production on 18 October 2026: **746 of your 749 daily health
summaries say you slept 0.0 hours**, beside real step counts and heart rates.
Nothing was measuring your sleep. The portrait turned that into eight sentences,
including:

> *"Has an explicit fitness and health goal but is logging repeated zero-sleep
> nights … the gap between intention and behavior has"*

That is the product judging your follow-through, about your health, from a sync
bug. A guard now stops new claims like it (committed, waiting to push). **The
existing ones are still in your portrait** — see "Also needs your decision" below.

The general lesson shapes every option: **the store has to count independent
sources, not rows, and has to tell "missing" from "zero."** Otherwise duplicates
and defects turn straight into confidence. About 90% of the database is copies,
so this is not hypothetical.

---

## Metric declared before choosing

1. **Lineage is impossible to skip**, not merely discouraged. Tested by trying to
   write an answer with no evidence and confirming the database refuses.
2. **Coverage is honest.** The store reports 2 of 36 for you today, not 20.
3. **Replay is stable.** Processing the same evidence twice changes nothing.

---

## Options

### A — An answers table, guarded so nothing unevidenced can be written *(recommended)*

**What it is.** Each question holds one or more candidate answers. Each answer
cites the facts and patterns it rests on. The only way to write an answer is
through a single database function that refuses one without evidence.

**What you'd notice.** "How do you know that?" always resolves to your actual
words or records. When the evidence points two ways, the product says so — *"I'm
seeing two things here"* — instead of flip-flopping between them week to week.

**What it costs.** Four or five new tables, one guarded write function, and a job
that derives answers. Medium. Every writer must go through the one function,
which makes quick experiments slower.

**How it fails.** The database can prove evidence *exists*. It cannot prove the
evidence is *relevant*. If the derivation picks real but irrelevant facts, you get
a wrong answer with receipts. That's caught by the test bank and by your
confirmations, not by the schema.

**What it forecloses.** Nothing significant. It's the most flexible option.

### B — Answers computed on the fly, nothing stored

**What it is.** Each answer is calculated from your facts every time it's asked.

**What you'd notice.** Fast and always current for things like "what does a normal
week look like." Complete silence on anything needing judgement.

**What it costs.** The least. No stored state means no replay problems.

**How it fails.** It can only express about 9 of the 36 questions — the ones that
are pure arithmetic over records. There's nowhere to record that you confirmed or
rejected an answer, so accuracy can never be measured.

**What it forecloses.** The whole "does this land? → your answer → it settles"
loop. **Worth using inside A** for the arithmetic questions; not enough alone.

### C — Answers stored as facts, in the existing facts table

**What it is.** An answer becomes a special kind of fact.

**What you'd notice.** Nothing at first. Later, an inference stated to you as
though it were something you said.

**What it costs.** The least to build. Reuses machinery that exists.

**How it fails.** It puts facts and guesses in one table. Every part of the system
that reads facts would pick up guesses unless each one remembers to filter them
out — and the claim ladder says those two must never blur.

**What it forecloses.** A clean boundary between "what you said" and "what we
think." Hard to undo once things depend on it.

### D — Extend the portrait document to 36 slots

**What it is.** Add the answers as fields in the existing portrait.

**What you'd notice.** Answers that drift between versions — the same failure as
the current 88-version prose portrait, which is how the zero-sleep claims got in.

**What it costs.** The cheapest.

**How it fails.** A document can't enforce that an answer has evidence. Lineage
becomes ids inside a blob, which is exactly what failed.

**What it forecloses.** Structural lineage. It cannot pass the first metric.

### Doing nothing

Keep the current portrait. You'd keep hearing confident sentences about yourself
with nothing behind them, including the false ones. Every goal from 8 onward
inherits that.

---

## Recommendation

**Option A**, using B's on-the-fly calculation for the arithmetic questions and
C's existing idempotency machinery under the hood.

**The trade-off you're accepting:** a stricter, slower write path in exchange for
"how do you know that" always having a true answer. The product will speak about
you *less* at first — 0 of 36 domains clear the bar today — and that silence is the
system working, not failing.

### How confidence works, in plain terms

> Each independent piece of evidence is a vote. Your own words count 1, mail and
> documents 0.6, calendar 0.4, health 0.15. Votes fade with age — fast for "how are
> you doing now," slowly for "what do you do." Contradicting evidence votes against.
> Every answer starts with two votes of doubt, so a single observation can never
> make it certain.

| Evidence | Confidence |
|---|---|
| One quote from you | 0.33 |
| Two independent quotes | 0.50 |
| Five independent quotes | 0.71 |

Votes are counted per **source document**, never per row — otherwise the 1,357
Google Doc rows would count as 1,357 votes for what is really 10 documents.

Your confirmation is kept **separate** from confidence. It raises an answer to
"you said so" rather than nudging a number.

---

## Prerequisites — found while checking the design, and they come first

Each of these was verified in the code, not taken from the survey's word.

1. **Facts aren't written atomically.** A fact and its evidence are saved in two
   separate calls, so a failure between them leaves a fact with no evidence. The
   question store's guarantee is only as strong as the layer under it.
2. **Replaying moves timestamps.** Every re-save stamps a fact as observed *now*,
   so reprocessing old writing makes it look recent.
3. **Deleting a source strips its evidence silently.** The fact survives,
   unevidenced.
4. **Data quality.** Count independent sources, not rows; treat sensor zeros as
   missing. The second is done; the first belongs here.
5. **One source of truth for the schema.** Migrations are applied by hand and
   production has drifted from the code. The guarded write function depends on
   database permissions holding, which depends on knowing what's actually deployed.

---

## If you pick A, it splits into

1. Facts written atomically, with a database rule that a fact must have evidence;
   stop refreshing timestamps on replay; retire facts whose evidence is deleted.
2. Count independent sources, not rows.
3. The question and domain tables, seeded with the 36 questions and the
   per-domain bars you set.
4. The answer tables, with direct writes revoked.
5. The single guarded write function, plus the rules it enforces.
6. Read-only views for current answers, coverage per domain, and accuracy — the
   two numbers never merged.
7. Arithmetic answers (one PR per group of questions).
8. Answers lifted directly from your own words.
9. Model-written answers, one domain at a time, only when that domain's evidence
   changed, with the model's own confidence discarded — models are measurably
   overconfident about themselves.
10. Wiring it in after the pattern-finder, with a twice-equals-once test.
11. The portrait reads answers for its matching slots, keeping its current shape so
    nothing downstream breaks.
12. Coverage reported for your account — the Phase 2 gate.
13. Tests that try to cheat: a direct write, an answer with no evidence, evidence
    from another user, a "how do you feel" answer backed only by sensor data. Each
    must be refused.

---

## Also needs your decision

**Clearing the false claims already in your portrait.** The new guard stops more
being made. The eight zero-sleep sentences already there came from 326 identity
inferences that have never been retired, so the next portrait rewrite would
regenerate them. Removing them changes what the product says about you — so it's
your call, not mine. My recommendation: retire the inferences built on sleep data
and let the next rewrite run without them.

---

## What's unverified

- **The confidence weights** were tuned for counting patterns. Reusing them here is
  an assumption to tune against your reactions.
- **Whether a model picks relevant evidence** for the judgement questions. Untested,
  and it's the main way Option A fails.
- **The 10–14 estimate** if your writing were processed — from content types, not
  from reading the documents.
- **Two Postgres details** — that revoking write access holds on this Supabase
  project, and that the check-at-commit rule works inside the function. Both are
  standard; neither has been tested here.
- **No published system does exactly this.** Zep, mem0 and Letta each lack
  confidence or database-enforced provenance. The design combines older, proven
  ideas — slot filling with provenance, truth-maintenance systems, and
  evidence-counting belief models — rather than copying a product.
