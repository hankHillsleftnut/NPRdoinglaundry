# Podcasts · every piece to PR level

The plan for the podcasts area (phase 3, contract 03, ship gate G3), to the journal's standard. Cards: [backend.md](./backend.md) (14 PRs), [platform.md](./platform.md) (16 PRs), [views.md](./views.md) (24 PRs). Contract: [../../contracts/03-podcasts.md](../../contracts/03-podcasts.md), fixtures in `../../contracts/fixtures/03/`. Board data: [tree.json](./tree.json).

**The weekly episode is the founder's top output.** So this plan spends its effort where the episode can go wrong: what it says must be exactly what the person hears and reads; every claim must show where it came from; a guess must never look like a fact; it must arrive on the person's Sunday, play anywhere, survive a plane, and never be lost when the old screens go.

## 1. Big picture

**For the person:** "every Sunday morning, Retro makes me a short episode about my week. I listen on a walk, read along if I want, skip to the part I care about, and when it says something about me I can see exactly what it's based on. If it asks me a question, I can answer it right there. If it got something wrong, I say so, and next week is better."

**Principles that shape every card:**
- **The claim ladder.** Facts, patterns, whys and guesses stay separate. The brain already writes episodes in two registers (`stated` and `asked`) and cuts any unsupported sentence (`writeEpisode` + the claim guard). The app must keep that line visible: stated claims are big inky text (`c:claim/stated`), asked claims are dashed cards (`c:claim/asked`), and the door refuses to return an "asked" claim that isn't a question.
- **Guesses asked, never asserted.** The one hypothesis in an episode arrives as a guess card at its moment in the transcript (C23e.3), answerable in a tap, and counts once across the journal and the episode.
- **When uncertain, withhold.** No chapter ticks unless the brain measured them (legacy and estimated episodes get none); no per-line times shown; no evidence invented when there's none ("nothing to show yet"); old episodes without sections show their words and nothing more.
- **No invented data.** Empty, quiet and making states say plainly what will come and when; no placeholder tiles.
- **One lit object per screen.** PC-1: the hero's play, removed while its own episode plays (the mini-player owns playback). PC-2 and PC-3: none (the transport never glows).
- **Privacy.** The push carries no title; excerpts and sentences are never logged; audio is private and signed; offline copies never leave the phone.

## 2. Flows

