# Target architecture — designed to the ceiling

Written 19 October 2026 (night), at the founder's direction: design for the full
goal spec first, pressure-test it, then build toward it — weekly podcast first,
then daily, then search, then the rest. Builds on
[architecture-and-sequence.md](./architecture-and-sequence.md) (the spine, the
three layers, the five commitments), which this does not replace but completes.

**Status: proposal. Section 6 is the decision brief (stop point).**

---

## TL;DR

- **Keep the spine:** sources → grounded evidence → understanding → what to
  say → said. Keep the five commitments (withhold when unsure; lineage is
  structural; reprocessing is safe; layers meet at contracts; say less and
  measure it).
- **What's new at the ceiling:** seven things the current system doesn't have
  a home for — **trust classes** on evidence, **people as first-class**, a
  separate **reference bank**, one **understanding store** that is the only
  thing expression reads, a **claim ladder with lineage edges** so corrections
  and lint propagate, an **expression planner** separate from the writer, and
  a **reception log** that the system learns from.
- **Pressure test:** all 25 goals have a home; 9 of today's real failures are
  designed out (section 5).
- **Build order for the weekly podcast:** trust classes → people → patterns
  with trajectory → understanding store → episode planner → writer with
  registers and guard → audio check with you. Seven steps, each with a gate.

---

## 1. Principles (unchanged, restated so every decision below can cite them)

- **P1 Withhold when unsure.** Below a bar, silent — never hedged-and-said.
- **P2 Lineage is structural.** Every claim can answer "how do you know" down
  to the exact words or record; enforced by schema, not convention.
- **P3 Reprocessing is safe.** Everything derived can be rebuilt from capture;
  twice equals once.
- **P4 Layers meet at contracts.** Capture → Evidence → Understanding →
  Expression. Each reads only the layer below it.
- **P5 Say less than you know, and measure it.** The withholding ratio is a
  first-class metric.
- **P6 The claim ladder is never blurred.** Fact → pattern → why → hypothesis,
  each born differently, each said differently.
