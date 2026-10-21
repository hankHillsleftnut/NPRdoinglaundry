# Behavioural analysis for the weekly episode — step by step

19 October 2026. Every analysis the weekly episode needs, in the order the
data flows, each with its method, the bar it must clear, its test, and its PRs.
Expands chunks W2–W5 of the [build plan](./build-plan.md). Sources: goals 7, 8,
10, 12, 13, 22, 25 in the [goal spec](./goal-specs.md); methods from the
[research foundations](./research-foundations.md).

## TL;DR

**This is the hyperpersonalisation (founder, 19 Oct).** The episode's insight
comes from three lenses on the person, with everything else in service of them:

- **Behaviour:** what you do and how it's changing (analyses 3–6, 11).
- **Content:** what you watch, read, listen to and save (analysis 10).
- **Time:** where your hours actually go (analysis 12, and said-versus-did, 8).

Each lens is read against your goals and the 36 questions. That is the context
the episode is written from.


Twelve analyses, in five steps:

1. **Clean the input:** trust levels, then daily summaries.
2. **Find the behaviour:** facts, then patterns.
3. **Measure change:** each pattern's trajectory, shifts against your own baseline, what moved in your answers.
4. **Put it against your life:** said versus did, people, content you've seen, what's in the way.
5. **Choose:** the planner picks the few worth saying and withholds the rest.

Three already exist, one is in progress, and eight are new.

Every analysis outputs a **claim** with a confidence, a status and lineage. Nothing reaches the script unless it can be traced to a source (F1.3).

---

## The eleven analyses

| # | Analysis | What it answers in the episode | Input | Method | Bar to say it | State |
|---|---|---|---|---|---|---|
| 1 | **Trust levels** | (none directly) Stops a newsletter or another AI's guess becoming "you feel…" | every item | rules by source and sender (W1) | n/a | ✅ built (#55) |
| 2 | **Daily summaries** | "You slept under 6 hours four nights" | calendar, health, screen time, YouTube, mail counts | roll records into one row per day per domain (C8): counts, durations, first/last times | ≥ 1 record that day | new (W3.1) |
| 3 | **Facts from your words** | the raw material for patterns | journals, voice, notes | extraction + span check + trust rules | quote verified in the text | ✅ built |
| 4 | **Patterns** | "You skip standup when the week is heavy" | facts (3) + daily summaries (2) | cluster by grouping key; promoter bar | ≥ 3 instances, weighted ≥ 2.0, on different days | ✅ built for facts · new for records (W3.2) |
| 5 | **Trajectory** | "Twice this month, five times last" · "it got worse" | a pattern's instances over time | two-window Poisson rate test (28 + 28 days), same bar as existence (goal 25) | significant at the declared level, else "not enough to say" | new (W3.3) · test cases ✅ (#54) |
| 6 | **Shifts from your baseline** | "Your screen time doubled this week" | daily summaries (2) | this week against your own 4-week baseline; counts → rate test, durations → median difference with ≥ 4 days each side | outside your normal range, enough days | new (W3.4) |
| 7 | **What moved in your answers** | "I'm surer now that money is what's weighing on you" | the 36 answers' confidence history | change in confidence since last episode; new evidence that moved it | a move of ≥ 0.15, or a new answer | partly built (store exists) · new delta (W4.2) |
| 8 | **Said versus did** | "You said fundraising; 3 of 40 hours went to it" | stated goals (goal 7) against time spent: calendar, content, patterns | match each goal to time and behaviour; two numbers side by side, never merged | the goal is active and ≥ 1 week of records | new (W4.3) |
| 9 | **People** | "You saw Priya twice; you haven't seen your brother since August" | calendar attendees, mail, mentions | Fellegi–Sunter matching; link / hold / separate; time-together counts with trajectory (5) | 0 wrong links; uncertain matches held | new (W2) · test cases ✅ |
| 10 | **Content you've seen** | "Most of what you watched was about fundraising; one thread was about leaving" | YouTube, reading, saves | topic groups by week; overlap with your goals; record only, never a claim about feelings | ≥ 3 items in a group | new (W4.4) |
| 12 | **Where your time went** | "Meetings took 22 hours; deep work 6; YouTube 9, mostly after 11pm" | calendar (by kind of event), screen time (by app category), content time (YouTube durations), from daily summaries (2) | weekly hours per category, against your 4-week baseline (6) and your stated goals (8) | ≥ 4 days of records that week | new (W3.5) |
| 11 | **What's in the way** | "Is it the mornings, rather than the gym?" (asked, not stated) | a live pattern + its facts | why gate (exists); outside causes considered first; asked, never asserted (goal 12) | pattern live + why gate passed | ✅ why gate built · question form at W6 |

