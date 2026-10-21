# The new iOS app: opportunities (stage 2), draft for review

20 October 2026. Stage 2 of [the implementation plan](./ios-v2-implementation-plan.md#stage-2-map-every-capability-to-ui-the-opportunities). **Every capability the product now has, where it belongs, the UI it needs, and which audit findings it also fixes.** It's a draft: where it depends on an open question (the tabs, the number of questions, paywall timing), that's marked **▶ open**. It must meet the 14 constraints in [app-audit-research.md](./app-audit-research.md#the-constraints-acceptance-criteria-for-the-new-app).

**How each entry reads:**
- **Where:** onboarding step and/or app tab.
- **What it shows / lets you do.**
- **States:** first time, loading, empty, error, offline.
- **Server:** the agent or backend route behind it.
- **Fixes:** audit finding numbers.

---

## A. Onboarding (keeps the "asks a lot, understands you" character)

### A1. What this is
- **Shows:** the current promise in one breath: *"A brain that knows you. A podcast made from your life. A brief every morning. Search your own mind."* The mark, the paper canvas (`color.background.canvas`), the Hedvig display line.
- **States:** none (static).
- **Fixes:** W1, W2, W4.

### A2. Sign in
- **Shows:** Apple's standard Sign in with Apple button; "Continue with Google" also connects Google in one approval (ios-v2 change 11).
- **States:** in progress · failed (plain sentence + try again) · offline.
- **Server:** backend `/auth/*`.
- **Fixes:** W3, C5 (Google once).

### A3. The conversation (story questions)
- **Shows:** one question at a time, voice-first (type if preferred). After each answer, a short acknowledgement that proves it was heard; occasionally a "wondering". A real progress line ("3 of 8").
- **Questions:** to be redesigned (founder, 20 Oct) as the **highest-leverage set**: the questions with the best chance of filling in the most about the person beyond what integrations provide (ranked by how many of the 36 questions each answer moves), plus **goals and aspirations** asked so they feel inspiring to answer. Starting point: the 8 story questions ([brief](./brief-onboarding-questions.md)). **No** gender, orientation, age, dream house.
- **Behaviour:** each answer is saved the instant it's given (survives closing); Back works; it never asks what a connected source will tell it.
- **Feeds:** the 36 questions, goals, the appetite first guess.
- **Server:** onboarding `/advance`; answers stored as own words.
- **Fixes:** V1–V5, O1, O2, M3.

### A4. Connect (core, not optional)
- **Shows:** up to 5 recommended sources first (Health, Calendar, Google, Screen Time, Contacts), each with one sentence on **what it helps it understand** ("Calendar → the shape of your weeks"). "More sources" opens the rest. Plain states: *Connected · read just now* / *Couldn't connect: try again*. **One Google card.** No "Skip"; "Not now" per source.
- **Starts the first episode** in the background as soon as there's enough (decision in A8).
- **Not here:** file imports (ChatGPT, Claude, Netflix, YouTube history), which move to Sources later.
- **Server:** integrations, `/integrations`, the device batch upload.
- **Fixes:** C1–C10, M4.

### A5. Privacy, shown off
- **Shows:** three honest lines: *what it reads* (the sources you connected), *where it's processed* (Retrospect's servers and named AI providers), *what it never does* (no selling, no training on your data unless the provider policy says so; to be checked with the actual provider terms). The **ambient switch** ("Read your connected apps in the background") and "delete everything anytime".
- **Server:** settings `/ambient`; backend revoke and delete.
- **Fixes:** D1, V2, M6.

