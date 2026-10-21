# Retrospect iOS: problems and refresh, in one document

> **Replaced.** This is the earlier version. The current one is [ios-problems-changes-solutions.md](./ios-problems-changes-solutions.md) (problems → what to change → solutions, with the north star, the sign-in screens and the contradiction fixes). Where they differ, the new one is right. Kept only until you say it can go.

20 October 2026, night. **Everything about the iOS app in one place:** every problem found in today's app, each shown beside the new screen that replaces it, and the whole refresh: what the product is, how it's used, what the backend can do, the new screens, the rules, the build order and the process. Generated from the source documents so nothing is dropped: [app-audit.md](./app-audit.md), [app-audit-deep.md](./app-audit-deep.md), [app-audit-research.md](./app-audit-research.md), [ios-refresh-blueprint.md](./ios-refresh-blueprint.md), [ios-refresh-plan.md](./ios-refresh-plan.md), [ios-refresh-opportunities.md](./ios-refresh-opportunities.md). Board: https://claude.ai/artifact/9uf2mRH9rk9RKneh4XrQDb

**In numbers:** 167 problem entries (10 blockers · 62 major · 76 minor · 19 notes or repeats) across 33 of today's screens; 41 new screens; 22 backend gaps (K1–K22); 33 opportunities (O-0 to O-32).

**How to read it:** Part A is the product and its users. Part B is the heart of it: **screen by screen, today → problems → the new screen.** Part C covers problems and work that belong to no single screen. Parts D–G are the refresh in full: backend, rules, build, process. Appendices list every finding and every module.

## Contents
- Part A. The product, how it's used, and the worst problems
- Part B. Screen by screen: today, its problems, and what replaces it
- Part C. Across the whole app
- Part D. The backend: what it can do, and the gaps
- Part E. The new app's rules: principles, constraints, conflicts reconciled
- Part F. Building it: the data contract, the order, the defaults
- Part G. The process
- Part H. Opportunities: every one
- Part I. Everything the founder asked for
- Part J. The design system
- Part K. The audit's step-by-step plan and the ranked list
- Appendix 1. Every finding, indexed
- Appendix 2. Verified behaviour and the completeness check
- Appendix 3. Module index

---

# Part A. The product, how it's used, and the worst problems

## 1. The product in one page

**The mission** ([goal-specs](./goal-specs.md)): *a companion that knows you and helps you grow. It learns on its own from what you write and do. You can hand it things. You talk to it in small pieces, continuously. It quietly handles the boring admin of your life. Talking to it feels soothing, not clinical.*

**Ambient by default** (decided 17 Oct): *the default user sends nothing.* Onboarding and connected sources are the substrate; journals are valuable context; links are a power-user bonus. The product must be good for someone who never types.

**The loop every hard thing follows:** **evidence → a question → their answer** (then, later, optionally an option). No verdicts. "Introspection, externalised." The product does the work; the person does the thinking.

**Two audio outputs, one profile:**
- **The daily brief:** the day's short episode (typically 4–5 min, cap 12, floor ~45 s; the cap announces itself), about what changed, framed by who you are and what you're trying to do; each item says why it's there; **on/off per person, off by default.**
- **The weekly episode:** the deep one: patterns, goals said vs did, reflection, and at most one question it's wondering about.

**The claim ladder** (how anything about a person is said): facts and patterns from evidence are **stated**; inferences and guesses are **asked**, never stated, and always carry how sure it is and what they rest on. Predictions are welcome; made-up content is not.

**The interaction shape** (founder, 20 Oct): a bottom bar, **one feature per page**, each page showing its feature off fully: **Journal · Podcasts · Goals · You**. Onboarding is **voice-first**: you can talk through every question and it talks back, opening with **the mission told by voice**, then questions → privacy → integrations → more questions → **the podcast tease** → **a scrollable paywall showing every benefit** → into the app, with guidance.

## 2. How it's actually used today

