# The six area plans, checked against each other

The six area plans (first run #69, podcasts #65, goals #60, you #62, settings #68, outside #66) were written on 21 Oct in parallel. This file checks them against each other and against `main` (README, context, first-ship, contracts 00 and 02, ui-engineer, backend phase 0, plumbing). It was read from these branch heads:

| Plan | PR | Branch head |
|---|---|---|
| first run | #69 | `cc79dc9` |
| podcasts | #65 | `6549e72` |
| goals | #60 | `cccd635` |
| you | #62 | `c51c49f` |
| settings | #68 | `28fa53c` |
| outside | #66 | `f7047c0` (re-read after the custom-notification update: 89 PRs) |

**The ownership rule used throughout:** a shared thing has one home. That home is the first area in build order that needs it (journal, first run, podcasts, goals, you, settings, outside). When a later area needs it earlier than its plan schedules it, it's built earlier, under the card that already describes it.

The founder's questions are in [founder-questions.md](./founder-questions.md) (section 8 alone, in plain words).

**Bottom line:**
- **Notifications are the biggest gap.** Only outside follows the 21 Oct decision fully. Five plans define five different push payloads, three places store notification preferences, and two tables enforce "one push a day". The custom-writing pipeline also has to be built in phase 2 (first run sends the first push), not phase 7.
- **Component ids collide.** C41–C44 each mean two or three different things, and UI5.0 and UI6.0 are used twice.
- **The migration numbers clash.** Agent 158 is claimed three times, 159 twice, and backend 013 three times. Section 3 assigns one number to each.
- **Beta 1 has a real hole.** Nothing builds the live audio player the journal's brief needs (PLP.1a). The ticket moment also needs about 15 more PRs than first-ship lists.
- **Moments M01–M13 are planned twice.** The outside plan builds all thirteen, and each page's own area builds them too.

---

## 1. Shared components: one home each

"Claims" lists every plan that builds, extends or assumes the piece. "Owner" is the one plan that builds it; the others reuse it or add a named variant in its home.

| # | Component | Claims | Owner | What the others do |
|---|---|---|---|---|
| 1.1 | Top bar C17 (base, journal, entry and settings variants) | journal (main), settings, you, goals | **journal** | settings, you and goals reuse it |
| 1.2 | Top bar C17-o (onboarding) | first run | **first run** | none |
| 1.3 | Top bar C17-t (tab title, optional trailing slot) | podcasts builds it; goals (P16) and you (P18) assume it | **podcasts** | goals uses the trailing "+" slot; you's C17-y adds the pill and avatar as a variant in C17's file |
| 1.4 | Sheet host and dialog C19.1 / C19.2 | journal; settings (C50.1 dialogs, C43 time sheet); goals (UIG.1); you (P21.1) | **journal** | all reuse it |
| 1.5 | Menu C20 / C20-p (player "…") | journal; podcasts (C20-p); goals (UIG.3); settings (↕ values); outside (C41.2 "change") | **journal** (C20), **podcasts** (C20-p variant) | none |
| 1.6 | Toast C21 (`RToast` #48) | journal backlog; goals C21-i; first run ("you're already in."); outside ("that's not here any more.") | **journal** (#48) | goals' C21-i is only the host integration, not a second toast. The look is still a founder pick (ui-engineer §12) |
| 1.7 | Mini-player C22 / C22-p | journal; first run C22-p | **journal** (C22), **first run** (C22-p) | FR0.1 changes `size.miniPlayer` 42 → 64, which matches journal conflict #2 |
| 1.8 | Player sheet, brief mode C23b | journal; podcasts changes it (speed shown, next-line colour Q-18) | **journal** | podcasts' C24-s PR updates C23b in the same PR. The C24 card says speed is hidden for briefs; podcasts shows "1.0×" on briefs, so the card changes |
| 1.9 | Player sheet, episode mode C23e.1–3 | podcasts builds it; first run P06 (ON-11) needs it in **phase 2**; outside M06 assumes it | **first run's phase** (built from podcasts' cards; at least C23e.1 and C23e.2 for the tease) | podcasts adds C23e.3 (guess in transcript) in phase 3. First run's risk R4 already expects this |
| 1.10 | Transport C24, scrubber C25, speed C24-s | journal (C24, C25); podcasts (C24-s; chapter capsules on C25) | **journal**; **podcasts** owns C24-s and the chapter capsules | none |
| 1.11 | Live player engine (`Media.Player`, PLP.1a) | podcasts builds it; the journal's P10 and PL3.1b assume "plumbing's live playback"; outside calls it a gap (lean: PL3.1b) | **journal (Beta 1)**, built from podcasts' PLP.1a card | see §4 (missing) and §5 |
| 1.12 | Now Playing and remote commands (PLP.2 vs PL7.6) | podcasts PLP.2; outside PL7.6 | **podcasts** (PLP.2) | outside's PL7.6 is deleted; outside keeps only the `lockScreenDetail` choice (PL7.10) |
| 1.13 | Now Playing artwork 600×600 render | podcasts (PLP.2, `RArtwork` render); outside (C40.4 `NowPlayingArtwork.render`) | **podcasts** (in PLP.2) | outside's C40.4 reuses it for the widget |
| 1.14 | Brief card C26 (and its "first episode ready" variant) | journal; first run (UI4.1 on C26.2; ON-13 variant); outside (widget headline) | **journal** | the first-run variant lives in C26's file |
| 1.15 | Episode tile C27 | podcasts; outside (M10) | **podcasts** | none |
| 1.16 | Guess card C28 | journal; podcasts (C23e.3, in the transcript); you (dashed "asked"); goals (C29.3 copies its states) | **journal** | goals' grey C29.3 is a separate card for questions, not guesses (see 1.17) |
| 1.17 | **Claim card** (`c:claim/stated`, `c:claim/asked`) | podcasts UI5.3 says it's shared with GL-2 and YO-4; you agrees (UI6.2 withdrawn); goals builds GL-2's guess as `C29.3 .guess` on the same Paper instance (`1G45-0`, named `c:claim/asked · a pattern`) | **podcasts** (UI5.3) | goals drops `C29.3 .guess` and uses UI5.3 "asked" with its own answer pills. C29.3 keeps only `.isThisAGoal` and `.stillOnIt` |
| 1.18 | Goal card C29.1–C29.5 and moment M11 | goals; outside (M11) | **goals** | none |
| 1.19 | Message C30 and moment M08 | journal; outside (M08) | **journal** | none |
| 1.20 | Entry row C31 | journal; first run (UI4.2 uses its text styles) | **journal** | none |
| 1.21 | **Evidence row C32** and variants | journal (base); you C32-n (numbered, matched words); podcasts ("and n more"); goals (restyled "your words" grouped panel on GL-2) | **journal** (base, phase 0) | each variant lives in C32's file, added by the area that first draws it: C32-n by you (main's C32 card says so), "and n more" by podcasts, the grouped panel by goals. Goals must not fork the row |
| 1.22 | Benefit row C33, question C34.1–3, progress C35, knows-you meter C36, plan pair C37 | first run; outside (M03, M04, M07, M13 assume them) | **first run** | none |
| 1.23 | **You map C38** | first run builds C38.1 "orbits at rest" (splash, AC-1, paywall tile) in phase 2; you builds C38.1–C38.5 and M12 in phase 5; main put C38 in you | **first run** (C38.1: canvas, rings, orb, `labels: .hidden`) | you builds C38.2–C38.5 and M12 on top. You's C38.1 PR shrinks to the slot table and `labels: .shown`. Splash labels: first run reads Paper's illustrative labels; you says "never show node names before auth". The rule "no invented data" decides: **hidden** |
| 1.24 | Shared states C39 | journal; everyone | **journal** | none |
| 1.25 | Widget views C40.1–4 | outside | **outside** | none |
| 1.26 | Sign-in buttons C43 (renumbered below) | first run | **first run** | P01, P32 and PI1 reuse it |
| 1.27 | Mark S10 (38/22/16) | first run; outside (`RMark(.s16)` in widgets); settings (C50.2 goodbye) | **first run** | main listed "16, 22, glyph"; first run's sizes win (Paper) |
| 1.28 | Composer #54 and voice composer #56 | journal backlog; outside (compact variant); you (C12-y dictation); goals (UIG.1); first run (M02 halo) | **journal** (#54, #56) | outside's compact composer is a `.compact` variant in #54's file, not a new id |
| 1.29 | Search field #53 / C12-y | journal backlog; you | **journal** | you adds C12-y as a variant |
| 1.30 | Settings row #47 and its new parts | settings (page frame, action row, row states) | **settings** | none |
| 1.31 | **Time picker** | settings C43 (time sheet); first run ON-8 (quick answers 7/8/9/not now; a picker only on F7 = B) | **settings**, unless the founder picks F7 = B, in which case **first run** builds it in phase 2 and settings reuses it | none |
| 1.32 | "How straight" recommendation card | first run C44 (ON-9); settings ST-6 may reuse it; settings also builds C45 "picked by retro" note | **first run** | settings' P28 reuses first run's card where it's the same drawing; its C45 note stays only if Paper draws it differently |
| 1.33 | Invite keepsake (torn ticket) | first run C41.5 ("86% size kept for PI3"); settings PI3 / C49 | **first run** | PI3 reuses C41.5 |
| 1.34 | **Force-update page** | first run PX; outside X02b | **first run** (PX) | outside drops X02b |
| 1.35 | **Signature moments M01–M13** | outside builds all thirteen; first run builds M01, M02, M04, M05, M06.1/2, M07 (M03 inside C34.2, M13 inside C34.1); podcasts M09, M10; goals M11; you M12; journal M08 (main) | **the area that owns the host page** (main ui-engineer: "each its own PR after its page") | outside drops its 13 moment PRs (89 → 76) and keeps the lab cases and the filmstrip-drawing request |
| 1.36 | Notification categories and tap routing (PL5.3) | first run PL5.3 (episode_ready, brief_ready); outside PL5.3 ("now a full card here"); goals PL3.5d adds `goal.checkin`; podcasts PL3.4g | **first run's phase**, with outside's full card and contract 07's category list | goals and podcasts add only router destinations |
| 1.37 | Erase on sign-out | PL1.5 (Beta 1); podcasts adds its tables; settings PL3.7i `Platform.LocalReset`; outside revokes the notify token | **journal / Beta 1** (PL1.5) | settings' PL3.7i refactors PL1.5's erase into `LocalReset`; it doesn't add a second routine |
| 1.38 | Player presentation across tabs (UI5.6) | podcasts moves it out of the journal's P10 | **podcasts** | the integrator's app-shell PR comes first |