### A6. How bold
- **Shows:** the four levels in plain words, **our pick preselected** from their words so far, with its reason ("you said you want to be challenged"). One tap to change.
- **Server:** settings `/appetite` (`suggested`).
- **Fixes:** goal 22 (founder's design).

### A7. Your voice
- **Shows:** a few questions about what they listen to and watch → a voice made for them; a sample line read in it.
- **Server:** voice creation (to build: ios-v2 lists it as needed server work).
- **Fixes:** P1, P2.

### A8. Your first podcast
- **Shows:** if it's ready, it plays immediately; if not, honest stages ("reading your calendar… writing… recording your voice") with what's already true about them shown while they wait (a line from their answers).
- **Needs:** the agent's existing onboarding pipeline (read → first pass → episode, `/onboarding/readiness`), started at A4 instead of after the last screen. No new server, only `ENABLE_ONBOARDING_PIPELINE` and the app calling it early. Episode length: measure first.
- **States:** ready · in progress (real stages) · failed (plain words, retry, "we'll make it tonight").
- **Server:** onboarding `/readiness/:userId`, podcasts.
- **Fixes:** A1, A3, A5, E1, M2.

### A9. The reveal
- **Shows:** after **30–40 s** of the first episode (▶ **open:** which), the buttons slide up (`motion.duration.reveal` 1.22 s): the sky glow (subscribe) and the cream secondary.
- **Server:** subscriptions (StoreKit).

### A10. Into the app
- **Shows:** Home, with the episode in its place and the first thing worth doing ("Tell me about today").
- **Fixes:** A3.

---

## B. The app: bottom bar **Home · Podcasts · Search · You** (founder, 20 Oct); everything else deeper, placement for the founder to approve

### B1. Home: your day
| Capability | UI | Server | Notes |
|---|---|---|---|
| **Capture** (journal) | a voice-first "Tell me…" field at the top; type too | backend `/content` with an outbox | every entry shows sent / read by the brain (J1–J3) |
| **Today's brief** | the brief card: audio and text, each item with "why this is here"; off by default (ios-v2) | briefs `/latest` | inbox-first: what you sent comes back |
| **Talk to it** | the same field becomes a conversation; replies may be silent; the thread for today | conversation `/`, `/today` | goal 18 |
| **Things waiting on you** | a small stack: a question it's asking (hypothesis), a "same person?" card, an action to approve | hypotheses, people `/held`, actions | each is one tap |

### B2. Podcasts: your episodes
| Capability | UI | Server |
|---|---|---|
| **This week's episode** | the hero card; tap to play | podcasts `/latest` |
| **Player** | transcript with the current line, chapters, speed; "why this was in it" (the plan's spine and items) | episode outline |
| **A question in the episode** | the asked line becomes a Yes / No / "why do you think that?" card under the player | hypotheses `/:id`, `/why` |
| **Past episodes** | a list | podcasts |

### B3. Search: your whole mind
| Capability | UI | Server |
|---|---|---|
| **Ask anything** | one field; sources appear first (~1 s), then "what we found" with numbered citations | search `/sources`, `/answer` |
| **Open a source** | full entry, email, doc or saved link | search `/:userId/source/:kind/:id` |
| **Saved links** | a "Saved" filter: each with your reason, and its transcript for videos | reference items |
| **Correct from here** | "that's not right" on any line of the answer | corrections |

### B4. You: what it knows
| Capability | UI | Server |
|---|---|---|
| **What I know about you** | the answers by area: how sure, and **why** (tap → the quote it rests on); silent areas said warmly ("I don't know much about your days yet") | read contract (new endpoint, ios-v2 §3) |
| **Corrections** | "not me / still true" on every answer; "that's wrong" in plain words anywhere; asks before overwriting your own words | corrections `/`, `/confirm` |
| **Goals** | active, expired, merged (the brain's view); what you said vs what you did, as two numbers; say a new one | goals (server-owned; G1–G3) |
| **Patterns** | what keeps happening, getting stronger or weaker | read contract |
| **People** | the people in your life; "same person?" questions | people |
| **What it's wondering** | hypotheses offered, with their framework; yes/no | hypotheses |
| **How bold** | the ladder, visible and changeable | settings `/appetite` |
| **What it's learned** | how often you answer each kind of question (transparency) | settings `/learning` |
| *(option)* **Constellation** | the brain as a graph (ios-v2 option), after people are clean | read contract |

### B5. Settings (behind your profile)
| Capability | UI | Server |
|---|---|---|
| **Sources** | each: last read, what it read, what it's for; reconnect; import files (YouTube history, ChatGPT…) here | integrations; Takeout import |
| **Privacy** | the A5 page again; the ambient switch; delete my data / account | settings `/ambient`; revoke |
| **Actions** | the ledger: what it prepared, approve / undo; what it may do on its own (standing authorisations) | actions |
| **Voice, brief, subscription, account** | standard | — |
| **Nothing for developers** | dev tools only in debug builds; team tools by server role (T1–T6) | — |

### B6. Everywhere
- **Share to Retrospect** (share extension): "Why are you saving this?" → saved with the reason (goal 23).
- **Notifications:** the brief is ready; the episode is ready; something to approve, with deep links to the right screen.
- **Widget / Live Activity:** capture, now playing.

---

## C. What this also fixes (the cross-check)

Every blocker and major finding has a home in this map:

| Finding | Fixed by |
|---|---|
| A1, A3, A5, E1 | A8 (honest first episode) + A10 |
| J1–J3, R1 | B1 capture with an outbox |
| G1–G3 | B4 Goals (server-owned) |
| T1–T6, R2 | B5 "nothing for developers" + the demo account |
| W1–W4 | A1, A2 |
| V1–V5 | A3 |
| C1–C10 | A4 |
| D1, V2 | A5 |
| P1–P2 | A7 |
| O1–O2 | A3 behaviour (Back, save per answer) |
| X1, X3, J6 | every screen's error state; server-owned prompts |

**Server work this map needs that doesn't exist yet:**
- a "what I know about you" read endpoint;
- the read contract for patterns and goals;
- voice creation;
- first-episode readiness that starts at Connect;
- feature endpoints to replace the prompt proxy;
- a staff role for team tools.

---

## Open questions (carried from the plan)
1. The tabs: Home · Podcasts · Search · You, with Settings behind the profile? Or conversation as its own tab?
2. How many story questions?
3. Paywall at 30 or 40 seconds?
4. A shorter first episode (~3 min) so it's ready inside onboarding?
5. Sign-in for the audit walk-through (a test Apple ID is recommended; it becomes the demo account).
