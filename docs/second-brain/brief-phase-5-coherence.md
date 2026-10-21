# Brief — Phase 5.2, the through-line

Step 2 of the [decision loop](./decision-loop.md). Written 18 October 2026.
Nothing built yet.

## The problem in one line

Selection decides *what* is worth saying. Coherence decides *why these things
together*. A brief that is five accurate, unrelated items is the abundance problem
with better sourcing — and the plan says this is the least-specified part of the
product.

## What exists today

- **The weekly episode picks a "theme" in one sentence** (Cook A,
  `current-context-outline.ts`), from the old portrait and recent insights. The
  theme is chosen and then the segments are chosen separately; nothing checks that
  each segment actually bears on it.
- **`guardTranscript`** can check that every sentence cites evidence. It has zero
  callers.
- **The question store** holds 31 answers, each with evidence, a confidence, and
  when it last moved. Nothing reads it for expression yet.

## Metric, declared before building

1. **Spine rate:** share of items in a brief that bear on its stated through-line,
   judged per item. Target ≥ 80%.
2. **Your verdict:** for 7 briefs, "did this hang together?" yes / no / partly.
3. **Withholding ratio** (already planned): what was known vs what was said.

## Options

### A — Pick the items, then look for a thread

Score candidates for relevance, take the top few, ask the model to find what
connects them.
**Cheap**, one extra call. **Fails by forcing it:** the model will always find a
connection, and a contrived one is worse than none. Coherence is decided last, so
it can't shape what gets picked.

### B — One moving question per brief *(recommended to start)*

Each brief is organised around **one core question whose answer moved** since
the last brief — e.g. "what is weighing on them" got new evidence yesterday, or
"what they actually do" contradicts "what they said they want". That question is
the spine; items are picked *because* they bear on it, and the brief says so.
Items that don't connect go in a short "also" tail or are dropped.
**Cheap and measurable:** it reads the question store directly, which already
records what moved and why. **Fails when nothing moved:** then the right brief is
short, which the spec already wants. **Fails by narrowness** if the same question
moves every day; a rule that a question can't lead two days running handles that.

### C — Long-running threads as first-class objects

Keep named storylines ("raising for Retrospect", "founding feels lonely") that
persist across weeks, each gathering answers, facts and events. Each brief
advances the thread with the most movement.
**Closest to how a good friend talks**: "remember last week…". **Costs most:**
a new store, rules for when a thread starts and ends, and a way to merge two
that turn out to be one. **Fails by going stale:** a thread nobody closes keeps
coming back.

## Recommendation

**B now, C later if B works.** B is a thread with a lifespan of one day; if your
verdicts show the briefs hang together but feel disconnected from each other,
that is the evidence for C. Building C first means designing thread lifecycles
before knowing whether one-day spines are good enough.

The weekly episode moves to the same rule: its theme becomes a question that
moved this week, and `guardTranscript` is wired so every segment cites
evidence that bears on it (5.5).

## What it would cost to prove

A **text-only** prototype on your account: 7 dry-run briefs from the question
store, no audio, no writes. About **$0.10–0.20 each, under $1.50 total.** You
read them and give the verdict. Audio only once the text is good.

**One honest constraint:** today almost every answer comes from your writing
alone. Calendar and Gmail would give the brief daily movement to work with. B
still works without them, but more days will be short or empty until they're on.

## Decisions for you

1. **B first?** Recommended.
2. **Prototype as text on your account, ~$1.50?** Slightly over the $1
   standing approval, so asking.
