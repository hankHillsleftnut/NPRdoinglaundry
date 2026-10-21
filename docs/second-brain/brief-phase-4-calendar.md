# Brief — Phase 4.1, getting your calendar in

**Decided 18 October 2026:** Google Calendar comes in **as part of the Google
integration** — the same sign-in as Docs and Gmail — and **Apple Calendar is
asked for separately**, through the iPhone. In your words: "some people have
Apple calendar and some people have Google calendar … hook up the Google
calendar as part of the Google integration, and ask for their Apple calendar
separately." Step 4 of the [decision loop](./decision-loop.md).
Checked against the code and production on 18 October 2026.

## Why calendar first

Six of the 36 questions are mainly answered by a calendar — what a normal week
looks like (12), what you reliably do (13) and skip (14), when you're at your
best (15), what changed this month (16), who you spend time with (22). Today
"What you actually do" is **silent: 0 of 6 confident**, and your account has
**0 calendar entries**.

## What exists already

- **The iPhone app has a calendar reader** (`NativeSourcesManager.swift`). It
  reads every calendar on the phone — iCloud, Google, work — and uploads events
  as `calendar` items. It has never produced a row for your account: either it
  was never switched on, or the upload path is broken. Not yet diagnosed.
- **The server has Google sign-in code** for Docs, Gmail and YouTube.
  **Corrected 19 October 2026:** earlier this said "with credentials
  configured". It was not — `GOOGLE_OAUTH_CLIENT_ID` and `_SECRET` were never
  set in production, so Google sign-in has never worked (the one Google Docs
  connection sits at "action required"). Setting them up is step 1 of
  connecting anything Google.
- The agent's integration runtime is **off** in its settings (no encryption key,
  no runtime switch), so even the Gmail and Docs connectors have never run there.

## Options

### A — The iPhone reads your calendar *(recommended to start)*

**What you'd do.** Tap "Allow calendar" once in the app.
**What you'd notice.** Works with every calendar on your phone, not only
Google. Updates when the app is opened or refreshes in the background (iOS
decides how often). Nothing about your calendar touches Google's servers.
**What it costs.** Diagnosing why it has never uploaded for you; probably small.
**How it fails.** If you rarely open the app, the calendar lags. Events created
on other devices arrive only once the phone has them.

### B — A Google Calendar connector on the server

**What you'd do.** Sign in with Google once and approve read-only calendar access.
**What you'd notice.** Updates in the background without the app, including
edits made on a laptop. Only Google calendars.
**What it costs.** A new connector (the Docs and Gmail ones are the pattern),
switching the integration runtime on, and an encryption key. Medium. Calendar
access is a "sensitive" Google permission: fine for up to 100 test users while
the app is unverified — enough for your 10–30-person beta — but needs Google's
review before a public launch.
**How it fails.** Google's sign-in tokens expire or get revoked; the product must
notice and ask again (the runtime has this, untested).

### C — Both

A now for every calendar; B later for background updates. Most coverage, most
work.

## Recommendation

**A first, then B with Gmail.** A is mostly built, covers every calendar, and is
the fastest route to the six silent questions. B belongs with Gmail (4.2–4.3),
which needs the same runtime switched on and the same Google review — doing them
together pays that cost once.

## The gate

Per the architecture: named questions move from unanswered to answered. For
calendar: at least 4 of questions 12–16 and 22 answered from calendar evidence
within a week of connecting. A connector that moves nothing gets reverted.

---

## Diagnosis, 18 October 2026 — why the iPhone calendar never arrived

Read-only check of the code on `main` and of production.

**Not the agent.** The agent's queue route is mounted and accepts uploads even
with the integration runtime off. The first calendar upload would have created a
calendar connection and a queued job. Production has **neither, ever** — and no
connection for Apple Music, Photos or Contacts either. So no phone upload of
this kind has ever reached the agent.

**The phone's normal uploads work.** 780 Health rows and 2 Screen Time rows
arrived via the ordinary upload route. Only the newer batch route
(`/integrations/:provider/device-batches`, shipped 8 August) has never succeeded.
The payload the phone builds passes the backend's validation on paper.

**What's left, and what settles it:**
1. The app on your phone predates 8 August, or the calendar sync was never
   triggered (it runs from the integrations screens after you allow access).
2. The backend → agent call for this route fails. Backend logs on Render for
   `device-batches` would show it in one search.

**A design problem found on the way, worth fixing regardless.** The phone marks
every individual calendar event *not for analysis*, and sends one rolling
summary instead: the first 80 events, cut at 3,500 characters, overwritten on
each sync. So even working, the product would see a thin slice of your
calendar — not enough for "what does a normal week look like". The phone also
sends event notes and call links, which the Google Calendar connector
deliberately leaves out for privacy. Recommendation: events analysable
individually (as the Google connector does), notes and links dropped.
