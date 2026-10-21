# Survey — how current engineering solves each piece

Step 2 of the [decision loop](./decision-loop.md) for the
[target architecture](./target-architecture.md), 19 October 2026. For each
piece: what exists, what we take, and the verdict — **adopt** (use as is),
**adapt** (take the method, build in our stack), **build** (nothing fits).

Our constraints that decide most verdicts: TypeScript + Postgres (Supabase),
the span rule (a fact needs your exact words), lineage enforced by schema,
small data per person (hundreds to thousands of items, not millions).

## 1. The memory model — temporal knowledge graphs

**What exists.** Zep's Graphiti engine ([paper](https://arxiv.org/html/2501.13956v1),
[library](https://pypi.org/project/graphiti-core/0.17.5/)) stores agent memory as
a knowledge graph with three tiers — *episodes* (raw input, kept as
provenance), *entities and facts* (extracted), *communities* (summaries) — and
**bi-temporal edges**: each fact records when it was true and when it was
learned; a contradicting fact sets `invalid_at` on the old one rather than
deleting it. Mem0 is vector + fact extraction; Letta is a tiered-memory agent
runtime ([comparison](https://www.digitalapplied.com/blog/open-source-agent-memory-mem0-letta-zep-compared)).
Their benchmark claims conflict and are mostly self-reported
([analysis](https://pub.towardsai.net/mem0-vs-zep-vs-letta-a-folder-of-text-files-shouldnt-beat-the-61k-star-memory-layer-9d7e65c5799c)).

**What we take.** The model maps almost exactly onto ours: our `raw_content` is
their episode; our facts with spans are their edges; supersession is their
invalidation. Two things we lack and should take: **bi-temporal validity on
every claim** (true-when vs learned-when) and **invalidate, never delete**.

**Verdict: adapt.** Not the library — it is Python on a graph database, and it
has no span rule or claim ladder. The method, in our Postgres schema.

**Architecture change:** claims get `valid_from` / `valid_to` (true-when) beside
`created_at` (learned-when); supersession becomes invalidation everywhere.

## 2. People — entity resolution

**What exists.** Probabilistic record linkage (Fellegi–Sunter), as in
[Splink](https://pypi.org/project/splink): pairwise comparison on several fields,
a match weight per field, a match score, and **explainable** parameters
([UK government write-up](https://www.gov.uk/government/publications/joined-up-data-in-government-the-future-of-data-linking-methods/splink-mojs-open-source-library-for-probabilistic-record-linkage-at-scale)).
Works best with several independent fields; needs blocking to avoid comparing
every pair. Graphiti uses hybrid similarity (embedding + full text) for
duplicates.

**What we take.** Fellegi–Sunter-style scoring on the fields we have: name,
email, handle, co-occurrence (same meeting, same thread), first-name-only flag.
Two thresholds: **link** above the upper, **hold** between (asked, never
guessed — goal 4), **separate** below. An LLM only breaks ties in the held
band, and never merges on its own.

**Verdict: adapt.** Splink is Python and built for millions of rows; per person
we have hundreds, so a small scorer in TypeScript with the same model, and its
weights visible.

## 3. Pattern trajectory — is it weakening?

**What exists.** Change-point detection: Bayesian online
([Adams & MacKay](https://arxiv.org/pdf/0710.3742)); offline methods built for
**short, discrete count series** ([arXiv 2008.09083](https://arxiv.org/pdf/2008.09083))
— the honest case for personal habits, where most methods assume long
continuous series.

**What we take.** For counts like "skipped the gym": compare the rate in the
recent window with the prior window using an exact test for two Poisson rates
(conditional binomial), and say "weakening" only when it clears the same bar as
the pattern's existence (goal 25). Output in the spec's own words: "twice this
month, five times last." Online change-point methods later, when there's
enough history.

**Verdict: build** (small, standard statistics; no library needed).

## 4. Choosing what to say — selection

**What exists.** Maximal marginal relevance (relevance minus redundancy, one
weight); greedy **submodular** selection, which is near-optimal (within
1 − 1/e) and in a 2025 study matched or beat MMR
([DRAG](https://digital.lib.washington.edu/researchworks/items/7785043e-d64c-4cf9-aa78-812993c3175e);
[overview](https://jina.ai/ko/news/submodular-optimization-for-text-selection-passage-reranking-context-engineering/)).
Recent agent work stops spending when marginal value falls
([arXiv 2608.08389](https://arxiv.org/pdf/2608.08389)).

**What we take.** The planner as **greedy submodular selection**: value =
relevance to what moved (spine) + coverage of distinct questions − redundancy,
with a **stopping threshold** — when the next item's marginal value is below
the bar, stop. That threshold *is* "say less than you know" (P5), and the
withholding ratio falls out of it as a number.

**Verdict: adapt** (deterministic code; testable; replaces "the model picks").

## 5. Staying grounded — checking the writer

**What exists.** Sentence-level claim checking against source documents:
[MiniCheck](https://huggingface.co/lytang/MiniCheck-RoBERTa-Large) (small model,
binary supported/unsupported); LLM-as-judge for attribution
([Yue et al. 2023](https://preview.aclanthology.org/watermark/2023.findings-emnlp.307));
citation-faithfulness work ([CiteGuard](https://arxiv.org/html/2510.17853v3)).

**What we take.** Our span check proves a **quote exists**; it does not prove
the sentence built on it **says what the quote supports**. Add an entailment
check per sentence: does its cited evidence support it? Start with Claude Haiku
5.5 as the judge (cheap, no hosting); measure against MiniCheck later if cost
or speed demands.

**Verdict: adapt.** Wire the existing `guardTranscript` (citations exist) plus
an entailment judge (citations support).

## What the survey changes in the architecture

| Change | From |
|---|---|
| Claims carry true-when and learned-when; contradiction invalidates, never deletes | §1 |
| People resolution: scored, three bands (link / hold / separate), weights visible | §2 |
| Trajectory by a two-window rate test, same bar as existence | §3 |
| Planner = greedy submodular selection with a stopping threshold (= withholding) | §4 |
| Guard = citations exist **and** each sentence is entailed by its evidence | §5 |

## Still to survey (when their steps come)
Search (hybrid keyword + vector + rerank; pgvector index limits) · hypothesis
frameworks registry (the literature for goal 21/22, research task in the spec) ·
voice (expressive TTS options and cost, given voice is ~60% of a user's week).
