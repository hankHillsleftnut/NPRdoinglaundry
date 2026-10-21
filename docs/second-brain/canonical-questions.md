# The canonical questions

**The barometer for whether we know someone.** Founder's idea, 17 October 2026:

> "If we have this massive bank of questions about who this person is, and we have
> the ability to accurately answer them, now we have all the information we truly
> need. This needs to be built around that idea, and the integrations we have
> should give the answer to that as much as possible."

This replaces row counts as the measure of profile completeness. "We have 400
observations" says nothing. "We can answer 31 of 36 questions about this person"
says everything.

**Draft. The questions are yours to correct** — they decide what the product tries
to know, which is a product decision, not an engineering one.

---

## This is not a questionnaire

Stated plainly because the first draft of this file was ambiguous about it.

**The system answers these questions itself.** It is an investigation the product
runs, continuously, from whatever it has. The user is never shown this list, never
asked to fill it in, and never aware it exists.

A question is answered when the product can produce a grounded answer from
sources it already holds. Unanswered means *we have not figured it out yet* — not
*we need to ask*.

### Every answer is a hypothesis with a confidence that grows

Founder's clarification, 17 October 2026, and it is the mechanism rather than a
detail:

> "We are never going to answer these questions by asking the user. The whole
> point is that it's ambient. We hypothesise answers to these core questions and
> grow them in confidence the more we observe... so we get to highest confidence
> with the least effort on the user's end."

So a question is not a checkbox. Each one holds:

| | |
|---|---|
| **Current best answer** | the standing hypothesis |
| **Confidence** | how sure, and it moves |
| **Evidence** | what observations support it, each traceable |
| **Last moved** | when new evidence changed it |

Confidence grows by accumulation. A second source saying the same thing raises it.
A contradiction lowers it or splits the answer. Nothing is ever settled by one
observation.

**Coverage therefore means "questions with an answer confident enough to use,"**
not "questions with any answer at all." Which also means the threshold for
speaking is a confidence threshold, and goal 21's gates apply to these answers
directly rather than by analogy.

### Asking is for confirmation, and it comes later

The product never puts a core question to the person. What it may eventually do is
show them an answer it already has and let them correct it — feedback on a
hypothesis, not an interview.

The distinction is sharp and worth holding:

| Allowed | Not allowed |
|---|---|
| "I've had the impression you care more about X than Y — am I off?" | "What do you care about most?" |
| Conversational onboarding questions about goals and how they like to consume | Putting the 36 questions to someone |
| A question in the brief about something specific it noticed and cannot resolve | A questionnaire |

The second column is not merely worse product. It defeats the premise: a companion
that has to interview you does not know you.

**The least-effort principle.** The measure of this system is how high a
confidence it reaches with how little asked of the person. Every question put to
the user is a small admission that inference failed — sometimes a necessary one,
never a free one.

### What `W` means, and what it does not

`W` in the table below means **the person's own words, from wherever they already
exist.** It is a source type, not a collection method.

Words arrive passively, in quantity, without anyone being prompted:

| Word source | What it is |
|---|---|
| **Sent mail** | How they actually talk, to whom, about what. Years of it. |
| **Notion and docs** | What they write when thinking something through. |
| **Public writing** | Posts, bios, anything they have published about themselves. |
| **Onboarding answers** | Collected once, as part of a flow they opted into. |
| **Journals and voice notes** | When they happen. Never assumed. |
| **Progress texts** | Power-user bonus. |

**This changes the connector ranking materially.** Gmail was listed above as a
metadata source — who they meet, how often. That undersells it badly. **Sent mail
is the largest corpus of the person's own words that exists**, and it is available
without asking for anything.

So several questions marked `W only` below are not blocked on someone deciding to
journal. They are blocked on reading what they have already written somewhere
else.

### What genuinely cannot be found

A real residue remains. "How are they doing right now" cannot be derived from a
calendar, and if someone has written nothing recent anywhere, it stays unanswered.

The honest position: for a silent user those questions stay open, the coverage
number says so, and the product is built to be good on the questions it *can*
answer. That is what ambient-by-default costs, and it is visible rather than
papered over.

---

## Two separate numbers, and they must not be merged

| | What it asks | How it is measured |
|---|---|---|
| **Coverage** | can we answer this at all? | share of questions with any grounded answer |
| **Accuracy** | is the answer right? | share the person confirms when shown |

The founder named this distinction explicitly. Coverage is cheap to measure and
easy to game — a system that guesses at everything scores 100%. Accuracy is the
one that matters and only a human can supply it.

**Report them together, always.** Coverage alone is the metric a dishonest system
optimises.

---

## What this unlocks

**A real answer to "confident enough to speak."** The ambient brief starts when
coverage crosses a threshold, per domain. No arbitrary two-week warm-up.

**A connector priority list.** Each source is worth exactly what it answers. The
`Answerable from` column below ranks the integration backlog without anyone
arguing about it.

**A gate for hypothesis (goal 21).** You may wonder aloud about a domain when that
domain's questions are answered. Critical mass stops being a feeling.

**The test bank's expectations.** The questions are what a correct system produces.

---

## The questions

`Answerable from` names the cheapest source that could ground an answer.
**W** = the person's own words · **Cal** = calendar · **Mail** · **ST** = screen
time · **H** = health · **LI** = LinkedIn/profile · **N** = Notion/docs ·
**Web** = public search

