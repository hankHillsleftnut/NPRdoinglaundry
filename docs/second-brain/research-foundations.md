# Research foundations — what the architecture rests on, and what it changes

19 October 2026. Step 2 (survey) of the [decision loop](./decision-loop.md),
done properly for the whole [target architecture](./target-architecture.md):
15 literature searches across seven fields, each decision tied to evidence, and
**the places the literature challenges the design stated plainly**. Builds on
the engineering survey in [survey-architecture.md](./survey-architecture.md).

Honesty note: most sources were read at abstract or summary level, not in full.
Where a number is quoted it is the paper's own; where a source is a preprint or
self-reported, it says so. Nothing here is treated as settled until it passes
our own gates on our own data — the process's rule.

## TL;DR

- **Confirmed:** the spine (evidence → understanding → expression), facts in
  the person's own words, confidence counted rather than claimed, contradiction
  that invalidates rather than deletes, people as first-class, ask-don't-tell.
  Each has direct support.
- **Challenged, and changed — ten design changes (C1–C10), section 3.** The
  biggest: the guard must check **atomic claims**, not sentences (FActScore);
  the **writer must not choose its own hedging** (models' stated confidence is
  miscalibrated); the brain needs an **evaluation suite modelled on
  LongMemEval's five abilities, including abstention**; and outputs need a
  **contextual-integrity flow policy** (what may be said where).
- **Where research is thin:** no standard evaluation for personal podcasts; the
  appetite/calibration research task (goal 22) is still owed; personal
  knowledge graphs with LLMs have no settled practice. These get our own gates.

---

## 1. Field by field

