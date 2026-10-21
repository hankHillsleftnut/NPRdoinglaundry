# The new iOS app: implementation plan and spec

20 October 2026. How everything in [ios-v2.md](./ios-v2.md), [the app audit](./app-audit.md) and the core product becomes the new iOS app. The founder's sequence: **audit → research the problems → map every capability to UI → product structure (onboarding + a bottom-bar app) → components → end-to-end journeys → stop and write the build spec.** This document is that plan, with each stage's spec detailed enough to execute. The build itself comes after.

**One-page board** (every screen with its problems, ship vs developer, rules, opportunities, iOS v2 ideas): https://claude.ai/artifact/9uf2mRH9rk9RKneh4XrQDb

Companion docs: [ios-v2.md](./ios-v2.md) (what's been asked and found) · [app-audit-plan.md](./app-audit-plan.md) / [app-audit.md](./app-audit.md) (stage 1) · [design-system-plan.md](../design/design-system-plan.md) + [tokens](../../design-system/tokens/README.md) · [goal-specs.md](./goal-specs.md) (what the product must do).

---

## 0. Where we are

| Input | State |
|---|---|
| Core product (the brain) | ~83% of the goal spec; phase F built and merged |
| Design tokens | v1 built: 272 tokens, 202 semantic, validated ([README](../../design-system/tokens/README.md)) |
| Audit of the current app | **In progress:** about 50 findings so far (code and static passes + screen 1 in the simulator). The walk-through past sign-in is blocked on an account decision (question 1) |
| Components, journeys, new app | not started (this plan) |

**The shape the founder wants:**
- **Onboarding keeps its character:** it asks a lot, it understands you, it asks good questions.
- It also signs you in, connects your sources, shows off the privacy, and delivers your first podcast inside onboarding itself.
- After 30–40 seconds of listening, the paywall rises.
- Then you're into the app.
- The app has a bottom bar: a home where you journal, a place for podcasts, a place to search the whole brain, and places for every other capability to show off.

---

## Stage 1: Audit the current app (the problems)

**Goal:** every logic problem and every place the app breaks, in every phase. Method: [app-audit-plan.md](./app-audit-plan.md) (five passes per screen: purpose, interaction, pixel, code, psychological). Findings so far: [app-audit.md](./app-audit.md).

**Blockers found so far** include:
- dev tools anyone can open in Settings, which reach mock podcasts and fake episodes;
- a failed first podcast is completely silent;
- a fake progress bar that never finishes;
- the same Google account split into three cards, one of which can never show as connected;
- "Make my podcast" and "Play Podcast" buttons that don't do what they say;
- sexual orientation asked in onboarding with no purpose;
- false privacy claims in dead code;
- a general AI-prompt proxy on the server.

**To finish stage 1:**
1. Walk every screen in the simulator, with every state and edge path (needs question 1).
2. The code pass on Journal, Podcasts, Goals and Entries, plus the player and the recorder.
3. Re-check the ~25 problems logged earlier.
4. The demo/fake inventory, each item marked remove, demo account, or replace.
5. The psychological journey map.

**Output:** `app-audit.md` complete, with a ranked list (blocker, major, minor).

### Stage 1b: Research each finding (where the logic breaks, and why)

For every blocker and major finding, one short research card:

| Field | Content |
|---|---|
| **Root cause** | the exact code path or decision that produces it (not the symptom) |
| **User impact** | what the person experiences, in one line, and where in the journey |
| **Principle** | the established practice or research it violates. Examples: Apple's HIG (Sign in with Apple, permissions), Nielsen's visibility of system status, Maister on waits, peak–end, Hick's law, contextual integrity for privacy |
| **What good looks like** | how strong apps handle the same moment (e.g. honest progress, permission priming, one Google sign-in) |
| **Constraint** | what the new app must guarantee, written as a testable rule (e.g. "no wait over 3 s without an honest reason; no percentage that isn't real") |

These constraints become acceptance criteria in stages 3–5. **Output:** `app-audit-research.md`.

---

## Stage 2: Map every capability to UI (the opportunities)

**Goal:** every capability the product now has gets an appropriate place, in onboarding (what it must *learn*) and in the app (what it must *show* and *let you do*).

### 2.1 What the brain now does, and what it needs from the app

| Capability (goal) | Server (agent routes) | Needs from onboarding | Needs in the app |
|---|---|---|---|
| **Weekly episode** (11–16) | podcasts `/generate`, latest | voice, goals, sources, appetite | Podcasts tab; player with transcript; "why this was in it" |
| **First podcast** (24) | onboarding `/advance`, readiness | story answers, sources | inside onboarding: the reveal, then the paywall |
| **Daily brief** (11, 13) | briefs `/latest`, `/generate` | opt-in (off by default) and timing | Home: today's brief, audio and text; "why this is here" |
| **Search the brain** (6) | search `/sources`, `/answer`, source | — | Search tab: "what we found" + sources, each openable |
| **Saved links and reasons** (23) | captured from shares; transcripts | — | share extension "why are you saving this?"; Saved inside Search; resurfaced in the brief |
| **What it knows about you** (10) | understanding read contract | the story questions (most of the 36) | You tab: answers, how sure, why; silent areas said warmly |
| **Corrections** (20) | corrections `/`, `/confirm` | — | "not me / still true" on any claim; correct in plain words anywhere; asks before overwriting your own words |
| **Conversation** (18) | conversation `/`, `/:userId/today` | — | talk to it from Home (voice or text); silence allowed; continuity across the day |
| **Hypotheses** (21) | hypotheses `/:id`, `/why` | appetite seed (own words) | asked in episodes and conversation; Yes/No in one tap; "why do you think that?" |
| **Appetite** (22) | settings `/appetite` | **onboarding shows the options with our pick preselected** (founder) | You → "How bold": the ladder, visible and changeable |
| **Style** (9) | (writer) | how you like to be spoken to | — (it's in the voice) |
| **Lint and freshness** (5) | (server) | — | nothing stale is shown; corrections close things |
| **Learning from itself** (19) | settings `/learning` | — | You → "What it's learned about asking you" (transparency) |
| **People** (W2) | people `/held` | contacts permission | "Is the Sam in your writing Sam Ortiz?" cards; people in You |
| **Patterns and change** (25) | (read contract) | health, calendar | You and episodes: patterns with "getting stronger / weaker" |
| **Said vs did** (8) | (read contract) | goals | You → Goals: what you said, what you did, two numbers |
| **Goals** (7) | goals lifecycle | the goals voice note | You → Goals: active, expired, merged; say a new one |
| **Acting for you** (17) | actions `/`, `/:id` | — | approval cards (draft-only); a ledger with undo |
| **Ambient switch** | settings `/ambient` | the privacy step explains it | Settings: "Let Retrospect read your connected apps in the background" |
| **Sources and imports** (1, 2) | integrations; Takeout import | **connect as a core step**; one Google sign-in | Sources: last read, what it read, what it's used for; YouTube history import |
| **Privacy** (contextual integrity) | ambient, revoke, delete-data | **show it off** | a Privacy page: what's read, where it's processed, what's never done; delete my data |

### 2.2 What onboarding must collect

| The brain needs… | Asked as… | Feeds |
|---|---|---|
| who you are, what you want, what's in the way | **8 story questions**, voice-first, one follow-up each ([brief](./brief-onboarding-questions.md)) | the 36 questions, goals, the appetite seed |
| your current goals | inside the story questions, plus an optional goals note | goals, said-vs-did, episode spine |
| how bold to be | **the appetite options, our pick preselected** | appetite |
| audio or reading | one tap | brief and episode format |
| your voice | a short voice conversation → a voice made for you (ios-v2 change 7) | episodes |
| your sources | the Connect step (core, not optional) | everything |
| consent and understanding | the Privacy step | the ambient switch, trust |

**What *not* to ask:**
- demographics with no use (gender, orientation, dream house);
- anything the sources will tell it anyway.

**Output:** `ios-v2-opportunities.md`. For every capability: where it lives, what UI it needs, and which audit findings it also fixes.

---

## Stage 3: Product structure (onboarding + a bottom-bar app)

### 3.1 Onboarding: the founder's sequence

Every step has a purpose you can see before reading a word, saves as you go, and has a way back.

| # | Step | What happens | Fixes |
|---|---|---|---|
| 1 | **What this is** | the *current* promise: a brain that knows you, a podcast made from your life, a brief each morning, search your own mind | W1 |
| 2 | **Sign in** | Apple (Google sign-in also connects Google, ios-v2 change 11) | W3, C5 |
| 3 | **The conversation** | the story questions, voice-first; it understands you as you go (short acknowledgements and wonderings); answers saved per answer | V1–V5, O2 |
| 4 | **Connect** | presented as core; each source says *what it helps it understand* ("Calendar → the shape of your weeks"); one Google card; plain states; no "Skip"; unbuilt sources hidden | C1–C10 |
| 5 | **Privacy, shown off** | what it reads, where it's processed, what it never does; the ambient switch; delete anytime. Honest (unlike the dead code's claims) | D1, trust |
| 6 | **How bold** | the appetite options with our pick preselected, from your words | goal 22 |
| 7 | **Your voice** | a short voice conversation → a voice made for you | P1, P2 |
| 8 | **Your first podcast** | generation **starts at step 4** (as soon as there's enough), with honest progress; ready by now; it plays inside onboarding | A1, A3, A5, E1 |
| 9 | **The reveal** | after 30–40 s the buttons slide up: the paywall (1.22 s reveal, the design system's signature) | the reference moment |
| 10 | **Into the app** | lands on Home with the episode there, and what to do next | O1, A3 |

**Rules:**
- one episode per onboarding, never two;
- no fake progress;
- every wait says what it's doing;
- a failed episode is told plainly, with a retry.

### 3.2 The app: bottom bar

Proposed tabs (question 2):

| Tab | Purpose | Holds |
|---|---|---|
| **Home** *(decided)* | your day | capture (journal by voice or text) · today's brief · talk to it · what's new (a held person, a question it's asking, an action to approve) |
| **Podcasts** | your episodes | this week's episode, player, transcript, past episodes, "why this was in it" |
| **Search** | your whole mind | ask anything; "what we found" + sources; saved links |
| **You** | what it knows | answers (how sure, why), goals and said-vs-did, patterns, people, what it's wondering; correct anything; how bold; what it's learned |
| *(profile or Settings)* | control | sources, privacy and ambient, voice, subscription, account, delete |

**Every screen gets a page spec:**
- purpose (visible before reading);
- content;
- actions;
- every state (loading, empty, error, offline, first-time);
- the server route behind it;
- the tokens and components it uses;
- the audit findings it closes.

**Output:** `ios-v2-structure.md` with every onboarding step and every app screen specified this way.

---

## Stage 4: Components

From the design system's plan, [Part 2](../design/design-system-plan.md#part-2-components-the-large-pass-after-tokens): foundations (glow and cream buttons, mono labels, the mark, grain and rim), inputs, display, audio (mini-player, scrubber, transcript, episode row, brief item), brain (answer card, source row, silent area, correction receipt, question card, same-person card, appetite ladder), conversation, actions, search, onboarding (story question, connect card, voice maker, first insight). **Built only from tokens.**

**For each component:**
- every state, light and dark;
- Dynamic Type and VoiceOver;
- a "when to use it" paragraph;
- which screens use it.

**Output:** `ios-v2-components.md`, the inventory mapped screen by screen, so nothing is built that no screen needs and no screen needs something unbuilt.

---

## Stage 5: Journeys (the whole product, end to end)

Each journey is written step by step: screen → action → what the server does → what the person sees and feels, with the waits, errors and edge paths.

1. **First run:** install → onboarding → first podcast → paywall → Home.
2. **A normal day:** morning brief → capture a thought → share a link with a reason → talk to it in the evening.
3. **The weekly episode:** it arrives → listen → a question it's asking → answer "no" → it eases off.
4. **Search:** ask → sources → open one → correct something it got wrong.
5. **Correction:** "that's wrong" from an episode line, from You, from conversation.
6. **People:** "Is the Sam in your writing Sam Ortiz?" → same/different.
7. **Acting:** "draft a note to Priya" → approve → it's prepared, never sent by itself.
8. **Sources:** connect later, reconnect expired, import YouTube history, revoke and delete data.
9. **Privacy:** turn ambient off, see what changes, delete my account.
10. **Subscription:** paywall → purchase → restore → lapse.
11. **Failure paths:** offline, server asleep, generation fails, permission denied.
12. **Demo vs ship:** the same build, with a staged demo account.

**Output:** `ios-v2-journeys.md`.

---

## Stage 6: Stop, then write the build spec

When stages 1–5 are approved, they're combined into one **build spec** (`ios-v2-spec.md`): the new app project, screen by screen and component by component, with acceptance criteria from the stage 1b constraints, in build order. **Building starts only after that spec is approved.**

---

## Order, owners and approvals

| Stage | Output | Your approval |
|---|---|---|
| 1 | app-audit.md (complete) | read the ranked list |
| 1b | app-audit-research.md | — |
| 2 | ios-v2-opportunities.md | yes/no on where each capability lives |
| 3 | ios-v2-structure.md | the onboarding sequence and the tabs |
| 4 | ios-v2-components.md | the component inventory |
| 5 | ios-v2-journeys.md | each journey |
| 6 | ios-v2-spec.md | **go to build** |

---

## Founder's answers (20 Oct, late)

1. **Audit sign-in:** the founder will sign into the simulator once with a test Apple ID (their own also fine). The test ID becomes the demo account.
2. **Tabs:** the bottom bar holds the core: **Home (journal + talk to it) · Podcasts · Search · You.** Everything else exists but lives deeper (settings behind the profile); the founder approves the final placement.
3. **Onboarding questions:** design the **highest-leverage** set: the questions most likely to fill in the most about the person *beyond what the integrations will tell us*. Plus **goals and aspirations** asked so the answers feel inspiring to give ("what do you care about, what do you want out of life"). A research task, added to stage 2.
4. **The first podcast inside onboarding:** *correction:* no new server needed. The agent already has an onboarding pipeline (read → first pass → episode) with a readiness endpoint, switched off (`ENABLE_ONBOARDING_PIPELINE`). The change is the app starting it at Connect. The constraint is only time (an episode takes minutes), which is why it must start early. Whether a shorter first episode is needed: measure once it runs.
5. **The audit covers both a UI audit and a product audit,** reported separately.

## Questions (originally)

1. **How do I get past sign-in for the audit?** Production (correctly) blocks the test-user button. Options:
   - (a) you sign into the simulator once with your Apple ID (your data stays in private screenshots);
   - (b) I run a local copy of the server in development mode against a **separate test database**, which takes setup but touches nothing real;
   - (c) a test Apple ID you create and sign in once.

   I'd recommend **(c)**: it becomes the demo account.
2. **The tabs:** Home · Podcasts · Search · You, with Settings behind your profile? Or should conversation be its own tab?
3. **Onboarding length:** how many story questions feels right to you, given the onboarding brief proposes 8?
4. **Paywall timing:** 30 or 40 seconds into the first podcast?
5. **The first podcast inside onboarding** needs generation to start early (at Connect) and finish within onboarding. That's a server change. Should the target be a shorter first episode (about 3 minutes) so it's ready in time?
