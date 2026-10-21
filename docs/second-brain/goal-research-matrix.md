# Goal research matrix — every goal, its approach, its evidence, its maturity

19 October 2026. The founder asked whether every goal has an approach,
**validated by research and calibrated to be stable but cutting edge**, then
broken down to chunks, bites and PRs. The honest answer was "partly":
[research-foundations.md](./research-foundations.md) covered the architecture
**by field** (15 searches), not goal by goal, and never rated maturity. This
closes that gap with 18 further searches, aimed at the goals the first pass
missed.

**How to read maturity.**
- **Established:** decades of evidence or a production standard. Low risk.
- **Emerging:** strong recent papers, little production track record. Use with a gate.
- **Frontier:** recent preprints or vendor claims. Use only behind a switch, measured against a stable fallback.

**The calibration rule:** the claim side (what it says about you) is always
established or gated. The craft side (how it's written, voiced, timed) may run
at the frontier, because a failure there costs engagement, not trust. This is
the spec's own split: "conservative about claims, never about craft".

**Honesty note:** sources were read at abstract or summary level. Vendor
memory benchmarks are disputed (the same system is reported at 75% and 94%).
Nothing here counts until it passes our own gate on our own data.

## TL;DR

- **Covered with a researched approach:** all 25 goals. Before today, eight
  had none: 9, 15, 16, 17, 18, 19, 20 and 22.
- **Where research changes our plan (new):** R1–R6 below. The biggest:
  - **audio narrative beats print** for behaviour change, so the podcast is the right primary output;
  - **LLM personality inference is weak** (r ≈ 0.2–0.3), so appetite (goal 22) must be read from behaviour and stated preference, never inferred from text;
  - **self-generated insight outperforms being told**, which confirms ask-don't-tell;
  - **bounded style-matching**: mirror the person's style, but cap it, or the voice drifts.
- **Broken down to PRs:** 11 goals. **Chunk level only:** 9. **Not yet planned:**
  5 (phase F). Each gets its PR breakdown when its chunk starts, per the plan.

---

## 2026 refresh: every goal re-checked (20 October 2026)

The founder asked for every goal to be checked against the newest work, not just the four biggest decisions. **Result: no goal's approach is overturned.** Three get upgrades and one gets a new requirement. Engineering-only goals (1 data sources, 2 ingestion, 16 delivery) need no literature.

| Goal | 2026 evidence | Verdict |
|---|---|---|
| 3 Making meaning | Constrained hybrid decoding guarantees quoted spans are verbatim ([2609.10046](https://arxiv.org/pdf/2609.10046)); ACL-Verbatim 2026 | ✅ Confirmed (our span check drops non-verbatim facts); constrained extraction is a possible later upgrade |
| 4 People *(tabled)* | EnsembleLink, record linkage with language models and no labelled data (Jan 2026, [2601.21138](https://arxiv.org/pdf/2601.21138)) | ✅ Confirmed; worth comparing when people work resumes |
| 5 Linting | Learned KG repairs (ESWC 2026); LLM SHACL repair still needs human review ([2507.22419](https://arxiv.org/pdf/2507.22419)) | ✅ Confirmed: proposals reviewed, never automatic |
| 6 Search | SodaMem planner–reader loop (Aug 2026, [2608.08055](https://arxiv.org/abs/2608.08055)); Memora (ACL 2026, [2604.20006](https://arxiv.org/abs/2604.20006)) | ⬆️ **Upgrade:** let the reader ask for more evidence before answering |
| 7, 8 Goals, said vs did | No 2026 work changes the psychology (implementation intentions; revealed vs stated) | ✅ Confirmed |
| 9 Communication style | LLMs **over-converge** to user style, more than humans do (EACL 2026, [2026.eacl-long.34](https://aclanthology.org/2026.eacl-long.34); May 2026, [2605.29278](https://arxiv.org/pdf/2605.29278)) | ✅ Confirmed, and **the cap matters more than we assumed** |
| 10 Current state | PersonaTree: layered person memory, conservative writes, confidence-guided consolidation (Jun 2026, [2606.04780](https://www.alphaxiv.org/abs/2606.04780)) | ✅ Same shape as our read contract (counted confidence, empty slots stay empty) |
| 11 Relevance, daily timing | No 2026 trial beats "explain why it's here"; JITAI 2026 work is still protocols | ✅ Confirmed |
| 12 Impediments | 2026 MI studies: reflections and open questions beat unsolicited advice; LLMs "talk more than they listen" ([2608.22425](https://arxiv.org/pdf/2608.22425), [2607.28814](https://arxiv.org/pdf/2607.28814)) | ✅ Confirmed: asked before stated |
| 13, 14 Outline, story | PodBench (ACL 2026); MoonCast (brief first); podcast faithfulness with catch-and-repair (Jul 2026, [2607.21961](https://arxiv.org/abs/2607.21961)) | ✅ Confirmed, ⬆️ **upgrade:** repair unsupported sentences instead of cutting them |
| 15 Voice | Eleven v4 (Sep 2026); listeners rate human podcasts above NotebookLM two-host on tone and engagement (UChicago); no study shows two hosts beat one | ✅ Unchanged: your blind listen decides; ⬆️ test v4 |
| 17 Acting | τ-bench 2026 (vendor-reported): best pass^4 is about 60%, so agents still fail repeated runs | ✅ Confirmed: confirmation before anything irreversible |
| 18 Conversation, 23 Reference | **CIMemories (ICLR 2026):** frontier models leak remembered details into the wrong context in up to 69% of cases, and privacy prompts don't fix it ([mlanthology](https://mlanthology.org/iclr/2026/mireshghallah2026iclr-cimemories/)) | ➕ **New requirement:** a context check on what the podcast, brief and conversation reveal, as its own gate before anyone else ever hears an episode |
| 19 Learns from itself | TO-GATE (AAAI 2026) plans question sequences; diffusion-style question asking ([2510.12015](https://arxiv.org/abs/2510.12015v1)) | ✅ Bandit still reasonable; TO-GATE is an option for phase F |
| 20 Correction | Already cites 2026 ([2609.26035](https://arxiv.org/pdf/2609.26035)) | ✅ |
| 21 Hypothesis | 2026 clinical safety study: newer models are *worse* at knowing when to stay quiet ([2603.09997](https://huggingface.co/papers/2603.09997.md)) | ✅ Confirmed: gated hardest, delivered as a question |
| 22 Calibration | Conversational trait inference is now r 0.38–0.58 ([2602.15848](https://www.alphaxiv.org/abs/2602.15848)), up from about 0.29, still moderate | ✅ Ask, then observe stays; the gap is narrowing, so re-check in 2027 |
| 24 Cold start | Already cites ICML 2026 | ✅ |
| 25 Pattern change | No 2026 method beats rate tests and change-point detection on personal data | ✅ Confirmed |
| V2 "affirm my progress" | Flattering, complimentary AI lowers trust (CHI 2026, [2502.10844](https://arxiv.org/abs/2502.10844v3)); sycophancy can feel supportive while hurting wellbeing ([2512.08937](https://arxiv.org/pdf/2512.08937)) | ⚠️ Praise must be specific and earned (tied to what you did), never flattery |

### Deliberate choices: bleeding edge understood, robust version shipped

Rule (founder, 20 Oct 2026): **understand the newest work, but ship only what's ironclad.** A single 2026 preprint shows where things are heading; it isn't proof.

| Upgrade | How strong the evidence is | What we ship |
|---|---|---|
| Search asks for more evidence before answering | SodaMem is one Aug 2026 preprint, **graded by its own model**, so not ironclad. Iterative retrieval itself is well established (multi-step retrieval-and-reasoning since 2023). | The **established, bounded form**: at most 2 extra searches, then answer or abstain; kept only if it beats today on our three-run gate. We don't import SodaMem's graph. |
| Repair instead of cut | Catch-and-repair is an unreviewed Jul 2026 preprint with no published numbers. | **Repair, then re-check the repaired sentence with the same fact check; if it still fails, cut.** The fact check stays the floor, so this can only add sentences that pass. |
| Eleven v4 | Three weeks old; ElevenLabs itself says tag-following is imperfect. | **Not a default.** A blind A/B against v3 on your episode; it ships only if your ear prefers it. |
| Context check on what's revealed | CIMemories is **peer-reviewed (ICLR 2026)**, and the finding is robust across frontier models: prompting doesn't stop leaks. | **Deterministic rules in code** (which kinds of claims may appear in which output), not a prompt, because the paper shows prompts fail. |
| Style cap, praise only when earned | Several 2026 studies agree (EACL, CHI). | Kept. Praise is already bound by the fact check: it can only cite things you actually did. |

## The matrix

| # | Goal | Approach | Evidence | Maturity | Planned to |
|---|---|---|---|---|---|
| 3 | Making meaning | LLM extraction, then **verbatim span check** (each fact quotes its source), then trust rules | FActScore ([Min et al. 2023](https://arxiv.org/pdf/2305.14251)); LLM extraction is not grounded by default, and span checks catch most hallucinations ([2510.00276](https://arxiv.org/pdf/2510.00276v1)); verbatim extraction ([ACL-Verbatim](https://arxiv.org/pdf/2605.21102)) | Established | built; W1 ✅ |
| 1 | Data sources | Direct connectors; a stated extraction intent per source | engineering standard (OAuth, incremental sync) | Established | built; Notion = R1 |
| 2 | Ingestion | Event-driven ("material arrived"), idempotent, crons as the safety net | standard event-driven design; replay safety tested (F1.5) | Established | F3 PRs |
| 4 | Connections / people | **Fellegi–Sunter** scoring, blocking, link / hold / separate bands, LLM tie-break | research-foundations §3; record linkage is a 50-year-old field | Established core + emerging LLM tie-break | W2 PRs |
| 23 | Reference bank | Saved items kept apart from claims about you; relevance edges to goals; findable by reason | contextual integrity ([2408.02373](https://arxiv.org/pdf/2408.02373)); trust classes | Established | R1 chunk |
| 20 | Correction sticks | Correction retires the claim and **propagates along lineage** to everything built on it; corrections outrank inference; corrections must reach downstream reasoning, not just the record | belief revision with user corrections ([2609.26035](https://arxiv.org/pdf/2609.26035)); memory staleness and state-aware revision (STALE / CUPMem, [summary](https://www.emergentmind.com/topics/cupmem)); errors propagate unless corrected early ([EMNLP 2025](https://preview.aclanthology.org/new-sigs/2025.findings-emnlp.627/)) | Emerging | lineage built (F1); propagation = phase F |
| 5 | Linting | Rule checks over claims (26 exist), explained in plain words; repair proposals reviewed, never automatic | SHACL-style constraint validation; LLM-explained violations ([xpSHACL](https://arxiv.org/pdf/2507.08432)); LLM KG repair ([2507.22419](https://arxiv.org/pdf/2507.22419)) | Established rules + emerging LLM repair | lint built; lint in charge = phase F |
| 22 | Calibration / appetite | **Ask, then observe** (engagement after bolder outputs); safe default; never infer from text | LLM trait inference from text is weak (r ≈ 0.29, [PMC11211928](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11211928/); r 0.18–0.31, [Marengo & Settanni 2025](https://iris.unito.it/handle/2318/2114965)); autonomy-supportive language helps most for people with a high need for autonomy ([2024 study](https://dare.uva.nl/id/34e1735f-5e50-4a10-813c-b8838575b8f1); [Altendorf 2019](https://pure.uva.nl/ws/files/33032229/Published_article_Altendorf_et_al_2019_.pdf)) | Emerging; **R2** | phase F (research task still owed: a proper review) |
| 10 | Current state | One portrait, built from claims; empty slots stay empty; claim class on every slot | Generative Agents' reflection ([Park 2023](https://arxiv.org/pdf/2304.03442v1)); bi-temporal model ([Zep/Graphiti](https://arxiv.org/html/2501.13956v1)) | Established | built; W4 read contract |
| 6 | Search | **Hybrid** (keyword + vector) retrieval, rerank, answer with receipt; **must abstain** | hybrid beats either alone ([summary](https://www.genzeon.com/hybrid-retrieval-deranking-in-rag-recall-precision/)); an optimised RAG that never refused raised over-confidence concerns (LiveRAG 2025, [summary](https://awesomepapers.io/similarity-search/papers/2506.22644)); LongMemEval abstention ([Wu 2025](https://arxiv.org/html/2410.10813v2)) | Established retrieval + emerging abstention; **R5** | S1 chunk; abstention measured in F2 |
| 24 | Cold start | Onboarding questions chosen to **reduce the most uncertainty** across the 36 questions at once; first output from what's read | adaptive questioning with persona priors beats classic CAT ([ICML 2026, 2605.00696](https://arxiv.org/pdf/2605.00696)); LLM adaptive testing with 20% fewer questions ([TestAgent, ACL 2025](https://arxiv.org/pdf/2506.03032)) | **Frontier** for the method; established intent (CAT/IRT) | onboarding built; adaptive picking = later, behind a switch |
| 7 | Reported goals | Lifecycle: stated → active → quit / achieved / expired; quitting is immediate | goal disengagement is adaptive; implementation intentions d = 0.65 ([Gollwitzer & Sheeran 2006](https://www.academia.edu/55735607/Implementation_intentions_Strong_effects_of_simple_plans)), with a 2024 update over 642 tests (d .27–.66) | Established | stated goals built (#44); lifecycle in W4 |
| 8 | Real goals | Observed pursuit = a pattern (evidence); what's wanted underneath = hypothesis; said-vs-did as **two numbers, never merged** | revealed versus stated preference; personal informatics ([Li, Dey & Forlizzi 2010](https://courses.cs.washington.edu/courses/cse440/15au/readings/PersonalInformatics-Li2010.pdf)) | Established | W4.3 PRs |
| 12 | Impediments | A why only after a pattern; outside causes first; **asked before stated** | self-generated reasons persuade more and cause less reactance than given ones ([Frontiers 2020](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2020.613418/epub); [IPR summary](https://instituteforpr.org/self-persuasion-in-media-messages-reducing-alcohol-consumption-among-students-with-open-ended-questions)); **R3** | Established | why gate built; question form W6 |
| 18 | Conversation | One memory across sessions; reads the same claims; writes back only through the same gates | LoCoMo-style long-term memory (Mem0 [2504.19413](https://arxiv.org/pdf/2504.19413); temporal memory [TiMem 2601.02845](https://arxiv.org/pdf/2601.02845)); **vendor scores disputed** | Emerging | phase F |
| 9 | Communication style | **Bounded style matching**: match formality, length and sentiment, capped so the voice stays itself | uncapped mirroring trades away stability; bounded (EMA + cap) keeps it ([2510.00339](https://arxiv.org/pdf/2510.00339)); LLMs match content better than style ([Durandard et al.](https://escholarship.org/uc/item/7623w45h)) | Emerging; **R4** | phase F; profile slot exists |
| 11 | Relevance & research | Each brought item traces to a question their life raised; **explanation shown**; keep-rate measured | explanations raise trust and intent to use ([UMN](https://experts.umn.edu/en/publications/exploring-explanation-effects-on-consumers-trust-in-online-recomm)); explained serendipity works, unexplained surprise lowers interest ([2508.19569](https://arxiv.org/pdf/2508.19569)) | Established | researcher built; D1 / R1 |
| 21 | Hypothesis | Three gates (critical mass, named framework, appetite); delivered as a question | weak validity of trait inference (above); self-persuasion (above) | **Frontier**, so gated hardest | phase F |
| 13 | Outline | **Plan, then write**: planner → typed, evidence-bearing outline | detailed outline control beats a plain plan-and-write on coherence (+22.5) ([DOC 2212.10077](https://arxiv.org/pdf/2212.10077); [Re3](https://arxiv.org/pdf/2210.06774)); adaptive recursive planning ([2503.08275](https://arxiv.org/pdf/2503.08275)) | Established core + emerging adaptive planning | W5 PRs |
| 14 | Story | Narrative in two registers; atomic-claim guard; **scaffolding tested** (heavy / medium / light) | **narrative persuades via audio and video, not print** (meta-analysis, 25 studies, N = 9,330, [PMC5267340](https://pmc.ncbi.nlm.nih.gov/articles/PMC5267340)); transportation is the mechanism ([IJoC](https://ijoc.org/index.php/ijoc/article/view/6977)); **R1** | Established mechanism; frontier craft | W6 PRs (incl. experiment) |
| 15 | Voice | Produced, expressive voice; possibly two-host dialogue; your blind listen decides | NotebookLM-style two-host audio is well received but **unevaluated formally** ([Willison](https://simonw.substack.com/p/notebooklms-automatically-generated)); PodAgent ([ACL 2025](https://arxiv.org/html/2503.00455v1)) | **Frontier**, so your ear is the gate | W7 |
| 16 | Delivery | Resumable, offline for what's downloaded, both forms (audio and text) | engineering standard | Established | iOS v2 project |
| 25 | Pattern change | **Two-window Poisson rate test** at the existence bar now; Bayesian online change-point detection as the upgrade | rate test (classical); BOCPD ([Adams & MacKay 2007](https://arxiv.org/pdf/0710.3742)), with a modular likelihood (Poisson fits counts); wearables ([Stival et al.](https://www.homepages.ucl.ac.uk/~ucakpde/publication/stival2023doubly/stival2023doubly.pdf)); **R6** | Established now, emerging upgrade | W3.3 PRs |
| 19 | Learns from itself | Which question to ask next as a **contextual bandit** over the 36 questions; learns only about its own performance (P7) | conversational contextual bandits ([ConUCB](https://ar5iv.labs.arxiv.org/html/1906.01219); key-term selection [2505.21393](https://arxiv.org/abs/2505.21393)) | Emerging | phase F |
| 17 | Acting on the world | Tools with **confirmation before anything irreversible**; measured on repeated runs | best agents succeed on under half of tasks, with pass^8 under 25% (τ-bench, [2406.12045](https://export.arxiv.org/pdf/2406.12045)); so acting needs confirmation and repeat-reliability gates | Frontier, so last in the spec, and rightly | phase F (last) |

---

## What the research changes (R1–R6)

These add to the design changes C1–C10 in
[research-foundations.md](./research-foundations.md).

- **R1. Audio is the right primary output, and narrative is the mechanism.**
  The meta-analysis found narrative effects through audio and video, not print.
  This supports podcast-first, and supports the founder's "narrative" ask
  (goal 14 gap). The W6 experiment should measure **transportation**: did you
  get absorbed, not just "was it accurate"?
- **R2. Never infer appetite or personality from text.** Correlations of
  0.18–0.31, with demographic bias. Goal 22 reads appetite from **what they
  say and how they respond** (finished, skipped, replied, disagreed), with a
  safe default. This closes the spec's open research task in the direction
  the spec already leaned.
- **R3. Asking beats telling, measurably.** Self-generated reasons persuade
  more and trigger less reactance. This confirms the IKEA effect, the asked
  register and the question-first why. The planner should prefer an asked item
  over a stated one whenever confidence is borderline.
- **R4. Style matching must be bounded.** Full mirroring destabilises the
  voice. Goal 9 becomes: match formality, length and sentiment toward the
  person, with a cap and smoothing.
- **R5. A search that never refuses is a warning sign.** The refusal rate is
  a first-class metric for S1, measured on F2's abstention questions.
- **R6. Trajectory now, change-point later.** The two-window test is simple
  and auditable; it's what W3 builds. BOCPD is the upgrade once people have
  months of data, behind a switch and scored on the same W3 fixtures.

## Gaps the research could not close

- No formal study of listener engagement with AI-generated personal audio.
  Your blind listen (W7) is the evidence.
- No study of propagating a user's correction to derived facts in a personal
  knowledge base. We built lineage (F1) to do it, and it gets its own gate.
- Tailoring to readiness to change: mixed evidence. Stay with the safe default.

## Where each goal's breakdown lives

- **To PRs:** 3, 1, 2, 4, 7 (part), 8, 10 (part), 12 (part), 13, 25, plus the
  analyses in [podcast-behaviour-analysis.md](./podcast-behaviour-analysis.md).
- **Chunk level (bites when the chunk starts):** 6, 11, 14, 15, 23, 24, 5, 20, 16.
- **Phase F, not yet chunked:** 9, 17, 18, 19, 21, 22 (planned when E passes).

**Next level of rigour, owed:**
- full-text reads of the papers each gate rests on, before that chunk starts;
- the goal 22 review, written as its own brief.