### 1.1 How AI agents remember
- **Generative Agents** ([Park et al. 2023](https://arxiv.org/pdf/2304.03442v1)):
  a memory stream of observations; retrieval scores **recency × importance ×
  relevance**; **reflection** synthesises memories into higher-level inferences
  and stores them back as memories.
  *Supports:* our patterns and whys are "reflection"; retrieval scoring informs
  the planner. *Challenges:* storing reflections back as memories is exactly how
  a system starts believing its own output — we keep the claim ladder separate
  and never let a reflection become evidence for itself (P7).
- **Zep / Graphiti** ([paper](https://arxiv.org/html/2501.13956v1)): episodes →
  entities and facts → community summaries; **bi-temporal** edges;
  contradiction **invalidates**. *Supports* our layering; we adopt true-when /
  learned-when.
- **Memory surveys** ([Rethinking Memory in AI, 2505.00675](https://papers.cool/arxiv/2505.00675);
  [AI meets Brain, 2512.23343](https://www.alphaxiv.org/overview/2512.23343);
  [Memory for Autonomous LLM Agents, 2603.07670](https://arxiv.org/html/2603.07670)):
  memory is a **write–manage–read** loop with six operations — consolidation,
  updating, indexing, forgetting, retrieval, compression; **consolidation and
  learned forgetting** are the open problems. *Challenges:* our design has
  update (supersession) and forgetting (decay) but no owner for each of the
  six → **C1**.
- **Personal knowledge graphs** ([Balog & Kenter 2019](https://research.google/pubs/personal-knowledge-graphs-a-research-agenda/);
  [ecosystem survey 2024](https://arxiv.org/html/2304.09572v2)): entities
  personally related to the user, owned by them, for personalised services;
  population and maintenance are open challenges. *Supports* people as
  first-class (W2) and single-person ownership.

### 1.2 Evaluating memory
- **LongMemEval** ([Wu et al., ICLR 2025](https://arxiv.org/html/2410.10813v2)):
  five abilities — **information extraction, multi-session reasoning,
  knowledge updates, temporal reasoning, abstention** — and assistants lose
  ~30% accuracy over sustained interaction. *Challenges:* we have no
  brain-level evaluation; our gates test parts, not whether the brain answers
  correctly over time, updates, or **declines when it doesn't know** → **C2**.
- **Vendor benchmarks are contested** (Mem0/Zep/Letta disputes,
  [analysis](https://pub.towardsai.net/mem0-vs-zep-vs-letta-a-folder-of-text-files-shouldnt-beat-the-61k-star-memory-layer-9d7e65c5799c)).
  *Implication:* evaluate on our own data, as the process already says.

### 1.3 Knowing a person from their traces
- **Digital footprints** ([Wu Youyou, Kosinski & Stillwell, PNAS 2015](https://pubmed.ncbi.nlm.nih.gov/25583507/)):
  models predicted personality from Facebook Likes better than friends
  (r = 0.56 vs 0.49), and beat a spouse at ~300 Likes — but **humans were
  better on life satisfaction** and traits "depending on subtle cognition".
  *Supports* trust classes: behaviour from records, inner life only from own
  words.
- **Personalisation benchmarks** ([PersonaMem-v2, 2512.06688](https://arxiv.org/html/2512.06688v1);
  [AlpsBench, SIGIR '26](https://arxiv.org/pdf/2603.26680)): frontier models
  reach only **37–48%** on implicit preferences; explicit memory improves
  **recall but not** preference-aligned or resonant responses.
  *Supports* structured, evidence-counted claims over "let the model infer".
  *Challenges:* recall is not the product — the expression layer needs its own
  evaluation (W5 spine rate, W7 audio check), not just memory accuracy.
- **Personal health insights** ([PH-LLM, Nature Medicine 2025](https://research.google/pubs/a-personal-health-large-language-model-for-sleep-and-fitness-coaching/)):
  insight generation works on **aggregated daily-resolution** sensor data,
  evaluated on expert-rated case studies → **C8**.

### 1.4 Reflection and behaviour change
- **Personal informatics** ([Li, Dey & Forlizzi 2010](https://courses.cs.washington.edu/courses/cse440/15au/readings/PersonalInformatics-Li2010.pdf);
  [Epstein et al. 2015](https://my.eng.utah.edu/~cs5540/au16/readings/PersonalInformatics-Epstein2015.pdf)):
  preparation → collection → integration → reflection → action; reflection
  has **discovery** and **maintenance** phases with different questions; for
  some people **understanding is the goal and action is skipped**.
  *Challenges:* our episodes assume one mode → **C6**.
- **Just-in-time adaptive interventions** ([2025 review](https://pmc.ncbi.nlm.nih.gov/articles/PMC12784143);
  [receptivity, 2508.02817](https://arxiv.org/html/2508.02817v1)): decision
  points, tailoring variables, and **receptivity** (willing and able to act
  now); most systems lack real adaptivity. → **C10** (daily brief timing).
- **Behaviour-change techniques** (BCT taxonomy v1, Michie et al. 2013, cited in
  [Bloom](https://arxiv.org/pdf/2510.05449)): 93 named techniques, including
  *self-monitoring* and *feedback on behaviour*; **motivational interviewing**
  fidelity is measurable (MISC) and LLM MI agents are being validated
  ([Aimi, 2505.17380](https://arxiv.org/pdf/2505.17380)). → **C9**.

### 1.5 Saying things under uncertainty
- **Mixed-initiative interfaces** ([Horvitz 1999](https://erichorvitz.com/chi99horvitz.pdf)):
  act only when expected value exceeds inaction, weigh the cost of attention,
  and **use dialogue to resolve key uncertainties**. *Supports* withholding,
  the planner's stopping threshold, ask-don't-tell, and V2's confirmation
  questions (chosen by what they'd settle).
- **Verbalised confidence** ([Xiong et al. 2306.13063](https://arxiv.org/pdf/2306.13063);
  [Kim et al., FAccT 2024](https://www.jennwv.com/papers/uncertaintyllms.pdf)):
  models' stated confidence is badly miscalibrated (near-max regardless), and
  hedged language **can increase over-reliance**. *Strongly supports* counting
  confidence from evidence. *Challenges:* the writer currently decides its own
  hedging → **C4**.

### 1.6 Staying faithful
- **FActScore** ([Min et al., EMNLP 2023](https://arxiv.org/pdf/2305.14251)):
  long text mixes supported and unsupported facts even within one sentence
  (40% of ChatGPT sentences); score = share of **atomic facts** supported.
  **VeriScore** ([Song et al. 2024](https://preview.aclanthology.org/fix-8040/2024.findings-emnlp.552))
  separates verifiable from unverifiable claims.
  *Challenges:* a sentence-level guard misses mixed sentences → **C3**.

### 1.7 Personal audio
- **PodAgent** ([Findings of ACL 2025](https://arxiv.org/html/2503.00455v1)):
  host–guest–writer agents beat direct generation; voice–role matching;
  LLM-guided expressive synthesis; **no standard evaluation exists**.
  *Implication:* our audio check (step 7) plus a written rubric is the
  evaluation; a critic pass in the writer is worth testing (W6).

### 1.8 Privacy of flows
- **Contextual integrity** ([DeepMind, 2408.02373](https://arxiv.org/pdf/2408.02373);
  [critique, 2501.19173](https://arxiv.org/html/2501.19173v2)): privacy is
  whether a flow fits its context's norms (subject, sender, receiver, type,
  transmission principle). *Challenges:* nothing stops an episode reading a
  friend's private message aloud → **C5**.

---

## 2. What the literature confirms (keep)

| Decision | Evidence |
|---|---|
| Facts in their own words; inner life only from own words | Wu Youyou 2015 (humans better on subtle cognition); our test bank |
| Confidence counted from evidence, never claimed by a model | Xiong 2023; Kim 2024 |
| Invalidate, never delete; true-when vs learned-when | Zep/Graphiti |
| People as first-class, owned by the person | PKG agenda and survey |
| Withhold below the bar; ask, don't tell | Horvitz 1999; MI |
| Structured claims over implicit model inference | PersonaMem-v2, AlpsBench |
| Separate claim ladder; reflections never evidence for themselves | Generative Agents, read critically |

## 3. Design changes (C1–C10)

| # | Change | From | Lands in |
|---|---|---|---|
| **C1** | Name an owner for each memory operation: write (capture), **consolidate** (facts → patterns), update (invalidation), index (search), **forget** (decay + retirement policy), retrieve (planner), compress (summaries) | memory surveys | architecture §2; W3, W4 |
| **C2** | A **brain evaluation suite** on the founder's test bank + fictional personas, in LongMemEval's five abilities — extraction, multi-session, **updates**, temporal, **abstention** — run after every chunk | LongMemEval | new chunk F2 |
| **C3** | Guard = decompose the script into **atomic claims**, check each against its evidence; asked-register lines are exempt from verification but must be in the asked register; metric = factual precision | FActScore, VeriScore | W6 |
| **C4** | **The planner assigns each item's register** (stated / offered / asked) from computed confidence and claim class; the writer cannot hedge or harden on its own | verbalised-confidence studies | W5, W6 |
| **C5** | An expression **flow policy**: third-party content may inform, not be quoted; nothing from one person's private channel is voiced about another; per output | contextual integrity | W5 |
| **C6** | A per-person **reflection phase** (discovery / maintenance) and **action optional**: episodes shaped by phase | personal informatics | W5 policy; later learned (goal 19) |
| **C7** | Planner value adds **importance and recency** to relevance, coverage and redundancy | Generative Agents | W5 |
| **C8** | Records are **aggregated to daily summaries** before any model reasons over them | PH-LLM | W3 |
| **C9** | Frameworks registry seeded with **BCT taxonomy + MI + CBT communication posture**; each episode segment tagged with the technique it uses | BCTTv1, MI | registry (W5), goal 21 |
| **C10** | The daily brief as a **decision point**: timing and content tailored to receptivity (calendar load, recent engagement) | JITAI | daily-brief chunk |

## 4. Still owed (surveys to run when their chunks come)
- **Appetite / calibration** (goal 22) — the spec's named research task.
- **Search** — hybrid retrieval, reranking, pgvector limits.
- **Voice** — expressive TTS options and cost (voice is ~60% of a user's week).
- **Hypothesis frameworks** — which named frameworks qualify, with
  applicability conditions (goal 21).