From the findings log and status (founder's account; production reads are by counts only):

| Fact | Source | What it means for the design |
|---|---|---|
| **5 written entries in the last 4 months**; 58 were in May | finding 15 | Journal can't be the engine. The app must be valuable to someone who doesn't write. |
| Last 120 days: **calendar on 35 days, health on 79, subscriptions 20, mail 1, own writing 2** | finding 16 | Passive sources carry the picture. Connect is the most important onboarding step after the questions. |
| 555 people stored: 300 from contacts, 211 named in writing, 8 from calendars; writing and contacts not yet joined | finding 17 (W2 merged) | The map's people layer is rich but needs matching; "same person?" questions are how the person helps. |
| 66 answers to the 36 questions, every one traced to evidence (2,636 links) | finding 14 | "What it knows about you" is real and inspectable today. |
| 72 patterns, all honestly "not enough to say yet" for change | findings 6–7 | Trajectories become readable from mid-November; the app must show "too early to tell" gracefully. |
| Reading after something is sent: median 2.5 min | finding 10 | "Read by the brain" can be shown within minutes of sending. |
| Cost ≈ $3.30 per user per week; first week ≈ $5–7 (two first episodes) | cost-per-user | One first episode, not two; the daily brief is the cost lever (speech is 20–40× thinking). |
| Testers: none yet; TestFlight not started | tester-readiness | The refresh ships to testers first; the demo is an account. |

**The design consequence, in one line:** the app must open each day with something already made for you (the brief, an episode, a question, a change), not with an empty box asking you to write.

## The blockers, and what fixes each

| # | Blocker | Today, on | Fixed by (new screens) |
|---|---|---|---|
| 1 | **N19**: In a release build the paywall has no way out (close is debug-only; subscribing can't work) | Paywall (`PodcastPaywallFlow`) | N12 |
| 2 | **N20**: The first episode can never be replayed after onboarding (player needs a local file) | The episode player | P2 P3 X2 |
| 3 | **Y26**: No episode can be heard in the app after onboarding (the player never downloads server episodes) | The episode player | P2 P3 X2 |
| 4 | **Y12**: Deleting an entry only removes it from the phone; the brain keeps it | A single entry | J4 |
| 5 | **N1**: "Learning about you" shows canned claims about the person as if they were real | "Learning about you" | N10 |
| 6 | **A1**: A failed first podcast is silent | When the first episode fails | N10 N11 |
| 7 | **J1**: A failed entry upload is lost silently | Journal (`DarkJournalView`) | J1 J2 |
| 8 | **G1**: The phone's goal list overrides the brain on every change | Goals (`DarkGoalsView`) | G1 G2 |
| 9 | **T1**: Every user sees Settings → "Advanced: Dev tools and experiments" (not debug-only) | Settings (`DarkSettingsView`) | T1 |
| 10 | **T2**: The legacy home screen shows hard-coded fake podcasts ("Love and Relationships", "Career Growth", "Personal Health", "Family Connections", each with " | Advanced (developer tools) | T1 (removed from the shipped app) |

### Why the blockers matter (root causes and the rule each sets)

### B1 (A1): A failed first podcast is silent

| | |
|---|---|
| **Root cause** | `startFirstPodcastHandoff` catches the error, stores it in `firstPodcastError`, and immediately calls `finishFinale()`. Nothing ever reads `firstPodcastError`. The code treats "end onboarding gracefully" as hiding the failure |
| **What the person experiences** | They finish 18 questions, connect their sources, pick a host, tap "Play Podcast", watch "Learning about you" for minutes, then land on an empty home screen with no podcast and no word about why. The peak of onboarding becomes its lowest point |
| **Principle** | *Visibility of system status* (Nielsen's first heuristic): the system should always tell people what's going on. And *peak–end* (Kahneman 1993): people remember the peak and the end, and here both are failures |
| **What good looks like** | Say what happened in plain words, keep what was done, offer the next step: "Your first episode didn't finish. Your answers are saved. Try again now, or we'll make it tonight and tell you." |
| **Constraint** | **Every failure after a wait is named in plain words, with a retry or a promise, and nothing the person did is lost. No failure path lands silently.** |

### B2 (J1): A failed journal upload is lost silently

| | |
|---|---|
| **Root cause** | `syncEntryToBackend` fires once in a background task; a failure is only `print`ed. The `Entry` model has no synced state, so nothing knows to retry; no queue exists |
| **What the person experiences** | They write; it looks saved (it is, on the phone). But the brain never receives it: it's missing from episodes, the brief and search, with no way to tell. Trust erodes invisibly: "it doesn't know what I told it" |
| **Principle** | *Durable writes and eventual consistency:* standard offline-first design keeps an outbox and retries with backoff until the server confirms (the pattern used by Notes, Day One, Things). Plus visibility of system status |
| **What good looks like** | Every entry has a state: saved on the phone → sent → read by the brain. A small mark shows it. Failed sends retry automatically (with backoff, and on reconnect); after a long failure, one quiet notice |
| **Constraint** | **Nothing written is ever lost: every capture is queued until the server confirms it, retried with backoff, and its state is visible. Editing re-sends. One upload per capture (no double writes).** Also covers J2, J3, R1 |

### B3 (G1): The phone's goal list overrides the brain

| | |
|---|---|
| **Root cause** | Two sources of truth. The app treats its local list as authoritative and reconciles the server to it on every change: it re-activates whatever the server turned off, and turns off whatever the phone doesn't know |
| **What the person experiences** | Goals they stopped mentioning keep coming back; duplicates pile up (31 "active" from June); episodes are built on goals that aren't theirs any more. The brain's "goals expire when you stop living them" can't work |
| **Principle** | *A single source of truth* for each piece of state; client changes as intents ("I added X", "I removed Y"), never "replace the server with my list" |
| **What good looks like** | The server (the brain) owns goals; the app shows the server's view (active, expired, merged, said-vs-did) and sends only what the person did |
| **Constraint** | **The server owns goals. The app sends only intents (add, rename, turn off, revive) and never reconciles by overwriting. The person always sees the brain's view.** *(The server half is fixed: NPRdoinglaundry#19.)* |

### B4 (T1): Every user can open Dev tools

| | |
|---|---|
| **Root cause** | Development tools were added to the shipped Settings screen behind a user-visible "Advanced" row and a "Dev Mode" toggle stored in `@AppStorage`, not behind `#if DEBUG` or a server-side staff flag |
| **What the person experiences** | A curious person finds "Dev tools and experiments", flips Dev Mode, and can generate mock podcasts, replay onboarding, open a fake old home screen, and trigger real podcast generations (real cost) |
| **Principle** | *Separate builds or accounts for development* (a staging build, TestFlight, or staff-only flags). Apple's review guidelines also reject apps with visible test or debug features (Guideline 2.2: "beta versions … should be submitted to TestFlight") |
| **What good looks like** | Dev tools exist only in debug builds; anything needed in production for the team is gated by a server-side staff flag on the account (the **demo account** idea) |
| **Constraint** | **A release build contains no developer tools, mock data paths or previews. Team-only tools are gated by a server-side staff role, never a toggle on the device.** Also covers T2–T6, R2 |

### B5 (T2): A fake home screen with made-up podcasts is reachable

| | |
|---|---|
| **Root cause** | A legacy home screen with a hard-coded `mockPodcasts` array was kept for comparison and wired to a Settings button |
| **What the person experiences** | "Love and Relationships", "Career Growth"…, episodes about a life that isn't theirs, inside a product whose whole promise is "about you". It breaks the product's core trust at the root |
| **Principle** | *Honesty of content* (goal 4: never claim beyond evidence). Fabricated personal content is the opposite of the product |
| **What good looks like** | Sample content lives only in the demo account and is labelled as such; the ship build never contains canned personal content |
| **Constraint** | **No canned personal content in the ship build. Anything shown as "yours" comes from the person's own data; demo content lives only in the labelled demo account.** Also covers A5, A6, T3 |

---

### The major problems, by theme

#### M1. Labels that promise what they don't do (C1, E1, W1)
- **Root cause:** buttons named for the outcome the team hoped for, not what they do. "Make my podcast" advances to the host picker; "Play Podcast" starts minutes of generation; the welcome sells the old product.
- **Experience:** each tap breaks a small promise right before the biggest moment, so by the peak the person has learned the labels lie.
- **Principle:** *Match between system and the real world* (Nielsen #2); labels describe the action, not the hope.
- **Constraint:** **Every button says exactly what happens next. A promise of an outcome ("play", "make") appears only when that outcome is immediate.**

#### M2. Waits that aren't honest (A3, A5)
- **Root cause:** a fake percentage (asymptotic creep to 95%) covers an unknown generation time; onboarding is marked complete before the episode exists.
- **Experience:** "Learning about you 94%" for minutes; then, if the app was closed, nothing.
- **Principle:** Maister (1985): uncertain and unexplained waits feel longer. Nielsen: status must be true. Research on progress indicators (Myers 1985; Harrison et al. 2007) finds false progress damages trust when it stalls.
- **What good looks like:** real stages ("reading your calendar… writing… recording the voice"), start the work early (at Connect), and keep the person busy with something meaningful.
- **Constraint:** **No progress number that isn't real. Every wait over 3 s names its real stage. Long work starts as early as possible and survives the app closing.**

#### M3. Asking too much, too soon, the wrong things (V1–V5, C4)
- **Root cause:** a form of demographics first (18 questions; sexual orientation without purpose; a dream house at the end) and 17 sources at once.
- **Experience:** it feels like a sign-up form before it feels like being understood; sensitive questions arrive before trust; choice overload at Connect.
- **Principle:** reciprocity and trust before ask; Hick's law (more options, slower and worse decisions); peak–end (end on the deepest moment, not a quiz); data minimisation (collect only what has a use).
- **What good looks like:** the 8 story questions ([brief](./brief-onboarding-questions.md)), voice-first, each one acknowledged so understanding is felt; a few recommended sources first, the rest behind "more".
- **Constraint:** **Every onboarding question has a stated use. Nothing sensitive without a reason the person can see. Connect shows at most 5 recommended sources up front. Onboarding ends on its strongest moment.**

#### M4. Connections that don't explain themselves (C2, C5, C6, C8)
- **Root cause:** the screen mirrors the backend's model (one card per provider object; engineering status words; file importers mid-flow); Google is hard-coded never "connected".
- **Experience:** "Google Docs" and "Gmail" and "YouTube" as three asks for one sign-in; "API-tier gated sync" as a label; no idea what anything is for.
- **Principle:** speak the person's language; one action per intent; show value before asking (permission priming).
- **What good looks like:** one Google card ("Google: your docs, mail, calendar and YouTube"); each source says what it helps the brain understand; states in plain words ("Connected · read 2 min ago"); file imports offered later, not in onboarding.
- **Constraint:** **One card per account the person signs into. Every source states, in a sentence, what it helps it understand. States use plain words. No file imports in onboarding.**

#### M5. Sign in with Apple styling (W3)
- **Root cause:** a custom-styled button (cream, grey label).
- **Risk:** App Review rejection and low contrast.
- **Principle:** Apple's HIG for Sign in with Apple (approved styles, minimum sizes and contrast).
- **Constraint:** **Use Apple's standard button (or the HIG's permitted custom form) with sufficient contrast.**

#### M6. Privacy said wrongly, or not at all (D1, V2)
- **Root cause:** old copy claiming on-device processing (false); a sensitive question with no purpose; no privacy step on the live path.
- **Experience / risk:** in the dead code, a false promise waiting to be revived; on the live path, nothing that earns trust for the asks.
- **Principle:** *contextual integrity* (Nissenbaum): say what flows where, for what. Data minimisation. Apple's privacy expectations.
- **What good looks like:** the founder's "show off the privacy" step: what it reads, where it's processed (honestly: our server and named AI providers), what it never does, the ambient switch, delete anytime.
- **Constraint:** **Every privacy statement is true and specific. The privacy step names what's read, where it's processed and how to turn it off or delete. No question asks for sensitive data without a visible use.**

#### M7. No way back, nothing saved within a step (O1, O2)
- **Root cause:** one-way step flags; per-answer state kept only in memory.
- **Principle:** user control and freedom (Nielsen #3); save as you go.
- **Constraint:** **Every onboarding step can go back. Every answer is saved the moment it's given and restored on reopen.**

#### M8. Raw errors and a general prompt proxy (X1, X3, J6)
- **Root cause:** errors are passed straight from the network layer to the screen; AI prompts are written in the app and sent to a general proxy.
- **Principle:** error messages in plain language that say what to do (Nielsen #9); server-side ownership of prompts (security, cost and consistency).
- **Constraint:** **No raw error text reaches the screen; every error has a plain sentence and a next step. The app never sends AI prompts; each feature calls its own server endpoint.**

#### M9. The brain's view never reaches the person (G3, host P1–P2, Podcasts dev R2)
- **Root cause:** the app shows its own local state (its goals list, its host choice) rather than what the brain knows; capabilities built on the server have no screens.
- **Principle:** the app is the brain's window (ios-v2 §3).
- **Constraint:** **Every capability the brain has is visible where it belongs (stage 2's map), with how sure it is and why, and is correctable.**

---

---

# Part B. Screen by screen: today, its problems, and what replaces it

For each of today's screens: what it is, **every problem found on it** (severity, kind, what happened, evidence), and **the new screen or screens that replace it**, in full: one feature, what's on it, the opportunities and backend gaps pinned to it, the backend behind it (✓ reachable today · ◐ built in the brain, needs a backend route · ✗ to build), its states, what it closes, and a lo-fi sketch.

## Onboarding

### Today: Welcome and sign-in (`WelcomeSignInPage`)

**Problems on this screen:**

- **W1** · Major · doesn't make sense (now) · not inspiring: **The promise is the old product:** "Your life, turned into a weekly podcast. Journal entries, voice notes, health data…". Nothing about the daily brief, search, talking to it, or a brain that knows you  
  *Evidence:* screenshot `welcome.png`
- **W2** · Minor · pixel · inconsistent: **Canvas colour differs from the paywall:** a cool grey here vs warm paper `#F4F2EE` on the paywall; the first impression and the payoff don't match  
  *Evidence:* screenshot vs `PodcastPaywallFlow.swift` `Pod.bg`
- **W3** · Major · risk · pixel: **The Sign in with Apple button is restyled** (cream, grey label): Apple's guidelines constrain this button, so it's an App Review risk, and the grey-on-cream label is low contrast  
  *Evidence:* screenshot
- **W4** · Minor · pixel · flat: A large empty middle: text sits top-left, the button at the bottom, about 40% of the screen empty with nothing drawing the eye  
  *Evidence:* screenshot
- **W5** · Note · demo (ok): "DEV: Sign in as new test user" is visible; confirmed debug-only (`#if DEBUG`)  
  *Evidence:* `WelcomeSignInPage.swift:114–123`
- **W6** · Major · pixel · broken (brand): **The app is named "Retrospect-2026"** in both debug *and* release configurations, so that's what appears under the icon and in Apple's sign-in sheet ("Create an account for Retrospect-2026")  
  *Evidence:* `project.pbxproj:657, 702` (`INFOPLIST_KEY_CFBundleDisplayName`); simulator screenshot
- **W7** · Minor · interaction: **Tapping Sign in with Apple gives no feedback for ~2 s** (no pressed state, no spinner) before Apple's sheet appears; people tap again  
  *Evidence:* simulator
- **X5** · Note · audit blocker: The DEV test-user sign-in only works against a local server (production correctly returns 404), so a fresh simulator can't get past screen 1 without a real Apple ID or a local backend  
  *Evidence:* `backend/src/routes/auth.ts:60–70`

**Becomes:** N1 N2 N3

#### N1. Talk or read?

**One feature:** Choose how onboarding speaks to you.

**On it:**
- Two choices: Talk with me (preselected) · Read instead
- One line: you can switch anytime
- Stored as your listening preference; the rest of onboarding honours it

**Pinned (opportunities O, backend gaps K):** **K14** store the listening preference · **Spec** onboarding respects how you like to take things in

**Backend:** ✗ PUT /profile/consumption  
**States:** none (static)  
**Closes:** spec gap

```
┌─────────────────────────┐
│                         │
│      (the mark)         │
│                         │
│  How should we do this? │
│                         │
│  ┌───────────────────┐  │
│  │ ● Talk with me    │  │
│  └───────────────────┘  │
│  ┌───────────────────┐  │
│  │ ○ Read instead    │  │
│  └───────────────────┘  │
│  You can switch anytime │
└─────────────────────────┘
```

#### N2. The mission (voice)

**One feature:** Say what Retrospect is for, before asking anything.

**On it:**
- Spoken in the app voice, words appearing as spoken
- Under 30 seconds; every word true today
- Replay · Skip · works with sound off
- Haptic on the key line

**Pinned (opportunities O, backend gaps K):** **O-19** one voice everywhere · **Founder** mission told by voice

**Backend:** ✓ pre-recorded audio (same for everyone)  
**States:** playing · paused · muted (text only)  
**Closes:** W1, W2, N8

```
┌─────────────────────────┐
│ Skip                    │
│                         │
│ "I'm here to get to know│
│  you, from what you tell│
│  me and what your days  │
│  show. Then I'll give it│
│  back…"                 │
│                         │
│        ∿∿∿∿∿            │
│                         │
│  [ Continue ]  Replay ↺ │
└─────────────────────────┘
```

#### N3. Sign in

**One feature:** Create your account.

**On it:**
- Apple's standard Sign in with Apple
- Continue with Google (also connects Google, one approval)
- Pressed state and a spinner; plain-words errors

**Pinned (opportunities O, backend gaps K):** **O-25** standard controls · **ios-v2 #11** Google sign-in = connect Google

**Backend:** ✓ /auth/signin · ✗ Google sign-in  
**States:** idle · signing in · failed · offline  
**Closes:** W3, W6, W7, C5

```
┌─────────────────────────┐
│                         │
│ "To remember you, I need│
│  an account."           │
│                         │
│                         │
│ [  Sign in with Apple ] │
│ [ Continue with Google] │
│   also connects Google  │
└─────────────────────────┘
```

---

### Today: Intro ("Before we begin…")

**Problems on this screen:**

- **V8** · Minor · pixel · psychological: *(simulator)* The intro ("Before we begin… Everything you share is private.") promises privacy in one line with nothing behind it; its **Continue label is mid-grey on cream**, low contrast, the same problem as W3  
  *Evidence:* `.scratch/audit` screenshot, 20 Oct

**Becomes:** N2

*N2 is described above.*

---

### Today: Your name

**Problems on this screen:**

- **V9** · Minor · redundant · interaction: *(simulator)* **"What should I call you?" comes right after Sign in with Apple,** which can already supply the name; first question is a form field, keyboard up, no Back  
  *Evidence:* simulator
- **N10** · Minor · interaction: **Return doesn't send an answer;** it closes the keyboard and the answer stays in the field, so you hunt for the arrow  
  *Evidence:* simulator

**Becomes:** N4

#### N4. Questions: your story

**One feature:** Get to know you by talking.

**On it:**
- One question at a time, spoken; you answer by voice (or type)
- Live transcript; haptics when listening starts and stops
- A real acknowledgement after each answer (proves it heard)
- At most one follow-up, only when it would settle a lot
- Back always; each answer saved the moment it is given; "3 of 4"

**Pinned (opportunities O, backend gaps K):** **O-19** voice in and out · **K5** streamed voice for quick replies · **O-21** answers saved instantly

**Backend:** ◐ acknowledgements via conversation (✗ backend route) · ✗ /speech/stream  
**States:** listening · thinking · speaking · typed · offline (queued)  
**Closes:** V1, V2, V4, V5, V9, N6, N9, N10, O1, O2

```
┌─────────────────────────┐
│ ‹ Back          2 of 4  │
│                         │
│ "Tell me about a moment │
│  this year you felt most│
│  like yourself."        │
│                         │
│     ◉ listening…        │
│ "…the morning I finally │
│  shipped it…"           │
│                         │
│ [type instead]   [Done] │
└─────────────────────────┘
```

---

### Today: Demographic questions (age, gender, relationship, job)

**Problems on this screen:**

- **V1** · Major · psychological · doesn't feel good: **18 questions, demographics first:** name, city, age, gender, **sexual orientation**, relationship status, job, how you feel about it, *before* any of the meaningful ones. Sensitive questions are asked before any trust is earned, and in an order that reads like a form  
  *Evidence:* `VoiceGoalsPage.swift:92–135`
- **V5** · Minor · interaction: **The progress bar is non-linear:** 8 demographic answers move it 8%→22%, then single deep answers jump 11–13 points; it misrepresents how much is left  
  *Evidence:* `progress:` values
- **N11** · Minor · pixel · interaction: **A picked option barely changes colour** (gender, relationship), so it's hard to see what you chose  
  *Evidence:* simulator
- **L1** · Note · broken: **Closing the app mid-onboarding loses everything:** a relaunch starts the questions again from the intro. Confirms O2 on a running build  
  *Evidence:* simulator
- **L15** · Note · interaction (debug only): The debug Skip needs two taps the first time (the first is swallowed while the keyboard comes up)  
  *Evidence:* simulator

**Becomes:** N4

*N4 is described above.*

---

### Today: Sexual orientation question

**Problems on this screen:**

- **V2** · Major · psychological · risk (privacy): **Sexual orientation is asked at all, in onboarding,** with no stated reason or use. Sensitive personal data, collected without purpose  
  *Evidence:* `:103`
- **N9** · Major · psychological · privacy: **The sexuality question is free text with no way to decline** (unlike gender, which has "Prefer not to say"); the keyboard opens straight away  
  *Evidence:* simulator

**Becomes:** N4

*N4 is described above.*

---

### Today: The deeper questions and acknowledgements

**Problems on this screen:**

- **V4** · Major · psychological · not fun: **Long:** 18 questions before the person gets anything back. The 8 story questions in [the onboarding brief](./brief-onboarding-questions.md) were designed to cover most of the 36 with far less  
  *Evidence:* count
- **N6** · Minor · not inspiring: **Every acknowledgement is the same line**, "Thank you. That helps.", whatever the answer (the AI-made reply falls back to it); after the first few it proves nothing was heard  
  *Evidence:* simulator; `/claude/generate` called once per deep answer (9 calls)
- **N7** · Minor · risk (cost): **Each deep answer makes its own AI call through the general prompt proxy** (`/claude/generate`, 9 per onboarding), so the app writes prompts client-side for every answer (adds to X1)  
  *Evidence:* stand-in server log
- **V7** · Minor · logic risk: **Many timed delays** drive the conversation's pacing (asyncAfter at 0.28 s, 0.1 s, 0.32 s, 0.2 s, plus "dwell" and "ack dissolve"); pacing breaks on a slow device  
  *Evidence:* `:312, 372, 467, 598, 887, 1028`
- **O1** · Major · interaction: **No way back between steps.** Steps are one-way flags; there is no back button or gesture from one step to the previous one (within the voice questions there is a Back)  
  *Evidence:* `DarkOnboardingFlow.swift:19–25, 29–77`
- **O2** · Major · broken: **Answers within a step aren't saved:** only step completion persists, so closing the app during the voice questions loses them (confirms a logged problem)  
  *Evidence:* `OnboardingState.swift:134–173`
- **Y46** · Minor · performance: *Onboarding acknowledgements:* Each acknowledgement dissolves into particles drawn by a `Canvas` at 60 fps; fine for a moment, but it runs on top of the typing keyboard  
  *Evidence:* deep pass (simulator, sample data)

**Becomes:** N4 N8

*N4 is described above.*

#### N8. Questions: where you’re headed

**One feature:** Your goals and aspirations, asked to inspire.

**On it:**
- 3–4 questions chosen after seeing what you connected (never asks what a source will say)
- Goals and aspirations: what you want out of life, what you are working toward
- Same voice and controls as N4

**Pinned (opportunities O, backend gaps K):** **Founder** inspiring goals questions · **Goal 24** cold start

**Backend:** ◐ /onboarding/goals (✗ backend route)  
**States:** as N4  
**Closes:** V3, V4

```
┌─────────────────────────┐
│ ‹ Back          1 of 3  │
│ "A year from now, what  │
│  would make you proud of│
│  this one?"             │
│                         │
│     ◉ listening…        │
│                         │
│ [type instead]   [Done] │
└─────────────────────────┘
```

---

### Today: Bridge screens

**Problems on this screen:**

- **N8** · Minor · psychological · interaction: **Three "bridge" screens with no Back** ("These next ones go a little deeper", "Now, the real reason you're here", "Now dream a little bigger… because with me, it is"). The last one promises what the product can't keep  
  *Evidence:* simulator

**Becomes:** N4 N8

*N4 is described above.*

*N8 is described above.*

---

### Today: Dream city and dream home

**Problems on this screen:**

- **V3** · Major · psychological · flat: **It ends on a dream city and a dream house** ("Suburban Mansion · Farmhouse · Cabin · Tiny Home"): quiz-like, after the deepest questions; the peak–end shape is inverted (it ends flat)  
  *Evidence:* `:131–134`
- **N12** · Minor · pixel: **The home-type grid misaligns:** two-line labels make some cards taller, so the two columns don't line up  
  *Evidence:* simulator

**Becomes:** N8

*N8 is described above.*

---

### Today: Thinking ("wonderings")

**Problems on this screen:**

- **N5** · Major · demo or fake · doesn't make sense: **The "wonderings" fallback is canned and written in the third person** ("What are *they* protecting when *they* stay this busy?"), shown whenever the AI call fails; the lines assume a busy achiever  
  *Evidence:* `VoiceGoalsPage.swift:1223–1232`; simulator

**Becomes:** N10

#### N10. Making your first episode

**One feature:** An honest wait, while it reads you.

**On it:**
- Real stages: reading your calendar ✓ · writing · recording the voice
- A line from your own answers while you wait
- No percentage; nothing canned
- Close the app and it tells you when it is ready

**Pinned (opportunities O, backend gaps K):** **O-22** honest waits · **Readiness** reading → understanding → making_episode → ready · **K21** magic moments for the line it shows

**Backend:** ◐ /onboarding/readiness, /advance (✗ backend routes)  
**States:** reading · understanding · making · ready · failed (plain words, retry or tonight) · slow  
**Closes:** A1, A3, A5, N1, N3, N4, N23, Y44

```
┌─────────────────────────┐
│                         │
│ Reading your calendar ✓ │
│ Writing your episode  ◌ │
│ Recording the voice     │
│                         │
│ "You said mornings are  │
│  when you think best."  │
│        ← your words     │
│                         │
│ We'll let you know if   │
│ you'd rather close this │
└─────────────────────────┘
```

---

### Today: Goal cards

**Problems on this screen:**

- **A2** · Major · logic: **The goals from the voice step are dropped at the handoff.** The closing page calls `onComplete?([])`, so the first podcast is requested with an empty goals list (goals were saved locally to `GoalsManager`; whether the server gets them another way is unverified)  
  *Evidence:* `DarkOnboardingFlow.swift:65`
- **A7** · Major · broken · cost · redundant: **Every onboarding generates two first episodes and discards one.** When the questions finish, `finishProcessing` starts a real generation (`prefetchPodcast`) *before any source is connected and before the profile is uploaded*; on the normal path that episode is never shown (only the debug-only closing screen uses it). The handoff then generates a second one (`FirstPodcastOrchestrator`). The backend ignores `generationSource` and has no in-flight or duplicate check, so both run: roughly double the voice and model cost of every sign-up, two episodes in the person's list, and the first one made from almost nothing  
  *Evidence:* `VoiceGoalsPage.swift:1162–1171, 1176–1199`; `FirstPodcastOrchestrator.swift:34`; `backend/src/routes/podcasts.ts:108–118` (no dedupe; `skipTTS` exists and could back a test switch)
- **N13** · Minor · psychological · interaction: **Goal cards say "I'll watch your life through the rest"** (reads as surveillance), with no way to add or edit a goal, only uncheck  
  *Evidence:* simulator

**Becomes:** N8 G1

*N8 is described above.*

#### G1. Goals

**One feature:** What you’re working toward, as it sees it.

**On it:**
- Active goals, each with said vs did in two plain numbers
- A small trajectory, or “too early to tell”
- Faded (unmentioned 90 days) and merged, below, revivable
- Add by voice or text (+)

**Pinned (opportunities O, backend gaps K):** **O-6** goals · **O-23** server owns goals · **K2** said-vs-did route

**Backend:** ✓ /goals (intents only) · ✗ said-vs-did + lifecycle view  
**States:** none yet · too early · server failing  
**Closes:** G1, G2, G3, Y17, Y18, Y19, Y20, Y21

```
┌─────────────────────────┐
│ Goals               +   │
│ ┌ Ship the first ver. ┐ │
│ │ said 6× · did 4h/wk │ │
│ │ usual 2h  ▁▃▅ more  │ │
│ └─────────────────────┘ │
│ ┌ Sleep before 12 ────┐ │
│ │ said 3× · did 1 night│ │
│ └─────────────────────┘ │
│ Faded 2 · Merged 1    › │
│Journal Podcasts[Goals]You
└─────────────────────────┘
```

---

### Today: Connections (`IntegrationsSetupPage`)

**Problems on this screen:**

- **C1** · Major · doesn't make sense · redundant: **"Make my podcast" and "Skip for now" do exactly the same thing** (both `advance()`), and neither makes a podcast; they go to the host picker. The main button promises what it doesn't do  
  *Evidence:* `IntegrationsSetupPage.swift:66–71, 204–208`
- **C2** · Major · broken: **Google can never show as connected:** its connected check is hard-coded `false`, so after connecting it shows at best a status label, never "connected"  
  *Evidence:* `:152` (`case .googleDocs: return false`)
- **C4** · Major · psychological · not fun: **17 sources in one list** (Health, Screen Time, Google Docs, Calendar, Apple Music, Photos, Contacts, Spotify, YouTube, Reddit, Gmail, TikTok, X, ChatGPT, Claude, Grok, Netflix): choice overload at the moment trust is lowest  
  *Evidence:* catalogue `IntegrationCatalogItem.all`
- **C5** · Major · redundant · confusing: **Google appears as three separate cards** (Google Docs, YouTube, Gmail), though one Google sign-in grants all three (backend commit 7f86719 combined them). It's also labelled "Google Docs" (logged problem, still there)  
  *Evidence:* catalogue
- **C6** · Major · doesn't make sense: **Engineering words shown under every card before connecting:** "Device sync", "Continuous sync", "API-visible sync", "Verification-gated sync", "API-tier gated sync", "Optional file import" (logged problem, wider than logged)  
  *Evidence:* `plannedStatus` values, shown by `connectionStatusLabel` default
- **N14** · Major · pixel: **Connections: every description is cut off mid-word** ("daily rhyth…", "apps an…"), the heading scrolls under the status bar, and the list runs under "Make my podcast" (confirms the logged "covers the list")  
  *Evidence:* simulator
- **Y50** · Note · navigation: *Swiped from the left edge on Connections:* **No way back** to the questions, by gesture or button (confirms O1 live)  
  *Evidence:* deep pass (simulator, sample data)
- **Y52** · Minor · clarity: *Opened Connections with a slow server:* The list renders immediately from a list built into the app, and real connection states arrive later with no sign of loading, so a source can appear "not connected" and then change  
  *Evidence:* deep pass (simulator, sample data)

**Becomes:** N6

#### N6. Connect

**One feature:** Connect what helps it understand you.

**On it:**
- Recommends what can connect today: Apple Health and Google (Docs now; mail, calendar and YouTube as Google approves them), each with what it lets it understand
- Calendar, Contacts and Screen Time join the list as they ship; never shown as connectable before they work
- One Google card
- Plain states: Connected · read just now / Couldn’t connect, try again
- "Not now" per source; More sources ›
- Starts reading for your first episode

**Pinned (opportunities O, backend gaps K):** **O-17** sources · **K15** only Health and Google Docs connect today · **K16** source descriptions in the catalog · **K12** one first episode per person · **Switch** ENABLE_ONBOARDING_PIPELINE

**Backend:** ✓ /integrations · ◐ readiness/advance · ✗ one-episode guard  
**States:** connecting · connected · failed · denied · skipped  
**Closes:** C1–C10, N14, N15, N16, A7, Y52

```
┌─────────────────────────┐
│ ‹                       │
│ "These let me see what  │
│  words can't."          │
│ ┌─────────────────────┐ │
│ │♥ Health → your sleep│ │
│ │  and energy       ✓ │ │
│ ├─────────────────────┤ │
│ │▦ Calendar → shape of│ │
│ │  your weeks  [Add]  │ │
│ ├─────────────────────┤ │
│ │G Google → mail, docs│ │
│ │  calendar    [Add]  │ │
│ └─────────────────────┘ │
│ More sources ›          │
│           [ Continue ]  │
└─────────────────────────┘
```

---

### Today: Connections: further down, file imports

**Problems on this screen:**

- **C3** · Minor · interaction: **The same error is shown twice:** inline red text *and* an alert, both from `connectionError`  
  *Evidence:* `:52–61` and `:87–94`
- **C7** · Minor · demo/fake · confusing: Tapping an unbuilt source explains, in engineering language, that it "can be connected here as soon as its verified collection path is ready"  
  *Evidence:* `:96–100`
- **C8** · Major · interaction · not fun: AI-chat history (ChatGPT, Claude, Grok) and Netflix are file imports (.json/.zip/.csv) mid-onboarding (logged problem, still there)  
  *Evidence:* `connectionKind: .archiveImport`
- **C9** · Minor · doesn't feel good: A failed status fetch shows the raw system error in an alert  
  *Evidence:* `:186–188`
- **C10** · Note · unknown: Whether each OAuth source (Spotify, Reddit, TikTok, X, YouTube, Gmail) has working production credentials is unverified; X needs a paid API tier and TikTok an approval  
  *Evidence:* needs a live connect test
- **N15** · Minor · interaction · confusing: **Tapping a file import opens the iOS file picker with no explanation** of which file or how to export it from ChatGPT/Claude/Grok/Netflix  
  *Evidence:* simulator
- **N16** · Minor · doesn't feel good: **A failed connection shows "Server error: Could not start connection"** in an alert, after the fact, with only OK  
  *Evidence:* simulator (X card)

**Becomes:** N7

#### N7. More sources

**One feature:** Everything else you can connect, explained.

**On it:**
- Grouped: your phone · your accounts · files you already have · your public profiles (optional: "Want me to read your public profiles?" with handles)
- Each shows its real state: ready, coming soon, or needs approval
- Each: what it adds, and how (one tap, or how to export a file)
- File imports explained step by step (ChatGPT, Claude, Netflix, YouTube history)

**Pinned (opportunities O, backend gaps K):** **O-17** sources · **Imports** YouTube Takeout, archives · **K18** social research route · **K15** honest availability

**Backend:** ✓ /integrations imports and assets  
**States:** as N6  
**Closes:** C4, C8, N15

```
┌─────────────────────────┐
│ ‹ More sources          │
│ YOUR PHONE              │
│  Screen Time · Music ·  │
│  Photos · Contacts      │
│ YOUR ACCOUNTS           │
│  Spotify · Reddit · …   │
│ FILES YOU HAVE          │
│  ChatGPT history  How ›  │
│  YouTube history  How ›  │
└─────────────────────────┘
```

---

### Today: Host picker (`PersonaPickerPage`)

**Problems on this screen:**

- **P1** · Major · not inspiring: **Canned hosts** ("wise mentor", "energetic host", "thoughtful friend"), saved only to the phone (`UserDefaults voice_persona`) (logged problem, still there; ios-v2 change 7 replaces it with a made-for-you voice)  
  *Evidence:* `PersonaPickerPage.swift:16, 28–60, 101`
- **P2** · Major · psychological · interaction: The host is chosen **before the person has heard any voice**: no sample to listen to  
  *Evidence:* `PersonaPickerPage.swift` (no audio preview)
- **N18** · Minor · pixel: **Host descriptions are cut off** ("Good…", "Celebrates y…"); green ticks on goals and hosts aren't in the design system  
  *Evidence:* simulator
- **Y51** · Major · interaction · waits: *Picked a host with the server responding slowly:* **"Saving…" blocks the screen for the whole server wait** (25 s in the test; a sleeping Render server takes ~50 s) just to save a preference, with no way to continue and no explanation. A preference should save in the background  
  *Evidence:* deep pass (simulator, sample data)

**Becomes:** T7

#### T7. Voice and listening

**One feature:** How it sounds, and how you take things in.

**On it:**
- Voice (with a sample); the made-for-you voice once voice creation exists (today the three hosts are one voice)
- Talk or read (onboarding and replies)
- Playback speed default

**Pinned (opportunities O, backend gaps K):** **O-19** voice · **K14** listening preference · **K17** one voice behind three hosts

**Backend:** ✓ /profile/persona · ✗ consumption  
**States:** none  
**Closes:** P1, P2, L9

```
┌─────────────────────────┐
│ ‹ Voice and listening   │
│ Voice   Warm  ▶ sample  │
│ Talk or read   ● Talk   │
│ Speed          1x     › │
└─────────────────────────┘
```

---

### Today: Closing page ("Play Podcast")

**Problems on this screen:**

- **E1** · Major · doesn't make sense · psychological (broken promise at the peak): **"Play Podcast" doesn't play a podcast.** No podcast exists yet; the button starts generation and the "Learning about you" wait. The label promises an instant payoff that's minutes away  
  *Evidence:* `DarkOnboardingFlow.swift` `OnboardingClosingPage` `:992–996`
- **E2** · Note · demo (ok): "DEV: Preview paywall" is debug-only (`#if DEBUG`), fine  
  *Evidence:* `:998–1002`
- **N17** · Minor · redundant: **The closing page repeats the questions step's closing line** ("Now I know what matters to you, Sam. Let's help you get there." vs "Now let's help you get there.") and shows "DEV: Preview paywall" (debug only)  
  *Evidence:* simulator
- **V6** · Note · demo (ok): A debug-only Skip exists (`#if DEBUG`), fine; a "Skip" at progress 0.02 jumps straight to completion  
  *Evidence:* `:697–710`
- **V10** · Minor · demo (debug only): *(simulator + code, corrected)* The questions step has its own closing screen ("Now let's help you get there." → **Play Podcast**) whose player falls back to the **demo transcript with no audio**. It is reached **only through the debug Skip**; the normal path goes processing → goal cards → Continue → Connections. Not a ship problem by itself, but dead-in-release UI that plays fake content  
  *Evidence:* `VoiceGoalsPage.swift:245, 618–655, 259, 592`

**Becomes:** N10 N11

*N10 is described above.*

#### N11. The tease: first episode plays

**One feature:** The first thing it gives back.

**On it:**
- A spoken callback first: "here is the first thing I noticed; it is narrow, because it is day one"
- Your real episode plays; transcript follows the voice
- Honest about how little it knows yet

**Pinned (opportunities O, backend gaps K):** **O-24** audio that plays · **Goal 24** something true you recognise · **K21** opening line asked, not stated

**Backend:** ✓ /podcasts (stream the audioUrl)  
**States:** playing · buffering · failed  
**Closes:** E1, L2, N20, N21

```
┌─────────────────────────┐
│ "Here's the first thing │
│  I noticed."            │
│                         │
│ ─ The week you started ─│
│ "…three of your best    │
│  days began before 8…"  │
│                         │
│ ━━━━━○───────── 0:31    │
│      ↺15   ‖   15↻      │
└─────────────────────────┘
```

---

### Today: "Learning about you"

**Problems on this screen:**

- **N1** · Blocker · demo or fake · psychological: **"Learning about you" shows hard-coded placeholder insights to every user as if they were about them:** "You carry more than you let on", "You move fast, and rarely stop to notice", "You're harder on yourself than the evidence warrants". The code says "Placeholder callouts — swap for the real source". At the emotional peak, the product states things about you it has no evidence for (Barnum statements), the opposite of goal 4  
  *Evidence:* `LearningAboutYouView.swift:203–210`; simulator (all answers were "Test")
- **A5** · Major · demo/fake · doesn't feel good: **"Learning about you" is a fake progress bar:** it creeps asymptotically toward 95% and never completes by itself; it only ends when the episode arrives (3–5 min, up to 10). Confirms the logged "hangs at 94%"  
  *Evidence:* `LearningAboutYouView.swift:283–295` ("indeterminate creep toward 95%")
- **A3** · Major · broken · confusing: **Onboarding is marked complete before the first podcast exists.** If the app is killed during the minutes of generation, the person reopens to a home screen with no episode, no message, and nothing that resumes it  
  *Evidence:* `RetrospectApp.swift:417` (comment acknowledges the choice)
- **N4** · Minor · pixel: **The dots draw over the headline text** on "Learning about you" (confirms the logged "dots over text")  
  *Evidence:* simulator
- **N23** · Note · demo or fake: **"Learning about you" ends "Understanding you. 100%"** the instant the episode arrives (94% → 100% in one jump), so the number is visibly tied to nothing  
  *Evidence:* simulator
- **Y44** · Major · performance: *"Learning about you":* A 60-times-a-second timer on the main thread updates SwiftUI state every frame (`@State hold/release/dissolve`), which re-renders the whole screen including a Metal shader, and drives continuous haptics, for the minutes the episode takes. On an older phone this is the most likely place for dropped frames and battery drain  
  *Evidence:* deep pass (simulator, sample data)

**Becomes:** N10

*N10 is described above.*

---

### Today: First episode plays

**Problems on this screen:**

- **A7** · Major · broken · cost · redundant: **Every onboarding generates two first episodes and discards one.** When the questions finish, `finishProcessing` starts a real generation (`prefetchPodcast`) *before any source is connected and before the profile is uploaded*; on the normal path that episode is never shown (only the debug-only closing screen uses it). The handoff then generates a second one (`FirstPodcastOrchestrator`). The backend ignores `generationSource` and has no in-flight or duplicate check, so both run: roughly double the voice and model cost of every sign-up, two episodes in the person's list, and the first one made from almost nothing  
  *Evidence:* `VoiceGoalsPage.swift:1162–1171, 1176–1199`; `FirstPodcastOrchestrator.swift:34`; `backend/src/routes/podcasts.ts:108–118` (no dedupe; `skipTTS` exists and could back a test switch)
- **N2** · Note · broken · cost: **The two-episode problem confirmed on a running build:** `/podcasts/generate` fired when the goal cards appeared (02:11:38) and again on "Play Podcast" (02:13:07). Confirms A7  
  *Evidence:* stand-in server log
- **N3** · Note · demo or fake: **"Learning about you" percentage is invented:** 24% at ~2 s, 77% at ~15 s, 91% at ~30 s, with the server still working. Confirms A5  
  *Evidence:* simulator

**Becomes:** N11

*N11 is described above.*

---

### Today: When the first episode fails

**Problems on this screen:**

- **A1** · Blocker · broken · doesn't feel good: **A failed first podcast is silent.** `firstPodcastError` is set, never displayed anywhere; the person is dropped on the home screen with no explanation and no retry  
  *Evidence:* `RetrospectApp.swift:68` (only declaration and assignments), `:427–432`
- **L2** · Major · demo or fake · broken: **With no episode, the player runs a fake clock:** "6:58" counting down, a Pause button, a moving bar, **no audio**, and the first line stays highlighted for 40 s. It looks like it's playing  
  *Evidence:* `Components/PodcastPlayer.swift:99–107` (`visualDuration = 420`); simulator
- **A4** · Minor · logic: **Finishing (or "DEV: Go home") sets `isAuthenticated = true` and `needsBackendAuth = false` unconditionally**, skipping the Face ID splash for that session regardless of the setting  
  *Evidence:* `RetrospectApp.swift:451–458`
- **A6** · Minor · demo/fake: A notification for an unknown podcast creates a **placeholder transcript** ("Your weekly reflection is ready." / "Your personalized podcast is ready to play.") shown as if real  
  *Evidence:* `RetrospectApp.swift` `findOrCreateTranscript`

**Becomes:** N10 N11

*N10 is described above.*

*N11 is described above.*

---

### Today: Paywall (`PodcastPaywallFlow`)

**Problems on this screen:**

- **N19** · Blocker · broken: **In a release build the paywall has no way out.** The close (X) is wrapped in `#if DEBUG`, there's no "Not now", and subscribing can't work yet (no purchase path), so a real person who reaches the reveal is stuck on that screen. Likely an App Review rejection by itself  
  *Evidence:* `PodcastPaywallFlow.swift:114–129`; simulator (X does nothing after the reveal)
- **L3** · Major · broken · App Review risk: **The paywall's "Privacy notice" does nothing** (empty action) and there is **no Terms of Use link**. Apple requires working links to both on a subscription screen (Guideline 3.1.2)  
  *Evidence:* `PodcastPaywallFlow.swift:706`; Apple's 3.1.2 rejections quote this requirement: the binary must have working Privacy Policy and Terms of Use links next to the subscription's title, length and price ([forum](https://developer.apple.com/forums/thread/807082), [forum](https://developer.apple.com/forums/thread/812192))
- **L4** · Major · missing · product: **The paywall can't take money:** there is no StoreKit purchase path at all. "$19.99/m" and "$239.99/y" are placeholder text (and the yearly placeholder is more than 12 × monthly); tapping either shows "Subscriptions aren't available in this build yet." Real prices and products need setting up in App Store Connect + StoreKit  
  *Evidence:* `SubscriptionManager.swift:9–10, 24–25, 45–51`; simulator
- **L5** · Minor · doesn't make sense: An **unlabelled icon button** (two arrows) on the paywall and at the top of the side menu; its purpose can't be told from the screen  
  *Evidence:* simulator
- **Y41** · Major · pixel · layout: *Reached the paywall on the SE:* **The paywall is one fixed 402 × 874 picture shrunk to fit** (16 hard-coded positions inside): on the SE everything is drawn at about 76%, so the price buttons and the "Restore · Privacy notice" links are smaller than designed (the links are around 9 pt), with empty bands at the sides. It's laid out for one phone, not any phone  
  *Evidence:* deep pass (simulator, sample data)
- **Y42** · Minor · pixel: *Played the episode on the SE:* The first-episode player fits; the transcript's lower lines are blurred deliberately, but on the small screen only one sentence is readable at a time  
  *Evidence:* deep pass (simulator, sample data)

**Becomes:** N12

#### N12. The paywall (scrollable)

**One feature:** Choose to subscribe, seeing everything you get.

**On it:**
- At the strongest line the episode slides up into a mini player (1.22 s reveal)
- Monthly / Yearly (real prices; yearly says what it saves) · Not now
- Scroll: every benefit, each with an example from your data where one exists
- Restore · Privacy · Terms; fits any phone

**Pinned (opportunities O, backend gaps K):** **O-29** real subscriptions · **K13** StoreKit + receipts · **Founder** scrollable with every benefit

**Backend:** ✗ /subscriptions/verify + StoreKit  
**States:** loading prices · purchasing · purchased · failed · restored  
**Closes:** N19, L3, L4, L5, Y41

```
┌─────────────────────────┐
│ ▶ episode (mini)  0:38  │
│ "Hear the rest, and one │
│  every week."           │
│ [ Monthly ][ Yearly −2m]│
│ Not now                 │
│ ── scroll ───────────── │
│ ◇ A brief every morning │
│ ◇ An episode every week │
│ ◇ Ask your own mind     │
│ ◇ Goals: said vs did    │
│ ◇ Talk to it anytime    │
│ Restore · Privacy · Terms│
└─────────────────────────┘
```

---

### Today: First reflection ("How was your first podcast?")

**Problems on this screen:**

- **N22** · Minor · dead (for now): **The reflection step ("How was your first podcast?") is unreachable today:** it only follows a completed subscription *and* a finished episode. Its answer would be saved as the first journal entry (good), but nobody can get there  
  *Evidence:* `FirstPodcastExperience.swift:59–70, 105–112` (code only)
- **K5** · Minor · dead: *First reflection ("How was your first podcast?"):* Unreachable today (needs a completed subscription); see N22  
  *Evidence:* `FirstPodcastExperience.swift:117–160`

**Becomes:** N13 J1

#### N13. Your mornings

**One feature:** Offer the daily brief, then step into the app.

**On it:**
- "Want a short brief each morning?" (off unless you say yes)
- Pick a time (default 8:30)
- Then Journal, with the episode where you left it

**Pinned (opportunities O, backend gaps K):** **O-3** daily brief · **K4** local time · **Spec** brief off by default

**Backend:** ◐ /briefs/enabled (✗ backend route) · ✗ /profile/timezone  
**States:** none  
**Closes:** A3, Y1

```
┌─────────────────────────┐
│ "Want a short brief each│
│  morning? Two minutes,  │
│  about what changed."   │
│                         │
│   Time  [ 8:30 am ▾ ]   │
│                         │
│ [ Yes, every morning ]  │
│   Not now               │
└─────────────────────────┘
```

#### J1. Journal

**One feature:** Say what’s on your mind, and hear back.

**On it:**
- Today’s brief card on top: ▶ press play, it briefs you, keeps playing when you close the app
- Today’s thread: your entries and its replies; each entry shows saved → sent → read
- Replies are short, sometimes none; guesses asked as questions
- Waiting on you: at most one (a correction to confirm, “same person?”)
- Composer: Tell me… with the mic first; drafts kept, never auto-sent
- “All entries” at the top right

**Pinned (opportunities O, backend gaps K):** **O-1** capture · **O-2** conversation · **O-3** brief card · **O-21** outbox · **K3** brief audio · **K8** idempotency

**Backend:** ✓ /content · ✗ backend: /conversation, /briefs, /corrections · ✗ brief audio  
**States:** first visit · nothing today · brief making · brief quiet · offline (queued) · server failing (named) · ambient off  
**Closes:** Y1, Y2, Y4, Y5, Y6, Y28, Y29, J1, J2, L6, L7

```
┌─────────────────────────┐
│ Journal      All entries│
│ ┌ Your brief ──────── ┐ │
│ │ ▶ 3 things · 2 min  │ │
│ └─────────────────────┘ │
│ You: slept badly, long  │
│ day of meetings  ✓ read │
│ Retrospect: Third Monday│
│ like that. What's       │
│ different about Mondays?│
│ ┌─────────────────────┐ │
│ │ Tell me…      🎙 ↑  │ │
│ └─────────────────────┘ │
│[Journal] Podcasts Goals You
└─────────────────────────┘
```

---

### Today: Second sign-in gate and Face ID

**Problems on this screen:**

- **K1** · Major · redundant · confusing: *Backend sign-in gate (shown when the app has no server token after onboarding):* **A second sign-in screen that repeats the welcome page word for word**, including the old promise ("Your life, turned into a weekly podcast…"); its error is raw system text. A person who reaches it has already signed in once and is asked again with no reason given  
  *Evidence:* `Components/BackendAuthGateView.swift:25–51, 104, 138`
- **K2** · Major · broken · interaction: *Face ID splash:* On failure shows the raw system error and a "Try Again" button; no way in by passcode or to turn Face ID off from here, so a failed Face ID locks the person out of their own journal  
  *Evidence:* `DarkSplashScreen.swift:14–48`

**Becomes:** N3 T9

*N3 is described above.*

#### T9. Account and subscription

**One feature:** Your plan, and your account.

**On it:**
- Plan, renewal date; Manage (Apple) · Restore
- Sign out
- Delete account (confirm; explains what is removed)

**Pinned (opportunities O, backend gaps K):** **O-29** subscriptions · **App Review** account deletion required

**Backend:** ✗ StoreKit · ✗ account deletion  
**States:** none  
**Closes:** L4

```
┌─────────────────────────┐
│ ‹ Account               │
│ Yearly · renews 3 Mar   │
│ Manage subscription   › │
│ Restore purchases       │
│ Sign out                │
│ Delete account…         │
└─────────────────────────┘
```

---

## App

### Today: Journal (`DarkJournalView`)

**Problems on this screen:**

- **Y1** · Major · clarity: *Opened the app:* Journal is an almost empty screen: a faint "tell me something….." in the middle, an episode pill, "Your next episode is in 3 days". **Nothing shows what you've written, what the brain made of it, or what to do today.** The home of the product has no content  
  *Evidence:* deep pass (simulator, sample data)
- **Y2** · Minor · interaction · pixel: *Tapped "tell me something…..":* The keyboard took a second or two to come up; **the cursor appears at the top left, not where the prompt was**, so the first tap doesn't land where your eye is. The text box is invisible (2% opacity) until you type  
  *Evidence:* deep pass (simulator, sample data)
- **Y4** · Major · broken: *Typed "Half written thought about", then opened the menu:* **The half-written thought was sent as a finished entry** (the server received it the moment the menu opened). Any way of leaving the box sends it: the menu, the mic, a call, swiping the keyboard away (`onChange(of: isJournalFocused)` → `sendJournalEntry`)  
  *Evidence:* deep pass (simulator, sample data)
- **Y5** · Major · clarity · feedback: *Tapped send:* **The words vanished with no confirmation.** No "saved", no entry shown, no sign it reached the brain. It did reach the server (seen in the stand-in log), but the person can't know  
  *Evidence:* deep pass (simulator, sample data)
- **Y6** · Minor · performance: *Timed the screen:* Several seconds between tapping send and the screen clearing, and between taps and the keyboard. Idle CPU is near zero, so it isn't a background drain; to confirm on a phone  
  *Evidence:* deep pass (simulator, sample data)
- **Y8** · Note · —: *(correction):* An earlier note here said the menu does nothing while typing; that was my tap landing off the button. The menu works  
  *Evidence:* deep pass (simulator, sample data)
- **Y28** · Major · clarity: *Opened the app with the server failing:* Journal looks exactly the same as when it works: no banner, no sign anything is wrong  
  *Evidence:* deep pass (simulator, sample data)
- **Y29** · Note · broken: *Wrote an entry and sent it while the server was failing:* The server returned an error, and **the screen cleared exactly as it does on success.** Nothing says the entry didn't arrive, nothing retries it (confirms J1 live)  
  *Evidence:* deep pass (simulator, sample data)
- **Y47** · Minor · performance: *Journal and menu:* Taps take about a second to register and the keyboard is slow to appear (Y2, Y6, Y16). Idle CPU is near zero, so the likely cause is work done on the tap itself (the side panel's shadow and scale animation, focus changes) rather than background load  
  *Evidence:* deep pass (simulator, sample data)
- **L6** · Major · demo or fake: **Journal promises "Your next episode is in 3 days" always:** the text is hard-coded, whatever the schedule or whether any episode exists  
  *Evidence:* `DarkAppContainer.swift:927`
- **L7** · Minor · pixel: Journal's prompt reads "tell me something....." (five dots), in faint grey on cream  
  *Evidence:* simulator
- **J1** · Blocker · broken: **A failed entry upload is lost silently.** The failure goes only to a debug log; the entry has no "synced" flag; nothing retries; the person is never told. The brain never sees that entry (logged problem, confirmed in code)  
  *Evidence:* `Models/EntryModel.swift:126–147`
- **J2** · Major · broken: **Writing while signed out skips the upload silently**, without queuing it for later  
  *Evidence:* `:127–130`
- **J3** · Major · broken · logic: **Editing an entry never re-syncs:** `updateEntry` saves only on the phone, so the server keeps the old words and the brain works from text the person changed  
  *Evidence:* `:196`; callers `EntryDetailView.swift:492–512`
- **J4** · Minor · redundant · risk: **The only recovery is "resync everything"**, hidden in Dev Mode settings, which re-uploads every entry ever written (duplicates, unless the server's dedup catches them)  
  *Evidence:* `:150–181`; `DarkSettingsView.swift:1271`
- **J6** · Minor · doesn't feel good: Audio and voice errors are shown raw ("Audio session error: …", "Failed to play audio: …")  
  *Evidence:* `DarkAppContainer.swift:37–38, 100–101, 995`

**Becomes:** J1 J2

*J1 is described above.*

#### J2. Today’s brief (open)

**One feature:** Read or replay today’s brief.

**On it:**
- The through-line, then each item with why it is here and the quote behind it
- Play / pause; keeps playing in the background
- A quiet day says so in one line
- “That’s not right” on any item

**Pinned (opportunities O, backend gaps K):** **O-3** brief · **O-10** corrections · **Goal 11** every item says why · **K22** sections need the v2 brief

**Backend:** ◐ /briefs/latest (✗ backend route) · ✗ brief audio  
**States:** playing · played · quiet · not made yet  
**Closes:** —

```
┌─────────────────────────┐
│ ⌄ Tuesday's brief  ▶ 2m │
│ "A heavier week than    │
│  usual, and it shows."  │
│ 1 Four meetings before  │
│   noon. Why: you said   │
│   mornings are for      │
│   thinking. "…" ›       │
│ 2 The fundraise article │
│   you saved. Why: …     │
│            ✕ not right  │
└─────────────────────────┘
```

---

### Today: Side menu and navigation

**Problems on this screen:**

- **L12** · Minor · interaction · pixel: The side menu opens about a second after the tap; the menu button moves between screens (Journal vs the rest)  
  *Evidence:* simulator
- **J5** · Minor · structure: **One 1,227-line file holds the app shell, an audio manager, the journal and an "agent podcast test"**, so changes to one break others  
  *Evidence:* `Views/DarkAppContainer.swift`
- **S1** · Minor · dead: **About 57 of 248 screen types (~32 files, ~8,000 lines) can't be reached from the app**, including a 1,273-line unused onboarding (`iMessageOnboardingView`), a whole video-journal feature (4 files), an old home screen (`OptimizedHomeScreen`), the old integrations screen, the teleprompter, an unused privacy page and an unused persona screen  
  *Evidence:* reachability pass (file-level estimate; widget views are false positives)
- **Y7** · Minor · clarity · redundant: *Opened the menu:* A "recents" list appears under the sections, every item titled **"Entry from Oct 20, 2026…"** and cut off, so you can't tell entries apart; it duplicates the Entries screen  
  *Evidence:* deep pass (simulator, sample data)
- **Y16** · Minor · interaction: *Tried to act on actions in quick succession:* Screens lag about a second behind each tap, so taps made while a menu is closing land on whatever is underneath (my long-press on an entry opened Goals through the closing menu)  
  *Evidence:* deep pass (simulator, sample data)

**Becomes:** J1 P1 G1 Y1

*J1 is described above.*

#### P1. Podcasts

**One feature:** Listen to what it made for you.

**On it:**
- This week’s episode as the hero: real title, length, what it covers
- Today’s brief beside it
- Earlier episodes and briefs, newest first
- Pull to refresh; refreshes when you open the tab

**Pinned (opportunities O, backend gaps K):** **O-4** episodes · **O-24** audio that plays · **O-30** new-episode notice

**Backend:** ✓ /podcasts (list, latest, get)  
**States:** first episode only · making this week’s · quiet week · failed (named) · offline (downloaded play)  
**Closes:** Y22, Y23, Y24, Y25, Y30, Y31, L8

```
┌─────────────────────────┐
│ Podcasts                │
│ ┌ This week ──────────┐ │
│ │ The week you stopped│ │
│ │ rushing · 12 min  ▶ │ │
│ └─────────────────────┘ │
│ Today's brief · 2 min ▶ │
│ EARLIER                 │
│ What the Sunday calls…▶ │
│ Your first episode    ▶ │
│Journal[Podcasts]Goals You
└─────────────────────────┘
```

*G1 is described above.*

#### Y1. You: the map

**One feature:** See the picture it has of you, and ask it anything.

**On it:**
- Search field (mic first) on top
- The map: people, places, projects, topics, goals, habits, emotions, sized by how much they show up (people by their significance score: recent, weighted, fading over 60 days), joined by facts
- Opens on the strongest dozen; zoom for more; clusters are patterns
- Nodes waiting for you glow quietly (same person? / wondering)
- Your picture top-left opens Settings; a list view for VoiceOver

**Pinned (opportunities O, backend gaps K):** **O-7** search · **O-8** the map · **O-11/12/13** patterns, people, wondering · **K2** map route

**Backend:** ✗ /understanding/map · ✗ backend: /search, /people/held, /hypotheses  
**States:** day one (thin, said so) · loading · offline (last map) · failing  
**Closes:** —

```
┌─────────────────────────┐
│ (pic)       You         │
│ ┌ Ask anything ─── 🎙 ┐ │
│ └─────────────────────┘ │
│       ◯ Priya           │
│  ●──────⬤ Work          │
│ Sleep●     \            │
│       ◯ Sam? ← waiting  │
│   ●Running  ⬤ Ship v1   │
│ What I know about you › │
│Journal Podcasts Goals[You]
└─────────────────────────┘
```

---

### Today: A single entry

**Problems on this screen:**

- **Y9** · Major · pixel · clarity: *Opened an entry:* **The hierarchy is upside down:** the title is the date and time in 36 pt serif over three lines ("Entry from Oct 20, 2026 at 2:27 AM"), the line below repeats the same date, and **the person's own words are the smallest, greyest text on the page**. The AI title the code expects (`aiGeneratedTitle`) never arrives  
  *Evidence:* deep pass (simulator, sample data)
- **Y10** · Major · missing: *Tapped the words; looked for edit or delete:* **The entry can't be edited, and the page has no delete.** Only a back button  
  *Evidence:* deep pass (simulator, sample data)
- **Y11** · Major · gesture: *Swiped from the left edge:* **Nothing happened.** The standard iPhone swipe-back gesture doesn't work; only the small round back button does  
  *Evidence:* deep pass (simulator, sample data)
- **Y12** · Blocker · broken · privacy: *Read the code for deleting from Entries (long-press menu):* **Deleting an entry only removes it from the phone.** `EntryManager.deleteEntry` deletes the local file and nothing else, so the server and the brain keep the words and can still use them in episodes and search. A person who deletes something private believes it's gone  
  *Evidence:* deep pass (simulator, sample data)
- **Y13** · Minor · redundant: *Read the code:* Three different entry-page views exist (`FigmaLightInlineEntryReader` live; `DarkEntryDetailView` and `EntryDetailView` unreachable or legacy), so the J3 "edits never re-sync" problem lives only in the unreachable one  
  *Evidence:* deep pass (simulator, sample data)

**Becomes:** J4

#### J4. An entry

**One feature:** Read, change or remove one thing you said.

**On it:**
- Your words first, large; the date small under them
- Edit (the brain re-reads it) · Delete (removed from the brain too: the entry via the existing DELETE /content/:id, and what was drawn from it via the correction path), with confirmation
- What I took from this: the facts it drew, each with ✕ not right
- Swipe from the edge to go back

**Pinned (opportunities O, backend gaps K):** **K7** edit/delete · **O-10** corrections · **O-25** swipe back

**Backend:** ✓ DELETE /content/:id (+ ✗ retract what was drawn) · ✗ PATCH /content/:id · ◐ /corrections  
**States:** saved · sending · read · failed  
**Closes:** Y9, Y10, Y11, Y12, J3

```
┌─────────────────────────┐
│ ‹                ⋯ Edit │
│ Slept badly, long day of│
│ meetings, felt flat.    │
│ Mon 20 Oct · 2:27 pm    │
│ ── What I took ──────── │
│ · sleep was poor      ✕ │
│ · meetings drain you  ✕ │
│                         │
│        Delete entry     │
└─────────────────────────┘
```

---

### Today: Entries

**Problems on this screen:**

- **Y14** · Major · navigation: *Opened an entry from the menu's recents, then tapped back:* **Back went to Entries, a screen I had never opened**, not to Journal where I started  
  *Evidence:* deep pass (simulator, sample data)
- **Y15** · Minor · incoherent: *Compared titles:* Entries titles each entry by its first words ("Half written thought about"); the menu's recents call the same entries "Entry from Oct 20, 2026…"; the entry page uses the date. Three names for one thing  
  *Evidence:* deep pass (simulator, sample data)

**Becomes:** J3

#### J3. All entries

**One feature:** Everything you’ve written or said, in one place.

**On it:**
- By day, newest first; your own words first, not a date title
- Written and voice, with a small mark for each; voice entries play
- Search your entries; filter written / voice / with links
- Each shows saved → sent → read; failed ones retry with one tap

**Pinned (opportunities O, backend gaps K):** **Founder** a place for your entries · **O-21** states · **K7** edit/delete reach the brain

**Backend:** ✓ GET /content · ✗ edit/delete routes  
**States:** empty (warm) · loading · offline (local copy) · some unsent  
**Closes:** Y7, Y9, Y15, J4

```
┌─────────────────────────┐
│ ‹ All entries      ⌕    │
│ All · Written · Voice   │
│ TODAY                   │
│  Slept badly, long day… │
│                 ✓ read  │
│ MONDAY                  │
│  🎙 On the walk home I… │
│                 ✓ read  │
│  "need to call mum"     │
│              ↻ sending  │
│ LAST WEEK               │
│  …                      │
└─────────────────────────┘
```

---

### Today: Goals (`DarkGoalsView`)

**Problems on this screen:**

- **G1** · Blocker · broken · logic: **The phone's goal list overrides the brain on every change.** The sync *reactivates* any goal the server marked inactive (undoing the brain's merge and expiry, goal 7: 31→3 active), and *deactivates* any active goal the phone doesn't know, including goals the brain created. Two sources of truth that fight; likely part of why 115 goals were created and 31 stayed "active" since June ([findings 37–38](./findings-log.md))  
  *Evidence:* `RetrospectAPIClient.swift:346–365`; called from `GoalsManager.saveGoals()` on every add or remove. **Revival half fixed server-side: NPRdoinglaundry#19**
- **G2** · Minor · broken: A failed goal sync is only printed; no retry, nothing shown  
  *Evidence:* `GoalsManager.swift:429–441`
- **G3** · Major · missing: The Goals tab shows only the phone's goals; the brain's view (active, expired, merged, said-vs-did) never reaches the person  
  *Evidence:* `DarkGoalsView.swift` reads `GoalsManager.shared` only
- **Y17** · Note · broken: *Opened Goals with a server holding 4 sample goals:* **It shows the phone's 3 onboarding goals, not the server's 4.** The brain's goals never appear (confirms G3 live)  
  *Evidence:* deep pass (simulator, sample data)
- **Y18** · Note · broken: *Added one goal ("Sample: read more"):* **One goal sent 8 writes:** a read, 4 creates (every phone goal re-created) and 3 updates switching off the server's goals the phone didn't recognise. Duplicates pile up and the brain's goals are turned off (confirms G1 live)  
  *Evidence:* deep pass (simulator, sample data)
- **Y19** · Major · pixel · layout: *Tapped "+":* **The whole screen jumps up under the status bar and camera:** the title and menu disappear, goal text runs behind the clock, and the input floats mid-screen over a large blank area  
  *Evidence:* deep pass (simulator, sample data)
- **Y20** · Minor · pixel · missing: *Expanded a goal:* The description is indented further than the "Why this matters" label under it; a large empty area; only a small bin icon. **No edit, no progress, nothing the brain has noticed.** "Why this matters" shows the extraction note ("Sample") rather than the person's reason  
  *Evidence:* deep pass (simulator, sample data)
- **Y21** · Minor · pixel: *Looked at the new goal:* A goal added by hand has no description, so its card is a different height from the rest  
  *Evidence:* deep pass (simulator, sample data)

**Becomes:** G1 G2

*G1 is described above.*

#### G2. A goal

**One feature:** Everything behind one goal.

**On it:**
- Said: when you first said it, last mentioned
- Did: the events, content and patterns that served it, with dates
- Rename · turn off · revive; ✕ not right on any item
- Goals heard in what you say are proposed, never assumed

**Pinned (opportunities O, backend gaps K):** **O-6** goals · **O-10** corrections

**Backend:** ✗ said-vs-did route · ✓ /goals update  
**States:** none  
**Closes:** G3

```
┌─────────────────────────┐
│ ‹ Ship the first version│
│ Said · 6 Oct, last Mon  │
│ Did this week · 4h      │
│ · Tue 2h "deep work"    │
│ · Thu demo w/ Priya     │
│ · pattern: late nights  │
│                ✕ not right
│ Rename · Turn off       │
└─────────────────────────┘
```

---

### Today: Podcasts (`DarkPodcastsView`)

**Problems on this screen:**

- **L8** · Minor · confusing · dead end: **Podcasts says "Write in your journal and generate your first personalized podcast"** but there is no generate button for a normal user; the menu says "podcasts", the header "Episodes"  
  *Evidence:* simulator
- **R2** · Major · demo in ship: The Podcasts tab carries a "Dev Mode" section (generate real or mock) behind the same user-reachable Dev Mode switch (T1)  
  *Evidence:* `DarkPodcastsView.swift:36, 282–311`
- **T3** · Major · demo/fake: **With Mock API Calls on, a podcast is generated from sample data and looks like a real one** ("Creating Mock Podcast… Using sample data…"); a user who flips it gets fake episodes  
  *Evidence:* `DarkPodcastsView.swift:17, 226–336`
- **T4** · Major · redundant · confusing: **Three separate "Generate podcast" buttons:** the Podcasts tab and twice in Advanced settings, all labelled "Generate Real Podcast" / "Generate Mock Podcast"  
  *Evidence:* `DarkPodcastsView.swift:287`; `DarkSettingsView.swift:1308, 1484`
- **Y22** · Major · broken · clarity: *Opened Podcasts with 3 sample episodes on the server:* **Every episode is titled "Weekly Insights"**: the title is hard-coded and the server's real titles ("The week you stopped rushing", "What the Sunday calls were for") are thrown away. You can't tell episodes apart  
  *Evidence:* deep pass (simulator, sample data)
- **Y23** · Minor · broken: *Read the mood under each title:* The server's moods ("warm", "curious") show as **"neutral"**: anything outside an old fixed list of eight is replaced (`Transcriptviewmodel.swift:632`)  
  *Evidence:* deep pass (simulator, sample data)
- **Y24** · Minor · redundant: *Counted rows:* **4 rows for 3 episodes:** the locally saved first episode sits beside the server's copy  
  *Evidence:* deep pass (simulator, sample data)
- **Y25** · Minor · pixel · redundant: *Looked at a row:* **Two play buttons per row** (a round one on the left, a triangle on the right); the date is cut off ("Oct 20, 2…")  
  *Evidence:* deep pass (simulator, sample data)
- **Y30** · Major · broken · clarity: *Opened Podcasts with the server failing:* **Three of four episodes silently disappeared**: no message, no retry, as if they never existed  
  *Evidence:* deep pass (simulator, sample data)
- **Y31** · Major · broken: *Pulled down to refresh; reopened Podcasts:* **No pull-to-refresh, and the list isn't re-fetched when you open the tab**; it loads once at launch, so a new episode doesn't appear until the app restarts  
  *Evidence:* deep pass (simulator, sample data)

**Becomes:** P1

*P1 is described above.*

---

### Today: The episode player

**Problems on this screen:**

- **N20** · Blocker · broken: **The first episode can never be replayed after onboarding.** The app's player only plays files saved on the phone; the first episode is saved with its web link (only the legacy "generate" path downloads audio), so on Journal the "Reflective episode ▶" pill opens a player whose play, skip and "…" do nothing, silently  
  *Evidence:* `DarkAppContainer.swift:79–86` (file-exists check), `FirstPodcastOrchestrator.swift:44–46` vs `Transcriptviewmodel.swift:572–581`; simulator
- **N21** · Minor · doesn't make sense: **The episode pill is labelled with the mood** ("Reflective episode"), not the episode's title; the full player shows no title, date, chapters, speed or "why this was in it", and only "0:37" with no label  
  *Evidence:* simulator
- **R3** · Minor · dead end: The full player opens only if a transcript is already loaded; otherwise "No Podcast Available" with Dismiss, with no route to the episode list or a retry  
  *Evidence:* `DarkAppContainer.swift:319–351`
- **Y26** · Blocker · broken: *Played a server episode:* **Nothing plays, for any episode:** the app never fetched the audio (no request reached the server). The player only plays files saved on the phone, and server episodes are links, so **no episode can be heard in the app after onboarding.** Extends N20 from the first episode to all of them  
  *Evidence:* deep pass (simulator, sample data)
- **Y27** · Major · missing · broken: *Looked at the player:* It shows a stale "0:37" from an earlier session, no title, no date, no chapters, no speed, no "why this was in it"; the "…" button does nothing; the only way out is a button drawn as a menu icon (≡), which reads as "open menu"; swiping down does nothing  
  *Evidence:* deep pass (simulator, sample data)
- **Y45** · Minor · performance: *Transcript in the player and paywall:* Every line except the current one is blurred (`.blur(radius: 1.8)`), plus 10–22 pt blurs on the paywall veil; blur on many text layers is expensive and the transcript scrolls while playing  
  *Evidence:* deep pass (simulator, sample data)

**Becomes:** P2 P3 X2

#### P2. The player

**One feature:** Listen to one episode, and understand it.

**On it:**
- Title, date, length; transcript following the voice; speed
- “Why this is here” for each part (from the stored plan: evidence; stated vs asked); shown only for v2 episodes (older outlines show the transcript alone)
- Its one question: Yes / No / Why do you think that?
- A word of feedback; keeps playing in the background; swipe down to close

**Pinned (opportunities O, backend gaps K):** **O-5** feedback and the question · **O-13** hypotheses · **K11** chapter timings · **K22** needs the v2 planner

**Backend:** ✓ /podcasts/:id (outline = plan) · ✗ backend: /feedback, /hypotheses  
**States:** playing · buffering · offline · failed · older episode (no plan: transcript only)  
**Closes:** Y26, Y27, Y45, N20, N21, R3

```
┌─────────────────────────┐
│ ⌄                1x  ⋯  │
│ The week you stopped    │
│ rushing                 │
│ "…three of your best    │
│  days began before 8…"  │
│ Why this is here ›      │
│ ━━━━━○───────── 4:12    │
│     ↺15    ‖    15↻     │
│ ┌ It's wondering ─────┐ │
│ │ Are mornings when you│ │
│ │ do your best work?   │ │
│ │ [Yes][No][Why ask?]  │ │
│ └─────────────────────┘ │
└─────────────────────────┘
```

#### P3. Why this is here

**One feature:** The evidence behind one part of an episode.

**On it:**
- What this part says, stated or asked
- The evidence: entries, events, health days, with dates
- For the question: the framework it comes from and what it rests on
- ✕ not right on any line

**Pinned (opportunities O, backend gaps K):** **Plan** stored outline · **O-10** corrections · **Goal 21** why do you think that

**Backend:** ✓ outline on /podcasts/:id · ◐ /hypotheses/:id/why  
**States:** none  
**Closes:** goal 13, 21

```
┌─────────────────────────┐
│ ⌄ Why this is here      │
│ Said: your best days    │
│ start early (stated)    │
│ · 14 Oct · up at 6:40   │
│ · 16 Oct · "felt sharp" │
│ · 17 Oct · run at 7     │
│               ✕ not right
└─────────────────────────┘
```

#### X2. Lock screen: now playing

**One feature:** Keep listening without the app open.

**On it:**
- Title and artwork; play, pause, skip 15
- A now-playing Live Activity for the brief and episodes

**Pinned (opportunities O, backend gaps K):** **O-24** background playback · **O-32** Live Activity

**Backend:** app: playback Live Activity exists; add lock-screen controls (background audio already allowed)  
**States:** playing · paused  
**Closes:** N20, Y26

```
┌─────────────────────────┐
│        9:02             │
│ ┌─────────────────────┐ │
│ │ Retrospect          │ │
│ │ Tuesday's brief     │ │
│ │ ↺15    ‖    15↻     │ │
│ └─────────────────────┘ │
└─────────────────────────┘
```

---

### Today: Recorder

**Problems on this screen:**

- **R1** · Minor · broken (double counting): **The old recorder saves every voice note twice** (`addEntry` → `voice_recording`, plus an explicit upload as `voice_journal`), so the brain counts each note double. The live recorder (`DarkVoiceRecordingView`) saves once, but the old one is still reachable through the legacy home screens (T1–T2)  
  *Evidence:* `VoiceRecordingView.swift:354–387`; reached from `MinimalHomeScreen.swift:87`, `HomeScreen.swift:278`
- **K6** · Note · —: *Recorder (full screen):* Not walked (it records the Mac's microphone). From code: the live recorder saves once; the legacy one twice (R1); transcription confidence is computed and thrown away  
  *Evidence:* `DarkVoiceRecordingView.swift`; `TranscriptionService.swift:88`

**Becomes:** J1

*J1 is described above.*

---

### Today: Settings (`DarkSettingsView`)

**Problems on this screen:**

- **T1** · Blocker · demo/fake in ship: **Every user sees Settings → "Advanced: Dev tools and experiments"** (not debug-only). Inside, a **"Dev Mode"** switch anyone can turn on reveals: **"Mock API Calls: use sample data instead of real API calls"**, an "Experimental View", replaying onboarding, a podcast-flow preview, a **legacy home screen**, and test podcast generation  
  *Evidence:* `DarkSettingsView.swift:100–109` (no `#if DEBUG`), `:1183–1230`, `:1355–1460`
- **T5** · Minor · demo in ship: "Animation: Fluid dots preview" is a Settings row for everyone  
  *Evidence:* `DarkSettingsView.swift:90–97`
- **T6** · Minor · redundant: Settings is 1,890 lines; Advanced alone holds onboarding replay, finale debug, legacy UI, flow previews and new-podcast-arrival tests (development tools living in the shipped settings)  
  *Evidence:* file
- **L13** · Minor · pixel: The Face ID switch reads ambiguously: knob on the "on" side, grey track like "off"  
  *Evidence:* simulator
- **Y40** · Minor · interaction: *Measured touch targets:* Several key controls are under 44 pt: the integration row buttons (34 pt), the player's "…", the debug Skip  
  *Evidence:* deep pass (simulator, sample data)

**Becomes:** T1

#### T1. Settings

**One feature:** Control, in one calm list.

**On it:**
- YOUR BRIEF · Daily brief (on/off, time)
- LISTENING · Voice · Talk or read
- YOU · How straight I am with you · What I’ve learned
- SOURCES · Connected sources (n · 1 needs attention)
- PRIVACY · Background reading · Download my data · Delete my data
- ACCOUNT · Subscription · Sign out · Delete account
- HELP · Contact us · Privacy policy · Terms
- Nothing for developers

**Pinned (opportunities O, backend gaps K):** **Founder** a production settings, simple, nothing dev · **O-17/18** control and transparency · **O-28** no dev tools

**Backend:** ✓ /integrations, /profile · ✗ backend: /settings/*, /briefs/enabled, /preferences, account delete  
**States:** none  
**Closes:** T1–T6, L9, L10, L11, L13, K4

```
┌─────────────────────────┐
│ ‹ Settings              │
│ YOUR BRIEF              │
│  Daily brief   8:30 On ›│
│ LISTENING               │
│  Voice         Warm    ›│
│  Talk or read  Talk    ›│
│ YOU                     │
│  How straight  Honest  ›│
│  What I've learned     ›│
│ SOURCES  4 · 1 needs   ›│
│ PRIVACY                ›│
│ ACCOUNT                ›│
│ HELP                   ›│
└─────────────────────────┘
```

---

### Today: Profile settings

**Problems on this screen:**

- **L9** · Major · broken · fake: **Profile's settings do nothing:** podcast cadence (Daily … Every 2 weeks) is stored on the phone and never read or sent; "Deep Research Mode" is read only by the legacy home screen. "AI style" is promised in the row's subtitle but isn't there  
  *Evidence:* `DarkSettingsView.swift:499–530`; `HomeScreen.swift:1054`; simulator
- **L10** · Minor · doesn't make sense: "Every Other Day" is described as "Mon, Wed, Fri, Sun" (four days, two in a row)  
  *Evidence:* simulator

**Becomes:** T2 T6 T7

#### T2. Daily brief

**One feature:** When, and whether, your brief arrives.

**On it:**
- On / off
- Time (your local time)
- Typical length (short / standard / long, capped at 12 min)
- Preview today’s

**Pinned (opportunities O, backend gaps K):** **O-3** brief · **K4** local time

**Backend:** ◐ /briefs/enabled · ✗ timezone + time  
**States:** none  
**Closes:** L6

```
┌─────────────────────────┐
│ ‹ Daily brief           │
│ Each morning      ( on )│
│ Time          8:30 am › │
│ Length   ● Standard     │
│          ○ Short ○ Long │
│ Play today's ▶          │
└─────────────────────────┘
```

#### T6. How straight I am with you

**One feature:** How bold it may be.

**On it:**
- The four levels; its current reading and why
- Your choice outranks its guess; “let it decide” hands back

**Pinned (opportunities O, backend gaps K):** **O-16** how bold

**Backend:** ◐ /settings/appetite  
**States:** none  
**Closes:** goal 22

```
┌─────────────────────────┐
│ ‹ How straight          │
│ ○ Just what happened    │
│ ○ Gentle questions      │
│ ● Honest observations   │
│ ○ Don't hold back       │
│ I picked this because…  │
│ Let it decide           │
└─────────────────────────┘
```

*T7 is described above.*

---

### Today: Integrations & Data

**Problems on this screen:**

- **L14** · Minor · doesn't feel good: With the server down, Integrations shows "Could not connect to the server." with only OK; the retry is a separate icon. Plain words, but no next step  
  *Evidence:* simulator
- **Y32** · Major · interaction · risk: *Looked at the row actions:* **The power button disconnects a source in one tap, with no confirmation**, and sits 2 pt from the "…" menu; both targets are 34 pt, under Apple's 44 pt minimum. Missing the "…" by a few points turns Google off  
  *Evidence:* deep pass (simulator, sample data)
- **Y33** · Major · clarity · pixel: *Read the states:* Status is colour-coded green and orange in colours the design system doesn't have; "Verified and connected · Continuous sync" and "Sync needs attention · Continuous sync" wrap mid-phrase; **"needs attention" never says what to do** (the fix, reconnect, is hidden in "…" as "Sync now")  
  *Evidence:* deep pass (simulator, sample data)
- **Y34** · Minor · incoherent: *Compared with onboarding:* The same source is "Google Docs" here, "Google Docs/YouTube/Gmail" in onboarding, and "Google" on the server; summary tiles ("1 Verified · 2 Needs attention") don't say which  
  *Evidence:* deep pass (simulator, sample data)
- **Y35** · Minor · incoherent: *Looked at the sheet:* This is a sheet over Settings with its own back button, while every other Settings page is a full screen: two navigation styles one tap apart  
  *Evidence:* deep pass (simulator, sample data)

**Becomes:** T3 T4

#### T3. Sources

**One feature:** What you’ve connected, and how it’s going.

**On it:**
- Each: connected, last read, what it’s for
- Needs attention says exactly what to do (Reconnect)
- Add a source; file imports with how-to
- Each source opens T4

**Pinned (opportunities O, backend gaps K):** **O-17** sources · **O-22** plain states

**Backend:** ✓ /integrations  
**States:** connected · needs attention · expired · syncing  
**Closes:** Y32, Y33, Y34, Y35, L14, C6

```
┌─────────────────────────┐
│ ‹ Sources               │
│ Google   read 2 min ago›│
│ Health   read today    ›│
│ Spotify  ⚠ Reconnect   ›│
│ Calendar read today    ›│
│ + Add a source          │
│ Import a file          ›│
└─────────────────────────┘
```

#### T4. A source

**One feature:** One source: what it reads, and control over it.

**On it:**
- What it reads and what it helps it understand
- Last read; Sync now
- Disconnect (with confirmation) · Delete what it read (with confirmation)

**Pinned (opportunities O, backend gaps K):** **O-17** sources · **Safety** confirm before disconnect

**Backend:** ✓ /integrations/connections/:id/{sync, delete-data}, DELETE  
**States:** syncing · failed · disconnected  
**Closes:** Y32

```
┌─────────────────────────┐
│ ‹ Google                │
│ Reads: mail, docs,      │
│ calendar, YouTube       │
│ Helps me see: your work │
│ and your weeks          │
│ Last read 2 min ago     │
│ Sync now                │
│ Disconnect…             │
│ Delete what it read…    │
└─────────────────────────┘
```

---

### Today: Advanced (developer tools)

**Problems on this screen:**

- **L11** · Major · psychological (trust before ask): **Opening Advanced asks for notification permission** out of nowhere, with no reason given, under the name "Retrospect-2026" (W6)  
  *Evidence:* `DarkSettingsView.swift:1586–1589`
- **T2** · Blocker · demo/fake in ship: **The legacy home screen shows hard-coded fake podcasts** ("Love and Relationships", "Career Growth", "Personal Health", "Family Connections", each with "Mock transcript for…") and is reachable from Settings  
  *Evidence:* `HomeScreen.swift:1425–1429, 1505, 1542`; `DarkSettingsView.swift:1418, 1543`

**Becomes:** T1 (removed from the shipped app)

*T1 is described above.*

---

### Today: Google prompt and data tools

**Problems on this screen:**

- **K3** · Minor · redundant · stale copy: *"Connect Google" prompt (appears over Home after onboarding when Google isn't connected):* **A second Google ask after onboarding already offered Google**, labelled "Secure Document Access… your Google Docs", the narrow old scope; promises "read-only… to include relevant content in your weekly insights"  
  *Evidence:* `DataManagementSection.swift:1256–1300`; `RetrospectApp.swift` (shown 1 s after launch)
- **K4** · Minor · demo in ship · structure: *Data management ("Reset All Data"):* Lives inside a 1,461-line file mixing Google Docs browsing, data overview and reset; "Setup Required: please add your Google Client ID" is developer copy shown to users when unconfigured  
  *Evidence:* `DataManagementSection.swift:18–103, 573–578`

**Becomes:** N6 T5

*N6 is described above.*

#### T5. Privacy

**One feature:** What it reads, where, and how to stop it.

**On it:**
- Background reading on / only what I send (with what changes)
- Where your data is processed (named)
- Download my data · Delete my data (confirm)

**Pinned (opportunities O, backend gaps K):** **O-17** privacy · **Ambient** switch

**Backend:** ◐ /settings/ambient · ✗ export, delete  
**States:** none  
**Closes:** D1

```
┌─────────────────────────┐
│ ‹ Privacy               │
│ Read in the background  │
│  ( on )  Only what I    │
│          send ○         │
│ Where it's processed  › │
│ Download my data      › │
│ Delete my data…         │
└─────────────────────────┘
```

---

## New screens with no counterpart today

What the brain can now do that today's app has no screen for.

### N5. Privacy, shown off

**One feature:** Earn trust before asking for data.

**On it:**
- Spoken callback: why it asks, what it will never do
- What it reads · where it is processed (our server, named AI providers) · what it never does
- Read in the background? (on / only what I send)
- Delete everything anytime

**Pinned (opportunities O, backend gaps K):** **O-17** privacy and ambient · **O-22** plain words

**Backend:** ◐ /settings/ambient (✗ backend route)  
**States:** none  
**Closes:** D1, N13

```
┌─────────────────────────┐
│ ‹                       │
│ What I read   only what │
│               you connect
│ Where         our server│
│               + named AI│
│ Never         sold, ads │
│                         │
│ Read in the background? │
│ (● on)(○ only what I    │
│          send)          │
│ Delete everything anytime
│          [ Continue ]   │
└─────────────────────────┘
```

### N9. How straight should I be?

**One feature:** Set how bold it is with you.

**On it:**
- Four levels in plain words
- Its first guess preselected, with the reason from your words
- One tap to change; changeable later

**Pinned (opportunities O, backend gaps K):** **O-16** how bold · **K20** guess made on the spot from saved answers · **Switch** ENABLE_APPETITE

**Backend:** ◐ /settings/appetite with suggested (✗ backend route)  
**States:** none  
**Closes:** goal 22

```
┌─────────────────────────┐
│ "How straight should I  │
│  be with you?"          │
│ ○ Just what happened    │
│ ○ Gentle questions      │
│ ● Honest observations   │
│ ○ Don't hold back       │
│ "You said you want to be│
│  challenged."           │
│          [ Continue ]   │
└─────────────────────────┘
```

### Y2. Search results

**One feature:** An answer from your own mind, with its receipts.

**On it:**
- Sources first (~1 s), lighting their part of the map
- Then what it found: 2–5 sentences, every claim numbered to a source; facts and guesses labelled
- Or a plain “nothing answers this” with what the sources do show
- Only what’s certain (filter); open any source; ✕ not right on any line

**Pinned (opportunities O, backend gaps K):** **O-7** search · **Goal 6** receipts, abstains

**Backend:** ◐ /search/sources, /answer, /source (✗ backend routes)  
**States:** searching · found · abstained · offline · failing  
**Closes:** —

```
┌─────────────────────────┐
│ ‹ "when do I sleep best"│
│ What I found            │
│ After days you run [1], │
│ and when work stops     │
│ before 9 [2].  ✕        │
│ □ only what's certain   │
│ SOURCES                 │
│ [1] Health · 14 nights ›│
│ [2] Journal · 3 entries›│
└─────────────────────────┘
```

### Y3. A source

**One feature:** One thing you said, did or saved, in full.

**On it:**
- The entry, event, fact, answer or saved link, in full
- Where it came from and when
- For a saved link: your reason, and the transcript for videos

**Pinned (opportunities O, backend gaps K):** **Goal 6** open any source · **O-14** saved links

**Backend:** ◐ /search/source/:kind/:id (✗ backend route)  
**States:** loading · not found  
**Closes:** —

```
┌─────────────────────────┐
│ ‹ Journal · 14 Oct      │
│ "Went to bed at 10 for  │
│  once, woke up before   │
│  the alarm…"            │
│ Source: your journal    │
└─────────────────────────┘
```

### Y4. A node

**One feature:** Everything it knows about one thing, and why.

**On it:**
- What it believes, how sure (●●●○), the quotes behind it, when it last moved
- Still true · Not right (changed then, or wrong)
- Linked nodes; for a person, same person?; for a goal, said vs did; saved links tied to it

**Pinned (opportunities O, backend gaps K):** **O-10** corrections · **O-12** people · **O-14** saved links

**Backend:** ◐ /corrections, /people/held · ✗ node detail in map route  
**States:** none  
**Closes:** —

```
┌─────────────────────────┐
│ ⌄  Priya                │
│ Comes up 14× this month │
│ A close colleague; you  │
│ feel lighter after      │
│ talking   fairly sure ●●●○
│ "coffee w/ Priya, felt  │
│  lighter" · 12 Oct      │
│ [Still true][Not right] │
│ Linked: Work · Ship v1  │
└─────────────────────────┘
```

### Y5. What I know about you

**One feature:** Its answers to the 36 questions about you.

**On it:**
- By area of life; each answer with how sure and the evidence count
- Tap for the quotes; Still true / Not right
- Areas it is silent on, said warmly (“I don’t know much about your days yet”)
- What moved since last week

**Pinned (opportunities O, backend gaps K):** **O-9** 36 answers · **K2** read-contract route · **Goal 10** admits what it doesn’t know

**Backend:** ✗ GET /understanding (read contract)  
**States:** thin (day one) · loading · offline  
**Closes:** —

```
┌─────────────────────────┐
│ ‹ What I know about you │
│ WORK                    │
│ What drives you most?   │
│ Building things people  │
│ use. fairly sure ●●●○ › │
│ HEALTH                  │
│ I don't know much about │
│ your health yet.        │
│ MOVED THIS WEEK  2 ›    │
└─────────────────────────┘
```

### Y6. A question waiting

**One feature:** Answer one thing it is unsure of.

**On it:**
- “Is the Sam in your writing Sam Ortiz from your contacts?” Same / Different
- or a hypothesis: the question, Yes / No / Why do you think that?
- One at a time; never a pile

**Pinned (opportunities O, backend gaps K):** **O-12** people · **O-13** hypotheses · **Dial** speak off by default

**Backend:** ◐ /people/held, /hypotheses (✗ backend routes)  
**States:** none waiting  
**Closes:** —

```
┌─────────────────────────┐
│ ⌄ One question          │
│ Is the Sam in your      │
│ writing Sam Ortiz from  │
│ your contacts?          │
│ [ Same ] [ Different ]  │
│ Not sure                │
└─────────────────────────┘
```

### T8. What I’ve learned

**One feature:** How it is learning to ask you better.

**On it:**
- Which kinds of questions you answer, and how often
- Plain words; read only

**Pinned (opportunities O, backend gaps K):** **O-18** transparency · **Switch** ENABLE_LEARNING

**Backend:** ◐ /settings/learning  
**States:** too early  
**Closes:** goal 19

```
┌─────────────────────────┐
│ ‹ What I've learned     │
│ You answer questions    │
│ about work most (8/10)  │
│ and skip ones about     │
│ family (1/5), so I ask  │
│ those less.             │
└─────────────────────────┘
```

### X1. Share to Retrospect

**One feature:** Save anything, with your reason.

**On it:**
- From any app’s share sheet
- Why are you saving this? (voice or text)
- Goes with a goal if one fits
- Video transcripts fetched automatically

**Pinned (opportunities O, backend gaps K):** **O-31** share · **K9** save-link route · **K19** link and note content types · **Switch** SUPADATA_API_KEY

**Backend:** ✗ share extension + POST /saved  
**States:** saving · saved · offline (queued)  
**Closes:** —

```
┌─────────────────────────┐
│ Save to Retrospect      │
│ youtube.com/… "How to…" │
│ Why are you saving this?│
│ ┌──────────────── 🎙 ┐  │
│ └────────────────────┘  │
│ Goes with: Ship v1  ▾   │
│              [ Save ]   │
└─────────────────────────┘
```

### X3. Notifications

**One feature:** Tell you when something is ready, then get out of the way.

**On it:**
- Your brief is ready (if on) · This week’s episode is here · One question waiting (at most one a day)
- Each opens the right screen; nothing at night

**Pinned (opportunities O, backend gaps K):** **O-30** notifications · **K10** APNs · **K4** local time

**Backend:** ✗ APNs + device tokens · ◐ /notifications/generate  
**States:** none  
**Closes:** A6, L11

```
┌─────────────────────────┐
│ ┌ RETROSPECT ─── now ─┐ │
│ │ This week's episode │ │
│ │ is here: "The week  │ │
│ │ you stopped rushing"│ │
│ └─────────────────────┘ │
└─────────────────────────┘
```

### X4. Widget

**One feature:** Talk to it, or play today’s brief, in one tap.

**On it:**
- Small: 🎙 Tell me…
- Medium: today’s brief ▶ + 🎙

**Pinned (opportunities O, backend gaps K):** **O-32** widget

**Backend:** app only  
**States:** brief ready · not yet  
**Closes:** —

```
┌───────────┐┌───────────┐
│ Retrospect││ Your brief│
│    🎙     ││ ▶ 2 min   │
│ Tell me…  ││    🎙     │
└───────────┘└───────────┘
```

---

# Part C. Across the whole app

## Problems that belong to no single screen

- **X1** · Major · risk (cost): **The app writes its own AI prompts and sends them to `/claude/generate`, a general "run any prompt" proxy.** It's protected by sign-in and a global rate limit and capped at 8,192 tokens, but any signed-in account (or leaked token) can run arbitrary Claude prompts on Retrospect's bill. Prompts should live on the server, per feature  
  *Evidence:* `ClaudeService.swift:94–108`; `backend/src/routes/claude.ts:17–39`, `index.ts:79`
- **X2** · Minor · stale: The proxy's default model is an older one (`claude-sonnet-4-6`) unless `CLAUDE_MODEL` is set  
  *Evidence:* `claude.ts:33`
- **X3** · Major · doesn't feel good: **28 places show raw errors to the person** (`error.localizedDescription`), and the API client builds them as "HTTP 500: {body}" (logged problem, wider than logged)  
  *Evidence:* `RetrospectAPIClient.swift:572`; 28 view sites
- **X4** · Minor · dead · broken: Legacy `OpenAIService` remains with an empty key ("until all call sites use the API"); any remaining caller fails silently  
  *Evidence:* `OpenAIservice.swift:38–41`
- **D1** · Major · dead · risk (false privacy claim): **Old onboarding screens say "All processing happens on your device" and "Your documents stay private and are never shared."** Both are false: Retrospect processes on its server and with AI providers. These screens (`DarkPrivacyOnboardingScreen`, `DarkGoogleDocsOnboardingScreen`, `DarkAppleHealthOnboardingScreen`, `DarkGoalsOnboardingScreen`, about 850 lines) are **unreachable**, but the claims live in the code and the same "never shared" line is in `GoogleDocsOnboardingScreen` (reached only from another dead template). Risk: someone revives them  
  *Evidence:* `DarkOnboardingFlow.swift:271–938` (0 references); `Components/GoogleDocsOnboardingScreen.swift:191`
- **O3** · Minor · logic: Completing the questions silently marks the privacy notice as acknowledged (the privacy page is no longer on the path)  
  *Evidence:* `OnboardingState.swift:147`
- **O4** · Minor · redundant naming: Named "Dark…" throughout, but forced to light mode  
  *Evidence:* `DarkOnboardingFlow.swift:80`
- **S2** · Minor · logic risk: **83 timed delays (`asyncAfter`)** across the app: a sign of timing patches that behave differently on slow devices and networks  
  *Evidence:* `grep asyncAfter`
- **S3** · Minor · demo: 37 `#if DEBUG` blocks and 5 "DEV:" controls: to be checked that none leaks into a release build  
  *Evidence:* `grep`
- **S4** · Minor · redundant: Two Xcode projects: `Retrospect/Retrospect.xcodeproj` (live) and `Retrospect fina (SwiftUI).xcodeproj` at the root  
  *Evidence:* repo root
- **F1** · Minor · broken: Three Libre Baskerville font files are saved web pages, not fonts  
  *Evidence:* `Retrospect/Fonts/LibreBaskerville-*.ttf` (re-check)
- **K7** · Note · —: *Widgets, Live Activity, notifications, share:* Phone-only. From code: no share extension exists; notifications for an unknown episode create placeholder transcripts (A6)  
  *Evidence:* targets list; `RetrospectApp.swift`
- **Y36** · Major · accessibility: *Set the largest accessibility text size:* **Nothing in the app got bigger.** 681 fonts are fixed sizes; 21 follow the system text size. Anyone who needs larger text can't get it (an App Store accessibility expectation)  
  *Evidence:* deep pass (simulator, sample data)
- **Y37** · Minor · incoherent · pixel: *Switched the phone to dark mode:* **The app stays light**: it's forced to light in 24 places (while every main file is named "Dark…"); a couple of player error screens force dark instead. The founder's decision is light and dark together  
  *Evidence:* deep pass (simulator, sample data)
- **Y38** · Major · accessibility: *Counted VoiceOver labels:* **9 accessibility labels for 427 buttons.** Icon-only buttons (menu, mic, +, send, power, "…", the two-arrow icon) are unnamed to VoiceOver  
  *Evidence:* deep pass (simulator, sample data)
- **Y39** · Minor · accessibility: *Checked reduced motion:* Respected in 2 places only; the shader, the dots and the onboarding animations ignore it  
  *Evidence:* deep pass (simulator, sample data)
- **Y48** · Minor · performance · logic: *Whole app:* 83 timed delays (`asyncAfter`) choreograph animations by the clock; on a slow phone they fall out of step with what's actually ready (S2)  
  *Evidence:* deep pass (simulator, sample data)
- **Y43** · Note · ok: *The SE's simulator uses no Dynamic Island; the welcome, intro and closing screens fit; nothing was cut off on those:* —  
  *Evidence:* deep pass (simulator, sample data)
- **Y49** · Note · ok · (O2): *Closed the app at Connections and reopened:* **Resumed at Connections**: step-level progress is saved (good). Within the questions, answers are not (O2)  
  *Evidence:* deep pass (simulator, sample data)

## Work that has no screen

| | What |
|---|---|
| **K1** | Backend pass-through routes for conversation, corrections, briefs, search, people, hypotheses, actions, settings, preferences, onboarding, feedback |
| **K2** | New reads: /understanding (read contract), /understanding/map, /goals/said-vs-did |
| **K3** | Brief audio: voice the through-line and items, stored like episode audio |
| **K4** | Timezone stored; brief and episode scheduled in local time (today 08:00 and Sun 06:00 UTC) |
| **K5** | Streamed voice, so spoken replies start in under a second |
| **K6** | An action proposer (from your own words only) feeding the existing approval ledger; the Journal slot waits for it |
| **K7** | Entry edit and delete that reach the brain (re-read, retract) |
| **K8** | Idempotency key on /content; an outbox in the app |
| **K10** | Push: APNs device tokens and delivery |
| **K11** | Chapter timings for episodes |
| **K12** | One first episode per person, enforced on the server |
| **K13** | StoreKit products and server-checked receipts |
| **K14** | Listening preference (talk / read) stored |
| **K16** | Source descriptions (what each helps it understand) added to the backend catalog from the agent profiles |
| **K4+** | A first guess at timezone from the calendar (usualOffset), confirmed in N13 |
| **K19–K22** | Content types for links and notes; the bold-guess seed on demand; magic moments wired to the tease; EPISODE_PLANNER and DAILY_PLANNER set to v2 for everyone |
| **Switch** | Flip as phases land: EPISODE_PLANNER=v2, DAILY_PLANNER=v2, ENABLE_ONBOARDING_PIPELINE, ENABLE_MATERIAL_ARRIVALS, ENABLE_DAILY_BRIEF, ENABLE_APPETITE, ENABLE_LEARNING, ENABLE_INTEGRATION_RUNTIME, hypothesis dial, SUPADATA_API_KEY |
| **Lint** | Stale or unsupported claims stay hidden until resolved (already runs daily; nothing to show) |
| **Spend** | $15 per person per day ceiling on episodes (already on) |
| **O-26** | Accessibility everywhere: Dynamic Type, VoiceOver labels, 44 pt targets, reduced motion, light and dark |
| **O-27** | Layout that fits any phone, SE to Pro Max |
| **O-28** | No developer tools in the shipped app; a server-side staff role for the team; demo content only in the demo account |
| **Perf** | No 60-times-a-second state updates on the main thread; no large blurs on scrolling text; check on an older phone |
| **Delete** | The ~57 unreachable screens and the second Xcode project are removed |

## Ship vs developer: what leaves the shipped app

| Feature | Where it belongs | Ref |
|---|---|---|
| Developer tools row and Dev Mode switch, in Settings for everyone | Debug builds only | T1 |
| Mock API Calls: fake podcasts from sample data | Delete | T3 |
| Legacy home screen with made-up podcasts | Delete | T2 |
| Experimental View, Preview Podcast Flow (×2), Test notification, Replay onboarding | Debug builds only | T6 |
| Generate Real / Mock Podcast buttons (×3) | Team only (server role) | T4 |
| Resync all entries | Replace with an outbox | J4 |
| Animation preview row | Delete | T5 |
| Deep Research Mode and podcast schedule (do nothing) | Replace with real settings | L9 |
| Canned "Learning about you" claims | Replace with real stages and their own words | N1 |
| Canned "wonderings" | Replace with real lines or none | N5 |
| Fake progress percentage | Replace with real stages | A5 |
| Demo script shown as your episode; fake playback clock | Demo account only | L2 |
| "Your next episode is in 3 days" | Replace with the real schedule | L6 |
| Placeholder prices, no purchase path | Replace with StoreKit | L4 |
| General "run any prompt" endpoint | Replace with feature endpoints | X1 |
| ~57 unreachable screens, incl. false privacy claims | Delete | S1 |
| Second Xcode project; legacy OpenAI service | Delete | S4 |
| Debug Skip, DEV buttons, test sign-in, paywall close | Already debug-only (the paywall needs a real close) | V6, N19 |

## The psychological journey (what a person does, thinks and feels)

Drawn from the walk-through and the code, using the lenses in [the audit plan](./app-audit-plan.md#the-five-passes-per-screen). **Peak** = the moment they'll remember; **risk** = where people are likely to drop off.

| # | Moment | They do | They think | They feel | Lens broken | What the plan changes |
|---|---|---|---|---|---|---|
| 1 | Welcome | read the promise, tap Sign in | "a weekly podcast about me?" | curious | — | the current promise (A1) |
| 2 | Apple's sheet: "Create an account for Retrospect-2026" | wait ~2 s with no feedback, then approve | "is this the right app?" | slight doubt | clarity of state; trust | the real name, a pressed state (W6, W7) |
| 3 | "Everything you share is private" → "What should I call you?" | type their name again | "didn't Apple just tell it that?" | it's a form | effort vs reward | name from Apple; the first question is a story question |
| 4 | 8 demographic questions, incl. **sexual orientation** | answer or hesitate | "why does a podcast need this?" | examined, guarded | **trust before ask**; self-image | no demographics; every question has a stated use (V1, V2) | **risk** |
| 5 | 10 deep questions | think hard, type a lot | "this is actually thoughtful" | engaged, invested | — | voice-first, acknowledged after each answer | **peak (first)** |
| 6 | Dream city, dream house | tap a pill | "huh, a quiz?" | deflated | peak–end | ends on the deepest question (V3) |
| 7 | Goal cards | prune a list | "it got me, mostly" | seen | — | brain-owned goals, kept |
| 8 | 17 sources with engineering labels | scroll, skip most | "which of these matter? what's 'Verification-gated'?" | overwhelmed | **choice load** | ≤5 recommended, each with its reason (C4, C6) | **risk** |
| 9 | Host picker (three canned hosts, no sample) | pick blind | "does it matter?" | indifferent | effort vs reward | a voice made for them, heard first (P1, P2) |
| 10 | "Play Podcast" → "Learning about you 94%" for minutes | wait, maybe leave | "it said play" | misled, impatient | **waits** (Maister); labels | real stages, started early (E1, A5) | **risk (highest)** |
| 11 | First episode plays; at 40 s it fades to the paywall | listen, then hit the price | "it knows me… and now it wants $20" | moved, then sold to | peak–end | the reveal timed to the strongest line, honest prices (L4) | **peak (intended)** |
| 12 | If generation failed: silence, empty home, or a demo script on a fake clock | look for their episode | "where is it? was that even mine?" | let down, deceived | peak–end; honesty | named failure + promise (A1, L2) | **risk (trust)** |
| 13 | Home: "tell me something…", "next episode in 3 days" | maybe type, maybe close | "what do I do here every day?" | unsure | **habit** (no cue, no reward) | Home with the brief, the conversation and "waiting on you" (B1) |
| 14 | Days 2–7: write; nothing visibly comes back until the episode | write a few times, then less | "is it listening?" | ignored | habit; clarity of state | every entry shows "read by the brain"; daily brief; replies (B1) | **risk (week 1)** |
| 15 | Settings: dev tools, settings that do nothing, a surprise permission prompt | explore | "is this finished?" | doubt about the product | trust | nothing for developers; every setting real (T1, L9, L11) |

**The shape today:** one real peak (the deep questions, step 5), an intended peak that often fails (the first episode, 11–12), and the highest drop-off risks right before and after it (8, 10, 12). Day-to-day use has no habit loop (13–14). **The shape the plan aims for:** trust earned before any ask, a wait that's short, honest and started early, the episode as the peak *and* the end of onboarding, and a reason to open it every day (the brief and replies).

## Re-check of the problems logged before the audit (20 Oct, from code)

| Logged problem ([ios-v2 §2](./ios-v2.md#2-problems-in-the-current-app)) | Now | Audit ref |
|---|---|---|
| Connections: unclear labels, file uploads, "Make my podcast" covers the list | still there (overlap not yet seen live) | C1, C6, C8 |
| Canned hosts | still there | P1 |
| "Learning about you" *and* a demo podcast | still there | A5, V10 |
| No way out of the demo player | fixed (close button, `PodcastPaywallFlow.swift:118`) | — |
| Hangs at 94% / two episodes per onboarding | still there; server has no duplicate check | A5, A7 |
| Goals step waited minutes | fixed server-side (#12) | — |
| Several Play Podcast buttons, no linear story | still there | E1, V10 |
| Answers lost on close | still there | O2 |
| Redoing onboarding reused old answers | unverified (server) | — |
| "Preparing your episode" frozen | live path now shows "Learning about you" instead; same fake wait | A5 |
| Demo shown after "Preparing" | only on the debug path now | V10 |
| Google labelled "Google Docs" | still there (three Google cards) | C5 |
| Dots over text | needs the live walk-through | — |
| ~90 s launch | not seen on the simulator (launch was quick) | — |
| Broken font files | **still there:** the 3 Libre Baskerville files are saved web pages, not fonts | new: F1 (m) |
| Audio setup Apple warns about | 13 `setCategory` sites, `setActive(true)` on the main thread in 3 places | to confirm live |
| No share extension | still none (targets: app, widgets, Screen Time report) | B6 plan |
| Raw errors | still there | X3 |
| Two app versions drifted | still two Xcode projects | S4 |
| Uploads lost silently | still there | J1 |
| Calendar sent as one summary | `NativeSourcesManager.swift` reads EventKit; per-event upload unverified | — |
| Five onboarding flows | still there (dead code) | S1 |

---

# Part D. The backend: what it can do, and the gaps

## 3. The complete backend inventory

Legend: **App** = can the iOS app reach it today (✓ via the backend · ◐ agent only, behind its internal secret · ✗ nowhere). **On** = switched on in production.

### 3.1 Capture and reading

| Capability | Where | Shape | App | On |
|---|---|---|---|---|
| Send an entry (text, voice transcript, any content type) | backend `POST /content` {contentType, content, contentDate, metadata} | 202, fire and forget; no idempotency key | ✓ | yes |
| List what was sent | backend `GET /content` (id, type, date, processing_status) | | ✓ | yes |
| Read new material (extract facts, link people, update answers) | agent `jobs/daily-ingestion` 05:00 UTC; `material-arrivals` every minute | | — | daily yes; arrivals **off** (`ENABLE_MATERIAL_ARRIVALS`) |
| Ambient switch (read sources in the background, or only what you send) | agent `GET/PUT /settings/:userId/ambient` → {enabled, effective}; master switch wins | | ◐ | yes |
| Trust class per item (own words vs data) | `raw_content.trust_class` (129) | | — | yes |
| Delete an entry | backend `DELETE /content/:id` (removes the entry; the facts and answers drawn from it are **not** retracted) · reprocess `POST /content/:id/reprocess` | | ✓ but the app never calls it | — |
| Edit an entry | none (reprocess re-reads, but there's no way to change the words) | | ✗ | — |

### 3.2 Sources

| Capability | Where | App | On |
|---|---|---|---|
| Catalogue of sources with connection state | backend `GET /integrations` | ✓ | yes |
| Connect (OAuth start, callback) | backend `/integrations/:id/connect/start`, callback | ✓ | yes |
| File imports (ChatGPT, Claude, Grok, Netflix, archives) | backend `/integrations/:id/imports`, `/assets` | ✓ | yes |
| Sync now, disconnect, delete source data | backend `/integrations/connections/:id/{sync,delete-data}`, DELETE | ✓ | yes |
| Device batches (Health, Screen Time, calendar, contacts, music, photos) | backend device batches → agent `/integrations/enqueue-device-batch` | ✓ | yes |
| Connectors: Gmail, Google Calendar, Google Docs, YouTube, Spotify, Reddit, TikTok, X, LinkedIn, Pinterest, archive import | agent `connectors/` | ✓ (via backend) | runtime **off** (`ENABLE_INTEGRATION_RUNTIME`) |
| **What the app can actually connect today** (backend `services/integration-catalog.ts`) | **available:** Apple Health, Google Docs · **in development:** Calendar, Screen Time, Apple Music, Photos, Contacts, Spotify, YouTube, Reddit · **Google verification needed:** Gmail · **platform approval needed:** TikTok, X, LinkedIn · **file import:** ChatGPT, Claude, Grok, Netflix | ✓ `GET /integrations`, `/catalog`, `/readiness`, `/connections`, `POST /:id/native-connected`, `/connections/:id/reconnect` | — |
| What each source helps it understand (general and special purpose, signals, how it may be used) | agent `integrations/source-intelligence.ts` (profiles per source) | ✗ not in the backend catalog (only short domain tags) | — |
| Research about the person's public profiles (Instagram, TikTok, X, LinkedIn, Substack, YouTube handles) | agent `pipelines/social-research.ts`, `/ingest/social-research` (internal) | ✗ | — |
| YouTube watch history (Takeout import) and transcripts for saved videos | agent `imports/youtube-takeout`, `reference/youtube-transcript` (needs `SUPADATA_API_KEY`) | ✗ (script only) | transcripts off until key set |
| Revoke a whole account | agent `/integrations/accounts/revoke` | ◐ | yes |

### 3.3 Understanding (the brain's picture of you)

| Capability | Where | Shape | App |
|---|---|---|---|
| **The read contract**: answers to the 36 questions (question, answer, confidence, independent sources, confirmed, stated/asked, last moved), silent areas, patterns (confidence, instances, first/last seen, trajectory), whys (mechanism, provisional), goals, shifts from normal, time by category, what moved since the last episode | agent `understanding/read.ts` `readUnderstanding()` | `UnderstandingContract` | **✗ no route** |
| Said vs did per goal (said: stated/last mentioned; did: hours this week vs usual, events, content items, patterns) | agent `understanding/said-vs-did.ts` | `SaidVsDid` | **✗ no route** |
| Content groups (what you've been consuming, clustered and named) | agent `understanding/content-groups.ts` | | ✗ |
| Entities: person, organization, project, place, topic, event, goal, identity, emotion, habit (confidence, status) | table `entities` + `entity_aliases` | | ✗ (old `/graph/assertions` only) |
| Facts between entities (subject → predicate → object, confidence, status) with evidence | `assertions`, `assertion_evidence`, `assertion_relations`, `claim_edges` | | ◐ old backend `/graph/assertions` |
| People matching: "is the Sam in your writing Sam Ortiz?" | agent `GET /people/:userId/held`, `POST …/held/:id` {same\|different} | | ◐ |
| Lint: claims flagged as stale or unsupported are withheld until resolved | agent `brain/lint.ts`, daily | | — |
| **People significance**: recency-weighted mentions × intensity × closeness, half-life 60 days; a barista mentioned once stays small, a partner mentioned weekly grows | agent `brain/people.ts` (stored on each person) | | ✗ (the map's dot size for people) |
| Changes from your normal (e.g. steps up 95% on your usual week, with significance) | agent `brain/baseline-shifts.ts` → `shifts` in the read contract | | ✗ (via `/understanding`) |
| Where your time went (each calendar event categorised) | agent `brain/time-categories.ts`, `place-events.ts` → `time` in the read contract | | ✗ (via `/understanding`) |
| Your usual timezone offset, inferred from your calendar | agent `brain/daily-summaries.ts` `usualOffset()` | | — (a first guess for K4) |
| The portrait (a small always-readable model: slots and lines) | agent `brain/portrait.ts`, `user_understanding` | | ✗ |

### 3.4 Talking to it

| Capability | Where | Shape | App |
|---|---|---|---|
| **Conversation** | agent `POST /conversation` {userId, text} → {intent: fyi\|question\|correction\|chat, reply (may be empty: silence is allowed), cut, used}; `GET /conversation/:userId/today` (working memory 18 h) | | ◐ |
| **Corrections in plain words** | agent `POST /corrections` {text} → applied, or candidates to confirm; `POST /corrections/confirm` {kind: fact\|answer\|pattern\|why, id, mode: changed\|wrong} | | ◐ (backend has old graph feedback only) |
| **Search** | agent `POST /search/sources` {q} → hits {kind: item\|fact\|answer\|saved, snippet, happened_at, score} (~1 s); `POST /search/answer` → {summary, abstained, sources, numbered citations}; `GET /search/:userId/source/:kind/:id` | | ◐ |
| **Hypotheses** ("what it's wondering"), from a closed set of non-clinical frameworks | agent `POST /hypotheses/:userId/:id` {yes\|no}; `GET …/why` → framework, rationale, what it rests on | proposed and offered inside the weekly episode (one asked slot); dial `speak` **off by default** | ◐ |
| How bold it may be (appetite 0–3: just what happened · gentle questions · honest observations · don't hold back), first guess from your words | agent `GET/PUT /settings/:userId/appetite` {level \| null} | stated outranks inferred | ◐; inference behind `ENABLE_APPETITE` |
| What it's learned about its own questions | agent `GET /settings/:userId/learning` | behind `ENABLE_LEARNING` | ◐ |
| Preferences (tone, trusted voice, focus areas, avoid topics, directives) | agent `GET/PUT /preferences/:userId` | | ◐ |
| **Actions** (draft a message, a reminder, a calendar hold, a note): approve / reject / undo | agent `GET /actions/:userId`, `POST …/:id` {decision} | only the person's own words may start one | ◐ — **nothing proposes actions yet** |

### 3.5 Outputs

| Capability | Where | Shape | App | On |
|---|---|---|---|---|
| **Weekly episode** | agent `POST /podcasts/generate`; cron Sun 06:00 UTC | title, description, mood, duration, **audioUrl**, script, summary, **outline = the plan** (items with kind, register, evidence; spine; the one question/hypothesis; withheld; silent areas) | ✓ list/get via backend | `ENABLE_AGENT_CRONS` |
| **Daily brief** (written in sections: what you sent · today (your calendar) · a saved link it resurfaced · what moved) | agent `GET /briefs/:userId/latest`, `POST /briefs/generate`, `PUT /briefs/:userId/enabled`; cron 08:00 UTC | kind brief\|quiet, **through_line (the spoken text)**, spine question and movement, items [{text, why, quote (verified), source}] | ◐ | `ENABLE_DAILY_BRIEF`; per person off |
| Daily brief **audio** | none: "text first; audio later" (migration 128) | | ✗ | — |
| Episode feedback | agent `POST/GET /feedback/episodes/:id` {text, rating} | | ◐ |
| Personalised notification copy (morning and evening variants about your week) | agent `POST /notifications/generate` | | ◐ |
| Voice (ElevenLabs) | backend `POST /speech/synthesize` {text} → whole MP3, one voice, chunked server-side | | ✓ (no streaming) |
| The three "hosts" (thoughtful friend, wise mentor, energetic host) | agent `services/elevenlabs.ts` and backend `voice-personas.ts`: **all use the same voice id**, differing only in stability and style | | ✓ `/profile/persona` (the picker barely changes the sound) |
| Spending ceiling | $15 per person per rolling 24 h (`USER_DAILY_SPEND_CAP_USD`) | episodes refused above it; reading never | — |

### 3.6 Goals

| Capability | Where | App |
|---|---|---|
| CRUD | backend `/goals` (list, create, update, decline, extract-and-save, synthesize) | ✓ (but the app overwrites the server's list: G1) |
| Lifecycle: merged (near-duplicates), expired (90 days unmentioned), revived | agent `goals/lifecycle.ts` daily; backend respects merged/expired (#19) | ✓ `GET /goals` returns every column (status, status_reason, merged_into, status_at); today's app decodes only `isActive` |
| Goals stated in onboarding | agent `POST /onboarding/goals` {answersText} | ◐ |
| Said vs did | 3.3 | ✗ |

### 3.7 Saved links (the reference bank)

| Capability | Where | App |
|---|---|---|
| Any link in anything you send becomes a saved item, with your surrounding words as its reason | agent `reference/capture.ts` (daily) | ✓ indirectly (send a link via `/content`) |
| Enrich (title, page text, long pages, tweets), relate to goals, find by meaning | agent `reference/{enrich,relevance,embed}` | via search ◐ |
| Resurface a saved link in the daily brief when it bears on today | brief planner (`resurface`) | via brief ◐ |
| Share sheet into the app | none | ✗ |

### 3.8 Onboarding

| Capability | Where | App | On |
|---|---|---|---|
| Stage: reading → understanding → making_episode → ready | agent `GET /onboarding/readiness/:userId` | ◐ | pipeline **off** (`ENABLE_ONBOARDING_PIPELINE`) |
| Advance now | agent `POST /onboarding/advance` | ◐ | |
| First pass at the 36 questions (~$0.72) | agent `questions/run-first-pass` | — | |
| "Magic moments" from onboarding + sources, seeded as tracked hypotheses | agent `POST /onboarding/interpret` | ◐ | |
| Onboarding answers as context | backend profile context upload | ✓ | |

### 3.9 Switches that change what the person experiences

**`EPISODE_PLANNER=v2` / `EPISODE_PLANNER_V2_USERS`** (the new episode planner: stored plan, "why this is here", the one question; otherwise the older Cook A/B/C pipeline runs, with a different outline) · **`DAILY_PLANNER=v2` / `DAILY_PLANNER_V2_USERS`** (the new brief: what you sent first, today, a resurfaced link, what moved) · `INTEGRATION_SYNC_INTERVAL_MINUTES` (360: sources sync every 6 h) · `ENABLE_AGENT_CRONS` (daily reading, weekly episode) · `ENABLE_DAILY_BRIEF` + per-person `daily_brief_enabled` (default off) · `ENABLE_MATERIAL_ARRIVALS` (read within minutes, not daily) · `ENABLE_ONBOARDING_PIPELINE` (first episode inside onboarding) · `ENABLE_QUESTION_RESEARCH` · `ENABLE_INTEGRATION_RUNTIME` (connectors sync) · `ENABLE_APPETITE` · `ENABLE_LEARNING` · `ENABLE_RECORD_PATTERNS` · hypothesis dial `speak` (default false) · ambient master switch · `SUPADATA_API_KEY` (video transcripts) · `USER_DAILY_SPEND_CAP_USD` (15).

### 3.10 Not for the app (internal, legacy or admin), listed so nothing is missed

- **Agent, internal only:** `/health` (+ `/ready`, `/metrics`), `/runs` (traces, users, compare), `/ingest/{run,social-research,backfill}`, `/cook0/run`, `/integrations/{process,queue-import,test,credentials}`. Operations and the pipeline canvas use these; the app never should.
- **Backend legacy:** `/pipeline/*` (observations, insights: the old model the brain replaced), `/claude/generate` (the general prompt proxy the refresh removes: X1), `/admin`, `/graph/*` (old assertion and entity-resolution feedback; replaced by `/corrections` and `/people/held`).

### 3.11 Reusable from today's iOS app

| Piece | Where | Use in the refresh |
|---|---|---|
| Playback Live Activity | `Models/AudioPlaybackAttributes.swift`, `Views/AudioPlaybackLiveActivity.swift`, `RetrospectWidgets/RetrospectWidgetsLiveActivity.swift` | X2 now playing (add lock-screen and Control Center controls: `MPNowPlayingInfoCenter`, `MPRemoteCommandCenter`, unused today) |
| Recording Live Activity + App Intents (start/stop voice recording) | `Models/VoiceRecordingActivity.swift`, `AppIntents/` | J1 capture from the lock screen and Siri |
| Widgets + a Control | `RetrospectWidgets/` | X4 |
| Screen Time report extension | `ScreenTimeReport/` | N6/T3 Screen Time source |
| Health, calendar, contacts and other device readers | `Services/HealthKitManager.swift`, `NativeSourcesManager.swift`, `ScreenTimeService.swift`, `IntegrationsSyncService.swift` | N6 Connect, background reading |
| On-device transcription | `SpeechRecognizerManager.swift`, `Services/TranscriptionService.swift` | voice in (N4, J1); keep the confidence it throws away |
| Apple sign-in, API client, Keychain | `Services/RetrospectAPIClient.swift` | N3; the client grows the Part 7 routes |
| Background audio permission | `Info.plist` `UIBackgroundModes: audio, fetch` | already on |
| The paywall's motion and look | `Views/PodcastPaywallFlow.swift` (the 1.22 s reveal) | N12, the visual language; rebuilt to fit any phone |
| Not reused | ~57 unreachable screens, the legacy home, dev tools, `ClaudeService` prompt proxy, `OpenAIservice`, the second Xcode project | removed |

## 4. Gaps between the backend and a refreshed app

Numbered **K** (kept separate from audit findings). Each is resolved in Part 8.

| # | Gap | Effect if not fixed |
|---|---|---|
| K1 | **Most capabilities are agent-only.** The backend has no routes for conversation, search, briefs, corrections, people, hypotheses, actions, settings, preferences, readiness, feedback | Journal can't reply, You can't search, no brief card, no onboarding stages |
| K2 | **No route returns the read contract, said-vs-did or the map** (entities + facts sized by evidence) | You and Goals can't show the brain's picture |
| K3 | **The daily brief has no audio** | the founder's "play card that keeps playing" can't exist |
| K4 | **No timezone stored**; brief at 08:00 UTC, episode Sun 06:00 UTC | a California user gets the "morning" brief at 1 am |
| K5 | **Speech isn't streamed** (whole MP3 per request) | voice onboarding and spoken replies would pause for seconds before every turn |
| K6 | **Nothing proposes actions** | no "want me to draft that?" until a proposer exists |
| K7 | **Delete exists but isn't used and doesn't retract; edit doesn't exist.** `DELETE /content/:id` removes the entry, not the facts and answers drawn from it (the correction path that retracts them exists); the app never calls it; there's no edit | deletes don't delete (Y12), edits don't reach the brain (J3) |
| K8 | **`/content` has no idempotency key**; the app has no outbox | lost or duplicated entries (J1, J4) |
| K9 | **No share extension** and no route that saves a link with an explicit reason | goal 23's "hand it a link with a reason" only works by pasting into Journal |
| K10 | **No push delivery** (APNs) for brief ready / episode ready / a question waiting | proactive means nothing if nothing arrives |
| K11 | **No chapter timings** for episodes (the plan is stored; timestamps aren't) | "why this is here" can be shown per part, but not jumped to |
| K12 | **One first episode per person isn't enforced** | two paid episodes per sign-up (A7) |
| K13 | **No StoreKit products or receipt validation** | the paywall can't take money (L4) |
| K14 | **Consumption preference (audio / text / both) isn't stored** | the spec requires onboarding itself to respect it |
| K15 | **Only Apple Health and Google Docs can be connected today**; the rest are in development or awaiting approval | Connect (N6) must recommend what works, and say plainly what's coming |
| K16 | **What each source helps it understand isn't in the backend catalog** (the agent has full profiles) | N6's "Calendar → the shape of your weeks" copy has no source of truth in the app |
| K17 | **The three hosts are one voice** with different settings | a host picker that barely changes the sound; replaced by voice creation (P1) |
| K19 | **The backend's content types don't include link, shared link, note or conversation**, though the brief treats them as things you sent | the share extension and notes can't be sent as what they are |
| K20 | **The "how bold" first guess only runs in the daily job**, and needs 3+ things you wrote (over 20 characters each) | N9 has no guess minutes into onboarding unless the seed runs on demand from the saved answers |
| K21 | **Magic moments (titled observations from onboarding + sources) are built and never called** | the tease's opening line has a ready source, asked as a question (no pattern claims on day one) |
| K22 | **The refresh assumes the v2 planners**; v1 is the default unless the switches are set | P2's "why this is here" and the episode question, and J2's brief sections, exist only under v2; the app must handle v1 outlines until both are on for everyone |
| K18 | **Social research (your public profiles) isn't reachable** | cold start misses an input the spec names; an optional onboarding question ("Want me to read your public profiles?") needs a route |

---

# Part E. The new app's rules

## 5. Design principles for the refresh

1. **Ambient first.** Every tab opens on something already made for you. The empty box is never the first thing you see.
2. **One feature per page**, shown off fully; the bar names the features; guidance teaches each one on first visit.
3. **Evidence → question → your answer.** Hard things are delivered as evidence plus a question, never a verdict.
4. **Stated vs asked, visibly.** Facts look like facts; guesses carry how sure and why, and are phrased as questions.
5. **Voice-first, never voice-only.** Talk or type everywhere; it talks back; it works with the sound off; it respects a stated preference for reading.
6. **Nothing lost, nothing hidden.** Every capture shows saved → sent → read; every failure says what happened and what's next.
7. **Least taken, most given.** Every question has a visible use; nothing is asked that a source will tell it.
8. **The server owns the brain.** The app sends intents; it never overwrites.
9. **Accessible and any-size by default.** Dynamic Type, VoiceOver, 44 pt targets, reduced motion, light and dark, from the SE up.
10. **Visual language:** the paywall moment (the insight plays, the buttons rise, 1.22 s); Hedvig serif with restraint; mono labels; beige + sky blue with the beige calibrated down (one hue, low even chroma); grain and rim only for special moments; dots never over text.

## The 14 constraints (acceptance criteria)

1. Every failure after a wait is named in plain words, with a retry or a promise; no silent failure paths.
2. Nothing written is ever lost: queued, retried, visible state, edits re-sent, one upload per capture.
3. The server owns the brain's data (goals, and likewise answers, patterns and people); the app sends intents, never overwrites.
4. A release build has no dev tools, mock paths or previews; team tools are gated by a server-side role.
5. No canned personal content in ship; demo content only in the labelled demo account.
6. Every button says exactly what happens next (M1).
7. No progress number that isn't real; waits over 3 s name their stage; long work starts early and survives closing (M2).
8. Every onboarding question has a stated use; nothing sensitive without a visible reason; at most 5 sources up front; end on the strongest moment (M3).
9. One card per account; each source says what it helps it understand; plain states; no file imports in onboarding (M4).
10. The standard Sign in with Apple button (M5).
11. Every privacy statement is true and specific; a privacy step that names what's read, where, and how to stop it (M6).
12. Every onboarding step can go back; every answer is saved immediately (M7).
13. No raw errors; no prompts from the app (M8).
14. Every brain capability visible, with confidence and why, and correctable (M9).

## 9. Conflicts reconciled

| Conflict | Resolution |
|---|---|
| Voice-first onboarding vs the spec's "if they prefer reading, don't speak at them" | N1 asks "talk or read?" (talk preselected); reading mode shows the same words, no audio; switchable anytime |
| The brief card on Journal vs the brief being off by default | N13 offers it; Journal shows the card only when on; when off, Journal shows a one-time "want a short brief each morning?" |
| "Nothing about you unless from your data" vs predictions | Inferences are welcome; shown as guesses (asked, with how sure and why); only ungrounded content is banned |
| One feature per page vs corrections, people questions and hypotheses appearing in several places | Each has one home (You), and appears elsewhere only where the claim it's about is shown (a reply, an episode line); never as a menu of features |
| Founder's "approve moving your 10am" sketch vs nothing proposing actions | Journal's design holds the slot; it stays empty until phase F |
| Daily brief "9am" vs a UTC cron | Local time, the person's choice (default 8:30), after K4 |
| Hypothesis dial off vs "what it's wondering" on You | Shown only when the dial allows and appetite ≥ 2; otherwise the node layer is simply absent |
| Patterns too new to judge vs showing trajectories | "Too early to tell" is a real, designed state until ~8 weeks of a source |

## 10. Coverage checks

### Every goal has a home

| Goal | Where in the refreshed app |
|---|---|
| 1 Data sources · 2 Ingestion | Connect (onboarding), Settings → Sources; saved → sent → read on every entry |
| 3 Making meaning | Journal ("what I took from this"), You |
| 4 Connections | You (people, "same person?") |
| 5 Linting | invisible: flagged claims never shown |
| 6 Search | You (search with receipts, "only what's certain") |
| 7 Reported goals · 8 Real goals | Goals (lifecycle, said vs did) |
| 9 Communication style · 22 Calibration | how bold (onboarding, settings); the voice; replies |
| 10 Current state | You → What I know about you (silent areas said warmly) |
| 11 Relevance | brief items with "why"; resurfaced saved links |
| 12 Impediments · 25 Pattern change | episodes (evidence → question); clusters with trajectory on You |
| 13–16 Outline, story, voice, delivery | Podcasts, the player, background playback, the brief card |
| 17 Acting | Journal's approval slot (phase F) |
| 18 Conversation | Journal thread |
| 19 Learns from itself | Settings → What it's learned |
| 20 Correction sticks | "that's not right" everywhere; corrections in plain words |
| 21 Hypothesis | the episode's one question; You's waiting nodes |
| 23 Reference bank | Share to Retrospect; saved links as nodes; resurfaced in the brief |
| 24 Cold start | N10–N11, honest about thinness |

### Every problem theme has a fix

| Audit theme (blockers in bold) | Fixed by |
|---|---|
| **No way out of the paywall · placeholder prices** | N12 (K13) |
| **Episodes unplayable after onboarding** | O-24 streaming/download; background playback |
| **Canned "Learning about you" claims** | N10 real stages + their own words |
| **Silent first-episode failure · lost uploads · deletes that don't delete** | N10 failure states; J1/J3/J4 outbox + K7/K8 |
| **Goal list overrides the brain** | G1 sends intents only |
| **Dev tools and fake home in the shipped app** | T1–T9: production settings, nothing for developers |
| Two first episodes | K12 |
| Demographics, orientation, dream house; long; no Back; lost answers | N4, N8; save per answer; Back everywhere |
| 17 sources, engineering labels, three Google cards | N6, N7 |
| Every episode "Weekly Insights"; no titles; no player exit | P1, P2 |
| Failing server looks like a working one; vanishing episodes | states on every tab |
| Ignores text size, VoiceOver, dark mode; fixed-size paywall | principle 9 |
| Half-written entries auto-sent; no confirmation; nowhere to see your entries | J1 composer keeps drafts; saved → sent → read; J3 All entries |
| Taps lag; 60 fps timers; blur | step 4 build rules + phone check |

### Onboarding: failure paths and cost

**Failure paths (every one named):** the episode isn't ready in time → "It's taking longer; I'll tell you when it's ready" + notification, onboarding still completes; generation fails → plain words, answers kept, retry or "tonight"; no sources connected → it still makes something true from the answers alone (goal 24 "degrade cleanly"); offline → answers queue and send later.

**What it costs per sign-up:** one first-pass read (~$0.72) + one first episode (~$1.90) + voice prompts (pre-recorded mission and callbacks: ~$0; per-person acknowledgements: a few cents). Target: under $3, from today's ~$5–7.

---

# Part F. Building it

## 7. The data contract the app needs (backend routes)

All behind the person's sign-in; the backend fills in `userId` and forwards to the agent with the internal secret. Shapes are the agent's, already built, unless marked ✗ new.

| Backend route (new) | → agent | Used by |
|---|---|---|
| `POST /conversation` · `GET /conversation/today` | conversation | Journal |
| `POST /corrections` · `POST /corrections/confirm` | corrections | everywhere |
| `GET /briefs/latest` · `PUT /briefs/enabled` · `GET /briefs/:id/audio` ✗ | briefs (+ ✗ brief TTS) | Journal, Podcasts, onboarding, settings |
| `POST /search/sources` · `POST /search/answer` · `GET /search/source/:kind/:id` | search | You |
| `GET /understanding` ✗ (read contract) | understanding/read | You, Goals |
| `GET /understanding/map` ✗ (entities + facts + evidence counts + held/hypothesis flags) | ✗ new read | You |
| `GET /goals/said-vs-did` ✗ · lifecycle fields on `/goals` | understanding/said-vs-did | Goals |
| `GET /people/held` · `POST /people/held/:id` | people | You, Journal |
| `POST /hypotheses/:id` · `GET /hypotheses/:id/why` | hypotheses | Podcasts, You |
| `GET /actions` · `POST /actions/:id` | actions | Journal |
| `GET/PUT /settings/ambient` · `GET/PUT /settings/appetite` · `GET /settings/learning` · `GET/PUT /preferences` | settings, preferences | onboarding, settings |
| `GET /onboarding/readiness` · `POST /onboarding/advance` · `POST /onboarding/goals` | onboarding | onboarding |
| `POST /feedback/episodes/:id` | feedback | player |
| `PATCH /content/:id` ✗ · `DELETE /content/:id` ✓ exists (✗ make it retract what was drawn, via corrections) · idempotency key on `POST /content` ✗ | (+ agent re-read / retract) | entries |
| source descriptions on `GET /integrations` ✗ (from the agent's source profiles) | source-intelligence | N6, N7, T3 |
| `POST /profile/public-handles` ✗ → social research | social-research | N7 |
| `POST /saved` ✗ {url, reason, goalId?} | reference capture | share extension |
| `POST /speech/stream` ✗ (streamed TTS) | ElevenLabs | onboarding, conversation |
| `PUT /profile/timezone` ✗, `PUT /profile/consumption` ✗ | users | all schedules |
| `POST /devices/apns` ✗ | push | notifications |
| `POST /subscriptions/verify` ✗ | StoreKit | paywall |

## 8. What to build, in order

Each phase ends with something the founder can use. Phases A–C are server work the app depends on and can start before the mid-fi is approved.

| Phase | Build | Unblocks | Size |
|---|---|---|---|
| **A. Pass-through** | the backend routes in Part 7 that forward to existing agent routes (conversation, corrections, briefs, search, people, hypotheses, actions, settings, preferences, onboarding, feedback) | everything | medium: many small routes |
| **B. New reads** | `/understanding`, `/understanding/map`, `/goals/said-vs-did` | You, Goals | medium |
| **C. Outputs and timing** | brief audio (TTS of `through_line` + items, stored like episode audio); timezone (first guess from `usualOffset`, confirmed in N13) + local scheduling for brief and episode; one first episode per person; streamed TTS | the brief card, voice onboarding | medium |
| **D. Capture integrity** | idempotency key; entry edit; delete that retracts; save-link route; source descriptions in the catalog; public-handles route | Journal, share, Connect | small–medium |
| **E. Delivery** | APNs; StoreKit + receipt verification | notifications, paywall | medium |
| **F. Proposing actions** | a proposer (from conversation, own words only) feeding the existing ledger | "want me to draft that?" | medium; last (goal 17 is last) |
| **G. The app** | per [ios-refresh-plan.md](./ios-refresh-plan.md) steps 3–6: structure → mid-fi → review → tokens and components | — | large |

**Sources, in parallel (outside these phases):** the in-development device sources (Calendar, Contacts, Screen Time, Music, Photos) and the approvals (Google verification for Gmail; platform approval for TikTok, X, LinkedIn). Connect only offers what works.

**Switches to flip as each phase lands:** `ENABLE_ONBOARDING_PIPELINE` (with A + C), `ENABLE_MATERIAL_ARRIVALS` (with A: "read within minutes"), `ENABLE_DAILY_BRIEF` (with C), `ENABLE_APPETITE` (with A), hypothesis dial `speak` (when the founder has heard it), `SUPADATA_API_KEY` (saved-video transcripts), `ENABLE_INTEGRATION_RUNTIME` (connectors).

## 11. Recommended defaults (used unless the founder changes them)

Nothing here blocks the work; each has a default the build follows.

| # | Decision | Default |
|---|---|---|
| 1 | The mission script (N2) | The draft in N2, recorded once in the app voice; the founder edits the words before recording |
| 2 | Brief and episode times | Brief 8:30 local (person can change it in N13 and T2); episode Sunday 9:00 local |
| 3 | Talk or read | Ask first (N1), "Talk" preselected |
| 4 | Paywall benefits | The six in N12, each with an example from their own data where one exists |
| 5 | Hypothesis dial | Off until the founder has heard three offered in his own episodes, then on for appetite ≥ 2 |
| 6 | Server order | A → B → C → D → E → F (pass-through first, actions last) |
| 7 | First sources offered | Apple Health and Google; others appear as they ship |
| 8 | Public profiles (social research) | Optional in N7, off unless the person adds a handle |

---

# Part G. The process

## The shape the founder wants (keep this in mind at every step)

**The interaction paradigm stays simple: one feature per page.** A navigation bar at the bottom; each page is dedicated to one feature and shows that feature off fully (founder, 20 Oct, correcting an earlier draft that put every feature on every page). A page doesn't advertise or carry the other features; you reach those through the bar. Nothing powerful is hidden three levels down: every major feature has a page of its own, reachable in one tap.

What this means in practice:
- **Each page has one job,** and everything on it serves that job (search is the Search page; talking to it lives on the page whose feature it is).
- **No cross-feature clutter:** no global search field, chat button or feature menu repeated on every page.
- **Discovery comes from the bar and the guidance,** not from every page listing everything: the bottom bar names the features, and the in-app guidance points a new person to the next one to try.
- **The bar (founder, 20 Oct): Journal · Podcasts · Goals · You.**
  - **Journal:** write or talk, and it replies; journal and chat are one page. **The daily brief is the day's episode: a card at the top you press play on; it briefs you, and keeps playing when you close the app** (founder, 20 Oct).
  - **Podcasts:** listen; why each part is there; past episodes.
  - **Goals:** the brain's view of your goals; said vs did.
  - **You = search + your brain, as a map (founder, 20 Oct).** The page is a visualization of the brain as **nodes and edges**: people, places, projects, goals and themes as nodes, **sized by how much they show up** in your life; edges are the facts linking them, each from your own words. A search field sits on it: searching **highlights and zooms to** the matching part of the map, with the written answer and its sources below. Tap a node for its receipts: the quotes behind it, how sure the brain is, "that's not me" / "still true". Patterns show as clusters growing or fading; "is this the same person?" and "what it's wondering" appear as nodes waiting for your answer. Saved links are nodes too, tied to the goals they bear on. Profile and settings sit behind your picture at the top.
  - To work out in steps 3–5: how the map stays readable as it grows (zoom levels, only the strongest nodes at first), how it reads to someone with a week of data versus a year, the empty state on day one, the 36 answers' place on the map (as regions?), performance on older phones, and VoiceOver (a list view of the same data).
  - Prerequisite (from the earlier constellation idea): people must be matched cleanly, or the map shows the same person twice. The graph is read-only from what the brain already stores; no new storage.

**Onboarding, in this order:**
1. **Questions** (the onboarding keeps its character: it asks good questions and understands you).
2. **Privacy**, shown off.
3. **Integrations** (connect your sources).
4. **More questions.**
5. **Tease the podcast**: the first episode starts playing.
6. **The paywall**: it rises out of the podcast. It's **scrollable**: the podcast slides up, and below it **every benefit of subscribing is laid out**, so the person sees all the features they get when they buy.
7. **Into the main app.**
8. **They play around from there.**

**Voice onboarding: a conversation, not a form (founder, 20 Oct).** The person can answer every onboarding question by talking, for as long as they like, and the app **talks back**: it asks each question aloud, reacts to what was said, and follows up, so onboarding is a conversation they have with the app. Requirements:
- **Voice in:** speak any answer (typing stays available); live transcription on screen.
- **Voice out:** the app speaks its questions and replies in a natural voice from **ElevenLabs** (already proxied through the backend, NPRdoinglaundry `e1f16b9`), so no keys sit in the app.
- **Haptics** mark the turns: when it starts listening, when it's heard you, when it's speaking.
- **On screen, for now:** the words as text, as today. **Later:** something more visual (a living shape or waveform that reacts to both voices); designed in step 6, not before.
- **Interruptible:** the person can cut in, skip ahead, or switch to typing at any moment; silence never fails a step.
- **The same conversation continues in the app:** the app's conversation page uses the same voice, so onboarding is the first conversation, not a separate mode.
- **Cost and latency** are measured in step 3 (voice per onboarding, time to first spoken word) and recorded in [cost-per-user.md](./cost-per-user.md).

This applies to steps 2–6: it's an opportunity in step 2, a flow in step 3, built in the mid-fi in step 4, reviewed in step 5, and given its visual treatment in step 6.

**The mission, told by voice in onboarding (founder, 20 Oct).** Onboarding opens by *telling* the person what Retrospect is for, in the app's own voice, before it asks anything: why it exists, what it will do with what they share, and what they get back. To think through deeply in step 3, not just script:
- **Where it sits:** at the very start (before the first question, so trust comes before asking), with short callbacks at the moments that need it: before privacy ("here's why I ask"), before integrations ("here's what these let me understand"), and before the paywall ("here's what you've just heard is for").
- **What it says:** the mission in the person's terms, not the product's: a brain that comes to know you and gives it back as something worth listening to. Short (under 30 s for the opening), spoken warmly, never a pitch; every claim true today (no promise the product can't keep, unlike the current "with me, anything is possible").
- **How it's carried:** the ElevenLabs voice, the words appearing on screen as they're spoken, haptics on the key line; skippable and replayable; works muted (text alone carries it).
- **How we judge it:** does a new person, after the opening, know what this is for and want to answer the first question? Tested by listening, in step 5.

**Inside the app, guidance.** Once they're in, the app shows them how to go further, so they always know what's going on and what to try next.

**The goal of every design choice:** the least taken from the person and the fewest questions asked, for the most output and value given back.

**The goals the structure must serve:** understand the person; understand their goals; give them content that makes their life better. And get the specifics right: how journals are stored, how you message the app, the share sheet, search and what an insight looks like when you search (and how you deep-dive for more), settings, and everything else.

---

## The order of work

Each step finishes, is checked, and is shown to the founder before the next starts. **Tokens are applied only after the structure has passed its review (step 5).**

| # | Step | What it produces | Done when | Founder |
|---|---|---|---|---|
| 1 | Deep audit of the current app | every problem, on a running build | every screen, control, state, size and gesture checked | reads it |
| 2 | Opportunity audit and spec | every place new functionality can enter, with lo-fi mockups of every screen | every capability has a home and a sketch | yes/no per opportunity |
| 3 | Best solution for every screen and flow | the new structure, written screen by screen | every problem closed, every opportunity used, least take and most value | approves the structure |
| 4 | The new screen set, mid-fi | every screen and flow of the new app, at mid fidelity | it reflects every change and every new capability | looks through it |
| 5 | Structure review | a written pass asking "is this the best structure, and why or why not" for every screen | each screen passes the goals and fits the interaction style | agrees |
| 6 | Tokens, then components | a sophisticated token set with Lime's breadth, applied page by page and component by component | spacing, hierarchy, interaction and flow are all handled | does the high-craft polish |

---

## Step 1: Deep audit of the current app (in progress)

**Purpose:** find every problem: where the app is incoherent or hard to use, interactions that break, odd pixels, confusing onboarding screens, sections that don't make sense, frame rates that drop, gestures that don't work.

**How:** a debug build on the simulator, pointed at a local stand-in server that serves a labelled sample week and can be switched to empty, error and slow modes. Nothing reaches Retrospect's servers; no spend.

**Checklist, per screen (all 32):**
- every control tapped; every gesture tried (swipe back, swipe down, long-press, scroll, drag);
- every state: first time, filled, empty, loading, error, slow, offline;
- closing the app mid-step and reopening; going back from every step;
- sizes: iPhone SE and 17 Pro Max; the largest text size; dark mode;
- pixels against the tokens: spacing, type, alignment, contrast, overlap, safe areas;
- frame rate: what redraws every frame or blocks the main thread (from code), and visible stutter (on a phone recording);
- clarity: before reading a word, can you tell what this is for and what to do next?

**Output:** [app-audit-deep.md](./app-audit-deep.md), merged into the ranked list in [app-audit.md](./app-audit.md) and onto the board.

**Limits:** real frame rate, haptics, the recorder, Health, Screen Time, notifications and widgets need a phone; one screen recording covers them.

---

## Step 2: Opportunity audit and spec

**Purpose:** list every opportunity to bring new functionality into the product, within the simple paradigm (bottom navigation bar, one feature per page).

**Inputs:** everything the brain can now do (from the goal spec and [ios-v2-opportunities.md](./ios-v2-opportunities.md)):
- the conversation (chat with it; replies may be silent);
- search across the whole mind, with sources and a written answer, and deep-dives;
- the daily brief and the weekly episode, each saying why each item is there;
- what it knows about you, with how sure it is and why; corrections anywhere;
- goals as the brain sees them (active, expired, merged; said vs did);
- patterns; people ("same person?"); hypotheses ("what it's wondering");
- how bold it is with you; what it has learned about how you like things;
- saved links with your reason (share sheet), and transcripts for videos;
- actions it prepares for your approval;
- sources: what each one read, when, and what it's for; the ambient switch; privacy and deletion.

**For each opportunity, the spec records:**
- what it is, in one line;
- where it can live (which tab, which screen, which moment in onboarding);
- **which page owns it:** a page of its own in the bar, or a part of another feature's page (and why it belongs there);
- what the person gives and what they get back;
- the server route behind it (built, or still to build);
- the audit problems it also fixes;
- **a very lo-fi mockup** of every screen it touches: boxes and labels only, enough to judge placement and flow.

**Note on the stage-2 draft:** [ios-v2-opportunities.md](./ios-v2-opportunities.md) puts several features on Home (capture, today's brief, talking to it, things waiting on you) and many on You. Under one feature per page, that draft is reworked here: each of those is placed on the page that owns it.

**Output:** `ios-refresh-opportunities.md` (replacing the stage-2 draft) plus the lo-fi mockups on the board, one per screen, side by side with today's screen.

**Done when:** every capability has at least one home and a sketch, and the founder has said yes or no to each.

---

## Step 3: The best solution for every screen, pixel and flow

**Purpose:** given every problem (step 1) and every opportunity (step 2), decide the best solution for each screen and flow. The test: **the least taken from the person, the fewest questions, the most value back.**

**It works to the founder's shape** (above): onboarding as questions → privacy → integrations → more questions → podcast tease → scrollable paywall with every benefit → into the app → play around, with guidance inside the app.

**For each screen it writes:**
- its job in one sentence, and what the person should feel;
- what's on it, in order of importance (the hierarchy);
- every action, and what each one does (exact labels);
- every state: first time, filled, empty, loading, error, offline;
- the one feature it shows off, and how it shows it off fully;
- how a person gets to it (which tab, and from where inside the app);
- the guidance it gives a new person (what to try next);
- the problems it closes (by audit number) and the opportunities it uses;
- what it asks of the person, and why that's the least it can ask.

**For each flow:** onboarding end to end; a normal day; the weekly episode; searching and deep-diving into an insight; correcting something; sharing a link in from another app; messaging the app; connecting or fixing a source; privacy and deletion; subscribing, restoring and lapsing; every failure path.

**Output:** `ios-refresh-structure.md`. The founder approves the structure before mid-fi starts.

---

## Step 4: The new screen set, mid-fi

**Purpose:** a mid-fidelity version of the new iOS app: every screen and every flow, reflecting every change and every new capability from steps 2 and 3.

**Recommendation (founder to confirm):** build the mid-fi as **real SwiftUI screens in the new app project**, running on the simulator against the stand-in server's sample data, so the founder can tap through every flow on a phone-sized screen. Mid-fi means real layout, real content and real interactions, in plain greys, without the final visual craft. The alternative is clickable HTML screens on the board: faster to make, but they don't carry over into the app.

**Includes:**
- onboarding with the scrollable podcast-and-benefits paywall;
- the four-tab app (Home, Podcasts, Search, You; settings behind the profile), each page dedicated to one feature;
- in-app guidance for a new person;
- every state from step 3 (empty, error, loading, offline), not only the happy path.

**Output:** the mid-fi app, plus screenshots of every screen and state on the board.

---

## Step 5: Structure review (before any tokens)

**Purpose:** a deliberate second look. For every screen and flow, ask: **is this the best structure, and why or why not?** Judged against:
- **Understanding the person:** does this screen help the brain learn, or show what it has learned?
- **Understanding their goals:** are goals visible, honest (said vs did), and easy to correct?
- **Content that makes life better:** is what it gives back worth the person's time?
- **The specifics:**
  - journals: how they're stored, and that nothing is ever lost;
  - messaging the app: how a conversation feels, and where it lives;
  - the share sheet: saving from anywhere, with a reason;
  - search: what an insight looks like in a result, how you deep-dive for more, and how sources are shown;
  - settings: what's there, and that every setting is real;
  - everything else in the goal spec.
- **The interaction style:** bottom bar; one feature per page, shown off fully; nothing important more than one tap from the bar; least take, most value.

**Output:** a review section in `ios-refresh-structure.md`, every screen marked keep, change or rethink, with the reason; changes made in the mid-fi before step 6.

---

## Step 6: Tokens, then components

**Starts only when step 5 is done.**

**6a. A sophisticated token set.** Inspired by the breadth of the Lime design system the founder shared: tokens that span as many visual details as possible, not only colour and type. Built on the decisions already made ([design-system-plan.md](../design/design-system-plan.md)):
- Hedvig serif used with restraint; mono for all labels;
- one accent, a sky blue; grain and rim only for special moments;
- light and dark together, light first; iOS only;
- tokens lead, named by purpose.

Coverage, at least: colour (surfaces, text, borders, states, the accent and its washes) · type scale and roles · spacing scale and layout rhythm · radii · borders and hairlines · elevation and shadow · blur and materials · grain and rim · opacity · iconography sizes · motion (durations, curves, the 1.22 s reveal) · haptics · touch targets · focus and pressed states · Dynamic Type steps · safe areas and edge padding. Starting point: the v1 set ([design-system/tokens](../../design-system/tokens/README.md), 272 tokens).

**Colour direction: beige + blue, with the beige calibrated down (founder, 20 Oct).** The design system stays two colours, a beige ground and the sky-blue accent, but the beige is turned down a little and made consistent. Today's paper and cream values drift between hues 68° and 106° and reach a chroma of 0.020 (OKLCH) on the cream ring, which reads yellow next to the blue. In step 6: one beige hue for all neutrals, chroma held low and even (surfaces ≈ 0.003–0.006, borders and rings ≈ 0.008–0.010), stepped in lightness only, and checked side by side with the sky blue in light and dark. This replaces the warm-paper values in v1 of the tokens.

**6b. Components, page by page.** Apply the tokens systematically, component by component, to the mid-fi app, so that **spacing, hierarchy, interaction and flow are all addressed**. The components should look good and follow the design system closely enough that **all that's left for the founder is the high-craft polish pass.**

**Output:** the token set (validated), the component inventory with every state in light and dark, and the mid-fi app re-skinned with them.

**Then the founder** does the high-craft pass.

---

## Rules that hold at every step

- Every claim about the current app is backed by a screenshot, a server log line or a code line.
- Every claim about a person rests on their own data. Predictions and inferences are welcome, and they're shown as what they are: a guess comes with how sure it is and what it rests on, and a weak guess is asked as a question, never stated. What's banned is content not grounded in their data at all (canned lines, made-up episodes). Demo content lives only in the demo account.
- No developer tools in the shipped app.
- The server owns what the brain knows; the app sends intents and never overwrites.
- Nothing written is ever lost, and you can always see that it arrived.
- Every wait names what it's doing; every failure says what happened and what's next.
- Each step ends with something the founder can look at (the board), and waits for their yes before the next.

---

# Part H. Opportunities: every place new functionality enters

## 1.1 What the brain can do, and what the app shows of it today

| Capability (built in the brain) | In the app today | Reachable by the app today? |
|---|---|---|
| Capture: entries by text and voice | Journal (sends once, no outbox, no confirmation) | yes (`/content`) |
| Weekly episode, with its outline and why each part is there | Podcasts list, all titled "Weekly Insights", unplayable after onboarding | partly (`/podcasts`; outline unused) |
| **Daily brief** about what changed | nothing | **no** (agent only) |
| **Conversation**: talk to it; replies may be silent | nothing | **no** (agent only) |
| **Search** across everything, sources then a written answer | nothing | **no** (agent only) |
| **What it knows about you**: 36 answers, how sure, the quotes behind them | nothing | **no** (no endpoint anywhere yet) |
| **Corrections**: "that's not me", "still true", changed vs wrong | two backend buttons on old graph routes | partly (`/graph/.../feedback`; the new `/corrections` is agent only) |
| **Goals** as the brain sees them: active, expired, merged; said vs did | Goals shows the phone's list, which overrides the brain | partly (`/goals` exists; the brain's view and said-vs-did don't) |
| **Patterns**: what keeps happening, stronger or weaker | nothing | **no** |
| **People**: who's in your life; "is this the same person?" | nothing | **no** (agent only) |
| **Hypotheses**: what it's wondering, with a framework | nothing | **no** (agent only) |
| **How bold** (appetite), with a first guess from your words | nothing | **no** (agent only) |
| **What it's learned** about how you like things | nothing | **no** (agent only) |
| **Saved links** with your reason; video transcripts | nothing (no share extension) | **no** |
| **Actions** it prepares for your approval | nothing | **no** (agent only) |
| **Sources**: what each read, when, what it's for | Integrations & Data (engineering labels) | yes (`/integrations`) |
| **Ambient switch**: read connected apps in the background, or not | nothing | **no** (agent only) |
| **First-episode readiness** (real stages) | a fake percentage | **no** (agent only) |
| Voice (ElevenLabs, proxied) | first-episode audio only | yes (`/speech/synthesize`) |

**The headline:** most of what the brain now does can't reach the app at all. The agent's routes are internal (they need the server's secret), and the backend the app talks to passes through only content, goals, podcasts, profile, speech, integrations and an old graph. **Opportunity O-0 is the foundation for everything else:** a backend route, behind the person's sign-in, for each capability the app needs (search, conversation, briefs, understanding, corrections, people, hypotheses, actions, settings, readiness, links).

## 1.2 The shape, in one picture

```
ONBOARDING (voice-first, one conversation)
  Mission (voice) → Questions → Privacy → Connect → More questions
     → First episode plays (tease) → Paywall rises, scroll for every benefit
     → Into the app → Guidance

THE APP  (one feature per page)
 ┌──────────┬──────────┬──────────┬──────────┐
 │ Journal  │ Podcasts │  Goals   │   You    │
 │ write ·  │ listen · │ yours ·  │ search · │
 │ talk ·   │ why it's │ said vs  │ the map  │
 │ brief    │ in it    │ did      │ of you   │
 └──────────┴──────────┴──────────┴──────────┘
  Outside the bar: Share to Retrospect (from any app) · notifications
  · widget and Live Activity · settings (behind your picture on You)
```

## 1.3 Where each capability lives (one owner each)

| ID | Capability | Owner page | Why there |
|---|---|---|---|
| O-1 | Capture (text and voice) | **Journal** | writing is what Journal is for |
| O-2 | Conversation | **Journal** | founder: journal and chat are one page; a reply is the natural answer to an entry |
| O-3 | **Daily brief = the day's episode** (founder, 20 Oct): an audio briefing | **a card at the top of Journal** you press play on; it also lists under Podcasts | it's the first thing of the day; it keeps playing when you close the app or lock the phone |
| O-4 | Weekly episode, outline, "why this is here" | **Podcasts** | listening |
| O-5 | Episode feedback, and the question an episode asks | **Podcasts**, under the player | answered where it was asked |
| O-6 | Goals: the brain's view, said vs did, add, rename, turn off, revive | **Goals** | its own page |
| O-7 | Search: sources first, then a written answer | **You** | founder: search and You are combined |
| O-8 | The map: people, places, projects, goals, themes, sized by presence | **You** | founder |
| O-9 | What it knows (the 36 answers, how sure, the quotes) | **You**, inside the map (regions or a layer) | it is the picture of you |
| O-10 | Corrections | wherever a claim appears; filed under **You** | a claim is fixed where you see it |
| O-11 | Patterns | **You**, as clusters on the map | they are shapes in your life |
| O-12 | People and "same person?" | **You**, as nodes waiting for an answer | people are nodes |
| O-13 | Hypotheses ("what it's wondering") | **You**, as nodes waiting for an answer; one at a time in an episode | they're guesses about you |
| O-14 | Saved links (with your reason, transcripts) | **You**, as nodes tied to goals; saved via the share sheet | they belong to what they bear on |
| O-15 | Actions it prepared | **Journal**, as a reply that asks to approve | it was asked for in conversation |
| O-16 | How bold | **onboarding** (first guess), then settings | a preference |
| O-17 | Sources, privacy, ambient, delete | **settings**, behind your picture | control, not daily use |
| O-18 | What it's learned | **settings** (transparency) | rarely visited |
| O-19 | Voice (the app talks) | onboarding, conversation, the brief | one voice everywhere |
| O-20 | Guidance for a new person | each page's first-visit state | one feature per page means each page teaches itself |

## 1.4 Opportunities that cut across pages

| ID | Opportunity | Fixes |
|---|---|---|
| O-0 | Backend routes for every capability above, behind sign-in | the gap in 1.1 |
| O-21 | **An outbox:** every capture is saved, sent, confirmed ("read by the brain"), retried, never lost; edits and deletes reach the server | J1–J3, Y4, Y5, Y12, Y29 |
| O-22 | **Plain states everywhere:** loading, empty, error, slow, offline, each named in words with a next step | A1, X3, Y28, Y30, Y51 |
| O-23 | **The server owns the brain's data**; the app sends intents | G1, Y17, Y18 |
| O-24 | **Audio that plays, and keeps playing:** stream or download every episode and brief; play continues with the app closed or the phone locked; lock-screen and Control Center controls; a now-playing Live Activity. (Background audio is already switched on in the app's settings; the lock-screen controls aren't built: 0 uses of `MPNowPlayingInfoCenter`) | N20, Y26 |
| O-25 | **One navigation model:** a bar, standard swipe-back, sheets that close by swiping down | Y11, Y14, Y27, Y35 |
| O-26 | **Accessible by default:** Dynamic Type, VoiceOver labels, 44-pt targets, reduced motion, light and dark | Y36–Y40 |
| O-27 | **Layout that fits any phone** (no fixed-picture screens) | Y41 |
| O-28 | **Nothing for developers in the shipped app**; demo content only in the demo account | T1–T6, N1, L2, L6 |
| O-29 | **Real subscriptions** (StoreKit, server-checked), a way out of the paywall, working Privacy and Terms | N19, L3, L4 |
| O-30 | **Notifications that lead somewhere real**: brief ready, episode ready, something to approve, a question waiting | A6 |
| O-31 | **Share to Retrospect** from any app, asking "why are you saving this?" | — (new) |
| O-32 | **Widget and Live Activity:** capture in one tap; now playing | — |

*The daily brief (O-3) was refined by the founder: it is the day's episode, a card you press play on that keeps playing when you close the app; it also lists under Podcasts. You and Search were combined into one tab (the map with search on top); the bar is Journal · Podcasts · Goals · You.*

## Part 3: what has to be built for this

| Layer | Work | Size |
|---|---|---|
| Backend | Routes behind sign-in for search, conversation, briefs, corrections, people, hypotheses, actions, settings, preferences, readiness, feedback (proxies to the agent) | medium (many, each small) |
| Backend | Entry edit and delete that reach the brain; one first episode per person | small |
| Agent | A graph read endpoint for the map; a "what I know about you" read; node detail | medium |
| Agent | Goals: the brain's view and said-vs-did, exposed | small–medium |
| App | Outbox, plain states, audio download/stream, navigation model, accessibility, layout | (step 4) |
| App | Share extension; widget; push | medium |
| Store | StoreKit products, server-checked receipts | medium |

---

# Part I. Everything the founder asked for, and the earlier iOS thinking

## Decisions in the chats (20 Oct)

- The bar is **Journal · Podcasts · Goals · You**; **one feature per page**, each page showing its feature off fully; no global search/chat/feature menu on every page.
- **You = search + a map of your brain**: nodes and edges sized by how much each thing shows up.
- **Journal and chat are one page.** A place for **all your journal entries** (J3).
- **The daily brief is the day's episode**: a card you press play on; it briefs you; it keeps playing when you close the app.
- Onboarding: **questions → privacy → integrations → more questions → tease the podcast → paywall → into the app → play around**, with **guidance** in the app.
- The paywall is **scrollable**: the podcast slides up and **every benefit** is laid out below.
- **Voice onboarding**: talk to the app for every question and it talks back (ElevenLabs voice), with haptics; text on screen for now, something more visual later.
- Onboarding **shares the mission, by voice**, before asking anything.
- **A fully new, simple, production Settings**, with nothing for developers.
- **Colour:** beige + sky blue, with the beige **calibrated down** (one hue, low even chroma).
- Predictions and inferences about the person are welcome, **shown as guesses** (how sure, and why); only ungrounded content is banned.
- The audit covers **UI and product**; the demo is **an account**, not a separate app.
- Process: audit → opportunities with lo-fi mockups → best solution per screen → mid-fi → structure review → tokens and components (Lime's breadth) → founder's high-craft polish.

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

## The problems logged before the audit (each re-checked in Part C)

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

## Settings: ambient on/off (founder, 20 Oct)
A toggle in Settings for `users.ambient_enabled` (agent #101). Off = only what you send is read; nothing in the background. Plain words: "Let Retrospect read your connected apps in the background."


## Search screen, v1 (founder, 20 Oct)
Type a question → sources appear first (`POST /search/sources`, ~1 s) → "What we found" fills in on top (`POST /search/answer`) → tap any source to open it in full (`GET /search/:userId/source/:kind/:id`). Plain empty state when nothing answers.

## Parked ideas (V2)

### 1. Asking to confirm, when it would settle a lot

Founder, 19 October 2026. When one question — or very few interactions —
would raise confidence a lot, the product may ask the person directly:
*"Hey, are you actually doing this, or are you actually doing that?"*

- The questions must be **super intelligent and well triangulated**: chosen
  because the answer would move several of the 36 at once, not one.
- It is **confirmation of a hypothesis it already holds**, never an interview —
  consistent with the rule in [canonical-questions](./canonical-questions.md)
  ("Asking is for confirmation, and it comes later").
- It raises confidence in the identity picture (the "identity score") with the
  least effort from the person.
- Needs: a way to pick the question with the most to gain, a place in the app to
  ask it lightly, and recording the answer as `confirmation` evidence (that
  evidence kind already exists).

### 2. A constellation view of the brain

See [ios-v2.md](./ios-v2.md) — points (people, places, projects), lines (facts
from your own words), clusters (patterns); tap for the receipts.

### Goal coaching in the audio (founder, 20 Oct 2026, V2 — not now)
- Commit to a goal each day. The daily audio then coaches toward it: "here's what you focus on today; yesterday's progress was real, keep it going."
- **Goals inferred from requests:** "make me a database of investors to talk to" means they're likely raising a round. The system proposes that as a goal (asked, never assumed) and tracks progress on it.
- **Progress updates inside the audio, to motivate and affirm,** grounded in what they actually did (said-vs-did), never invented praise.
- **Builds on:** the goal lifecycle (W4), said-vs-did, the daily planner, and the emotional direction (W7, "warm" register for wins).

---

# Part J. The design system (tokens lead; components after the structure review)

## Decisions (yours, 20 Oct)

| # | Decision |
|---|---|
| 1 | **Hedvig Letters Serif, used tastefully:** display moments only (the first insight, an episode title, a screen's one headline), never body or UI |
| 2 | **One accent: a nice sky blue,** the paywall's blue family |
| 3 | **Monospace for all labels:** buttons, tags, metadata, times, prices, captions |
| 4 | **Grain and rim light are special:** only the primary (sky glow) button and a few signature moments, never ordinary controls |
| 5 | **Light and dark ship together; light first.** Dark follows each step, never blocks it |
| 6 | **iOS only for now** |
| 7 | **Tokens lead.** They're defined once, named by purpose, then mirrored to Figma and Swift |
| 8 | **Then a large component pass for the new app** (from [ios-v2.md](../second-brain/ios-v2.md) and the core product) |

## Three sources, three roles

| Source | Role |
|---|---|
| **Lime** (design.how) | Structure and coverage: token categories, the component inventory, blocks, written rules, the lint and the agent skill |
| **Queue** | Restraint: content carries colour; one accent, one job; space instead of lines; mono where time ticks ([study](./queue-reference/tokens.md)) |
| **Your paywall screen** (`PodcastPaywallFlow.swift`, Figma node 303:711) | Style: warm paper, the Hedvig serif, mono labels, the lit sky-blue glow button, the cream secondary, the motion of the buttons sliding up |

---

### 1.1 How they're named: by purpose, in three tiers

| Tier | Says | Example | Used by |
|---|---|---|---|
| **Palette** (primitives) | what the value *is* | `palette.sky.500`, `palette.paper.100`, `palette.ink.900` | only the semantic tier, never a screen |
| **Semantic** | what it's *for* | `color.background.canvas`, `color.text.secondary`, `color.action.primary.fill` | every screen and component |
| **Component** | one component's own decision | `button.primary.height`, `episodeRow.gap` | only that component |

**Naming rules:**
- **Never name a semantic token after its look.** No `blue`, `cream` or `grey40`. A token's name must survive a palette change: if sky blue became green tomorrow, `color.accent.default` stays correct, but `color.blue` would lie.
- Pattern: `category.role.variant.state`, as in `color.action.primary.fill.pressed`.
- **States are always the same words:** `default · pressed · focused · disabled · selected · loading`.
- **Light and dark share one name;** the value changes by mode. Screens never mention a mode.
- **Every token has a one-line purpose** in the docs ("the page behind everything"). A token whose purpose can't be written in one line is two tokens, or none.

### 1.2 The inventory: the "wide enough array"

Values marked **from paywall** are measured from the existing code. Values marked **to set** are defaults for you to refine. *(Light / dark.)*

**Colour: backgrounds**
| Token | Purpose | Light / dark |
|---|---|---|
| `color.background.canvas` | the page behind everything | `#F4F2EE` from paywall / warm near-black, to set |
| `color.background.raised` | things that float: mini-player, sheets, pills | `#F9F7F5` from paywall / to set |
| `color.background.sunken` | wells: search field, input | to set |
| `color.background.scrim` | dims the page behind a sheet or dialog | ink at 40% / black at 60% |
| `color.background.inverse` | the rare dark block on a light page | to set |

**Colour: surfaces**
| Token | Purpose |
|---|---|
| `color.surface.card` | grouped content |
| `color.surface.control` | ordinary buttons and pills (the paywall "bubble" `#EAE7E3`) |
| `color.surface.control.pressed` | that, pressed |
| `color.surface.selected` | a selected row or chip |
| `color.surface.track` | progress and scrubber tracks (`#E9E7E2` from paywall) |
| `color.surface.secondaryAction` | the cream button (`#F7F3EE` from paywall) |

**Colour: text** (mono labels use these too)
| Token | Purpose |
|---|---|
| `color.text.primary` | headlines and body (`#121212` or `#000`, to set) |
| `color.text.secondary` | supporting text |
| `color.text.label` | mono labels (`#9E9E9E` from paywall) |
| `color.text.tertiary` | hints, timestamps at rest |
| `color.text.disabled` | |
| `color.text.onAccent` | text on the sky button (white, from paywall) |
| `color.text.inverse` | text on `background.inverse` |
| `color.text.link` | inline links (accent, darkened for contrast) |

**Colour: lines**
| Token | Purpose |
|---|---|
| `color.border.subtle` | the rare divider |
| `color.border.strong` | field outlines |
| `color.border.focus` | the focus ring (accent) |
| `color.border.highlight` | the white top-lit rim (from paywall, white at 50–100%) |
| `color.border.secondaryRing` | the cream button's warm ring (`#E4DBCE`) |

**Colour: accent** (the one sky blue)
| Token | Purpose |
|---|---|
| `color.accent.default` | the accent as a flat colour (to set; within the paywall family) |
| `color.accent.pressed` | |
| `color.accent.subtle` | a tinted background (selected, highlighted) |
| `color.accent.text` | accent used as text, with readable contrast |

**Colour: status** (never decoration)
`color.status.success`, `.warning`, `.danger`, each with `.subtle` (background) and `.text`.

**Colour: content** (Queue's lesson: content carries the colour)
| Token | Purpose |
|---|---|
| `color.content.artworkFallback` | when an episode or person has no image |
| `color.content.personTint.*` | a small set of soft tints for people's initials (to set) |

**Glow** (the signature: the sky button as tokens, Lime's structure)
| Token | Purpose |
|---|---|
| `glow.primary.gradientTop` / `gradientBottom` | `#43B7FF` → `#2899DF` (from paywall) |
| `glow.primary.ring` | outer ring `#50A4EC` at 40% |
| `glow.primary.rim` | top-lit white edge, 50% fading down |
| `glow.primary.halo` | the blue bloom `#2FB3FF` at 46%, blur 16 |
| `glow.primary.lit` / `.pressed` | brighter on focus, deeper when pressed (to set) |

**Material** (special only, per decision 4)
| Token | Purpose |
|---|---|
| `material.grain.primary` | the sky button's grain (seed 19, intensity 0.2) |
| `material.grain.secondary` | the cream button's faint grain (intensity 0.045) |
| `material.grain.signature` | the mark and the first-insight moment |
| `material.dots` | the shader's dots: density, size, colour, and never over text (ios-v2 rule 3) |

**Type** (three families, one job each)
| Token | Family / size / weight / leading | Purpose |
|---|---|---|
| `type.display.hero` | Hedvig 40, −1.5% tracking | the first insight, the onboarding close |
| `type.display.title` | Hedvig 30, −2% tracking (from paywall) | a screen's one headline, an episode title |
| `type.display.quote` | Hedvig 22 | a quoted line of their own words |
| `type.text.headline` | sans semibold 17 | list titles |
| `type.text.body` | sans regular 16, leading 1.45 | reading |
| `type.text.bodySmall` | sans regular 14 | supporting copy |
| `type.label.button` | **mono** 14 (from paywall) | every button label |
| `type.label.default` | **mono** 12 (from paywall) | metadata, tags, section labels |
| `type.label.small` | **mono** 11 | tab bar, dense metadata |
| `type.numeric.time` | **mono** 14, tabular | elapsed / remaining (from the mini-player) |
| `type.numeric.stat` | **mono** 28 | big numbers in insights |

Plus: `type.tracking.*`, `type.leading.*`, and Dynamic Type limits per role.

**Space** (4-point scale)
`space.0` 0 · `space.1` 4 · `space.2` 8 · `space.3` 12 · `space.4` 16 · `space.5` 20 · `space.6` 24 · `space.8` 32 · `space.10` 40 · `space.12` 48 · `space.16` 64

Purpose aliases: `space.screen.margin` (to set: 24, 28 or 32) · `space.section.gap` · `space.list.rowGap` · `space.stack.tight` / `.default` / `.loose` · `space.inline.default`.

**Size**
| Token | Value | Purpose |
|---|---|---|
| `size.control.small` | 32 | chips, small icon buttons |
| `size.control.default` | 44 | ordinary buttons (Apple's minimum touch size) |
| `size.control.hero` | 60 | the paywall-scale primary (from paywall) |
| `size.icon.small` / `default` / `large` | 16 / 20 / 24 | |
| `size.artwork.row` / `card` / `player` / `hero` | 40 / 64 / 120 / 240 | to set |
| `size.miniPlayer.height` | 42 | from paywall |
| `size.progress.height` | 3 | from paywall |
| `size.mark` | 38 | the logo mark (from paywall) |

**Radius**
`radius.small` 8 · `radius.default` 12 · `radius.card` 20 (the mini-player, from paywall) · `radius.sheet` 28 · `radius.control` capsule (the paywall buttons at 29–30 on 60) · `radius.artwork` about 20% of size.

**Elevation**
| Token | Purpose | From |
|---|---|---|
| `elevation.flat` | | |
| `elevation.raised` | pills, mini-player | black 12%, blur 4, y 1 (paywall mini-player) |
| `elevation.card` | | Lime-style, to set |
| `elevation.overlay` | sheets, dialogs | to set |
| `elevation.primary` | the sky button's two drops + halo | paywall |
| `elevation.secondary` | the cream button | black 15%, blur 4, y 4 (paywall) |
| `elevation.mark` | the logo disc | black 24% y 6, plus 12% y 1 (paywall) |

**Motion** (the paywall moment is the reference, ios-v2 change 2)
| Token | Purpose |
|---|---|
| `motion.duration.instant` / `fast` / `base` / `slow` / `reveal` | 80 / 140 / 200 / 280 / the slide-up reveal (to measure from the paywall) |
| `motion.curve.standard` / `enter` / `exit` / `spring.reveal` | the buttons sliding up from the bottom |
| `motion.scale.press` | 0.98 |
| `motion.stagger.reveal` | delay between elements arriving |
| `motion.reduced.*` | what each motion becomes with Reduce Motion on |

**Haptics** (iOS-specific, not in Lime)
`haptic.select` · `haptic.confirm` · `haptic.reveal` (the first-insight moment) · `haptic.warning`

**Layers and layout**
`layer.base` · `layer.miniPlayer` · `layer.sheet` · `layer.toast` · `layer.dialog`, and `layout.readingWidth` (the 326-wide transcript column, from paywall) · `layout.controlsWidth` (310, from paywall).

That's **about 120 tokens across 14 categories**, the wide array to build the components on.

## Part 2: Components (the large pass, after tokens)

Built only from tokens, in the order the new app needs them. Each has every state, light and dark, Dynamic Type, VoiceOver, a gallery page, a Figma component, and a one-paragraph "when to use it".

| Tier | Components | Serves |
|---|---|---|
| **Foundations** | `PrimaryButton` (sky glow) · `SecondaryButton` (cream) · `QuietButton` (text) · `IconButton` · `Label` (mono) · `Mark` · `Divider` · `Grain` / `Rim` / `Glow` modifiers · `DotsField` (shader, never under text) | everything |
| **Inputs** | `TextField` · `TextArea` · `SearchField` · `Switch` · `Segmented` · `Chip` · `Slider` | search, settings, onboarding |
| **Display** | `Card` · `ListRow` · `Avatar` (people) · `Artwork` · `Badge` · `ProgressBar` / `Ring` · `Stat` (mono number + label) · `EmptyState` · `Skeleton` · `Toast` (with Undo) | everywhere |
| **Audio** | `MiniPlayer` · `Scrubber` (chapters as gaps) · `Transport` · `Transcript` (reading column, current line highlighted) · `EpisodeRow` · `BriefItem` ("why this is here") | Today, Episodes |
| **Brain** | `AnswerCard` (what it knows, how sure, *why*: tap for the quote) · `SourceRow` (last read, what it read, what it's for) · `SilentArea` ("I don't know much about your days yet") · `CorrectionReceipt` ("I'll stop saying…", Undo) · `QuestionCard` (a hypothesis: Yes / No in one word) · `SamePersonCard` · `AppetiteLadder` (0–3, plain words) | You, Sources, Settings |
| **Conversation** | `ChatInput` (voice-first) · `Message` (theirs / its) · `Silence` (an acknowledgement, not a bubble) · `FollowUps` | the conversation surface |
| **Actions** | `ApprovalCard` (what it's about to do, from what you said; Approve · Edit · Decline) · `ActionReceipt` (what it did, Undo) | acting (drafts only) |
| **Search** | `FoundSummary` ("What we found", with numbered citations) · `SourceResult` (openable) | Search |
| **Onboarding** | `StoryQuestion` (voice-first, one follow-up) · `ConnectCard` ("Calendar → what your weeks look like", clear state) · `VoiceMaker` · `FirstInsight` (the paywall moment: the line plays, then the buttons slide up) | Onboarding |
| **Blocks** (whole screens) | Today · Episodes · Player · You (what I know) · Sources · Search · Conversation · Settings · Onboarding · Paywall | the new app |

**Proof the system works:** the existing paywall rebuilt from tokens and components only, matching the current screen pixel for pixel.

---

## Part 3: Rules, lint and skill

- **Rulebook:**
  - one sky glow per screen;
  - colour only from semantic tokens;
  - mono for every label;
  - Hedvig only for display moments (at most one display style per screen);
  - grain and rim only where the tokens say;
  - dots never under text;
  - space before lines;
  - content carries the colour;
  - every screen's purpose readable before a word is read (ios-v2 rule).
- **Lint** (SwiftLint custom rules): no raw `Color(…)`, `Font.custom`, `.shadow(…)`, `cornerRadius:` or numeric padding outside the token layer; flag a second primary button in a view.
- **Agent skill** at `.claude/skills/retrospect-design/SKILL.md`, so every future change follows the system.
- **Gallery:** an in-app (debug) catalogue of every token and component in every state, light and dark, mirrored in Figma.

---

## Part 4: Order of work (this matches ios-v2's process)

| Step | Output | Your part |
|---|---|---|
| 1 | Answer the questions below | ✅ mostly done |
| 2 | **Token set v1:** `tokens.json` with all ~120 tokens, every name and purpose line, light and dark | review the names: do they say what each is *for*? |
| 3 | Generate Swift + Figma from it; the sync check | |
| 4 | **Your refinement pass on tokens** (values, the exact sky, the dark set) | the craft |
| 5 | Signature primitives: glow, rim, grain, dots, the reveal motion | |
| 6 | **Large component pass** (Part 2), foundations first, each with a gallery page + Figma component | approve each tier |
| 7 | Rules, lint, skill | |
| 8 | Paywall rebuilt from the system (proof), then the new app's screens, one at a time | before/after |

---

## Founder, 20 Oct (late): calibrate the beige
Beige + blue stays the system, but the beige is turned down a little and made consistent: one hue for every neutral, low and even chroma (surfaces ≈ 0.003–0.006 OKLCH, rings ≈ 0.008–0.010; today's values range 0.003–0.020 across hues 68°–106°), stepped by lightness only, judged next to the sky blue in light and dark. Applied in step 6 of [the iOS refresh plan](../second-brain/ios-refresh-plan.md); v1 primitives `palette.paper.*` are superseded then.

---

# Part K. The audit's step-by-step plan and the ranked list

## Phase map (the live path, from `RetrospectApp.swift`)

`WelcomeSignInPage` → `VoiceGoalsPage` → `IntegrationsSetupPage` → `PersonaPickerPage` → `OnboardingClosingPage` → **handoff** (`startFirstPodcastHandoff`) → `FirstPodcastExperience` (learning ritual → podcast + paywall → reflection) → `BackendAuthGateView` (if no token) → `DarkSplashScreen` (Face ID) → `DarkAppContainer` (Journal · Podcasts · Goals · Entries · Settings, behind a side panel; full-screen recorder and player).

## Every step: audit → plan

Founder, 20 Oct: the audit carries **a plan for every single step**. Each step below shows **today** (what it does and its findings), the **plan** (what replaces it, from [the opportunities map](./ios-v2-opportunities.md)), the **rules** it must meet (the 14 constraints in [app-audit-research.md](./app-audit-research.md#the-constraints-acceptance-criteria-for-the-new-app)), and the **work** it needs. Plans are direction, not final designs; detailed screens come in stages 4–6 of [the implementation plan](./ios-v2-implementation-plan.md), after the founder approves stage 2.

### Onboarding

| # | Step today | Findings | Plan | Rules | Work |
|---|---|---|---|---|---|
| 1 | **Welcome and sign-in** (`WelcomeSignInPage`): the old promise, a restyled Apple button, "Retrospect-2026" in Apple's sheet | W1–W4, W6, W7 | **A1 What this is** (the four-part promise, one breath) + **A2 Sign in**: Apple's standard button, a pressed state and spinner on tap, Google as a second option that also connects Google | 6, 10 | app; rename the display name to "Retrospect" (one build setting) |
| 2 | **Intro** ("Before we begin… Everything you share is private.") | V8 | Folded into A1/A3: no separate page. The privacy line moves to its own step (A5), where it's backed by specifics | 6, 11 | app |
| 3 | **18 questions** (`VoiceGoalsPage`): name first, demographics before meaning, orientation, dream house last, non-linear progress, answers lost on close | V1–V5, V7, V9, O2 | **A3 The conversation:** the 8 story questions + 2 fallbacks ([brief](./brief-onboarding-questions.md#v2)), voice-first, each answer acknowledged, saved the moment it's given, Back always works, "3 of 8" progress. Name from Apple when given | 8, 12, 7 | app; onboarding `/advance` (exists); the 3 question decisions (founder) |
| 4 | **Processing + goal cards** ("wonderings", then a prune of extracted goals). **Starts a paid episode that is never shown** | A7, A2 | Goals extracted from the answers are shown as the brain's view (server-owned), one tap to drop. **No episode starts here**: the first episode starts at Connect (A8), once | 3, 7 | app; remove the prefetch; server: one first-episode run per person (dedupe on `onboarding_first_episode`) |
| 5 | **Connections** (`IntegrationsSetupPage`): 17 sources, three Google cards, engineering status words, file imports mid-flow, two buttons that do the same thing | C1–C10 | **A4 Connect:** at most 5 recommended sources, each with one sentence on what it helps it understand; one Google card; plain states; "Not now" per source; file imports move to Settings → Sources. **The first episode starts here** in the background | 6, 9, 7 | app; `ENABLE_ONBOARDING_PIPELINE`; production credentials per source (C10) |
| 6 | *(missing)* **Privacy** | D1, V2 | **A5 Privacy, shown off:** what it reads, where it's processed (our server + named AI providers), what it never does, the ambient switch, delete anytime. Delete the dead screens with false claims (D1) | 11 | app; settings `/ambient` (exists); provider terms checked |
| 7 | *(missing)* **How bold** | — | **A6:** the four levels, our pick preselected from their words, with the reason | 6 | settings `/appetite` `suggested` (exists); `ENABLE_APPETITE` |
| 8 | **Host picker** (`PersonaPickerPage`): three canned hosts, no sample, saved only on the phone | P1, P2 | **A7 Your voice:** a few questions on what they listen to → a voice made for them, a sample line read aloud; saved on the server | 14 | server: voice creation (to build) |
| 9 | **Closing page** ("Play Podcast" that starts generation) | E1, A2 | Removed. The button that ends onboarding says what happens next ("Hear your first episode" only when it's ready) | 6 | app |
| 10 | **Learning about you** (fake % creeping to 95) | A5, A3 | **A8 Your first podcast:** real stages from `/onboarding/readiness` ("reading your calendar… writing… recording"), a line from their own answers while they wait; survives closing the app | 7, 1 | app; readiness (exists) |
| 11 | **Handoff failure** (silent; lands on an empty home) | A1, A3 | Failure is named: "Your first episode didn't finish. Your answers are saved. Try again now, or we'll make it tonight and tell you." Onboarding completes only when the episode exists or the promise is made | 1 | app; server: a scheduled retry + notification |
| 12 | **Player + paywall** (demo transcript fallback, 40 s tease) | A5/V10, E2 | **A9 The reveal:** the real episode only, never the demo script; after 30–40 s (open) the two buttons rise (1.22 s); demo content lives only in the demo account | 5, 6 | app; StoreKit |
| 13 | **Backend sign-in gate + Face ID** (skipped after onboarding, A4) | A4, X5 | One sign-in, done at step 1; Face ID honoured from the first launch if switched on | 1 | app |
| 14 | **Into the app** (lands on Journal) | A3 | **A10:** Home with the episode in place and the first thing worth doing ("Tell me about today") | 14 | app |

### The app

| # | Step today | Findings | Plan | Rules | Work |
|---|---|---|---|---|---|
| 15 | **Navigation**: a side panel with five screens | J5, S1 | Bottom bar **Home · Podcasts · Search · You**; Settings behind the profile (founder, 20 Oct; placement to approve) | 14 | app |
| 16 | **Journal** (capture): uploads fire once, failures lost, edits never re-sent | J1–J4, J6 | **B1 Home:** a voice-first "Tell me…" field with an outbox: saved → sent → read by the brain, retried with backoff, edits re-sent, one upload per capture. Today's brief, the conversation and "things waiting on you" below | 2, 13 | app outbox; backend `/content` idempotency key |
| 17 | **Recorder**: the old one saves every note twice (reachable via dev paths) | R1 | One recorder, one upload per note, through the same outbox | 2 | app; delete the old recorder |
| 18 | **Podcasts tab + player**: a dev section, three generate buttons, a dead-end "No Podcast Available" | R2, R3, T3, T4 | **B2 Podcasts:** this week's episode, the player with transcript, chapters and "why this was in it", the in-episode question as a Yes/No card, past episodes. No generate buttons for users | 4, 6, 1 | app; episode outline + hypotheses routes (exist) |
| 19 | *(missing)* **Search** | — | **B3 Search:** sources first (~1 s), then the written answer with citations; open any source; "Saved" filter; "that's not right" on any line | 14 | search `/sources`, `/answer` (exist) |
| 20 | **Goals**: the phone's list overrides the brain | G1–G3 | **B4 You → Goals:** the brain's view (active, expired, merged, said vs did); the app sends intents only | 3 | app; server half done (NPRdoinglaundry#19) |
| 21 | **Entries** (a list of past entries) | J3 | Merged into Home's history and Search; each entry shows its state | 2 | app |
| 22 | *(missing)* **What it knows** | M9 | **B4 You:** answers by area with how sure and why, corrections, patterns, people, what it's wondering, how bold, what it's learned | 14, 3 | server: a "what I know about you" endpoint (to build) |
| 23 | **Settings**: dev tools, Mock API, a fake legacy home, previews, all reachable by anyone | T1–T6 | **B5 Settings:** Sources (with file imports), Privacy, Actions, Voice/brief/subscription/account. **Nothing for developers:** `#if DEBUG` or a server-side staff role | 4, 5 | app; server: a staff role |
| 24 | **Everywhere**: raw errors, a general prompt proxy, placeholder transcripts from notifications | X1–X4, A6, S2–S4 | **B6:** plain errors with a next step; per-feature server endpoints instead of the prompt proxy; notifications deep-link to real content; share extension asks "why are you saving this?" | 13, 1, 5 | server: feature endpoints; app: error copy |

**Seen on a running build:** steps 1–3, 12, 15–16, 18, 20–21, 23. **Code only:** steps 4–11 (they need typed answers), 13, 17 (recorder), 19 and 22 (don't exist yet), 24 (notifications and widgets are phone-only). New live findings L1–L15 belong to steps 12 (L2–L5), 16 (L6–L7), 18 (L8), 23 (L9–L14); each is covered by that step's plan.

## Ranked list (20 Oct, after the walk-through)

From the code and static passes, the re-check, and the simulator walk-through.

**10 blockers · 60 major · 72 minor** (159 entries across this file and [app-audit-deep.md](./app-audit-deep.md); 17 are notes or repeats)

### Blockers
1. **N19**: In a release build the paywall has no way out (close is debug-only; subscribing can't work)
2. **N20**: The first episode can never be replayed after onboarding (player needs a local file)
3. **Y26**: No episode can be heard in the app after onboarding (the player never downloads server episodes)
4. **Y12**: Deleting an entry only removes it from the phone; the brain keeps it
5. **N1**: "Learning about you" shows canned claims about the person as if they were real
6. **A1**: A failed first podcast is silent
7. **J1**: A failed entry upload is lost silently
8. **G1**: The phone's goal list overrides the brain on every change
9. **T1**: Every user sees Settings → "Advanced: Dev tools and experiments" (not debug-only)
10. **T2**: The legacy home screen shows hard-coded fake podcasts ("Love and Relationships", "Career Growth", "Personal Health", "Family Connections", each with "

### Major
1. **A2**: The goals from the voice step are dropped at the handoff
2. **A3**: Onboarding is marked complete before the first podcast exists
3. **A5**: "Learning about you" is a fake progress bar: it creeps asymptotically toward 95% and never completes by itself; it only ends when the episode arrives
4. **W1**: The promise is the old product: "Your life, turned into a weekly podcast
5. **W3**: The Sign in with Apple button is restyled (cream, grey label): Apple's guidelines constrain this button, so it's an App Review risk, and the grey-on-c
6. **V1**: 18 questions, demographics first: name, city, age, gender, sexual orientation, relationship status, job, how you feel about it, *before* any of the me
7. **V2**: Sexual orientation is asked at all, in onboarding, with no stated reason or use
8. **V3**: It ends on a dream city and a dream house ("Suburban Mansion · Farmhouse · Cabin · Tiny Home"): quiz-like, after the deepest questions; the peak–end s
9. **V4**: Long: 18 questions before the person gets anything back
10. **C1**: "Make my podcast" and "Skip for now" do exactly the same thing (both `advance()`), and neither makes a podcast; they go to the host picker
11. **C2**: Google can never show as connected: its connected check is hard-coded `false`, so after connecting it shows at best a status label, never "connected"
12. **C4**: 17 sources in one list (Health, Screen Time, Google Docs, Calendar, Apple Music, Photos, Contacts, Spotify, YouTube, Reddit, Gmail, TikTok, X, ChatGPT
13. **C5**: Google appears as three separate cards (Google Docs, YouTube, Gmail), though one Google sign-in grants all three (backend commit 7f86719 combined them
14. **C6**: Engineering words shown under every card before connecting: "Device sync", "Continuous sync", "API-visible sync", "Verification-gated sync", "API-tier
15. **C8**: AI-chat history (ChatGPT, Claude, Grok) and Netflix are file imports (
16. **P1**: Canned hosts ("wise mentor", "energetic host", "thoughtful friend"), saved only to the phone (`UserDefaults voice_persona`) (logged problem, still the
17. **P2**: The host is chosen before the person has heard any voice: no sample to listen to
18. **E1**: "Play Podcast" doesn't play a podcast
19. **D1**: Old onboarding screens say "All processing happens on your device" and "Your documents stay private and are never shared
20. **O1**: No way back between steps
21. **O2**: Answers within a step aren't saved: only step completion persists, so closing the app during the voice questions loses them (confirms a logged problem
22. **J2**: Writing while signed out skips the upload silently, without queuing it for later
23. **J3**: Editing an entry never re-syncs: `updateEntry` saves only on the phone, so the server keeps the old words and the brain works from text the person cha
24. **R2**: The Podcasts tab carries a "Dev Mode" section (generate real or mock) behind the same user-reachable Dev Mode switch (T1)
25. **G3**: The Goals tab shows only the phone's goals; the brain's view (active, expired, merged, said-vs-did) never reaches the person
26. **T3**: With Mock API Calls on, a podcast is generated from sample data and looks like a real one ("Creating Mock Podcast… Using sample data…"); a user who fl
27. **T4**: Three separate "Generate podcast" buttons: the Podcasts tab and twice in Advanced settings, all labelled "Generate Real Podcast" / "Generate Mock Podc
28. **X1**: The app writes its own AI prompts and sends them to `/claude/generate`, a general "run any prompt" proxy
29. **X3**: 28 places show raw errors to the person (`error
30. **A7**: Every onboarding generates two first episodes and discards one (cost doubles per sign-up)
31. **W6**: The app is named "Retrospect-2026" in release, under the icon and in Apple's sign-in sheet
32. **L2**: With no episode, the player runs a fake clock with no audio
33. **L3**: Paywall "Privacy notice" does nothing and there's no Terms link (App Review)
34. **L4**: The paywall has no purchase path; prices are placeholders
35. **L6**: "Your next episode is in 3 days" is hard-coded
36. **L9**: Profile settings (cadence, Deep Research, "AI style") do nothing
37. **L11**: Opening Advanced asks for notifications with no reason

### Minor
A4, A6, W2, W4, V5, V7, V8, V9, V10, W7, C3, C7, C9, O3, O4, J4, J5, J6, R1, R3, G2, T5, T6, X2, X4, S1, S2, S3, S4, L5, L7, L8, L10, L12, L13, L14, F1

---

## What's left (phone and typed-answer paths only)
- **On your phone** (simulator can't): the recorder, Health, Screen Time, Calendar, notifications, widgets and the Live Activity. One screen recording is enough.
- **The normal onboarding path, steps 3–9**, needs answers typed in. It can run on a test account when you want it (no spend with the server pointed away, or one real run of about $2–4 to see the real first episode).
- Everything else in step 1 (the audit) is done: code, static, re-check, walk-through, journey, a plan per step, the ranked list.

---

# Appendix 1. Every finding, indexed

| ID | Severity | Kind | Finding | Shown in |
|---|---|---|---|---|
| A1 | Blocker | broken · doesn't feel good | **A failed first podcast is silent.** `firstPodcastError` is set, never displayed anywhere; the person is dropped on the home screen with no explanation and no retry | When the first episode fails |
| A2 | Major | logic | **The goals from the voice step are dropped at the handoff.** The closing page calls `onComplete?([])`, so the first podcast is requested with an empty goals list (goals were saved… | Goal cards |
| A3 | Major | broken · confusing | **Onboarding is marked complete before the first podcast exists.** If the app is killed during the minutes of generation, the person reopens to a home screen with no episode, no me… | "Learning about you" |
| A4 | Minor | logic | **Finishing (or "DEV: Go home") sets `isAuthenticated = true` and `needsBackendAuth = false` unconditionally**, skipping the Face ID splash for that session regardless of the setti… | When the first episode fails |
| A5 | Major | demo/fake · doesn't feel good | **"Learning about you" is a fake progress bar:** it creeps asymptotically toward 95% and never completes by itself; it only ends when the episode arrives (3–5 min, up to 10). Confi… | "Learning about you" |
| A6 | Minor | demo/fake | A notification for an unknown podcast creates a **placeholder transcript** ("Your weekly reflection is ready." / "Your personalized podcast is ready to play.") shown as if real | When the first episode fails |
| A7 | Major | broken · cost · redundant | **Every onboarding generates two first episodes and discards one.** When the questions finish, `finishProcessing` starts a real generation (`prefetchPodcast`) *before any source is… | Goal cards |
| W1 | Major | doesn't make sense (now) · not inspiring | **The promise is the old product:** "Your life, turned into a weekly podcast. Journal entries, voice notes, health data…". Nothing about the daily brief, search, talking to it, or … | Welcome and sign-in (`WelcomeSignInPage`) |
| W2 | Minor | pixel · inconsistent | **Canvas colour differs from the paywall:** a cool grey here vs warm paper `#F4F2EE` on the paywall; the first impression and the payoff don't match | Welcome and sign-in (`WelcomeSignInPage`) |
| W3 | Major | risk · pixel | **The Sign in with Apple button is restyled** (cream, grey label): Apple's guidelines constrain this button, so it's an App Review risk, and the grey-on-cream label is low contrast | Welcome and sign-in (`WelcomeSignInPage`) |
| W4 | Minor | pixel · flat | A large empty middle: text sits top-left, the button at the bottom, about 40% of the screen empty with nothing drawing the eye | Welcome and sign-in (`WelcomeSignInPage`) |
| W5 | Note | demo (ok) | "DEV: Sign in as new test user" is visible; confirmed debug-only (`#if DEBUG`) | Welcome and sign-in (`WelcomeSignInPage`) |
| W6 | Major | pixel · broken (brand) | **The app is named "Retrospect-2026"** in both debug *and* release configurations, so that's what appears under the icon and in Apple's sign-in sheet ("Create an account for Retros… | Welcome and sign-in (`WelcomeSignInPage`) |
| W7 | Minor | interaction | **Tapping Sign in with Apple gives no feedback for ~2 s** (no pressed state, no spinner) before Apple's sheet appears; people tap again | Welcome and sign-in (`WelcomeSignInPage`) |
| V1 | Major | psychological · doesn't feel good | **18 questions, demographics first:** name, city, age, gender, **sexual orientation**, relationship status, job, how you feel about it, *before* any of the meaningful ones. Sensiti… | Demographic questions (age, gender, relationship, job) |
| V2 | Major | psychological · risk (privacy) | **Sexual orientation is asked at all, in onboarding,** with no stated reason or use. Sensitive personal data, collected without purpose | Sexual orientation question |
| V3 | Major | psychological · flat | **It ends on a dream city and a dream house** ("Suburban Mansion · Farmhouse · Cabin · Tiny Home"): quiz-like, after the deepest questions; the peak–end shape is inverted (it ends … | Dream city and dream home |
| V4 | Major | psychological · not fun | **Long:** 18 questions before the person gets anything back. The 8 story questions in [the onboarding brief](./brief-onboarding-questions.md) were designed to cover most of the 36 … | The deeper questions and acknowledgements |
| V5 | Minor | interaction | **The progress bar is non-linear:** 8 demographic answers move it 8%→22%, then single deep answers jump 11–13 points; it misrepresents how much is left | Demographic questions (age, gender, relationship, job) |
| V6 | Note | demo (ok) | A debug-only Skip exists (`#if DEBUG`), fine; a "Skip" at progress 0.02 jumps straight to completion | Closing page ("Play Podcast") |
| V7 | Minor | logic risk | **Many timed delays** drive the conversation's pacing (asyncAfter at 0.28 s, 0.1 s, 0.32 s, 0.2 s, plus "dwell" and "ack dissolve"); pacing breaks on a slow device | The deeper questions and acknowledgements |
| V8 | Minor | pixel · psychological | *(simulator)* The intro ("Before we begin… Everything you share is private.") promises privacy in one line with nothing behind it; its **Continue label is mid-grey on cream**, low … | Intro ("Before we begin…") |
| V9 | Minor | redundant · interaction | *(simulator)* **"What should I call you?" comes right after Sign in with Apple,** which can already supply the name; first question is a form field, keyboard up, no Back | Your name |
| V10 | Minor | demo (debug only) | *(simulator + code, corrected)* The questions step has its own closing screen ("Now let's help you get there." → **Play Podcast**) whose player falls back to the **demo transcript … | Closing page ("Play Podcast") |
| C1 | Major | doesn't make sense · redundant | **"Make my podcast" and "Skip for now" do exactly the same thing** (both `advance()`), and neither makes a podcast; they go to the host picker. The main button promises what it doe… | Connections (`IntegrationsSetupPage`) |
| C2 | Major | broken | **Google can never show as connected:** its connected check is hard-coded `false`, so after connecting it shows at best a status label, never "connected" | Connections (`IntegrationsSetupPage`) |
| C3 | Minor | interaction | **The same error is shown twice:** inline red text *and* an alert, both from `connectionError` | Connections: further down, file imports |
| C4 | Major | psychological · not fun | **17 sources in one list** (Health, Screen Time, Google Docs, Calendar, Apple Music, Photos, Contacts, Spotify, YouTube, Reddit, Gmail, TikTok, X, ChatGPT, Claude, Grok, Netflix): … | Connections (`IntegrationsSetupPage`) |
| C5 | Major | redundant · confusing | **Google appears as three separate cards** (Google Docs, YouTube, Gmail), though one Google sign-in grants all three (backend commit 7f86719 combined them). It's also labelled "Goo… | Connections (`IntegrationsSetupPage`) |
| C6 | Major | doesn't make sense | **Engineering words shown under every card before connecting:** "Device sync", "Continuous sync", "API-visible sync", "Verification-gated sync", "API-tier gated sync", "Optional fi… | Connections (`IntegrationsSetupPage`) |
| C7 | Minor | demo/fake · confusing | Tapping an unbuilt source explains, in engineering language, that it "can be connected here as soon as its verified collection path is ready" | Connections: further down, file imports |
| C8 | Major | interaction · not fun | AI-chat history (ChatGPT, Claude, Grok) and Netflix are file imports (.json/.zip/.csv) mid-onboarding (logged problem, still there) | Connections: further down, file imports |
| C9 | Minor | doesn't feel good | A failed status fetch shows the raw system error in an alert | Connections: further down, file imports |
| C10 | Note | unknown | Whether each OAuth source (Spotify, Reddit, TikTok, X, YouTube, Gmail) has working production credentials is unverified; X needs a paid API tier and TikTok an approval | Connections: further down, file imports |
| P1 | Major | not inspiring | **Canned hosts** ("wise mentor", "energetic host", "thoughtful friend"), saved only to the phone (`UserDefaults voice_persona`) (logged problem, still there; ios-v2 change 7 replac… | Host picker (`PersonaPickerPage`) |
| P2 | Major | psychological · interaction | The host is chosen **before the person has heard any voice**: no sample to listen to | Host picker (`PersonaPickerPage`) |
| E1 | Major | doesn't make sense · psychological (broken promise at the peak) | **"Play Podcast" doesn't play a podcast.** No podcast exists yet; the button starts generation and the "Learning about you" wait. The label promises an instant payoff that's minute… | Closing page ("Play Podcast") |
| E2 | Note | demo (ok) | "DEV: Preview paywall" is debug-only (`#if DEBUG`), fine | Closing page ("Play Podcast") |
| D1 | Major | dead · risk (false privacy claim) | **Old onboarding screens say "All processing happens on your device" and "Your documents stay private and are never shared."** Both are false: Retrospect processes on its server an… | Part C |
| O1 | Major | interaction | **No way back between steps.** Steps are one-way flags; there is no back button or gesture from one step to the previous one (within the voice questions there is a Back) | The deeper questions and acknowledgements |
| O2 | Major | broken | **Answers within a step aren't saved:** only step completion persists, so closing the app during the voice questions loses them (confirms a logged problem) | The deeper questions and acknowledgements |
| O3 | Minor | logic | Completing the questions silently marks the privacy notice as acknowledged (the privacy page is no longer on the path) | Part C |
| O4 | Minor | redundant naming | Named "Dark…" throughout, but forced to light mode | Part C |
| J1 | Blocker | broken | **A failed entry upload is lost silently.** The failure goes only to a debug log; the entry has no "synced" flag; nothing retries; the person is never told. The brain never sees th… | Journal (`DarkJournalView`) |
| J2 | Major | broken | **Writing while signed out skips the upload silently**, without queuing it for later | Journal (`DarkJournalView`) |
| J3 | Major | broken · logic | **Editing an entry never re-syncs:** `updateEntry` saves only on the phone, so the server keeps the old words and the brain works from text the person changed | Journal (`DarkJournalView`) |
| J4 | Minor | redundant · risk | **The only recovery is "resync everything"**, hidden in Dev Mode settings, which re-uploads every entry ever written (duplicates, unless the server's dedup catches them) | Journal (`DarkJournalView`) |
| J5 | Minor | structure | **One 1,227-line file holds the app shell, an audio manager, the journal and an "agent podcast test"**, so changes to one break others | Side menu and navigation |
| J6 | Minor | doesn't feel good | Audio and voice errors are shown raw ("Audio session error: …", "Failed to play audio: …") | Journal (`DarkJournalView`) |
| R1 | Minor | broken (double counting) | **The old recorder saves every voice note twice** (`addEntry` → `voice_recording`, plus an explicit upload as `voice_journal`), so the brain counts each note double. The live recor… | Recorder |
| R2 | Major | demo in ship | The Podcasts tab carries a "Dev Mode" section (generate real or mock) behind the same user-reachable Dev Mode switch (T1) | Podcasts (`DarkPodcastsView`) |
| R3 | Minor | dead end | The full player opens only if a transcript is already loaded; otherwise "No Podcast Available" with Dismiss, with no route to the episode list or a retry | The episode player |
| G1 | Blocker | broken · logic | **The phone's goal list overrides the brain on every change.** The sync *reactivates* any goal the server marked inactive (undoing the brain's merge and expiry, goal 7: 31→3 active… | Goals (`DarkGoalsView`) |
| G2 | Minor | broken | A failed goal sync is only printed; no retry, nothing shown | Goals (`DarkGoalsView`) |
| G3 | Major | missing | The Goals tab shows only the phone's goals; the brain's view (active, expired, merged, said-vs-did) never reaches the person | Goals (`DarkGoalsView`) |
| T1 | Blocker | demo/fake in ship | **Every user sees Settings → "Advanced: Dev tools and experiments"** (not debug-only). Inside, a **"Dev Mode"** switch anyone can turn on reveals: **"Mock API Calls: use sample dat… | Settings (`DarkSettingsView`) |
| T2 | Blocker | demo/fake in ship | **The legacy home screen shows hard-coded fake podcasts** ("Love and Relationships", "Career Growth", "Personal Health", "Family Connections", each with "Mock transcript for…") and… | Advanced (developer tools) |
| T3 | Major | demo/fake | **With Mock API Calls on, a podcast is generated from sample data and looks like a real one** ("Creating Mock Podcast… Using sample data…"); a user who flips it gets fake episodes | Podcasts (`DarkPodcastsView`) |
| T4 | Major | redundant · confusing | **Three separate "Generate podcast" buttons:** the Podcasts tab and twice in Advanced settings, all labelled "Generate Real Podcast" / "Generate Mock Podcast" | Podcasts (`DarkPodcastsView`) |
| T5 | Minor | demo in ship | "Animation: Fluid dots preview" is a Settings row for everyone | Settings (`DarkSettingsView`) |
| T6 | Minor | redundant | Settings is 1,890 lines; Advanced alone holds onboarding replay, finale debug, legacy UI, flow previews and new-podcast-arrival tests (development tools living in the shipped setti… | Settings (`DarkSettingsView`) |
| X1 | Major | risk (cost) | **The app writes its own AI prompts and sends them to `/claude/generate`, a general "run any prompt" proxy.** It's protected by sign-in and a global rate limit and capped at 8,192 … | Part C |
| X2 | Minor | stale | The proxy's default model is an older one (`claude-sonnet-4-6`) unless `CLAUDE_MODEL` is set | Part C |
| X3 | Major | doesn't feel good | **28 places show raw errors to the person** (`error.localizedDescription`), and the API client builds them as "HTTP 500: {body}" (logged problem, wider than logged) | Part C |
| X4 | Minor | dead · broken | Legacy `OpenAIService` remains with an empty key ("until all call sites use the API"); any remaining caller fails silently | Part C |
| X5 | Note | audit blocker | The DEV test-user sign-in only works against a local server (production correctly returns 404), so a fresh simulator can't get past screen 1 without a real Apple ID or a local back… | Welcome and sign-in (`WelcomeSignInPage`) |
| S1 | Minor | dead | **About 57 of 248 screen types (~32 files, ~8,000 lines) can't be reached from the app**, including a 1,273-line unused onboarding (`iMessageOnboardingView`), a whole video-journal… | Side menu and navigation |
| S2 | Minor | logic risk | **83 timed delays (`asyncAfter`)** across the app: a sign of timing patches that behave differently on slow devices and networks | Part C |
| S3 | Minor | demo | 37 `#if DEBUG` blocks and 5 "DEV:" controls: to be checked that none leaks into a release build | Part C |
| S4 | Minor | redundant | Two Xcode projects: `Retrospect/Retrospect.xcodeproj` (live) and `Retrospect fina (SwiftUI).xcodeproj` at the root | Part C |
| L1 | Note | broken | **Closing the app mid-onboarding loses everything:** a relaunch starts the questions again from the intro. Confirms O2 on a running build | Demographic questions (age, gender, relationship, job) |
| L2 | Major | demo or fake · broken | **With no episode, the player runs a fake clock:** "6:58" counting down, a Pause button, a moving bar, **no audio**, and the first line stays highlighted for 40 s. It looks like it… | When the first episode fails |
| L3 | Major | broken · App Review risk | **The paywall's "Privacy notice" does nothing** (empty action) and there is **no Terms of Use link**. Apple requires working links to both on a subscription screen (Guideline 3.1.2… | Paywall (`PodcastPaywallFlow`) |
| L4 | Major | missing · product | **The paywall can't take money:** there is no StoreKit purchase path at all. "$19.99/m" and "$239.99/y" are placeholder text (and the yearly placeholder is more than 12 × monthly);… | Paywall (`PodcastPaywallFlow`) |
| L5 | Minor | doesn't make sense | An **unlabelled icon button** (two arrows) on the paywall and at the top of the side menu; its purpose can't be told from the screen | Paywall (`PodcastPaywallFlow`) |
| L6 | Major | demo or fake | **Journal promises "Your next episode is in 3 days" always:** the text is hard-coded, whatever the schedule or whether any episode exists | Journal (`DarkJournalView`) |
| L7 | Minor | pixel | Journal's prompt reads "tell me something....." (five dots), in faint grey on cream | Journal (`DarkJournalView`) |
| L8 | Minor | confusing · dead end | **Podcasts says "Write in your journal and generate your first personalized podcast"** but there is no generate button for a normal user; the menu says "podcasts", the header "Epis… | Podcasts (`DarkPodcastsView`) |
| L9 | Major | broken · fake | **Profile's settings do nothing:** podcast cadence (Daily … Every 2 weeks) is stored on the phone and never read or sent; "Deep Research Mode" is read only by the legacy home scree… | Profile settings |
| L10 | Minor | doesn't make sense | "Every Other Day" is described as "Mon, Wed, Fri, Sun" (four days, two in a row) | Profile settings |
| L11 | Major | psychological (trust before ask) | **Opening Advanced asks for notification permission** out of nowhere, with no reason given, under the name "Retrospect-2026" (W6) | Advanced (developer tools) |
| L12 | Minor | interaction · pixel | The side menu opens about a second after the tap; the menu button moves between screens (Journal vs the rest) | Side menu and navigation |
| L13 | Minor | pixel | The Face ID switch reads ambiguously: knob on the "on" side, grey track like "off" | Settings (`DarkSettingsView`) |
| L14 | Minor | doesn't feel good | With the server down, Integrations shows "Could not connect to the server." with only OK; the retry is a separate icon. Plain words, but no next step | Integrations & Data |
| L15 | Note | interaction (debug only) | The debug Skip needs two taps the first time (the first is swallowed while the keyboard comes up) | Demographic questions (age, gender, relationship, job) |
| N1 | Blocker | demo or fake · psychological | **"Learning about you" shows hard-coded placeholder insights to every user as if they were about them:** "You carry more than you let on", "You move fast, and rarely stop to notice… | "Learning about you" |
| N2 | Note | broken · cost | **The two-episode problem confirmed on a running build:** `/podcasts/generate` fired when the goal cards appeared (02:11:38) and again on "Play Podcast" (02:13:07). Confirms A7 | First episode plays |
| N3 | Note | demo or fake | **"Learning about you" percentage is invented:** 24% at ~2 s, 77% at ~15 s, 91% at ~30 s, with the server still working. Confirms A5 | First episode plays |
| N4 | Minor | pixel | **The dots draw over the headline text** on "Learning about you" (confirms the logged "dots over text") | "Learning about you" |
| N5 | Major | demo or fake · doesn't make sense | **The "wonderings" fallback is canned and written in the third person** ("What are *they* protecting when *they* stay this busy?"), shown whenever the AI call fails; the lines assu… | Thinking ("wonderings") |
| N6 | Minor | not inspiring | **Every acknowledgement is the same line**, "Thank you. That helps.", whatever the answer (the AI-made reply falls back to it); after the first few it proves nothing was heard | The deeper questions and acknowledgements |
| N7 | Minor | risk (cost) | **Each deep answer makes its own AI call through the general prompt proxy** (`/claude/generate`, 9 per onboarding), so the app writes prompts client-side for every answer (adds to … | The deeper questions and acknowledgements |
| N8 | Minor | psychological · interaction | **Three "bridge" screens with no Back** ("These next ones go a little deeper", "Now, the real reason you're here", "Now dream a little bigger… because with me, it is"). The last on… | Bridge screens |
| N9 | Major | psychological · privacy | **The sexuality question is free text with no way to decline** (unlike gender, which has "Prefer not to say"); the keyboard opens straight away | Sexual orientation question |
| N10 | Minor | interaction | **Return doesn't send an answer;** it closes the keyboard and the answer stays in the field, so you hunt for the arrow | Your name |
| N11 | Minor | pixel · interaction | **A picked option barely changes colour** (gender, relationship), so it's hard to see what you chose | Demographic questions (age, gender, relationship, job) |
| N12 | Minor | pixel | **The home-type grid misaligns:** two-line labels make some cards taller, so the two columns don't line up | Dream city and dream home |
| N13 | Minor | psychological · interaction | **Goal cards say "I'll watch your life through the rest"** (reads as surveillance), with no way to add or edit a goal, only uncheck | Goal cards |
| N14 | Major | pixel | **Connections: every description is cut off mid-word** ("daily rhyth…", "apps an…"), the heading scrolls under the status bar, and the list runs under "Make my podcast" (confirms t… | Connections (`IntegrationsSetupPage`) |
| N15 | Minor | interaction · confusing | **Tapping a file import opens the iOS file picker with no explanation** of which file or how to export it from ChatGPT/Claude/Grok/Netflix | Connections: further down, file imports |
| N16 | Minor | doesn't feel good | **A failed connection shows "Server error: Could not start connection"** in an alert, after the fact, with only OK | Connections: further down, file imports |
| N17 | Minor | redundant | **The closing page repeats the questions step's closing line** ("Now I know what matters to you, Sam. Let's help you get there." vs "Now let's help you get there.") and shows "DEV:… | Closing page ("Play Podcast") |
| N18 | Minor | pixel | **Host descriptions are cut off** ("Good…", "Celebrates y…"); green ticks on goals and hosts aren't in the design system | Host picker (`PersonaPickerPage`) |
| N19 | Blocker | broken | **In a release build the paywall has no way out.** The close (X) is wrapped in `#if DEBUG`, there's no "Not now", and subscribing can't work yet (no purchase path), so a real perso… | Paywall (`PodcastPaywallFlow`) |
| N20 | Blocker | broken | **The first episode can never be replayed after onboarding.** The app's player only plays files saved on the phone; the first episode is saved with its web link (only the legacy "g… | The episode player |
| N21 | Minor | doesn't make sense | **The episode pill is labelled with the mood** ("Reflective episode"), not the episode's title; the full player shows no title, date, chapters, speed or "why this was in it", and o… | The episode player |
| N22 | Minor | dead (for now) | **The reflection step ("How was your first podcast?") is unreachable today:** it only follows a completed subscription *and* a finished episode. Its answer would be saved as the fi… | First reflection ("How was your first podcast?") |
| N23 | Note | demo or fake | **"Learning about you" ends "Understanding you. 100%"** the instant the episode arrives (94% → 100% in one jump), so the number is visibly tied to nothing | "Learning about you" |
| K1 | Major | redundant · confusing | *Backend sign-in gate (shown when the app has no server token after onboarding):* **A second sign-in screen that repeats the welcome page word for word**, including the old promise… | Second sign-in gate and Face ID |
| K2 | Major | broken · interaction | *Face ID splash:* On failure shows the raw system error and a "Try Again" button; no way in by passcode or to turn Face ID off from here, so a failed Face ID locks the person out o… | Second sign-in gate and Face ID |
| K3 | Minor | redundant · stale copy | *"Connect Google" prompt (appears over Home after onboarding when Google isn't connected):* **A second Google ask after onboarding already offered Google**, labelled "Secure Docume… | Google prompt and data tools |
| K4 | Minor | demo in ship · structure | *Data management ("Reset All Data"):* Lives inside a 1,461-line file mixing Google Docs browsing, data overview and reset; "Setup Required: please add your Google Client ID" is dev… | Google prompt and data tools |
| K5 | Minor | dead | *First reflection ("How was your first podcast?"):* Unreachable today (needs a completed subscription); see N22 | First reflection ("How was your first podcast?") |
| K6 | Note | — | *Recorder (full screen):* Not walked (it records the Mac's microphone). From code: the live recorder saves once; the legacy one twice (R1); transcription confidence is computed and… | Recorder |
| K7 | Note | — | *Widgets, Live Activity, notifications, share:* Phone-only. From code: no share extension exists; notifications for an unknown episode create placeholder transcripts (A6) | Part C |
| Y1 | Major | clarity | *Opened the app:* Journal is an almost empty screen: a faint "tell me something….." in the middle, an episode pill, "Your next episode is in 3 days". **Nothing shows what you've wr… | Journal (`DarkJournalView`) |
| Y2 | Minor | interaction · pixel | *Tapped "tell me something…..":* The keyboard took a second or two to come up; **the cursor appears at the top left, not where the prompt was**, so the first tap doesn't land where… | Journal (`DarkJournalView`) |
| Y4 | Major | broken | *Typed "Half written thought about", then opened the menu:* **The half-written thought was sent as a finished entry** (the server received it the moment the menu opened). Any way o… | Journal (`DarkJournalView`) |
| Y5 | Major | clarity · feedback | *Tapped send:* **The words vanished with no confirmation.** No "saved", no entry shown, no sign it reached the brain. It did reach the server (seen in the stand-in log), but the pe… | Journal (`DarkJournalView`) |
| Y6 | Minor | performance | *Timed the screen:* Several seconds between tapping send and the screen clearing, and between taps and the keyboard. Idle CPU is near zero, so it isn't a background drain; to confi… | Journal (`DarkJournalView`) |
| Y7 | Minor | clarity · redundant | *Opened the menu:* A "recents" list appears under the sections, every item titled **"Entry from Oct 20, 2026…"** and cut off, so you can't tell entries apart; it duplicates the Ent… | Side menu and navigation |
| Y8 | Note | — | *(correction):* An earlier note here said the menu does nothing while typing; that was my tap landing off the button. The menu works | Journal (`DarkJournalView`) |
| Y9 | Major | pixel · clarity | *Opened an entry:* **The hierarchy is upside down:** the title is the date and time in 36 pt serif over three lines ("Entry from Oct 20, 2026 at 2:27 AM"), the line below repeats t… | A single entry |
| Y10 | Major | missing | *Tapped the words; looked for edit or delete:* **The entry can't be edited, and the page has no delete.** Only a back button | A single entry |
| Y11 | Major | gesture | *Swiped from the left edge:* **Nothing happened.** The standard iPhone swipe-back gesture doesn't work; only the small round back button does | A single entry |
| Y12 | Blocker | broken · privacy | *Read the code for deleting from Entries (long-press menu):* **Deleting an entry only removes it from the phone.** `EntryManager.deleteEntry` deletes the local file and nothing els… | A single entry |
| Y13 | Minor | redundant | *Read the code:* Three different entry-page views exist (`FigmaLightInlineEntryReader` live; `DarkEntryDetailView` and `EntryDetailView` unreachable or legacy), so the J3 "edits ne… | A single entry |
| Y14 | Major | navigation | *Opened an entry from the menu's recents, then tapped back:* **Back went to Entries, a screen I had never opened**, not to Journal where I started | Entries |
| Y15 | Minor | incoherent | *Compared titles:* Entries titles each entry by its first words ("Half written thought about"); the menu's recents call the same entries "Entry from Oct 20, 2026…"; the entry page … | Entries |
| Y16 | Minor | interaction | *Tried to act on actions in quick succession:* Screens lag about a second behind each tap, so taps made while a menu is closing land on whatever is underneath (my long-press on an … | Side menu and navigation |
| Y17 | Note | broken | *Opened Goals with a server holding 4 sample goals:* **It shows the phone's 3 onboarding goals, not the server's 4.** The brain's goals never appear (confirms G3 live) | Goals (`DarkGoalsView`) |
| Y18 | Note | broken | *Added one goal ("Sample: read more"):* **One goal sent 8 writes:** a read, 4 creates (every phone goal re-created) and 3 updates switching off the server's goals the phone didn't … | Goals (`DarkGoalsView`) |
| Y19 | Major | pixel · layout | *Tapped "+":* **The whole screen jumps up under the status bar and camera:** the title and menu disappear, goal text runs behind the clock, and the input floats mid-screen over a l… | Goals (`DarkGoalsView`) |
| Y20 | Minor | pixel · missing | *Expanded a goal:* The description is indented further than the "Why this matters" label under it; a large empty area; only a small bin icon. **No edit, no progress, nothing the br… | Goals (`DarkGoalsView`) |
| Y21 | Minor | pixel | *Looked at the new goal:* A goal added by hand has no description, so its card is a different height from the rest | Goals (`DarkGoalsView`) |
| Y22 | Major | broken · clarity | *Opened Podcasts with 3 sample episodes on the server:* **Every episode is titled "Weekly Insights"**: the title is hard-coded and the server's real titles ("The week you stopped r… | Podcasts (`DarkPodcastsView`) |
| Y23 | Minor | broken | *Read the mood under each title:* The server's moods ("warm", "curious") show as **"neutral"**: anything outside an old fixed list of eight is replaced (`Transcriptviewmodel.swift:… | Podcasts (`DarkPodcastsView`) |
| Y24 | Minor | redundant | *Counted rows:* **4 rows for 3 episodes:** the locally saved first episode sits beside the server's copy | Podcasts (`DarkPodcastsView`) |
| Y25 | Minor | pixel · redundant | *Looked at a row:* **Two play buttons per row** (a round one on the left, a triangle on the right); the date is cut off ("Oct 20, 2…") | Podcasts (`DarkPodcastsView`) |
| Y26 | Blocker | broken | *Played a server episode:* **Nothing plays, for any episode:** the app never fetched the audio (no request reached the server). The player only plays files saved on the phone, and … | The episode player |
| Y27 | Major | missing · broken | *Looked at the player:* It shows a stale "0:37" from an earlier session, no title, no date, no chapters, no speed, no "why this was in it"; the "…" button does nothing; the only wa… | The episode player |
| Y28 | Major | clarity | *Opened the app with the server failing:* Journal looks exactly the same as when it works: no banner, no sign anything is wrong | Journal (`DarkJournalView`) |
| Y29 | Note | broken | *Wrote an entry and sent it while the server was failing:* The server returned an error, and **the screen cleared exactly as it does on success.** Nothing says the entry didn't arr… | Journal (`DarkJournalView`) |
| Y30 | Major | broken · clarity | *Opened Podcasts with the server failing:* **Three of four episodes silently disappeared**: no message, no retry, as if they never existed | Podcasts (`DarkPodcastsView`) |
| Y31 | Major | broken | *Pulled down to refresh; reopened Podcasts:* **No pull-to-refresh, and the list isn't re-fetched when you open the tab**; it loads once at launch, so a new episode doesn't appear u… | Podcasts (`DarkPodcastsView`) |
| Y32 | Major | interaction · risk | *Looked at the row actions:* **The power button disconnects a source in one tap, with no confirmation**, and sits 2 pt from the "…" menu; both targets are 34 pt, under Apple's 44 p… | Integrations & Data |
| Y33 | Major | clarity · pixel | *Read the states:* Status is colour-coded green and orange in colours the design system doesn't have; "Verified and connected · Continuous sync" and "Sync needs attention · Continu… | Integrations & Data |
| Y34 | Minor | incoherent | *Compared with onboarding:* The same source is "Google Docs" here, "Google Docs/YouTube/Gmail" in onboarding, and "Google" on the server; summary tiles ("1 Verified · 2 Needs atten… | Integrations & Data |
| Y35 | Minor | incoherent | *Looked at the sheet:* This is a sheet over Settings with its own back button, while every other Settings page is a full screen: two navigation styles one tap apart | Integrations & Data |
| Y36 | Major | accessibility | *Set the largest accessibility text size:* **Nothing in the app got bigger.** 681 fonts are fixed sizes; 21 follow the system text size. Anyone who needs larger text can't get it (… | Part C |
| Y37 | Minor | incoherent · pixel | *Switched the phone to dark mode:* **The app stays light**: it's forced to light in 24 places (while every main file is named "Dark…"); a couple of player error screens force dark … | Part C |
| Y38 | Major | accessibility | *Counted VoiceOver labels:* **9 accessibility labels for 427 buttons.** Icon-only buttons (menu, mic, +, send, power, "…", the two-arrow icon) are unnamed to VoiceOver | Part C |
| Y39 | Minor | accessibility | *Checked reduced motion:* Respected in 2 places only; the shader, the dots and the onboarding animations ignore it | Part C |
| Y40 | Minor | interaction | *Measured touch targets:* Several key controls are under 44 pt: the integration row buttons (34 pt), the player's "…", the debug Skip | Settings (`DarkSettingsView`) |
| Y41 | Major | pixel · layout | *Reached the paywall on the SE:* **The paywall is one fixed 402 × 874 picture shrunk to fit** (16 hard-coded positions inside): on the SE everything is drawn at about 76%, so the p… | Paywall (`PodcastPaywallFlow`) |
| Y42 | Minor | pixel | *Played the episode on the SE:* The first-episode player fits; the transcript's lower lines are blurred deliberately, but on the small screen only one sentence is readable at a tim… | Paywall (`PodcastPaywallFlow`) |
| Y43 | Note | ok | *The SE's simulator uses no Dynamic Island; the welcome, intro and closing screens fit; nothing was cut off on those:* — | Part C |
| Y44 | Major | performance | *"Learning about you":* A 60-times-a-second timer on the main thread updates SwiftUI state every frame (`@State hold/release/dissolve`), which re-renders the whole screen including… | "Learning about you" |
| Y45 | Minor | performance | *Transcript in the player and paywall:* Every line except the current one is blurred (`.blur(radius: 1.8)`), plus 10–22 pt blurs on the paywall veil; blur on many text layers is ex… | The episode player |
| Y46 | Minor | performance | *Onboarding acknowledgements:* Each acknowledgement dissolves into particles drawn by a `Canvas` at 60 fps; fine for a moment, but it runs on top of the typing keyboard | The deeper questions and acknowledgements |
| Y47 | Minor | performance | *Journal and menu:* Taps take about a second to register and the keyboard is slow to appear (Y2, Y6, Y16). Idle CPU is near zero, so the likely cause is work done on the tap itself… | Journal (`DarkJournalView`) |
| Y48 | Minor | performance · logic | *Whole app:* 83 timed delays (`asyncAfter`) choreograph animations by the clock; on a slow phone they fall out of step with what's actually ready (S2) | Part C |
| Y49 | Note | ok · (O2) | *Closed the app at Connections and reopened:* **Resumed at Connections**: step-level progress is saved (good). Within the questions, answers are not (O2) | Part C |
| Y50 | Note | navigation | *Swiped from the left edge on Connections:* **No way back** to the questions, by gesture or button (confirms O1 live) | Connections (`IntegrationsSetupPage`) |
| Y51 | Major | interaction · waits | *Picked a host with the server responding slowly:* **"Saving…" blocks the screen for the whole server wait** (25 s in the test; a sleeping Render server takes ~50 s) just to save a… | Host picker (`PersonaPickerPage`) |
| Y52 | Minor | clarity | *Opened Connections with a slow server:* The list renders immediately from a list built into the app, and real connection states arrive later with no sign of loading, so a source c… | Connections (`IntegrationsSetupPage`) |
| F1 | Minor | broken | Three Libre Baskerville font files are saved web pages, not fonts | Part C |

*Every finding above appears in full in Part B or Part C.*

# Appendix 2. Verified behaviour (read in full, not just indexed)

What each piece actually does, where it shapes a screen:

| Area | Verified | Screen consequence |
|---|---|---|
| Onboarding stages | `stageFor`: reading until nothing is outstanding and 2 min quiet, or 20 min max; then the first pass; then one episode (guarded only inside the pipeline: an episode run in the last 15 min blocks a second); the pipeline covers accounts from the last 3 days, every 2 min | N10 shows real counts (sources still syncing, entries waiting, answers formed); the app must not call `/podcasts/generate` itself (K12) |
| Reading speed | arrivals: read 2 min after material stops arriving, at most 10 min (when on); otherwise the daily 05:00 UTC run | J1/J3 "read" mark within minutes only with `ENABLE_MATERIAL_ARRIVALS` |
| Source sync | every 6 h (`INTEGRATION_SYNC_INTERVAL_MINUTES` 360) | T3 "last read" is honest at hours, not minutes |
| Daily brief (v2) | inbox = everything you sent since the last brief, always, in full, first, never dropped; then today's calendar; at most one saved link resurfaced (saved 7+ days ago, tied to a live goal or moved question, not resurfaced in 14 days); then what moved; anything said in the last three briefs discounted; a day with nothing is quiet | J2 sections in this order; J1 entries come back in tomorrow's brief ("daily is your inbox") |
| Weekly episode | eligible: anyone with new material in 14 days; spend cap checked; v2 stores the plan; a quiet week with nothing over the bar refuses to pad | P1 quiet-week state is real |
| Conversation | intent fyi/question/correction/chat; reply may be empty; a correction said in conversation is routed to corrections; uses search for questions; working memory 18 h | J1 replies, including none |
| Corrections | outcomes: not a correction · applied (with what it retired and an echo) · confirm (candidates to pick) · ask own words (when the claim came from what you wrote: shows your quote and date before changing it) | every "not right" flow has these four endings |
| People questions | each held pair: "Is the {name} in your writing {contact}?"; same links, different keeps apart for good | Y6 copy and outcomes |
| Hypotheses | yes → confirmed, no → declined; unanswered ones expire after the dial's window (30 days); one per episode, only when the dial speaks and appetite ≥ the dial's minimum (2) | P2, Y6 |
| How bold | stated always wins; inferred rises one level after 2 engaged signals in 14 days with no discomfort; drops one on any discomfort in 7 days; first guess capped at 2, at most 1 if something hard is in your words, 0 under 3 entries | N9, T6 copy ("I picked this because…") |
| What it's learned | per question type, a Bayesian response rate turned into a weight of 0.8–1.2 that only reorders what's already allowed | T8 |
| Magic moments | title, pattern, evidence, reframe, future-self line, hypothesis, strength; seeded into the portrait as tracked hypotheses | N10/N11 opening line, asked (K21) |
| Voices | three personas, one ElevenLabs voice id, different stability and style | T7; voice creation replaces the picker (K17) |
| Deleting | backend deletes the entry row; derived facts and answers are not retracted | J4 (K7) |
| Goals list | backend returns every column including lifecycle | G1 can show faded and merged from day one |

## Completeness check

**Read in full:** all 18 agent route files and every function they call that returns data to a person (conversation, corrections, search, briefs and both planners, podcasts v2 and the plan, hypotheses, people, settings, appetite and seed, learning, onboarding pipeline and job, arrivals, goals lifecycle, said-vs-did, the read contract, reference capture, actions ledger, spend guard, the elevenlabs personas); all 11 backend route files and their services; the users table across all migrations; every scheduled job in both services.

**Indexed, not read line by line, and why that's safe:** reading internals (ingestion agent, fact extractor, verify-span, supersession, promoter, trust, lint catalog, remediation, lineage), writer internals (claim guard, style), connectors' API details, evaluation and health tooling, legacy pipelines and prompts. None returns anything to the app directly; their effect reaches the app only through the routes above, whose outputs were read.

**Values that change at runtime (not unknowns about capability), and how the plan handles every value:**

| Value | Where it lives | Every possible value is designed for |
|---|---|---|
| Production switches (planners v1/v2, arrivals, onboarding pipeline, brief, appetite, learning, integration runtime, hypothesis dial) | Render environment | Each screen states its behaviour with the switch off and on (Part 3.9, K22, the "States" line of each screen). Phase G ships with the switches on for testers; until then the app reads the episode's `outline.planner` and shows "why this is here" only for v2 outlines |
| How much data a person has | the database, per person | Every screen has a day-one (thin) state and a full state; the planners refuse to pad; "too early to tell" is a designed state (Part 9) |
| Which sign-in providers have production credentials | `GET /integrations/readiness`, read by the app at runtime | Connect (N6, N7) and Sources (T3) render from the live catalogue and readiness, so a provider appears exactly when it works; nothing is hard-coded |

**What the backend can do for the app is fully accounted for**: every capability is in Part 3, every gap in Part 4, every module in Appendix A, every behaviour a screen depends on in Appendix B. Checking the Render switches and running one counts-only query (with the founder's okay) only confirms which states testers see first; it can't add a capability the code doesn't contain.

---

# Appendix 3. Module index: every module, and where this blueprint accounts for it

Agent (`retrospect-agent/src`, 178 modules, main `d4206a3`). Grouped; each group points to where it's covered.

| Group | Modules | Covered in |
|---|---|---|
| actions | ledger (classes: draft message, reminder, calendar hold, note; own-words origin rule) | 3.4, K6, J1 slot |
| agents | cook0 (portrait maintainer), fact-extractor, ingestion-agent (authorship), podcast-agent (legacy), tools (search graph, insights, observations, raw content, previous podcasts, identity inferences, internet research) | reading (3.1); legacy podcast path, not for the app |
| ambient | switch (master + per person; sent-only reading) | 3.1, N5, T5 |
| appetite | appetite (levels 0–3, rise/fall rules), seed (first guess from words) | 3.4, N9, T6 |
| brain | baseline-shifts, complete-document, daily-summaries (incl. usual offset), evidence-pack, lease, lineage, lint, lint-catalog, people (significance), place-events, portrait, promoter, pulls, record-patterns, remediation, run-promoter, run-trajectory, supersession, time-categories, trajectory, transcript-guard, trust, trust-stamp, verify-span, why, write-journal-facts | 3.3 (patterns, trajectories, shifts, time, people, portrait, timezone), lint and trust are invisible guards (No screen) |
| briefs | daily-brief, run-daily-brief, run-daily-brief-v2 | 3.5, J1, J2, P1, T2, K3 |
| connectors | gmail, google-calendar, google-docs, youtube, spotify, reddit, tiktok, x, linkedin, pinterest, archive-import, registry, oauth-http | 3.2, N6, N7, T3, K15 |
| conversation | reply (intents, silence allowed), rules (sentence budget, no restating) | 3.4, J1 |
| corrections | target, apply, retract (changed vs wrong) | 3.4, everywhere "not right" |
| db, health, eval, text, types, config, middleware | migrations, paging, schema check, health summary, evaluation, utilities | operations; not for the app |
| events | arrivals (read within minutes) | 3.1, switch |
| goals | lifecycle (merged, expired, revived) | 3.6, G1 |
| hypotheses | propose, validate (closed framework set), offer (dial, one per episode) | 3.4, P2, Y6 |
| imports | youtube-takeout | 3.2, N7, T3 |
| integrations | revoke (on account deletion), source-intelligence (per-source profiles) | 3.2, T9, K16 |
| jobs | daily-ingestion, weekly-podcast, daily-brief, material-arrivals, onboarding-pipeline, question-research, integration-scheduler, integration-worker | 3.9 switches, Part 8 |
| learning | reception (weights 0.8–1.2) | 3.4, T8 |
| onboarding | pipeline (stages), stated-goals | 3.8, N8, N10 |
| people | resolve, run-resolution (held pairs) | 3.3, Y6 |
| pipelines | ingest, claim-work, batch-outputs, after-reading, graph-v2, integration-sync/-evidence/-tests, legacy-shim/-writes, magic-moments, podcast, podcast-v2, retry-policy, social-research, spend-guard, trace, health-summary | reading and outputs (3.1, 3.5); magic moments and social research (3.8, K18); spend cap (No screen) |
| planner | plan (episode plan: spine, items, one question, withheld, silent), select (the bar), daily (inbox, today, resurfaced) | P2 "why this is here", J2 brief sections |
| prompts | cook0, current-context-outline, episode-summary, final-transcript, historical-agent, ingestion, magic-moments, notification | server-side; notification copy → X3 |
| questions | first-pass, research, run-first-pass, run-research, transcript, understanding | 3.8, Y5 |
| reference | capture, enrich, relevance, embed, youtube-transcript | 3.7, X1, Y3 |
| routes | all 18 | 3.1–3.8, 3.10 |
| search | search, answer, source | 3.4, Y2, Y3 |
| services | anthropic, openai, perplexity, elevenlabs (personas: one voice), embeddings, credential-vault, integration-queue, token-budget, telemetry, canonical-json | server-side; voice → K5, K17 |
| understanding | read (the contract), said-vs-did, answer-moves, content-groups | 3.3, K2, G1, Y1, Y5 |
| writer | write-episode, write-brief, claim-guard, style | outputs; the guards are invisible (No screen) |

Backend (`NPRdoinglaundry/backend/src`): **auth** (signin, refresh, dev test user — debug only), **content** (create, list, get, reprocess, delete), **goals** (CRUD, decline, extract, extract-and-save, synthesize), **podcasts** (list, latest, get, generate), **profile** (get, persona, personas), **speech** (synthesize), **integrations** (catalog, list, connections, readiness, native-connected, items, device-batches, imports, assets, connect start/callback, sync, reconnect, delete data, disconnect), **graph** (legacy assertion and entity feedback), **pipeline** and **claude** (legacy, removed from the app), **admin** (operations: users, backfill, goals, content, observations, insights, pipeline, diagnose, podcasts, stats). Services: agent-client, apple-auth, goals, insight-synthesis (legacy), integration-catalog, oauth-providers, observations (legacy), podcast-db, voice-personas. No scheduled jobs in the backend.

Database: 52 agent migrations (100–151) plus the base schema; the tables each feature reads are named in Part 3. `users` holds: id, apple_user_id, email, voice_persona, daily_brief_enabled, ambient_enabled (no timezone).

