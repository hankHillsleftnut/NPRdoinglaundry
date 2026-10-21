# Decision record

**What this is.** Every decision that changed how the product behaves, in order,
with the evidence that drove it and what happened after. Founder's request,
18 October 2026: *"record them in a place where I can check your work … see how
the performance actually went … see what actually improves performance … so I
can learn what you did and see if the decision made sense to me."*

**How to read an entry.** *Problem* is what was wrong, in plain words. *Decided
by* is you or me (engineering calls within your standing rules). *Evidence* is
measured, never estimated — where it says "estimate", it says so. *Check next*
is how we'll know whether it was right.

**Rules for this file.** Entries are added, never rewritten. If a decision turns
out wrong, a new entry says so and points back. Numbers come from runs that can
be re-run (`npm run bank:score`, `npm run questions:first-pass`, `npm run db:check`).

---

## At a glance

| # | Date | Decision | Decided by | Measured effect |
|---|---|---|---|---|
| 1 | 18 Oct | Answers to the 36 questions must carry evidence (Phase 2, Option A + your amendments) | You | 0 → 28 answered; every answer cites your words |
| 2 | 18 Oct | Retire the false "zero sleep" claims; corrected portrait v89 | You | 5 inferences retired; 8 false sentences removed |
| 3 | 18 Oct | Facts and their evidence save together or not at all | Me | Proven in tests; no production data yet |
| 4 | 18 Oct | Database enforces the answer rules, not just the code | Me | 13 cheating attempts refused in tests |
| 5 | 18 Oct | Episodes may read evidenced answers (off until you switch it on) | Me | Not yet measured — needs a listened-to episode |
| 6 | 18 Oct | iPhone counts a night's sleep properly | Me | 8/8 checks; not yet seen on a real device |
| 7 | 18 Oct | `db:check` — know what production actually has | Me | Found a live bug: voice choice never saved |
| 8 | 18 Oct | `db:migrate` — apply changes safely, with a ledger | You (gave the key) | 116–125 applied, 0 failures |
| 9 | 18 Oct | Read each kind of your writing fairly; never show the model an absence | Me | 25 → 48 items read; "doesn't practise mindfulness" gone |
| 10 | 18 Oct | No assumed pronouns; no internal labels in answers | Me | 32 "he/his/him" in 6 answers + 1 label → 0 |
| 11 | 18 Oct | A document in your Drive isn't automatically your words | Me | Q26 no longer cites Ladder's brief as you |
| 12 | 18 Oct | Test bank lives on your Mac only | You | — |
| 13 | 18 Oct | Measure the extractor before changing it | Me | Baseline: 47–53% recall |
| 14 | 18 Oct | Itemise every cost by service, model, calls, tokens | You (asked) | Every paid run now prints its breakdown |
| 15 | 18 Oct | Conversations: keep only your turns | Me, from your material | Answers now reflect leaving your job, NYC, the founder choice |
| 16 | 18 Oct | Read long writing in full | Me | 98% of a long conversation was unread → 0% |
| 17 | 18 Oct | When a model corrects itself, use its final answer | Me | 1 of 8 calls was being lost → 0 |
| 18 | 18 Oct | **Extraction → Claude Sonnet 5.5, facts only** | You | Recall ~60% → ~89%; false claims down; 0.7¢ → 1.6¢ per entry |
| 19 | 18 Oct | **Question store → Claude Sonnet 5.5** | You | ~9% cheaper; comparable quality, plainer voice |
| 20 | 18 Oct | Re-read your history once with the new extractor | You | Facts 4 → 178; patterns 40 (10 live); $0.58 |
| 21 | 18 Oct | Facts mode reads one entry per call | Me | Re-read failed twice, then 43/43 read |
| 22 | 18 Oct | First run of the ambient researcher | Me (within standing approval) | 3 answers strengthened; showed "how you are" evidence is stale |
| 23 | 18 Oct | Store only the new line from shared notes | Me, from your material | 1 new entry; 2 answers weakened by it |
| 24 | 18 Oct | Merge the PR stack | You | 15 agent PRs + 2 backend PRs; every one passed its checks first |
| 25 | 18 Oct | New app entries are yours by default (migration 126) | Me | Bug caught before any entry was affected |
| 26 | 18 Oct | Read long entries in full, in sections (Phase 3.2) | Me — PR awaiting your merge | Conversation facts 37 → 95; 31 from text never read before |
| 27 | 18 Oct | Episode test: today's input vs evidenced answers; episodes report cost | Me — PR #33 awaiting your merge | $0.23 per episode before voice; voice ≈ $1.80 |
| 28 | 18 Oct | Calendar: Google via the Google sign-in; Apple via the iPhone | You | Connector built (PR #34, NPRdoinglaundry #9) |
| 29 | 18 Oct | Prove the never-run integration pipeline on a test account | You | 8 of 9 checks pass; the 9th measures the retired framework |

---

## Entries

### 1. Answers must carry evidence — Phase 2

- **Problem.** The portrait answered 20+ questions about you fluently with
  nothing behind them; some of it was false.
- **Options.** A: answers table, database refuses unevidenced answers. B:
  compute on the fly (only 9 of 36). C: store as facts. D: slots in the portrait.
- **Decided by.** You — A, amended: a first best guess at all 36 after
  onboarding, then an ambient researcher.
- **Evidence.** Before: 2 of 36 answered with evidence. After the first pass:
  28, then 31 with the conversation. Domains confident enough to speak: 2 of 8,
  now 1 (see entry 15).
- **Where.** PRs #20–#24; migrations 120–122. Brief: `brief-phase-2-question-store.md`.
- **Check next.** Accuracy — when you're shown answers, how many you confirm.
  Not measured yet.

### 2. Retire the false sleep claims

- **Problem.** 746 of 749 health summaries said "0.0 hours sleep" because
  nothing measured sleep. The portrait turned that into 8 sentences saying you
  don't sleep.
- **Decided by.** You.
- **Evidence.** 5 identity inferences retired (4 sleep, 1 mindfulness), with the
  reason recorded. Portrait v89 written with those sentences removed; v88 kept.
- **Check next.** The next portrait rewrite must not reintroduce them.

### 3. Facts save atomically

- **Problem.** A fact and its evidence were two separate saves; a failure
  between them left a claim with nothing behind it.
- **Decided by.** Me.
- **Evidence.** Real-Postgres tests: failed evidence → no fact; replay keeps
  first-seen time; cross-user evidence refused. Migration 119 live.
- **Where.** PR #19.

### 4. The database enforces the rules

- **Problem.** Code-level checks can be bypassed by any future code path.
- **Decided by.** Me.
- **Evidence.** 13 tests that try to cheat — no evidence, health data posing as
  your words, someone else's journal, a direct write with the backend's key —
  all refused. Migration 121 live.
- **Where.** PR #21.

### 5. Episodes can read evidenced answers

- **Problem.** Episodes are written from the portrait, which has no evidence.
- **Decided by.** Me — built behind `ANSWERS_IN_EPISODES`, **off**.
- **Evidence.** None yet.
- **Check next.** Generate one episode each way; you listen (step 7).
- **Where.** PR #24.

### 6. iPhone sleep counting

- **Problem.** Counted from midnight (a full night could read 1.5h), "in bed"
  became 0.0h, and two devices double-counted.
- **Decided by.** Me.
- **Evidence.** 8/8 rule checks; app builds clean. Not yet on a real device.
- **Where.** NPRdoinglaundry#8.

### 7. `db:check`

- **Problem.** Changes were applied by hand; nobody knew what production had.
- **Evidence.** First run: `users.voice_persona` missing — profile said "User
  not found" for every user, voice choices never saved. Fixed by migration 123.
- **Where.** PR #25.

### 8. `db:migrate`

- **Decided by.** You, by adding `DATABASE_URL`; each apply approved or within
  standing approval.
- **Evidence.** 116, 117, 118, 123, then 119–122, 124, 125 applied; 0 failures.
  One false alarm (124 looked partly applied) correctly refused, then resolved
  by recording 115.
- **Where.** PR #26.

### 9. Fair reading of your writing

- **Problem.** First dry run read only 25 items: 1,357 re-synced Google Doc rows
  crowded out your text entries and voice notes. And told "sleep: not recorded",
  the model still concluded you don't practise sleep tracking.
- **Evidence.** 25 → 48 items. The false "avoids mindfulness" answer disappeared
  once unrecorded readings were removed rather than labelled.
- **Where.** PR #27.

### 10. No assumed pronouns or internal labels

- **Evidence.** Second dry run: "he/his/him" 32 times across 6 answers, with
  nothing in the evidence to say so; one answer cited "(E33)". After: 0 and 0.

### 11. Whose words are these

- **Problem.** Your Drive contains Farza's hiring post and Ladder's brief. All
  Google Docs counted as your words; Q26 cited Ladder's brief as yours.
- **Evidence.** 7 evidence rows relabelled; 0 answers had to be retired; Q26
  now rests on your own words. Migration 124 live.
- **Trade-off.** Your own docs (Design Doc, SFP Application) also count for
  less until you confirm they're yours.
- **Where.** PR #28.

### 12. Test bank stays local

- **Decided by.** You. `retrospect-agent/test-bank/`, excluded from git.

### 13. Measure before changing — the extractor baseline

- **Evidence.** Today's extractor on 20 of your entries: **53% recall, 9 false
  claims** (first run); 47% / 10 on an identical second run — so differences
  under ~6 points are noise. Biggest misses: long essays (3 of 11), others'
  documents (7 false claims), opinion writing (0 of 3).
- **Where.** PR #29; `npm run bank:score`.

### 14. Itemised costs

- **Decided by.** You asked.
- **Evidence.** Every paid run now prints provider, model, calls, tokens in/out,
  price per million, and purpose.

### 15. Conversations, your turns only

- **Material.** Your 27 September conversation with Francis.
- **Evidence.** 198 of your turns kept; all 349 of Francis's left out; 151
  filler turns dropped. Answers now reflect leaving your job (Q16), the
  founder-vs-design choice (Q28), New York (Q6), how you're doing (Q27).
- **Side effect, not yet resolved.** "Who you are" fell from speaking to silent
  (5 → 2 confident) because Q1 now leans on documents that count for less
  (entry 11). Confirming which docs are yours fixes it.
- **Where.** PR #30; migration 125.

### 16. Long writing read in full

- **Problem.** The model was shown at most 700 characters of any item.
- **Evidence.** Before: ~98% of the conversation unread. After: sections of
  ~1,200 characters, all read. **Cost rose from $0.24 to $0.79 per refresh.**
- **Where.** PR #30.

### 17. A model correcting itself

- **Evidence.** Sonnet 5.5 lost 1 of 8 calls by writing a partial answer then a
  correction. After the fix: 0 of 8 lost.

### 18. Extraction → Sonnet 5.5, facts only

- **Problem.** Today's extractor finds ~60% of what your writing says, and asks
  the model for five things at once, four of them the old framework.
- **Options measured** (same 20 entries, two runs each):

  | Model | Recall | False claims | Per entry |
  |---|---|---|---|
  | gpt-4o (today) | 59–61% | 12–13 | 0.7¢ |
  | gpt-4o-mini | 63–71% | 9–18 (+12–16 invented quotes) | 0.15¢ |
  | Haiku 5.5 | 84–88% | 13–19 | 0.15¢ |
  | **Sonnet 5.5** | **86–92%** | **8–10** | 1.6¢ |
  | Opus 5.5 | 88–92% | 11–13 | 3.1¢ |

- **Decided by.** You.
- **Consequence.** The extractor stops producing observations, insights and
  identity inferences. Existing rows stay; they stop growing. Episodes that
  still read them should switch to evidenced answers (entry 5).
- **Check next.** Re-score after your test-bank corrections; recall should stay
  above 85%. Watch real cost per entry.
- **Where.** PR #31 (switch `EXTRACTOR=legacy` to undo). Doc: `model-selection.md`.

### 19. Question store → Sonnet 5.5

- **Evidence.** Same task: $0.79 → $0.72. **The price list said 33% cheaper; it
  was 9%** — Sonnet 5.5 counts ~28% more tokens for the same text. Quality
  comparable; plainer, more careful voice.
- **Decided by.** You.
- **Where.** PR #31 (`ANTHROPIC_QUESTIONS_MODEL` to undo).

### 20. Re-read your history with the new extractor

- **Decided by.** You ($1.10 estimated, above the $1 standing approval).
- **What ran.** 43 distinct pieces of your writing — copies counted once,
  latest version of each document section: 1 conversation, 20 text entries, 9
  voice notes, 2 journal entries, onboarding, 10 document sections.
- **Evidence.** Facts **4 → 178** (176 new, 0 thrown out by the quote check).
  New categories in use: 26 "believes", 25 "work plan", 23 "building".
  Patterns: 40 (10 live, 30 candidates). Old framework outputs: 0, as decided.
  **Cost $0.58** — Sonnet 5.5, 43 calls, 86k tokens in / 40k out. 6 minutes.
- **Spot check.** 14 random facts read by me: sound. One mislabel — "moving to
  New York" filed as a goal when you described it as an option.
- **Known gap.** The extractor reads at most 16,000 characters of one item, so
  only the first 16,000 of your 36,000-character conversation became facts.
  Splitting long entries is Phase 3.2. (Your 36 answers read it all.)

### 21. Facts mode reads one entry per call

- **Problem.** The re-read failed twice: the pipeline packed ~15 entries per
  call, and even one 16,000-character entry overran the reply limit.
- **Fix.** One entry per call (as benchmarked), reply limit 16,000 tokens. Also
  fixed: a real run's summary printed "facts written: 0".
- **Where.** PR #31.

### 22. First run of the ambient researcher

- **What ran.** One researcher pass on your account (`npm run questions:research`):
  the three unanswered questions first, then those furthest below their bar.
- **Evidence.** Q15, Q20, Q25: still no basis. Q27, Q28, Q30 ("how you are"):
  strengthened with new evidence — yet Q27 sits at **0.23 confidence on 4
  sources**, because evidence for "how are you doing" halves every 14 days and
  your newest writing is three weeks old. Q1 (work) is 0.10: one document not
  confirmed as yours. Cost **$0.06** (Sonnet 5.5).
- **What would move it.** A few entries this week; confirming which docs are yours.

### 23. Shared notes: store only what's new

- **Material.** Notes you shared in chat. Five of six paragraphs were already
  stored, word for word, from your 21 September journal; storing them again
  would have counted the same words as independent evidence twice.
- **Decision.** Store only the new line — "Don’t dissapear when you feel
  inadequate. Wow" — as a text entry dated 18 October, exactly as written.
- **Evidence.** The researcher read it and **weakened** Q27 ("how you're
  doing": energised) and Q30 (expansive phase) — a note about feeling
  inadequate cuts against both. Cost $0.03.

### 24. Merge the PR stack

- **Decided by.** You ("merge them").
- **How.** Bottom up, one PR at a time: re-place the PR's own commits on the new
  `main`, typecheck, run the full suite locally, push, wait for GitHub's
  required check, then squash-merge (the only method the repo's rules allow).
  Stop at the first failure.
- **What happened.** Merge conflicts appeared in two shared files (the
  migration tests and the command list), always from both sides *adding*
  things; both were resolved by keeping everything, by tools that refuse any
  other kind of conflict. One resolution produced a malformed file; the
  typecheck caught it before anything was pushed. One check-wait gave up
  early; GitHub's own status was re-read instead. #31 duplicated a field #16
  had already added; caught by the typecheck, removed.
- **Result.** All 15 agent PRs (#16, #18–#31) and backend #7, #8 merged; final
  suite 370/370. `db:check` after merging: production matches `main`, nothing
  pending.

### 25. New app entries are yours by default

- **Problem.** Migration 115 set new items' authorship to "unknown" by default,
  and the API never sets it. With 124 and the new extractor, every entry you
  typed from now on would have counted as possibly not yours — so it would
  have taught the product nothing about you.
- **How it was found.** 9 tests failed when #28 was placed on top of #16 during
  the merge. Production check: 0 rows affected yet.
- **Fix.** Migration 126 fills a missing authorship from the item's type (typed,
  spoken, onboarding and conversations are yours; sensors are no one's words;
  collected documents stay unknown). Live in production.

### 26. Read long entries in full

- **Problem.** The extractor saw only the first 16,000 characters of an entry;
  20,000 characters of your 36,000-character conversation were never read.
- **Fix.** Entries over 12,000 characters are read in sections, one call each;
  every quote still checked against the whole entry.
- **Evidence.** Re-reading the conversation: facts **37 → 95**, of which **31**
  quote text past the old cut. Cost **$0.19** (Sonnet 5.5, 3 calls).
- **Status.** PR #32, waiting for your OK to merge.

### 27. Episode test, and what an episode costs

- **What ran.** Two script-only dry runs on the same 30 days of your data —
  today's input vs evidenced answers (`ANSWERS_IN_EPISODES`). No audio, nothing
  saved. Comparison sent to you as `episode-comparison.md`.
- **Evidence.** Both free of the false sleep claims. The evidence-based script
  is shorter (939 vs 1,100 words) and, as designed, silent about New York, your
  job and how you're doing — those domains haven't cleared their bar.
- **Gap found.** The episode runner reported no cost. Fixed (PR #33), and voice,
  web research and embeddings now get their own cost lines.
- **Measured.** One episode without voice: **$0.23** (Sonnet 4.6 $0.22;
  gpt-4o-mini, gpt-4o, Perplexity under a cent each). **Voice adds ≈ $1.80**
  (≈6,000 characters × $0.30/1k) — the largest cost per episode by far.
- **Check next.** You read both scripts; then decide on `ANSWERS_IN_EPISODES`.

### 28. How calendars get in

- **Problem.** Six of the 36 questions depend mainly on a calendar; all silent;
  your account has 0 calendar entries.
- **Options.** A: iPhone reads every calendar. B: a Google Calendar connector.
  C: both.
- **Decided by.** You — Google Calendar as part of the Google integration
  (one sign-in with Docs and Gmail); Apple Calendar asked for separately.
- **Check next.** At least 4 of questions 12–16 and 22 answered from calendar
  evidence within a week of connecting.
- **Brief.** `brief-phase-4-calendar.md`.

### 29. Proving the integration pipeline

- **Problem.** The pipeline that brings in Google and Apple data had never
  processed anything: 0 jobs, 0 payloads, 0 items ever. Nobody had connected a
  calendar, and the agent's integration runtime is off in production.
- **Decided by.** You — prove it on a test account before switching it on.
- **Evidence.** Built-in smoke test on the demo account (`667a3b40…`), synthetic
  rows marked `smoke_test`. Without the model step: every stage that ran passed;
  replay skipped duplicates and updates updated. With the model step: **8 of 9
  checks passed**, through to stored content, analysis, and facts with
  evidence. The 9th counts links into observations/insights — the retired
  framework — so 0 is expected; it should be re-pointed at facts.
- **Not proven.** The job queue (a worker leasing queued jobs) — the smoke test
  feeds the pipeline directly. Proven only once the runtime is on.
- **To switch on (your Render settings).** Agent: `ENABLE_INTEGRATION_RUNTIME=true`,
  `INTEGRATION_LOCAL_ENCRYPTION_KEY` (from `openssl rand -base64 32`), and the
  Google client ID and secret. Backend: confirm the Google settings are set.

---

## 19 Oct, late — four founder decisions

| Decision | Choice | Consequence |
|---|---|---|
| People matching when unsure (W2) | **Strict: hold and ask** | Link only on decisive evidence; ambiguous pairs held and asked once |
| The 31 "active" goals (mostly duplicates) | **Merge and expire** | Near-duplicates merged; untouched or unmentioned for 90 days becomes "expired" (kept, never deleted, revivable) |
| Provisional whys | **May be asked, at most one per episode** | Always "I wonder whether…", never stated; the reaction counts as evidence |
| Database changes | **127, 130 and F1.4b approved** | Correction notes survive re-reads; answers weigh evidence by trust; re-derivation retires old evidence instead of deleting it |

---

## 19 Oct — Brain evaluation baseline (F2.4)

Declared before any W-chunk changes the reading pipeline, so every later
change is measured against it. Fictional persona "Maya" (30 items, 40
questions, LongMemEval's five abilities); `npm run eval:brain`; 3 runs.

| Ability | Mean | Runs |
|---|---|---|
| Extraction | 87% | 90 · 80 · 90 |
| Multi-session | 67% | 62 · 75 · 62 |
| Updates | 67% | 57 · 71 · 71 |
| **Temporal** | **38%** | 38 · 38 · 38 |
| Abstention | 100% | 100 · 100 · 100 |
| **Overall** | **28.7 / 40** | 28 · 29 · 29 |

- **Fail in all three runs (9):** class location, promotion uncertainty, content
  topic, run club stopped, and five counting/date questions.
- **Flaky (5):** treat a move on these as noise unless it holds over 3 runs.
- **Diagnosis:** calendar and journal facts lose dates and places, so repeats
  collapse into one (temporal); people are stored by role ("selfs_manager"),
  not name (W2); content topics aren't summarised (W4.4).
- **Rule from here:** a change claims an improvement only if the 3-run mean
  rises and abstention stays at 100%.
- Cost: $0.24 a run ($0.18 reading 30 items, $0.05 asking).

---

## Spend ledger — model calls made while building

| Date | What | Service · model | Cost |
|---|---|---|---|
| 18 Oct | First-pass dry run 1 | Anthropic · Sonnet 4.6 | $0.16 |
| 18 Oct | First-pass dry run 2 | Anthropic · Sonnet 4.6 | $0.23 |
| 18 Oct | First pass saved | Anthropic · Sonnet 4.6 | $0.24 |
| 18 Oct | First pass re-saved (authorship) | Anthropic · Sonnet 4.6 | $0.24 |
| 18 Oct | Test-bank scoring (5 runs) | OpenAI · gpt-4o + Anthropic · Sonnet 4.6 judge | ~$1.20 |
| 18 Oct | Model benchmark (10 runs) | OpenAI · gpt-4o, gpt-4o-mini; Anthropic · Haiku/Sonnet/Opus 5.5 | ~$2.57 |
| 18 Oct | First pass with conversation (700-char limit) | Anthropic · Sonnet 4.6 | $0.24 |
| 18 Oct | First pass, long writing in full | Anthropic · Sonnet 4.6 | $0.79 |
| 18 Oct | Sonnet 5.5 comparison dry runs (2) | Anthropic · Sonnet 5.5 | $1.34 |
| 18 Oct | Re-read history (43 items; two earlier attempts failed on their first call) | Anthropic · Sonnet 5.5 | $0.58 + ~$0.05 |
| 18 Oct | Researcher, first run | Anthropic · Sonnet 5.5 | $0.06 |
| 18 Oct | Researcher, second run (new note) | Anthropic · Sonnet 5.5 | $0.03 |
| 18 Oct | Conversation re-read in sections | Anthropic · Sonnet 5.5 | $0.19 |
| 18 Oct | Episode dry runs (3, script only) | Anthropic · Sonnet 4.6; OpenAI · gpt-4o, gpt-4o-mini; Perplexity | ≈ $0.69 |
| 19 Oct | Brain evaluation runs (F2.2 ×3, F2.4 ×3) | Anthropic · Sonnet 4.6 / 5.5; OpenAI embeddings | ≈ $1.37 |
| | **Total** | | **≈ $10.0** |

Estimates from token counts × published prices; the providers' invoices are
the final word.