**Total: 38 shared pieces.** 18 have two or more claimants who disagree, or who would build the same thing twice: 1.3, 1.8, 1.9, 1.11, 1.12, 1.13, 1.17, 1.21, 1.23, 1.28, 1.31, 1.32, 1.33, 1.34, 1.35, 1.36, 1.37, 1.38.

---

## 2. Contracts

### 2a. Things defined differently in two contracts

| # | Topic | Where it differs | Resolution |
|---|---|---|---|
| 2.1 | **Connect a source** | 01 has `POST /v2/sources/:id/connect`. It returns `{authUrl}` for accounts; on-phone sources take `{granted:true}` and return `{source}`. 06 has the same path but returns `{mode:"browser", authorizationUrl}` or `{mode:"onPhone"}`, plus a separate `POST /v2/sources/:id/connected`. Main 01 said "the existing integration doors". | **One door, owned by 01 (BE2.10).** 06's shape (`mode`, plus a separate `connected`) is the better one; 01 adopts it. 06's BE6.5d shrinks to imports only |
| 2.2 | **The `Source` type** | 01: `state available\|connecting\|connected\|problem\|hidden`, `kind onDevice\|account`, `group onThisIphone\|yourOtherApps\|seeAll`. 06: `status connected\|syncing\|needsYou\|notConnected\|comingSoon`, `where onPhone\|account\|file`, plus `purpose`, `reads` and others. | **One type in 01.** 06 adds only its fields. Use 06's richer status vocabulary, with `group` kept for ON-6. `GET /v2/sources?for=onboarding` (01) and `?include=all` (06) become one query parameter |
| 2.3 | **Goal creation** | 01 (main and BE2.1) accepts an onboarding goal through `POST /v2/goals {title, description, fromOnboarding:true}`. 04 requires `clientGoalId` and `Idempotency-Key`, adds `quote`, and calls BE2.1's version a "stop-gap" that BE4.1b replaces. | **04's shape, defined once.** 01 drops its own goal door text. On first run's lean F16 (no goals in first run), nothing in phase 2 calls `POST /v2/goals`. See §4 for BE2.1's orphaned suggestions |
| 2.4 | **Episode jobs** | 01: `Job{kind:"first", step reading\|writing\|voicing\|ready\|quiet, stepIndex, failed{code, retryable}}`, plus `GET /v2/episodes/jobs/first`. 03 §7: `EpisodeJob{kind first\|weekly\|onDemand, state queued\|running\|made\|quietWeek\|nothingSafeToSay\|failed, stage reading\|writing\|voicing}`. Both say "shared". | **01 owns the jobs doors** (BE2.5b builds them). One shape. 03's `state` + `stage` split is more precise, so 01's `step` maps onto it: `step` = `stage` while running, `ready` = `made`, `quiet` = `quietWeek`. 03 references 01 and doesn't restate it |
| 2.5 | **`GET /v2/episodes/:id`** | 01: subset `{…, chapters[{title, startSeconds}], transcript[{text, startSeconds?}]}`. 03: full `Episode` with `lines[{index, text, chapterIndex, …}]`, `chapters[{index, title, startSeconds, claimId?}]`, `claims`, `madeFrom`. | **03's shape**, built as BE3.5 in **phase 2** (the podcasts plan already says it must land before P06). 01 drops `transcript` and reads `lines` |
| 2.6 | **Push payloads** (see 2b) | 01, 03, 04, 05, 06 and 07 each have their own | **07 §5.2 (v2) for every push** |
| 2.7 | **Deep links** | episode: `retrospect://episode/<id>` (01, 07) vs `retrospect://podcasts/episodes/<id>[?at=][/claims/<id>]` (03). goal: `retrospect://goal/<id>` (07) vs `retrospect://goals[/<id>]` (04). question: `retrospect://guess/<id>` → YO-4 (07) vs `retrospect://you/question/<id>` (05). settings: push `path` `/settings/<route>` (06) vs `retrospect://settings/privacy` (07) vs `retrospect://settings/brief` (07's widget, not in its own link table) | **One link table, in 07 §7, owned by PL5.2's router:** `retrospect://episode/<id>[?at=][/claims/<id>]`, `retrospect://goal/<id>`, `retrospect://goals`, `retrospect://you/question/<id>` (same-person) and `retrospect://guess/<id>` (guesses), `retrospect://settings/<page>`. 03, 04 and 05 cite it instead of defining links |
| 2.8 | **Notification preferences** | 06: `PATCH /v2/settings/notifications {brief, episode, questions, hideWordsOnLockScreen}`, default all on, backend migration `014_notification_settings` (BE6.7). 07: `GET/PUT /v2/notifications/preferences {briefReady, episodeReady, questions, checkIns, quietHours (read-only)}`, default all on (BE7.3). 04: `GET/PUT /v2/goals/checkins {enabled}`, **default off**, column `users.goal_checkins_enabled`. | **One store and one door: 07's `/v2/notifications/preferences` (BE7.3)**, built in phase 2 with the pipeline (§4). 06's settings read and write it (and `GET /v2/settings` embeds it); BE6.7 and `014` are deleted. 04's checkins door and column are deleted; `checkIns` lives in BE7.3, **default off** (04's lean; founder question N4). `hideWordsOnLockScreen` goes (see 6.1) |
| 2.9 | **Brief settings** | 02 has `PUT /v2/briefs/enabled`. 06 has `PATCH /v2/settings/brief {enabled, time, length}` (BE6.2a rewires 02's door onto the same service). 01's ON-8 writes `enabled` through 02 and holds the time in an outbox op `brief.time` "until contract 06 exists", which is phase 6. Main D7 says the time is picked in onboarding. | **Keep both doors** (02 for the journal's on/off; 06 the full one), on one service. **Pull BE6.1a (brief time column), BE6.2a (the door) and BE6.2b (per-person local-time scheduler) into phase 2**, so the time picked in onboarding reaches the server four phases earlier. BE7.5 needs BE6.2 anyway |
| 2.10 | **Devices and the notify token** | 01: `POST /v2/devices {token, environment, appVersion}`. 07: `notify_tokens` are "one per device" by `device_id` from BE0.4's sessions. | 01 adds `deviceId` (the session's device id) to `POST /v2/devices`, so the APNs token and the notify token join on one key |
| 2.11 | **Plan / entitlement** | 01: `Entitlement{active, productId, inTrial, expiresAt, willRenew, environment}`. 06: `GET /v2/account → plan{active, period, trial, renews, renewsOrEndsAt, billingIssue, store}`. | 06's `plan` is computed from BE2.8a's table, not a second store. Rename to match 01 (`inTrial`, `willRenew`, `expiresAt`) |
| 2.12 | **Invite states** | 00: `state used\|unused`, and `link` is null when revoked. 06 (C49) draws a "revoked" state; 06 (PI3) says "the founder adds invites by hand, no 'get more'". | Add `revoked` to 00's `state` enum, or drop it from C49. Founder invites are made in the admin tool (00 §4); member invites stay three, automatic |
| 2.13 | **`retryAfterSeconds`** | Every plan follows 00 (only on `rate_limited` and `spend_limited`). Only first run says what the app does with it (PI1 disables the field until it passes). The `spend_limited` fixtures disagree: 36000 (05, 07) and 43200 (01). Settings' export uses 72000. | **00 §2 gains one rule:** the app disables the refused action until `retryAfterSeconds` has passed and shows `message`. For `spend_limited`, the value is seconds until the person's local midnight. Fixtures keep illustrative values |
| 2.14 | **New error codes** | `gone` 410 (07, X07.0 tombstones); `apple_confirmation_required` 409 (06, delete account); `subscription_required` 402 (01, only if the founder picks a paid gate, F15). | Add `gone` and `apple_confirmation_required` to 00 §2. Add `subscription_required` only on the founder's yes |
| 2.15 | **New limit buckets** | 01 adds `public` (30/min per IP) and `inviteCheck` (20/10 min per user, 60 per IP). 06 adds per-door caps (sync 6/h, export 1/day). 07 adds 10/day per device for the notify token. | Name them in 00 §1 next to `read`/`write`/`expensive`; BE0.1b's limiter config holds the numbers |
| 2.16 | **Episode feedback** | 03's BE3.2a: "never fold into directives". Main BE3.2: folds into `user_preferences.directives` (needs BEA.3). | 03 wins. Main's later-phases BE3.2 is updated, and BE3.2a drops its BEA.3 need |
| 2.17 | **Answer verdicts** | Main BE5.3: `POST /v2/understanding/answers/:id {verdict}` with confirm or reject. 05: `POST /v2/you/claims/:kind/:id/verdict {stillTrue}`; rejecting goes through corrections (02 §6). | 05 wins; main's later-phases is updated |
| 2.18 | **Search doors** | Main BE5.4: `/v2/search/sources`, `/v2/search/answer`. 05: `POST /v2/you/search` (one expensive door), `GET /v2/you/sources/:kind/:id`. | 05 wins |

### 2b. The six push payloads

| Plan | What it sends | Against the decision |
|---|---|---|
| 01 first run | `aps.alert {title:"retrospect", body:"something's ready for you."}`, `mutable-content:1`, `kind:"episode_ready"`, `id`, `noteId`, `path` | fixed fallback text; snake-case kind; its own keys |
| 03 podcasts | `aps.alert.body "this week's episode is here."`, `category "episode.ready"`, `kind:"episodeReady"`, `episodeId`, `path`; no `mutable-content` | contradicts: fixed words, no extension |
| 04 goals | `aps.alert {title:"retrospect", body:"a question about one of your goals."}`, `category "goal.checkin"`, `route`, `questionId`; no `mutable-content`; a test asserts "the alert strings are the fixed ones" | contradicts |
| 05 you | "an id and the path"; copy "one question for you, when you have a minute."; no backend card sends it | contradicts (fixed copy); unowned |
| 06 settings | none of its own. It emits an `export.ready` event with `path`, stores `hideWordsOnLockScreen`, and Q17 leans on a "private mode" in the writer | partly contradicts (see 6.1) |
| 07 outside | v2: `aps.alert` = a **custom, non-sensitive fallback**, `mutable-content:1`, `category` (`BRIEF_READY`, `EPISODE_READY`, `QUESTION`, `CHECK_IN`, `EXPORT_READY`), `r {v:2, kind, id (notification), refId, link, sentAt}`. The extension fetches `GET /v2/notifications/:id/content` with a 7-day notify token | complies. Two trade-offs go to the founder (N2, N3) |

**Resolution:** 07 §5.2 is the only payload. Every push goes through BE7.4's `schedule()` and the BE7.8a writer:
- first run's BE2.7b becomes a `schedule({kind:"episodeReady"})` call;
- podcasts' BE3.3b becomes a `schedule()` call, and its `push_sends` table is dropped (BE7.4's `notification_log` enforces one a day);
- goals' BE4.3 becomes a `schedule({kind:"checkIn"})` call, with no window or switch of its own;
- you's question push is BE7.6's;
- settings' export event calls `schedule({kind:"exportReady"})`.

