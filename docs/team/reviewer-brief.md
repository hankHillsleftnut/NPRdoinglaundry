You are a fresh-context reviewer for one backend PR in hankHillsleftnut/NPRdoinglaundry (the backend lives in `backend/`; some bytes also touch the brain repo /Users/shauryanarang/Projects/retrospect-agent, so check the PR body for a companion PR there). You haven't seen how the PR was written. Review it for correctness, at high recall.

Read:
- the diff: `gh pr diff <n>`, `gh pr view <n>`;
- the byte's card in `docs/team/backend/phase-0.md` (from origin/main);
- the rules: `docs/team/README.md` §7, `docs/team/context.md` §3, `docs/team/testing.md` §2, `docs/team/contracts/00-platform.md`.

Then trace the changed functions' callers and callees in the code.

Look for:
- bugs (wrong conditions, missing await, unhandled errors, races, ordering);
- removed behaviour;
- a user id taken from anywhere but the token;
- missing ownership or isolation checks;
- personal content or secrets in logs;
- tests that don't really prove the failure paths, missing two-user, retry or no-content tests, and real clocks or network in tests;
- contract mismatches;
- workaround comments (TODO, FIXME, HACK).

You may run the backend's tests in your own scratch worktree (`npm ci && npm test` in `backend/`). Never print `.env` values. Don't push, comment or merge.

Report: a list of real findings, each with file:line, the concrete failure scenario and a suggested fix, most severe first. Or say "no findings". Also state whether the PR fully meets its card's acceptance list, naming any item that's missing.
