# Ready for real testers? — the end-to-end checklist

Your target, 19 October 2026: get the engine as good as it can be, then test
the whole pipeline end to end with real people and see where it works and
where it doesn't. This is the finish line for the goal-spec work.

Status key: ✅ works · ⚠️ works with a known problem · ❌ missing or broken

## The working plan (19 October 2026, night)

Work is picked from this table, highest step first, after checking it is the
most valuable thing on that step. Anything new is logged here, not fixed on
the spot, unless it blocks the current step. Updates report against it.

| # | Step | Who | State |
|---|---|---|---|
| 1 | **One complete fake tester, end to end**, on the test account: sign-up, writing, onboarding pipeline, first pass, episode (no voice), daily brief. List every break | me | in progress |
| 2 | Fix what step 1 breaks, worst first | me | — |
| 3 | Make it live: merges, database changes (004–006, 127, 128), Render switches (onboarding pipeline, daily brief, researcher) | founder approves, I do | waiting |
| 4 | Tester access: TestFlight build, Google test users | founder | not started |
| 5 | Quality: weekly episode on the 36 questions (founder's listen), Notion import, AI-assistant email as low-trust, people in meetings | me | queued |

### Logged, not yet scheduled
- Email from other AI assistants: may be read as a fact ("exploring other assistants"); its contents are **not relied on** as evidence (founder, 19 Oct).

## A tester's journey, step by step

| # | Step | Status | Notes |
|---|---|---|---|
| 1 | Install the app | ❌ | Needs a TestFlight build with the current app ID (`com.shauryanarang.Retrospect`) and a public TestFlight link |
| 2 | Sign in with Apple | ✅ | Fixed today (old app copy had the wrong ID) |
| 3 | Onboarding questions | ⚠️ | Works; still the old 18 questions. New 8 drafted, waiting on your approval |
| 4 | Goals at the end of onboarding | ✅ | Seconds now, from their own words (#44, #12) |
| 5 | Connect Google | ⚠️ | Works — but **each tester's Gmail must be added as a test user** in Google Cloud (up to 100), and they'll see "unverified app" |
| 6 | Connect iPhone sources | ⚠️ | Health, Calendar, Contacts, Photos arrive; calendar as one thin summary (needs your yes) |
| 7 | First episode | ⚠️ | **Makes two full episodes (~$4 per tester), 3–5 min wait at a fake 94%, and showed you the demo though yours was ready.** Must fix before testers |
| 8 | Brain reads their data | ✅ | Facts from writing, mail, calendar; researcher updates the 36 answers |
| 9 | Researcher runs daily | ❓ | Code works; whether the daily job is switched on in Render (`ENABLE_QUESTION_RESEARCH`) is unverified |
| 10 | Weekly episode | ⚠️ | Generates; still built on the old framework ("Eleven weeks", counts its own outputs). Reading the 36 answers is behind a switch (`ANSWERS_IN_EPISODES`) awaiting your listen-test |
| 11 | Daily brief | ❌ | Designed and tested on paper; not built |
| 12 | See and correct what it knows | ❌ | Not in the app |
| 13 | Save links with a reason | ❌ | Not built (reference bank) |

## Behind the scenes

| Area | Status | Notes |
|---|---|---|
| Server stays awake | ⚠️ | Render free plan sleeps when idle — up to ~50 s on the first request, and it slowed your launches. Paid starter plan ≈ $7/month per service |
| Deploys | ✅ | Fixed today (#43) |
| Watching it work | ⚠️ | `pipeline-canvas` dashboard exists (read-only, behind login); not yet showing questions/answers per tester |
| Cost per tester | ⚠️ | First week ≈ $5–7 (two onboarding episodes, first sync, weekly episode); then ≈ $2–3/week, mostly voice. No per-user cap yet |
| Errors in plain words | ❌ | App shows raw "HTTP 500" |
| Privacy basics | ⚠️ | Data deletion route exists in the agent; privacy notice and consent wording not reviewed |
| Accounts: several sign-in methods per account | ⚠️ | Written in NPRdoinglaundry#5 (13 Sep), conflicts with main — update and merge before Google sign-in |
| Accounts: delete my account | ❌ | **Apple requires it**; also revoke the Sign in with Apple link |
| Accounts: sign out everywhere | ❌ | Sessions are 30-day tokens with no early cut-off |

## Must fix before the first outside tester

1. **One episode per onboarding**, real progress, no demo passed off as theirs.
2. **TestFlight build** + tester invite list (App Store Connect).
3. **Google test users** for each tester's Gmail.
4. **Confirm the daily researcher and weekly episode jobs are on** in Render.
5. **Plain-words errors** on sign-in and connect.
6. ~~A per-tester cost ceiling~~ — done (#48): $15/day ceiling and `npm run costs`.
7. **Account deletion** (Apple requires it) and NPRdoinglaundry#5 merged.

## Should fix early in testing
- Weekly episode reads the 36 answers (your listen-test decides).
- iPhone calendar per event.
- Render paid plan so nothing sleeps.
- Testers can see (and correct) what it thinks — even a simple list.

## Can wait for the new app
Daily brief, reference bank and links, constellation view, voice creation,
Google sign-in = connect, the full onboarding redesign.
