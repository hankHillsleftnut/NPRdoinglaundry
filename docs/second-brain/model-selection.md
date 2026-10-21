# Which model for which job

**Founder's direction, 18 October 2026:** for every job a model does in the
system, ask whether the current model is the best choice — on cost, speed,
quality and what the model is actually good at — and change it where a better
option exists. Measured, not assumed.

**Status: the extraction benchmark is running; the rest is analysis with the
decisions marked.** Nothing has been switched yet.

---

## How the system spends money today

From the run logs, May–September 2026 (the old meter, known to be wrong in
places — treat as rough):

| Pipeline | Runs | Estimated spend |
|---|---|---|
| Ingestion (reading your writing) | 286 | **~$53 (93%)** |
| Weekly episode | 19 | ~$4 |

**Extraction is where model choice matters.** Everything else is small
until there are many users.

## Every model in the system

Defaults from `src/config.ts`. Production can override them with Render
settings, which I cannot see from here.

| Job | Model now | How often | Notes |
|---|---|---|---|
| Reading writing into facts (ingestion) | OpenAI gpt-4o | every new entry | 2024 model. Being benchmarked — see below. |
| Rewriting the portrait (Cook 0), magic moments | Claude Sonnet 4.6 | each ingest | Being retired with the old model (architecture §6b). |
| Episode outline (Cook A) | OpenAI gpt-4o-mini | weekly | Cheap. Fine until episodes read the question store. |
| Episode research (Cook B), notifications | Claude Sonnet 4.6 | weekly | |
| Episode script (Cook C) | Claude Sonnet 4.6 | weekly | The job users hear. |
| Episode title, summary | OpenAI gpt-4o | weekly | A small, simple job on a large model. |
| Question store: first pass, researcher | Claude Sonnet 4.6 | daily when on | Judgement about a person. |
| Search embeddings | OpenAI text-embedding-3-large (3,072 dims) | every entry | Too large to index — see below. |
| Web research | Perplexity sonar-pro | weekly | |
| Voice | ElevenLabs eleven_v3 | weekly | |

## Current prices

Verified against Anthropic's pricing page today. OpenAI's are from the existing
price table, not re-verified.

| Model | Input / Output per million tokens |
|---|---|
| Claude Haiku 5.5 | $0.10 / $0.50 (prompts under 100k tokens) |
| Claude Sonnet 5.5 | $2 / $10 |
| Claude Sonnet 4.6 (in use) | $3 / $15 |
| Claude Opus 5.5 | $4 / $20 |
| OpenAI gpt-4o (in use) | $2.50 / $10 |
| OpenAI gpt-4o-mini (in use) | $0.15 / $0.60 |

Two facts from the table alone:

- **Sonnet 5.5 is a third cheaper than the Sonnet 4.6 used everywhere, and
  newer.** Switching is very likely a pure gain, but it changes what users read
  and hear, so it is measured (and, for episodes, listened to) first.
- **Haiku 5.5 is 30× cheaper than Sonnet 4.6.** If it holds quality on a job, it
  changes what is affordable — e.g. researching every question daily.

Anthropic also offers a batch discount for work that can wait (the daily
researcher, re-extracting history). Not used yet.

## Extraction — measured on your test bank

Five models, two runs each, on the same 20 entries of your writing, with the
same instructions (Option F, facts only) and the same judge. Measured 18
October 2026. Cost is the extraction model only, for all 20 entries.

| Model | Recall | False claims | Invented quotes | Cost / 20 | Per entry | Speed (median) |
|---|---|---|---|---|---|---|
| OpenAI gpt-4o (**in use**) | 59–61% | 12–13 | 1–2 | $0.14 | 0.7¢ | 2–3 s |
| OpenAI gpt-4o-mini | 63–71% | 9–18 | **12–16** | $0.03 | 0.15¢ | 4 s |
| Claude Haiku 5.5 | 84–88% | 13–19 | 1 | $0.03 | 0.15¢ | 6 s |
| **Claude Sonnet 5.5** | **86–92%** | **8–10** | **0** | $0.33 | 1.6¢ | 7 s |
| Claude Opus 5.5 | 88–92% | 11–13 | 0 | $0.62 | 3.1¢ | 9–10 s |

