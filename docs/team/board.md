# The board

Who is doing what, right now. Only the integrator edits this. Two agents: **app** and **backend**, running at the same time ([first-ship.md](./first-ship.md) decides what's in). Each agent has at most one byte **doing** and one **next**.

Status: `next` · `doing` · `review` (PR open) · `merged` · `blocked` (with the reason).

## Phase 0 (plan approved 21 Oct)

| Agent | Byte | Status | PR | Notes |
|---|---|---|---|---|
| integrator | merge the reviewed backlog (#42, #44–#46, #48, #50, #52–#56), conflicts resolved | next | | every agent starts from one clean `main` |
| integrator | land `docs/team/**` on `main` | next | | after the founder's approval |
| integrator | contract 00 and 02 fixtures; `Platform/Flows/Journal.swift` | next | | |
| integrator | invite screens and M14 "you're in" in Paper | doing | | round 1 keyframes on the approvals page |
| integrator | Beta 1 guardrails: SwiftLint (new folders) · token-check + secret scan in CI · `AGENTS.md` | next | | first-ship.md; about half a day, in parallel |
| app | T02 screen launcher | next | | Beta 1 verification (first-ship.md) |
| backend | BE0.0 runtime hygiene | next | | |
| backend | BE0.S local staging | next | | needs the founder's second Supabase project |
| app | PL0.4 pinned packages, `Package.resolved` | next | | |
| app | PL0.1 tests that run | next | | |
| app | C17 top bar | next | | Paper part 06 |
| app | C18 tab bar | next | | needs the progressive-blur modifier (integrator) |

## Waiting on the founder

| What | For |
|---|---|
| The invite link's web domain | BE0.12, PL1.7 |
| A second Supabase project (`retrospect-staging`) | BE0.S |
| `ADMIN_SECRET` set on Render before BE0.0 deploys | BE0.0 |
| Rotate the ElevenLabs key | B0.2 |
| Contract 02 decisions: sureness words, a corrected claim (struck or gone), message state, acknowledgement lines, guesses speaking | contract 02 |

Later (after Beta 1, before the App Store): Google sign-in client id; Apple push and Sign in with Apple keys; RevenueCat keys and webhook secret.
