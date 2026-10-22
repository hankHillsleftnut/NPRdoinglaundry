# Testing: how we know the app behaves

Founder, 21 Oct: "if you're suggesting that we set up tests so that the app behaves properly, do that and make that part of the agent plan." Today the app has 8 unit tests that CI never runs (the scheme has no testables), the backend has 10 unit test files with no HTTP-level tests, and the agent's 680 tests run as a database superuser, which is how a production permission bug slipped through. This file is the testing standard every agent follows. A byte isn't done until its tests exist, run in CI, and pass.

## 1. The layers

| Layer | What it proves | Tool | Owner | Runs |
|---|---|---|---|---|
| **1. Agent unit and database** | each engine and route does the right thing, for one user only | `node:test` + PGlite | backend engineer | every agent PR |
| **2. Agent as production runs it** | queries work with the real role (`service_role`), not superuser | PGlite with the role switched (BEA.1) | backend engineer | every agent PR that touches SQL |
| **3. Backend doors over HTTP** | the nine door tests (backend plan §4) on every door | `node:test` + the BE0.2 harness and a fake agent | backend engineer | every backend PR |
| **4. Contract fixtures, both sides** | the app and backend agree on every shape | zod (backend) and `Decodable` (app) over the same files in `docs/team/contracts/fixtures/` | backend + plumbing | every PR on either side |
| **5. App Platform unit** | client, session, refresh, outbox, store, router, purchases behave, including every failure | Swift Testing, `URLProtocol` stubs, in-memory GRDB, fake Keychain and RevenueCat | plumbing engineer | every app PR |
| **6. Component snapshots** | every component state looks as approved, in light and dark and at a large text size | `swift-snapshot-testing` (Point-Free, pinned) | UI engineer | every app PR (T01) |
| **7. Accessibility audit** | no missing labels, contrast failures, small hit areas or clipped text | `XCUIApplication.performAccessibilityAudit()` per screen | UI engineer | every page PR |
| **8. Flow UI tests on sample data** | each flow's screens connect: navigation, states, back, errors | XCUITest with the T02 launcher (`-Screen <id> -Data sample -State <state>`) | UI engineer | every page PR, and nightly |
| **9. End to end on local staging** | the real app against the real backend and brain (local staging), with seeded test accounts | XCUITest with `-Environment local`, plus `scripts/staging-up.sh` | integrator | before each wiring PR and each ship gate |
| **10. Motion and performance** | no dropped frames; motion follows the system | Instruments (Animation Hitches), recordings | UI engineer, checked by integrator | each signature moment and flow pass |
| **11. On a real phone** | the feel: haptics, audio, push, sign-in, purchases (sandbox) | the founder's iPhone and TestFlight | integrator + founder | each ship gate |

## 2. What every PR's tests must cover

- **The happy path and every failure the code handles**, each as its own test with a name that reads as a sentence ("a reused refresh token outside the grace window revokes the family").
- **Isolation:** any code that reads or writes user data has a two-user test proving one user can't see or change the other's data.
- **Idempotency:** any write that can be retried has a test that retries it and finds exactly one result.
- **Offline (app):** any code that talks to the network has a test with the network down.
- **No content:** a test that log lines and analytics events carry no message text (Platform and doors).
- **Determinism:** no real clocks, randomness or network in tests: inject them.

## 3. The T bytes (the progress map's testing layer), now assigned

| ID | What | Owner | When |
|---|---|---|---|
| T00 | The app's tests actually run: test plan, scheme testables, test-host guard (PL0.1); CI runs them (integrator) | plumbing + integrator | phase 0, first |
| T00b | Agent tests run as `service_role` where SQL is involved (BEA.1) | backend | phase 0 |
| T01 | Snapshot tests for every merged and new component state, light and dark, AX3 | UI | phase 0, then with every component |
| T02 | The screen launcher: any screen in any state from launch arguments, on sample or live data | UI (views) + plumbing (data) | phase 0 |
| T03 | First run UI test: invite link → sign-in → code applied → you're in → questions → connect → paywall → first home | UI + integrator | phase 2 |
| T04 | Journal UI test: send typed and voice entries, offline then online sends exactly once, the brief plays, a guess is answered, "not right" works | UI + integrator | phase 1 |
| T05 | Podcasts, goals and you UI tests | UI + integrator | phases 3–5 |
| T06 | Settings and account UI tests, including delete account, restore purchases (sandbox) and sign-out | UI + integrator | phase 6 |
| T07 | Backend contract tests for every door (the nine tests) | backend | with every door |
| T08 | Seeded test accounts on staging for every flow; test spend logged separately | backend (BE0.S) | phase 0 |

## 4. CI

- Backend `api` job: build, typecheck, tests (adds layer 3 and the backend half of layer 4).
- Backend tests run as `tsx --test --import ./tests/support/env.ts …` (`npm test`): `env.ts` sets placeholder config before anything imports it, and `config.ts` reads no `.env` file when `NODE_ENV` is `test`. A new test needs no env setup of its own; HTTP tests use `tests/support/harness.ts` and doors use `tests/support/door-suite.ts`.
- Agent CI (its own repo): security check, typecheck, tests, build.
- iOS `ios` job: build, then `xcodebuild test -testPlan Platform` (layers 4, 5) and the snapshot test plan (layer 6). UI and accessibility tests (layers 7, 8) run on page PRs and nightly, because they're slow on one runner.
- A red test is never merged. A flaky test is fixed or quarantined in the same day, with a findings-log entry; never retried until green.
- Snapshots are recorded on the integrator's simulator configuration (iPhone 17 Pro, iOS 26.0) so they compare like with like; a deliberate design change re-records them in the same PR, with before and after images in the PR body.
