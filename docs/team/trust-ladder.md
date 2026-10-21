# The trust ladder: how we make agents safe to leave alone

Source: Lauren Tan (poteto), "how I shipped 2,000 PRs last month" (X, Oct 2026), transcribed locally and read in full. This file says what the talk claims, how much of it we already do, what we take, what we change, and what we reject, with the reason for each.

## 1. The talk in five lines

1. **Speed comes from trust, not from more agents.** If you can't trust the work, 100 agents just make 100 times the slop. Most people are stuck at one to five agents, correcting every chat.
2. **Verification first.** Teach agents to run the app themselves and collect evidence. Hers is a skill with two parts: a **CLI** (so every session runs the app the same way, instead of writing a new script each time) and a **feature map** (every feature, what it does and how to reach it, kept up to date by an automation).
3. **Whenever you correct an agent, fix it at the strongest layer you can**, in this order:
   1. the codebase (make the mistake impossible);
   2. static analysis (lint, compiler, CI);
   3. rules and review bots;
   4. skills;
   5. the style guide (only a human can enforce this, so it's the weakest).
4. **The codebase is the agents' memory.** They copy what they see. One workaround becomes the pattern in weeks. So: one paved path per job, delete debt, and write a lint rule the moment you see a bad pattern, even before you clean it up. She bans code comments because agents used them to justify workarounds. Someone has to be the **gardener**.
5. **The outer loop:** connect bug reports, alerts and chat to agents that reproduce bugs and open PRs on their own.

## 2. How much of this we already do

Roughly **a third**. We're strong on the two weakest layers and weak on the two strongest.

| Layer | Status | What we have | What's missing |
|---|---|---|---|
| **Verification** | weak | the simulator tool, used by hand each time; the T02 screen launcher and snapshot tests are **planned, not built**; CI **builds the app but runs no app tests** | one command that opens any screen in any state, screenshots it and compares it to Paper |
| **Feature map** | partial | `reference/paper-inventory.md` and `reference/app-reference.md`, written by hand once | a map kept true automatically: every screen, its Paper node, how you reach it, its launcher arguments |
| **1. Codebase** | half | the generated tokens, `RShape`, `RMotion` and `RHaptic` are a real paved path; the plan's `door()` kit makes skipping the ownership check impossible on the backend | the old app still shows agents the wrong way (singletons, untyped client, JSON files); "old and new never mix" is only a rule |
| **2. Static analysis** | weak | backend typecheck and tests in CI; `design-system/token-check.mjs` exists | no SwiftLint, no ESLint, token-check **not in CI**, no import-boundary check, no secret scan |
| **3. Rules and review bots** | strong (too strong) | 47 memory rules, CLAUDE.md, the team plan, CodeRabbit, my review of every PR | most of these could be checks instead |
| **4. Skills** | broad but generic | 35 iOS skills, the `better-*` design skills, `watch` | nothing Retrospect-specific: no skill that knows our app, our Paper file or our launcher |
| **5. Style guide** | strong | design-system principles, `craft.md`, screen rules, your reviews in Paper | it's the part only you or I can check |
| **Gardener** | yes, informally | I review every PR and log findings | gardening isn't scheduled, and corrections aren't sorted by which layer fixes them |
| **Outer loop** | none | n/a | nothing to connect yet: no users, no crash reporting |

The honest reading: when an agent got something wrong, we've mostly answered by **writing another rule** (memory files, longer plans). By her ordering that's the third-best fix, and it's the one that quietly fails when an agent doesn't read it.

## 3. What we take, change and reject

### Take as-is

- **Every correction is fixed at the strongest layer possible.** This becomes rule 11 for every agent (README §7) and a line in my review checklist: each finding is tagged with the layer it gets fixed at, and "write a rule" needs a reason why a check can't do it.
- **A verification tool of our own, with a CLI and a feature map** (byte **V0.1** below). It's the biggest gap. It also serves your "dont open the simulator" rule: agents check their own work headlessly and show you screenshots next to Paper.
- **Lint the moment a bad pattern appears, clean up later.** This stops the spread on day one, before any cleanup.
- **One paved path per job.** It's already the plan's shape (`Platform/` namespaces, the door kit, tokens); now enforced by checks rather than prose.
- **A codebase that's strict for humans.** No cost to us: you don't write the code.

### Change for a team of one

- **Comments: ban workaround comments, keep explanations.** She bans all comments. We ban the dangerous kind: `TODO`, `FIXME`, `HACK`, `workaround`, `temporary` and commented-out code fail lint, unless they carry a findings-log id (`// F-112: …`), so every workaround is on record and has an owner. We keep doc comments that explain *why* on public `Platform/` APIs and doors, because our agents are short-lived and start cold every time: the why has to live somewhere they'll read. Decision **D15**.
- **The goal is fewer interventions, not more agents.** She runs hundreds of agents on a company's cloud. We have one Mac, one CI runner, and your rule of one agent at a time after the disk filled up. Our speed limit is the runner and your design reviews, not the agent count. So the ladder buys us agents that need correcting less, and PRs I can merge on evidence. Agent count goes up only when the runner allows (D12, D16).
- **The feature map is kept true by CI, not a background bot.** Her map is updated by an automation. Ours is checked in CI: every route in `Platform/Routing` and every launcher screen id must have a row, or the build fails. Cheaper and just as reliable at our size.

### Reject (for now)

- **The outer loop.** There's nothing to listen to yet. Revisit at the first external TestFlight: crash reports or a feedback inbox would then trigger a "reproduce this with the launcher" byte automatically.
- **Formal methods** (Lean, TLA+). Wrong cost for us. Our invariants (one user can't see another's data; a write sends exactly once) are covered by the two-user and retry tests in `testing.md`.
- **A custom framework like her "Dune".** We get the same effect from the `Platform/` layer, the door kit and lint boundaries, without building a framework.

### What other teams add

From 15 other sources (OpenAI, Stripe, Anthropic's Claude Code team, Cursor, Willison, Hashimoto, Beck, Ronacher and more; full report in the scratchpad's `research/agentic-workflows.md`). Every number in them is self-reported. Most agree with her. Six practices are worth taking:

- **Lint messages name the fix.** "Use `RShape(.card)`; corners come from `RCorner`" instead of "rule violated". An agent fixes a named mistake on the first try.
- **New tokens need a gate too.** Agents get around token rules by inventing new tokens. A change to `tokens.json` needs the integrator's approval and a matching Paper value.
- **Checks run at the moment of editing, not only in CI.** A hook runs token-check and lint after each edit and before an agent can say it's done (Claude Code hooks in the project settings).
- **Short rule files that work as a map.** OpenAI keeps its agent rules to about 100 lines, linking to deeper docs; long files get skimmed. Our README is long, so agents get a one-page `AGENTS.md` that points into it, plus a table of every rule and what enforces it.
- **A retry budget.** Stripe caps an agent at two CI rounds before a human looks. Ours: two red CI runs or two failed corrections on one byte, and the agent stops and reports; I restart it fresh rather than let it dig.
- **A check is added when a mistake has happened twice,** and it must be shown to fail on that real past mistake (Tan's own `/correct` skill). This stops us writing checks for problems we've only imagined.

The solo engineers (Willison, Hashimoto, Beck) all run one to three agents at once, because review is the limit. That matches D16. No source lets agents merge their own work until weeks of audits come back clean, so the human merge stays.

## 4. What changes in the plan

New phase 0 bytes, owned by the integrator unless noted, done **before the first component byte**, because every later PR inherits them:

| Byte | What | Layer |
|---|---|---|
| **G0.1** | **SwiftLint on `DesignSystemV2/`, `Platform/` and `Features/` only** (the old app stays out until it's retired). Custom rules: no `Color(red:` or hex or raw font sizes outside `DesignSystemV2/Generated`; no `RoundedRectangle` or `.cornerRadius(` (squircles only); no `withAnimation(.linear` or `.easeInOut(duration:` (motion only from `RMotion`); no `UIImpactFeedbackGenerator` outside `RHaptic`; no `print(`; `Logger` string interpolation must not be marked `.public`; no `TODO`/`FIXME`/`HACK` without a findings id | static |
| **G0.2** | **Import boundaries:** `Platform/` never imports SwiftUI views or old singletons; `Features/` never touches `URLSession`, the keychain or GRDB directly (only `Platform`); the old app never imports `Features/`. A script in CI | codebase + static |
| **G0.3** | `token-check.mjs` and a secret scan (gitleaks) in CI | static |
| **G0.4** (backend) | ESLint with `no-restricted-imports`: the agent client is only importable inside the door kit, `process.env` only inside `config`, no `console.log` in `src/v2` | static |
| **V0.1** (UI + plumbing, after T02) | **`scripts/rc`, the Retrospect control CLI**, plus a project skill that teaches agents to use it. `rc screen <id> --state <s> --theme dark --text ax3` opens a screen headlessly and screenshots it; `rc compare <id>` puts it beside the Paper export; `rc record <flow>` records a flow; `rc hitches` runs the animation-hitch trace. Comes with `docs/team/feature-map.md`, checked in CI | verification |
| **G0.5** | **Edit-time checks and the rule map:** a project hook runs token-check and SwiftLint on changed files after each edit and before the agent stops; `tokens.json` changes need integrator approval; a one-page `AGENTS.md` with the table "rule → what enforces it" (code, lint, CI, hook, review, or prose only); every lint message names the fix | static + rules |
| **V0.2** | My review checklist and the report format gain "**which layer fixes this**" for every finding; a weekly gardening byte deletes debt the lint rules have frozen | gardener |

Sizes: G0.1 about half a day, G0.2 two hours, G0.3 an hour, G0.4 two hours, G0.5 half a day: **about a day of work in total**, done on day one while the backend and plumbing engineers start their own work. Only the first UI component waits for it. V0.1 (`rc`) is the big one; it doesn't block anything and is built alongside the first components, and they switch to it when it lands.

## 5. Decisions for the founder

| # | Decision | Lean |
|---|---|---|
| D15 | Comments | **decided 21 Oct: workaround comments banned**; "why" doc comments stay |
| D16 | Agent count: stay at one agent at a time until a second runner is set up, then two, never more on one Mac | yes |
| D17 | Guardrail checks on day one, in parallel; `rc` alongside the first components | yes: about a day, and only the first UI byte waits |