No plan uses `POST /notifications/generate`: goals dropped it, and outside retires it (BE7.8a, X08a). Check-in pushes now follow 07's quiet hours (21:00–08:00) instead of goals' 10:00–20:00 window.

### 2c. Changes the plans need in contracts 00 and 02

| Contract | Change | Asked by |
|---|---|---|
| 00 §2 | add `gone` (410) and `apple_confirmation_required` (409); `subscription_required` (402) only on the founder's yes | outside, settings, first run |
| 00 §2 | the `retryAfterSeconds` rule (2.13) | this check |
| 00 §1 | name the `public` and `inviteCheck` buckets | first run |
| 00 §3 | a second, narrower credential: the notify token (`POST /v2/notifications/token`, accepted only by the content door) | outside |
| 00 §4 | add `GET /public/invites/:code` (preview) and `POST /v2/invites/check`; make `POST /v2/invites/redeem` idempotent per redeemer and return `invite{serial, redeemedOn}`; add `POST /v2/onboarding/complete` (approved → member) | first run |
| 00 §4 | `revoked` invite state, or C49 drops it (2.12) | settings |
| 02 §3 | add `Brief.headline` (≤ 120, the first sentence of the first part) | outside (widget) |
| 02 §3 | `GET /v2/briefs/:id` (a past brief with audio) belongs here, not in 03 | podcasts (BE3.6) |
| 02 §3 | `date` is the local day, but BE1.3 writes the UTC date until BE6.2b. Pulling BE6.2b to phase 2 (2.9) shortens the gap; for Beta 1, 02 says so plainly | settings |
| 02 §5 | `Entry.kind` += `"shared"` (links saved from the share sheet) | outside |
| 02 §6 | `about.kind` accepts `"pattern"` (YO-4's "not right" on a pattern) | you |
| 02 §4 | none. Goals' grey card says "yes" / "not quite" to its own questions, never to C28's guesses (1.17) | goals |

**Count for section 2:** 18 cross-contract differences (2a), 6 payload shapes reconciled (2b), 12 changes to 00 and 02 (2c).

---

## 3. Migration numbers

**What's real (checked 21 Oct):**
- **Agent repo** (`retrospect-agent`, `supabase/migrations/`): `origin/main` ends at **151** (`151_action_ledger.sql`). No branch has 152 or higher.
- **Backend** (NPRdoinglaundry `supabase/migrations/`, at the repo root, not `backend/`): `origin/main` has **001–004** (`004_podcast_episodes_and_voice_persona.sql`).
- **Stale open PRs carry clashing backend files:**
  - #13 `accounts/core` has `004_auth_identities`, `005_account_type_and_flags` and `006_session_epoch`;
  - #6 `feat/durable-note-capture` has `006_content_idempotency`;
  - the branch `cursor/x-bookmarks-integration-7d06` has `004_add_x_twitter_data_source`.

  None of them may merge with those numbers. Settings already asks to close #13 and #14, which also build "sign out everywhere" (v2).
- **Already assigned on main** (backend/phase-0.md):
  - backend: 005 BE0.4 · 006 BE0.5 · 007 BE0.12 · 008 BE0.9 · 009 BE0.11 · 010 BE2.8 · 011 BE2.6 · 012 BE2.4
  - agent: 152 BEA.1 · 153 BEA.4 · 154 BEA.7 · 155 BE1.3b · 156 BE2.5a · 157 BE3.0

**What the plans propose, and the clashes:**

| Repo | Number | Claimed by |
|---|---|---|
| agent | 156 | first run BE2.5a1 (main's BE2.5a, same thing) |
| agent | 157 | podcasts BE3.0a (main's BE3.0; scope grows: sections, timing_version) |
| agent | **158** | first run BE2.2a `onboarding_answer_type` (conditional) · podcasts BE3.2a `episode_feedback_keys` · settings BE6.1a `user_settings` |
| agent | **159** | podcasts BE3.3a `weekly_delivery` · settings BE6.1d `ambient_dial` |
| agent | 160 | settings BE6.3a `data_exports` |
| agent | `<n>` ×4 | goals BE4.0a `goal_progress`, BE4.1b (goals columns + a backfill), BE4.0c `goal_link_verdicts`, BE4.0d `goal_questions` |
| agent | `16a/16b/16c` | you BE5.3a, BE5.3b, BE5.4a |
| agent | `1NN` ×2 (+1 unnamed) | outside BE7.2a, X08b, X08c |
| backend | **013** | first run BE2.0b `invite_serial` · podcasts BE3.3b `push_sends` · settings BE6.6b/BE0.7 `deletions` |
| backend | 014 | settings BE6.7 `notification_settings` |
| backend | `0NN` ×3 (+1 unnamed) | outside BE7.3 `notification_preferences`, BE7.4 `notification_log`, BE7.9b `notify_tokens`; X07h (null `podcast_episodes.audio_url`) |
| backend | (column) | goals BE4.3 `users.goal_checkins_enabled` |

**Assigned (clash-free, in build order).** These include the moves this check recommends: the notification pipeline and brief time go to phase 2 (§2, §4), and three tables are dropped as duplicates.

| Repo | Number | File | Byte | Phase |
|---|---|---|---|---|
| backend | ~~013~~ **021** | `021_invite_serial.sql` (013 was assigned here, but 019 and 020 were taken first; built as 021, 22 Oct) | BE2.0b | Beta 1 |
| backend | 014 | `014_notification_preferences.sql` (with `check_ins` default false) | BE7.3 (built in phase 2) | 2 |
| backend | 015 | `015_notification_log.sql` | BE7.4 (built in phase 2) | 2 |
| backend | 016 | `016_notify_tokens.sql` | BE7.9b (built in phase 2) | 2 |
| backend | 017 | `017_deletions.sql` | BE0.7 / BE6.6b (the App Store lane) | 2 (after payments) |
| backend | 018 | `018_null_legacy_audio_urls.sql` | X07h | 8 |
| backend | — | dropped: podcasts `push_sends` (→ 015), settings `notification_settings` (→ 014), goals `users.goal_checkins_enabled` (→ 014) | | |
| agent | 158 | `158_onboarding_answer_type.sql` (only if `content_type` has a check constraint; otherwise the number stays unused) | BE2.2a | 2 |
| agent | 159 | `159_user_settings.sql` (brief time, length, playback speed) | BE6.1a (pulled to phase 2) | 2 |
| agent | 157 | `157_episode_chapters.sql`, with podcasts' larger scope | BE3.0a | 3 |
| agent | 160 | `160_episode_feedback_keys.sql` | BE3.2a | 3 |
| agent | 161 | `161_weekly_delivery.sql` | BE3.3a | 3 |
| agent | 162 | `162_goal_progress.sql` | BE4.0a | 4 |
| agent | 163 | `163_goal_link_verdicts.sql` | BE4.0c | 4 |
| agent | 164 | `164_goal_questions.sql` (+ the `goal_questions` dial row, speak off) | BE4.0d | 4 |
| agent | 165 | `165_goal_origin.sql` (origin, first_quote, client_goal_id, unique key) | BE4.1b | 4 |
| agent | 166 | `166_goal_quit_backfill.sql` | BE4.1b | 4 |
| agent | 167 | `167_question_you_text.sql` | BE5.3a | 5 |
| agent | 168 | `168_confirm_fact.sql` | BE5.3b | 5 |
| agent | 169 | `169_search_person_content_date.sql` | BE5.4a | 5 |
| agent | 170 | `170_ambient_dial.sql` | BE6.1d | 6 |
| agent | 171 | `171_data_exports.sql` | BE6.3a | 6 |
| agent | 172 | `172_reference_goal_source.sql` | BE7.2a | 7 |
| agent | 173 | `173_retire_legacy_tables.sql` | X08b | 8 |
| agent | 174 | `174_drop_retired_tables.sql` | X08c | 8 |

157 keeps its number although it's built after 158 and 159: numbers on main are reserved, and nothing has been applied. The BE2.9a–d (Notion) migrations, if D9 says build, take the next agent number at that time.

**The phone's GRDB store** (same problem, smaller): main has v1 = PL2.1 and v2 = PL2.6. Assigned:
- v3 = PLP.3 (playback positions, episode cache, downloads);
- v4 = X3.1 (`legacy_episodes`);
- v5 = PL3.6b (`you_map_seen`);
- v6 = PL7.4 (`inbox_imports`).

**Count for section 3:** 28 proposed migrations (21 agent, 7 backend, plus 1 backend column). There are 3 numbering clashes (agent 158, agent 159, backend 013), plus 3 conflicting open PRs. 25 numbers were assigned; 3 tables were dropped as duplicates.

---

## 4. Duplicate or missing PRs

### 4a. The same work in two plans

| # | Work | Plans | Keep | Drop |
|---|---|---|---|---|
| 4.1 | Signature moments M01–M13 | outside (all 13) and each page's area | each page's area (1.35) | outside's 13 moment PRs |
| 4.2 | Force-update page | first run PX, outside X02b | PX | X02b |
| 4.3 | Now Playing and remote commands | podcasts PLP.2, outside PL7.6 | PLP.2 | PL7.6 |
| 4.4 | Notification categories and tap routing | first run PL5.3, outside PL5.3 (full card), goals PL3.5d (category part), podcasts PL3.4g (category part) | one PL5.3 in phase 2, from outside's card | the category halves of PL3.5d and PL3.4g |
| 4.5 | One push a day, quiet hours | outside BE7.4, podcasts BE3.3b (`push_sends`), goals BE4.3 (its own 7-day rule and window) | BE7.4 | `push_sends`; BE4.3's window |
| 4.6 | Notification preferences | outside BE7.3, settings BE6.7, goals BE4.3 (checkins door) | BE7.3 | BE6.7; the checkins door |
| 4.7 | The "one question" push | you (EX-3, copy only), outside BE7.6 | BE7.6 | none |
| 4.8 | Sources list and connect doors | first run BE2.10, settings BE6.5b/BE6.5d | BE2.10 (one `Source` type); settings keeps sync, disconnect, delete-data and imports | settings' connect half of BE6.5d |
| 4.9 | `GET /v2/episodes/:id` | first run BE2.5b, podcasts BE3.5 | BE3.5, in phase 2 | the door half of BE2.5b |
| 4.10 | GL-2's guess card | goals `C29.3 .guess`, podcasts UI5.3 | UI5.3 | `C29.3 .guess` |
| 4.11 | You map canvas C38.1 | first run, you | first run's C38.1 | you's C38.1 canvas (keep the slot table) |
| 4.12 | Now Playing art render | podcasts (PLP.2), outside C40.4 | PLP.2's render | C40.4 becomes a call to it |
| 4.13 | Deleting the old podcasts tab | podcasts X3.2b, outside X10c ("old screens after G3") | X10c | X3.2b |
| 4.14 | Importing `podcasts.json` / old local data | podcasts X3.1, outside X06a–f, main PL2.6 | podcasts X3.1 for episodes (it has the "made on this phone" variant); X06a–f for everything else | none, but X06's list drops `podcasts.json` |
| 4.15 | Live player engine | podcasts PLP.1a, outside ("gap, lean PL3.1b"), journal P10 (assumes it) | PLP.1a, in Beta 1 | none |
| 4.16 | Local erase on sign-out | PL1.5, settings PL3.7i | PL1.5, refactored by PL3.7i | none |

### 4b. Assumed by a plan, built by nobody

| # | Missing | Assumed by | Fix |
|---|---|---|---|
| 4.17 | **A live audio player for the journal's brief** | P10 (Beta 1), PL3.1b, the wiring PR | PLP.1a (and PLP.1b in its smallest form) joins Beta 1 (§5) |
| 4.18 | **The custom-writing pipeline in time for the first push** | first run BE2.7b ("the outside plan's note writer", phase 2); podcasts BE3.3b (phase 3); goals BE4.3 (phase 4). Outside schedules BE7.8a/b, BE7.9a/b, BE7.4, BE7.3, PL7.11, PL7.12 and INT7.3 in phase 7 | build those nine in **phase 2**, under their outside ids |
| 4.19 | Brief time on the server before phase 6 | first run ON-8 (holds it in the outbox until "contract 06"); outside BE7.5 needs BE6.2 | BE6.1a, BE6.2a and BE6.2b in phase 2 (2.9) |
| 4.20 | Who consumes `POST /v2/onboarding/goals` (BE2.1) | first run says BE2.1 "only feeds contract 04's question cards" (lean F16); goals' questions come from `stated_goal` facts (BE4.0d) and never read BE2.1's output | **drop BE2.1** on F16 = A, saving a spend-capped model call per new member. On F16 = B, keep it, and goals' BE4.0d reads its suggestions |
| 4.21 | A check-ins switch on the settings screen | goals (contract 06 must show it); outside (`checkIns` in prefs) | settings' P23a draws and builds four switches: brief, episode, questions, check-ins |
| 4.22 | Corrections accepting `pattern` | you (YO-4 "not right" on a pattern) | BE1.7 (journal, after Beta 1) takes it; note it on BE1.7's card |
| 4.23 | `Brief.headline` and `Entry.kind "shared"` in the doors | outside | BE7.2b covers `shared`; `headline` goes into BE1.3's mapper as a small follow-up byte (BE1.3c) |
| 4.24 | Router destinations `.compose`, `.goal(id:)`, `.settings(page)`, `.youQuestion(id)` | outside, goals, settings, you | each lands with its area's PL deep-link byte (PL7.x, PL3.5d, PL5.2s, PL3.6f); PL5.2 just accepts them |
| 4.25 | `deviceId` on `POST /v2/devices` | outside's notify token | BE2.6 (2.10) |
| 4.26 | `Media.LevelMeter` | outside (M02, recording) | part of #56; if #56 lacks it, an S byte under PL3.1 |
| 4.27 | `GOAL_PROGRESS_REUSE` changes podcast generation | goals' BE4.0a edits `podcast-v2.ts` | the podcasts plan must know; BE4.0a's PR is reviewed against BE3.0 |

### 4c. Ids used twice

| # | Id | Meanings | Renumbered |
|---|---|---|---|
| 4.28 | **C41** | first run: invite ticket (C41.1–5); settings: page frame; outside: share item card (C41.1–2) | first run keeps C41–C44. Settings becomes C45–C54: C41→C45, C42.1/2→C46.1/2, C43→C47, C44→C48, C45→C49, C46→C50, C47→C51, C48→C52, C49→C53, C50.1/2→C54.1/2. Outside's C41→C55 (C55.1/2) |
| 4.29 | **C42** | first run: printer slot; settings: row parts; outside: compact composer | outside's C42 → a `.compact` variant of #54, no new id (1.28) |
| 4.30 | **C43** | first run: sign-in buttons; settings: time sheet | as 4.28 |
| 4.31 | **C44** | first run: recommendation card; settings: voice sample pill | as 4.28 |
| 4.32 | **UI5.0** | podcasts: SamplePodcastsData; you: SampleYouData | main gives UI5.x to podcasts and UI6.x to you, so you's UI5.0 → **UI6.0** |
| 4.33 | **UI6.0** | settings: SampleSettingsData (and you, after 4.32) | settings → **UIS.0** (like goals' UIG.x) |
| 4.34 | **M14** | the design milestone (`docs/design/m14-*`, PR titles "M14 C04") and the "you're in" moment | the moment is built as **PI2.1–PI2.4**; no PR title uses "M14" alone. The milestone is "milestone 14" in new docs |
| 4.35 | **M07** | main and first run: "the plan glow slides"; outside: "save tag rolls in, no glide" | first run's meaning (1.35); outside's version is a variant only if F10b = B |
| 4.36 | **X3.x vs X03a–d** | podcasts' X3.1/X3.2a–c (import, delete writers, tab, reminders); outside's X03a–d (remove experiments) | podcasts' become **XP.1, XP.2a, XP.2c** (XP.2b is dropped, 4.13) |
| 4.37 | **PL5.3** | first run (a phase 2 card) and outside ("a full card here") | one card (4.4) |
| 4.38 | **BE2.1** | main: all onboarding doors; first run: the goals-suggestions door only | first run's meaning, or dropped (4.20) |
| 4.39 | **BE3.1 / BE3.2 / BE3.3** | main: evidence door, feedback into directives, weekly push; podcasts: claim door, feedback read directly, schedule + push | podcasts' meanings; `later-phases.md` is rewritten in the same PR as the plan |
| 4.40 | **BE4.1 / BE4.2 / BE4.3** | main: all goal doors incl. DELETE, `/evidence`, `/notifications/generate`; goals: split, no DELETE, no `/evidence`, BE7.4 | goals' meanings; same rewrite |
| 4.41 | **BE5.1–BE5.4** | main: `/v2/people`, `/v2/portrait`, `/v2/understanding`, `/v2/search/*`; you: everything under `/v2/you` | you's meanings; same rewrite |
| 4.42 | **BE6.4** | main: manage subscription; settings: `GET /v2/account` | settings' meaning |
| 4.43 | **"Phase 7"** | README: outside; `later-phases.md`: retire the old | retirement is **phase 8** everywhere (outside already uses it) |
| 4.44 | **P35** | main: lock screen, Live Activity and Now Playing; outside: Now Playing only (Q2) | outside's scope; main's title updated |

**Count for section 4:** 16 duplicates, 11 missing pieces, 17 id problems.

---

## 5. PRs the plans want in Beta 1

**The test (first-ship.md):** it's in if the journal needs it to work, if people's data must be safe, or if money mustn't leak. On top of that, the founder's priority on the invite moment (M14, "you've just been given a gift"). first-ship already lists **PL1.7, PI1 and M14**, so the ticket's parts are a breakdown of PI1 and M14, not new scope.

| PR | Asked by | Blocks Beta 1? | Why |
|---|---|---|---|
| **PLP.1a** live player engine | podcasts | **Yes** | The journal's brief is audio (decided) and P10 plays it. No other card builds a player, so without it JR-2 can't play |
| **PLP.1b** old engines become adapters | podcasts | **Yes, smallest form** | The old podcasts tab ships next to the new journal. If both can play, two audio sessions fight. Beta 1 needs "only one plays"; the full adapter refactor can wait for phase 3 |
| **PL1.7d** check after sign-in, redeem at the tear | first run | **Yes** | It replaces PL1.7b's auto-redeem (already in Beta 1). The drawn moment spends the invite at the tear, so redeeming at sign-in would make the tear theatre. Founder priority |
| **BE2.0b** check door, serial, idempotent redeem (+ `013_invite_serial`) | first run | **Yes** | PL1.7d needs it. An idempotent redeem also stops a retried tear from showing "already used" to the person who just used it |
| **BE2.0a** public preview before sign-in | first run | **No** (unless the founder says I1 = A and wants the name before sign-in) | The round 2 board signs in first, and the check door returns the ticket's face after sign-in. The preview only adds the inviter's name to the gate. Neither data safety nor money |
| **FR0.1** tokens, Core Haptics rumble, shaped depth, mesh recipes | first run | **Yes** | The ticket can't be built from tokens without its sizes and depth (tokens-only lint). The rumble is part of the moment the founder prioritised |
| **FR0.2** `Invite.swift` protocol | first run | **Yes** | The seam PI1 and PI2 are built against (like `Journal.swift`) |
| **UI4.0** SampleInviteData | first run | **Yes** | Every view byte proves its states on it |
| **C43** sign-in buttons (Apple only in Beta 1) | first run | **Yes** | The gate needs a sign-in button. Google waits (decided) |
| **C41.1–C41.5** ticket, **C42** printer slot | first run | **Yes** | The parts of M14 |
| **PI2.1–PI2.4** the print, the tear, separation, Reduce Motion | first run | **Yes** | M14 itself, split four ways (it was one L card) |
| **PL1.8** invite gate in the app root | first run | **Yes** | Without it, a waitlisted person could reach the old screens, and every `/v2` door refuses them anyway. Data safety |
| **T03a** invite flow test (sample + staging) | first run | **Staging half only** | first-ship keeps only T04 at layer 8. The staging redeem run folds into the layer 9 end-to-end run before TestFlight |
| **PL7.6** Now Playing (outside Q8) | outside | **No** | The brief plays in the app without it. AirPods pause and lock-screen controls are polish. It also drags in PL7.10 and C40.4, and PL2.4 is deferred |
| **BE3.8** old routes return signed links | podcasts | **No, if the bucket stays public through Beta 1** | BEA.7 already says to flip the bucket only after the old app no longer needs public links. If the founder flips it during Beta 1, BE3.8 becomes a yes |
| **C38.1** map (if the splash were in Beta 1) | you | **No** | The new splash and onboarding wait for phase 2 (first-ship) |
| **App Store minimum lane** (settings Q11) | settings | **No** | It's needed before submission, not for an internal TestFlight |
| **BE6.1a / BE6.2a / BE6.2b** brief time and local scheduler | (this check, 2.9) | **No** | The Beta 1 brief runs on BE1.3's existing schedule. The UTC-date gap is written into contract 02 |

**Net change to first-ship:** about 17 PRs join Beta 1:
- BE2.0b, FR0.1, FR0.2, UI4.0 and C43;
- C41.1–5 and C42 (6);
- PI2's extra 3;
- PL1.7d and PL1.8;
- PLP.1a and PLP.1b.

That takes it from about 85 PRs to about 102. Only PLP.1a and PLP.1b come from the "journal must work" test. The other 15 are the invite moment's real size, and the founder's priority puts them in.

---

## 6. Decision drift

| # | Decision | Where it drifts | Resolution |
|---|---|---|---|
| 6.1 | **Notifications: custom-written, ids + `mutable-content`, an extension fetches the words, a "hide the words on the lock screen" switch in settings** | first run: a fixed fallback ("something's ready for you."), contradicting its own "no fixed string". podcasts: a fixed alert, no extension. goals: a fixed alert and fixed question copy, tested as fixed. you: fixed copy. settings: a server-side `hideWordsOnLockScreen` switch and a "private mode" in the writer (Q17). outside (updated): complies, but its lock-screen control is a settings **row that opens iOS's Show Previews**, not a switch of ours | All five follow 07 §5 (2b). Settings drops `hideWordsOnLockScreen` and Q17 and builds outside's row. Whether a row to iOS meets "a switch" is founder question N1 |
| 6.2 | the same, but the fallback rides through Apple | outside's own record: "only the non-sensitive fallback passes through Apple" | founder question N2 (the founder's call, written down) |
| 6.3 | the same, but the extension's token lasts 7 days | outside: the founder said "a short-lived token"; a 15-minute token would rarely work | founder question N3 |
| 6.4 | Brief words on the lock screen (related) | outside: Now Playing shows no brief words unless `lockScreenDetail` is on (off by default). podcasts PLP.2: chapter titles as the Now Playing title (Q-14 lean) | outside's rule wins for briefs and episodes alike. PLP.2 reads `lockScreenDetail` (founder question P5) |
| 6.5 | **Prices** $19.99 / $199.99, first month free on yearly | everyone takes prices from StoreKit. first run writes "works out to **$16.66** a month" (199.99 / 12 = 16.67); outside never mentions the free month; Paper is stale (§7) | "$16.67", or better, computed from StoreKit at run time. Product ids `retro.monthly` / `retro.yearly` are unverified, so the founder confirms them in App Store Connect |
| 6.6 | **Invites** only through links, three per member, `retrospect-api.onrender.com/i/<code>` | first run keeps a typed-code fallback: **allowed** (README §9: "typing it is a fallback"). settings PI3: "the founder adds invites by hand, no 'get more'"; C49 draws "revoked" | PI3's text says the three are automatic. "revoked" per 2.12 |
| 6.7 | **Sign out everywhere is v2** | no plan builds it. Open PRs #13 and #14 do | close #13 and #14 (settings already asks). They also carry clashing migrations (§3) |
| 6.8 | **Journal v1 canned acknowledgements** | none. Settings hides "talk or read", first run drops the "talks back" benefit, outside's M08 is the v1 lift | complies |
| 6.9 | **Briefs are audio, off until opt-in** | outside's notification preferences default every kind **on** (the brief push still needs the brief to be on). goals' check-ins default **off**. outside keeps a "ready to read" path for briefs without audio | prefs: brief, episode and questions on; check-ins off (founder question N4). The no-audio path stays as a fallback for a failed voice step, not a product mode |
| 6.10 | **Chapters loose** | podcasts complies (one per topic). Internal: chapters are `[]` vs omitted for legacy episodes (contract vs BE3.5) | contract wins: `chapters: []` |
| 6.11 | **Apple and Google, Google after Beta 1** | first run: Apple only in Beta 1 (I8 lean A, already decided). settings' BE6.4 needs BE2.4 (Google) and sits in the App Store lane, which is after Beta 1 | complies; first run's I8 is removed from the questions |
| 6.12 | **Workaround comments banned** | no `TODO`/`FIXME` anywhere. Settings puts "copy to confirm" markers in code (catalogue copy, B:461). Goals' UIG.1 ships "+" hidden behind a flag if the drawing is late. Goals' PL3.5c adds a one-line guard to `GoalsManager.swift` | "copy to confirm" lives in the PR body and the copy table, never in code. The flag and the guard are fine as code; each gets a findings-log id |
| 6.13 | Quiet hours | outside: 21:00–08:00. podcasts: never 21:00–08:00. goals: only 10:00–20:00 | one rule, 07's (founder question N5) |
| 6.14 | Guess vocabulary | journal C28: "that's right" / "not quite". goals: "yes" / "not quite" for everything incl. GL-2's guess. podcasts and you: C28's | GL-2's guess uses the claim card with C28's words (1.17); "yes" / "not quite" stays for goals' own questions |
| 6.15 | Splash map labels before sign-in | first run (Paper draws illustrative labels) vs you ("never show node names before auth") | the rule "no invented data" → hidden |
| 6.16 | Haptic tick rate | first run: every 40 ms (the founder's board) vs motion-system's 80 ms floor | the founder's board is newer and the founder's own, so 40 ms. motion-system gets a noted exception |

**Count for section 6:** 16 rows. 5 contradict a founder decision outright (6.1 in four plans, 6.7 in open PRs).

---

## 7. Paper: to draw, and texts to fix

### 7a. Not drawn yet (deduplicated)

| # | What | For | Area |
|---|---|---|---|
| 7.1 | PI1's waitlist sheet, joined state, used / expired refusals, suspended page; C41.4's refused stubs | Beta 1 (or approved from snapshots, I3) | first run |
| 7.2 | A dark board for the invite | Beta 1 (or approved from dark snapshots) | first run |
| 7.3 | Force-update page (one drawing, for PX) | G1 | first run (outside had it too) |
| 7.4 | ON-8 brief time (quick answers, or a picker on F7 = B) | phase 2 | first run |
| 7.5 | C44 recommendation card (optional); split lock glyph for UI4.5 (asset) | phase 2 | first run |
| 7.6 | Filmstrips for M02–M13 (M01 has only a keyframe page); M01 waits for the opening pick (F5) | each moment's PR | all areas |
| 7.7 | PC-1: loading, empty, error, offline, the quiet-week row (C27.3) | phase 3 | podcasts |
| 7.8 | PC-2: offline, failed, no audio, ended + feedback ask (UI5.4) | phase 3 | podcasts |
| 7.9 | The "…" menu's download states (queued, %, downloaded / remove, failed) | phase 3 | podcasts |
| 7.10 | PC-3: "and n more" (a C32 variant), "nothing to show yet"; a master for the moment card (UI5.2) | phase 3 | podcasts |
| 7.11 | AX3 one-column squares on PC-1 | phase 3 | podcasts |
| 7.12 | GL-3 ended list; GL-4 add sheet | phase 4 | goals |
| 7.13 | `c:icon/guess` master; a "play" glyph for watched rows (asset); the question card's "where from" tap | phase 4 | goals |
| 7.14 | Portrait list view (UI6.7); YO-3 record and saved-link variants; search "nothing found" phone; YO-5 "moved this week" filtered state | phase 5 | you |
| 7.15 | More map slots (up to 24) and node-to-node lines, only on the founder's yes (Y1) | phase 5 | you |
| 7.16 | P23a notifications page: four switches (incl. **check-ins**) and the "keep notification words off my lock screen" row | phase 6 | settings |
| 7.17 | PI3 your invites and the invite row; P25a add a source (or reuse ON-6's "see all"); P27a where it's processed | phase 6 | settings |
| 7.18 | Danger dialogs' copy (C54.1); deleting / goodbye (C54.2); the time sheet (C47); "let it decide" and "yours" (C49); AC-2 at SE; the sign-out sheet's "nothing waiting" variant | phase 6 | settings |
| 7.19 | **EX-3 redraw:** a custom title and body, and the hidden-preview look ("retrospect has something for you.") | phase 2 (with the pipeline) | outside |
| 7.20 | EX-1 share states; C40.3 widget states beyond ready; a master for the share card (C55) | phase 7 | outside |
| 7.21 | "Save your old videos to photos" sheet (X06e); the recording Live Activity look | phase 7–8 | outside |
| 7.22 | Dark twins awaiting approval: podcasts `2HZY-0`, `2IFN-0`, `2GV0-0`, `2P6Q-0`, `2PBS-0`; goals `2JCP-0`, `2JRP-0`; outside's dark file `2KTI-0` (not read) | each area's gate | podcasts, goals, outside |

### 7b. Paper texts and values to fix

| # | Where | Now | Should be |
|---|---|---|---|
| 7.23 | Paywall `22M4-0` (`22MO-0`, `22ML-0`, `22MP-0`) | "$24.99", "$239.99", "works out to $20.00 a month"; no free-month line | "$19.99", "$199.99", "works out to $16.67 a month", "first month free" (the app shows StoreKit's localized price; Paper shows the founder's) |
| 7.24 | Paywall / M07 `IFL-0` | "save 20%" | "save 17%" |
| 7.25 | ST-9 account | "$239.99" | "$199.99" (StoreKit at run time) |
| 7.26 | ST-5 privacy | "where it's processed · europe" | unverified: Render's default region is Oregon. Verify where the backend, brain, database and model calls run, or drop the row (settings Q5) |
| 7.27 | ST-3 sources | the "add a source" subline names health, which is already connected | a source that isn't connected |
| 7.28 | ST-1 | hidden leftover layers ("listening", "warm", "talk") | delete them |
| 7.29 | AC-2 sign-out sheet | fill is canvas | `backgroundRaised` (already queued) |
| 7.30 | ON-10 hairline and M05 | blue | ink (one lit object) |
| 7.31 | Part 42 (questions) | "skip" | removed (screen rule 6) |
| 7.32 | PC-3 | "rests on 3 mornings" | "rests on 3 entries" (a noun the brain produces) |
| 7.33 | GL-1 | "you talk about running most on sundays." | an earned line (goals Q2); no weekday engine exists |
| 7.34 | GL-1 / GL-2 | "did 4 hours", "did 1 night" | counts ("2 times") on goals Q11's lean |
| 7.35 | Grey card on check-ins | label "a guess" | "a question" (a check-in isn't a guess: the honesty rule) |
| 7.36 | EX-2 lock screen | title "the fundraise article you sent" | the private look; brief words only with `lockScreenDetail` on |
| 7.37 | EX-3 | fixed lines | custom text (7.19) |
| 7.38 | YO-2 | the old "list" text and a grey mic | finding 55's fix |
| 7.39 | GL-2 instance name | `c:claim/asked · a pattern` (a description in the name); a state named "too early" with a space | rename (paper-inventory finding 8) |

Pending a founder answer, not fixes yet:
- YO-4's two-sentence synthesis (Y4);
- YO-5's life areas and non-canonical questions (Y5);
- Paper's grouped sources on YO-2 (Y6).

**Count for section 7:** 22 drawings, 17 text fixes.

---

## 8. The founder's questions

Deduplicated and sorted by what they block, Beta 1 first. The full list, written for the founder, is [founder-questions.md](./founder-questions.md).

| Id | Question | Lean | Blocks |
|---|---|---|---|
| B1 | Add about 17 PRs to Beta 1 (the live player and the ticket's real parts)? | yes for the 15 marked yes in §5; no for BE2.0a, PL7.6 and the sample half of T03a | Beta 1 scope |
| B2 | Show the inviter's name before sign-in? | yes, only on a live code | BE2.0a, PI1 |
| B3 | What is the ticket's "no. 0412"? | the invite's number in creation order | BE2.0b, `013`, C41.2 |
| B4 | Who is a founder invite "from"? | the founder's first name | BE2.0a/b |
| B5 | After "begin" in Beta 1, where do people go? | the current onboarding | PL1.8 |
| B6 | A sound at the tear? | none | PI2.4 |
| B7 | The undrawn invite states: approve from snapshots, or draw first? | build from round 1, approve snapshots | PI1 (on "draw first", PI1 waits) |
| N1 | Is a settings row that opens iOS's "Show Previews" the "hide the words" switch? | yes | P23a, PL7.10, contract 06 |
| N2 | Accept that the short, non-sensitive custom fallback passes through Apple? | yes | BE7.4, BE7.8a |
| N3 | Accept a 7-day notify token for the extension? | yes | BE7.9b, PL7.12 |
| N4 | Notification defaults: brief, episode, questions on; check-ins off? | yes | BE7.3 |
| N5 | One notification a day, never 21:00–08:00, the lower one dropped? | yes | BE7.4 |
| N6 | When to ask for notification permission? | on ON-10 while the first episode is made, and again when the brief is turned on | P05, PL5.1, PL5.4 |
| F1 | Is anything in first run behind the paywall? | no; `subscription_required` waits | BE2.8b |
| F2 | A quiet first episode: what then? | quiet line, skip the tease and paywall, land on first home | P05, PL1.9 |
| F3 | Goals in onboarding? | no; drop BE2.1 | BE2.1 |
| F4 | Which question set? | v2 (8 core + 2 fallbacks) | QuestionKey, P02 |
| F5 | One model-written follow-up per answer? | not in the first build | P02 |
| F6 | Knows-you thresholds? | little: under 1 source and under 3 answers; well: ≥ 3 sources and ≥ 7 answers | BE2.3b |
| F7 | Brief time in onboarding: quick answers or a picker? | quick answers (7, 8, 9, not now) | P02.2, who owns the picker |
| F8 | Splash opening (A, B2, B3 or D)? | D, "the dots connect" | M01 |
| F9 | M07 under paywall option A? | the glow slides to the plan being bought | M07 |
| F10 | Notion in ON-6 for the beta? | your earlier call was build; confirm the timing | BE2.9a–d |
| F11 | Legacy "magic moments" line? | leave out | BE2.1 / UI4.1 |
| P1 | Offline copies of episodes? | newest weekly auto-downloads on Wi-Fi; others by hand; position on this phone only | PL3.4c2, C20-p, PLP.3 |
| P2 | Episode feedback (more / less + "say more")? | yes, not mapped to a rating | UI5.4, BE3.2a/b |
| P3 | A quiet week, and the weekly time? | no push, a quiet row with the next date; Sunday 9:00 local | BE3.3a/b, C27.3 |
| P4 | Past briefs in the podcasts tab, audio kept for the account's life? | yes | BE3.6, BE3.4b, C27.2 |
| P5 | Episode chapter titles on the lock screen? | only with "show what's in your brief on the lock screen" on | PLP.2, PL7.10 |
| P6 | Old on-phone episodes? | carried over as "made on this phone" | XP.1, C27.2 |
| P7 | The new episode writer for everyone? | at G3 | chapters, PC-3 |
| P8 | The "…" menu? | chapters + download only | C20-p |
| G1 | Which window do goal counts cover, and in what unit? | card: 28 days; header: since stated; rows: this week; counted in things | BE4.0a, C29.1/2 |
| G2 | What may Retro's line on a goal say? | only earned lines, never model-written | BE4.0a |
| G3 | "Is that a goal?" questions: from where, on by default? | your own stated goals with a quote, behind a dial that's off | BE4.0d, BE4.4 |
| G4 | Add a goal by hand with "+"? | yes, a sheet (needs a drawing) | UIG.1 |
| G5 | Goals: a "done" state, and deleting? | neither in v1 | P17.2, BE4.1b |
| Y1 | What the map shows | themes = live patterns; 10 people / 8 themes / 6 goals; a person with no fact shows "comes up n times"; same-person questions first; you draw up to 24 slots | BE5.5a, C38 |
| Y2 | Merge YO-3 into JR-4 for your own words? | yes | UI6.6, P20 |
| Y3 | Where the portrait lives? | the "list" pill (needs a drawing) | UI6.7, BE5.2 |
| Y4 | YO-4's big line? | the best-supported single fact, no model call | BE5.1a, P21.1 |
| Y5 | YO-5's areas? | the brain's 8, with your titles | BE5.3c, P22 |
| Y6 | Group sources in search? | one per item for v1 | C32-n, BE5.4b |
| S1 | Ship the App Store minimum (delete account, restore, manage) right after payments? | yes | the App Store lane |
| S2 | Confirm with Apple when deleting an old Apple account? | only when no token is held | BE6.6a, PL3.7g |
| S3 | "Delete my data" keeps your choices? | keep brief, ambient, straightness and voice; drop what was learned | BE6.6c |
| S4 | Brief length, voice speeds | build length (2/4/6 min); speeds 0.8–1.5 | BE6.1a, BE6.2c |
| S5 | What people see when your master ambient switch is off? | their switch keeps its value, subline "paused for everyone" | BE6.1i, P27 |
| S6 | Where "your invites" lives? | a row on settings, "invite friends · 2 left" | PI3, P23 |
| S7 | "Where it's processed"? | a verified page, or drop the row | P27a |
| S8 | Export delivery? | a zip from the share sheet, plus a written notification | BE6.3c |
| S9 | "Let it decide" on how straight, once you've picked? | yes | C49 (was C45) |
| O1 | A Live Activity for playback? | no; Now Playing only | P35 |
| O2 | What can be shared in v1? | links and text; "goes with" offers only the suggestion | PL7.5a, BE7.2b, C55.2 |
| C1 | Copy to approve (one sitting) | see founder-questions.md | many |

**Dropped because a rule already answers them:**

| Question (plan) | Rule that answers it |
|---|---|
| "skip" on questions (first run F2) | screen rule 6: no skip |
| Google on the gate in Beta 1 (first run I8) | founder decision: Google after Beta 1 |
| Glow after the tear (I5); hint pill (F13); PC-3 ‹ and ⌄ (podcasts Q-12); next-line colour (Q-18); node-to-node lines (you Q2c); ST-1 trailing (settings Q16) | "Paper wins" (integrator rule, 21 Oct) |
| ON-10 hairline colour (F8) | one lit object per screen: ink |
| Force-update design (F9) | drawn in Paper first; a drawing task (§7), not a question |
| Paywall copy (F10) | prices decision + canned-acknowledgement decision |
| C16 listening field (F11) | one home per component: fold into #56 |
| VoiceOver progress wording (F12) | "step n of m": what iOS and the accessibility rules read |
| Talk or read on ST-7 (settings Q2) | journal v1 has canned acknowledgements: hidden |
| Check-in label "a guess" vs "a question" (goals Q10) | the honesty rule: only a guess is called a guess |
| Ended row's destination (goals Q5); did-row tap and "not for this goal" (Q7); reaching "why" while playing (podcasts Q-7); widget "talk" (outside Q4); search mic (you Q10); sureness dots (Q7); "only what's certain" remembered (Q6); "moved this week" row (Q12); add-a-source page (settings Q12); ST-9 for non-members (Q13); voice names (Q3, becomes copy) | the design system decides interaction and layout; only product questions go to the founder |
| Notifications always private (outside Q3) | decided 21 Oct: written custom |

**Count for section 8:** about 100 questions across the six plans, deduplicated to **55** (7 Beta 1, 6 notifications, 11 first run, 8 podcasts, 5 goals, 6 you, 9 settings, 2 outside, 1 copy sitting). 27 were dropped because a rule or a decision already answers them; the rest were merged.

---

## Changes this file asks of each plan

| Plan | Changes |
|---|---|
| first run (#69) | payload → 07 v2 (BE2.7b calls `schedule()`); adopt 06's connect shape and one `Source` type; `GET /v2/episodes/:id` uses 03's shape; jobs doors map onto 03's state + stage; `deviceId` on devices; drop BE2.1 on F16 = A; "$16.67"; build C23e.1–2 in phase 2 from podcasts' cards; migrations 013 and 158 as assigned |
| podcasts (#65) | payload → 07; BE3.3b calls `schedule()`, no `push_sends`; deep links from 07's table; PLP.1a and PLP.1b (small) in Beta 1; PLP.2 reads `lockScreenDetail`; X3.x → XP.x, and XP.2b dropped for X10c; migrations 157, 160, 161 |
| goals (#60) | check-in push through BE7.4 and the writer, no fixed text, no window, no switch of its own (`checkIns` in BE7.3); GL-2's guess uses UI5.3; C32 grouped panel as a C32 variant; migrations 162–166 |
| you (#62) | UI5.0 → UI6.0; C38.1 builds on first run's; the question push is BE7.6's; link `retrospect://you/question/<id>`; migrations 167–169 |
| settings (#68) | C41–C50 → C45–C54; UI6.0 → UIS.0; drop BE6.7, `014` and `hideWordsOnLockScreen`; build the iOS Show Previews row; read and write BE7.3's prefs; add the check-ins switch; export calls `schedule()`; BE6.1a, BE6.2a and BE6.2b move to phase 2; migrations 159, 170, 171, 017; "copy to confirm" out of code |
| outside (#66) | drop M01–M13, X02b and PL7.6; C41 → C55, C42 → a #54 variant; the notification pipeline (BE7.3, BE7.4, BE7.8a/b, BE7.9a/b, PL5.3, PL7.11, PL7.12, INT7.3) moves to phase 2; C40.4 reuses PLP.2's render; migrations 014–016, 018, 172–174 |
| main docs | first-ship: §5's Beta 1 additions. Contracts 00 and 02: §2c. later-phases: BE2.1, BE3.x, BE4.x, BE5.x and BE6.4 meanings, and retirement as phase 8. phase-0: §3's numbers. ui/later.md: C ids, UI ids, moments' owners |
