# First ship: what's in, what waits

Founder, 21 Oct: "anything that can be somewhat added later will add later. I want this robust and in people's hands." This file overrides every plan in this folder. A byte not listed under **Beta 1** waits, however fully its card is written. Cards stay as they are, so nothing is lost when it's time to build them.

## The target: Beta 1

An invite-only TestFlight build for a small group. You get in through an invite link, sign in with Apple, see "you're in", and use the **new journal**: send thoughts and voice notes that never get lost, get the daily brief as audio, and answer guesses. **Podcasts, goals, you and settings stay on the current screens**, still working, and move to the new design flow by flow after Beta 1. That's what ship gates were for: one flow at a time, with the rest of the app still running.

**The test for "in" or "later":** is it needed for the journal to work, for people's data to be safe, or for money not to leak? Then it's in. Everything else waits.

## The team for Beta 1

Two engineers running at the same time: the **app engineer** (all of `Retrospect/`, working from the UI and plumbing cards) and the **backend engineer** (backend and brain). I review and merge. See README §2.

## Beta 1: in

**Backend** (about 24 PRs)
- Foundations: local staging (BE0.S), runtime hygiene (BE0.0), the door kit (BE0.1), the test harness (BE0.2), error-leak cleanup (BE0.3).
- Sessions: refresh tokens (BE0.4), so people stay signed in and a single 401 no longer logs them out.
- Invites: the waitlist, approval links and three links each (BE0.12).
- Brain safety: production corrections fixed (BEA.1), other users' data unreachable (BEA.2), every model call counted against the spend cap (BEA.4), episode audio no longer a permanent public link (BEA.7), quiet weeks not treated as errors (BEA.8).
- The journal: sending (BE1.1), today's brief with audio (BE1.3, BE1.3b), guesses (BE1.4), entry history (BE1.5).

**App engineer: Platform cards** (about 22 PRs)
- Tests that run, the Platform folder, injection, pinned packages (PL0.1–PL0.4).
- The typed client, retries, the session store, Apple sign-in, silent refresh with the old screens kept signed in (PL1.1–PL1.5).
- The invite link applying itself (PL1.7).
- GRDB, the store, the outbox, and the old screens' entries going through the outbox (PL2.0–PL2.3).
- The journal on real data (PL3.1), the router (PL5.2), launch options for testing (T02a), the privacy manifest (PL7.1, which Apple checks on upload).

**App engineer: view cards** (about 36 PRs, fewer once a page's view and live data land together)
- The screen launcher (T02), so every PR carries real screenshots next to Paper.
- The journal's components and four pages (C17–C39, UI1.0–UI1.2, C22–C25, P09–P12).
- The invite gate (PI1) and **M14, "you're in"**.

**Integrator:** merge the backlog, contracts 00 and 02 with fixtures, the journal protocol, the guardrails below, one end-to-end run of the journal on local staging before TestFlight, and your sign-off from recordings.

## Added 22 Oct: session diagnostics (founder)

The six PRs in `flows/diagnostics.md` (DG.1–DG.6): the app records how it behaved, with no personal content, and "send a report" sends it to us for debugging. Beta 1 is now about 90 PRs.

## Later: waits until after Beta 1

| What | Why it can wait | When it comes back |
|---|---|---|
| Google sign-in (BE2.4, part of PL1.4) | Apple covers every tester | before the App Store |
| Payments: RevenueCat, paywall, entitlement mirror (BE2.8, PL6.x, P07) | testers don't pay | before the App Store |
| Push notifications (BE2.7, PL5.1, PL5.3) | the brief is off until opted in; testers open the app | with first run |
| Account deletion and Apple revoke (BE0.5–BE0.8, BE0.13) | for Beta 1, you delete a tester by hand on request | **required** before the App Store |
| The new onboarding and first run (contract 01, ON-x, the podcast job) | the current onboarding still works | phase 2 |
| The new podcasts, goals, you and settings screens | the current screens still work | phases 3–6, flow by flow |
| Editing and deleting an entry, "what Retro took", "not right" (BE1.5b, BE1.6, BE1.7, UI1.2's correction half) | the brain already learns from entries; correcting it is a refinement | right after Beta 1, before the App Store |
| Streaming and real conversation (PL3.2) | decided: canned acknowledgements in v1 | v2 |
| Shared limiter, minimum app version, Sign in with Apple notifications, measured cost per user (BE0.9–BE0.11, BE0.13, PL1.6) | one server instance; TestFlight updates testers itself; cost is tracked by hand in `cost-per-user.md` | before the App Store |
| Bringing old on-phone data into the store (PL2.6), cached reads for other tabs (PL2.4, PL2.5) | the old screens still read their own data | with each flow's move |
| Analytics and a crash vendor (PL4.x) | TestFlight's built-in crash reports are enough for a small group | before external testers |
| Signature moments M01–M13 | M14 is the one that matters now | with their flows |
| Brain fixes BEA.3, BEA.5, BEA.6 | not hit by the journal slice | when their flows move |

## Testing for Beta 1 (from testing.md's 11 layers)

**In:**
- Brain and backend tests, including running brain SQL as production's role (layers 1–3).
- Contract fixtures checked on both sides (layer 4).
- Platform unit tests: client, session, refresh, outbox, store (layer 5).
- One journal UI test, T04: send typed and voice entries, go offline, come back online, and each entry sends exactly once (layer 8, journal only).
- One end-to-end run on local staging before each TestFlight build (layer 9).
- Your phone (layer 11).

**Later:**
- Snapshot tests of every state (layer 6). Each PR's screenshots next to Paper do this job for now.
- The automated accessibility audit (layer 7). For Beta 1, one manual pass at the ship gate.
- Flow tests for the other flows (layer 8).
- Instruments traces (layer 10), except for M14 and the brief player.

The rules in testing.md §2 stay for every PR: tests for the failures the code handles, a two-user test on anything touching user data, a retry test on retried writes, and no content in logs.

## Guardrails for Beta 1 (from trust-ladder.md)

**In** (about half a day; they stop bad patterns before they spread):
- SwiftLint on the new folders only, with messages that name the fix. Its rules:
  - tokens only;
  - squircles only;
  - motion only from `RMotion`, haptics only from `RHaptic`;
  - no `print`, and no public log interpolation;
  - no workaround comments (D15);
  - no `URLSession`, keychain or GRDB in `Features/`.
- `token-check.mjs` and a secret scan in CI.
- A one-page `AGENTS.md` that maps every rule to what enforces it.

**Later:** the backend ESLint, edit-time hooks, the full `rc` CLI with a CI-checked feature map, and the weekly gardening byte. The screen launcher (T02) plus a short screenshot script covers verification for now.

## Size

About **85 PRs** to Beta 1, out of about 230 in the full plan.
