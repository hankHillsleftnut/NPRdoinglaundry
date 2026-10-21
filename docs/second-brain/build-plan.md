# Build plan — macro to PRs

19 October 2026. How the [goal spec](./goal-specs.md) becomes the brain, at four
levels: **macro plan → chunks → bites → PRs**. Built on the
[target architecture](./target-architecture.md), the
[research foundations](./research-foundations.md) (design changes C1–C10), the [goal research matrix](./goal-research-matrix.md) (every goal: approach, evidence, maturity; R1–R6) and
the [decision loop](./decision-loop.md). Supersedes the milestone order in
[engineering-plan.md](./engineering-plan.md), whose task log continues.

## 📍 Live progress

*Updated after every step. Last update: 20 October 2026, night.* **Process:** every approach calibrated (state of the art → goal spec → best → most robust, [approach-calibration.md](./approach-calibration.md)); every PR reviewed before merge.

**Whole goal spec: ~83%** (~60% at the start of tonight) · **Phases A–E: ~75%** · **Phase F: all 7 chunks built and merged**. **Database steps:** 147–151 applied ✅ (confirmed 20 Oct). **Merged tonight (20):** search #111 · corrections #112, #114, #115 + NPRdoinglaundry#18 · lint #117, #118 · appetite #119 · style #120 · hypotheses #121, #122 · learning #123 · actions #125 · people #126 · conversation #124 · appetite first guess #127 · YouTube watch-history import #128 · YouTube transcripts #129 (on when a Supadata key is set) · saved links #116. **Tests:** 751 under production's row limits. **Left, all yours:** listening and grading (~8), decisions (~3: appetite, hypotheses dial, low-step days, YouTube, exam questions, goals note), using it (~4). [what-i-need-from-you.md](./what-i-need-from-you.md) · **iOS refresh:** one combined proposal, problems → what to change → solutions ([ios-problems-changes-solutions.md](./ios-problems-changes-solutions.md)): 43 new screens including sign-in, onboarding rebuilt to your north star (something pretty → sign in → one conversation through privacy and Connect → ready → tease → paywall → home), a parasocial test, 23 backend gaps (K23 new: next-best question), 12 contradictions found and fixed. **Side tracks:** design tokens **394** (Lime-coverage + every app need; validated) and **in Paper** (token pages: palette, colour roles light|dark, type/space/radius/elevation, motion & haptics) · iOS app audit **done** (167 entries: 10 blockers · 62 major · 76 minor; [app-audit.md](./app-audit.md)) · [iOS v2 implementation plan](./ios-v2-implementation-plan.md).