| Flow | Entry | Happy path | Failures and edges |
|---|---|---|---|
| **Find and listen** | the podcasts tab; the mini-player on any tab; a deep link; the push | PC-1 shows this week's hero → play → PC-2 opens playing → read along, scrub across chapters, skip, change speed → close to the mini-player → reopen | first load > 400 ms: skeleton; offline: cache marked "showing what's saved", downloaded episodes play, others say they'll play when back; a link expiring mid-pause: renewed silently; a phone call: pauses, resumes only on tap; headphones out: pause; no audio: the episode reads as words; legacy episode: words, no chapters; `not_found`: "that episode isn't here any more" and its copy is deleted |
| **Why this is here** | the why line under the title (ready state); long-press a line → "why this is here ›"; a link | PC-3: the claim (stated or asked) → what it rests on (your words, records) → where Retro says it (hear it) → not right | no evidence: "nothing to show yet"; records before YO-3 exists: no chevron; more than 20 sources: "and n more" pages; offline: cached claim or the offline line |
| **A guess arrives** | playback reaches the hypothesis chapter | the guess card appears in the transcript → that's right / not quite → kept, and the journal's guess shows answered | speaking dial off: no card; already answered in the journal: shown answered or not at all; offline: queued "saved on this phone" |
| **Correct a part** | "correct this part" pill; the line menu; PC-3's "not right" | UI1.2's correction flow, pushed inside the player sheet, with the claim as `about` when it has one | corrections blocked in production until BEA.1 (journal dependency) |
| **The weekly episode arrives** | Sunday morning, the person's zone | the job runs from 06:00 local → made → push at 09:00 local "this week's episode is here." → tap → PC-2 paused | quiet week: no push, a quiet row in PC-1 for 7 days; failure: one retry before 09:00, then nothing (logged); night: never; already one push today: held |
| **Tell Retro how it went** | the ended state | "more like this / less like this", "say more" in your words → sent once (outbox) | offline: waits and sends once; already given: shows it with "change" |
| **Keep it offline** | automatic on Wi-Fi for the newest; the "…" menu for others | downloads in the background, plays on a plane | link expires mid-download: resumes with a fresh link; under 500 MB free: no auto download; sign-out: all copies deleted |
| **Day one vs the hundredth** | — | day one: "your episodes appear here every sunday." (or the first episode's making row from first run); the hundredth: hero + paging squares, oldest at the end | 50+ items page by 20; "made on this phone" old episodes at the end |
| **Retiring the old** | the update that turns the podcasts switch on | old server episodes appear in the new tab; old on-phone episodes carried over; one Sunday notification | eleven `TranscriptViewModel` instances rewriting `podcasts.json`: two-launch checksum confirm; old app versions keep playing after the bucket goes private (BE3.8) |

## 3. The full tree

```
podcasts
├── flow · find and listen
│   ├── PC-1 podcasts ............................................................ P13.1 M · P13.2 S
│   │   ├── C17-t top bar, tab title (S)
│   │   ├── C27 episode tile ── C27.1 hero (M) · C27.2 square (S) · C27.3 upcoming row: making, quiet (S)
│   │   ├── C22 mini-player (journal, reused) · C18 tab bar (reused) · C39 states (reused)
│   │   └── M10 tiles lag the scroll (M)
│   ├── PC-2 the player .......................................................... P14.1 M · P14.2 M
│   │   ├── UI5.6 the player on every tab (M; needs the integrator's app-shell PR)
│   │   ├── C23e player, episode mode (on C23b) ── C23e.1 header, title, why line (M) · C23e.2 transcript by line (M) · C23e.3 a guess arriving (M)
│   │   ├── C24 transport (reused) ── C24-s speed (S)
│   │   ├── C25 scrubber (reused: one capsule per chapter)
│   │   ├── C20-p the "…" menu (S) ── UI5.1 chapter list (S)
│   │   ├── UI5.4 episode feedback (S; waits for a Paper drawing)
│   │   ├── M09 play morph, rolling time, chapter ticks (M)
│   │   └── M06 player → mini-player (L; first run owns it, PC-2 exposes its ids)
│   ├── playback (platform) ── PLP.1a live engine (L) · PLP.1b one audio owner (S) · PLP.2 lock screen (M) · PLP.3 positions (S)
│   ├── the library (server + platform) ── BE3.4a agent route (S) · BE3.4b door (M) · BE3.6 a brief by id (S) · PL3.4a live (M)
│   ├── one episode (server + platform) ── BE3.0a sections + chapter titles (M) · BE3.0b audio per chapter (M) · BE3.0c line times (S)
│   │                                       · BE3.5 door (M) · PL3.4b live + cache (M) · PL3.4c1 audio links (M) · PL3.4f guess in episode (S)
│   ├── offline (platform) ── PL3.4c2 offline copies (M)
│   ├── sample data ── UI5.0 SamplePodcastsData (M)
│   └── T05a podcasts flow test (M)
├── flow · why this is here
│   ├── PC-3 why this is here .................................................... P15 M
│   │   ├── UI5.3 the claim, stated or asked (S) ── SHARED: built here, reused by goals GL-2 and you YO-4
│   │   ├── UI5.2 "where retro says it" (S)
│   │   └── C32 evidence row (journal, reused) · UI1.2 not right (journal, reused)
│   └── claims and evidence ── BE3.1a agent route (M) · BE3.1b door (S) · PL3.4d live (S)
├── flow · the weekly episode arrives ── BE3.3a local-time schedule (M) · BE3.3b push (S) · PL3.4g links + tap (S)
├── flow · tell retro how it went ── BE3.2a the writer hears it (M) · BE3.2b door (S) · PL3.4e outbox (S) · (UI5.4 above)
└── flow · retiring the old ── X3.1 old episodes carried over (M) · X3.2a dead writers (S) · X3.2b old tab (M) · X3.2c old reminders (S) · BE3.8 old routes on private audio (S)
```

**Counts:** 5 flows · 3 pages · 13 new components or sub-components (C17-t, C27.1–3, C23e.1–3, C24-s, C20-p, UI5.1, UI5.2, UI5.3, UI5.4, UI5.6) · **54 PRs: 14 backend, 16 Platform, 24 views** (views include UI5.0, P13.1/2, P14.1/2, P15, M06, M09, M10, T05a). Reused, not redone: C17, C18, C19.1, C20, C22, C23b, C24, C25, C28, C32, C39, UI1.2, UI3.0, `RArtwork`.

## 4. The queue, in build order

Each needs only merged work. Cross-side needs are in bold.

| # | PR | Side | Size | Needs |
|---|---|---|---|---|
| 0 | **PLP.1a live player engine** | platform | L | PL0.3, Playback.swift, PL3.1b — **a Beta 1 gap: the journal's brief can't play live without it** |
| 0 | **PLP.1b one audio owner** | platform | S | PLP.1a — **Beta 1 (new journal + old podcasts tab in one build)** |
| 1 | BE3.0a sections and chapter titles | backend | M | BEA.8 |
| 2 | BE3.4a library route | backend | S | BEA.2 |
| 3 | BE3.4b `GET /v2/podcasts` | backend | M | BE3.4a, BE1.3, **BE2.5a** |
| 4 | BE3.5 `GET /v2/episodes/:id` | backend | M | BE3.0a, BEA.7 (BE3.0c for line times) — **also needed by first run's P06** |
| 5 | BE3.6 `GET /v2/briefs/:id` | backend | S | BE1.3, BE1.3b |
| 6 | BE3.0b audio per chapter | backend | M | BE3.0a, **BE1.3b helper**, BEA.4, BEA.7 |
| 7 | BE3.0c line times | backend | S | BE3.0b |
| 8 | BE3.1a claim route | backend | M | BEA.2, BE3.0a |
| 9 | BE3.1b claim door | backend | S | BE3.1a, BE3.5 |
| 10 | BE3.2a the writer hears feedback | backend | M | BEA.2, BEA.3 |
| 11 | BE3.2b feedback door | backend | S | BE3.2a |
| 12 | BE3.3a weekly in your own week | backend | M | **BE2.5a**, BEA.4, BEA.5, BEA.8 |
| 13 | BE3.3b episode-ready push | backend | S | BE3.3a, **BE2.6, BE2.7** |
| 14 | BE3.8 old routes on private audio | backend | S | BEA.7 (any time after; before the bucket goes private) |
| 15 | PLP.2 lock screen | platform | M | PLP.1a, #42 |
| 16 | PLP.3 positions (store v3) | platform | S | PLP.1a, PL2.1 |
| 17 | UI5.0 SamplePodcastsData | views | M | **Flows/Podcasts.swift + Playback additions (integrator)**, UI3.0, T02 |
| 18 | C17-t tab title | views | S | C17 |
| 19 | C27.1 hero | views | M | #42, UI5.0 |
| 20 | C27.2 square | views | S | C27.1 |
| 21 | C27.3 upcoming row | views | S | C27.1, **the quiet-row drawing** |
| 22 | P13.1 PC-1 | views | M | C17-t, C27.x, C39, C22 |
| 23 | P13.2 PC-1 edges | views | S | P13.1, UI0.1 |
| 24 | UI5.6 player on every tab | views | M | P10, **the integrator's app-shell PR** |
| 25 | C23e.1 header and title | views | M | C23b, UI5.0 |
| 26 | C23e.2 transcript by line | views | M | C23b, C20 |
| 27 | C24-s speed | views | S | C24 |
| 28 | P14.1 PC-2 | views | M | UI5.6, C23e.1, C23e.2, C24-s |
| 29 | C23e.3 a guess arriving | views | M | C28, C23e.2 |
| 30 | C20-p "…" menu | views | S | C20, C24 |
| 31 | UI5.1 chapter list | views | S | C20-p |
| 32 | UI5.3 the claim (shared) | views | S | C28, T01 |
| 33 | UI5.2 where retro says it | views | S | #42, #45 |
| 34 | UI5.4 feedback | views | S | **the feedback drawing (founder Q-2)** |
| 35 | P14.2 PC-2 more | views | M | P14.1, C20-p, UI5.1, C23e.3, UI1.2 |
| 36 | P15 PC-3 | views | M | P14.2, UI5.3, UI5.2, C32 |
| 37 | PL3.4a library live | platform | M | PL2.4, **BE3.4b, BE3.6** |
| 38 | PL3.4b one episode live | platform | M | PL3.4a, PLP.3, **BE3.5** |
| 39 | PL3.4c1 audio links | platform | M | PL3.4b, **BEA.7** |
| 40 | PL3.4c2 offline copies | platform | M | PL3.4c1 |
| 41 | PL3.4d claims live | platform | S | PL3.4b, **BE3.1b** |
| 42 | PL3.4e feedback outbox | platform | S | PL2.2, **BE3.2b** |
| 43 | PL3.4f guess in episode | platform | S | PL3.1c, PL3.4b |
| 44 | PL3.4g links + tap | platform | S | PL5.2, PL5.3 |
| 45 | X3.1 old episodes carried over | platform | M | PL2.6, PLP.3, PL3.4b |
| 46 | X3.2a dead writers | platform | S | the founder's go (can be any time) |
| 47 | M10, M09 | views | M + M | P13.1, P14.1 |
| 48 | T05a flow test | views | M | P13.2, P14.2, P15, PL3.4g |
| 49 | **the podcasts wiring PR (integrator)**, then layer 9 on staging, then G3 | — | — | everything above |
| 50 | X3.2b old tab, X3.2c old reminders | platform | M + S | G3, X3.1 confirmed; BE3.3b |

The backend (1–14) and the app (15–48) run at the same time; the app builds on sample data and fixtures until the doors land, as in the journal.

## 5. Offline downloads: what the app does today, and the decision

The current app has **no offline downloads**: server episodes play from their remote link; only an episode generated on the phone has its audio moved to `tmp/podcast_<id>.mp3`, which iOS may purge (`Transcriptviewmodel.swift:574-618`). There's a "download on wi-fi only" row in the `RSettingsRow` gallery, but only as sample copy. Paper's "…" menu draws "download" (`BFC-0`). So offline copies are new: built on lean A (Q-1), with the settings row as a contract 06 question if the founder wants control.

## 6. Live data and Beta 1 (podcasts is mostly after it)

Beta 1 keeps the old podcasts tab. Two things in this plan are needed **before** Beta 1 and have no other card: **PLP.1a** (the live player: the journal's brief audio can't play on real data without it; P10 and the journal wiring PR assume "plumbing's live playback") and **PLP.1b** (with the new journal and the old podcasts tab in one build, the two players must never talk over each other). BEA.7 (signed audio) is already in Beta 1; BE3.8 keeps the old tab playing once the bucket goes private.

## 7. Risks

| Risk | Answer |
|---|---|
| The transcript doesn't match the audio | BE3.0a stores exactly the kept sentences; a test proves they join back into the voiced script |
| Chapter joins are audible after per-chapter synthesis | BE3.0b checks continuity options and the founder approves an A/B; fallback is a timestamp endpoint (a new card) |
| A guess shown as a fact | two different components by register; the door refuses an asked claim that isn't a question; snapshot tests per register |
| The weekly episode lands at night or twice | per-zone schedule with a unique weekly job; push once per episode, never 21:00–08:00, one per day |
| Feedback that changes nothing | BE3.2a makes the v2 writer read it; UI5.4's copy waits until it's true |
| `podcasts.json` lost or doubled during the switch | two-launch checksum import; old file untouched until X06 and the founder's go; eleven writers removed in three steps |
| Old app silenced when audio goes private | BE3.8 signs links in the old routes first |
| Legacy (non-v2) episodes look broken | mapped to plain words, no chapters or claims; founder Q-16 turns v2 on for everyone at G3 |
| Paper and docs disagree | Paper wins (integrator rule, 21 Oct); every disagreement listed in §9 |
| Cost: per-chapter synthesis | the same characters as one call; measured on staging in BE3.0b |

## 8. Founder questions (work goes ahead on the lean)

| # | Question | Options | Lean | What changes |
|---|---|---|---|---|
| Q-1 | Offline copies | A: the newest weekly episode downloads itself on Wi-Fi, others by hand · B: by hand only · C: none, stream only | **A** | B: drop the auto rule in PL3.4c2. C: drop PL3.4c2 and the menu row; offline shows "it'll play when you're back" |
| Q-2 | Episode feedback (not drawn) | A: at the end, "more like this / less like this" + "say more" in your words · B: only "tell retro about this episode" in the "…" menu · C: none in v1 | **A** | B: UI5.4 becomes a menu row + composer. C: drop UI5.4, BE3.2b, PL3.4e (BE3.2a still useful for old feedback) |
| Q-2b | Should "less like this" lower how bold Retro is (appetite reads ratings ≤ 2 as discomfort)? | A: no rating until you decide · B: more = 5, less = 2 · C: more = 5, less = null | **A** | B feeds appetite; C feeds only the positive side |
| Q-3 | A quiet week | A: no push; a quiet row in podcasts with the next date · B: push the quiet line · C: nothing at all | **A** | B: BE3.3b sends on quiet. C: drop the quiet row (C27.3 making only) |
| Q-4 | When the weekly episode arrives | A: Sunday 9:00 your time (Paper's "ready sunday 9:00") · B: you choose in settings later | **A** | B adds a contract 06 field and a settings row |
| Q-5 | Past briefs in the podcasts tab | A: yes, as Paper draws ("today's brief", "monday's brief"), audio kept for the life of the account · B: episodes only | **A** | B: drop BE3.6, brief squares and the brief merge in BE3.4b |
| Q-6 | The "…" menu (part 09 still asks this on the approvals page) | A: chapters, download (as drawn) · B: + AirPlay · C: + sleep timer or share link | **A** | B/C add rows and drawings; AirPlay stays in Control Center under A |
| Q-7 | Reaching "why this is here" while playing (the why line scrolls away on play) | A: long-press a line → "why this is here ›" · "correct this part" · B: a small "why" pill beside "correct this part" · C: only by scrolling back up | **A** | B needs a drawing and a pill; C drops the line menu |
| Q-9 | Old episodes the old app made on the phone | A: carried over as "made on this phone" · B: left in the old file, not shown · C: ask each person | **A** | B: X3.1 imports server matches only |
| Q-11 | Listening position across devices | A: this phone only · B: synced | **A** | B adds a door and a table |
| Q-12 | PC-3's ⌄ close (Paper draws ‹ and ⌄) | A: keep both, as drawn · B: ‹ only; swipe down closes (later.md's lean) | **A** (Paper) | B removes one header button |
| Q-14 | Lock screen wording for episodes | A: title = the chapter; "this week's episode · chapter 2 of 5" · B: title = the episode | **A** (matches EX-2 for briefs) | B: PLP.2 shows the episode title |
| Q-16 | The new episode writer (v2) for everyone | A: at the podcasts ship gate (G3) · B: now · C: keep the allowlist | **A** | chapters and "why this is here" exist only for v2 episodes; under C most people get legacy episodes with neither |
| Q-17 | Copy | the quiet line, the empty line ("your episodes appear here every sunday."), "words only", the push line ("this week's episode is here."), feedback thanks | written with you | copy only |
| Q-18 | The line after the spoken one | A: `text.secondary`, as Paper draws (`1FWV-0`) · B: `text.tertiary`, as player.md says (21 Oct) | **A** (Paper wins per the integrator) | B changes one colour in C23e.2 and C23b |

## 9. Paper (read 21 Oct) versus the reference docs: Paper wins

| Where | Reference / docs said | Paper shows (used) |
|---|---|---|
| PC-1 section label | "made for you, sam · since 12 oct" (c-zy9zt2) | "earlier" (`1FUJ-0`); `since` dropped from the contract |
| Hero tile | line "<about> · 4 min", 2xl title | "this week · 12 min" on the artwork in white (`1FUV-0`), artwork 180, title `text.2xl`, the topics line "mornings, the standup, sleep" in SF `text.md` secondary; an extra ambient shadow |
| Square tiles | "your sister, the job · 4 min" | "tue 21 oct · 4 min" (date · length); briefs titled "today's brief", "monday's brief"; 171 wide, 155 artwork, `text.base` titles |
| Being-made row | a 40 skeleton well with the ring | a raised card, no well: "this week's episode" over a 6pt ring + "being made · ready sunday 9:00" (`FZ1-0`) |
| Player header | "your weekly episode" Geist 500 14 | Geist 12 `text.label` + a `today` tag in `accent.subtle` (`BD2-0`, `BD0-0`) |
| Player title (ready) | 34pt serif | `text.title`, ink-title weight, line 37 (`BCQ-0`) |
| Why line | mono line with a guess glyph | Geist 12 label with a 6pt `inference.marker` dot (`BCM-0`) |
| Transcript colours | player.md 21 Oct: every non-spoken line tertiary | past tertiary, spoken primary, **next secondary** (`1FWZ/1FWX/1FWV-0`); founder Q-18 |
| Transcript size | approvals note on part 09: 18 with body leading | `text.xl`, `leading.snug`, 20 between lines (`1FWU-0`) |
| Speed | "1×" | "1.0×", mono 15/18 (`1FVN-0`), also on the brief sheet |
| "…" menu | chapters ›, download (+ AirPlay per player.md) | chapters ›, download only, 220 wide, 44 rows (`BFC-0`) |
| Asked claim (PC-3) | dashed card with "that's right · not quite"; no sureness | dashed card with "a guess", the question in `text.2xl`, "asked · fairly sure · rests on 3 mornings", **no answer pills**; "not right" at the bottom for every claim (`1FZ6-0`, `1FXU-0`) |
| Stated claim | inky 3xl | `text.3xl`, ink-title weight, `tracking.title`, min height 142 (`G2A-0`) |
| Evidence rows | "tue 14 oct · journal" | "14 oct · your words", "17 oct · calendar"; rows grouped on `background.canvas` at `radius.panel` (`1FYD-0`) |
| Moment card | 40 thumb | 32 thumb at `radius.default`, quote in curly quotes `text.xl`, 32 "hear it" pill (`1FY2-0`) |
| PC-3 header | ⌄ may go | ‹ (32) and ⌄ (34) both drawn (`1FZA-0`); founder Q-12 |
| "rests on 3 mornings" | — | a noun the brain doesn't produce; the app writes "rests on 3 entries" / "4 things" (listed) |

Not drawn anywhere (built from the system's shared states, each listed for the founder): PC-1 loading, empty, error, offline and the quiet row; PC-2 offline, failed, no audio, ended + feedback; the "…" menu's download progress; PC-3 "and n more" and "nothing to show yet". The moment card has no master on 02 components.

## 10. What this plan needs changed elsewhere (shared files; the integrator's call)

- **first-ship.md / app-plumbing-engineer.md:** add PLP.1a and PLP.1b to Beta 1 (the journal's live brief playback has no card).
- **later-phases.md:** BE2.5b becomes the job doors only; the list and episode doors are BE3.4b and BE3.5 here, and **BE3.5 must land before first run's P06** (ON-11 plays an episode). BE3.0 is now BE3.0a–c.
- **phase-0.md migration list:** agent `158_episode_feedback_keys.sql` (BE3.2a), `159_weekly_delivery.sql` (BE3.3a); backend `013_push_sends.sql` (BE3.3b); app store migration **v3** (PLP.3).
- **`Platform/Flows/Podcasts.swift`** and the `Playback.swift` additions (platform.md §0): the integrator writes them.
- **The app shell:** one player sheet and mini-player above all tabs (UI5.6), a background-session bridge line in the AppDelegate (PL3.4c2).
- **ui/later.md:** C27, C23e, C20-p, UI5.1, UI5.2, P13–P15 are superseded by this folder; M06 belongs to first run (F40).
- **contracts/README.md:** 03 status → draft.
- **C23b (journal):** match Q-18's answer (next-line colour) and Paper's "1.0×" speed shown on briefs.
- **Paper (integrator, read-only for planners):** draw the quiet row, the feedback ask, the download states in the "…" menu; a master for the moment card.
