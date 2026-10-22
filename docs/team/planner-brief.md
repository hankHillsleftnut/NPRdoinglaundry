# Planner brief (shared by the six area planners)

You plan one area of the new Retrospect iOS app to **the same standard as the journal**, the area already planned in full. The founder, 21 Oct: "each part of the app is really, really important and needs all of its separate pieces well considered before they turn into PRs." You write plans only: no app or backend code, no Paper edits.

## The model to copy
The journal's plan is the standard. Read it first and match its depth, shape and tone.
- **Contract:** `docs/team/contracts/02-journal.md`, plus the rules in `contracts/README.md` (fixtures: full, minimal, one per error).
- **Card shape:** `docs/team/byte-card.md`. Every card has: place in the tree, needs/unblocks, why in the user's terms, inputs (contract §, Paper node ids, code anchors as path:line), the spec (UI: anatomy as tokens, a state table, an interaction table with haptic, motion and Reduce Motion, accessibility; backend: request, validation, ownership, limits, the brain call, errors, logs, migrations; Platform: types, API, concurrency, persistence, failures), steps, yes/no acceptance, tests named as sentences with their layer, proof, watch-outs.
- **Examples:** `docs/team/ui/P09.md` (a page), `ui/C30.md` and `ui/C26.md` (components split into sub-component PRs), `plumbing/PL3.1.md` (live data), `backend/phase-1-journal.md` (doors).
- **Rules:** `docs/team/README.md` (rules §7, the tree §3), `context.md` (decisions and hard rules), `testing.md`, `trust-ladder.md`, `first-ship.md` (what's in Beta 1; your area is mostly after it).
- **Ground truth:**
  - `docs/team/reference/` (agent-api, backend, app, design, paper-inventory);
  - the brain repo `/Users/shauryanarang/Projects/retrospect-agent`, for real routes and tables;
  - the backend in `backend/`;
  - the app in `Retrospect/`;
  - the design system in `design-system/`: read `principles/`, `craft.md` and `screen-rules.md` before planning any UI.
- **Existing outlines for your area** (start from them, don't trust them blindly):
  - `docs/team/ui/later.md`;
  - `docs/team/backend/later-phases.md`;
  - `docs/team/plumbing/outline.md`.

Read everything from `origin/main` of /Users/shauryanarang/Projects/retrospect-main (`git fetch` first). **Never edit the main checkout.** Make your own worktree: `git -C /Users/shauryanarang/Projects/retrospect-main worktree add <your scratch dir>/plan-<area> -b docs/plan-<area> origin/main`.

## Paper (the design master, read only)
Light file `01M5D5J321P5X86ZT58002B7NT`, dark file `01M5EK9MGGWHX9H05V9MENVB6P`. Load the Paper guide once (`get_guide` topic "paper-mcp-instructions"). Use `get_tree_summary`, `get_jsx`, `get_computed_styles` and `get_screenshot` on your area's screens:
- page "06 · everything · latest" (`p-J-0`);
- page "04b · pages · hi-fi" (`p-D-0`);
- any approvals boards for your area.

Take exact values from these tools, never from screenshots. **Don't edit, move, rename or comment on anything.** Several sessions use this file at once. Reading is fine. If Paper isn't running, say so in your report and plan from `paper-inventory.md`.

## The process (the same for every area)
1. **Big picture:** what this area is for the person, in their words. Which product principles apply (the claim ladder, guesses asked and never asserted, "when uncertain, withhold", no invented data, one lit object per screen).
2. **Flows:** every path through the area: entry points (tabs, deep links, notifications), the happy path, failures, offline, empty, the first time versus the hundredth.
3. **Contract:** write `docs/team/contracts/0N-<area>.md` in the same form as 02. Every request and response field, error codes, enums with `unknown`, idempotency, limits, and what the brain must add (with brain-side bytes) where data doesn't exist yet. Write the fixtures in `contracts/fixtures/0N/`, with invented, obviously-fake content only.
4. **Pages:** each screen with its states (loading, empty, content, error, offline, and any area-specific ones), its Paper node, and its interaction sheet.
5. **Components, then sub-components:** reuse what exists, both built (`DesignSystemV2/Components`) and planned (the journal cards). New ones get their own cards. Any component bigger than about a day splits into sub-component PRs (`C27.1`, `C27.2` …), each its own card.
6. **PRs:** every leaf is one PR with a full card. Three kinds, matching the two engineers:
   - **backend:** brain bytes and doors;
   - **Platform:** client, live data, store, push, purchases, router;
   - **views:** components, pages, motion.

   Order them so each needs only merged work, and name the cross-side dependencies.
7. **Tests:** the area's flow test (T03/T05x/T06) as a full card, plus each card's tests per `testing.md`.
8. **Questions:** anything the founder must decide. Each one has lettered options, your lean, and what changes under each option. **Work goes ahead on the lean.** Never invent product behaviour silently. If Paper and the docs disagree, the newest source wins (say which), or it becomes a question.

## What to write (in your worktree, then one PR)
- `docs/team/contracts/0N-<area>.md` + `docs/team/contracts/fixtures/0N/*.json`
- `docs/team/flows/<area>/README.md` — big picture, flows, the **full tree** (area › flow › page › component › sub-component › PR id, with size and needs), the queue in build order, risks, and founder questions with leans
- `docs/team/flows/<area>/backend.md`, `platform.md`, `views.md` — every card in full (byte-card format). One file per side is fine; split if a file passes ~1,500 lines.
- `docs/team/flows/<area>/tree.json` — `{"nodes":[{"id","parent","title","plain","size","side":"backend|platform|views","needs":[...]}]}`, with ids unique and parents valid. **Only these levels become nodes:** the area (root), its flows, pages, components, sub-components and PRs (leaves are PRs). `plain` is one line in the user's terms. The integrator loads this into the founder's build board.

**Don't edit shared files:** the README, board, context, ui-engineer.md, later.md, the other areas' folders, or other contracts. If one needs a change, write it down in your report.

Open a PR against `main` titled `docs(plan): <area>, every piece to PR level`. The body is plain words: the counts (pages, components, PRs per side), the founder questions, and anything you couldn't verify. End it with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. **Never merge.** Never bare `git stash`. No secrets, no personal content (the brain's real user data is off-limits; read schemas, not rows).

## Your report back (short)
- PR link;
- counts per side;
- the top founder questions with leans;
- gaps you couldn't close;
- changes needed in shared files.
