# Goal specs

**Draft. Yours to correct.** I wrote these from the 16 goals in
[16-product-goals.md](./16-product-goals.md) plus the mission you described on
15 October 2026. They are step 1 of [decision-loop.md](./decision-loop.md) — the
thing every brief, task and PR traces back to.

Where I guessed, I guessed. Correct freely; nothing here is settled.

---

## The mission, as I have it

A companion that knows you and helps you grow. It learns on its own from what you
write and do. You can also hand it things — a link, a note, something about your
day. You talk to it in small pieces, continuously. It quietly handles the boring
admin of your life. And talking to it feels soothing rather than clinical.

Two consequences run through every spec below:

- **It is spoken to daily, not weekly.** Every error gets more chances to repeat.
  Staleness and fabrication stop being embarrassing and become corrosive.
- **The weekly episode is one output, not the product.**

---

## All 25 goals, on one page

Read this to check nothing is missing. Each links to its full spec below.

**Goals 1–16** are yours, from [16-product-goals.md](./16-product-goals.md),
rewritten for the companion mission. **Goals 17–25** are mine, derived from what
you have described since. Cut any of those that are not real.

| # | Goal | Done when | Tier |
|---|------|-----------|------|
| **3** | [Making meaning](#goal-3--making-meaning-from-data) | you write anything and the true parts come back | 0 |
| **1** | [Data sources](#goal-1--data-sources) | you hand it a link with a reason and get both back | 0 |
| **2** | [Ingestion](#goal-2--ingestion-system) | you never wonder whether something made it in | 1 |
| **4** | [Connections](#goal-4--making-connections-from-data) | it never confuses two people, never raises a quit goal | 1 |
| **23** | [Reference bank](#goal-23--the-reference-bank-new) | fifty links land, findable by your reason, and none change what it thinks of you | 1 |
| **20** | [Correction sticks](#goal-20--correction-that-sticks-new) | you correct it once | 1 |
| **5** | [Linting](#goal-5--linting-information) | it stops repeating what stopped being true | 1 |
| **22** | [Calibration](#goal-22--calibrating-to-the-person-new) | two people with identical data get different products, neither feels misjudged | 1 / 3 |
| **10** | [Current state](#goal-10--understanding-the-current-state-of-the-person) | it knows where you are today and admits what it doesn't | 2 |
| **6** | [Search](#goal-6--searching-content) | you ask anything about your life and get an answer with a receipt | 2 |
| **24** | [Cold start](#goal-24--cold-start-new) | onboarding ends with something true you recognise | 2 |
| **7** | [Reported goals](#goal-7--understanding-reported-goals) | January's marathon isn't this week's topic | 3 |
| **8** | [Real goals](#goal-8--understanding-real-goals-and-aspirations) | it shows the said-versus-did gap without editorialising | 3 |
| **12** | [Impediments](#goal-12--understanding-what-is-impeding-progress) | it names what's in your way and you don't feel accused | 3 |
| **18** | [Conversation](#goal-18--conversation-as-a-surface-new) | it feels continuous, not a new session each time | 4 |
| **9** | [Communication style](#goal-9--understanding-communication-style) | talking to it feels like relief, not a performance review | 4 |
| **11** | [Relevance & research](#goal-11--researching-and-retrieving-what-is-relevant) | it brings you something useful unasked, and shows why | 4 |
| **21** | [Hypothesis](#goal-21--hypothesis-new) | it names something you hadn't put into words, and you recognise it | 5 |
| **13** | [Outline](#goal-13--writing-an-informative-outline) | the shape traces to your actual life | 5 |
| **14** | [Story](#goal-14--writing-an-engaging-story) | nothing makes you think "that's not me" | 5 |
| **15** | [Voice](#goal-15--creating-great-voices) | you listen voluntarily | 5 |
| **16** | [Delivery](#goal-16--delivering-it-on-the-device) | you can use it standing in a queue | 5 |
| **25** | [Pattern change](#goal-25--visible-pattern-change-new) | you watch a pattern weaken, and believe it | 5 |
| **19** | [Learns from itself](#goal-19--learning-from-itself-new) | it gets better at asking, without being rebuilt | 6 |
| **17** | [Acting on the world](#goal-17--acting-on-the-world-new) | the boring things happen and you trust they happened right | last |

---

## Decisions log

Everything settled so far, so you can check it without re-reading the whole
document. All 17 October 2026 unless noted.

| Decided | Where it lands |
|---|---|
| Span rule stays the foundation; four claim classes, never blurred | [claim ladder](#the-claim-ladder) |
| Hypotheses allowed, gated on mass + framework + appetite | goal 21 |
| Never clinical — no diagnosis, disorder, trauma, pathology | goal 21 |
| Hypothesis boldness left open, resolved by your 10–15 test episodes | goal 21 |
| Cloud-heavy, thin clients; Mac and iPhone both cheap to make | [build principle](#build-principle--cloud-heavy-thin-clients) |
| **Ambient by default** — the typical user sends nothing | [ambient](#ambient-by-default) |
| Integrations are the substrate, not enrichment; onto the critical path | ambient |
| Grounding has two anchors — their words, or a structured record | [grounding](#grounding--two-anchors-not-one) |
| Two outputs: daily 9am brief, weekly episode. Different prompts, models, gates | [two outputs](#the-two-outputs) |
| Daily brief length **variable** — as long as there is something worth saying | daily brief |
| Daily brief has a per-user on/off switch, default off | daily brief |
| Fix the cost meter before daily cadence (authorised) | daily brief |
| Produced voice first; talking back is V2, with a second faster voice | goals 15, 16 |
| Input channel: **iOS share sheet direct to app** | goal 1 |
| Link tiers A and B in plan; tier C (TikTok, auth-walled) separate project | goal 1 |
| Two banks — self and reference — with a hard wall between them | goal 23 |
| Collections created by saying them aloud | goal 23 |
| Profile completeness measured by [canonical questions](./canonical-questions.md), not row counts | ambient |
| Onboarding: questions → privacy → integrations → more questions → first insight | goal 24 |
| Onboarding asked in voice, typing always available | goal 24 |
| All four sources connected at once, plus a web search on the person | goal 24 |
| External research disclosed before access is requested | goal 24 |
| No journaling push yet; weekly notification carries real personal content | goal 24 |
| Appetite from onboarding answers + integration data + a psych framework | goal 22 |
| **The user journey** — evidence → question → their answer → optionally an option | [user journey](#the-user-journey) |
| Suggestions allowed, but only after their answer, as an option, never a prescription | user journey · goal 25 |
| **Journey ships as three steps.** The option/action step deferred with goal 17 | user journey |
| Coverage thresholds set per domain, rising with the cost of being wrong | [ambient](#the-coverage-threshold--decided-per-domain) |
| Trauma: internal sensitivity flag allowed, surfacing it as a conclusion is not | goal 21 |
| Confirmed claims may be repeated to build belief; unconfirmed ones may not | goal 21 |
| Onboarding framed as a hero's journey, with an explicit commitment moment | goal 24 |
| Every integration declares which canonical questions it exists to answer | goal 1 |
| Each canonical answer is a growing-confidence hypothesis, never asked directly | [canonical questions](./canonical-questions.md) |
| One profile, two consumers; consumption modality is part of it | two outputs |
| Daily brief capped at 12 minutes, and the cap announces itself | daily brief |
| Reference items may become hypotheses, never facts — conservatively | goal 23 |
| Relevance stored with its reason, not recomputed | goal 23 |
| Control panel for tuning: good idea, explicitly after the product | [later](#later--the-control-panel) |
| Goal 17 built last; credentials stay read-only until then | goal 17 |
| Privacy architecture and on-device deferred, disclosure is not | [later](#later--privacy-and-on-device) |
| Beta: 10–30 people, all four tester types, private | — |
| **Phase 2: Option A** — answers stored with evidence; confidence earned, never asserted (18 Oct) | [brief](./brief-phase-2-question-store.md) |
| First best guess at all 36 after onboarding + integrations; quiet until confident (18 Oct) | brief |
| Ambient researcher keeps re-reading the data to strengthen or weaken each answer (18 Oct) | brief |
| False zero-sleep claims retired; portrait corrected as v89 (18 Oct) | — |

---

## The claim ladder

Added 17 October 2026, and it reorders several goals below.

The span rule stays the foundation: **a fact must be backed by your own words.**
But a companion that can only repeat what you already said cannot help you grow.
So there are four classes of claim, and they are never blurred.

| Class | Born from | Confidence | How it is said |
|---|---|---|---|
| **Fact** | a quote in your own words | highest | stated plainly |
| **Pattern** | the same behaviour repeating | high | stated, with its instances |
| **Why** | a mechanism on a live pattern | low, labelled | offered, marked inferred |
| **Hypothesis** | framework + critical mass | lowest, labelled | **asked, never asserted** |

**Extraction stays pure.** Hypotheses are never formed at ingest. They are formed
later, from a bank that is already full. This protects the one number that tells
us whether the system is honest: if inference could happen at extraction, the drop
rate stops meaning anything.

### The three gates on a hypothesis

All three must pass. Any one failing means the hypothesis is stored and not spoken.

**1. Critical mass — and it is per domain, not global.**
Enough is known about *this area* of your life to have a view. You might know
enough about their work to wonder aloud and nothing about their relationships.
Measured on live patterns in the domain, time span covered, and portrait coverage —
not on total row count.

**2. A named framework.**
A hypothesis is only an educated assumption if something educates it. A framework
is a named, cited theory with explicit conditions for when it applies — not a
vibe. It must be nameable to the user: *"I am reading this through X."* An
inference nobody can trace to a framework is a guess wearing a lab coat.

**3. The person's appetite.**
Covered by goal 22. Some people live to explore. Some need to feel completely
safe, and a hypothesis offered too early loses them permanently.

### What is never hypothesised — refined 17 October 2026

The original rule said the product never infers trauma at all. The founder's
refinement is more precise and more useful:

> "We don't want to diagnose that a person's been traumatised, that's for sure.
> But we want to be able to note — this could be an area of stress or trauma for
> this person. We need to acknowledge the possibility, but not prescribe it,
> because we're not psychiatrists."

So there are two different things, and only one is forbidden.

**Allowed — an internal sensitivity flag.** The product may hold, privately, that a
subject appears to be an area of stress or possible trauma. **It is not a claim
about the person. It is an instruction to itself about how to behave**: go slower
here, be gentler, ask rather than observe, do not push.

**Forbidden — surfacing it as a conclusion.** Never "this looks like trauma," never
"you may have been traumatised," never hedged, never as a question. No diagnosis,
disorder, or pathology, ever.

The practical difference: the flag changes *tone and pace*, never *content*. The
person experiences a product that is unusually careful about one subject and never
hears why. Which is how a thoughtful person behaves around a friend's sore spot —
they do not announce the diagnosis, they just tread lightly.

### On what kind of intelligence this is

Worth stating, because it sets the posture for everything above.

> "A language model observing someone's behaviour ambiently is a very smart
> structure. It doesn't have the same intelligence a psychiatrist or a researcher
> might. We need to acknowledge that we are going to hypothesise about the person
> — but only deliver it according to the rules."

That is the right self-assessment, and it is why the delivery rules are strict
while the internal reasoning is allowed to be ambitious. **Think freely in
private; speak carefully in public.** The gap between those two is not dishonesty
— it is the appropriate humility of a system that sees a great deal and
understands less than it sees.

### Repetition — how a true thing comes to be believed

Added 17 October 2026, from a founder question that nothing else in this document
addressed:

> "How often does this person need to be reminded of these ideas for them to start
> believing them — the ideas of self-trust, self-esteem."

A real mechanism, and a necessary one. Someone hearing a true thing about
themselves once does not absorb it. Belief takes repetition and pacing.

**But this sits one inch from the failure that goal 5 exists to catch**, so the
line has to be exact:

| Repeating this | Is |
|---|---|
| an observation the person **confirmed** | reinforcement — the mechanism, and good |
| a **fact** with new evidence each time | legitimate, and the evidence grows |
| an **unconfirmed hypothesis** | manufacturing belief, and forbidden |

The difference is consent. Returning to something someone has agreed is true helps
them hold onto it. Returning to a guess until it feels true is how a system talks
someone into a story about themselves.

**So:** confirmed claims may be revisited deliberately, paced, and tracked — how
often, and whether it is landing. Unconfirmed ones get asked about again, not
asserted again. And the pacing is per person, through goal 22.

### How a hypothesis is delivered

As a question, always. Your own research is the reason: AI-generated goal
*suggestions* produced no measurable effect, progress is mediated by **felt
accountability**, and AI-authored goals were more specific but less owned. The
sequence the literature supports is *notice → what do you think → it might be
this → what would you do* — and only when the person can actually answer.

So a hypothesis is an offer. The person's response to it is data twice over: about
the hypothesis, and about their appetite for the next one.

---

## Build principle — cloud-heavy, thin clients

Decided 17 October 2026.

As much as possible lives in the cloud. Clients capture and render; they do not
think. The point is that **a Mac app and an iPhone app should both be cheap to
make**, because testing needs to happen on both.

Consequences that bind every spec below:

- No intelligence in a client. Ever. A client that reasons is a client that has to
  be rebuilt per platform.
- All state server-side. A client holding its own model of the person is a second
  source of truth, and the two will disagree.
- The API is the product boundary. Every surface — Mac, iPhone, web — is a
  consumer of the same endpoints, with no privileged path.
- Offline is a cache of what the server already said, never a place where new
  conclusions are formed.

This is close to what already exists: the agent thinks, the phone is a client. The
change is making it a rule rather than an accident, and adding a Mac target.

---

## Ambient by default

Decided 17 October 2026, and it reverses an assumption running through earlier
drafts of this document.

**The default user sends nothing.** No links, no progress texts, maybe no
journals. Most people will not do those things, and the product has to be good
anyway.

> "We want this to be ambient and proactive and super relevant to them based off
> the onboarding, data sources, and ongoing intelligence of what we learn from
> them... none of this is necessary. We should make this as smart as possible
> without this information."

So the hierarchy inverts:

| | Was treated as | Actually is |
|---|---|---|
| Onboarding + integrations | enrichment | **the substrate** |
| Journals | the substrate | valuable context |
| Links and progress texts | the substrate | power-user bonus |

### Three consequences

**1. Integrations move onto the critical path.** Earlier drafts said hold them
until extraction is measurable. That was right when journals were the input. It is
wrong now — if passive data is the substrate, the connector fleet is the main
pipeline, and it currently has zero rows and has never run.

**2. A confidence threshold before it speaks**, and it is measured by the
**canonical questions** — see [canonical-questions.md](./canonical-questions.md).

Thirty-six questions about a person. Coverage is the share we can answer at all;
accuracy is the share they confirm. The ambient brief starts when coverage crosses
a threshold for a domain, rather than after an arbitrary warm-up.

This replaces row counts everywhere they appear in this document. It also ranks
the connector backlog — a source is worth exactly the questions it answers — and
gives goal 21 a real definition of critical mass.

**The number that direction costs:** thirteen of the thirty-six can only be
answered by the person's own words. A purely ambient product answers about
two-thirds, and the missing third is *why*, *feeling* and *meaning*.

### The coverage threshold — decided, per domain

You asked. **Per domain, not global**, and the bar rises with how much damage
being wrong does.

Domains are the canonical question groups. Starting numbers, to be tuned once
coverage is actually measurable:

| Domain | Bar to speak about it | Why |
|---|---|---|
| Who they are | **50%**, low confidence floor | Mostly factual. Being wrong is a correctable annoyance. |
| What they actually do | **60%** | Records-based, so it fills fast and is easy to verify. |
| Their attention | **60%** | Same. |
| What they want | **70%**, higher floor | A wrong goal makes every brief wrong. |
| The people in their life | **70%** | Getting a relationship wrong is memorably bad. |
| How they are | **80%**, highest floor | The most sensitive, the fastest-decaying, and the easiest to get offensively wrong. |
| What is in the way | **80%** | This is where it tells someone something hard. It should have earned it. |
| How to speak to them | **always active** | Goal 22 runs from the first minute at its safe default. |

Three rules around the numbers:

- **A domain below its bar is silent, not approximate.** The brief simply does not
  go there.
- **Domains unlock independently.** Talking confidently about someone's work while
  saying nothing about their relationships is the correct behaviour, not an
  incomplete one.
- **The bar is for *speaking*, not for *knowing*.** Hypotheses accumulate
  underneath regardless; the threshold governs what comes out.

**3. The grounding rule has to generalise** — see below.

### Two mechanical rules for an ambient system

I had flagged ambient-plus-proactive as a creepiness risk. **The founder's call,
17 October 2026: not a concern, and not something to design around.** Noted and
dropped as a product risk.

Two rules survive on their own merits, because they are cheap and they make the
product better rather than safer:

- **It says where something came from** when asked, always. "How do you know
  that" has a real, specific answer. This is the same requirement as every other
  claim in the system carrying its source.
- **It never implies it was told something it inferred.** Observing a calendar gap
  is not the same as being told about a hard week. This is the claim ladder, not a
  separate rule.

## The IKEA effect — how everything gets delivered

Founder's principle, 17 October 2026, and it is the delivery rule for the whole
product:

> "Gently bring up the kinds of data points that allow them to realise it for
> themselves... here are seven or eight things we noticed that we feel might be
> getting in the way of your progress — but what do you think that is? We want the
> user to take the data points we present and find their own solutions. We don't
> want to prescribe... lead the user to find their own conclusions, but do all the
> work before that."

**"Introspection, externalised."** That is the product in two words.

### Why this matters more than it sounds

It converges exactly with what the research says works, which is worth noting
because the two arrived independently:

- AI goal **suggestions** produced no measurable effect (N=543).
- AI-authored goals were more specific but **less owned** (N=470).
- Implementation intentions are strongly effective — d=0.65 — **but only when the
  person forms them.**
- Progress is mediated by **felt accountability**, not advice quality.

So the IKEA instinct is not a style preference. It is the only version the
evidence supports. A product that prescribes is doing the measured-ineffective
thing; one that assembles the evidence and hands over the conclusion is doing the
effective thing.

### What it requires in the build

- **The work happens before the conversation, not in it.** Seven or eight real
  data points, assembled, grounded, ready. The product does the labour; the person
  does the thinking.
- **It ends in a question**, and the question has to be answerable. "What do you
  think that is" only works if they can actually see what prompted it.
- **No verdicts.** Not "you are avoiding this" — the evidence, then the question.
- **Their answer is the valuable output**, and it is also a word source for the
  reasons the product cannot derive on its own. The IKEA mechanism and the
  words-gap fix are the same mechanism.

---

## The user journey

The core interaction loop of the whole product. Settled 17 October 2026, and the
founder's words for it: *"this is a better user journey."*

> **Evidence → question → their answer → then, optionally, an option.**

That is the order, and the order is the whole thing.

### What ships now: the first three steps

Founder's call, 17 October 2026:

> "Eventually this is a strong selling point, but it needs to come later, since we
> aren't working on actions yet."

So the loop ships as **evidence → question → their answer**. Step four is
specified here, and deferred.

Three reasons that is the right cut rather than a compromise:

- **Steps one to three are where the value is.** The product assembles the
  evidence, asks the real question, and captures the answer. That is introspection
  externalised, complete, with nothing missing.
- **It requires no new infrastructure.** No action layer, no integrations with
  write access, no approval flow. It runs on the bank and the brief.
- **It is the strongest position the research supports.** With no suggestion step
  at all, there is nothing that could crowd out the person's own thinking. The
  version that ships first is the version with the cleanest evidence behind it.

And their answer still gets held onto and returned to — *you said last week you'd
move it to mornings; how did that go* — which is the accountability mechanism
without any action capability at all.

**Step four arrives with the action layer**, alongside goal 17 and the later part
of goal 25. Worth building then, and worth selling then.

**Why it works, and why the obvious version does not.** The measured failure in the
research was suggestions offered *instead of* the person's thinking. A suggestion
offered *after* they have engaged and answered is a different act entirely — the
goal is already theirs, and the suggestion helps them execute rather than
substituting for ownership.

**The four rules that keep it honest:**

- Multiple perspectives, never one prescribed answer.
- An easy no.
- **Never an option where a question was not asked first.**
- The action layer comes last in the build. It is the closer, not the opener.

### This is not one goal's policy

It is how every hard thing gets delivered, everywhere:

| Goal | The same loop |
|---|---|
| **12** — impediments | evidence of the pattern → what do you think is going on → their reason → optionally, something to try |
| **21** — hypothesis | what we noticed → does this land → their correction → the hypothesis settles or dies |
| **25** — pattern change | three Thursdays → what would make next week different → their plan → held to their own answer |
| **9** — how it speaks | the tone that makes a question feel like an invitation rather than an audit |

Goal 9 is not a fifth case. It is the thing that makes the other three land, which
is why it is the hardest and the least measurable.

### On the clinical question

The non-clinical rule in goal 21 stays, with its reason restated accurately: it is
not squeamishness, it is that **prescribing a cause is the opposite of the IKEA
effect.** A product that names a pathology has taken the conclusion away from the
person. The founder's own delivery principle enforces the line more strictly than
my caution did.

Separately: selling into clinical settings is a stated future direction. That is a
regulatory question — clinical claims put a product in medical-device territory
with an evidence burden attached — and it is a conversation for when it is real,
not a constraint on this build. The ACE finding stands regardless of ambition,
because it is about that instrument being harmful when self-administered, not
about who the customer is.

## Grounding — two anchors, not one

The span rule generalises rather than bending.

A fact must be backed by **a verifiable source**, which is one of:

1. **A quote in the person's own words** — the original rule, unchanged.
2. **A structured record** — a calendar event, a health figure, a screen-time
   total. Grounded in the row, checkable against it, not inferred.

Both are verifiable. Neither is a guess. What changes is what they can support:

- A record supports *what happened*. It never supports *why*, or *how it felt*.
- Only words support a claim about wanting, feeling or meaning.

The existing source weights already encode this — journal 1.0, calendar 0.4,
health 0.15 — which means the architecture anticipated it. What was missing was
saying so.

**The sharp edge.** "Skipped the gym three Thursdays" from a calendar is a real
pattern. It supports no why whatsoever. "I skipped because I was exhausted"
supports one.

### The reasons are the product, not a nice-to-have

Founder's correction, 17 October 2026, and it reverses how I had framed this:

> "The reasons for their behaviour are really, really important, because that is
> what we're trying to dissect and dissolve... why they exhibit a certain
> behaviour allows us to understand if it's maladaptive or not."

I had written the words gap as *the cost of going ambient* — something to accept
and report honestly. That is wrong. **The gap is the thing the product exists to
close.**

Which changes several things:

- **Goals 12 and 21 move up in importance.** The why layer is not a late refinement
  on top of a behaviour tracker; it is the point. A product that only ever reports
  behaviour has not done its job, however accurate it is.
- **The thirteen word-dependent canonical questions are the most valuable
  questions, not the hardest ones.** They were listed as the awkward residue. They
  are the goal.
- **Eliciting words becomes a first-class job.** Not a journaling prompt — a
  question asked inside the brief, about something specific the product actually
  noticed and genuinely cannot resolve on its own. One good question a week beats
  another month of calendar data.
- **Records are the setup, words are the payoff.** Passive data finds the pattern
  and earns the right to ask about it. The answer is what makes it usable.

What does *not* change: a record still cannot support a why. The rule stays —
behaviour from records, reasons only from words. What changes is that we now go
and get the words rather than noting their absence.

---

## The two outputs

Defined 17 October 2026. This is the product shape, and it reframes goals 13–16.

There are **two audio products**, not one, and they do different jobs.

### Daily — the 9am brief

**Clarified 17 October 2026, and it is not a link reader.**

The inputs, in order of how much the product can rely on them:

- **what your sources show** — calendar, mail, screen time, health, profile. Always
  present. The substrate.
- **your goals** — the actual goals model
- **what you care about** — the portrait
- **who you are** — and what you are trying to become
- **what you journalled** — when there is any
- **what you sent** — links, articles, videos. A bonus, never assumed.

The brief must be worth hearing when only the first four exist.

The output is one episode that tells you exactly what you want to know, framed in
who you are and where you are trying to get to.

So the content is external; the **selection, ordering and framing are entirely
about you.** An article is covered because it bears on something you are trying to
do, and the brief says why. The same five links sent by two different people
produce two different episodes.

Reads from the **reference bank** for material and the **self bank** for framing.

### Length — capped at 12 minutes, and the cap is visible

Revised 17 October 2026. An earlier draft of mine suggested a four-minute
ceiling. That was wrong for the case that matters most.

> "Four might be too short for growth periods in people's lives, for power users.
> The average user, yeah, probably four to five minutes. But don't cap it
> strictly, because I want to use this too."

- **Cap: 12 minutes.** Not a target.
- **Typical: 4–5 minutes**, arrived at by having nothing more worth saying rather
  than by truncation.
- **Floor: around 45 seconds.** Below that, say less and stop.

**The cap announces itself.** When the brief hits 12 minutes, it says so, and says
what it left out and why. *"There was more here — three more pieces on the funding
thing — but I'm capped at twelve minutes."*

That turns an arbitrary number into a measurable one. If the cap is being hit
every day during a reading-heavy week, that is evidence 12 is wrong, and the
product reports it rather than silently trimming. Same principle as the drop rate:
**a constraint nobody can see is a constraint nobody can tune.**

**What it costs, stated plainly.** Twelve minutes is roughly 10,000 characters of
speech — about $3 a day, near $90 a month, for one user at the cap. A power user in
a growth period will sit at the cap. That is the number to watch once the meter is
fixed, and it is the strongest argument for the per-user monthly cap being a real
feature rather than a safeguard.

### Relevance is scored, not assumed

Added 17 October 2026. The brief's job is selection, so selection has to be
measurable.

**Every candidate item is scored against this person's goals before it is
included.** Not "is this interesting" — *is this relevant to what we know this
person is trying to do.*

**Must.**
- An item that scores below the bar is dropped, even on a thin day. Padding with
  the irrelevant is how the brief becomes boring, and boring is how it dies.
- The brief can say *why* something was included — which goal or thread it bears
  on. If it cannot, it should not be in there.
- Items dropped for irrelevance are logged, so the bar itself can be tuned.
- **Relevance is per person, not global.** The same article is essential for one
  user and noise for another. That is the entire product.

**Metric.** Share of included items the person finds relevant, against the share
the scorer predicted. Divergence between those two is the signal that the goals
model is wrong, not that the scorer is.

### The daily brief has an on/off switch

Decided 17 October 2026. Per user, and it does three jobs at once:

- **Consent.** Proactive daily audio is intrusive by nature. Being able to stop it
  in one tap is what makes it acceptable to receive at all.
- **Cost control.** Daily audio is the dominant cost line. A toggle is the burn
  rate's off switch — at thirty testers that is roughly $750 a month under your
  direct control.
- **Staged rollout.** On for the founder first, then selectively for testers.
  Nobody gets daily audio before someone has judged whether it is any good.

Default for a new user is **off**, turned on deliberately. A product that starts
speaking to you every morning before you asked is the version that gets deleted.

### Two prerequisites before daily cadence turns on for anyone

1. **Fix the cost meter.** Authorised 17 October 2026. Three pricing bugs in the
   agent's trace layer: Anthropic billed at Opus rates while every cook runs
   Sonnet, OpenAI billed at full rates while Cook A runs a mini model, and
   ElevenLabs characters multiplied by an extra thousandth. The net effect
   overstates thinking and understates speech — backwards for a product about to
   speak every day.
2. **Length discipline on the audio.** Since speech is 20–40× the cost of the
   thinking behind it, runtime is the cost lever. It also happens to be the
   quality lever.

### The consequence that changes the build order

Framing a daily brief around *where this person could be in life* requires the
goals model to make **the most intelligent assumptions it can** about what someone
truly wants — not only what they stated.

That is goal 8 and goal 21. Which means **hypothesis is load-bearing for the daily
output**, not only the weekly one, and cannot sit at the end of the queue.

It also means the daily brief is **not** purely external content, so the claim
ladder still applies to it: material from a source may be summarised freely,
while any claim about *the person* obeys the same rules as everywhere else.

### Weekly — the real episode

The intense one. Behaviour patterns, performance against goals, reflection.

Reads mostly from the **self bank** — facts, patterns, why, portrait.

### One profile, two consumers

Stated 17 October 2026 because it was implied and never written: **both outputs are
measured against the same profile.** The daily brief is judged against who you are
and what you care about exactly as the weekly episode is. There is one
hyper-personalised model of the person, and two things that read it.

What differs is which *bank* each one draws material from. What does not differ is
whose profile decides what matters.

A second personalisation model for the daily brief would drift from the first
within a month, and the two outputs would start disagreeing about the same person.

### How they consume it is part of the profile

Delivery is not packaging. Some people absorb by reading, some by listening, and
the same content lands differently depending on which.

**Must.**
- The profile holds a consumption preference — audio, text, or both, and at what
  length.
- Determined by **both** asking and observing: onboarding asks directly, behaviour
  corrects it. Did they finish the audio or skim a transcript. Stated preference
  outranks inferred, as everywhere else.
- **Applied to onboarding itself**, not only afterwards. If someone says they
  prefer reading, the rest of onboarding should not be spoken at them.
- Both forms of every output exist. An episode has a readable version; a written
  brief can be spoken.

**Metric.** Completion rate by modality, against stated preference. A large gap
means the stated preference is wrong or the other form is badly made.

### Why the two outputs map onto the two banks

The two outputs map almost exactly onto the two banks. That is a strong signal the
split in goal 23 is the right one: the banks are not a complication, they are the
two products.

| | Daily brief | Weekly episode |
|---|---|---|
| Reads | reference bank | self bank |
| Input | links you send | progress you text |
| Claim classes | facts from sources | facts, patterns, why, hypothesis |
| Fails by being | boring | wrong about you |
| Cost | every day, per user | once a week |

### They must not share a prompt, a model, or a quality gate

The failure modes are opposite, so the engineering is opposite.

**Daily fails by being boring.** A bland brief costs attention. Recoverable —
regenerate it, nobody is hurt. It needs creative latitude to find a through-line
and a check that asks *does this have a spine.*

When there is genuinely nothing important, **a short brief is the right answer**,
not a padded one.

**Weekly fails by being wrong.** A wrong claim about someone costs trust, and
"that is not me" does not recover the way "that was dull" does.

### Correction — conservative about claims, never about craft

Founder's correction, 17 October 2026. An earlier line of mine said the weekly
episode needs "conservative generation." That conflated two different things:

> "The facts, and what you tell the person they are — we're very, very careful
> about that. But engagement-wise, tone-wise, delivery-wise it needs to be super
> inviting... really well written and captivating, and in their style.
> Conservative is not the way we want to do it over here."

| | Posture |
|---|---|
| **What is claimed** | maximally careful — grounded, hedged where hedging is honest, nothing asserted that is not supported |
| **How it is written** | maximally captivating — well made, in their idiom, genuinely good to listen to |

These are not in tension, and treating them as one dial is the error. Hedged
content delivered flatly is just vague. Precise content delivered beautifully is
the entire product.

So the grounding check applies to **claims only**, and must never be allowed to
sand down the prose. A guard that flattens the writing has broken the thing it was
protecting.

Specifically: the transcript guard is a *grounding* check. Correct for the weekly
episode. Pointed at the daily brief it would strip exactly the framing that makes
the brief worth hearing.

The trap is that both read as "write audio about the user," so one prompt looks
like sensible reuse. It averages them — a weekly that is too loose and a daily
that is too stiff.

### The input that feeds the weekly one

Texting progress, continuously. *"Did this, did that, this is where I am."* That is
the primary journaling mode now — not long-form entries. It changes what
extraction sees: many short fragments rather than a few paragraphs, which is a
different shape of input and may well extract better.

### It must work for someone who sends almost nothing

Stated requirement, and it is the harder case. The founder is an aggressive power
user. A normal user sends three links a week and texts twice.

Both outputs must degrade to something honest and short rather than padding to
fill a runtime. A daily brief with nothing to brief on should say so in fifteen
seconds, not generate four minutes of filler.

---

## How to read a spec

**Is** — what the goal means under the mission.
**Must** — the performance requirements. These become the gate at step 3.
**Done when** — stated as something you can do that you cannot do today.
**Metric** — the number declared before any survey, per the validation gate.

---

## Tier 0 — foundation

Nothing above this tier is measurable until these hold.

### Goal 3 — Making meaning from data

**Is.** Turning what you wrote into findable claims, without inventing and without
dropping.

**Must.**
- Never assert anything not supported by a quote from your own words.
- Never silently drop. Every discard has a recorded reason.
- Every domain of your life has somewhere to land — work and ideas included, not
  just habits and feelings.
- A long entry is read to its end.
- Capture and analysis stay separate: banking a thought must not promote it to a
  claim about who you are.
- **Produce facts only. No inference at this layer, ever** — not even hedged.
  Hypotheses are formed later, from a full bank, by goal 21. If inference can
  enter here, the drop rate stops being a truthfulness signal and the whole
  measurement collapses.

**Done when.** You write five paragraphs about anything at all, and the true parts
of it come back to you later.

**Metric.** Recall against bank expectations; false-positive rate; drop rate with
reasons. A method wins by raising recall without raising false positives.

---

### Goal 1 — Data sources

**Is.** Three things that were one goal. **Passive** sources you connect once.
**Pointed** input — handing it a link, a screenshot, a note about your day. And
**intent** — what you want done with the thing you just handed over.

That third part was missing and it changes the design. "Here is a TikTok, I want
this to be a script for a set of videos" is not a capture. It is a capture plus a
purpose, and the purpose is the more useful half.

**Must.**
- Pointed input: from intent to captured in under ten seconds.
- **An intent note travels with the item.** Why you sent it, in your words, stored
  alongside it and never paraphrased away.
- A new source type does not require a schema change.
- Nothing fails silently. If it did not land, you are told at the time.
- **If it cannot read the link, it says so and keeps the link.** It never pretends
  to have understood something it could not open, and it never quietly drops it.
- Everything captured is traceable to where it came from.

**Done when.** You can hand it a link with a sentence about why, and later ask
about either the content or your reason, and get both back.

**Metric.** Pointed-capture success rate; time from hand-over to retrievable;
share of items that retain their intent note.

### The integrations approach

Written out 17 October 2026 to confirm alignment, because several threads need
reconciling and one of them changes the plan.

**Sources fall into three kinds, and only the first is a "connector" at all.**

| Kind | Sources | Where the code lives |
|---|---|---|
| **1. Server-side OAuth** | Google (all of it), Notion, Linear, Slack | the agent |
| **2. On-device iOS** | HealthKit, Screen Time, Contacts, Photos | **the iOS app — no server API exists** |
| **3. One-shot import** | Apple Notes, Granola, ChatGPT/Claude archives, Google Takeout | either |

**This is the part worth catching now.** HealthKit and Screen Time have **no
server-side API**. They are on-device frameworks, and Screen Time's
(`DeviceActivity`) is tightly restricted by Apple. They cannot be a connector,
cannot go through Composio, and cannot be built in the agent. They are iOS work
that uploads to the agent.

So "connect four sources" is really: one OAuth connector, two pieces of native iOS
code, and a profile lookup. Budget accordingly.

**LinkedIn sits awkwardly.** The official API is restrictive about profile data.
Its value for cold start is real, so it is worth checking what is actually
obtainable before relying on it — and a web search on the person may do the same
job with less integration work.

### Direct versus Composio

- **Google: direct.** It is the substrate, it is three sources in one, sent-mail
  bodies are the valuable part, and it is already partly built. Its data shape
  should not come through someone else's abstraction.
- **The long tail: Composio**, pending the audit. One question decides it —
  whether it returns usable message bodies or only metadata.
- **On-device sources: neither.** Native, by necessity.

### Connected together, built one at a time

These two instructions are not in conflict, and it is worth saying so explicitly:

- **The user connects everything at once.** Five or six buttons on one onboarding
  page, framed as *help us understand you* — with a meter showing how well we know
  them, which is canonical-question coverage made visible.
- **We build them one at a time.** Pick one source, pass real data through the
  entire chain, understand what came out, review, ship, then the next. Per the
  [decision loop](./decision-loop.md).

The UI presents a single moment. The engineering is strictly serial. Nothing about
the onboarding page requires the connectors to be built simultaneously, and
building them simultaneously is how you end up debugging four broken chains with
zero rows ever written.

**The integrations page is a product surface, not an admin screen.** Founder's
instruction. It should feel like *tell us more about you so we can actually be
useful*, with visible progress — not like a settings pane.

### The wider source catalogue

Expanded 17 October 2026. Ranked by **questions answered per unit of work**, not
by how impressive the logo is. Question numbers refer to
[canonical-questions.md](./canonical-questions.md).

#### Tier 1 — build these after Google

| Source | Questions | Why it earns its place |
|---|---|---|
| **Meeting transcripts** — Granola, Otter, Fathom, Zoom | 22, 24, 27–29, 31–33 | **The best source after Google, and possibly including it.** Spoken words, unguarded, about real situations with real people. It answers the expensive thirteen directly. The founder already uses Granola. |
| **Readwise** | 18, 19, 21 | Highlights are *deliberate* attention — someone stopped and marked this. Far higher signal per row than browsing, and a clean API. Also carries Kindle. |
| **GitHub** | 2, 7, 13, 14, 16 | For a founder, the record of what they actually built versus what they said they would. Commit cadence, abandoned branches, what they keep returning to. Excellent API. |
| **Spotify / Apple Music** | 15, 18, 30 | Rhythm and mood proxy, with time-of-day resolution nothing else has. Cheap to add, and it answers "when are they at their best." |

#### Tier 2 — good, with more friction

| Source | Questions | Note |
|---|---|---|
| **Whoop / Oura** | 15, 17, 30 | Sleep and recovery, which is a much better read on *how someone is* than step count. Both have APIs. |
| **Linear / Jira** | 7, 8, 13, 14 | Planned versus shipped, formalised. Strong for the stated-versus-real gap. |
| **Slack** | 22, 24, 26, 29 | A large words source, but workspace-scoped and needs admin consent — organisational friction rather than technical. |
| **X / Twitter** | 18, 19, 29 | Public writing plus what they engage with. API pricing is the obstacle, not capability. |
| **Shiori** | 18, 19, 21 | Already in the founder's own stack. Self-hosted read-later, so no third party and no rate limit. |

#### Tier 3 — high signal, and they need their own conversation

| Source | Questions | Why it is held back |
|---|---|---|
| **Banking via Plaid** | 7, 8, 20 | Spending is the purest revealed preference there is — what someone actually values, unmediated by what they say. Also regulated, deeply invasive, and deserving of a separate consent conversation rather than a button among five. |
| **Browser history** | 18–21 | Answers attention questions well. Feels the most surveilled of anything on this page. |

#### What cannot be an integration

Worth listing so nobody plans around it:

- **iMessage and WhatsApp.** No API for personal messages. The richest words in
  most people's lives, and unreachable.
- **Google Keep.** No public API.
- **Instagram and TikTok feeds.** No API — the tier C link problem.
- **Location and YouTube history.** Takeout export only, not a live sync.

#### The ordering rule

Add the source that answers the most **currently unanswered** questions, measured
rather than argued. Once coverage is instrumented this stops being a matter of
opinion: a source either moved the number it promised to move, or it did not.

Which also means this catalogue is a backlog, not a roadmap. Several of these may
turn out to be redundant once Google and meeting transcripts are in — if sent mail
and spoken transcripts already answer how someone talks, Slack adds volume rather
than knowledge.

### Each source has a stated extraction intent

Founder's instruction, 17 October 2026: a connector can be general purpose, but
**we should be deliberate about what we actually take from each one.**

So every integration declares, in writing before it is built, **which canonical
questions it exists to answer.** Not "sync Gmail" — *Gmail is here for questions
22, 24, 26 and 29, and sent-mail bodies are the reason.*

Why this matters beyond tidiness:

- It stops generic ingestion. A connector pulling everything produces volume
  nobody reads and a drop rate nobody can interpret.
- It makes a connector's value measurable: did coverage on its stated questions
  actually move after it shipped.
- It is the ordering mechanism. Build the one that answers the most unanswered
  questions next.
- It bounds what we take. A source that cannot answer a question we care about has
  no business sending us that field, which is also the cheapest privacy posture
  available — collect less because less is useful, not because a policy says so.

### Google means all of Google

Decided 17 October 2026: Calendar, Gmail, Drive and Docs, Contacts, Tasks — the
whole surface, not a slice.

Which canonical questions each part is there for:

| Source | Questions it exists to answer |
|---|---|
| **Calendar** | 12–16, 22, 25 — what a week looks like, what they reliably do and avoid, who they spend time with |
| **Gmail metadata** | 22, 25, 26 — who, how often, who disappeared, who they answer to |
| **Gmail sent bodies** | 27–29, 6, 24 — how they talk, what they care about, who they talk to when it is hard. **The expensive third of the list.** |
| **Drive and Docs** | 2, 21, 29 — what they are building, what they are learning, how they write while thinking |
| **Contacts** | 22, 26 — disambiguating people, and the alias namespace for goal 4 |
| **Tasks** | 6, 9 — stated intentions, and what gets abandoned |

### The constraint that actually matters here

Not the API surface — the **OAuth scopes.** Full Gmail access and broad Drive
access are *restricted scopes*, and Google requires a **CASA security
assessment** for them: performed by a Google-empanelled assessor, including a DAST
scan against production, and **repeated annually.**

**The beta is unaffected.** An app in *Testing* publishing status is capped at
[100 test users](https://developers.google.com/identity/protocols/oauth2/production-readiness/overview),
which covers 10–30 testers with room to spare. No verification needed to run the
beta.

**Public launch is gated.** Before anyone outside the allowlist can connect Gmail
or Drive, that assessment has to pass. Secondary sources cite roughly six weeks
from Google's own FAQ, with assessor costs in the hundreds to low thousands. It is
not a blocker now; it is a thing with a lead time that should start before it is
urgent.

**What to do about it in the build:** request the **narrowest scope that answers
the questions in the table above**, and nothing wider. One developer reported
narrower Drive scopes dropping their verification burden substantially. This is
the same discipline as the extraction-intent rule — take only what answers a
question — and here it has a direct commercial payoff.

**Honest sourcing note:** the 100-user cap is from Google's own documentation. The
CASA details, timeline and costs came from vendor and developer blogs, not Google,
and the sources disagreed on assessment tiers. Confirm against Google's own
verification pages before planning around the numbers.

**And "everything" has real gaps.** Keep has no public API. Location and YouTube
history are Takeout-only exports, not live APIs. Those are not oversights to fix
later — they simply cannot be synced.

### Fetchability tiers

Links are not one problem. They are three, and only the first two belong in this
engineering plan.

| Tier | What | How | In this plan? |
|---|---|---|---|
| **A** | articles, blog posts, public docs, PDFs, repos | plain HTTP request | **yes** |
| **B** | YouTube, podcasts, anything with a published transcript | transcript API | **yes** |
| **C** | TikTok, Instagram, anything behind auth or video-only | browser automation or computer use | **no — separate project** |

Tier C has nothing to do with the brain's logic. Its failure modes are bot
detection, auth walls, rate limits and layouts that change weekly. Mixing it into
this plan would mean brain work blocked on a scraper.

**But the shape must be decided now**, because a tier C item eventually lands in
the same place a tier A item does. Design the destination early, build the
plumbing late.

---

## Tier 1 — integrity of the bank

A companion spoken to daily cannot afford a bank that rots.

### Goal 2 — Ingestion system

**Is.** The guarantee that "saved" means the brain has it. Largely built.

**Must.**
- Survive worker death without losing or duplicating work.
- A retry can never clone what is already there.
- Every row reaches a terminal state. Nothing sits half-processed.
- A backlog drains on its own, without hand-written SQL.

**Done when.** You never have to wonder whether something made it in.

**Metric.** Rows in a non-terminal state after 24 hours: zero. Duplicate rate:
zero.

---

### Goal 4 — Making connections from data

**Is.** The same person stays one person. A contradiction resolves rather than
accumulating.

**Must.**
- Two people with the same first name never merge.
- An ambiguous name is held for resolution, never guessed.
- Quitting something retires the goal it contradicts.
- An older claim can never retire a newer one.
- This week continues from the weeks before it.

**Done when.** It never confuses two people you know, and never raises a goal you
already abandoned.

**Metric.** Identity errors on the bank's same-name cases: zero. Stale-serve rate
on the contradiction cases: zero.

---

### Goal 23 — The reference bank *(new)*

**Is.** A second store, for material that is **not about you**. Links, articles,
people to reach out to, investors, jobs, things to look into, a video you want to
make something out of.

This is a genuinely separate bank, and the reason is the grounding rule. The self
bank holds claims about you, grounded in *your own words*. A reference item is
grounded in **its own source** — an article's claim is the article's, not yours.
Same span discipline, different anchor.

**Must.**
- **Organised into areas you define** — outreach, investors, video ideas,
  research, whatever you actually use. Not a single undifferentiated pile, and not
  categories I invented for you.
- **Sorted on arrival**, into an existing area where one fits, and into a held
  tray when nothing does. Never guessed into the wrong place silently.
- **The intent note is first-class.** Searchable, and often the most valuable
  field — your reason for saving something outlives the thing itself.
- **People in here are people, not entities about you.** A name on an outreach
  list is not someone in your life, and must not acquire a significance score as
  though it were.
- **A diagnostic view**: per content type and per area, how much arrived, how much
  was readable, how much got sorted correctly, what is sitting in the held tray.
  `pipeline-canvas` already exists for exactly this shape of surface.

### Collections declared by speaking them

Added 17 October 2026 and it is the most distinctive part of this goal.

Saying *"I'm going to keep sending you a list of investors I want to speak with"*
creates the collection. No settings screen, no schema decision, no form. The next
thing sent lands in it.

**Must.**
- A sentence of intent creates a named collection, and says so, so you know it
  understood.
- It infers **which project** the collection belongs to from what you are currently
  working on. An investor list is for the thing you are raising for.
- **Columns emerge from the items, not from a guess.** The temptation is to invent
  a nine-column investor table up front; seven of them would be permanently empty.
  Start with the name and the intent, let structure accrete as real items arrive.
- Ambiguity is asked about, once, cheaply. *"For Retrospect, or something else?"*
- Collections can be renamed, merged and deleted by you. Auto-created structures
  that cannot be undone become clutter within a month.

**Relevance is answered and stored, not recomputed.** Added 17 October 2026, and it
is what makes this a brain rather than a bookmark folder:

> "If I send you a link for a bunch of articles — yeah, save the link, but also:
> this article is relevant to this goal in this way, and save that. I want the
> answer to the question of how the content is relevant to the person."

So saving an item writes two things: the item, and **a reasoned link between that
item and whatever it bears on** — a goal, a pattern, a project — in a sentence.

- Every stored item can answer *why is this here* without being asked again.
- The brief reads that link rather than re-deriving relevance every morning.
- A reference item with no link to anything is a flag: either the relevance
  judgement failed, or it genuinely does not belong.
- A collection's structure accretes from these links. If every saved investor has
  a stage and a thesis-fit note, those become the collection's columns — the
  structure is discovered rather than designed.

Where this lives is an engineering decision, left to me. My intent: an edge with a
reason, not a column on the item, so one item can bear on three goals differently.

**Done when.** You declare a list in passing, send things to it for two weeks,
never open a settings page, and the product can tell you why each thing is in
there.

**Metric.** Share of declared collections correctly created on first attempt;
share attached to the right project; collections never used after creation
(a proliferation signal).

**The wall — revised 17 October 2026 from a wall into a gate.**

The original rule was absolute: nothing in the reference bank may ever become a
claim about you. The founder's amendment:

> "If someone sends you a reference, that's a very high-intent action. They really
> cared, they really sent this to you — that literally matters... I don't want this
> to be a hard wall. But be very, very conservative, because it could go haywire."

Both halves of that are right, and the claim ladder already resolves them.

**Still absolute: a reference item may never become a fact about you.** Saving an
article about morning routines does not make *"he wants to wake up earlier"* true.
You looked at a thing.

**Newly allowed: it may become a hypothesis.** Sending something is a deliberate
act, and a run of them is real signal — not about what someone *is*, but about
what they may be moving toward. So it enters as the lowest-confidence class,
under goal 21's existing gates:

- **Never from one item.** A single link means almost nothing; four on the same
  theme across two weeks means something.
- **Asked, never asserted.** *"You've sent me five things about moving to
  Japan — is that something you're actually working toward, or just interesting?"*
- **Their answer is what settles it.** Yes makes it a stated want, grounded in
  their words. No retires it, permanently.
- **Consumption is not aspiration.** Reading about something is at least as often
  curiosity, work, or avoidance. The hypothesis has to allow for that and the
  question has to make declining easy.

**Conservative at the start, deliberately.** High bar, few of these, and the
founder's own reason for the caution is the right one — this is the failure that
goes haywire quietly, because every wrong inference would still trace to something
real that they really did send.

**Logged as an open question**, in the founder's words: *how much do we want to
attribute content a person sends to their identity?* Conservative now, revisited
with evidence from the beta.

This is the single highest contamination risk in the product. Reading material
is the easiest thing in the world to mistake for self-expression, and a bank
poisoned this way would be poisoned invisibly — every claim still has a real span,
just in someone else's words.

**Done when.** You can dump fifty links across a week, find any of them later by
your own reason for saving it, and trust that none of them changed what the
product thinks about you.

**Metric.** Sort accuracy against your correction; share of items retaining intent;
**cross-bank contamination: zero, and tested for explicitly in the bank.**

---

### Goal 20 — Correction that sticks *(new)*

**Is.** Being able to tell it that it is wrong, in passing, and have that hold.

**Must.**
- Correct it in plain language, mid-conversation, without opening a settings screen.
- A correction propagates: the claim, anything built on the claim, and the portrait
  slot that showed it.
- Something you rejected is never resurrected.
- It asks before overwriting something you said, rather than quietly deciding.

**Done when.** You correct it once.

**Metric.** Resurrection rate of rejected claims: zero. Corrections needing to be
repeated: zero.

---

### Goal 5 — Linting information

**Is.** Catching rot before it is spoken. Promoted sharply by the mission — a
stale fact in a weekly episode is one wince a week; in a daily companion it
repeats until corrected.

**Must.**
- Runs on a schedule, not when someone remembers.
- Every finding names a specific row and a specific reason.
- Remediation is proposed for approval, never applied silently.
- Nothing flagged as rotten reaches an output before it is resolved.
- **Catch hypothesis hardening.** A hypothesis repeated often enough starts being
  treated as known — by the system and by the person. Lint checks that nothing
  inferred has quietly acquired the standing of a fact, and that anything still
  unconfirmed after a set period is either tested or retired.

**Done when.** It stops repeating things that stopped being true, and never
promotes a guess to a fact by repetition alone.

**Metric.** Stale statements reaching any output: zero. Hypotheses presented as
facts: zero. Findings per run, trending down.

---

## Tier 2 — the read path

This is where the mission changed the architecture most.

### Goal 10 — Understanding the current state of the person

**Is.** One current picture of you, readable in a single request. The hottest read
in the system — every conversational turn needs it.

**Must.**
- One portrait, not a history.
- An unknown slot stays empty. It is never filled with last month's answer.
- Rebuilt whenever something lands.
- Readable fast enough to sit inside a conversation.
- **Carries the appetite reading** from goal 22, and **per-domain critical mass**,
  so any consumer can tell at a glance what it is allowed to wonder about today.
- Every slot states its claim class. A portrait is where facts and inferences are
  most likely to blur, because it reads as a summary.

**Done when.** It knows where you are today, tells you plainly what it does not
know, and knows how boldly it is allowed to speak.

**Metric.** Slot staleness in days; accuracy of populated slots against your own
review; claim class present on every slot.

---

### Goal 6 — Searching content

**Is.** No longer plumbing. Under the mission this **is** the conversation surface.

**Must.**
- Answer typed questions — what is still true, what changed since June — not
  nearest-chunk.
- Every answer carries its source.
- Say "I do not know" rather than approximating.
- Fast enough to talk to. Portrait-level reads under a second.
- **Filterable by claim class.** You can ask for only what is certain, and get an
  answer that excludes every inference. A result set never mixes facts and
  hypotheses without saying which is which.
- **Searches both banks, with the boundary visible.** One question can return
  "what you said" and "what you saved," and it is never ambiguous which is which.

**Done when.** You can ask anything about your own life and get an answer with a
receipt — and you can always ask for just the part that is known.

**Metric.** p95 latency; citation rate at 100%; refusal rate on the bank's
deliberately unanswerable cases; claim class present on every returned row.

---

### Goal 24 — Cold start *(new)*

**Is.** Getting from nothing to something worth hearing, fast. Added 17 October
2026 from a requirement that cuts across the whole plan: *"we want to be able to
give them insight about who they are quickly after we index their profile."*

Everything else in this document assumes a bank that fills over time. This goal
assumes the opposite — no history at all — and it is the moment that decides
whether anyone stays.

**The inputs it has.** A battery of onboarding questions. Connected integrations.
Professional profiles. Research about the person. No journals yet, and no
patterns, because patterns need repetition and there has been none.

**Must.**
- Produce a first portrait from onboarding alone, with populated slots that are
  genuinely populated and empty ones left visibly empty.
- **Be honest about its own thinness.** A first insight is allowed to be narrow. It
  is not allowed to sound like it knows more than it does — that is the fastest
  way to lose trust, and the easiest mistake to make when trying to impress.
- The onboarding questions double as the appetite reading (goal 22), so the same
  answers serve two purposes and nobody is asked twice.
- **No pattern claims.** A pattern requires repetition, and day one has none. A
  first insight that asserts a behavioural pattern is fabricating.
- Degrade cleanly. Someone who connects nothing and answers briefly still gets
  something true, just less of it.

**Done when.** Someone finishes onboarding, hears something about themselves they
recognise, and it is all defensible.

**Metric.** Share of new users who say the first insight was accurate; share of
first-insight claims that survive later contradiction; pattern claims at
onboarding (must be zero).

**Depends on goal 21.** "Insight about who they are" on day one is almost entirely
hypothesis — there is nothing else available. So this goal cannot be finished
before the hypothesis mechanism exists, and it is the single strongest argument
for building goal 21 earlier than its tier suggests.

### The frame — an adventure, not a setup wizard

Founder's direction, 17 October 2026, and still being played with:

> "Frame this like a hero's journey... what do you want your legacy to be, what do
> you want in your life — make it feel like they're about to go on an adventure."

Worth saying that this converges with the psychology rather than decorating it.
McAdams' whole method asks people to narrate their life as a book with chapters,
and the redemption sequence — difficulty that turns — is the hero's journey
described in research language. **Asking someone for their life as a story is both
the most engaging possible onboarding and the most useful possible data.** Those
rarely coincide.

### Be upfront about what the product is for

> "We want to be upfront. This product is meant to help you be better. We want to
> make sure you're on board with being better — committed to being better. The
> purpose is to achieve your wildest dreams. Be bold about that claim."

An explicit commitment moment in onboarding, stated plainly rather than softened.

This is also the one onboarding element with direct research support: progress is
mediated by **felt accountability** (d=0.33, N=517). Asking someone to commit out
loud, at the start, is not framing — it is the mechanism. A product that quietly
hopes you improve has skipped the only step shown to matter.

### The onboarding sequence

Specified 17 October 2026.

0. **The frame.** What do you want your life to look like. What would you want
   said about you. Bold, and asked as the opening of an adventure.
1. **A couple of questions first.** Earn a little trust before asking for anything.
2. **Then the privacy conversation** — the policy, and how we think about this —
   *before* access is requested, not after.
3. **Then ask for the data sources.** Framed as what it is: *"we want to understand
   you better."*
4. **Then more questions**, now that there is something to ask about.
5. **Then the first insight.**

**Asked in voice, with the option to type.** Voice is the default because it
produces far richer answers than a text field, and because it sets the
relationship with the product from the first minute. Typing is always available
and never a lesser path.

**All four integrations at once**, not staged: LinkedIn and professional profile,
Google, screen time and browsing, health and activity. Plus **a web search on the
person**. Everything together produces the specific profile; staged connection
produces four thin ones.

**"How are they doing" starts here and then grows.** Founder's instruction: assess
it during onboarding, and have it grow from there. It is canonical question 27,
and it is one of the two that passive sources cannot answer. The first
conversation is where it gets its initial answer; from then on it is a hypothesis
whose confidence moves with every observation, and whose answer decays if nothing
refreshes it.

**Disclosure question — closed.** External research on a new user is disclosed
before access is requested, as part of step 2. The founder's own sequencing
answered this: privacy policy first, then ask. Which also means the privacy
conversation is a *product surface* with real copy to write, not a legal checkbox
— it is step two of the first thing anyone experiences.

---

## Tier 3 — understanding

### Goal 7 — Understanding reported goals

**Is.** What you said you wanted, with a lifecycle.

**Must.**
- A stated goal moves through states: stated, active, quit, achieved, expired.
- Goals expire rather than lingering forever.
- Quitting is respected immediately, not at the next weekly run.

**Done when.** January's marathon is not this week's topic.

**Metric.** Correct retirement on the bank's contradiction cases.

---

### Goal 8 — Understanding real goals and aspirations

**Is.** What you actually pursue, as distinct from what you said.

**Must.**
- Pursuit is named only after repetition. Never from one data point.
- Stated and actual are both visible, and never merged into one number.
- It does not claim to know a want it cannot evidence.
- **The line between the two classes sits here.** Observed pursuit is a pattern —
  evidence, stated plainly. What you *actually want* underneath it is a
  hypothesis, and goes through goal 21's gates. The product must never present
  the second as the first.

**Done when.** It can show you the gap between what you said and what you did,
without editorialising — and can wonder aloud about the reason only once it has
earned the right to.

**Metric.** Share of promoted patterns you confirm on review; false pattern rate.

---

### Goal 12 — Understanding what is impeding progress

**Is.** Naming the thing in the way. Mechanism unchanged by the mission; delivery
transformed by it.

**Must.**
- A standing thread, never one bad day.
- A why only after a pattern exists, and labelled as inferred.
- External causes considered before behaviour is blamed.
- Delivered as a question before it is delivered as a verdict.
- **The why here is a hypothesis** and inherits goal 21's three gates. Today it is
  a lookup table from the predicate — which is honest but shallow. A framework-led
  why is the upgrade, and it is gated on appetite like any other.

**Done when.** It names what is in your way and you do not feel accused.

**Metric.** Your agreement rate on named impediments; share delivered
question-first.

---

### Goal 22 — Calibrating to the person *(new)*

**Is.** A per-user reading of three things: how inclined they are to grow, how
sensitive they are, and how open they are. Together these set their **appetite for
hypothesis** — and it differs enormously between people. Some live to explore.
Some need to feel completely safe, and being hypothesised about too early loses
them for good.

**How it is determined.** Decided 17 October 2026. Three inputs, combined at
onboarding and revised continuously:

1. **Onboarding questions** about current goals and aspirations, asked in a
   deliberately non-threatening way. The answers matter; so does *how* they
   answer — length, hedging, what they skip.
2. **Integration and professional-profile data.** What their work looks like, what
   they have been doing, what they have made public about themselves.
3. **A profiling framework from the literature**, which maps those inputs onto an
   appetite bucket — roughly, how growth-oriented, how much honesty they want, how
   sensitive they are.

That third input does not exist yet and is a **research task**, specified below.

**Must.**
- **Start safe and earn upward.** The default for a new user is low appetite:
  facts and patterns only. Appetite is raised on evidence and lowered on any
  signal of discomfort. It is never assumed upward.
- Read appetite from what actually happened — did they engage with a hard
  observation, did they answer or deflect, did they come back after a difficult
  episode, did they confirm or reject.
- **Ask, as well as infer.** Appetite can be set directly by the person, and
  stated preference always outranks inferred preference.
- Appetite is a current reading, not a trait. It moves with the week someone is
  having.
- Visible and overridable. A person can see how boldly it thinks it may speak, and
  change it.
- **Bucketing is explainable.** If someone is placed in a bucket, the reason
  traces to their answers and the named framework — never to an opaque score.

### The research task this goal depends on

A survey pass, run through the decision loop like any other method, on what the
literature establishes about:

- what distinguishes a person with high appetite for growth feedback from one with
  low appetite, and whether that is measurable from the inputs above
- how sensitivity to feedback is assessed in practice
- how therapeutic traditions decide **how to speak to someone** — CBT is the named
  starting point, and motivational interviewing's readiness stages are the obvious
  neighbour
- which of this survives contact with the data we actually have: onboarding
  answers and digital traces, not a clinical interview

Existing groundwork: research docs 17–22 in the agent repo already cover stated
goals versus real wants, inferring from digital traces, and whether the why is
computable. Doc 12 covers the persona layer. This task extends them toward
*appetite* specifically.

**The line that must hold.** Borrowing CBT's *communication posture* — ask before
asserting, collaborative rather than expert, test a thought rather than diagnose
it — is legitimate and is exactly what is wanted here. Borrowing CBT's *clinical
assessment* is not. The product may learn how to speak to someone from
therapeutic practice. It may never conclude what is wrong with them. Goal 21's
non-clinical rule is unaffected by this research and is not up for revision by it.

**Done when.** Two people with identical data get noticeably different products,
and neither feels misjudged.

**Metric.** Disengagement after a hypothesis-bearing output: trending to zero.
Agreement between inferred appetite and stated appetite when the person sets it
directly.

**The bootstrap problem, stated plainly.** Reading someone's sensitivity is itself
a hypothesis, so early on the system is guessing about the exact thing it most
needs to get right — and guessing too bold is the one error that loses a user
permanently. Hence: safe default, ask early, raise slowly. The asymmetry is
deliberate. Being too cautious costs engagement. Being too bold costs the person.

**Safe default ships in tier 1.** The *learned* version needs goal 19 and belongs
here. A constant "assume low appetite" can and should land much earlier, because
without it nothing downstream knows how to behave.

---

## Tier 4 — the companion

### Goal 18 — Conversation as a surface *(new)*

**Is.** Talking to it bit by bit. Nothing in the original 16 covered turn-taking.

**Must.**
- Carries context across a day, not just within a reply.
- Knows when to say nothing.
- Interruptible. Does not deliver a monologue when asked a question.
- Never restates what you just told it as if it discovered it.

**Done when.** It feels continuous rather than like a new session every time.

**Metric.** Context carried across a day; your count of "it forgot."

---

### Goal 9 — Understanding communication style

**Is.** Two directions now. How you talk about yourself, and how it talks to you.
This is where "soothing" actually lives.

**Must.**
- Your self-talk is stored and quotable.
- Its voice is calm and specific. Never therapeutic-generic.
- It does not perform empathy it cannot ground in something you said.
- It reads how much you can take today and adjusts.

**Done when.** Talking to it feels like relief, not a performance review.

**Metric.** Your rating on a fixed set of generated responses. **Not automatable,
and stated as such** — this is the one goal where you are the only instrument.

**Tension to hold.** Your own research says being seen is not the same as getting
better, and that progress rides on felt accountability. Soothing and
growth-driving pull against each other. This spec should not resolve that
quietly.

**The tension sharpened, 17 October 2026.** You have now asked for both, in the
same conversation: *"really emotionally soothing to speak with"* and *"catch them
on their bullshit."*

That is not a contradiction — it is a description of a good coach, and it is also
the single hardest thing in this product to get right. The two fail in opposite
directions: soothing alone is flattery, blunt alone is a performance review
nobody opens twice.

What makes both possible at once, from the research and from how it actually works
between people:

- **Warmth in the delivery, precision in the content.** The softness goes in how
  it is said, never in what is claimed. Hedged content delivered kindly is just
  vague.
- **Evidence instead of judgement.** "Three Thursdays" lands differently from
  "you're avoiding the gym," and it is the same observation.
- **Ask, do not tell.** A question cannot be condescending in the way a verdict
  can.
- **Earn the right over time** — goal 22. Bluntness that would land in month three
  is a betrayal in week one.

This is the goal most likely to be judged by taste rather than metric, and the one
where your own ear during the 10–15 test episodes matters most.

---

### Goal 11 — Researching and retrieving what is relevant

**Is.** Bringing you things worth your attention. Triggered by what you point at,
and by what the bank says is live.

**Must.**
- Every brought item traces to a question your own life raised.
- Sources cited.
- Never pads with generic advice when it has nothing.
- Continuous, not episode-prep.

**Done when.** It brings you something useful you did not ask for, and you can see
why it thought so.

**Metric.** Your keep-rate on brought items.

---

## Tier 5 — inference and output

### Goal 21 — Hypothesis *(new)*

**Is.** The educated assumption. A claim the product makes about you that your own
words do not directly support — the thing that lets it help you grow rather than
only reflect you back.

This is the highest-value and highest-risk capability in the product. It is also
the one most likely to be built too early.

**Must.**
- **Never asserted. Always asked.** A hypothesis enters the conversation as a
  question or an offer, and the person can decline it without friction.
- **Audibly different from a fact.** In text and in audio. A listener can always
  tell which register they just heard, without being told.
- **Passes all three gates:** per-domain critical mass, a named framework, and the
  person's current appetite. Any one failing means it is stored, not spoken.
- **Names its framework on request.** "Why do you think that" has a real answer
  that traces to a theory and to the facts underneath it.
- **Never clinical.** No diagnosis, no disorder, no trauma, no pathology — not
  hedged, not as a question, not ever.
- **Cheap to reject.** Declining a hypothesis costs one word and the system
  updates both the claim and the appetite reading.
- **Expires.** A hypothesis unconfirmed after a set period is tested or retired,
  never quietly kept.
- **Never becomes a fact by repetition.** Only your confirmation can promote it,
  and lint checks this (goal 5).

**Done when.** It tells you something about yourself that you had not put into
words, you recognise it as true, and you can see exactly why it thought so.

And the harder half: when it is wrong, you feel invited to correct it rather than
examined.

**Metric.** Confirmation rate on offered hypotheses; rate of hypotheses delivered
as assertions (must be zero); disengagement following a hypothesis (must not rise);
share whose framework can be named on request (must be 100%).

**Critical mass can be bootstrapped, not only earned.** This changes the gate
materially. The assumption elsewhere in this doc is that enough-to-wonder
accumulates over weeks of journaling. It does not have to. Onboarding front-loads
it: a battery of questions, connected integrations, professional profiles, and
research about the person. After that, the bank is not empty — it is thin but
broad.

So goal 21 does not have to wait weeks. It has to wait for **mass**, and
onboarding is where most of it arrives.

**How bold — deliberately unresolved.**

Noted as an open product question rather than a decision, at the founder's
instruction on 17 October 2026: *"we could be bold about it, but I also don't know
that that's the correct answer just yet."*

It is a question that can only be answered with the thing in hand. The protocol:

1. Generate 10–15 episodes about the founder, from data he supplies.
2. He judges his own reaction — not whether the claims are true, but how being
   hypothesised about *felt*.
3. Then the same with a handful of friends, and judge their reactions.
4. The boldness setting comes out of that, and goes in this doc as a decision with
   a date.

Until then the engineering builds the **mechanism and the dial**, not a chosen
position on it. The dial must be adjustable without a deploy, because the whole
point is to turn it during testing.

**What still holds regardless of boldness.** Asked not asserted. Audibly
different from fact. Framework nameable. Never clinical. Cheap to reject. Never
promoted by repetition. Those are not dials.

---

### Goal 13 — Writing an informative outline

**Is.** The shape of what it tells you. One channel now, not the destination.

**Must.**
- The spine is live patterns and facts, never a recent-activity dump.
- Every section carries the evidence it rests on.
- Typed, not freeform prose.

**Done when.** The shape of what it tells you is traceable to your actual life.

**Metric.** Share of sections with evidence attached: 100%.

---

### Goal 14 — Writing an engaging story

**Is.** The thing you actually hear or read.

**Must.**
- Claims only what is in the evidence pack.
- Says less rather than inventing.
- Sounds like a person, not a template.
- Honest about what it does not know.
- **Carries two registers without blurring them.** "You skipped it three times"
  and "I wonder whether it is the mornings rather than the gym" cannot sound
  alike. The second is audibly a question, and the listener can always tell which
  one they just heard.
- **Respects the appetite reading.** The same week of data produces a bolder
  episode for someone who likes being pushed and a gentler one for someone who
  does not. Same facts, different distance.

**Done when.** Nothing in it makes you think "that is not me" — and nothing
hedged ever lands as if it were certain.

**Metric.** Fabricated claims: zero. Your count of "that is not me" per output.
Hypotheses delivered as assertions: zero.

---

### Goal 15 — Creating great voices

**Is.** Back in scope. "Soothing to speak with" makes voice a product
requirement, not a vendor choice. This reverses line 55 of the goals doc.

**Decided 17 October 2026: produced first, conversational second.** Two voices,
and the reason is honest rather than aesthetic.

**Must.**
- A voice you would choose to hear daily, not tolerate weekly.
- Prosody that does not flatten the hard sentences. ElevenLabs expressive tags
  are the starting point, and emotional delivery is a product requirement, not
  polish.
- Produced quality for both the daily brief and the weekly episode.

**Done when.** You listen voluntarily.

**Metric.** Your rating; latency to first audio.

### Talking back — V2, and here is the honest constraint

The thing wanted: you are listening, you ask a question, it answers — *"like
someone is giving me a really cool presentation and I just asked a question."*

Switching modes is easy. **Latency is the problem.** Answering requires speech to
text, a pull against the bank, generation, and then speech again. At produced
quality that is several seconds of silence, which breaks exactly the feel being
asked for.

So the design is: **do not answer in the episode's voice.** A real presenter does
not answer in their prepared delivery either — they drop into a looser register,
and everyone finds that natural rather than jarring.

- **Episode voice:** produced, expressive, slow to render, pre-generated.
- **Answer voice:** fast, lower production, generated live.

Two voices is not a compromise here. It is what the interaction actually is.

Marked V2 as instructed. The architectural note that matters now: **do not build
the delivery path in a way that assumes one voice.**

---

### Goal 16 — Delivering it on the device

**Is.** Also back in scope. "Talk to it bit by bit" needs a live surface, not a
player.

**Must.**
- Resumes where you left off.
- What is already there works without a connection.
- Interruptible mid-sentence.

**Done when.** You can talk to it while standing in a queue.

**Metric.** Time from intent to first word.

---

### Goal 25 — Visible pattern change *(new)*

**Is.** Showing someone a pattern weakening. Added 17 October 2026, because it is
what the founder named as the actual success condition:

> "If they give me any indication that I can start breaking negative patterns
> after usage, and it's engaging while doing so... then we can start suggesting
> actions, and help them see how their life is moving along."

Everything else in this document *detects*. This is the first goal that is about
*change*, and it is the payoff the rest exists for.

**Must.**
- A pattern carries its trajectory, not just its existence. Weakening, holding,
  strengthening.
- Progress is shown from evidence, never asserted encouragingly. "Twice this
  month, five times last" — not "you're doing great."
- **It must be able to say a pattern got worse.** A product that only reports
  improvement is a product nobody believes.
- The claim "this is breaking" needs the same bar as the claim it existed.
- Honest about attribution. The pattern changed; whether the product caused that
  is unknowable and must not be implied.

**Done when.** Someone sees a pattern they recognise getting weaker, believes it,
and the evidence is right there.

**Metric.** Patterns with a computed trajectory; agreement rate when a trajectory
is shown; share of trajectory claims traceable to instance counts.

### The research problem sitting inside this goal

"Then we can start suggesting actions" is the one part your own research warns
against directly.

- AI-generated goal **suggestions** produced no measurable effect (N=543).
- AI-authored goals were more specific but **less owned** (N=470).
- Implementation intentions work well — d=0.65 on attainment — **but only when
  formed by the person themselves.**
- Progress is mediated by **felt accountability**, not by advice quality.

So the version that works is not *"here's what to do."* It is *"you've skipped
three Thursdays — what would make next Thursday different?"* and then holding them
to their own answer.

**Confirmed by the founder, 17 October 2026:** *"I like the idea of 'you skipped
three Thursdays, what's the problem' and holding them to their own answer."*

### Suggestions are allowed — second, as an option, and later

The founder's refinement, which is more precise than my original flag:

> "It sucks to learn where your weaknesses are. So help them with the IKEA method
> first, and then also help them break patterns with suggestions... we noticed
> this, what do you think would make a difference — and we also have the option,
> do you want to do this? We suggest, we let them answer the question first... and
> the action part is later. It's the closer for behaviour change."

This is [the user journey](#the-user-journey) — evidence, question, their answer,
then optionally an option — applied to pattern change. It is defined once at the
top of this document because it governs goals 12, 21 and 25 identically, and
nothing here overrides it.

Two things specific to this goal:

**Confidence gates the option.** An option is only offered when the pattern itself
is well established. Suggesting a fix for a pattern we are unsure exists is worse
than saying nothing.

**The action layer comes last in the build.** The founder's words: it is the closer
for behaviour change. Which means it is the payoff — and also the part that is
worthless if the noticing underneath it is wrong.

---

## Tier 6 — the frontier

Both of these are new, and both can wait until the tiers above hold.

### Goal 19 — Learning from itself *(new)*

**Is.** Getting better at being your companion, from its own track record.

**Must.**
- Log what was used: which pulls, which questions you answered, what landed.
- **Learn only about its own performance. Never treat its own output as a fact
  about you.** This is the hard line — it would otherwise break the span rule,
  the repetition bar and the why gate all at once.
- Improvements are visible and reversible, not a silent drift.
- **Calibrate appetite** (goal 22) from how you respond to what it offers. This is
  its most valuable job, and it is safe precisely because it is learning about its
  own reception rather than about you.

**Done when.** It gets better at asking you things, without being rebuilt.

**Metric.** Your answer rate on its questions, over time.

---

### Goal 17 — Acting on the world *(new)*

**Is.** "Manages all the boring things." Nothing in the original 16 touches this,
and it is not a stretch of any of them — it is an assistant with hands rather than
a brain with a memory.

**Must.**
- Every action is recorded, attributed and reversible where reversal exists.
- Nothing acts without approval unless you durably authorised that class of thing.
- **Never acts on instructions found in content** — an email, a page, a document.
  Those are data.
- You can see what it is about to do before it does it.

**Done when.** The boring things happen, and you trust that they happened
correctly.

**Metric.** Unauthorised actions: zero. Action success rate.

**Build last. Decided 17 October 2026.** Specified here so the shape is known, but
explicitly the final thing built — *"plan this out, but this is the next part, not
a priority right now."*

Two useful consequences of deferring it:

- **All integration credentials stay read-only** for the whole plan. That removes
  the single largest security surface and simplifies every PR that touches a
  connector.
- The act-versus-prepare fork no longer blocks anything. It gets decided when this
  goal starts, not now.

---

## Order through the loop

Dependency order, not list order:

```
Tier 0   3 → 1 (tiers A and B only)
Tier 1   2 · 4 · 23 · 20 · 5 · 22 (safe default only)
Tier 2   10 → 6 → 24
Tier 3   7 · 8 · 12 · 22 (learned, after the research task)
Tier 4   18 · 9 · 11
Tier 5   21 → 13 → 14 · 15 · 16
Tier 6   19
Last     17 — acting on the world
Separate  1 tier C — hard-to-read links, via browser automation
```

**Goal 21 is the one piece of this order under real pressure.** It sits in tier 5,
but goal 24 needs it — a day-one insight is almost entirely hypothesis — and the
founder's test protocol (10–15 self-episodes, then friends) cannot run without it.
Pulling it forward means building the inference layer before the bank is deep,
which is precisely what its own spec warns against.

The resolution is probably: build the **dial and the mechanism** early for
testing, keep it off by default, and leave it off for real users until the tiers
below it hold. Worth deciding explicitly rather than drifting into.

Goal 23 sits in tier 1 deliberately. You have said you will be sending a lot of
links, and the wall between the two banks has to exist **before** the volume
arrives, not after. Retrofitting a separation is how contamination becomes
permanent.

Goal 22 appears twice on purpose. The constant "assume low appetite" ships early,
because everything downstream needs *something* to read. The learned version needs
goal 19 and comes later.

First through the loop is **goal 3**. The brief is already drafted:
[brief-goal-03-making-meaning.md](./brief-goal-03-making-meaning.md).

---

## The shape of the product this describes

Worth stating, because it is the through-line of every spec above.

The product spends most of its life being **certain and quiet** — facts, patterns,
things you said. It earns the right to **wonder aloud** slowly, per area of your
life, and only as fast as you show you want it to.

The failure it is designed against is the obvious one: a system that guesses
confidently at someone it does not know yet, and loses them.

---

## Still open — what this document cannot decide

Ordered by how much they block. Nothing below stops the first build starting;
everything below stops a later goal finishing.

### Blocks a goal from being finished

**1. The canonical questions themselves.**
[Thirty-six drafted](./canonical-questions.md). Which are missing, and which are
off-limits? Question 20 — *what do they consume that they would say they
shouldn't* — is answerable and may be unkind. It decides what the product tries
to know, which is not an engineering call.

**2. Which frameworks are allowed.** Goal 21 requires named ones, and goal 22's
appetite research will propose candidates. Choosing them decides what lens the
product looks through. Research docs 17–22 in the agent repo are the pool.

**3. Coverage threshold: global or per domain?** My recommendation is per domain —
speak about work when work's questions are answered, stay quiet about feelings
until someone has said something. Needs your yes.

**4. Composio or direct connectors.** Explained in chat; my recommendation is
direct for Google, Composio for the long tail.

### Decided by testing rather than discussion

**5. Hypothesis boldness.** Your 10–15 self-episodes, then friends. Build the dial,
not a position on it.

**6. Goal 9's balance** — soothing versus catching you on your bullshit. Goal 22 is
the mechanism that could resolve it per person. Your ear during testing decides.

**7. The success bar for the beta.** You said you do not have the perfect answer
yet and that it is yours to think about. Noted rather than guessed at.

### Deferred by choice

**8. Goal 17's fork** — act, or prepare for approval. Not needed until goal 17
starts, which is last.

**9. Privacy architecture and on-device.** Explicitly later. Disclosure is not.

### For you to confirm about this document

**10. Are the metrics right?** Each goal declares one, and it becomes the
validation gate. A wrong metric means everything passes.

**11. Anything I invented that you did not mean.** Goals 17–25 are my derivations
from what you have described. Cut freely.

---

## Later — the control panel

Founder's idea, 17 October 2026, recorded here at his instruction and explicitly
**not** a design constraint on anything above:

> "A control panel that lets me tune the behaviour of the product in a UI. Manage
> behaviour, add a feature, add a functionality... a sandbox for tuning the product
> and managing different variables. Obviously make this after the product. It
> should not be designed around this whatsoever."

It is a good idea, and the reason it is good is specific: this product has an
unusual number of **numbers that can only be found by feel.** Hypothesis boldness.
The eight coverage thresholds above. Brief length. Repetition pacing. Appetite
sensitivity. Relevance bars. Promotion bars.

Every one of those is currently set by a judgement in a document, changed by a
deploy, and evaluated by remembering how last week felt. A panel turns that into
same-afternoon iteration — and more importantly, into iteration the founder can do
without me.

**Why it must come after, and the reason is not just priority.** A tuning surface
built before the variables are known will enshrine the wrong variables, and then
the product gets shaped to fit its control panel. The dials have to be discovered
by building the thing and finding out which ones you keep reaching for.

**What to do now, which costs nothing:** keep every one of those numbers in one
place rather than scattered through the code, and make them readable at runtime
rather than compiled in. That is good practice regardless, and it is the entire
groundwork this would need later.

---

## Later — privacy and on-device

Noted 17 October 2026, explicitly as a future direction rather than a current
goal. The present priority is making the product impressive. Privacy
architecture comes after.

The eventual ambition: as privacy-focused as possible, with as much as possible
running on the person's own device.

**What ports cleanly when that day comes.** More than you might expect. The span
rule, the claim ladder, supersession in code, the repetition bar, typed pulls, the
two-bank separation — all of it is architecture, not model behaviour. None of it
assumes a hosted API. The careful part of this design is portable.

**What gets expensive.** Every model in the stack is a hosted call: extraction,
the cooks, embeddings at 3072 dimensions, and TTS. On-device means much smaller
models, and extraction quality is the thing that would suffer most — which is the
foundation everything else sits on.

**The one cheap thing that preserves the option.** Keep the model layer swappable,
which it already is — every model is an environment variable, and nothing in
`src/brain/` knows which model produced its input. Do not let that erode. A
hard-coded provider anywhere is the thing that would make this move cost a rewrite
instead of a configuration.

**One distinction worth keeping straight.** Deferring *on-device* is a reasonable
product call. Deferring *not leaking* is not the same decision, and should not
inherit the same "later." Two findings from the September audit were unauthenticated
access to `/runs` and a publicly readable `podcast-audio` bucket. Those are bugs,
not privacy features, and they belong in the current plan regardless of where
this section sits.
