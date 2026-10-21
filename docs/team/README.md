# The team plan: building the new Retrospect app

This folder is how four engineers (two agents and an integrator) build the new Retrospect iOS app together, fast, without lowering the bar. Every agent reads this file and [context.md](./context.md) first, then their own plan. The founder reviews and approves this plan before anyone starts.

| File | Who it's for |
|---|---|
| [README.md](./README.md) (this) | everyone: the big picture, the rules, the phases, the decisions |
| [context.md](./context.md) | everyone: the shared context pool, kept current by the integrator |
| [board.md](./board.md) | everyone: who is doing what right now (the integrator edits it) |
| [contracts/](./contracts/README.md) | everyone: the agreed data shapes between app and backend |
| [testing.md](./testing.md) | everyone: how we know the app behaves (every PR's tests, the T bytes, CI) |
| [reference/](./reference/) | everyone: field-level truth about the agent, backend, app and design specs (21 Oct) |
| [integrator.md](./integrator.md) | the integrator (the main Claude session) |
| [first-ship.md](./first-ship.md) | everyone: **what's in Beta 1 and what waits; overrides every plan** |
| [trust-ladder.md](./trust-ladder.md) | everyone: why mistakes become checks, not rules |
| [ui-engineer.md](./ui-engineer.md) | the app engineer: view cards |
| [backend-engineer.md](./backend-engineer.md) | the backend engineer agent |
| [app-plumbing-engineer.md](./app-plumbing-engineer.md) | the app engineer: Platform cards |

## 1. The big picture

**What we're building.** Retrospect is "a companion that knows you and helps you grow": ambient by default, it reads what you connect and what you say, keeps facts tied to your words, notices patterns only after repetition, asks rather than asserts its guesses, and turns it all into a daily brief and a weekly episode you listen to. The new app is a thin client over a brain that already exists: "no intelligence in a client, ever; offline is a cache of what the server already said."

**Where we are (21 Oct).** The design is done: 37 screens approved in Paper, a full design system in tokens. The brain (the agent service) already does most of what the designs show. The new app's foundation and about a third of its components are built to the founder's bar. What's missing is the middle: the backend doesn't yet expose the brain to the app, the app has no modern plumbing (typed client, offline store, push, payments), and no screen is built yet.

**The shape of the system.**

```
 iOS app ─────────────── Features/<flow>  (screens, app engineer)
   │                        │ reads only a flow protocol
   │                     Platform/        (client, session, store, outbox, push, purchases: app engineer)
   │  HTTPS, /v2 doors, a 15-minute token
 backend (Express, Render) ── doors: auth → user from token → owns it? → limits → forward → map → log
   │  private network, shared secret                                       (backend engineer)
 agent (Express, Render, private) ── the brain: conversation, briefs, guesses, search, facts, podcasts
   │                                                                       (backend engineer)
 Supabase Postgres + storage
```

**The plan in one sentence.** Build the journal first as one complete slice through every layer (it's the core product and exercises almost every system), then the other six flows the same way, each joined at a ship gate where the founder signs off and the old screens are deleted.

## 2. The team

**Decided 21 Oct (founder): two engineers, split the way that's easiest to manage and gives the highest quality fastest.** That split is by repo: one engineer for the app, one for the server side.

| Role | Who | Owns | Never touches |
|---|---|---|---|
| **Integrator** | the main Claude session | contracts, shared files (tokens, RType, RDepth, RMotion, the lab, the app shell, workflows, lint config), the board, every review, every merge, the founder conversation | nothing is off-limits, but it writes product code only in shared files |
| **App engineer** | agent | the whole iOS app: `DesignSystemV2/Components`, `Parts`, `Features/<flow>`, `Platform/`, sample and live data, tests, entitlements. Works from both card sets: [ui-engineer.md](./ui-engineer.md) (views) and [app-plumbing-engineer.md](./app-plumbing-engineer.md) (Platform) | backend, agent, shared files |
| **Backend engineer** | agent | `backend/`, backend migrations, the whole agent repo | the app |

**Why by repo, not by layer.** With UI and plumbing as two agents inside one app, every journal page needs a hand-off: one agent builds the view on sample data, the other the live data, then I wire them together. Three PRs, two agents waiting on each other, and two agents queuing for one simulator and filling one disk. One app engineer builds a page from view to live data, so the seam disappears, and there's never a fight over the simulator. The backend engineer never opens Xcode, so the two can run **at the same time** without touching the same files or the same disk. The contracts are still the line between them.

**The cost, and how it's handled.** One agent holds a bigger slice of the app in its head. Byte cards keep each task self-contained, and the app engineer is restarted fresh at each phase with a short handover note (README §8 reports carry the state).

**Why not more.** Throughput is limited by review and the one CI runner, not by how many agents type. Two engineers in separate repos is the most parallelism that never collides.

## 3. The first principle: big picture down to small parts, for everything

Founder, 21 Oct: every piece of work, for every agent, is broken down the same way: **start from the big picture, break it into flows, then pages, then components, then sub-components, and each smallest part is one small PR.** Design down, build up. This isn't only for the UI; it's how the backend and the plumbing are cut too.

| Level | App engineer (view cards) | Backend engineer | App engineer (Platform cards) | Tested by |
|---|---|---|---|---|
| **Product** | the app the designs describe | everything the app needs from the server and brain | everything inside the app that isn't a pixel | the ship gates |
| **Flow** | a flow's screens in order (the journal: JR-1 → JR-4) | the flow's contract (`contracts/0N-…`) | the flow's live data (`LiveJournalData`) | a flow UI test (T03–T06) |
| **Page / capability** | one screen (JR-1) with its interaction sheet | one capability (today's brief: latest, history, switch, audio) | one repository (`BriefsRepository`) | an accessibility audit and a page UI test / a capability's contract tests |
| **Component** | one component (the brief card) with every state | one door (`GET /v2/briefs/latest`) or one agent route | one module (the streaming parser, the outbox drainer) | snapshot tests / the nine door tests / unit tests |
| **Sub-component** | one part (the progress hairline) | one engine change or fix (BEA.1's permission grant) | one type or function (the backoff policy) | unit tests |
| **Byte (one PR)** | the smallest of the above that stands alone | same | same | its own tests, in the same PR |

How it's applied:
1. **Before a phase starts**, each agent writes its part of the tree for that phase, top-down (flow → pages → components → sub-components, or flow → capabilities → doors → engine changes), and the integrator reviews it against the contract and Paper. Only then does building start.
2. **Building goes bottom-up:** sub-components before the components that use them, components before pages, pages before the flow is joined.
3. **Every byte names its place in the tree** in its board row and PR title (for example `journal › JR-1 › brief card › progress hairline`), so anyone can see what it's for and what it unblocks.
4. **A byte that turns out bigger than one PR is split**, down the tree, before work continues; never one PR doing two levels at once.

## 4. How work is cut: bytes

**Founder, 21 Oct: everyone drips into the codebases bit by bit, PR by PR, and nothing is compromised.** Small PRs land continuously; none of them trades away any of these:

| Quality | What it means here | Checked by |
|---|---|---|
| **Tests** | every behaviour and failure path has a named test in the same PR ([testing.md](./testing.md)) | CI; integrator review |
| **Code quality** | readable, in the codebase's own idiom, no duplication, no dead code, names that say what they are | integrator review; lint |
| **UI quality** | matches Paper value for value, in light, dark and large text | snapshots; screenshots next to Paper |
| **Interaction quality** | every touch has its press, haptic and outcome motion as specified; interruptible; Reduce Motion respected | the interaction table on the card; recordings |
| **Visual quality** | tokens only, squircles, one lit object, optical alignment, the craft checklist | the literal check; review |
| **Behavioural quality** | correct with no network, slow network, retries, relaunch, sign-out, another user's data | tests; staging runs |
| **Completion** | every state the design draws and every acceptance item on the card; nothing "for later" without a card for it | the card's acceptance list |
| **Edge cases** | empty, day one, very long text, the largest text size, SE screen, interrupted actions, repeats | the card's tests and proof |

Small is how quality stays high: a PR small enough to review completely is a PR whose every line was checked.


A **byte** is one small PR that does one thing, can be reviewed in one sitting, leaves `main` green, and moves one item on the board. The full pool is `docs/design/m14-progress-map.md` (240 bytes) plus the new bytes in each engineer's plan. Every byte has an id, a repo, its dependencies, acceptance criteria and tests.

The life of a byte:
1. **Assigned** on the board by the integrator (never self-assigned).
2. **Built** in the agent's own worktree, on a branch off fresh `origin/main`, never stacked on another open PR.
3. **Checked** by the agent: the definition of done in their plan, every check run locally and read.
4. **Pushed once**, as one PR, with the report (§8).
5. **Reviewed** by the integrator: the diff read as a reviewer, the screenshots or tests checked, findings fixed (by the agent, or by the integrator for one-line fixes, noted in the PR).
6. **Merged** by the integrator when CI is green. Branches aren't deleted until nothing is based on them.
7. **Logged**: the board, the progress map, the build chronicle and the findings log.

## 5. The phases

```
Phase 0  Foundations ─────────────────────────────────────────────────────────────┐
  backend:  door kit · harness · refresh tokens · Apple revoke · invites · deletion │  in parallel,
  plumbing: tests · Platform · client · session · invite gate · GRDB store · outbox │  no contract
  UI:       remaining journal components (top bar, tab bar, message, brief, guess…) │  conflicts
  integrator: merge the backlog · contract 00 (platform) · contract 02 (journal)    ┘
Phase 1  The journal slice (contract 02): doors → live data → JR-1…4 pages → wiring → flow pass → ship gate G2
Phase 2  First run (contract 01): onboarding doors · podcast job · push · StoreKit · invite gate screen → G1
Phase 3  Podcasts (03) → G3      Phase 4  Goals (04) → G4      Phase 5  You (05) → G5
Phase 6  Settings and account (06) → G6      Phase 7  Outside the app (07) → G7
Phase 8  Retire the old: version floor passes, old screens/services/routes/tables removed (X01–X09)
Then     Release: TestFlight beta (invite-only) → App Store submission
```

Why the journal before first run (a change from the original flow order): the journal is the core product and needs nearly every system (doors, streaming, the outbox, the store, the brief, guesses, corrections), all on Apple sign-in, which already works. If the architecture is wrong, the journal shows it cheaply. First run is heavier on outside services (StoreKit, push, App Review, invites) that can mature in parallel during phase 1. The founder's first real use (an Xcode build on their phone) can be the journal slice, behind a switch.

**A ship gate** (per flow, unchanged from `swift-implementation-plan.md` §5): every contract item live and the sample-data ledger at zero for the flow; TestFlight on a real account; cost per user logged; errors and offline handled; App Store rules met; the founder signs off from recordings. Then the flow's switch turns on for everyone and its old screens are deleted.

## 6. The machine and the shared environment

- **One Mac** runs everything: two agents' builds (only the app engineer uses Xcode), the integrator, and CI (a self-hosted GitHub runner). Disk floor: **5 GB free**, checked before every build; under it, stop and tell the integrator.
- **Simulators** (iOS 26.0 runtime; never create, clone or delete simulators or runtimes, ever):
  - integrator: iPhone 17 Pro `2E876B5C-E345-44BC-A7D5-236837088B31`
  - app engineer: `agent-a 17 Pro` `3E962F9F-E537-4C97-9F2E-134B3FD8B992`
  - spare: `agent-b 17 Pro` `6F5A82DF-2979-4DE6-B9E2-C968FE1D51DA` (unused while there's one app engineer)
  - small-screen checks: iPhone SE `6804ADCD-506C-476C-A084-B40D15E3254C` (ask first; shared)
- **Derived data:** one folder per engineer in the session scratchpad (`dd-main`, `dd-ui`, `dd-plumbing`). The backend engineer doesn't build iOS.
- **Never open the Simulator window or show the founder a simulator.** Check headlessly (`simctl io screenshot`, launch flags). The founder: "feel free to use it, I just don't want to see it."
- **CI:** jobs `api` (backend), `ios` (build; tests once PL0.1 lands), lint and format (DesignSystemV2, Features, and Platform once added), tokens and literals, gitleaks. One runner, one job at a time; the integrator may add a second runner on the same Mac to double throughput (needs the founder's yes).
- **Paper:** the design master, file `01M5D5J321P5X86ZT58002B7NT`. Paper Desktop must be running for anyone to read it; if it isn't, stop and tell the integrator.

## 7. Rules every agent follows

1. **Read before you build:** this file, `context.md`, your plan, the contract for your byte.
2. **Stay in your column** (§2). A byte that seems to need someone else's file stops and asks.
3. **Contracts are law.** Build to the contract exactly. If it's wrong or missing something, stop and ask; never adapt on your side.
4. **One byte, one branch, one PR, pushed once.** Never stack on another open PR; never merge, close or retarget PRs.
5. **Quality over speed, always.** Every check run and read before pushing. A red check is never pushed "to see".
6. **No personal content anywhere**: not in logs, analytics, fixtures, screenshots of real accounts, or reports. Counts and types only.
7. **No secrets** printed, logged or committed. Env var names only.
8. **Nothing outward without the founder** (via the integrator): no deploys, no production migrations, no TestFlight uploads, no App Store Connect changes, no messages to anyone.
9. **Never use bare `git stash`**; other sessions share the stash. Use a temporary commit, or a tagged stash applied by SHA.
10. **Report honestly**: what's done, what isn't, what you weren't sure of, and every mistake you made.
11. **Fix every correction at the strongest layer** ([trust-ladder.md](./trust-ladder.md)): make the mistake impossible in the code, else catch it with a lint or CI check, and only then a rule or a skill. Your report names the layer, and says why a check couldn't do it whenever you propose a rule.
12. **Two strikes, then stop:** two red CI runs or two failed corrections on one byte, and you stop and report. Don't keep digging.
13. **Prove it with `rc`**, once V0.1 lands: screenshots, comparisons and recordings come from the control CLI, never from a one-off script.

## 8. The report every agent sends after each PR

```
PR #N · <title> · <repo> · base main
Byte: <id> · place in the tree: <flow › page › component › part> (board row)
What: two or three sentences.
Contract: the section implemented, or "none".
Checks: each command and its result.
Proof: tests added (names), screenshots (paths, next to the Paper node compared), or staging results.
Not done / out of scope: …
Decisions I made: … (each with the rule or evidence behind it)
Questions for the integrator / founder: …
Mistakes and recoveries: …
Shared-file requests: …
```

## 9. Releases, review and access

- **Invite-only (founder, 21 Oct).** You get in only through an invite link. People join the waitlist (in the app or on the website); the founder approves each one, which makes a link the founder sends personally; each member gets three links of their own that let a friend straight in. Opening a link and signing in with Apple or Google applies the code automatically; typing it is a fallback. Existing users are grandfathered in. Every `/v2` door refuses waitlisted users. Design: the invite screen is drawn in Paper and approved before it's built.
- **Beta on TestFlight.** Apple's Guideline 2.2 says betas belong on TestFlight. Internal testers (up to 100, App Store Connect users) need no review; external testers need a light beta review. The beta runs here, invite-gated, until the founder decides to submit.
- **App Review.** A login-gated app must give the reviewer working access (Guideline 2.1). With Sign in with Apple the reviewer uses their own Apple ID, so the review notes carry a permanent review invite code (revocable afterwards) and, ideally, a seeded demo account it unlocks. The app always shows a way to ask for an invite, so it's never a dead end. Whether App Review accepts "sign in, then enter a code" isn't officially documented; the first submission tests it, with the notes written plainly.
- **Account deletion (Guideline 5.1.1(v))** in the app, with Sign in with Apple token revocation; subscribers are reminded billing continues until they cancel, with a link to manage subscriptions.
- **Privacy manifest** and App Privacy labels match what the app actually collects (no tracking; analytics counts only).

## 10. Decisions the founder makes before or during phase 0

Each has a lean; the plan proceeds on the lean unless the founder says otherwise.

| # | Decision | Lean | Blocks |
|---|---|---|---|
| D1 | Approve this plan | **approved 21 Oct** (two engineers, Beta 1 scope) | everything |
| D2 | **Staging** | **decided 21 Oct: local staging now** (the backend and brain run on the Mac against a second, free Supabase project), **Render staging later** (a configuration change: about $14/month for two Starter services; no code changes) | BE0.S, every proof |
| D3 | **Google as a sign-in method** | **decided 21 Oct: Apple and Google.** Needs a separate Google sign-in client with basic scopes only (founder action) | BE2.4, PL1.4, the splash |
| D4 | **Invites** | **decided 21 Oct:** waitlist in the app and on the website; you approve each person; each member gets three invite links that let a friend straight in. Approval is an invite link you send personally; the link's code applies itself after sign-in. Invite links use the free server address for now (`retrospect-api.onrender.com/i/…`), moving to a domain later with old links still working | BE0.12, PL1.7, the invite screens |
| D5 | **Local store: GRDB** instead of SwiftData (SwiftData on iOS 18 has unresolved crash and migration bugs; an outbox must never lose a write) | GRDB | PL2.x |
| D6 | **Prices** | **decided 21 Oct (later the same day): $19.99 a month; $199.99 a year (17% off), with the first month free on the yearly plan.** Every typed-in price in code and docs is removed; the app shows Apple's localized price | PL6.x, P07 |
| D7 | Daily brief default | **decided 21 Oct: off until the person opts in**; they pick the time in onboarding (ON-8) | BE6.2, ON-8 |
| D8 | Analytics and crash reporting vendor (or none for the beta) | none for the first internal beta; decide before external testers | PL4.x |
| D9 | Notion in ON-6 (build the connector) or hide it like GitHub | your 21 Oct call was build it; confirm it's in the beta or after | BE2.9 |
| D10 | Turning the brief cron on in production (`ENABLE_DAILY_BRIEF` is unset today) | when the journal slice ships (G2) | BE1.3 |
| D11 | Guesses speaking outside episodes (the `speak` dial is off) | on for the beta, since the journal's guess cards need it | BE1.4 |
| D12 | A second CI runner on your Mac | yes (local only, no cost) | merge speed |
| D13 | Brief audio | **decided 21 Oct: briefs are audio** (a feature to add) | BE1.3b |
| D15 | Code comments ([trust-ladder.md](./trust-ladder.md) §3) | **decided 21 Oct: workaround comments banned** (`TODO`, `FIXME`, `HACK`, "workaround", commented-out code) unless they carry a findings id; "why" doc comments stay | G0.1 |
| D16 | How many agents at once | **decided 21 Oct: two, app and backend, at the same time** (README §2) | merge speed |
| D17 | Guardrails | **decided 21 Oct: Beta 1 gets only the half-day set** ([first-ship.md](./first-ship.md)); the rest waits | nothing |
| D14 | Episode chapters | **decided 21 Oct: loose chapters for now**, one per topic as the narrator moves on; a small production-side change | BE3.0 |

**Founder actions** (things only you can do, in App Store Connect, the Apple Developer site, Render or providers):
1. Rotate the ElevenLabs key (B0.2, still open).
2. Apple Developer: an **APNs key (.p8)** for push; a **Sign in with Apple key (.p8)** for token exchange and revocation; the Push Notifications and Associated Domains capabilities on the app id.
3. App Store Connect and **RevenueCat** (yours; you've set it up): the two subscription products ($19.99 a month; $199.99 a year with a one-month free trial), the entitlement and offering in RevenueCat, its public iOS key and webhook secret for us, TestFlight groups, and the review notes and invite code at submission.
4. Render: staging services if D2 is yes; production env vars when each byte needs them (the integrator lists them).
5. Production deploys and migrations, each when the integrator asks, with a backup first.

## 11. Risks and how the plan answers them

| Risk | Answer |
|---|---|
| Agents collide on shared files | Ownership (§2); only the integrator edits shared files; no stacked PRs |
| Two sides of an API drift | Contracts first; the same JSON fixtures tested by backend (zod) and app (Codable) |
| A door leaks one user's data to another | User only from the token; ownership checks; a mandatory "another user's id → 404" test on every door |
| An entry is lost offline | GRDB outbox, one transaction per write, idempotency keys, exactly-once tests |
| CI or the Mac stalls everything | Disk floor, assigned simulators, a second runner, the integrator watches the runner |
| Quality drifts with speed | The same checklist on every PR; the integrator reviews every diff; signature moments get recorded passes |
| App Review rejects the invite gate | Review code + demo account in the notes; a waitlist path; beta on TestFlight first |
| Old and new code tangle | New code only under `/v2`, `Platform/`, `Features/`; old code frozen; retirement on a schedule (X bytes) |
| Production surprises | Nothing deploys on merge; staging first; every deploy and migration is the founder's yes |