**How sure is this?** The same model's recall moved up to ±6 points between
identical runs, so differences that small are noise. The gap between today's
model and the Claude 5.5 models — about 30 points — is far outside it. The
expectations are still my drafts; your corrections will move the numbers,
probably not the ranking.

**What it shows:**

- **Today's model finds about 60% of what it should.** Every Claude 5.5 model
  finds well over 80%.
- **Sonnet 5.5 is the best on what matters most:** highest recall, fewest
  false claims, never invents a quote. About 2.3× today's cost per entry.
- **Opus 5.5 is not better than Sonnet 5.5 here** — same recall, more false
  claims, twice the cost, slower. Not worth it for this job.
- **Haiku 5.5 finds almost as much as Sonnet for a tenth of the price,** but
  makes ~50% more false claims. The right choice if volume ever makes cost
  dominant; not while trust is the product.
- **gpt-4o-mini invents quotes** (12–16 per run, all caught by the span check
  and thrown away). Cheap, but wasteful and unreliable.

**Recommendation: extraction moves to Claude Sonnet 5.5**, together with Option F
(facts only). For a typical user's backlog (~66 pieces) that is about $1 once;
for each new entry about 1.6¢.

Benchmark cost: ~$2.57 in total (all ten runs, extraction plus judge).

## The question store — Sonnet 4.6 vs Sonnet 5.5

Same task (the first pass on your account, everything read in full), dry run,
18 October 2026:

| | Sonnet 4.6 (in use) | Sonnet 5.5 |
|---|---|---|
| Questions answered | 31 | 31 |
| Cost | $0.79 | $0.72 |
| Tokens counted for the same text | 222k in | **284k in** |

**The price list misleads here.** Sonnet 5.5 is a third cheaper per token, but
counts ~28% more tokens for identical text, so the real saving is ~9%.

**Quality, side by side:** comparable. 5.5 writes plainer, shorter answers and
is slightly more careful ("appear to have left a startup design job" vs "laid
off or departed"). It caught your worry about founding being lonely, which 4.6
missed; 4.6 was a little more specific in places. This one is a judgement of
taste about how the product describes you — yours to make.

It also found a robustness gap affecting every Claude call: a model correcting
itself mid-reply lost the whole call. Fixed for all models.

## Embeddings

The 3,072-number vectors exceed the 2,000-dimension limit of the database's
`ivfflat` index, so every search scans every row, and four index definitions in
the migration history cannot be built at all. text-embedding-3-large can
return shorter vectors directly (its `dimensions` setting) at the same price,
and they fit an index. **Recommendation:** 1,536 dimensions, re-embed the 66
distinct pieces of writing (cents). Low urgency — only Cook B's search uses
embeddings, and coverage is 0.5% today.

## Decisions for you

1. **Extraction → Claude Sonnet 5.5 with Option F (facts only).** Measured:
   ~60% → ~89% recall, fewer false claims, no invented quotes; ~2.3× the cost
   per entry (0.7¢ → 1.6¢). Recommended. Also retires the old observations /
   insights / inferences outputs from the extractor (architecture §6b), so it
   is a Phase 3 decision as well as a model one.
2. **Question store → Sonnet 5.5 or stay on 4.6.** ~9% cheaper, comparable
   quality, different voice. Your taste call; compare the answers above.
3. **Embeddings → 1,536 dimensions.** Same model and price, indexable. Low
   urgency.
4. **Episodes (Cook B, Cook C) → Sonnet 5.5.** Not yet tested. Needs one
   episode generated each way and listened to (step 7 of the loop), because
   it changes what you hear.
5. **Small jobs (episode titles, summaries) → Haiku 5.5.** gpt-4o is far more
   than a title needs. Not yet tested; trivially cheap to check.

## What this research cost

About $7 in model calls on 18 October 2026, all itemised in the runs above:
the extraction benchmark ~$2.57, question-store runs ~$3.20, test-bank
scoring ~$1.20.
