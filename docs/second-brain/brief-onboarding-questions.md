# Brief — onboarding questions that answer the core questions

**Your direction, 18 October 2026:** ask a handful of questions, but each one has
to invite an answer that covers several of the 36 core questions at once, so a
small amount of input tells us a lot and the product feels ambient from day one.

## What onboarding asks today

18 questions (`VoiceGoalsPage.swift:92`). Mapped against the 36:

| Kind | Questions | Core questions they feed |
|---|---|---|
| Form fields | name, city, age, gender, sexuality, relationship, job, how you feel about it | 1, 4, 5 (thinly) |
| Reflective | "a goal someone said you couldn't achieve", "how a friend would describe you", "something you haven't told anyone", "a moment you felt most like yourself", "what future-you would say" | 28, 29, partly 10 |
| Goals | what you want to change, why, what's in the way | 6, 11, 32 |
| Dream life | where you'd live, what kind of home | none |

**Roughly 10 of 36 touched, from 18 questions.** Nothing about the week, the
people in their life, what they pay attention to, or how to talk to them. The
dream-home questions feed nothing.

## The principle

**Ask for a specific recent story, not an opinion.** "Walk me through
yesterday" gets the schedule, the people, the mood, what was avoided and what
mattered, in one answer. "What are your values?" gets a polished paragraph that
answers one question badly. Spoken answers carry more than typed ones, so voice
stays the default.

## Proposed: 7 questions, plus name

| # | Question | Core questions it feeds |
|---|---|---|
| 0 | What should I call you, and where are you based? | 5 |
| 1 | **Walk me through yesterday — what you did, who you saw, and what you'd have skipped if you could.** | 7, 12, 13, 14, 15, 22, 27, 30 |
| 2 | **What are you working on right now, and how is it actually going?** | 1, 2, 3, 4, 11, 26, 28, 30 |
| 3 | **What's been taking up most of your head lately?** | 27, 28, 29, 24, 10 |
| 4 | **What do you want the next few months to change — and what have you already tried?** | 6, 8, 9, 11, 31, 32, 33 |
| 5 | **Who would you call if something went wrong? Anyone you wish you saw more?** | 23, 24, 25, 22 |
| 6 | **What have you been reading, watching or learning lately — by choice?** | 18, 19, 21 |
| 7 | **How should I talk to you: straight or gentle, push you or let you be?** (two pill choices plus optional words) | 34, 35, 36 |

**About 32 of 36 touched, from 8 prompts.** Not covered: 16 (what changed this
month — needs a baseline), 17 (sleep and movement — Health), 20 (deliberately
not asked). Calendar and Health then confirm or correct the day-one answers.

Each answer gets **one short follow-up** written from what they said ("You
mentioned Francis twice — who are they to you?" style, using their words, never
assuming pronouns). That is where the depth comes from without adding questions.

## What gets dropped

Age, gender, sexuality, relationship status, the dream-home pair. No core
question needs them; relationship status comes out of questions 1 and 5 if it
matters to the person. **Nothing is deleted** — the old list stays in the code
behind a switch, so it can be reconnected.

## How we'd know it worked (the gate)

Run the question store's first pass on **onboarding answers alone** and count
answers confident enough to speak. Today's onboarding vs the new one, on the
same person. You answering both (≈10 minutes, spoken) is the cleanest test.
Target: the new set answers at least twice as many questions. If it doesn't,
it doesn't ship.

Cost: two first-pass runs, about $0.30.

## Decisions for you

1. **The 7 questions** — wording is yours; change any.
2. **Drop age / gender / sexuality / relationship / dream home?** Recommended.
3. **One follow-up per answer, generated from what they said?** Recommended;
   adds a model call per answer (~$0.01 each on Haiku 5.5).

---

## v2: highest leverage, plus aspirations (founder, 20 Oct)

**The founder's direction:**
1. Pick the questions with the best chance of filling in the most about the person **beyond what the integrations will tell us**.
2. Ask about **goals and aspirations** (what they care about, what they want out of life) in a way that **feels inspiring to answer**.

