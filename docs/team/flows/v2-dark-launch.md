# V2 dark launch: how a V2 screen stays out of the release app, and how a wiring PR lets it in

V2 (every Paper screen other than the core 12, splash → first home) merges to `main` like any other PR, but **dark**: reachable only from the debug launcher (`-Screen <id> -State <state> -Data sample`) and the design lab. The founder turns a group on after testing the core flow, with one small wiring PR per group (plan: `pipeline/plan-v2.md` §1).

## The guard: `ReleaseRouteTableTests`
`Retrospect/RetrospectTests/Features/Launcher/ReleaseRouteTableTests.swift` runs in hosted CI with every PR.

1. **Pinned route tables.** Every case of the release root (`NewAppRoot.Screen`) and the launch table (`FirstRunRoute`) maps to a route in `approvedRoot` / `approvedLaunch`, through exhaustive switches: a new case doesn't compile until it is named there. Every `FlowStep` and every `FlowEdge.table` destination must be a member of `approvedFlow`, which already lists all core-12 steps, so the core lane adds its steps without touching the test; any other step or destination fails.
2. **Fenced folders.** V2 screens live in the dark folders: `Features/Shell`, `Features/Entries` (JR-2 today's brief in `Entries/Brief`, JR-3 in `Entries/Drawer`, JR-4 in `Entries/Entry`; JR-1 stays in `Features/Journal`), `Features/Podcasts` (PC-1, PC-3), `Features/You`, `Features/Settings`, `Features/Goals`, `Features/Outside`. No Swift file outside them names anything they add: their non-private types, their top-level functions and values, or members they add to types declared outside the fence (`extension JournalScreen { var podcastsRow … }`, with or without attributes such as `@available(iOS 18, *)`, however the opener wraps; nested types in such an extension count too). A type nested in a dark type is reached through its outer name, so its short name is not fenced on its own. Comments, string literals and `private` helpers are ignored; the scanner understands raw strings, multi-line strings, nested comments and interpolations (code inside `\( … )` is scanned). An `init` or `subscript` a dark folder adds to an outside type has no name of its own to look for, so a non-private one fails the test by itself (`extension RSheet where Content == PodcastsPage { init() … }` would let release code write `RSheet()`). The exceptions are the launcher (`Features/Launcher/**`, where each group registers its screens in `Registry/<Group>Screens+Launcher.swift`) and the lab (`DesignSystemV2/RLabPages*`). So a tab, drawer row, sheet, deep link or flow step can't open a V2 screen.

3. **The sandbox never ships** (founder, 27 Oct): test and state screens live in the sandbox, the launcher (`Features/Launcher/**`, every `*Screens+Launcher.swift`), the lab (`DesignSystemV2/RLab*`, `*Lab.swift`, `*Gallery.swift`) and any `Sandbox/` or `Lab/` folder. `SandboxFenceTests` (same folder) fails a PR when a sandbox file has code outside `#if DEBUG` (imports aside), when a `…Gallery`/`…Lab`/`…LabPage`/`…Launch`/`…Sandbox`/`…States`/`…Scenario`/`Sample…` type is declared in release code at any depth (the sample seams that already ship in core-12 files are pinned in `shippedSampleSeams`, a list that may only shrink), when release code (previews included) names a type that exists only in debug builds, or when a release route names a lab, sample, sandbox or state. It reads the source, so the Debug-only CI catches what only a Release build would.

Shared components a V2 screen needs are built once in `DesignSystemV2/Components` (lane 0). They are not fenced: core screens may use them.

## What a V2 PR may not do
- Add a case to `NewAppRoot.Screen`, `FirstRunRoute` or `FlowStep` for a V2 screen.
- Name a dark-folder type from any app file outside the dark folders, the launcher or the lab.
- Edit `ReleaseRouteTableTests.swift`. Nothing in CI enforces this yet (no CODEOWNERS rule or workflow check): the reviewer (the Opus checker) sends back any non-wiring PR that touches it.

## The wiring PR (founder-approved, one per group)
1. The founder says go for a group (it is quoted in the PR body, with the date).
2. The PR mounts the group: tab bar entry, drawer row, routes, flow edges, whatever the group needs.
3. In `ReleaseRouteTableTests.swift` it (a) removes the group's folder from `darkFolders`; (b) adds the group's release routes to `approvedRoot` / `approvedLaunch` (and the switch cases), or flow steps to `approvedFlow`; (c) changes nothing else.
4. The PR body lists the route-table diff in a section called "Route table", so the reviewer can compare it with the founder's go.

A reviewer sends back a PR that edits the table without a quoted go. (A CODEOWNERS rule plus branch protection, or a CI step that fails when this file changes and the body has no "Route table" section, would make this automatic; it's an integrator decision.)
