# Before you push: what reviewers caught today, so you catch it first

> **Prototype mode until Beta 1 ships** (founder, 22 Oct): `docs/team/prototype-mode.md` overrides this file where they differ — a fresh reviewer only on risky PRs (sign-in, sessions, store, outbox, doors, brain queries, diagnostics, migrations); one PR per whole component, page or route; exact Paper matching only for P09–P12, their visible components, the invite ticket and M14; nits go to `docs/team/polish-list.md`.

Every PR gets three reviews (an automated pass, a fresh reviewer and the integrator). Each fix round costs about an hour. Check these yourself before the first push.

**Every PR**
- Test at the level the card names: a promised HTTP status or header gets a **route-level** test, not just a helper test.
- No real clock, randomness or network in tests: inject `Date.now`, `randomUUID` and fetch.
- Every failure branch the code handles has its own test (DB error, unique violation, lookup miss).
- Logs: only closed lists and ids. Any string that comes from the client (headers, ids, codes) is checked against a fixed list or a strict numeric pattern, never a loose regex.
- Error text: print codes, not `error.message`, which can carry row values.
- Inputs: cap the length of every client-supplied key, wherever it comes from (header or body).

**Backend and scripts**
- A script that writes to a database proves it's the right database by checking the database itself, not an env label. Env files must override the shell (`override: true`).
- Spend and limits: every contract field (`retryAfterSeconds`) is produced, and clocks that go backwards are handled.
- Unsupported or junk tokens give 401, never 500.

**App**
- Every corner goes through `RShape`; no raw shadow, colour or size numbers in components.
- VoiceOver actions only when they do something; VoiceOver paths take the same code path as touch (haptics, failure handling).
- Gestures never steal scroll or a child button's tap; use `simultaneousGesture`.
- No auto-focus or keyboard pop the person didn't ask for.
- Never leave a timer or observer alive past its view, and no infinite waits.

**Added 22 Oct (later reviews)**
- Never switch a view's identity (`if`/`else` around content) on a flag that changes at runtime. Use modifiers that take the flag.
- Key `ForEach` by stable id, never by offset.
- A text style or transition that already exists elsewhere gets reused from `RType`/`RMotionModifiers`, not copied.
- VoiceOver text: commas, not " · ". Announce a state change once per change, not once per appearance.
- Haptics fire once per event, not on every re-insert of a view.
- `Color.opacity` multiplies: to make a colour opaque, store the base colour.
- Decide screen-size layouts from the window or scene, never from a subview's own size.
- Models: nest them in namespaces (`Flows.…`), give list rows a stable identity across state changes, and decode every fixture file (a test fails on any unmapped one).
- The test host must start an empty app: no notifications, observers or network.
- A test must fail when the rule it proves is removed. Try deleting the check; if the test still passes, it proves nothing (e.g. assert the agent was never called on a refused request).
- Waiting for builds: `while pgrep -x xcodebuild >/dev/null; do sleep 15; done`. A `pgrep -f` pattern matches its own shell and waits forever.

**Added 22 Oct (morning reviews)**
- "Erase everything for this person" never lists tables by hand: derive the list from the schema, or add a test that the list equals every table. On a different account, delete the database file, not just rows (deleted rows stay readable in the file).
- Every security check is tested against the real checker, not only a stand-in: sign real tokens with local keys and prove each bad one is refused (wrong audience, wrong issuer, wrong algorithm, expired, unknown key).
- Settings parsed from a URL can override the safe settings you pass beside it (e.g. `sslmode=` in a database URL turns certificate checks off). Refuse those parameters, and test with a real client built from a hostile URL.
- Optional, cosmetic fields never block a sign-in or a save: strip or drop them. Never store identity data the client sends unless the verified token carries it.
- Dates read back from storage decode with or without fractional seconds.
- GitHub's API limit (5,000 an hour) is shared by every agent: check CI every few minutes, never in a tight loop.
