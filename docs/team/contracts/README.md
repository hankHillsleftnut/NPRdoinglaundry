# Contracts

A contract is the agreed shape of every request and response between the app and the backend's `/v2` doors, for one flow. It's written by the integrator before either side builds, from the field-level truth in `../reference/agent-api-reference.md` and `../reference/backend-reference.md`, and it's law: the backend engineer builds the doors to it, the plumbing engineer builds the client and `Live…` data to it, the UI engineer builds sample data in its shapes. Nobody changes a contract on their own side.

| # | Contract | Flow | Status |
|---|---|---|---|
| 00 | [00-platform.md](./00-platform.md) | envelopes, errors, headers, sign-in (Apple, Google), refresh, sign-out, access and invites, waitlist, meta | draft for review |
| 01 | 01-first-run.md | onboarding, knows-you, the first episode job, devices, purchases | written in phase 1, before phase 2 starts |
| 02 | [02-journal.md](./02-journal.md) | conversation (buffered and streamed), today, briefs, guesses, entries, what Retro took, corrections | draft for review |
| 03 | 03-podcasts.md | episodes, jobs, chapters, signed audio, evidence, feedback | later |
| 04 | 04-goals.md | goals, yes / not quite, evidence | later |
| 05 | 05-you.md | people, portrait, understanding, search | later |
| 06 | 06-settings.md | brief settings, ambient, how straight, voice, preferences, export, delete data, delete account | later |
| 07 | 07-outside.md | widgets, share extension, notification payloads, deep links | later |

## Rules

1. **Names are camelCase in JSON**, always. The door maps the agent's mixed snake_case and camelCase into this one convention. The app decodes with explicit `CodingKeys` only where a name differs; never `convertFromSnakeCase`.
2. **Dates** are ISO 8601 UTC with milliseconds (`2026-10-21T08:00:04.200Z`); calendar days are `YYYY-MM-DD` in the **user's** time zone, which the app sends as `X-Time-Zone` (an IANA name) on every request and the backend stores on `users.time_zone`.
3. **Ids** are UUID strings. Where the agent uses something else (a timestamp as an id), the door converts it or the agent is fixed first (BE1.0).
4. **Optional means omitted or `null`**, both decoded the same way; the contract says which fields can be absent.
5. **Enums are closed lists.** The app decodes an unknown value into an `unknown` case instead of failing, and the door logs any value outside the list.
6. **Every request and response has a fixture** in `fixtures/<contract>/<name>.json`: at least one full example, one minimal example and one for each error. Backend tests validate fixtures against the zod schemas; app tests decode the same files. A fixture that fails on either side fails CI on that side.
7. **Versioning:** a breaking change to a contract that has shipped is a new path (`/v2/…` → `/v3/…`) or an additive field. Before anything ships, the integrator edits the contract and both sides follow in the same phase.
8. **Content is never invented in fixtures to look real**: invented people ("sam", "priya"), invented words, never a real person's data.
