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

## What this doesn't change

- **The Beta 1 scope** (`first-ship.md`). Same features, same diagnostics.
- **The founder's decisions** in `context.md`.
- **The board, the changelog, the chronicle and the findings log.** They're still updated, just in lighter batches.
- **The design rules:** tokens only, squircles, motion and haptics through the system, one lit object, lowercase. These are enforced by CI, so they cost nothing.

## When it ends

When Beta 1 is on TestFlight, the integrator proposes which light checks come back before the App Store: the polish list, full Paper matching on every screen, and a reviewer on every PR. The founder decides.

## Change log for this doc

- 22 Oct: created. The previous integrator session wrote it and sent it to the current integrator to apply.