- **P7 Learn about its own performance, never about you from its own output**
  (goal 19's line).

---

## 2. The architecture

```
 CAPTURE ─────────► EVIDENCE ─────────────► UNDERSTANDING ─────────► EXPRESSION ─► DELIVERY
 sources            self bank                the one read surface      planner        app, voice
 (durable, once)    · facts (spans)          · answers to the 36       · select       offline, resume
                    · people & relations     · patterns + trajectory   · withhold
                    · records                · whys (gated)            · spine
                    reference bank           · hypotheses (3 gates)    writer
                    · items, collections     · goals: said vs did      · registers
                    · intent notes           · appetite                guard (lineage)
                                             all with confidence,      voice (2 voices)
                                             status, evidence edges
        ▲                                          ▲                         │
        │                                          │                         ▼
   PLATFORM: jobs & events · spend guard · traces & costs · readiness · lint · privacy
   FEEDBACK: corrections ──► claim status, propagated along lineage edges
             reception log ──► calibration (appetite), planner learning
```

### 2.1 Capture — get it in, durably, exactly once
- Every source (Google, iPhone, Notion, share-to-Retrospect, onboarding,
  voice/text) lands as a **durable row** with: source, authorship, **trust
  class** (new — 3.1), idempotency key, terminal status.
- **Per-item visibility** for the person: arrived · read · used (goal 2).
- Connectors are read-only for the whole plan (goal 17 deferred).

### 2.2 Evidence — what is grounded
- **Self bank:** facts (claims with an exact quote span, P2), **people and
  relationships** (3.2), records (calendar, health, screen time — behaviour,
  not words).
- **Reference bank:** links, articles, people-to-contact, collections created
  by speaking them, the intent note, and a stored **relevance edge** to the
  goal or question it bears on (goal 23). Never evidence about you.

### 2.3 Understanding — the only thing expression reads (P4)
One store, every entry a **claim** with: class (fact / pattern / why /
hypothesis / answer / goal / appetite), current text, confidence (counted, not
claimed), status (active / held / rejected / expired / superseded), last moved,
and **evidence edges** to what it rests on.
- **Answers to the 36** (exists: question store) — the backbone.
- **Patterns with trajectory** (goal 25): weakening / holding / strengthening,
  with instances.
- **Whys** behind the why gate; **hypotheses** behind three gates (critical
  mass per domain, a named framework from a versioned registry, appetite)
  (goal 21).
- **Goals:** stated (goal 7) versus revealed (goal 8), with said-vs-did as a
  computed claim.
- **Appetite** per person (goal 22): safe default, raised only on evidence.

### 2.4 Expression — decide what to say, then say it well
- **Planner** (new, deterministic where possible): picks what is worth saying
  from the understanding store — spine, items, what to withhold, why each item
  is there (goal 11) — and records the withholding ratio (P5). The same planner
  serves the weekly episode, the daily brief and conversation; each has its own
  policy (length, boldness, cadence).
- **Writer:** turns a plan into an outline (typed, evidence on every section —
  goal 13) and a script with **two registers** — stated vs asked (goal 14).
- **Guard:** rejects any sentence whose evidence isn't in the plan
  (`guardTranscript`, which exists with zero callers).
- **Voice:** produced voice for episodes; a separate fast voice for live
  answers (goal 15, V2). The delivery path never assumes one voice.

### 2.4a The two outputs, and what feeds them (founder, 19 Oct)
Both are **hyper-personalised** from the same understanding store, by the same
planner with different policies:

| Output | Priority | Draws on |
|---|---|---|
| **Weekly episode** | first | the three lenses — **behaviour, content, time** (founder: "that is what hyperpersonalisation is") — : behaviour patterns and their trajectory (weakening / holding / worse), what moved in the 36 answers this week, said-vs-did, people, and the content they've seen — framed by their goals |
| **Daily brief** | second | what moved since yesterday, today's calendar and plans, content they've seen and saved, and things worth their attention brought in for a reason (goal 11) |

**Content they've seen** — what they watched, read, listened to, saved — is
captured as *record* (behaviour) and *reference* (saved for later). It feeds
the attention questions (18–21), the reference bank's relevance links to
their goals, and the planner's candidates. It never becomes a claim about
their inner life (trust classes, §3.1).

### 2.5 Delivery — the app
Resume, offline for what's already there, interruptible (goal 16). The app is
a client of the read routes; no logic of its own about the person.

### 2.6 Feedback
- **Corrections** (goal 20) set a claim's status to rejected and **propagate
  along evidence edges** to everything built on it, and the portrait slot.
  Rejected is never resurrected.
- **Reception log** (goal 19): what was offered, answered, skipped, kept,
  confirmed, rejected. Calibration (appetite) and the planner learn from it —
  never treated as facts about the person (P7).

### 2.7 Platform
Jobs and **events** (material arrived → interpretation runs, debounced; cron
as a safety net), the spend guard, traces and costs per person, readiness
(onboarding pipeline), lint as a scheduled guardian over every derived claim
(goal 5), privacy (deletion cascades, grant revocation), accounts.

---

## 3. The decisions that matter at the ceiling

Each: the choice, the alternative, why. These are what thin-to-thick would
have got wrong by accident.

### 3.1 Trust classes on every piece of evidence
**Choice:** each captured item carries a trust class — *own words* · *record*
(calendar, health) · *third party* (someone else's words, inbox) · *automated*
(other AI assistants, receipts, notices) · *reference* (not about you). Weight
in confidence follows the class; *automated* can support "you use X" but never
a claim about your inner life (founder, 19 Oct).
**Alternative:** today's own-words flag plus ad-hoc weights per content type.
**Why:** the bugs today (assistant summaries quoted as you; newsletters as
facts; YouTube read like journals) are all one missing concept.

### 3.2 People are first-class, with a held-ambiguity queue
**Choice:** a person entity with aliases across sources (name, email, handle),
relationships to you, and resolution that **holds** ambiguous matches rather
than guessing (goal 4). Meetings, mail and mentions attach to people.
**Alternative:** names as strings inside facts (today).
**Why:** "who you spend time with", the weekly episode's cast, outreach
collections and goal 4 all need it; it is the hardest thing to retrofit.

### 3.3 One understanding store, one read contract
**Choice:** expression reads only claims from the understanding store — never
raw content, never old tables (observations, insights, identity inferences).
**Alternative:** let the episode keep reading what it reads today.
**Why:** today's weekly episode counts the old system's own outputs ("tracked
seven times"); it can't say less than it knows if it reads everything.

### 3.4 Lineage edges, not lineage columns
**Choice:** one edge table — claim → evidence (fact, record, quote, other
claim) — that every layer writes and corrections/lint walk.
**Alternative:** evidence columns per table (today: answer_evidence,
assertion_evidence, pattern facts…).
**Why:** propagation (goal 20), hypothesis-hardening checks (goal 5) and "why
do you think that" (goal 21) are all graph walks. Existing evidence tables
stay; edges are added beside them (non-destructive).

### 3.5 Planner separate from writer
**Choice:** selection and withholding are code (testable, measurable); the
model writes prose from a plan.
**Alternative:** one prompt that selects and writes (today's cooks).
**Why:** P5 can't be measured inside a prompt; the spine-rate test (67–73%)
showed selection is where quality is lost.

### 3.6 Events first, cron as the net
**Choice:** "material arrived for this person" triggers interpretation
(debounced per person); crons catch anything missed.
**Alternative:** everything on daily crons (today).
**Why:** onboarding needed exactly this; a daily product can't wait a day.

### 3.7 A frameworks registry
**Choice:** named, cited frameworks as versioned data with explicit
applicability conditions; every why and hypothesis names one.
**Why:** goal 21's second gate and "names its framework on request".

---

## 4. Contracts between layers

| Boundary | What crosses | What may never cross |
|---|---|---|
| Capture → Evidence | durable row: source, authorship, trust class, status | network calls, retry policy |
| Evidence → Understanding | facts with spans, records, people, reference items | model output without evidence |
| Understanding → Expression | claims: class, text, confidence, status, edges | raw content, old tables |
| Expression → Delivery | a rendered episode/brief + its plan + its evidence | anything the app must decide about the person |
| Feedback → Understanding | status changes with reasons; reception events | the system's own output as a fact about you |

---

## 5. Pressure test

### 5.1 Every goal has a home

| Goal | Home | Exists today? |
|---|---|---|
| 1 Data sources | Capture + trust classes | partly |
| 2 Ingestion | Capture, per-item visibility | partly |
| 3 Making meaning | Evidence: facts with spans | yes |
| 4 Connections | Evidence: people + held queue; supersession | no |
| 5 Linting | Platform: lint over claims + edges | written, never run |
| 6 Search | Expression: query → claims + reference → receipt | no |
| 7 Reported goals | Understanding: stated goals, decay | partly |
| 8 Real goals | Understanding: said-vs-did claim | partly |
| 9 Style | Expression policy + appetite | no |
| 10 Current state | Understanding: answers + coverage | yes |
| 11 Relevance | Planner: why each item; reference relevance edges | partly (brief) |
| 12 Impediments | Understanding: answers 31–33 + patterns | partly |
| 13 Outline | Writer: typed outline, evidence per section | partly |
| 14 Story | Writer: two registers + guard | partly |
| 15 Voice | Voice: produced + fast | produced only |
| 16 Delivery | App | partly |
| 17 Acting | (last) | no |
| 18 Conversation | Expression: planner policy + session memory | no |
| 19 Learning | Feedback: reception log | no |
| 20 Correction | Feedback: status + propagation along edges | partly |
| 21 Hypothesis | Understanding: 3 gates + registry | no |
| 22 Calibration | Understanding: appetite; feedback | no |
| 23 Reference bank | Evidence: reference bank | no |
| 24 Cold start | Platform: readiness pipeline | yes (off) |
| 25 Pattern change | Understanding: pattern trajectory | no |

### 5.2 Today's real failures, designed out

| Failure found | Design answer |
|---|---|
| Two services writing the same status (2,000 lost) | Contracts: capture owns status (done, #10) |
| Deploys silently failing a day | Platform: health includes deployed version |
| Researcher blind to calendar (crowding) | Routing by source + trust class (done, #45–47) |
| New person's episode crashed (portrait shape) | Expression reads claims, not a document (3.3) |
| Weekly job silently stopped (insights) | Expression reads the understanding store, not old tables |
| Assistant summaries quoted as you | Trust classes (3.1) |
| Two episodes per onboarding | Readiness pipeline owns the first episode |
| Cost surprises | Spend guard + cost per person (done, #48) |
| Reading private content while debugging | Counts-only rule; privacy in platform |

### 5.3 Hard cases walked through
- **"Who do you spend time with?"** — calendar meetings + mail threads attach
  to people (3.2); the answer is built on people claims with counts over time,
  not on raw calendar text. Today: no.
- **"You rejected X last month, then wrote something similar."** — the claim is
  rejected; a new matching claim is held and asked about, not resurrected
  (goal 20).
- **"A hypothesis repeated in three episodes."** — lint walks edges: no
  confirmation edge → still a hypothesis; expiry retires it (goal 5).
- **"Quiet week."** — planner withholds; episode is short and says why (P1, P5).

---

## 5a. Survey results folded in

From [survey-architecture.md](./survey-architecture.md) (step 2 of the loop):
claims carry **true-when and learned-when**, and contradiction **invalidates,
never deletes** (from Zep/Graphiti); people resolution is **scored in three
bands — link / hold / separate** — with visible weights (Fellegi–Sunter);
trajectory uses a **two-window rate test** at the same bar as existence; the
planner is **greedy submodular selection with a stopping threshold** (the
threshold is the withholding ratio); the guard checks citations **exist and
entail** each sentence. Verdicts: adapt the methods into our TypeScript +
Postgres stack; adopt no library wholesale (none has the span rule or the
claim ladder).

## 6. Decision brief (stop point)

### What I recommend
Adopt this architecture as the target. Build toward it non-destructively —
new structures beside old ones, readers switched one at a time, old ones
retired only when nothing reads them.

### The weekly-podcast build path (your priority), seven steps, each gated

| # | Step | Gate (declared now) |
|---|---|---|
| W1 | Trust classes on all evidence | Test bank: assistant/notice content yields 0 claims about the person |
| W2 | People as first-class, held ambiguity | Same-name cases: 0 merges; ≥80% same-person links |
| W3 | Patterns with trajectory | On the bank's repeat cases: trajectory correct ≥ 80% |
| W4 | Understanding store read contract (claims + edges) | Episode inputs come 100% from claims |
| W5 | Episode planner (selection, spine, withholding, why-it's-here) | Spine rate ≥ 80% on the founder's weeks; withholding ratio recorded |
| W6 | Writer with two registers + guard wired | Fabricated claims 0; hypotheses-as-assertions 0 |
| W7 | Audio check with you | Your listen: "I'd listen to this voluntarily" |

Then: daily brief on the same planner → search → reference bank and Notion →
corrections and lint in full → calibration and hypotheses → conversation.

### What it costs
Weeks, not days; W2 (people) and W5 (planner) are the largest. Model cost per
user rises slightly (people resolution), offset by the planner sending less to
the writer.

### How it fails
- Over-engineering ahead of evidence: mitigated by building only the weekly
  path first and gating every step.
- Migration drag: two structures side by side for a while; mitigated by
  switching readers one at a time.

### Decisions for you
1. **Adopt this as the target architecture?**
2. **Start with W1–W7 in that order?** (Or move people (W2) after the planner
   if you'd rather hear an episode sooner.)
3. **Anything in the goal spec you want weighted differently** before it's
   locked in?
