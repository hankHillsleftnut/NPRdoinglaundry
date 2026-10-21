# Integrator · plan

The integrator is the main Claude session: the principal engineer who owns the whole, keeps two agents unblocked and non-colliding, holds the bar on every PR, writes the contracts and wiring, and is the founder's single point of contact. This file is the integrator's own operating plan; agents read it to know what to expect from the integrator.

## 1. Responsibilities

1. **The board** (`board.md`): assign every byte, keep each agent at most one byte ahead, record status. Agents never self-assign.
2. **Contracts** (`contracts/`): write each flow's contract before either side builds against it, with its JSON fixtures; publish the flow's Swift data protocol and models (`Platform/Flows/<Flow>.swift`) from the contract; change a contract only by a PR that names every byte it affects.
3. **Shared files**, edited only by the integrator, each change in its own small PR: `tokens.json` and generated Swift, `RType.swift`, `RDepth.swift`, `RMotion*.swift`, `RMotionLab.swift` (lab pages), `RetrospectApp.swift`, `.github/workflows/**`, `.swiftlint.yml`, `.swiftformat`, `project.pbxproj` beyond what a byte names, new targets (share extension), `docs/team/**`, the progress map, the plan, the checklist.
4. **Review** every PR as a reviewer: the diff line by line; removed behaviour; callers; duplication; naming; comments; tests that prove the behaviour; screenshots against Paper (UI); contract conformance; security (user from token, ownership, no content in logs). Findings go back to the agent; one-line fixes may be made directly and noted in the PR.
5. **Merge** when CI is green and the review is clean, in dependency order; never delete a branch something is based on; check main builds after each batch of merges.
6. **Wiring PRs**: swap a flow's `Sample…` for `Live…`, prove it on staging with the test account, clear the flow's rows in the sample-data ledger.
7. **Flow passes and ship gates**: navigation, transitions, signature moments on a device; recordings for the founder; the gate checklist; turning the flow's switch on; deleting the flow's old screens.
8. **The founder**: decisions (README §10), founder actions, deploys and production migrations (each with a backup and an explicit yes), progress reports in plain words.
9. **Records**: the build chronicle (every step), the findings log (every discovery and every mistake), `context.md` (kept current), the progress map and plan status.
10. **The machine**: disk, simulators, derived data, the CI runner's health (it died once on a full disk and sat "busy" for two hours).

## 2. The first moves (phase 0, in order)

1. Merge the reviewed backlog in dependency order, resolving the conflicts left by stacking (#42, #44–#46, #48, #50, #52–#56), so every agent starts from one clean `main`.
2. Land this plan (`docs/team/**`) on `main`.
3. Write `contracts/00-platform.md` (envelopes, errors, auth, invites, meta, version header) and its fixtures.
4. Write `contracts/02-journal.md` and its fixtures, then `Platform/Flows/Journal.swift` (protocol + models), so the app engineer can start on the journal the moment their foundations land.
5. Shared-file PRs the agents will need first: Platform added to lint, CI `test` step once PL0.1 lands, Node 22 in CI for BE0.0, the progressive-blur modifier for the tab bar.
6. Draft the invite screens in Paper (the waitlist, the invite screen with the typed-code fallback, "your invites" with three links, and **M14, the celebratory "you're in" moment**: the founder's priority) from the splash's parts, for the founder's approval. Needs Paper Desktop running.
7. The Beta 1 guardrails ([first-ship.md](./first-ship.md)): SwiftLint on the new folders, token-check and a secret scan in CI, and `AGENTS.md`. About half a day, done while the agents start.
8. Start the two agents (app and backend) together, one byte each.

## 3. How the integrator runs the agents

- Each agent is started with: README, context, its plan, the board row for its byte, and the contract if any. Its reply is the report format in README §8.
- At most one byte in flight per agent, plus the next one queued on the board, so an agent never waits on the integrator.
- If an agent's context grows very long (hundreds of thousands of tokens), the integrator retires it and starts a fresh one with the same plan and a short handover note in the board's notes column (this worked on 21 Oct).
- Agents that stop to ask are doing the right thing; answers go back the same day, and any answer that changes a plan is written into the plan.

## 4. Review checklist (every PR)

1. Scope: only the byte; only files in the agent's column.
2. Contract: shapes match field for field; fixtures updated on both sides.
3. Correctness: read every changed line; trace callers; look for removed behaviour.
4. Security and privacy: user from the token; ownership checked; no content in logs, analytics or fixtures; no secrets.
5. Tests prove the behaviour, including failure paths; CI green; checks actually ran.
6. UI: screenshots next to Paper's render of the same node, light and dark, Dynamic Type, every drawn state; motion on `RMotion`, haptics on `RHaptic`, corners on `RShape`, tokens only.
7. Plain-words PR body with what's not done and what needs the founder.
8. After merge: main builds; the board, progress map, chronicle and findings log updated.
9. **The gardener's question:** for every finding, which layer stops it from happening again (code, lint/CI, rule, skill, style guide)? Use the strongest one that works, as a follow-up byte when it's bigger than the PR. Once a week, a gardening byte deletes debt the lint rules have frozen.

## 5. The founder's build board

A live page pinned in the founder's sidebar: https://claude.ai/artifact/Uzk22xF2tMPKzxSkGF8Lsy. It shows each engineer's Beta 1 work as a tree (area › page › component › PR), what each engineer is doing now, and a log of updates and of everything I catch in review, with the layer that fixes it. I update it through its database (`status/<eng>` items, `meta/now`, `log`), never by republishing: when a byte starts, opens a PR, merges or blocks; when an engineer reports; and for every review finding. A new byte or a split goes into `plan/<eng>` first, so the board always matches the plan.
