# App audit: research on the findings (stage 1b)

20 October 2026. Stage 1b of [the implementation plan](./ios-v2-implementation-plan.md#stage-1b-research-each-finding-where-the-logic-breaks-and-why). For each blocker and major finding in [app-audit.md](./app-audit.md): the root cause, what the person experiences, the principle it breaks, what good looks like, and the **constraint** the new app must meet, written as a testable rule. The constraints become acceptance criteria for the new app.

**Status:** the 5 blockers and all 29 majors are done (the majors grouped into 9 themes).

---

## B1 (A1): A failed first podcast is silent

| | |
|---|---|
| **Root cause** | `startFirstPodcastHandoff` catches the error, stores it in `firstPodcastError`, and immediately calls `finishFinale()`. Nothing ever reads `firstPodcastError`. The code treats "end onboarding gracefully" as hiding the failure |
| **What the person experiences** | They finish 18 questions, connect their sources, pick a host, tap "Play Podcast", watch "Learning about you" for minutes, then land on an empty home screen with no podcast and no word about why. The peak of onboarding becomes its lowest point |
| **Principle** | *Visibility of system status* (Nielsen's first heuristic): the system should always tell people what's going on. And *peak–end* (Kahneman 1993): people remember the peak and the end, and here both are failures |
| **What good looks like** | Say what happened in plain words, keep what was done, offer the next step: "Your first episode didn't finish. Your answers are saved. Try again now, or we'll make it tonight and tell you." |
| **Constraint** | **Every failure after a wait is named in plain words, with a retry or a promise, and nothing the person did is lost. No failure path lands silently.** |

## B2 (J1): A failed journal upload is lost silently

| | |
|---|---|
| **Root cause** | `syncEntryToBackend` fires once in a background task; a failure is only `print`ed. The `Entry` model has no synced state, so nothing knows to retry; no queue exists |
| **What the person experiences** | They write; it looks saved (it is, on the phone). But the brain never receives it: it's missing from episodes, the brief and search, with no way to tell. Trust erodes invisibly: "it doesn't know what I told it" |
| **Principle** | *Durable writes and eventual consistency:* standard offline-first design keeps an outbox and retries with backoff until the server confirms (the pattern used by Notes, Day One, Things). Plus visibility of system status |
| **What good looks like** | Every entry has a state: saved on the phone → sent → read by the brain. A small mark shows it. Failed sends retry automatically (with backoff, and on reconnect); after a long failure, one quiet notice |
| **Constraint** | **Nothing written is ever lost: every capture is queued until the server confirms it, retried with backoff, and its state is visible. Editing re-sends. One upload per capture (no double writes).** Also covers J2, J3, R1 |

## B3 (G1): The phone's goal list overrides the brain

| | |
|---|---|
| **Root cause** | Two sources of truth. The app treats its local list as authoritative and reconciles the server to it on every change: it re-activates whatever the server turned off, and turns off whatever the phone doesn't know |
| **What the person experiences** | Goals they stopped mentioning keep coming back; duplicates pile up (31 "active" from June); episodes are built on goals that aren't theirs any more. The brain's "goals expire when you stop living them" can't work |
| **Principle** | *A single source of truth* for each piece of state; client changes as intents ("I added X", "I removed Y"), never "replace the server with my list" |
| **What good looks like** | The server (the brain) owns goals; the app shows the server's view (active, expired, merged, said-vs-did) and sends only what the person did |
| **Constraint** | **The server owns goals. The app sends only intents (add, rename, turn off, revive) and never reconciles by overwriting. The person always sees the brain's view.** *(The server half is fixed: NPRdoinglaundry#19.)* |

## B4 (T1): Every user can open Dev tools

| | |
|---|---|
| **Root cause** | Development tools were added to the shipped Settings screen behind a user-visible "Advanced" row and a "Dev Mode" toggle stored in `@AppStorage`, not behind `#if DEBUG` or a server-side staff flag |
| **What the person experiences** | A curious person finds "Dev tools and experiments", flips Dev Mode, and can generate mock podcasts, replay onboarding, open a fake old home screen, and trigger real podcast generations (real cost) |
| **Principle** | *Separate builds or accounts for development* (a staging build, TestFlight, or staff-only flags). Apple's review guidelines also reject apps with visible test or debug features (Guideline 2.2: "beta versions … should be submitted to TestFlight") |
| **What good looks like** | Dev tools exist only in debug builds; anything needed in production for the team is gated by a server-side staff flag on the account (the **demo account** idea) |
| **Constraint** | **A release build contains no developer tools, mock data paths or previews. Team-only tools are gated by a server-side staff role, never a toggle on the device.** Also covers T2–T6, R2 |

## B5 (T2): A fake home screen with made-up podcasts is reachable

| | |
|---|---|
| **Root cause** | A legacy home screen with a hard-coded `mockPodcasts` array was kept for comparison and wired to a Settings button |
| **What the person experiences** | "Love and Relationships", "Career Growth"…, episodes about a life that isn't theirs, inside a product whose whole promise is "about you". It breaks the product's core trust at the root |
| **Principle** | *Honesty of content* (goal 4: never claim beyond evidence). Fabricated personal content is the opposite of the product |
| **What good looks like** | Sample content lives only in the demo account and is labelled as such; the ship build never contains canned personal content |
| **Constraint** | **No canned personal content in the ship build. Anything shown as "yours" comes from the person's own data; demo content lives only in the labelled demo account.** Also covers A5, A6, T3 |

---

## Major findings, by theme

### M1. Labels that promise what they don't do (C1, E1, W1)
- **Root cause:** buttons named for the outcome the team hoped for, not what they do. "Make my podcast" advances to the host picker; "Play Podcast" starts minutes of generation; the welcome sells the old product.
- **Experience:** each tap breaks a small promise right before the biggest moment, so by the peak the person has learned the labels lie.
- **Principle:** *Match between system and the real world* (Nielsen #2); labels describe the action, not the hope.
- **Constraint:** **Every button says exactly what happens next. A promise of an outcome ("play", "make") appears only when that outcome is immediate.**

### M2. Waits that aren't honest (A3, A5)
- **Root cause:** a fake percentage (asymptotic creep to 95%) covers an unknown generation time; onboarding is marked complete before the episode exists.
- **Experience:** "Learning about you 94%" for minutes; then, if the app was closed, nothing.
- **Principle:** Maister (1985): uncertain and unexplained waits feel longer. Nielsen: status must be true. Research on progress indicators (Myers 1985; Harrison et al. 2007) finds false progress damages trust when it stalls.
- **What good looks like:** real stages ("reading your calendar… writing… recording the voice"), start the work early (at Connect), and keep the person busy with something meaningful.
- **Constraint:** **No progress number that isn't real. Every wait over 3 s names its real stage. Long work starts as early as possible and survives the app closing.**

### M3. Asking too much, too soon, the wrong things (V1–V5, C4)
- **Root cause:** a form of demographics first (18 questions; sexual orientation without purpose; a dream house at the end) and 17 sources at once.
- **Experience:** it feels like a sign-up form before it feels like being understood; sensitive questions arrive before trust; choice overload at Connect.
- **Principle:** reciprocity and trust before ask; Hick's law (more options, slower and worse decisions); peak–end (end on the deepest moment, not a quiz); data minimisation (collect only what has a use).
- **What good looks like:** the 8 story questions ([brief](./brief-onboarding-questions.md)), voice-first, each one acknowledged so understanding is felt; a few recommended sources first, the rest behind "more".
- **Constraint:** **Every onboarding question has a stated use. Nothing sensitive without a reason the person can see. Connect shows at most 5 recommended sources up front. Onboarding ends on its strongest moment.**

### M4. Connections that don't explain themselves (C2, C5, C6, C8)
- **Root cause:** the screen mirrors the backend's model (one card per provider object; engineering status words; file importers mid-flow); Google is hard-coded never "connected".
- **Experience:** "Google Docs" and "Gmail" and "YouTube" as three asks for one sign-in; "API-tier gated sync" as a label; no idea what anything is for.
- **Principle:** speak the person's language; one action per intent; show value before asking (permission priming).
- **What good looks like:** one Google card ("Google: your docs, mail, calendar and YouTube"); each source says what it helps the brain understand; states in plain words ("Connected · read 2 min ago"); file imports offered later, not in onboarding.
- **Constraint:** **One card per account the person signs into. Every source states, in a sentence, what it helps it understand. States use plain words. No file imports in onboarding.**

### M5. Sign in with Apple styling (W3)
- **Root cause:** a custom-styled button (cream, grey label).
- **Risk:** App Review rejection and low contrast.
- **Principle:** Apple's HIG for Sign in with Apple (approved styles, minimum sizes and contrast).
- **Constraint:** **Use Apple's standard button (or the HIG's permitted custom form) with sufficient contrast.**

### M6. Privacy said wrongly, or not at all (D1, V2)
- **Root cause:** old copy claiming on-device processing (false); a sensitive question with no purpose; no privacy step on the live path.
- **Experience / risk:** in the dead code, a false promise waiting to be revived; on the live path, nothing that earns trust for the asks.
- **Principle:** *contextual integrity* (Nissenbaum): say what flows where, for what. Data minimisation. Apple's privacy expectations.
- **What good looks like:** the founder's "show off the privacy" step: what it reads, where it's processed (honestly: our server and named AI providers), what it never does, the ambient switch, delete anytime.
- **Constraint:** **Every privacy statement is true and specific. The privacy step names what's read, where it's processed and how to turn it off or delete. No question asks for sensitive data without a visible use.**

### M7. No way back, nothing saved within a step (O1, O2)
- **Root cause:** one-way step flags; per-answer state kept only in memory.
- **Principle:** user control and freedom (Nielsen #3); save as you go.
- **Constraint:** **Every onboarding step can go back. Every answer is saved the moment it's given and restored on reopen.**

### M8. Raw errors and a general prompt proxy (X1, X3, J6)
- **Root cause:** errors are passed straight from the network layer to the screen; AI prompts are written in the app and sent to a general proxy.
- **Principle:** error messages in plain language that say what to do (Nielsen #9); server-side ownership of prompts (security, cost and consistency).
- **Constraint:** **No raw error text reaches the screen; every error has a plain sentence and a next step. The app never sends AI prompts; each feature calls its own server endpoint.**

### M9. The brain's view never reaches the person (G3, host P1–P2, Podcasts dev R2)
- **Root cause:** the app shows its own local state (its goals list, its host choice) rather than what the brain knows; capabilities built on the server have no screens.
- **Principle:** the app is the brain's window (ios-v2 §3).
- **Constraint:** **Every capability the brain has is visible where it belongs (stage 2's map), with how sure it is and why, and is correctable.**

---

## The constraints (acceptance criteria for the new app)

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