### Chunks
| Phase | Chunk | Status | Gate |
|---|---|---|---|
| A | F1 Claims, lineage, time | ✅ done (#57–#60) | ✅ every claim walks to a source (all 66 of your answers do) · ✅ nothing deletes a claim (F1.4b #81: last known case fixed, migration 138 live) · ✅ replay twice = once · 🟡 walk takes ≤ 4 queries, not 1 (speed only; revisit if it's slow) |
| A | F2 Brain evaluation suite | ✅ F2.1 #61 · F2.2 #62 · F2.4 baseline · F2.3 waits on you | baseline **28.7/40** (3 runs): facts 87% · connecting 67% · changes 67% · **time 38%** · saying "I don't know" **100%** |
| A | F3 Events | ✅ built (#63–#65), migrations 132–133 live · switch off until you flip it | before the switch: 95% read within 10 min, but **117 items waiting** and research only daily |
| B | **W1 Trust classes** | ✅ done (#55, #56, #80; migrations 129, 130, 137 live) | ✅ 15/15 classes · ✅ 0 inner-life facts from non-own-words · your answers held (none rested on automated items) |
| B | W2 People | ✅ strict scorer ✅ #87 (gate 12/12, 0 wrong links) · resolution ✅ #88 · apply + hold queue ✅ #89 · **un-tabled by you (20 Oct)**: runs daily (#126); the 6 clear matches link, and the 6 unclear ones are asked ("Is the Sam in your writing Sam Ortiz?") | today: 555 people, all from journals, exact-name only; 0 from calendar or mail |
| C | W3 Patterns with trajectory | 🔄 W3.1 daily summaries ✅ (#66–#68, migration 134 live, your 120 days backfilled) · W3.2 patterns from records ✅ #69 (behind a switch until you check) · W3.3 trajectory ✅ #70–#72 (migration 135 live) · W3.4 baseline shifts ✅ #73 · W3.5 where your time went ✅ #74–#76 · **W3 built**; W3 gate on trajectory ✅ 10/12 | your last 120 days: calendar 35 days · health 79 · subscriptions 20 · mail 1 · **own writing 2 days (5 entries)** |
| C | W4 Understanding read contract | 🔄 W4.1 ✅ #77 · W4.2 ✅ #78 · W4.4 ✅ #79 · goal lifecycle ✅ #82–#83 (31 → 3 active; backend now reuses goals, NPRdoinglaundry#16) · W4.3 said vs did ✅ #84 (your review) · next W4.5 route | your contract: 2 of 8 areas may speak · 8 answers (7 stated, 1 asked) · 21 live patterns · 0 live whys · 31 "active" goals (all June) |
| D | W5 Planner | 🔄 calibrated (DPP-style, deterministic) · W5.1 core ✅ #90 (gate 3/3) · W5.2 plan from the contract ✅ #91 · next W6 writer (calibrate first) | ✅ gate W5 3/3, never pads |
| D | W6 Writer + guard | 🔄 calibrated · W6.1 claim guard ✅ #92 · W6.2 writer ✅ #93 · W6.3 blind experiment ✅ #94 (your ranking) · W6.4 switch ✅ #96 · **W6 built** | ✅ gate W6 10/10, 0 must-catch missed |
| D | W7 Voice + audio check | ⬜ (stop point: your listen) | — |
| E | D1 Daily brief | ✅ built (#97–#100), **switched on by you, 20 Oct** · gate = your verdict on 7 briefs | today's dry run: 161 words, 3 items, 0 cut, $0.007 |
| E | AMB Ambient on/off | ✅ #101 (migration 141 live): your master `AMBIENT_MASTER=off` + each person's switch | ✅ off = only what's sent is read (tests) · app toggle logged for iOS v2 |
| E | R1 Reference bank + Notion | 🔄 R1.1 capture ✅ #102 · R1.2 safe enrichment ✅ #103 · R1.2b long pages ✅ #104, tweets ✅ #105 · R1.3 relevance ✅ #106 · R1.4 reminding ✅ #107 · **R1.5 merged** #116 (147 applied) · YouTube import #128, transcripts #129 | ✅ **49/50** found by why you saved them (paraphrases 27/28) · 0 claims about you from saved links |
| E | S1 Search | ✅ S1.1 #108 · S1.2 #109 · S1.2b #110 · **S1.3 gate passed** #111 | ✅ **83%** over 3 runs (32, 32, 36 of 40; bar 80%) · "I don't know" 7/7 every run · ~$0.01 a search |
| — | Gate test sets (all of W) | ✅ #54 | 52 cases, bars declared before code |
| F | **F-C Corrections that stick** (goal 20) | ✅ calibrated · F-C1 retraction ✅ #112 (10/10, 3/3) · F-C2 never resurrected ✅ #114 (6/6) · F-C3 plain words + F-C4 own words asked merged #115 (19/20 ×3, 0 wrong) · F-C3b app buttons merged NPRdoinglaundry#18 · migration 148 ✅ · **F-C done** | gate declared: 0 resurrections · 100% unsupported dependents retire · supported ones survive · ≥ 90% right target |
| F | F-L Lint in charge (goal 5) | ✅ F-L1 daily, safe at scale, closes what's fixed ✅ #117 · F-L2 flagged claims stay out of outputs + F-L3 hardening checks (H1 asked twice unanswered, H2 60 days unsupported) ✅ #118 · **F-L built** | ✅ 2,500 facts → 0 false findings |
| F | F-S Style and appetite (goals 9, 22) | ✅ F-S1 appetite ladder 0–3, you set it or it's read from behaviour, merged #119 (behind `ENABLE_APPETITE`, your call) · F-S2 cuts stock comfort and performed empathy, merged #120 · bounded style matching moves to F-V · **F-S built** | ✅ appetite 13/13 cases · ✅ style 20/20, 0 cuts on 115 real draft sentences · goal 9's real metric is your rating |
| F | F-H Hypotheses (goal 21) | ✅ calibrated (closed non-clinical framework catalogue; model proposes, code decides) · F-H1 propose, validate, store #121 · F-H2 offered in the asked slot only when the dial is on and appetite ≥ 2, "no" in one word, 30-day expiry, "why do you think that" route #122 · migration 149 ✅ · merged #121, #122 · **the dial ships off** · **F-H done** | ✅ 31/31: 20 clinical phrasings blocked · live: non-clinical proposals, all held because no domain had critical mass yet (the gate working) |
| F | F-Q Learns which questions to ask (goal 19) | ✅ calibrated (one person gives too little data for a bandit; a bounded Bayesian answer rate per kind of question instead) · F-Q1 merged #123: orders only what the gates already allow · visible, last 5 snapshots kept · behind `ENABLE_LEARNING` · **F-Q built** | ✅ bounds hold over 200 random histories · ✅ writes nothing about you (write-tracked) |
| F | F-V Conversation (goal 18) | ✅ calibrated · F-V1 #124: today's turns are working memory and the brain is long-term memory; same fact and style checks; no restating as discovery; silence allowed; bounded length; context rules (CIMemories); "that's wrong" goes to corrections · migrations ✅ · merged #124 · **F-V done** | ✅ rules 4/4, integration 4/4 · live, 3 runs: quiet on 9/10 messages you're just sending, **8/10 questions answered** (bar 8), 0 over budget |
| F | F-A Acting (goal 17) | ✅ mechanism #125: a ledger, preview, approval or standing authorisation, undo; **content never starts an action** (CaMeL-style) · prepare-only, no write credentials · **acting vs preparing is your call** · migration 151 ✅ · merged #125 | ✅ 4/4: 0 actions from content, 0 runs without approval |

### PRs in the current chunk (W1)
| PR | What | Status |
|---|---|---|
| W1.1 | Trust classifier | ✅ merged #55 |
| W1.2 | Trust level stored on every item (migration 129) | ✅ merged #55 · applied · 2,669 items backfilled |
| W1.3 | Reading enforces it | ✅ merged #55 |
| W1.4 | Answers weigh evidence by trust (migration 130) | ✅ merged #55 · ⏸ apply waits for your yes |
| W1.5 | Effect on your answers (counts only) | 🔄 waits on 130 · fix found on the way merged #56 |

### Recent
- **Search, your shape (S1.2–S1.2b, #109–#110):** "here's what we found" on top, sources below, each openable. Questions are rewritten into searches, every claim cites a source and is fact-checked, and it says plainly when nothing answers. Tryout on your bank: 3/3 answered, ~$0.01, 7–13 s, so sources show first. Your three results are in `.scratch/search-v1-tryout.md`. Also added: the route for the ambient toggle.
- **What "done with A–E" gives you:** the weekly episode, the daily brief and search on the new brain, a bank for everything you send, and the ambient switch. Phase F (corrections, conversation, hypotheses, calibration, learning, acting) is the companion layer after that.
- **Saved links come back (R1.3–R1.4, #106–#107):** each link is tied to the goals and questions it bears on. Once a day at most, the brief brings back one you saved a week or more ago, when it bears on something live right now. No graveyard.
- **More links understood:** long pages are now read in full, in sections (#104). Tweets are read through X's official embed endpoint (#105), verified live. **Your calls:** YouTube transcripts ([brief](./brief-youtube-transcripts.md)); whole-bookmark sync from X needs its paid API (~$200/mo). Until then, share tweets one by one.
- **Links you send (R1.1–R1.2, #102–#103):** captured with your words as the reason, then fetched safely and summarised (about the page, never you). They're kept apart from what the brain believes about you. **Gaps you asked about:** only the first ~6,000 characters are read; JavaScript-only, paywalled, PDF and video links aren't understood yet. YouTube transcripts and full-length pages come next (R1.2b).
- **Ambient switch built (#101, your requirement):** `AMBIENT_MASTER=off` in Render turns ambient off for everyone; each person also has their own switch. Off means only what they send is read: no syncing, research or background patterns.
- **Daily brief on the new brain (D1, #97–#100):** what you send all day comes back first, each with why it matters, then today's calendar and what changed. It has its own writer and the same fact check, and repeats are discounted. Today's dry run: 161 words, 0 cut, $0.007. Text in `.scratch/daily-brief-v2.md`. To get it daily: add yourself to `DAILY_PLANNER_V2_USERS` in Render.
- **Disk:** 21 GB free after removing truly useless caches (stale build folders, orphaned Xcode data, npm download cache).
- **Disk was full** (119 MB left): I cleared 3.5 GB of my own build leftovers, so 3.2 GB is free. The disk is still essentially full; the rest is your data.
- **Daily brief, your direction:** you'll send links and notes all day, and the daily brief delivers them back first, each with why it matters. D1.1 (#97) added the repetition penalty so briefs don't go stale.
- **The weekly episode now runs on the new brain (W6.4, #96),** behind a per-person switch. Your end-to-end dry run: 6 items, 18/18 sentences passed the fact check, ~98 s, $0.016 before voice. To hear it: add yourself to `EPISODE_PLANNER_V2_USERS` in Render.
- **Review finding 10 fixed** (#95, migration 140): every review finding is now closed.
- **Your first episode from the new brain (W6.2, #93):** written from the plan and fact-checked sentence by sentence. 17 sentences, 0 cut, every section with its evidence, $0.01. Draft in `.scratch/episode-draft-v2.md` (private). **It's short (~90 s):** length and craft are next, in the experiment.
- **Fact check for the episode (W6.1, #92):** every sentence's claims about you are checked against the evidence. Figurative language is never checked, so the writing keeps its craft. Gate: **10/10**, every must-catch caught ("you feel ashamed", "Priya is your closest friend", an app's "you seem stressed"). About $0.001 per check.
- **Your next episode now has a plan (W5.2, #91):** a behaviour pattern leads, then what you've been watching, a goal with 7h this week, your step jump, an answer about you, and a second pattern. 31 more held back by the length cap. **Found on the way:** the first plan was six patterns and nothing else. Fixed so each lens (behaviour, change, goals, content) gets its turn.
- **Planner core (W5.1, #90):** calibrated first. The state of the art is select-then-write with diversity-aware selection; letting a model pick what matters to *you* loses to a trivial baseline, so the planner is deterministic. Gate 3/3. **People tabled** (your call): built, not applied.
- **People (W2, #87–#89):** the strict scorer passes all 12 test cases with 0 wrong links. **Correction:** your 555 people are 300 contacts, 211 people you write about and 8 calendar people, not "all from writing" as I said. The real gap: people you write about weren't connected to your contacts. 6 will link and 6 are held. **Nothing moves until you check them** (short list item 9).
- **Code review of everything merged tonight (#57–#84):** 12 findings. The big ones: reads silently stopped at 1,000 rows (6 places), the lineage walk failed on big patterns, and revived goals would re-expire the next day. All fixed (#85, backend #17), with regression tests.
- **Calibration pass, your process:** two detector thresholds were my picks, not research. Now sourced: sedentary means under 5,000 steps (Tudor-Locke), short sleep means under 7h (CDC/AASM) (#86). Everything else checked matches the state of the art ([approach-calibration.md](./approach-calibration.md)).
- **Said vs did (W4.3, #84):** each of your 3 goals beside what you did. One stands out: 7h this week on a goal with 0 in a usual week. Goal titles and links are in `.scratch/said-vs-did-review.txt` for your check. **Also fixed at the root:** the backend now reuses or revives a goal instead of adding a copy (NPRdoinglaundry#16).
- **Goals cleaned up (#82, your call):** your 31 "active" goals were 7 goals plus 24 copies. Now 3 are active, all mentioned in your recent writing; 4 expired (kept, revivable). The goal writer has made 115 goals for you over time, so it's next to fix.
- **Your four decisions (19 Oct):** strict people matching; merge + expire goals; one provisional why may be *asked* per episode; database changes 127, 130 and F1.4b approved. **All three applied:** 127 and 130 live; 137 re-weighted old evidence (none of your answers changed: none rested on automated mail); 138 (#81) means evidence is retired, never deleted.
- **Content lens (W4.4, #79):** your last 28 days hold 51 chosen items in 6 topic groups. Goal links by similarity were impossible (goal sentences and video titles never score close), so linking moves to W4.3. Your 31 goals contain 127 near-duplicate pairs.
- **What moved in your answers (W4.2, #78):** recomputed from the evidence, so only new evidence counts (fading isn't news). 19 moved since your last episode. Biggest: question 7 went 0.42 → 0.82.
- **One read contract (W4.1, #77):** everything the brain knows, in one read, each item marked *stated* or *asked* from counted confidence. **On you:** only 2 of 8 areas may be spoken about yet; 8 answers; 21 live patterns; 0 live whys; 31 "active" goals, all from June (two product calls for you, short list item 7).
- **Where your time went (W3.5, #74–#76):** 69 hours in your calendar over 120 days: meetings 18%, personal 16%, social 10%, travel 2%, unplaced 54%. Two fixes on the way: a model now places titles the rules can't (a fraction of a cent), and "free"-marked blocks now count as time spent (my mistake). Unplaced time needs your labels (short list item 6).
- **Time lens (W3.5, #74):** each calendar event gets a category. **Finding:** declared rules place only 38% of your booked hours (meetings 25%, social 13%), and the other 62% is unplaced. Your calendar also holds little time: about 10h this week, 3h in a usual week. Next: a model pass on unrecognised events.
- **Shifts from your normal (W3.4, #73):** this week against your previous four, per metric, only when it's both statistically real and a 25%+ move. Your week: **steps up ~95%** (median 5,006/day vs 2,566). Nothing else moved enough to say.
- **Trajectory (W3.3, #70–#72):** every pattern now carries weakening / holding / stronger / not enough to say, with the counts behind it. Gate: 10/12, 0 unsupported claims. **On your account it first said 8 patterns were getting stronger. All 8 were artifacts:** one uploaded conversation counted 10–20 times, and newly connected Gmail/YouTube/Calendar looked like a surge. Fixed (#72). Now all 72 honestly read "not enough to say". They become readable as sources pass 8 weeks connected (around mid-November).
- **Notion:** you'll feed it through the app as a real test; I won't process the export.
- **Patterns from records (W3.2, #69):** six declared detectors read your days. On your last 120 days: low-step days 2 → **11** (four weeks before vs last four), short recorded sleep 7, very active 5, late finishes 4, exercise 3. **Not written to your brain yet:** low steps might be a phone on a desk, so it's behind a switch until you check (short list item 5).
- **Daily summaries live (W3.1):** your last 120 days became 137 day-summaries, built in about a second at no model cost. **What it shows:** only 5 entries of your own writing in 4 months (most is from May), so your recent weeks are seen almost entirely through calendar, health and subscriptions. That's why the time and behaviour lenses have to work from records. Also found: YouTube likes carry the video's publish date, not when you liked it, so they're excluded from daily counts. Watch history needs a Takeout import (added to R1).
- **F3 done:** new material now raises an event in the database (live). A worker reads, then researches, once you've gone quiet for 2 minutes. It's behind a switch for you to flip in Render. `npm run events:report` measures it: today, 117 items from the last week are still unread because they arrived on paths that never call the agent.
- **Baseline set (F2.4):** 3 runs average **28.7/40**. It never took the automated guesses as fact (100% every run). **Time is weakest (38%, every run).** From now on a change only counts as an improvement if the 3-run average rises and "I don't know" stays at 100%. Recorded in [decision-record.md](./decision-record.md).
- **Goal research matrix done** ([goal-research-matrix.md](./goal-research-matrix.md)): all 25 goals now have an approach, the papers behind it, and a maturity rating (established / emerging / frontier). It adds six research-driven changes. The biggest: audio narrative beats print for behaviour change (podcast-first is right), and personality can't be reliably inferred from text, so appetite comes from behaviour and asking.
- **The brain's first exam** (fictional persona, $0.23): **26/40**. Facts 7/9 · connecting 4/8 · changes 5/7 · **time 3/8** · saying "I don't know" 7/8. Time fails because calendar facts lose their dates (fixed by W3.1). People fails because her manager is stored as "selfs_manager" (fixed by W2).
- **Honest gap you caught:** research was done by field, not goal by goal, and approaches weren't rated for maturity. A matrix for all 25 goals is now in progress.
- **F1 done.** Replay test merged (#60): playing the same material through the brain twice leaves it exactly as once.
- **Your note on disagreeing:** recorded one: "other updates" in the weekly episode only when tied to your patterns or goals ([podcast-behaviour-analysis.md](./podcast-behaviour-analysis.md)). Your call.
- **F1.4 merged (#59):** a test now blocks any code that deletes a claim. Found one existing case: re-deriving an answer drops evidence it no longer cites. The fix replaces a database function, so it **waits for your yes** (F1.4b).
- **Podcast approach:** Cook A/B/C are reworked, not replaced. A planner goes in front, and each pass maps to goals 11, 13, 14 and 15 ([podcast-behaviour-analysis.md](./podcast-behaviour-analysis.md)).
- **F1.2 lineage view merged (#57) and applied:** 2,636 links on your data. **F1.3 "how do you know that?" walk merged (#58).**
- **Wrote the step-by-step for the podcast's behavioural analysis:** 11 analyses, each with method, bar, test and PRs ([podcast-behaviour-analysis.md](./podcast-behaviour-analysis.md)).
- **F1.1 map done:** lineage already exists in four tables → F1 becomes an additive view; people tables already hold 940 entities → W2 starts by measuring them.
- **Fixed and merged:** trust levels weren't recorded for large batches (request too long) — #56.
- **Applied:** migrations 128 (daily brief table) and 129 (trust level).
- **Research:** 15 searches across 7 fields → 10 design changes ([research-foundations.md](./research-foundations.md)).

---

**Rules that apply at every level**
- **Dependency order** (the spec's): evidence before understanding before
  expression; weekly podcast first, then daily, then search, then the rest.
- **A chunk is done when its gate passes**, measured on the founder's test
  bank and fictional personas, with the bar declared before the code.
- **A PR is atomic** (process step 5): one commit-sized change, one gate that
  can fail, no product decision inside it, reviewable in one sitting. Every PR
  has tests.
- **Non-destructive:** new structures beside old ones; readers switched one at
  a time; old ones retired only when nothing reads them.
- **Built to extend:** every chunk leaves a seam for what the spec says comes
  later (e.g. the planner takes a policy, so daily and conversation reuse it;
  the registry takes frameworks as data, so goal 21 needs no rebuild).
- **Stop points (yours):** decision briefs and the audio check. Everything
  else runs without you.

---

## 1. Macro plan

| Phase | What it delivers | Goals moved | Chunks |
|---|---|---|---|
| **A. Foundations** | The structures everything stands on: claims with lineage and time, a brain-level evaluation, events | 2, 5, 20 (enables all) | F1, F2, F3 |
| **B. Evidence** | Trust levels; people | 1, 3, 4 | W1, W2 |
| **C. Understanding** | Patterns with trajectory; goals said-vs-did; one read contract | 7, 8, 10, 12, 25 | W3, W4 |
| **D. The weekly episode** | Planner, writer with registers and guard, voice, your audio check | 11, 13, 14, 15, 16 | W5, W6, W7 |
| **E. Daily, links, search** | Daily brief on the same planner; reference bank + Notion; search with receipts | 1, 6, 11, 23, 24 | D1, R1, S1 |
| **F. The companion** | Corrections end to end, lint in charge, calibration, hypotheses, conversation, learning, acting | 5, 9, 17, 18, 19, 20, 21, 22 | later, planned when E passes |

---

## 2. Chunks

| Chunk | Goals | Gate (declared now) | Depends on |
|---|---|---|---|
| **F1 Claims, lineage, time** — one claim reference + evidence edges + true-when/learned-when across facts, patterns, answers; invalidation, never deletion | 2, 5, 20 | Every derived claim walks to a source in ≤ 1 query; a contradicted fact is invalid, not gone; replay twice = once | — |
| **F2 Brain evaluation suite** — LongMemEval-style questions on test bank + personas: extraction, multi-session, updates, temporal, **abstention** | 10, 4, 6 | Suite runs in one command; baseline recorded; abstention measured (C2) | F1 for updates |
| **F3 Events** — "material arrived for this person" triggers reading and research, debounced; crons as the net | 2, 24 | New material read and researched within 10 min, no cron needed | — |
| **W1 Trust classes** *(in progress)* | 1, 3 | Gate W1 100%; 0 inner-life claims from non-own-words (fixtures + test bank) | — |
| **W2 People** — scored resolution, link / hold / separate, aliases, relationships; meetings and mail attach to people | 4, 22–26 | Gate W2: 0 wrong links, ≥ 80% true links, all ambiguous held | F1 |
| **W3 Patterns with trajectory** — daily aggregates (C8), consolidation facts → patterns (C1), two-window rate test | 25, 13, 14, 31 | Gate W3 ≥ 80%, 0 unsupported change claims | F1, W1 |
| **W4 Understanding read contract** — one read API over claims (answers, patterns, people, goals, said-vs-did) with confidence, status, edges | 7, 8, 10, 12 | Episode inputs 100% from the contract; old tables read by nothing in expression | F1, W2, W3 |
| **W5 Planner** — greedy submodular selection with stop (P5, C7), registers assigned from confidence (C4), flow policy (C5), phase (C6), BCT tags (C9), withholding ratio | 11, 13 | Gate W5 ≥ 80%; never pads; spine rate ≥ 80% on the founder's weeks | W4 |
| **W6 Writer + guard** — typed outline → script with registers; atomic-claim guard (C3); critic pass; **scaffolding experiment: heavy vs medium vs light writer, judged blind by you** | 13, 14 | Gate W6 ≥ 90%; factual precision ≥ 95%; 0 hypotheses as assertions | W5 |
| **W7 Voice + audio check** — produced voice, delivery; your listen | 15, 16 | **Your verdict: you'd listen voluntarily** (stop point) | W6 |
| **D1 Daily brief** on the planner, JITAI timing (C10) | 11, 13–16 | Your verdict on 7 briefs; spine rate ≥ 80% | W5, W6 |
| **R1 Reference bank + Notion** — collections by speaking them, intent notes, relevance edges; **YouTube watch history via Takeout import** (the API has none) | 23, 1 | 50 links findable by reason; 0 change answers about you | F1 |
| **S1 Search** — hybrid retrieval over claims + reference, answer with receipt, abstains | 6 | ≥ 80% correct with receipt; abstains when unknown (F2) | F1, F2, R1 |

---

## 3. Bites and PRs

Detailed for the chunks next in line; later chunks are broken down when they
start (the drift check decides whether the plan still holds).

### W1 Trust classes (in progress)
| PR | Bite | Gate | State |
|---|---|---|---|
| W1.1 | Classifier: five classes, inner-life rule | 15/15 fixtures | **done** (branch) |
| W1.2 | `raw_content.trust_class` (migration 129), stamped on read, Gmail labels + sender, backfill script | stamped correctly on a real DB | **done** (branch) |
| W1.3 | Fact extraction enforces it: from non-own-words, only behaviour predicates about the person (attended, scheduled, consumed…), never inner-life ones (felt, believes, wants…) | test bank: 0 inner-life facts from records/mail/automated | next |
| W1.4 | Evidence weight in the question store by trust class (new evidence kinds for automated + third party, low weight) | answers citing automated items can't exceed the bar alone | after W1.3 |
| W1.5 | Backfill on the founder's account (counts only), re-run research | answers that rested on automated items drop or hold | after W1.4 |

### F1 Claims, lineage, time *(revised after F1.1)*
| PR | Bite | Gate |
|---|---|---|
| F1.1 | Map every claim kind, its evidence and its time fields ([f1-claims-map.md](./f1-claims-map.md)) | ✅ done |
| F1.2 ✅ #57 | `claim_edges` **view** over the four existing evidence tables — one lineage graph, additive, no dual writes | every edge in the four tables appears once in the view (real DB test) |
| F1.3 ✅ #58 | `walkEvidence(claim)` — from any claim down to the source rows, through patterns and facts | answer → pattern → fact → raw content walked in tests |
| F1.4 ✅ #59 | "Invalidate, never delete": a checked rule — no code path deletes a claim; supersession and retirement keep the row | test + code scan finds no deletes of claims |
| F1.5 ✅ #60 | Replay test: reading the same rows twice leaves derived state unchanged | twice = once |

### F2 Brain evaluation suite
| PR | Bite | Gate |
|---|---|---|
| F2.1 | Question set format + 40 fictional-persona questions across the five abilities, including unanswerable ones | parses; each has an answer or "abstain" |
| F2.2 | Runner: asks the brain (answers + search later), scores per ability | one command; per-ability score |
| F2.3 | Founder test-bank questions (from your corrections) | your review |
| F2.4 | Baseline recorded in the decision record | numbers written down before W2 |

### F3 Events
| PR | Bite | Gate |
|---|---|---|
| F3.1 ✅ #63 | "Material arrived" event on every capture path (content route, device batches, syncs) | event per arrival, idempotent |
| F3.2 ✅ #64 | Debounced per-person trigger: read, then research | new material researched within 10 min |
| F3.3 ✅ #65 | Crons stay as the net; metric: items picked up by cron rather than event (should trend to 0) | measured |

### W2 People
| PR | Bite | Gate |
|---|---|---|
| W2.1 | Survey note: ER for personal data (Fellegi–Sunter fields, blocking, LLM tie-break) — done in survey; brief on thresholds | your sign-off on link/hold bands |
| W2.2 | `people` + `person_aliases` + `person_links` (migration, additive) | schema on a real DB |
| W2.3 | Mention extraction: names, emails, attendees from facts, calendar, mail | all mentions captured on fixtures |
| W2.4 | Scorer: field weights, blocking, three bands; held queue | Gate W2 on fixtures |
| W2.5 | Relationships: co-occurrence counts over time (met, emailed, mentioned) | correct counts on fixtures |
| W2.6 | Backfill on founder data (counts only) + held-queue review flow | 0 wrong links in your review |

### W4 Understanding read contract *(broken down 19 Oct)*
Today the episode reads none of the new brain (findings #26). W4 gives it one door.
| PR | Bite | Gate |
|---|---|---|
| W4.1 | `readUnderstanding(user)`: one typed read of answers (36 questions), live patterns with trajectory, whys (asked only), stated goals, this week's shifts and time. Every item has claim ref, confidence, status and evidence count | returns every live claim for a persona; each walks to a source (F1.3) |
| W4.2 | Answer moves: confidence change since the last episode, and the evidence that moved it | correct moves on a fixture history |
| W4.3 | Said vs did: each active stated goal beside time spent and matching patterns, as two numbers | fixture cases; your review of 5 goals |
| W4.4 | Content groups: what you saved, subscribed to and read this week, grouped by topic and tied to goals (never a claim about feelings) | fixture groups; 0 feeling claims |
| W4.5 | Route: `GET /understanding/:user` behind the agent key, for the planner, the dashboard and the app | contract test; no raw content in the response |

### R1 Reference bank *(calibrated 20 Oct)*
| PR | Bite | Gate |
|---|---|---|
| R1.1 | Link capture: every link you send becomes a reference item with your note as its reason (migration 142) | all links in fixtures captured with their reason; your note stays your words, the page doesn't |
| R1.2 | Enrichment: safe page fetch (no private addresses, size/time limits), title, summary, topics from a fixed list | fixture pages enriched; unsafe URLs refused |
| R1.2b | Read more kinds of link: **YouTube via its transcript**, long pages in full (sections), then PDFs; JS-only/paywalled pages marked "saved, not read" | fixture video and long page understood |
| R1.3 | Relevance: each item linked to goals and questions it bears on (judged, "none" allowed) | fixture links tied correctly |
| R1.4 | Remind: the daily brief brings a saved item back when it bears on today | an item resurfaces on a relevant day, not on others |
| R1.5 | Gate: 50 fixture links findable by reason (with S1); 0 answers changed by them | goal 23 |

### S1 Search *(calibrated: research matrix, goal 6)*
| PR | Bite | Gate |
|---|---|---|
| S1.1 | Hybrid retrieval over your items, claims and saved links: keyword rank + meaning, fused (reciprocal rank fusion) | known items found in the top 5 on fixtures |
| S1.2 | **Your shape (20 Oct):** a written synthesis on top ("here's what we found"), the sources below with date and kind, each openable to its full content. Query rewriting so natural questions find things; cites every claim; **abstains** in plain words; claim guard | ≥ 80% correct with receipt; abstains on unanswerable (F2 questions) |
| S1.2b | Search route for the app: `GET /search?q=` returns the synthesis + sources | contract test; one person only |
| S1.3 | Gates: F2 persona questions through search; R1.5's 50 links findable by reason | goal 6 and goal 23 |

### W3–W5 behavioural analysis
Step by step in [podcast-behaviour-analysis.md](./podcast-behaviour-analysis.md).

### W6 Writer + guard *(broken down 20 Oct; research pass pending network)*
| PR | Bite | Gate |
|---|---|---|
| W6.0 | Calibration note: state of the art in fact-checking long generation (atomic-claim verifiers 2025–26) and plan-to-script writing | written before code |
| W6.1 | Atomic-claim guard: split each script sentence into claims; each must match a plan item's facts or be in the asked register | gate W6 (10 cases, #54) ≥ 90%; every `must_catch` caught |
| W6.2 | Writer v2 from the plan: Cook A outline from plan items, Cook B enrich only from plan evidence, Cook C script in two registers | 100% of sections carry evidence (goal 13) |
| W6.3 | Scaffolding experiment: heavy / medium / light writers on the same plan | your blind ranking + guard pass rate |
| W6.4 | Switch: `EPISODE_PLANNER=v2` per person, old path kept as comparison | your first v2 episode |

### W7
Broken into PRs when it starts (voice, and your listen as the stop point).

### D1 Daily brief on the planner *(broken down 20 Oct; calibrated in approach-calibration.md)*
| PR | Bite | Gate |
|---|---|---|
| D1.1 | Planner policy (weekly / daily) + repetition penalty for items said in the last 3 briefs | a repeated item loses to a fresh one of equal strength; daily cap 4 + 1 aside |
| D1.2 | Daily candidates: **what you sent since the last brief (first, protected, each with its why)**, then today's calendar, moved since yesterday, saved/followed yesterday, today's shifts | everything you sent appears; quiet day with nothing sent → nothing selected |
| D1.3 | Daily writer prompt (latitude for a through-line) + claim guard | guard pass on 7 briefs; your verdict |
| D1.4 | Switch: `DAILY_PLANNER=v2` per person | your verdict on 7 briefs (spec gate) |, following the same pattern: survey note (if
needed) → schema (additive) → pure core judged by the gate fixtures → wiring →
founder-data run (counts only) → gate.

---

## 4. Order of work from here

1. Finish **W1** (W1.3–W1.5) — in flight, small, already gated.
2. **F1** and **F2** together — the foundations every later gate needs.
3. **F3**, then **W2 → W3 → W4 → W5 → W6 → W7** (audio check: stop point).
4. Then **D1 → R1 → S1**, then phase F.

Each step reports: chunk · gate result · spend (user vs test) · drift check.
