# The new iOS app — everything to consider

One place for: the changes you've asked for, the problems you've hit in the
current app, and how the new app should be built around the new brain.
Started 19 October 2026; added to as we go. **Building starts after the
goal-spec work** — this is the brief it starts from.

The running problem list it grew out of is
[ios-app-review-log.md](./ios-app-review-log.md).

---

## 0. How this gets made — the process

Your direction, 19 October 2026. Three separate things, and they meet in a
fixed order:

| Thing | What it is | State |
|---|---|---|
| **The core product (the engine)** | The brain and everything it does: the 36 questions, facts, sources, the daily brief and weekly episode. Defines *what* the app must show and do. | Being built now (goal-spec work) |
| **The current iOS app** | Outdated; full of flow problems, redundancies and patches. | Problems being logged (section 2) |
| **The design system** | Your direction: a few tokens and ideas now, extended with your details. | You'll provide the starting elements |

**What changes the app — the inputs:**

- What the core product should be.
- How the core product should show up in the app.
- How I think the app should change, based on the core product.
- How you think the app should change, based on the core product.
- Plus the journey problems you log in the current app (section 2).

Together these produce **the entirely new flow — the new app experience.**

**The order:**

1. **Journey pass on the current app.** Analyse every user journey: what
   could change to make it flow and work better. You give me the problems; I
   map them and add what I find.
2. **The new flow.** From the inputs above, the full new app experience.
3. **You hand me the nucleus of the design system** — the tokens and ideas
   you have now.
4. **I take the first pass:** components built from that nucleus, for the new
   flows.
5. **You refine it** — add the tokens, the craft, everything that makes it
   right. Nothing is applied before you okay it.
6. **I take the second pass:** apply the refined design system to the iOS
   app.
7. **We test it** — use it, see how it feels, iterate.

So: engine (what) + journey problems (where it breaks) → new flow → design
system (nucleus → my components → your refinement) → applied → tested.

---

## The approach, in three steps (founder, 20 Oct)

This refines steps 1–2 of the process above.

1. **Audit the entire current app**, onboarding and every app screen: screen by screen, interaction by interaction, pixel by pixel. Every problem, redundancy, thing that doesn't make sense, and **every demo or fake** standing in for the real thing. Read psychologically too: what the person feels and thinks at each moment, across onboarding and daily use. Plan: [app-audit-plan.md](./app-audit-plan.md). **Only this step is being planned now.**
2. **Find where the new functionality must enter.** For every capability the core product now has (corrections, conversation, hypotheses, appetite, search, saved links, people, actions, the daily brief…), decide where it belongs, in onboarding and in the app.
3. **Design the new onboarding** that solves step 1's problems and introduces step 2's capabilities, then **carry it forward** into the home screen and how the app is used day to day.

**Demo vs ship.** A demo version to play with and a ship version for real people. The founder's lean: the demo is **an account**, not a separate app: the same build, signed into an account whose data is staged. The audit marks every demo/fake it finds as one of: remove from ship, move to the demo account, or replace with the real thing.

## Rules for every screen

1. **Every screen is purpose-built, not just present.** Its purpose is
   communicated **visually**, before anyone reads a word. (19 Oct)
   - *Example — the connections screen:* not a list of links to tap. It
     invites the person to share, shaped around "I need to get to know you to
     do the best for you" — showing what each source would let it understand
     about them.

## 1. Changes you've asked for

| # | Change | Source |
|---|---|---|
| 1 | **A new app**, reflecting how the product now works | 19 Oct |
| 2 | **Visual language = the paywall moment**: tap the podcast, the first insight plays, the buttons slide up from the bottom. That motion and pacing everywhere | 19 Oct |
| 3 | **Keep the shader's dots** — but never over text | 19 Oct |
| 4 | **Every screen must earn its place**: ask of each, is it conducive to a proper experience? Flow-wise: illogical, redundant, broken, patched together? | 19 Oct |
| 5 | **Restructure onboarding** around what the product now does and how intelligent it is | 19 Oct |
| 6 | **Onboarding asks a handful of questions that each reveal a lot** — stories, not opinions; covers most of the 36 from little input, so it feels ambient. Draft: [brief](./brief-onboarding-questions.md) | 18 Oct |
| 7 | **No canned podcast hosts.** A short voice conversation — a few pointed questions about what they listen to and watch — then the product *creates* their voice | 19 Oct |
| 8 | **The connections screen must say it's core**, not optional setup, and every source's state must be clear | 19 Oct |
| 9 | **Apple Calendar asked for on the iPhone; Google Calendar comes with the Google sign-in** | 18 Oct |
| 10 | **Share links into the app**, with a reason, from any app | 19 Oct |
| 11 | **Sign in with Google = connect Google, in one approval. Top priority** for the new app | 19 Oct |
| 12 | **Remove "Skip for now"** from the connections screen ("Here's what would help me know you best") — connecting is core, not optional | 19 Oct |
| 13 | **Accounts:** Sign in with Google (also connects Google), plain-words sign-in errors, sign out everywhere, delete my account. Server side built in the core; app side here. Download my data: later | 19 Oct |
| 14 | **The first episode arrives without a tap, once ingestion is complete.** Onboarding finishes reading everything they connected, then shepherds them into the app with their first episode ready. An experience the founder will design; the app just has to be capable of it | 19 Oct |

