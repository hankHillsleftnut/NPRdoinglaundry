# V2 dark launch: how a V2 screen stays out of the release app, and how a wiring PR lets it in

V2 (every Paper screen other than the core 12, splash → first home) merges to `main` like any other PR, but **dark**: reachable only from the debug launcher (`-Screen <id> -State <state> -Data sample`) and the design lab. The founder turns a group on after testing the core flow, with one small wiring PR per group (plan: `pipeline/plan-v2.md` §1).

## The guard: `ReleaseRouteTableTests`
`Retrospect/RetrospectTests/Features/Launcher/ReleaseRouteTableTests.swift` runs in hosted CI with every PR.

1. **Pinned route tables.** Every case of the release root (`NewAppRoot.Screen`), the launch table (`FirstRunRoute`) and the sample flow (`FlowStep`) maps to a route in `approvedRoot` / `approvedLaunch` / `approvedFlow`. The switches are exhaustive, so a new release-root or launch case doesn't compile until it is named there. `approvedFlow` already lists all core-12 steps, so the core lane adds its steps without touching the test; any other step fails.
2. **Fenced folders.** V2 screens live in the dark folders: `Features/Shell`, `Features/Entries` (JR-3, JR-4), `Features/Podcasts` (PC-1, PC-3), `Features/You`, `Features/Settings`, `Features/Goals`, `Features/Outside`. No Swift file outside them names a type declared inside them (comments and `private` helpers are ignored), except the launcher (`Features/Launcher/**`, where each group registers its screens in `Registry/<Group>Screens+Launcher.swift`) and the lab (`DesignSystemV2/RLabPages*`). So a tab, drawer row, sheet, deep link or flow step can't open a V2 screen.

Shared components a V2 screen needs are built once in `DesignSystemV2/Components` (lane 0). They are not fenced: core screens may use them.

## What a V2 PR may not do
- Add a case to `NewAppRoot.Screen`, `FirstRunRoute` or `FlowStep` for a V2 screen.
- Name a dark-folder type from any app file outside the dark folders, the launcher or the lab.
- Edit `ReleaseRouteTableTests.swift`. The checker fails a V2 PR that touches it.

## The wiring PR (founder-approved, one per group)
1. The founder says go for a group (it is quoted in the PR body, with the date).
2. The PR mounts the group: tab bar entry, drawer row, routes, flow edges, whatever the group needs.
3. In `ReleaseRouteTableTests.swift` it (a) removes the group's folder from `darkFolders`; (b) adds the group's release routes to `approvedRoot` / `approvedLaunch` (and the switch cases), or flow steps to `approvedFlow`; (c) changes nothing else.
4. The PR body lists the route-table diff in a section called "Route table", so the checker can compare it with the founder's go.

A PR that edits the table without a quoted go is sent back.
