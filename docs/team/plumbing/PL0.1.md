### PL0.1 · Tests that actually run (T00)                                  size: M
Place in the tree: product › platform foundations › testing › the Platform test plan
Repo · branch: NPRdoinglaundry · pl/PL0.1-tests-run
Needs: PL0.4      Unblocks: every Platform byte (each must add tests that run), the integrator's CI `test` step

Why: the app has eight tests and nothing runs them; CI only checks that it compiles. After this, every behaviour a later byte adds is checked automatically on every PR.

Inputs:
- Reference: app-reference.md §14 (tests, scheme XML, CI), §1.1 (AppDelegate), §1.4 (root ladder); testing.md §1 layers 4–5, §3 T00.
- Code anchors:
  - `Retrospect/Retrospect.xcodeproj/xcshareddata/xcschemes/Retrospect.xcscheme`: the `<TestAction … shouldAutocreateTestPlan = "YES">` with no `<Testables>` and no test plan.
  - `Retrospect/RetrospectTests/RetrospectTests.swift` (Swift Testing template), `SleepMathTests.swift` (7 real tests).
  - `RetrospectTests` target: `TEST_HOST` = the app, `BUNDLE_LOADER = TEST_HOST` (pbxproj), so tests boot the whole app.
  - `Retrospect/Retrospect/RetrospectApp.swift:15-23` (`didFinishLaunching`: notification delegate, `SubscriptionManager.shared.configure()`, `IntegrationBackgroundTasks.register()/.schedule()`), `:146-147` (the `WindowGroup { ZStack {` that starts the root ladder).

Spec:
- `Retrospect/Platform.xctestplan` (JSON test plan): one configuration "Default", testable `RetrospectTests`, `parallelizable: false` for now (one simulator), test timeouts on (`maximumTestExecutionTimeAllowance` 60 s), random execution order on (finds hidden order dependencies early), code coverage on for the app target.
- The scheme's `TestAction`: `shouldAutocreateTestPlan = "NO"` and `<TestPlans><TestPlanReference reference = "container:Platform.xctestplan" default = "YES"/></TestPlans>`. Edit through Xcode (Product › Test Plan), then read the XML diff.
- Test-host guard (a bridge, two small edits):
  - New `Retrospect/Retrospect/Platform/Platform+TestHost.swift`: `extension Platform { static let isRunningUnitTests: Bool = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil }` (the `Platform` namespace enum is created here if PL0.2 hasn't landed; PL0.2 then moves nothing).
  - `RetrospectApp.swift:15-23`: first line of `didFinishLaunching` becomes `guard !Platform.isRunningUnitTests else { return true }`.
  - `RetrospectApp.swift:147`: the first branch of the `ZStack` becomes `if Platform.isRunningUnitTests { Color.clear } else if isDesignLabMode { …` (the existing ladder continues unchanged).
- Test support (new, under `Retrospect/RetrospectTests/Platform/Support/`):
  - `StubProtocol.swift`: a `URLProtocol` subclass with a per-test registry (`StubProtocol.register(_ handler: @Sendable (URLRequest) throws -> (HTTPURLResponse, Data))`), a request log for assertions, and a `URLSession.stubbed()` factory. Each test registers its own handler and clears it (no shared global state across tests: key the registry by a per-session header the factory adds).
  - `Fixtures.swift`: `enum Fixtures { static func data(_ contract: String, _ name: String) throws -> Data }` reading `docs/team/contracts/fixtures/<contract>/<name>.json` from the repo, located from `#filePath` (tests run in the simulator on the Mac, which can read the repo's files). A missing fixture fails with the exact path in the message.
  - `TestClock.swift`: a controllable clock conforming to `Clock` (for backoff tests later).
- One smoke test, `PlatformSmokeTests.swift`: "the app boots as a test host without side effects" (asserts `Platform.isRunningUnitTests` is true).

Steps: test plan → scheme → guard → support files → smoke test → run locally twice (once in random order) → PR → the integrator adds the CI step in a separate PR.

Acceptance:
- `xcodebuild test -project Retrospect/Retrospect.xcodeproj -scheme Retrospect -testPlan Platform -destination 'platform=iOS Simulator,id=<assigned>'` runs 9 tests (7 SleepMath, the template, the smoke test) and passes.
- During the test run, no network request leaves the simulator (the integrator checks with the stub's log and by running with the Mac offline once).
- A normal app launch is unchanged (screenshot of the launch screen before and after).

Tests (layer 5): "the app boots as a test host without side effects"; "a stubbed session returns the registered response"; "a request with no registered stub fails loudly"; "a missing fixture names its path".

Proof in the PR: the `xcodebuild test` summary; the scheme XML diff; the two-line diff in RetrospectApp.swift.

Watch out:
- Don't add `<Testables>` by hand alongside a test plan: the plan owns the testables.
- `XCTestConfigurationFilePath` is set for unit tests and UI tests' test runner, but not inside the app launched by a UI test; UI tests (T02, layer 8) use their own launch arguments, so the guard doesn't break them.
- Keep the guard to those two lines; every other old file stays untouched.