**Then the planner (W5)** takes candidates from all of these. It picks a spine
(the one thing most worth saying) and adds distinct items in order of strength
and recency, stopping when the next one isn't worth saying. Each item gets a
register from its confidence: **stated** for facts and patterns with
trajectory, **asked** for whys and hypotheses, and **asked whenever confidence is
borderline** (self-generated insight outperforms being told, R3). It records what it left out and
why. Its pass/fail cases already exist (#54).

**Known limit on the content lens (found 19 Oct):** YouTube's API gives
subscriptions (dated), playlists and liked videos. A liked video carries the
video's *publish* date, not when it was liked, and **watch history isn't
available through the API at all**. So "what you watched this week" and "up
till 2am watching" need a **Google Takeout watch-history import** (an
archive importer already exists; YouTube history becomes one of its formats,
planned in R1). Until then, content analysis uses subscriptions, saves,
reading and Docs, and never dates a like.

**What is deliberately not analysed for the first podcast:**
- Hypotheses about what you "really" want: goal 21's three gates, phase F.
- Appetite calibration (goal 22): safe default until there's evidence.
- Suggesting actions: the research warns against it (goal 25).

---

## The order, and why

The data flows 1 → 2 → 4 → 5/6 → 8 → planner.

- Trajectory (5) is the success condition (goal 25) and the episode's backbone.
- Daily summaries (2) come first because 4–6 and 8 read them.
- People (9) and content (10) feed items, not the spine, so they can come later.

| Step | PRs | Pass/fail test (declared before code) |
|---|---|---|
| **W3.1 Daily summaries** | (a) `daily_summaries` table, additive · (b) roll-up per domain from records · (c) backfill your data, counts only | sums equal the source rows on test data; no item counted twice |
| **W3.2 Patterns from records** | promoter reads daily summaries as instances (e.g. "past 1am" nights), as well as facts | a record pattern is promoted on test data; facts-only patterns are unchanged |
| **W3.3 Trajectory** | (a) pure rate test · (b) stored on each pattern, with the counts it rests on · (c) run on your patterns | W3 cases ≥ 80%, **0 change claims without support**; trajectory always traceable to counts |
| **W3.4 Baseline shifts** | pure test over daily summaries; outputs candidates | made-up weeks: a real shift is found, a normal week finds none |
| **W3.5 Time allocation** | (a) one category map for events, apps and content · (b) weekly hours per category · (c) your week, counts only | hours add up to the source durations; nothing counted in two categories |
| **W4.1 Read contract** | one read of every claim with confidence, status and lineage | episode inputs 100% from the contract |
| **W4.2 Answer moves** | confidence history and change since the last episode | correct changes on test data |
| **W4.3 Said vs did** | goal ↔ time matching; two numbers, never merged | made-up cases; your review of 5 goals |
| **W4.4 Content groups** | weekly topic groups from what you've seen, linked to goals | groups match on test data; 0 claims about feelings |
| **W2 People** | as in the build plan (stop point: your sign-off on the link/hold thresholds) | 0 wrong links, ≥ 80% true links |
| **W5 Planner** | selection, registers, withheld list | W5 cases ≥ 80%; never pads |

**Founder checks:**
- after W3.3: are your patterns' trajectories right?
- after W3.5: does the time breakdown match your week?
- after W4.3: is said-versus-did fair?
- at W7: would you listen?

---

## How this reaches the podcast: Cook A, B and C are reworked, not replaced

**What each pass must produce is already defined by the goal spec:** goal 11
(relevance), 13 (outline), 14 (story), 15 (voice), 16 (delivery). The spec is
the source of truth. This table only maps each goal to the pass that meets it.