### How "leverage" is scored

Each of the 36 questions is weighted by how replaceable it is:
- **3:** only their words can answer it (6, 24, 27, 28, 29, and the word-heavy 9, 11, 23, 32, 33, 34–36).
- **1:** a source also covers it (calendar, health, screen time, mail, LinkedIn).
- **0:** the source *is* connected (asking would waste their time).

A question's leverage is the sum over the core questions it moves. The set is chosen greedily (each next question adds the most *new* weight), the standard approximation for this kind of coverage problem.

### Where the questions come from (established methods, chosen because they replicate)
- **Best Possible Self** (King 2001; meta-analysis Carrillo et al. 2019): imagining life when everything has gone well. **Uplifting to answer** and rich in goals, values and the shape of their life.
- **Values questions,** borrowed from Acceptance and Commitment Therapy as a way of asking, not as therapy: what they'd protect even when it costs them.
- **The Life Story Interview's high point and low point** (McAdams): recent peaks and troughs, which reveal mood, phase and what matters.
- **Motivational interviewing's open questions** for change: what they keep meaning to change, and what's in the way.

### The proposed set: 8 core questions, plus 2 asked only if a source isn't connected

| # | Question (spoken, one follow-up each) | Moves | Leverage |
|---|---|---|---|
| 0 | What should I call you, and where are you based? | 5 | low (needed) |
| 1 | **Picture a year from now, and everything has gone as well as it realistically could. What does your life look like?** *(Best Possible Self: the inspiring one)* | 6, 10, 11, 4, 5, 23, 21 | **high** |
| 2 | **What do you care about most: the things you'd protect even if they cost you?** *(values)* | 6, 11, 23, 29, 32 | **high** |
| 3 | **What's been taking up most of your head lately?** | 27, 28, 29, 24, 10 | **highest** (all words-only) |
| 4 | **What are you working on right now, and how is it actually going?** | 1, 2, 3, 4, 11, 26, 28, 30 | high |
| 5 | **What's one thing you keep meaning to change, and what's gotten in the way so far?** *(MI)* | 6, 8, 9, 31, 32, 33 | **high** |
| 6 | **A high point and a low point from the last few months?** *(life story)* | 27, 28, 29, 30, 16, 9 | high |
| 7 | **Who would you call if something went wrong? Anyone you wish you saw more?** | 23, 24, 25, 22 | high |
| 8 | **How should I talk to you: straight or gentle, push you or let you be?** (our pick preselected from their words, goal 22) | 34, 35, 36 | needed |
| *f1* | *Only if Calendar or Health isn't connected:* Walk me through yesterday: what you did, who you saw, what you'd have skipped | 7, 12–15, 22, 30 | 0 if connected |
| *f2* | *Only if Screen Time or YouTube isn't connected:* What have you been reading, watching or learning lately, by choice? | 18, 19, 21 | 0 if connected |

**Coverage:** the 8 core questions touch about 30 of the 36, and **every words-only question**. With the fallbacks, it's about 34 for people who connect nothing. The questions that only behaviour can answer (17 sleep and movement, 20) are left to the sources by design.

### Why this order
- **It opens inspiring:** the future you want, then what you care about.
- **The heavier ones come once trust is built:** what's on your mind, the change you keep putting off.
- **It ends on people and on how to be spoken to.** The peak is question 1 and the end is warm (peak–end).
- **The fallbacks come after Connect,** so they're only asked when needed.

### Gate (unchanged, plus one)
- The first pass on onboarding answers alone must answer **at least twice as many** of the 36 as today's onboarding (≈$0.30 to test).
- **New:** the founder answers the set once, spoken, and judges whether it *felt* inspiring rather than like a form. That's the only instrument for "inspiring".

### Decisions for you
1. The wording of each question: yours to change.
2. Ask the 2 fallbacks only when the source is missing? (Recommended: it's what makes this "beyond the integrations".)
3. Connect before the conversation, so the fallbacks are known in advance, or after it, as planned? (Recommended: keep the conversation first, since it's the heart of onboarding, and ask the fallbacks after Connect.)
