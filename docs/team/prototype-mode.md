# Prototype mode (founder decision, 22 Oct 2026)

**The decision.** The founder asked: "Do we need this many checks and balances for our first prototype?" The answer: not all of them. From now until Beta 1 ships, the team runs in **prototype mode**:
- the checks that protect people's data, entries and production stay strict;
- the checks that only buy polish or process get lighter;
- the visible quality testers see (the journal and the ticket) stays high-craft.

**Expected effect:** about twice the speed at about half the usage, with the same safety and the same look where it counts.

This overrides the matching parts of `README.md` §4 and §7, `testing.md`, `integrator-loop.md` and `first-push-checklist.md`, until Beta 1 ships. The integrator updates those files to point here.

## What stays strict (non-negotiable, even for a prototype)

| Check | Why |
|---|---|
| CI green before merge (build, app tests, lint, tokens, secret scan, backend tests) | automatic and cheap; it catches breakage |
| Isolation: one person can never reach another's data (two-user tests on every door and query) | testers write private journals |
| No personal content in logs, analytics, fixtures or reports | privacy promise |
| Staging can never touch production; nothing outward without the founder | real data lives in production |
| The outbox never loses or duplicates an entry (its tests, including retry and offline) | the product's core promise |
| Sign-in, sessions and tokens (and anything touching money later) | security |
| A test must fail when the rule it protects is removed | otherwise the safety tests above are hollow |
| The journal screens and the invite ticket / "you're in" (M14) match Paper | that's what testers see and judge |

## What gets lighter

| Before | Now | Saves |
|---|---|---|
| A fresh-context reviewer on **every** PR | A fresh reviewer (on the Fable model) **only on risky PRs**: sign-in and sessions, data and the store, the outbox, backend doors and brain queries, diagnostics, anything with migrations. UI component PRs get green CI plus a quick integrator read. | the biggest share of usage |
| Tiny PRs (one sub-part each, e.g. C26.1 / .2 / .3) | **One PR per whole component, page or route.** Platform chains can still stack. | builds, reviews and merge conflicts |
| Every component matched to Paper value by value | Value-by-value matching for **the journal pages (P09–P12), their visible components, the invite ticket and M14**. Internal parts can be "close" and go on the polish list. | Paper reads and review time |
| Screenshots at light, dark and AX3 for every component | **One proof set per page** (light, dark, AX3, SE). Components show a single light screenshot. | build and simulator time |
| Every reviewer nit fixed before merge | **Only real problems** (correctness, safety, accessibility blockers, Paper mismatches on the strict list) block a merge. Nits go to `docs/team/polish-list.md` and are batched before the App Store. | fix rounds |
| Full card detail for every later area before it starts | Later areas keep their existing plans; no further planning work until Beta 1 ships | planning usage |

## Effort by phase (founder, 22 Oct)

Every **integration piece** runs in three phases, each at its own reasoning effort. An integration piece wires a screen to live data, a door to the brain, or the app to a door: PL3.1x live data, the BE1.x journal doors, PL1.4/PL1.5 sign-in wiring, PL1.7/BE0.12 invites.

| Phase | Effort | Who | What it produces |
|---|---|---|---|
| 1. Contract and edge cases | **high** | one short agent, before any code | Both sides inspected. The agreed shapes, errors, states and timing. The edge-case list: offline, retry, expired session, empty, partial failure, races. Written into the card or the PR body. |
| 2. Build | **medium** | the engineer | The wiring, built to that contract. |
| 3. Combined-flow review | **high** | a fresh reviewer (Fable) | Both sides together, every edge case on the list, and contract fixtures passing on both sides. |

**Pure UI components and simple bytes run at medium throughout**, with a reviewer only where this doc's risky list says.

The integrator sets this with `effort` on each agent it starts. Engineers run at medium, phase 1 and phase 3 agents at high.

## Team shape (founder, 22 Oct, afternoon: "fly through this faster, built intentionally")

Usage is no longer the limit; the Mac's one iOS build lane and dependency order are. So:

- **Five engineers at once, all on Fable at medium:** Platform A (diagnostics DG.3 → DG.4 → DG.5, then the drainer PL2.2b), Platform B (sign-in PL1.4a → PL1.5), backend A (invites BE2.0b, then the journal doors BE1.x), backend B (brain-side BEA.4 → BEA.7 → BEA.8), views (C39.1, C30.1, C30.3, C26, then C39.2, C19, C20, DG.6). Two engineers never touch the same files; each has its own worktree and, for iOS, shares the one-build-at-a-time lock.
- **A contract pass stays one byte ahead** of every integration piece (phase 1 above), written to `/Users/shauryanarang/Projects/retrospect-handover/contracts/<byte>.md`, so no engineer builds to a guess. The integrator decides each open question on the pass's lean and records it in the engineer's brief.
- **A fresh reviewer the moment a risky PR opens**, not batched per tick. UI PRs: green CI plus the integrator's read.
- **CI off the critical path:** incremental builds, stale runs cancelled, a second Mac as an iOS runner (`docs/team/ci.md` once it lands).
- **What doesn't change:** the four gates (contract pass where it applies, fresh reviewer where the risky list says, the integrator's own read of every diff, green CI); one PR per whole component, page or route; the strict list above. Speed comes from parallelism and preparation, never from skipping a gate.

## What this doesn't change

- **The Beta 1 scope** (`first-ship.md`). Same features, same diagnostics.
- **The founder's decisions** in `context.md`.
- **The board, the changelog, the chronicle and the findings log.** They're still updated, just in lighter batches.
- **The design rules:** tokens only, squircles, motion and haptics through the system, one lit object, lowercase. These are enforced by CI, so they cost nothing.

## When it ends

When Beta 1 is on TestFlight, the integrator proposes which light checks come back before the App Store: the polish list, full Paper matching on every screen, and a reviewer on every PR. The founder decides.

## Change log for this doc

- 22 Oct (afternoon): team shape added (five engineers, contract passes one byte ahead, reviewers on open).

- 22 Oct: effort by phase added (founder instruction, relayed).

- 22 Oct: created. The previous integrator session wrote it and sent it to the current integrator to apply.