## 2. Problems in the current app

**Onboarding**
- The connections screen ("Here's what would help me know you best") doesn't
  say it matters; state labels ("Device sync", "First sync queued", a tick)
  don't explain themselves; AI-chat sources (Claude, ChatGPT, Grok) are clumsy
  file uploads; **"Make my podcast" covers the list**.
- Host picker (wise mentor / energetic host / thoughtful friend) — canned.
- After Play Podcast, "Learning about you" *and* a demo podcast — two things
  doing one job.
- **No way out of the demo player** (fixed in NPRdoinglaundry#11).
- **"Learning about you" hangs at 94%.** Diagnosed 19 Oct: after onboarding
  the app generates a **second** full episode (the questions screen already
  made one), and the percentage is fake — it creeps to 95% and waits for that
  episode (3–5 min, up to 10 if slow). Two episodes per onboarding ≈ $4 in
  voice, and the source of the multiple "Play podcast" buttons and sessions.
  New onboarding: **one episode, started early, honest progress, played once.**
- **The goals step also waited minutes** on the full pipeline — fixed
  server-side (#12).
- **Onboarding overall lacks clarity:** "Learning about you" after Play
  Podcast, multiple Play Podcast buttons and sessions. Needs one clear,
  linear story.
- Answers aren't saved until the goals step finishes — closing the app loses
  them.
- Redoing onboarding reused the *old* answers on the server (being fixed).

**Everywhere**
- **"Preparing your episode" looks frozen for 3–5 minutes.** It is generating a
  full real episode (outline, research, script, voice) with no progress shown.
  Every onboarding test also costs ~$2 in voice. Needs real progress (or a
  shorter first episode) and a test switch to skip generation.
- **After "Preparing your episode", it still showed the demo screen**, not the
  real episode (19 Oct). The server finished the episode ("Confronting the
  Build-Body Tradeoff", ready with audio at 21:16, $1.89), so the **app** gave
  up or lost the connection and fell back to the demo transcript. The app
  should wait for (or fetch) the finished episode, and any fallback should say
  it's a demo rather than pass it off as yours.
- **The Google connection is labelled "Google Docs"** in the app. It connects
  all of Google (Docs, Calendar, Gmail, YouTube) and should say "Google".
- Dots draw over text in the shader area.
- **~90 s launch after a rebuild**, white screen, then slow Face ID (mostly the
  debugger over Wi-Fi; to confirm). Render's free plan also sleeps when idle
  (up to ~50 s on the first request).
- Broken font files (saved web pages, not fonts); a listed font is missing.
- Audio set up in a way Apple warns can freeze the screen.
- **No share-in** (no share extension) and **shares out carry no link**.
- **Error messages are raw server output** ("HTTP 500: {...}") instead of
  saying what went wrong.
- **Two versions of the app** drifted apart (main vs the September design
  branch); an even older May copy with a different app ID broke sign-in.
- Uploads have **no retry**: a failed upload is silently lost.
- The iPhone sends **one summary of your calendar**, not each event — too thin.
- Five different onboarding flows exist in the code; 114 screens, 52,000 lines.

## 3. Building around the new brain

The old app was built around the old model (observations, insights, a
portrait document). The brain now works differently. The app should reflect
how it really works:

### What the brain is now
- **36 questions about you**, each with a current best answer, a
  **confidence** that grows with evidence, the **evidence itself** (exact
  quotes, traceable), and when it last moved.
- **Eight areas of life**, each with a bar it must clear before it speaks.
  *Below the bar it stays silent rather than guessing.*
- **Facts** pulled from your writing and sources, every one tied to the exact
  words it came from.
- **Sources** (Google, iPhone, Notion later) feed it continuously.
- **Two outputs**: a daily brief (about what changed; can be short) and a
  weekly episode (deeper).

### What that means for the app

| Brain property | App consequence | Goal |
|---|---|---|
| Answers have confidence and receipts | A **"What I know about you"** view: each answer, how sure, and *why* — tap for the quote it rests on | 10, 6 |
| You can correct it | **Correct any answer in one tap** ("not me" / "still true"), and it sticks | 20 |
| Areas stay silent below their bar | Show honestly what it **doesn't know yet** — warmly ("I don't know much about your days yet"), never as a percentage | 10, 24 |
| Ambient, not an interview | Ask only to **confirm** something it already guessed, never a questionnaire | ambient principle |
| Sources feed it | A **Sources** view where you never wonder whether something made it in: last read, what it read, what it's used for | 2, 1 |
| Daily brief about what changed | **Today** = the brief, audio *and* text; short on quiet days, says why each item is there | 13–16, 11 |
| Weekly episode | **Episodes** = the weekly deep one | 13–16 |
| Links with reasons | **Share to Retrospect** + "why are you saving this?"; links never change what it thinks of you | 23, 1 |
| How you like to consume | Ask audio vs reading during onboarding, then **respect it in onboarding itself** | two outputs |
| Daily brief is intrusive | Brief **off by default**, one tap to turn on; length cap visible | daily brief |
| Claims careful, craft captivating | Warm, well-made prose and motion; nothing asserted about you without support | 14 |
| Onboarding is the richest words source | Voice-first, story questions, one follow-up each; **ends with something true you recognise** | 24 |
| Talks like a friend | Calibrated directness from onboarding Q7 ("straight or gentle?") | 22, 9 |

### Onboarding, re-thought (draft order)
1. **What this is, upfront** — honest, short.
2. **Sign in with Apple.**
3. **The conversation** — the 8 story questions, voice-first, one follow-up
   each. Answers saved as you go.
4. **Connect** — presented as core, each source saying *which questions it
   answers* ("Calendar → what your weeks look like"), clear states.
5. **Your voice** — a few questions about what you listen to → a voice made
   for you.
6. **The first insight** — the paywall moment: one true, specific thing about
   you plays, then the buttons slide up.

### Technical considerations
- **A separate new project** beside the old one, not a "redesign" folder
  inside it. Old app untouched until the new one covers the core loop.
- **Reuse**: the server client, Apple sign-in, Health and calendar readers,
  sleep maths, the paywall's colours and motion.
- **One app ID**, and the server accepts it at sign-in (the May copy's
  different ID is what broke sign-in today).
- **Uploads retry** until they succeed; every entry shows whether it's in.
- **Errors in plain words.**
- **Nothing slow on the launch path**; no fake progress bars — show real
  progress or none.
- **Server work the app needs that doesn't exist yet**: an endpoint for "what I
  know about you" (answers, confidence, evidence), one for corrections, the
  daily brief, link saving, and voice creation.

### Option: a constellation view of the brain
Founder's question, 19 October 2026. The brain is already graph-shaped —
entities as points, facts as lines between them (each from your exact words),
patterns as clusters, answers linked to their evidence; saved links will link
to the goals they bear on. A read-only graph can be built from it with no new
storage. In "What I know about you", tapping a point would show its receipts;
it would sit naturally with the shader's dots. **Prerequisite:** goal 4
(never confusing two people), or the graph shows duplicates. First as an
internal "your brain" page in pipeline-canvas to judge quality.

### Sign in with Google = connect Google, in one step
Founder's request, 19 October 2026: sign in with Google and grant data access
in the same approval. Possible, and worth doing. Considerations:
- **Keep Sign in with Apple too** — Apple requires an equivalent private
  sign-in option whenever a third-party one is offered.
- **Ask for the right amount at sign-in.** Calendar and Docs (read-only) on
  the first screen are reasonable; Gmail is a "restricted" permission with a
  scarier consent screen and Google's security review before public launch, so
  it is better asked for later, in context. Google itself recommends asking
  incrementally.
- **Server work:** accounts are keyed by Apple ID today; they need a Google ID
  too, and linking when the same person uses both.
- **Unverified-app warning** shows to everyone until Google verifies the app —
  fine for the beta (up to 100 test users), not for launch.

## Separate project: the full audit of the iOS app

Founder, 19 October 2026. **Start only once the core product's goals are met
and the core is set up well** — then, when I'm confident the time is right, a
complete audit pass of the iOS app and its structure, every screen, written up
as its own doc. For each screen, everything that is:

- redundant
- a problem or broken
- an interaction issue
- not making sense
- confusing for the user
- not fun in onboarding
- not feeling good
- not inspiring
- flat

Part of the V2 app work; feeds step 1 (the journey pass) of the process above.

## 4. Open questions for you
- Tabs (Today · You · Sources) or one scrolling home?
- Name for the new project while both exist?
- Does onboarding end in the paywall, or after the first insight?


## Settings: ambient on/off (founder, 20 Oct)
A toggle in Settings for `users.ambient_enabled` (agent #101). Off = only what you send is read; nothing in the background. Plain words: "Let Retrospect read your connected apps in the background."


## Search screen, v1 (founder, 20 Oct)
Type a question → sources appear first (`POST /search/sources`, ~1 s) → "What we found" fills in on top (`POST /search/answer`) → tap any source to open it in full (`GET /search/:userId/source/:kind/:id`). Plain empty state when nothing answers.
