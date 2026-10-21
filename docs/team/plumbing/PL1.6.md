### PL1.6 · Version floor, app half                                          size: S
Place in the tree: product › platform › backend client › the version floor
Repo · branch: NPRdoinglaundry · pl/PL1.6-version-floor
Needs: PL1.1, backend BE0.10      Unblocks: the force-update screen (UI, once designed), X07 (retiring old routes safely)

Why: once old routes are retired, very old app versions must be told to update instead of breaking silently.

Inputs: contract 00 §2 (`update_required`, 426), §5 (`GET /v2/meta` → `minVersion`, `latestVersion` as `"1.0 (40)"`).

Spec:
- `Platform/Backend/AppVersion.swift`: `struct Backend.AppVersion: Comparable, Sendable { let marketing: [Int]; let build: Int; init?(_ string: String) }` parsing `"1.0 (42)"`; compares marketing numerically component by component, then build.
- `Platform.Environment.updateRequired` becomes true when any call throws `.updateRequired`, or `GET /v2/meta` (called once at launch and on each `.active`, at most every 6 hours) reports a `minVersion` above the running version. It never becomes false within a session once true.

Tests (layer 5): "1.10 (5) is newer than 1.9 (99)"; "a 426 sets updateRequired"; "meta with a higher minVersion sets updateRequired"; "an unparseable version never sets it and logs once".

Proof in the PR: test output.

Watch out: never compare version strings lexically.