### Who they are

| # | Question | Answerable from |
|---|---|---|
| 1 | What do they do for work, concretely? | LI · Web |
| 2 | What are they building or responsible for right now? | LI · N · W |
| 3 | How long have they been doing it? | LI |
| 4 | What stage of life are they in? | LI · W |
| 5 | Where do they live, and does it matter to them? | W · Web |

### What they want

| # | Question | Answerable from |
|---|---|---|
| 6 | What have they *said* they want? | **W only** |
| 7 | What do they spend their time on regardless of what they say? | Cal · ST |
| 8 | Where do those two disagree? | Cal · ST · W |
| 9 | What have they quit, and when? | W |
| 10 | What do they want that they have never named? | **hypothesis — goal 21** |
| 11 | What does success look like to them specifically? | W |

### What they actually do

| # | Question | Answerable from |
|---|---|---|
| 12 | What does a normal week look like? | Cal |
| 13 | What do they reliably do? | Cal · H |
| 14 | What do they reliably avoid or skip? | Cal · H |
| 15 | When are they at their best, by time of day? | Cal · ST · H |
| 16 | What has changed in the last month? | Cal · ST · H |
| 17 | How much are they sleeping and moving? | H |

### Their attention

| # | Question | Answerable from |
|---|---|---|
| 18 | What do they read or watch by choice? | ST · W |
| 19 | What do they keep returning to? | ST |
| 20 | What do they consume that they would say they shouldn't? | ST |
| 21 | What are they trying to learn? | ST · N · W |

### The people in their life

| # | Question | Answerable from |
|---|---|---|
| 22 | Who do they spend the most time with? | Cal · Mail |
| 23 | Who matters most, as distinct from most frequent? | W |
| 24 | Who do they talk about when something is hard? | **W only** |
| 25 | Who has disappeared from their life recently? | Cal · Mail |
| 26 | Who do they work for or answer to? | LI · Mail |

### How they are

| # | Question | Answerable from |
|---|---|---|
| 27 | How are they doing right now? | **W only** |
| 28 | What is weighing on them? | **W only** |
| 29 | How do they talk about themselves? | **W only** |
| 30 | Are they in an expansive phase or a depleted one? | W · H · Cal |

### What is in the way

| # | Question | Answerable from |
|---|---|---|
| 31 | What pattern is costing them most? | Cal · ST · H · W |
| 32 | What do they blame, and is it the real cause? | **W + hypothesis** |
| 33 | What have they tried that did not work? | W |

### How to speak to them

| # | Question | Answerable from |
|---|---|---|
| 34 | How direct can we be with them? | goal 22 |
| 35 | How much do they want to be pushed? | goal 22 · onboarding |
| 36 | What would make them stop listening? | goal 22 · behaviour |

---

## What this draft already tells us

**Thirteen of thirty-six need the person's own words** — everything about wanting,
feeling, meaning, and who actually matters.

But words are mostly already available. Sent mail and documents answer a large
share of them without anyone being asked anything. The gap is far smaller than it
first looks, and it is a *reading* problem rather than an *engagement* problem.

**Google is the clear first connector, and for a better reason than "it's already
partly built."** It is three sources in one: calendar answers what they do, mail
metadata answers who they do it with, and **sent mail answers how they talk and
what they care about** — the expensive third of the list.

**Screen time is the highest-value second** despite feeling the most invasive. It
is the only source that answers what someone attends to as opposed to what they
claim to value, which is the stated-versus-real gap in goal 8.

**LinkedIn answers the cold-start questions** — 1 through 4, the ones nothing else
can answer on day one, before any behaviour has been observed.

**Notion matters more than its question count suggests.** Few questions, but it is
where someone writes while *thinking*, which is qualitatively the best words
available.

**What remains hardest for a silent user:** how they are right now, and what is
weighing on them. Those need *recent* words — old mail tells you how someone
talks, not how this week is going.

### The first conversation closes the cold-start half of that

Founder's note, 17 October 2026: this can probably be got in the first
conversation with the user.

Correct, and it is the strongest argument for voice onboarding. A spoken
conversation at signup produces exactly the words these questions need — how
they are, what is weighing on them, what they are hoping for — in a context where
being asked is natural rather than intrusive.

So onboarding is not only how the product gets *permission*. It is the single
richest words source it will ever get in one sitting, and the only one guaranteed
to exist for every user.

**The caveat worth holding.** It answers these questions *as of day one*. Question
27 is "how are they doing **right now**," and the answer decays. By week six the
onboarding answer is a historical fact, not a current state — and goal 5's lint
should treat it that way rather than letting it sit in the portrait as though it
were fresh.

Which is why the weekly notification matters so much: it is the mechanism for
refreshing the only answers that cannot be refreshed passively.

---

## Open for the founder

1. **Which questions are missing?** Thirty-six is a draft. The ones you would
   actually want answered about yourself are the real list.
2. **Which are off-limits?** Question 20 — what they consume that they would say
   they shouldn't — is answerable and may be unkind. It is the sort of question
   that makes a product feel like it is watching.
3. **Is the coverage threshold global or per domain?** Per domain is my
   recommendation: speak about work when work's questions are answered, stay quiet
   about feelings until someone has said something.
