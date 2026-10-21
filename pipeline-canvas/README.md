# Pipeline canvas

Every step of Retrospect on one canvas — capture, upload, ingestion, span
verification, promotion, podcast generation — with whether each step is working
and what it last processed.

It exists because the product had no surface that would have shown the May 2026
failure, where a billing lapse killed 2,034 of 2,268 entries and nothing retried
them. The board's first job is to make that kind of damage impossible to miss.

## Running it

```bash
npm install && npm run dev
```

Then open http://localhost:3100 and sign in.

`.env.local` needs:

| variable | what it is |
|---|---|
| `SUPABASE_URL` | the project URL |
| `SUPABASE_SERVICE_KEY` | service key — **server-side only, never exposed to the browser** |
| `CANVAS_PASSWORD` | the password for the login gate |
| `CANVAS_SESSION_SECRET` | 32+ random characters used to sign the session cookie |

## Why reads are server-side

Every RLS policy in this database keys on `auth.uid()`, but `public.users.id` is
a fresh `uuid_generate_v4()` created by the backend from Apple sign-in. Supabase
Auth has never been used by this product, so `auth.uid()` never equals any
`user_id` in any table. For the `anon` and `authenticated` roles, RLS here is not
a filter — it is deny-all.

So a browser client would read nothing. Every query runs in a Next.js route
handler with the service key, and only computed node states are sent to the
browser. The key is never bundled; `npm run build` plus a grep of `.next/static`
confirms it.

The reads are aggregates only. No `raw_content.content`, no
`assertion_evidence.excerpt`, no `final_script`, no embeddings, and nothing from
`integration_credentials`. This database holds 27 people's journals and the
board must never carry their words anywhere.

## How a node knows its own health

`pipeline_run_traces.kind` only accepts five values, so most steps can never have
a trace row of their own. Instead each node declares a **slice of a rollup**:
a source, optionally a bucket, and which statuses count as failure. One
aggregation pass feeds all 69 nodes, and adding a node is a pure TypeScript edit
in `lib/nodes/` with no new query.

Seven states, and the distinctions between them are the point:

| state | meaning |
|---|---|
| `ok` | ran recently, nothing failed |
| `degraded` | ran, some of it failed |
| `failed` | most of what went through it failed |
| `idle` | has history, nothing inside the window |
| `never` | this table has never held a row |
| `notInstrumented` | nothing records this step — not a health claim |
| `unknown` | the read failed — **never rendered as healthy** |

`unknown` and `notInstrumented` exist so the board cannot quietly imply health it
has not measured. A failed query showing green would be worse than no board.

Failure outranks recency on purpose: a step whose last 2,000 rows failed reads
`failed`, not `idle`, however old the failures are. That is the May 2026 lesson
encoded as a rule.

## Zoom is the detail control

All 69 nodes are always on the canvas. At fit-view the board is around 0.3 zoom,
where a 260px card is ~80px wide and body text is unreadable, so cards change
what they render instead of shrinking into noise:

- below 0.45 — a colour and a glyph; the board reads as a health mosaic
- 0.45 to 0.80 — status dot and title
- above 0.80 — purpose, caveats and last-processed detail

## Checks

```bash
npm run check:manifest
npm test
```

`check:manifest` enforces the manifest as content: every node needs a real
purpose sentence, every `notInstrumented` node needs both a reason and the
specific change that would light it up, every edge must resolve, and no two nodes
may occupy the same layout slot.

`npm test` covers the health resolver, and the first test is the one that
matters: a failed read must never resolve to `ok` or `notInstrumented`.

## What it shows today

Roughly 20 of 69 steps are `notInstrumented`, and that is the honest state of the
product rather than a shortcoming of the board. The whole iOS surface is blind —
a failed upload leaves no evidence anywhere — and span verification, the single
most important gate in the product, computes its drop rate during every run and
then discards it. Each of those cards names the change that would fix it.
