# Integration catalogue

Every source worth considering, 17 October 2026. Companion to goal 1 in
[goal-specs.md](./goal-specs.md).

**Two axes for every entry: what questions it answers, and whether it is actually
reachable.** Question numbers refer to
[canonical-questions.md](./canonical-questions.md).

> **Sourcing caveat, stated up front.** API availability below is from my own
> knowledge, not verified per source today. Platform access changes constantly and
> usually gets worse. **Each source's feasibility must be confirmed before it is
> scheduled**, as a step 2 survey item in the [decision loop](./decision-loop.md).
> Treat the access column as a hypothesis.

## Access classes

| | Meaning |
|---|---|
| **A** | Real OAuth API, usable now |
| **B** | API exists with friction — cost, admin consent, or narrow scopes |
| **C** | Export/import only. No live sync; the user downloads an archive |
| **D** | On-device only. Must be native iOS, cannot be a server connector |
| **E** | No access. Listed so nobody plans around it |

---

## 1. Google — the substrate

| Part | Questions | Access |
|---|---|---|
| Calendar | 12–16, 22, 25 | A |
| Gmail — metadata | 22, 25, 26 | A (restricted scope) |
| Gmail — sent bodies | 6, 24, 27–29 | A (restricted scope) |
| Drive / Docs | 2, 21, 29 | A (restricted scope) |
| Contacts | 22, 26 | A |
| Tasks | 6, 9 | A |
| Photos | 12, 22 | B — separate API, limited metadata |
| YouTube history | 18–21 | C — Takeout |
| Location history | 12, 15 | C — Takeout |
| Chrome history | 18–21 | C — Takeout or extension |
| Keep | — | **E** |

Gmail and broad Drive require a CASA assessment for public launch. Fine for a
beta under 100 users.

---

## 2. Apple and on-device

**All class D unless noted. This is iOS engineering, not connector work.**

| Source | Questions | Access |
|---|---|---|
| HealthKit — sleep, activity, heart | 13, 15, 17, 30 | D |
| Screen Time (`DeviceActivity`) | 18–21 | D — tightly restricted by Apple |
| Contacts | 22, 26 | D |
| Photos | 12, 22 | D |
| Apple Music | 15, 18, 30 | B — MusicKit |
| Calendar (local) | 12–16 | D |
| Reminders | 6, 9 | D |
| Apple Notes | 2, 21, 29 | C — PDF import, already built |
| Journal app | 27–29 | **E** |
| Messages | 22, 24, 29 | **E** — richest words most people have, unreachable |
| Safari history | 18–21 | **E** |

---

## 3. Professional identity — the cold-start sources

These answer questions 1–4, which nothing else can answer on day one.

| Source | Questions | Access |
|---|---|---|
| **LinkedIn** | 1–4, 26 | **B** — the official API is restrictive about profile data. Verify what is obtainable before relying on it. |
| Personal site / portfolio | 1, 2, 11 | A — just fetch it |
| **Web search on the person** | 1–5 | A — and often does LinkedIn's job with no integration at all |
| GitHub | 2, 7, 13, 14, 16 | A |
| Substack / blog | 18, 29 | A — RSS |
| Crunchbase / AngelList | 1–3 | B |

---

## 4. Socials

**The honest position: almost no social platform gives you a personal feed any
more.** What exists is your own posts, and data exports.

| Source | Questions | Access |
|---|---|---|
| X / Twitter | 18, 19, 29 | B — own posts via API, pricing is the obstacle. C for the archive |
| Reddit | 18–21 | B — API exists; own history via export |
| Instagram | 18, 19 | C — data download only. No feed API |
| TikTok | 18, 19 | C — data download only |
| YouTube | 18–21 | C — Takeout |
| LinkedIn feed | 18, 19 | **E** |
| Facebook / Threads | 18, 22 | C |
| Bluesky / Mastodon | 18, 29 | A — open APIs, small user base |
| Discord | 22, 24, 29 | B — own messages via export; bot API does not cover DMs |
| Snapchat | — | **E** |

**What this means for the product.** Socials are a *tier C import* story, not a
connector story — the user downloads an archive and hands it over, once. Which
makes them excellent for cold start and useless for ongoing ambient signal.

Screen Time is the better answer for *ongoing* social behaviour: it knows how long
someone spent in Instagram without Instagram's cooperation.

---

## 5. Notes and thinking

Where people write while working something out — the highest-quality words
available.

| Source | Questions | Access |
|---|---|---|
| **Notion** | 2, 6, 11, 21, 29 | **A** — good API, and the obvious first non-Google connector |
| Obsidian | same | C — local markdown files |
| Roam / Logseq | same | C |
| Evernote | same | B |
| Craft / Bear | same | C |
| Google Docs | — | covered under Google |

---

## 6. Meetings and transcripts

**Arguably the highest-value category after Google.** Spoken, unguarded words
about real situations with real people.

| Source | Questions | Access |
|---|---|---|
| **Granola** | 22, 24, 27–29, 31–33 | C initially — the founder already uses it and will supply exports |
| Otter | same | A |
| Fathom | same | B |
| Fireflies | same | A |
| Zoom / Meet recordings | same | B |
| Grain / Read.ai | same | B |

---

## 7. Communication

| Source | Questions | Access |
|---|---|---|
| Slack | 22, 24, 26, 29 | B — workspace-scoped, needs admin consent |
| Outlook / Microsoft 365 | 22, 25–29 | A — the non-Google half of the world |
| Superhuman | — | sits on Gmail; no separate value |
| Telegram | 22, 24, 29 | B |
| WhatsApp | 22, 24, 29 | **E** for personal accounts |
| Signal | — | **E**, by design |

