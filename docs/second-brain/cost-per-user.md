# Cost per user per week — running estimate

Founder's direction, 19 October 2026: keep a running evaluation of what one
user costs per week, so it can be brought under a target. **Test spending is
tracked separately** — runs done to build and test the product are not what a
user costs.

Update this whenever a measured number changes. `npm run costs` gives real
spend per person from production.

## The estimate (updated 19 October 2026)

All figures measured on real runs unless marked *estimate*.

### One-time, when someone joins

| Item | Cost | Basis |
|---|---|---|
| Onboarding goals | $0.01 | measured (Claude Sonnet 5.5) |
| First pass at the 36 questions | ≈ $0.72 | measured on the founder (Sonnet 5.5); automatic for new users once the onboarding pipeline is on (#50) |
| First episode | **$1.89** | measured (voice ≈ $1.60 of it) |
| …a second, duplicate episode | ~~$1.89~~ $0 | fixed (#15, merged 19 Oct) |
| First read of their connected data | $1–3 | measured on the founder: calendar 45 items $0.34, Gmail 25 $0.19, YouTube ~150 ≈ $1.10; Docs in progress |
| **Total to join** | **≈ $3.50–5.50** | first episode + first pass + first read of their data |

### Every week, after that

| Item | Cost / week | Basis |
|---|---|---|
| Weekly episode | **$1.89** | measured; voice is ~85% |
| Reading new material | ≈ $1.10 | *estimate*: ~20 new items a day × ~0.8¢ (measured per item) |
| Researcher (daily, 6 questions) | ≈ $0.30 | measured per question (~0.7–1.5¢) |
| Daily brief | $0 now | not built; when built ≈ $0.70 text + voice $2–15/week depending on length — **off by default** per the spec |
| **Total per week** | **≈ $3.30** | |

**Where the money goes: voice.** Roughly 60% of a normal week is the weekly
episode's voice.

### Levers to bring it down (not yet decided)

| Lever | Saves / week | Trade-off |
|---|---|---|
| Fix the duplicate onboarding episode | $1.89 once | none — it's a bug |
| Shorter weekly episode (e.g. 5 min instead of 7) | ≈ $0.50 | less depth |
| Cheaper voice model / plan tier | up to ≈ $1.00 | voice quality — needs a listen test |
| Read low-stakes sources (YouTube, promotions) with Claude Haiku 5.5, or not as facts at all | ≈ $0.50 | slightly less recall on those |
| Batch the researcher and re-reads (Anthropic's batch pricing is half price for work that can wait) | ≈ $0.15 + half of any re-read | results arrive within hours, not instantly |
| Gmail: primary and sent only (done, #46) | ≈ $0.10 | none |

**A target to agree on:** e.g. **under $2 per user per week**, excluding the
daily brief. Reachable with the voice and episode-length levers.

## Test spending (not user cost)

| Date | What | Cost |
|---|---|---|
| 18 Oct | Model benchmark, question-store runs, test-bank scoring | ≈ $7 |
| 19 Oct | Daily-brief prototype | $0.39 |
| 19 Oct | Researcher runs ×4 (fixing routing on the founder's account) | ≈ $1.84 |
| 19 Oct | Founder's onboarding test runs (episodes) | ≈ $5 |
| 19 Oct | First read of the founder's data | ≈ $2.70 — this one is also a real user cost |
| 19 Oct | Brain evaluation runs ×6 on the fictional persona (F2.2, F2.4 baseline) | ≈ $1.37 |
| 20 Oct | Drafts, fact-check gates, search tryouts, dry runs (all offline or dry) | ≈ $0.40 |
| 20 Oct | Retro voice samples ×5 (4 on eleven_v3, 1 on flash v2.5; 662 characters each, 3,310 in all), on the founder's ElevenLabs subscription | subscription characters, not dollars |

Most of the founder account's $10.19 on 19 October was testing, not use.

## Ceiling

Per person per 24 hours: **$15** (`USER_DAILY_SPEND_CAP_USD`, #48). Over it,
new episodes are refused; reading data never is.

**Reading cost, measured (19 Oct):** reading 30 items through the full pipeline cost $0.18–0.19 (fictional persona). That's about **$0.006 per item**, consistent with the join-cost estimate above.

**20 Oct, night (test only):** search gate ×9 runs ≈ $2.40 · corrections targeting ×4 ≈ $0.10 · 2026 research and links gate ≈ $0.05 → **≈ $2.55**. New per-use cost: a plain-language correction ≈ $0.001.

**Later 20 Oct (test only):** hypotheses live ≈ $0.03 · conversation gate ×7 ≈ $1.20 → **≈ $1.25**. New per-use cost: a conversation reply ≈ $0.01.

**Running total, 20 Oct night:** ≈ $22.75 since 18 Oct. Before tonight: ≈ $19 since 18 Oct (production logged $10.34 in 72 h, mostly your test episodes and first read; ≈ $9 offline tests). **New paths per use:** weekly script $0.016 before voice · daily brief $0.007 · search $0.01.
