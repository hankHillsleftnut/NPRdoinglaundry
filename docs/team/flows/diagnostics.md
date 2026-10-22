# Session diagnostics and "send a report"

Founder, 22 Oct: "There should be a troubleshooting part to be able to check on how the user session went. We should track the user session, and there should be a system that looks at this where you can do a send report and it sends the entirety of the usage report… for you to then debug. This should be a feature."

**Beta 1: in.** A TestFlight beta lives or dies on tester reports, so this joins Beta 1 (six PRs, listed below).

## What the person sees

- **Settings › "send a report"**, plus **shake the phone anywhere** (the shake can be turned off).
- A sheet opens:
  - one line, "this sends what the app did in your recent sessions, so we can fix what went wrong";
  - an optional field: "what happened?";
  - a preview, "what's included", listing the parts with their counts;
  - **send**, the lit object.
- **Sent:** a toast reads "sent. thank you." It carries a short reference, e.g. `r-7KQ2`, that the person can quote.
- **Offline:** the report is saved and sent later. It goes through the outbox, so it's never lost.

## What a report contains (the "entirety of the usage report", within the privacy rule)

The privacy rule still holds: **no personal content**. That means no entry words, voice audio, names, guesses' text or search queries. A report is everything about *how the app behaved*, which is what debugging needs:

| Part | Detail |
|---|---|
| Session timeline | The last 7 days or 2,000 events, whichever is smaller. App launch and foreground; screen shown and left; a named control tapped (control id, never the text); sheets opened; playback started, paused and ended (ids and positions); permission prompts and answers |
| Network | Each request's route template (`/v2/entries/:id`, never real ids), status, error code, duration, retry count, and the idempotency outcome (new or replayed) |
| Outbox | Queued, sending, sent and failed counts; the age of the oldest item; the last failure codes |
| Errors | Every `Flows.Failure` with its code and screen; crash and hang markers from MetricKit (diagnostic payloads, symbolicated server-side) |
| Performance | Launch time, hitch rate per screen, memory warnings, and thermal state changes |
| Environment | App version and build, iOS version, device model, locale and time zone, Dynamic Type size, Reduce Motion, VoiceOver on/off, network type, and free disk (as a bucket) |
| Account state | The person's id (the token's user), access state (member, waitlist), entitlement, and the sign-in provider. No email |
| Their note | The optional "what happened?" text, which is the only free text, written for us on purpose and labelled so |

## How it works

- **Recording (Platform):** `Platform.Diagnostics` is an append-only event recorder.
  - Events are a closed enum, with ids and numbers only. **The type can't carry free text**, the same pattern as the backend's door log (#64).
  - It writes to a ring buffer in GRDB: 7 days or 2,000 events, pruned on launch. It lives on the device only until the person sends a report.
  - It's cheap: batched writes, never on the main thread.
- **Sending:** the outbox sends `POST /v2/diagnostics` with `Idempotency-Key` = the report id. The body is the bundle as compressed JSON (≤ 2 MB).
- **Backend:**
  - The door validates the schema strictly (unknown fields are rejected) and stores the report in a private bucket under the token's user, kept **30 days, then deleted**.
  - It returns the reference.
  - The door log records only the size and counts.
- **Reading reports:** an admin view, behind `ADMIN_SECRET`, lists reports by reference, user and date, shows the timeline, and lets the integrator download one. The integrator reads reports **only when the person sent one**, which is consent per report.
- **Delete my data and delete account** also delete diagnostics.

## The PRs (Beta 1)

| Id | Side | What | Needs |
|---|---|---|---|
| DG.1 | backend | `POST /v2/diagnostics`: strict schema, private storage, 30-day expiry job, reference; contract 00 addendum and fixtures; deletion hooks | BE0.2 |
| DG.2 | backend | Admin report viewer: list, timeline, download; behind `ADMIN_SECRET` | DG.1 |
| DG.3 | Platform | `Platform.Diagnostics` recorder: closed event enum, GRDB ring buffer, pruning; a test that no event type can hold a String | PL2.1 |
| DG.4 | Platform | Instrumentation: client (route templates, status, timing), outbox, failures, MetricKit, and the environment snapshot | DG.3, PL1.1b |
| DG.5 | Platform | The report builder and sending through the outbox | DG.3, PL2.2a |
| DG.6 | views | The "send a report" sheet, the shake trigger and its switch, the sent toast with its reference, and the settings row | DG.5, C19.1 |

**Tests:**
- Two-user isolation on the door.
- A retry stores one report.
- A test that no free text appears anywhere except the labelled note.
- A test that the bundle has the exact field list.
- An offline send that delivers later.

## Questions (work goes ahead on the lean)

| # | Question | Lean |
|---|---|---|
| DQ1 | Should the shake trigger be on by default? | Yes in TestFlight builds, off in App Store builds. |
| DQ2 | Should crashes send a report automatically, without asking? | No. Ask on the next launch: "the app closed unexpectedly. send a report?" |
| DQ3 | How long are reports kept? | 30 days. |