---

## 8. Body and health

Richer than HealthKit alone, and the best available read on *how someone is* when
they have written nothing.

| Source | Questions | Access |
|---|---|---|
| **Whoop** | 15, 17, 30 | A — recovery and strain, a genuinely good proxy |
| **Oura** | 15, 17, 30 | A — sleep quality |
| Garmin | 13, 17 | B |
| Fitbit | 13, 17 | A |
| Strava | 12–14, 22 | A — and it has a social graph |
| Peloton | 13, 14 | B |
| MyFitnessPal / Cronometer | 13, 20 | B |
| Eight Sleep | 17, 30 | B |

---

## 9. Attention and reading

Deliberate attention — someone stopped and marked this. Much higher signal per row
than browsing.

| Source | Questions | Access |
|---|---|---|
| **Readwise** | 18, 19, 21 | **A** — clean API, and it carries Kindle highlights |
| Kindle | 18, 21 | via Readwise |
| **Shiori** | 18, 19, 21 | A — already in the founder's own stack, self-hosted, no third party |
| Raindrop / Matter | 18, 19 | A |
| Instapaper | 18, 19 | B |
| Pocket | — | shut down; confirm before considering |
| Goodreads | 18, 21 | C — API deprecated |
| Letterboxd | 18 | C |

---

## 10. Media and taste

| Source | Questions | Access |
|---|---|---|
| **Spotify** | 15, 18, 30 | **A** — easy, and uniquely gives time-of-day resolution |
| Apple Music | 15, 18 | B |
| Last.fm | 18 | A |
| Netflix | 18 | C |
| Steam | 18, 20 | A |
| Audible | 18, 21 | C |

---

## 11. Money — revealed preference

**The purest signal of what someone actually values, and the one needing its own
consent conversation rather than a button among five.**

| Source | Questions | Access |
|---|---|---|
| Plaid — banks | 7, 8, 20 | B — regulated, and a serious undertaking |
| Amazon order history | 18, 20 | C |
| Mercury / Ramp / Brex | 2, 7 | A — business rather than personal |
| Stripe | 2, 16 | A — for a founder, revenue is a goal-progress signal |
| Venmo / Splitwise | 22, 25 | B — who they actually do things with |

---

## 12. Place and movement

| Source | Questions | Access |
|---|---|---|
| Google location | 12, 15 | C — Takeout |
| Apple Significant Locations | 12, 15 | **E** |
| TripIt / Flighty | 12, 16 | B |
| Uber / Lyft | 12, 22 | C |

---

## 13. Build and ship — for the founder specifically

What someone planned against what they shipped, which is the stated-versus-real
gap in its cleanest form.

| Source | Questions | Access |
|---|---|---|
| **GitHub** | 2, 7, 13, 14, 16 | A |
| Linear | 7, 8, 13, 14 | A |
| Jira / Asana / Trello | 7, 13, 14 | A/B |
| Todoist / Things | 6, 9 | A / D |
| Vercel / Sentry | 16 | A |
| Figma | 2, 21 | A |

---

## The build order

Not a roadmap. An ordering **rule**, because the catalogue is a backlog:

> **Add the source that answers the most currently-unanswered questions.**

Once coverage is instrumented this stops being an argument. A source either moved
the number it promised to move, or it did not — and that is a measurement.

What that rule probably produces, as a prediction to check rather than a plan:

1. **Google** — all of it. Three kinds of question in one connector.
2. **Meeting transcripts** — the expensive thirteen, directly.
3. **Notion** — the best remaining words source, clean API.
4. **Readwise** — deliberate attention, cheap.
5. **GitHub** — built versus said, for a founder.
6. **Whoop or Oura** — how they are, without words.
7. **Spotify** — rhythm, and nearly free to add.

Then reassess, because several of these may turn out redundant. **If sent mail and
spoken transcripts already answer how someone talks, Slack adds volume rather than
knowledge** — and the coverage number will say so rather than leaving it to taste.

## Two standing rules

**Narrowest scope that answers the question.** Every source requests only the
fields mapped to a question we care about. This is the extraction-intent rule from
goal 1, and with Google it has a direct commercial payoff in reduced verification
burden.

**Read-only, all of them, for the entire plan.** Goal 17 is last, so no connector
needs write access to anything. That removes the largest security surface from
every PR before it.

## Data downloads (GDPR / data-protection exports), founder idea, 22 Oct

**The idea.** Most services must hand you a full export of your data on request, e.g. Google Takeout, Spotify ("download your data"), Instagram, Facebook, Netflix, Amazon, Apple, LinkedIn and Uber. Retro can use those exports as a deep, historical context source, often years of data that no live API exposes.

**How:**
- **Computer use does the tedious part.** With the person watching and approving, it opens the service's export page, requests the export and comes back when it's ready. The person signs in themselves; Retro never handles passwords.
- **Download and import.** It downloads the archive, and a per-service importer normalises it into the brain's raw content with its true dates and source.

**Privacy and honesty:**
- Every import is opt-in per service.
- The archive is deleted after import.
- Facts carry their source ("from your spotify export").
- Delete my data removes them.

**When:** after Beta 1, as its own connector family with one PR per service importer. It needs its own plan, with a contract, the brain-side normaliser and the consent screens.