The podcast is already made in three passes (`src/pipelines/podcast.ts`).
Today each pass reads loose context and decides by prompt what's worth saying.
The plan keeps the passes and moves the deciding in front of them:

| Pass | Today | After W5–W6 |
|---|---|---|
| **Planner** *(new, W5)* · goal 11 | n/a | picks the spine and items from the twelve analyses; assigns stated / asked; records what it withheld and why |
| **Cook A** (outline) · goal 13 | outline from loose context | turns the plan into a typed outline, with evidence on every section (goal 13) |
| **Cook B** (enrich) · goals 11, 14 | agent enriches freely | enriches only from the plan's evidence and the reference bank; adds nothing about the person that isn't in the plan |
| **Cook C** (script) · goal 14 | writes the transcript | writes in two registers (stated for facts and patterns, asked for whys); same voice and craft |
| **Guard** *(exists, unused; W6)* · goal 14 | n/a | checks each sentence against its evidence; an unsupported sentence is cut or turned into a question |

So the three lenses (behaviour, content, time) decide **what** the episode
says, and Cook A–C decide **how** it's said. Each change ships behind a switch,
with today's episode kept as the comparison until your audio check (W7).

---

## What the episode is, and how much scaffolding the writing needs

**Founder, 19 Oct:** highly engaging, narrative audio that combines the content
they pay attention to, behavioural analysis, other updates and tracking, and
surfaces real insight. Like a therapist, coach, mentor, researcher and
assistant in one. How much scaffolding the writing needs is a delivery
question, to be tested rather than assumed.

**Where the goal spec already says this:**

| What you said | In the spec |
|---|---|
| Highly engaging, well written | "Conservative about claims, never about craft": careful about what's claimed, captivating in how it's written; the guard must never flatten the prose. Goal 14: sounds like a person, not a template. |
| Behavioural analysis, tracking | Weekly = "behaviour patterns, performance against goals, reflection"; goals 7, 8, 12, 25 |
| Coach | Goal 22: "soothing" and "catch them on their bullshit" at once is "a description of a good coach" |
| Researcher | Goal 11, plus the ambient researcher (decision, 18 Oct) |
| Assistant | Mission ("handles the boring admin"), goal 17 |
| Therapist | Deliberately bounded: no diagnosis or named pathology ("On the clinical question", goal 21). It can be therapeutic in manner, never clinical in claim. |
| Insight that's surfaced, not prescribed | IKEA effect: it asks, so the person draws the conclusion |

**What the spec doesn't yet say (your call to add it to the spec):**
1. **Content they pay attention to belongs in the weekly episode.** The spec's
   table says the weekly reads the self bank and the daily reads the reference
   bank. What they watched or read is behaviour (self bank), so it fits. "Other
   updates" (research brought in for them) is reference bank, which the spec
   currently gives to the daily only.
   **My recommendation (disagreeing in part):** content they consumed goes in
   freely, because it's behaviour. Brought-in research goes in only when the
   planner ties it to one of their patterns or goals, never as general
   updates. The weekly fails by being wrong about them, and a digest dilutes
   the thread. Yours to accept or overrule.
2. **Narrative.** Goal 14 says "engaging story", but nothing about structure:
   an arc that weaves the three lenses into one thread rather than a list of
   items.
3. **Mentor** isn't named. Closest is goal 22's coach.
4. **Scaffolding is an experiment, not a decision.** The spec fixes the
   outline as "typed, not freeform" (goal 13). It doesn't say how much the
   writing pass should be steered.

**The scaffolding experiment (added to W6).** Same week, same plan, same
guard. Three writers:
- **Heavy:** typed outline, section by section (today's Cook A → C).
- **Medium:** plan + evidence + a narrative brief; one strong writing pass.
- **Light:** plan + evidence only; the model chooses the shape.

Each is judged on:
- **claims:** fabricated = 0, hypotheses stated as fact = 0, guard pass rate;
- **craft:** your blind listen, ranked, plus "that's not me" count, plus **were you absorbed** (narrative transportation is the mechanism by which stories change behaviour, R1 in the [research matrix](./goal-research-matrix.md));
- **cost and time.**

The winner becomes the default. The guard's numbers decide whether a looser
writer is safe. Your ear decides which is better.
