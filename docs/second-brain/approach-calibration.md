# Approach calibration — every approach, checked the founder's way

19 October 2026. **The process (founder, standing rule):**
1. state of the art;
2. goal spec;
3. which solution achieves the spec best;
4. pick the most robust, then build.

Every PR is code-reviewed before merge. This file records the calibration for
each approach, including a retroactive pass over what was built before the rule.

## Built before the rule: retroactive check

| Approach | State of the art | Spec need | Verdict |
|---|---|---|---|
| Lineage as edges + walk (F1) | Bi-temporal graphs, invalidate-not-delete (Zep/Graphiti) | Goals 5, 20: trace every claim | ✅ matches |
| Brain exam (F2) | LongMemEval's five abilities incl. abstention | Goal 10: knows what it doesn't know | ✅ matches |
| Arrival events (F3) | Transactional outbox | Goal 2: never wonder if it made it in | ✅ matches |
| Trust classes (W1) | Contextual integrity; source reliability | Goals 1, 3 | ✅ matches |
| Detector thresholds (W3.2) | Tudor-Locke step zones; CDC/AASM 7 h sleep; WHO 150 min | Goal 25: claims as careful as existence | **❌ were picked, not sourced. Fixed (#86): sedentary 3k → 5k, short sleep 6h → 7h** |
| Trajectory (W3.3) | Exact conditional test for two Poisson rates (recommended for small counts); BOCPD as the upgrade | Goal 25 | ✅ matches; BOCPD later (R6) |
| Shifts from normal (W3.4) | Rank tests for small samples (no distribution assumed) | Goal 25 / analysis 6 | ✅ reasonable; no direct benchmark |
| Calendar categories (W3.5) | No benchmark exists; practice moved from rules to a small model with a human in charge | Time lens | ✅ matches; accuracy unmeasured until you label events |
| Read contract, registers (W4.1) | Confidence counted, not verbalised (models' stated confidence is miscalibrated) | Goal 14: two registers | ✅ matches (C4) |
| Content groups (W4.4) | BERTopic/HDBSCAN marks most short texts outliers; agglomerative is the advised fallback for small sets | Content lens | ✅ matches |
| Said vs did (W4.3) | Model-judged relevance (similarity can't cross text types, measured) | Goal 8 | ✅ reasonable; your review is the gate |
| Goal lifecycle | Goal disengagement is adaptive; implementation-intention research | Goal 7 | ✅ matches |

## Ahead: calibrated before the first PR

- **W2 people:** Fellegi–Sunter record linkage with blocking, plus a model tie-break inside the hold band only. Strict (your call). ✅ calibrated (research foundations §3).
- **W5 planner: calibrated 20 Oct.**
  - *State of the art:* select-then-write with **DPP selection over atomic key points, with user-intent relevance in the kernel** ([Padmakumar et al., ACL 2025](https://preview.aclanthology.org/setup/2025.acl-long.1445)); submodular coverage plus diversity under a budget ([Lin & Bilmes 2011](https://aclweb.org/mirror/acl2011/accepted/640.html)).
  - *Warning:* zero-shot LLM selection recovers personal relevance worse than a trivial baseline ([2606.10398](https://arxiv.org/pdf/2606.10398)).
  - *Reflection* must be prompted, not assumed ([Kocielnik 2018](https://faculty.washington.edu/garyhs/docs/kocielnik-UBICOMP2018-reflection.pdf)).
  - *Spec:* goal 11 (worth attention, never padding), goal 13 (spine from live patterns and facts), goal 14 (registers), your one-asked-why rule.
  - **Pick:** deterministic DPP-style greedy selection. Quality = evidence strength × (moved, goal-linked); similarity = shared topic or duplicate claim; stop when the next item's marginal value is under the bar or the length cap is reached; one reflection question (asked). No model chooses what matters.
- **W6 writer: calibrated 20 Oct.**
  - *State of the art:* claim-vs-grounding checking with small models, matching GPT-4 at ~1/400 of the cost ([MiniCheck, EMNLP 2024](https://arxiv.org/pdf/2404.10774)); extracting only **verifiable** claims, skipping subjective and figurative language ([VeriScore](https://papers.lunadong.com/paper/4448)); LLM verbal hedging is systematically overconfident ([2507.06306](https://arxiv.org/abs/2507.06306v2), [2605.28778](https://papers.cool/arxiv/2605.28778)).
  - *Spec:* goal 14 (claims only from evidence, two registers never blurred, 0 hypotheses as assertions); "conservative about claims, never about craft".
  - **Pick:** two-stage guard. (1) Extract only verifiable claims about the person (craft is never checked). (2) Check each against the plan's facts with a small model. Unsupported → cut or turned into a question; asked items must read as questions. The writer never chooses its own hedging; the planner assigns registers. Scaffolding level decided by the W6.3 experiment, not assumed.

- **D1 daily brief: calibrated 20 Oct.**
  - *State of the art:* daily prompts work best tailored to time and day, and their effect decays over weeks (micro-randomised trials: [VALENTINE 2024](https://www.hcplive.com/view/periodic-text-messages-can-improve-daily-activity-during-cardiac-rehab), [HeartSteps](https://ar5iv.arxiv.org/html/2007.13741)).
  - *Novelty decay:* engagement with daily AI agents drops once output patterns recur ([2509.24073](https://arxiv.org/pdf/2509.24073)).
  - *Trust:* users easily distrust plausible but wrong plans ([CHI 2025](https://arxiv.org/abs/2502.01390)).
  - *Spec:* daily fails by being boring, reads the reference bank, short when quiet, never shares the weekly's prompt or gate.
  - **Founder, 20 Oct:** *"I'm going to send you links and information constantly, and you can deliver it to me in a daily cadence."* So what they sent since the last brief is the brief's first, protected part, each item with why it matters.
  - **Pick:** the same selection core with a daily policy. Candidates: **what you sent since the last brief (always first)**, today's calendar, moved since yesterday, saved yesterday, today's shifts, one researched item. **Repetition penalty for anything in the last 3 briefs**; ≤ 4 items + 1 aside; its own writing prompt; the claim guard on claims about the person only (framing untouched).

- **R1 reference bank: calibrated 20 Oct.**
  - *State of the art:* re-finding happens mostly through search and reminders, not browsing what was kept, and a reminding function matters ([Microsoft Research, Keeping Found Things Found](https://www.microsoft.com/en-us/research/?p=274701)); read-later lists become graveyards ([1](https://memx.app/blog/read-it-later-list-graveyard/), [2](https://contextbolt.com/glossary/read-it-later/)). Production: fetch on save, LLM summary, tags constrained to a fixed vocabulary ([Karakeep](https://docs.karakeep.app/)).
  - *Spec (goal 23):* 50 links findable by your reason; none change what it thinks of you (trust class 'reference', W1).
  - **Pick:** capture the reason with the link (your note is the intent) → enrich on arrival (safe fetch, title, summary, topics from a fixed vocabulary) → relevance edges to goals and questions → find by reason (S1) → **remind** in the daily brief when it bears on today.

## W7 — Voice and emotional delivery (research only, 20 October 2026; nothing built)

**Asked by the founder:** episodes must sound emotionally well tuned (emphasis, tone, idiosyncrasies) and match how the person will feel hearing each part: excited, mourning, sober, inquisitive. Research before building.

**1. State of the art**
- **Eleven v4** (`eleven_v4`, launched 28 Sep 2026; `eleven_v4_turbo` is for live agents). It is ElevenLabs' most emotive model and is directed by inline **audio tags** ([sighs], [curious], [softly]) plus punctuation. There is no SSML. ElevenLabs says tag-following is "not perfect yet". [Docs](https://elevenlabs.io/docs/overview/capabilities/text-to-speech/eleven-v4)
- **The model reads emotion from the words themselves:** well-written text performs correctly without tags, and tags are for emphasis. Use **one emotion per phrase**, since contrasting directions reduce accuracy. Generate whole paragraphs, not single lines, because context improves delivery. If a line doesn't land, swap the tag rather than rewriting the line. [ElevenLabs blog](https://elevenlabs.io/blog/emotional-text-to-speech-with-eleven-v4)
- **The voice matters most;** a tag that fights the voice's character fails. Lower stability gives more expressive, more varied delivery, so audition several takes. [Prompting guide](https://elevenlabs.io/docs/best-practices/prompting)
- **Price (third-party, needs confirming on our plan):** v4 about $0.08 per 1,000 characters against our current ~$0.30 on v3. If that's right, voice cost falls by about 70%. [usagepricing](https://www.usagepricing.com/blueprint/activity/elevenlabs-2026-10-05-v4-launch-tts-price-cut)
- **Research:** having a model plan the emotion of a script before speech generation is an active area (the CoT-TTS challenge, arXiv 2606.21933; emotion-labelled script generation, Springer 2025). No study yet shows it beats well-written plain text for listeners, so this is unproven.
- **Empathy research:** what most predicts that a listener feels understood is **matching their intensity**, more than pitch or pace (therapist prosodic entrainment, arXiv 2310.14181). A good coach meets you where you are, then stays the steady one; they don't amplify distress.

**2. Against the goal spec:** the episode must feel like a therapist, coach, mentor and researcher, never perform a feeling the evidence doesn't support (goal 4: never claim beyond evidence), and be something you'd replay.

**3. Best fit: "emotional direction" as its own planned step, not left to the writer's whims**
- Each beat of the typed outline gets an **affect**: what this lands like *for you* (a win, a setback, a loss, an open question, routine), and the **register** to deliver it in. There are five, kept small:
  - *warm-bright* (wins);
  - *steady-sober* (hard truths, said-vs-did gaps);
  - *gentle* (loss, low weeks);
  - *curious* (asked whys, open patterns);
  - *plain* (summaries of what you watched or read).
- The affect is derived from evidence (the lens, the direction of change, your recent state). It is never more intense than the evidence. Rule: **meet the feeling, then steady it.**
- The writer writes for that register first, in word choice, sentence length and pauses, because v4 reads emotion from the text. **Then a small tagging pass** adds at most one tag per beat opening and the rare mid-line cue ([pause], [softly], [warmly]).
- A check runs before audio: only allowed tags, a cap on how many, no clashing directions within a phrase, and the register matches the beat's affect.

**4. Most robust, to be tested before adopting:** a blind A/B on the same script, (a) plain text on v4 against (b) directed text on v4, graded by the founder on "did the tone fit how it felt to hear it?". Also a voice audition (2–3 voices at 2 stability settings). **Ship only what wins.**

## 2026 recency check (20 October 2026, prompted by the founder)

The founder rightly flagged that several sources behind earlier decisions were from 2022–2024. I re-checked the four main decisions against 2026 work.

| Decision | 2026 evidence | Verdict |
|---|---|---|
| Brain: claims with source, true-when / learned-when, invalidate don't delete; hybrid search | **SodaMem** (Aug 2026, [2608.08055](https://arxiv.org/abs/2608.08055)): typed facts with mandatory provenance, three times per fact (mentioned, occurred, valid), SUPERSEDES/UPDATES edges, hybrid word and meaning search. Reports 92.8% on LongMemEval-S. **Memora** (ACL 2026 Findings, [2604.20006](https://arxiv.org/abs/2604.20006)) and **According to Me** ([2603.01990](https://arxiv.org/html/2603.01990)) test updates and evidence from mixed sources like ours. | **Confirmed.** Same shape as F1 and S1. |
| Search answers: one rewrite, then one reading | SodaMem uses a **planner–reader loop**: the reader keeps asking for more evidence until it can cite an answer, then writes. | **Upgrade.** This is the likely fix for our weak spot (counting and time questions that need several notes). |
| Episode: plan first, then write, then check every claim | **PodBench** (ACL 2026, [2601.14903](https://aclanthology.org/2026.acl-long.2019/)): explicit reasoning helps long inputs and multiple speakers, and following instructions doesn't guarantee substance. MoonCast: a briefing document first beats writing straight from sources. **Faithfulness of podcasts** (Jul 2026, [2607.21961](https://arxiv.org/abs/2607.21961)): even top models add ungrounded content; a turn-level judge plus **catch-and-repair** fixes it while keeping the flow. | **Confirmed, with one upgrade:** repair unsupported sentences instead of cutting them, so the story keeps flowing. |
| Voice: emotional direction, judged by ear | 2026 emotional speech work (EmoTra-TTS, [2608.23791](https://arxiv.org/abs/2608.23791)) is inside the speech model, which we can't change on ElevenLabs. **No 2026 study measures listener empathy.** ElevenLabs v4 (Sep 2026) is the current tool. | **Unchanged:** the blind A/B by your ear is the only real test. |

Nothing found in 2026 argues for going back to a free-roaming multi-agent chain (old Cook B) for claims about a person; the faithfulness paper is evidence against it.

## Goal 20 — Correction that sticks (phase F, first chunk; 20 October 2026)

**The spec:**
- Correct it in plain words, without a settings screen.
- The correction reaches the claim, everything built on it, and the portrait slot that showed it.
- A rejected claim is never resurrected.
- It asks before overwriting something you said yourself.

The metric: resurrections 0, repeated corrections 0.

**1. State of the art**
- **Bleeding edge:** belief revision with user corrections in LLM memory (2026, [2609.26035](https://arxiv.org/pdf/2609.26035)), and memory-staleness work (STALE/CUPMem). These are preprints. Their consistent finding is that corrections stored as *more text* get overridden by older memories, so the correction has to change the structure.
- **Knowledge-editing work** (RippleEdits, 2023 onward) shows that a fact edited inside a model rarely propagates to what depends on it. That's evidence against relying on a model to propagate a correction.
- **Ironclad and decades old:** **truth maintenance systems** (Doyle 1979, the justification-based TMS). Every belief records its justifications. When a premise is retracted, every belief whose support *all* runs through it is retracted, and beliefs with independent support survive. It is deterministic, explainable and well understood.

**2. Against the spec:** propagation plus "survives if independently supported" is exactly TMS. "Never resurrected" needs a block at write time, not a filter at read time.

**3. Best fit, and what we ship**
- **Retraction:** our `claim_edges` view already *is* the justification graph (F1). A correction retires the claim, then walks **upward** to its dependents. A dependent retires only if all its support ran through retired claims; otherwise its confidence is recomputed from what remains (answers already do this). Code only, no model.
- **Never resurrected:** a **rejection record** keyed on what was claimed (predicate plus normalised object, or the answer's question plus stance), checked in the database where facts and answers are written. A later re-extraction is refused and logged.
- **Your own words win, but get asked about:** if the correction contradicts something you yourself said, it's held as one question ("You wrote X in June. Has that changed?") instead of silently overwriting.
- **Plain words:** a model only *proposes* which claim you mean (top 3, with lineage). Applying the correction is deterministic, and it echoes back what it will stop saying. Until conversation (goal 18) exists, corrections come from replying to an episode, brief or search answer, or from a sent message starting "that's wrong".

**Gate F-C (declared before code):** in fixtures:
- 100% of dependents with no other support retire;
- 100% of independently supported dependents survive, with lower confidence;
- **0 resurrections** across a full re-ingest of the same material;
- every conflict with your own words is held, never overwritten;
- the right claim is targeted in ≥ 90% of 20 plain-language corrections;
- 0 rejected claims reachable by the episode, brief or search after correction.

## Goals 22 and 9: appetite and style (phase F, F-S; 20 October 2026)

**The spec:**
- Appetite starts low and is earned upward; it drops on any discomfort; stated always outranks inferred.
- It's a current reading, not a trait; visible, overridable and explainable.
- Style is "warmth in the delivery, precision in the content", with no empathy it can't ground in something you said.

**1. State of the art (the spec's research task)**
- **The Feedback Orientation Scale** (Linderbaum & Levy 2010) is the validated measure of receptiveness to feedback (20 items, 4 factors; short forms exist; validated again in 2025). But in a leadership study it **didn't predict coaches' ratings of openness or defensiveness** (Braddy et al. 2013). Self-report is useful, and it isn't the whole story.
- **2026:** personality-adaptive AI coaching helped some users and had no effect where readiness was missing ([2604.00464](https://arxiv.org/pdf/2604.00464)). Inferring traits from text is still only moderate (r 0.38–0.58, matrix goal 22).
- **Motivational interviewing's posture** (ask before telling, reflect before advising) is well established; whether matching to stage of change improves outcomes is mixed.

**2. Most robust, so shipped:** a transparent **ladder**, not a score.
- **0** "Just what happened": facts, patterns, said-vs-did as two numbers. *The default for new users.*
- **1** "Gentle questions": plus one asked why.
- **2** "Honest observations": plus gaps framed as tension, and hypotheses as questions (goal 21).
- **3** "Don't hold back": plus direct challenge, still only from evidence.

**How the level is set:**
- **Stated** (one direct choice in settings) always wins.
- **Inferred** is rules on behaviour:
  - It rises one step only after **2 engagement signals in 14 days** (they confirmed or answered an asked item) and no discomfort.
  - It **drops one step on any discomfort signal in the last 7 days**: rejecting an asked item, or a low episode rating.
- Every reading stores its reasons. No model and no opaque score.

**Style (goal 9) now:** a deterministic check in the writer for therapeutic-generic phrases and empathy not grounded in the person's words. Bounded style matching belongs with conversation (F-V).

**Disagreement recorded, founder's call:** the spec's default (level 0) would remove the one provisional why per episode you approved on 19 October. So the planner gate ships **off** (`ENABLE_APPETITE`) until you either set your own level or say to apply the spec default.

## Goal 21: Hypotheses (phase F, F-H; 20 October 2026)

**The spec, as non-dials:**
- asked, never asserted;
- audibly different from a fact;
- passes three gates (critical mass in the domain, a named framework, appetite);
- names its framework on request;
- **never clinical**;
- costs one word to reject;
- expires;
- never becomes a fact by repetition.

**The dial** (how bold) is deliberately unresolved and must change without a deploy.

**1. State of the art**
- **2026:** newer models are *worse* at knowing when to stay quiet in emotionally hard moments ([2603.09997](https://huggingface.co/papers/2603.09997.md)). Inferring traits from text is moderate (r 0.38–0.58). Flattering, complimentary AI lowers trust (CHI 2026).
- **So a model must never be the only gate.** Every gate is deterministic, and the model only *proposes*.
- **Frameworks**, chosen because each is decades old, non-clinical, backed by meta-analyses, and maps onto evidence we actually hold:

| Framework | Evidence | What it lets us wonder |
|---|---|---|
| Self-determination theory (autonomy, competence, relatedness; Deci & Ryan; meta-analysis Ng et al. 2012) | patterns, content, own words | which need an activity feeds |
| Flow (Csikszentmihalyi) | own words about absorption, time distortion | where they're most absorbed |
| Intention–behaviour gap (Sheeran 2002 meta-analysis; implementation intentions, Gollwitzer & Sheeran 2006) | said-vs-did | whether a plan lacks a when-and-where |
| Habits and context cues (Wood & Neal 2007) | repeated pattern after the same cue | whether a cue is driving it |
| Approach and avoidance goals (Elliot & Thrash 2002) | how goals are worded, what's pursued vs dropped | moving toward something vs away from something |

**2. Most robust, so shipped**
- A closed framework catalogue in code.
- A model proposes hypotheses from the read contract, each with a framework and the ids it rests on.
- **Deterministic validation:** the framework is in the catalogue; ≥ 2 supporting claims from ≥ 2 sources; the domain has critical mass (`may_speak`); the hypothesis is phrased as a question; it passes the **clinical blocklist**.
- Stored as `stored`. It is spoken only when the **dial** is on (`product_dials`, a database row, so no deploy is needed) **and** appetite ≥ 2.
- **At most one asked question per episode:** a hypothesis takes the provisional why's slot.
- **Rejecting it** goes through the corrections path and counts as a discomfort signal for appetite.
- **Expiry:** lint H1/H2 cover hypotheses (asked twice and unanswered, or 30 days unconfirmed, means test or retire).

**Gate F-H (declared before code):**
- 0 clinical hypotheses get through validation (fixture of 20 clinical phrasings);
- 100% of invalid proposals are rejected (unknown framework, one source, statement not question, silent domain);
- every stored hypothesis can name its framework and its evidence.

## Goal 19: Learning from itself (phase F, F-Q; 20 October 2026)

**The spec:**
- Log what was used and what landed.
- **Learn only about its own performance, never treat its own output as a fact about the person.**
- Improvements are visible and reversible.
- The metric is your answer rate on its questions over time.

**1. State of the art:** conversational contextual bandits (ConUCB; key-term selection, 2505.21393) and planned question sequences (TO-GATE, AAAI 2026). Both need far more interactions than one person gives in months: a weekly episode asks about one question a week.

**2. Against the spec and the data we have:** with roughly 4 asked questions a month, an exploring bandit would mostly explore, and it would make episodes random. The planner is deterministic by design.

**3. Most robust, so shipped:**
- **Per kind of question asked** (why · hypothesis per framework · asked answer per area of life): a Bayesian average answer rate with a Beta(1,1) prior. That's the standard small-sample estimate.
- It becomes a **bounded weight (0.8–1.2)** relative to this person's overall answer rate.
- **Used only to order things that are already allowed:** which hypothesis to offer first, and how strongly an asked answer competes in the planner. It never decides *whether* something may be said; every gate stays as it is.
- **Visible:** `GET /settings/:userId/learning`, with the last 5 snapshots. **Reversible:** behind `ENABLE_LEARNING`, and snapshots are kept.
- **It reads only reception** (what was asked, and whether you answered). It writes only its own scorecard and never a claim.

**Gate F-Q (declared before code):**
- weights stay within 0.8–1.2 for any history;
- with no history every weight is 1.0;
- more answers on a kind raises its weight;
- it never writes to facts, answers, patterns, whys or hypotheses (checked with a write-tracking database).

## Goal 18: Conversation (phase F, F-V; 20 October 2026)

**The spec:** carries context across a day; knows when to say nothing; interruptible, never a monologue; never restates what you just told it as if it discovered it. The metric is your count of "it forgot".

**1. State of the art**
- **Memory:** working memory plus retrieval from a long-term store (MemGPT-style), and 2026 work that keeps facts with provenance and validity (SodaMem, Memora, MemMachine). **Our brain already is that long-term store.**
- **Privacy:** CIMemories (ICLR 2026) found models leak remembered details into the wrong context, and prompting didn't fix it.
- **Style:** LLMs over-converge to the user's style (EACL 2026).

**2. Most robust, so shipped**
- **Today's turns** (the last 18 hours) are working memory, stored in their own table (migration 150, additive). Your turns are also saved as your own words, so the brain reads them like anything you send. **Its replies are never read as facts about you.**
- **Context:**
  - today's turns;
  - the read contract (what may be said, in which register);
  - search hits for the message;
  - anything it can't say stays out.
- **Every reply sentence** passes the same fact check (against the context it was given) and the style check as episodes.
- **Saying nothing is a valid reply:** for something you're just sending, the reply is a one-word acknowledgement or nothing.
- **Bounded length:** at most about twice your message's length, between 1 and 4 sentences. A question gets its answer first.
- **No restating as discovery:** any sentence that mostly repeats your own words from today, framed as an observation, is cut (word overlap, deterministic).
- **"That's wrong"** goes straight to the corrections path (goal 20).
- **Context rules, deterministic (CIMemories):**
  - silent domains, flagged claims and extreme-severity patterns are never brought up unasked;
  - automated or someone else's mail is never stated as a fact about you;
  - saved links come up only when asked.

**Gate F-V (declared before code):**
- context from earlier in the day reaches the reply prompt; yesterday's doesn't;
- 100% of restating-as-discovery fixtures are cut, and 0 genuine answers;
- the length bound always holds;
- corrections are routed;
- the context rules exclude every forbidden item in fixtures;
- live: on 10 FYI messages it says nothing or acknowledges; on 10 questions it answers first.

## Goal 17: Acting on the world (phase F, F-A; 20 October 2026). Mechanism only; the fork is the founder's

**The spec:**
- Every action recorded, attributed and reversible where possible.
- Nothing acts without approval unless the class was durably authorised.
- **Never acts on instructions found in content.**
- You see what it's about to do first.
- *"The act-versus-prepare fork gets decided when this goal starts"*, and all credentials stay read-only for the whole plan.

**1. State of the art**
- **Agents are unreliable on repeated runs:** best pass^4 is about 60% on τ-bench (2026, vendor-reported).
- **Indirect prompt injection is the main attack** (Greshake et al. 2023). The robust defence is **capability separation**, as in CaMeL (Google DeepMind 2025): control flow comes only from the trusted request, and untrusted data (emails, pages) can never choose an action.

**2. Most robust, so shipped (fork-independent):**
- **An action ledger** (migration 151, additive): what, why, which of your messages it came from, status, who approved, when, and how to undo it.
- **Origin rule, deterministic:** an action may be proposed only from your own words (your message, as own words). Anything from mail, a page, a saved link or an automated sender is refused, whatever it says.
- **Preview, then approval.** A class you've durably authorised is auto-approved, but still recorded.
- **Executors are prepare-only:** a draft message, a reminder, a calendar hold drafted inside Retrospect. Nothing leaves Retrospect, and **no write credentials** are added.

**Founder's call when ready:** prepare-only forever, or let some classes act (each needing write credentials and its own gate).

**Gate F-A (declared before code):**
- 0 actions proposed from content (fixtures include an email saying "forward this to…");
- 0 actions executed without approval or authorisation;
- every action recorded with its origin;
- undo works on everything prepared.
