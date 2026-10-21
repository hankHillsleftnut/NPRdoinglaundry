# Contract 07 · Outside the app

Everything Retro does when the app isn't open: EX-1 (save something from another app through the share sheet), EX-2 (the lock screen while a brief or episode plays), EX-3 (notifications) and EX-4 (widgets). It also covers the links that open the app at the right place. Built on contract 00; the brief and the entry come from contract 02. Status: **draft for the founder's review**.

Part of this contract is between the backend and the app (the share doors, notification preferences and the push payloads). Part of it is **on the phone only**, between the app and its own extensions (the widget snapshot and the share inbox). The phone-only shapes are written here anyway, with fixtures, because two separately built programs (the app and an extension) must agree on them exactly as the app and backend do.

The agent fields below were read from code on 21 Oct: `src/reference/capture.ts`, `enrich.ts`, `relevance.ts`, `youtube-transcript.ts`, `src/jobs/material-arrivals.ts`, `src/routes/notifications.ts` (agent, `origin/main` a886060) and the backend's `routes/*.ts`. Where the brain can't give what a screen needs, the byte that adds it is named.

## 1. Shared types

```ts
// The thing someone shared. The page itself is reference, never evidence about the person
// (capture.ts header): nothing here is a claim about them.
type SharedThing = {
  url: string;                                    // canonical http(s) URL after redirects (enrich.ts checkUrl rules)
  kind: "page" | "video" | "post" | "unknown";    // video = a YouTube link (youtubeVideoUrl), post = an X/Twitter status (tweetOembedUrl)
  title?: string;                                 // ≤ 200 characters; absent when the page has none
  site: string;                                   // the host without "www.", e.g. "example.com"
  length?: { unit: "read" | "watch"; minutes: number };   // read: words / 230, rounded up; watch: the transcript's last cue, rounded up
};
```

There's no thumbnail on purpose. EX-1 draws a 56pt mesh made on the phone (seeded from the URL), so the phone never downloads a stranger's image and the server never proxies one.

`Entry` is contract 02 §5. A saved share comes back as an `Entry` whose `kind` is `"imported"` today (02's rule: everything else the person sent). **Requested change to 02:** an additive value `"shared"`. The app already decodes unknown values as `unknown` (README rule 5), so this is safe to add (see §11).

## 2. Saving something from another app (EX-1)

The share sheet does two things. It **reads** the link ("retro's read" and what it "goes with"), which needs a model, so it can be slow or refused. It **saves** the thing, which is cheap and must never be lost. Saving never waits for reading: the person can tap **save** while "reading…" still shows.

### 2.1 Reading it: `POST /v2/shares/preview`

```json
{ "url": "https://example.com/essays/on-sleep", "text": "the bit about naps" }
```
- `url` is required: http or https only, ≤ 2,048 characters, no credentials, standard ports. A plain-text share has no preview; the extension shows just the text.
- `text` is optional, ≤ 2,000 characters. It's what came with the link (the selected text, or a post's own words). It's sent so the read can mention it, and it's never stored by this door.

→
```json
{
  "thing": { "url": "https://example.com/essays/on-sleep", "kind": "page", "title": "on sleep and memory", "site": "example.com", "length": { "unit": "read", "minutes": 12 } },
  "read": "a long essay on how sleep shapes what you remember.",
  "goesWith": { "goalId": "<uuid>", "title": "sleep before midnight" },
  "reading": "ready"
}
```
- `reading`: `ready | unreadable | unknown`. When the page can't be fetched (private address, too big, not text, timeout, blocked), the response is `unreadable`: `thing` has only `url`, `kind` and `site`, and `read` and `goesWith` are `null`. That's an answer, not an error.
- `read` is **one sentence about the thing, never about the person**, lowercase and ≤ 140 characters. It is never "you'll love this" or "this is for your goal". The door rejects (and drops to `null`) any read that starts with "you" or contains "your". That check is a test in BE7.1b.
- `goesWith` is **a suggestion the person confirms by saving**. The app shows it as a chip with "change" beside it, and it's stored as theirs only if they keep it (§2.2 `goalChoice`). It comes from the same judgement the agent already makes for saved links (`relevance.ts`, "when unsure, leave it out"). At most one goal: the first the model names. `null` when none.
- Idempotent by nature (no writes). The door caches by `(user, url)` for 10 minutes, so reopening the sheet doesn't pay twice.
- Bucket `expensive`, 20 an hour per user; `spend_limited` and `rate_limited` are answered with the plain error. The extension then shows no read and saving still works.
- Timeout: the door gives the agent 12 s. The extension stops waiting after 8 s and shows the card without a read. The person can still save.

### 2.2 Saving it: `POST /v2/shares`, idempotent (`Idempotency-Key: <clientEntryId>`)

```json
{
  "clientEntryId": "<uuid>",
  "url": "https://example.com/essays/on-sleep",
  "text": "the bit about naps",
  "note": "for the trip planning",
  "goalId": "<uuid>",
  "goalChoice": "kept",
  "sharedAt": "2026-10-21T13:02:11.410Z"
}
```
- At least one of `url` or `text` is required (`invalid_request` otherwise). `url` follows the §2.1 rules; `text` is ≤ 20,000 characters; `note` (the person's "add why", typed or spoken) is ≤ 2,000.
- `goalChoice`: `kept` (the suggestion, unchanged) · `changed` (the person picked another goal) · `none` (they removed it, or none was suggested). `goalId` is present only for `kept` and `changed`. An id that isn't theirs is `not_found`.
- `sharedAt` follows the same skew rules as `createdAt` in BE1.1: not more than 5 minutes ahead, not older than 30 days (the share inbox can hold items while offline).
- → **201** `{ "entry": Entry, "thing": SharedThing | null }` on the first save, and **200** with the stored entry on a replay. The same key with a different body is 409 `idempotency_mismatch` (contract 00). `thing` is `null` if the read never ran.
- What's stored: one `raw_content` row, `content_type 'shared_link'` (already in the agent's "sent by the person" set, `planner/daily.ts:22`). Its `content` is the person's own words first (the note, then the text) followed by the URL, because `capture.ts` takes "the words around it as its reason". `metadata` holds `{ client_entry_id, goal_id?, goal_choice, app_version }`. Nothing else is stored.
- After the write: the agent's minute-by-minute material-arrivals job already captures, enriches and relates links (`material-arrivals.ts:20-23`). With `goalChoice` `kept` or `changed`, the agent records the goal as **the person's own link** (BE7.2a), so the relevance model doesn't override it later.
- Bucket `write`. Never `spend_limited`: saving is reading data, and reading data is never refused (context §3).

**"saved" means the server has it.** The EX-1 states map to this as follows:

| EX-1 state | When |
|---|---|
| reading | `preview` in flight; the card shows `site` at once (parsed on the phone) |
| saving | `POST /v2/shares` in flight (from the extension, or from the app's outbox) |
| saved, "it'll be in tomorrow's brief" | a 200 or 201 came back. If the person's brief is off, the line is "it's in your journal" instead (founder copy, §12) |
| offline (queued) | no network, no access token, or the extension ran out of time: the item is in the share inbox (§4) and the app sends it the next time it runs; the line is "it'll send next time you open retrospect" |
| video (transcript fetched) | `thing.kind == "video"`; the read is based on the transcript (`youtube-transcript.ts`), and the length is "12 min watch" |

## 3. Widgets (EX-4): the widget snapshot, phone only

The widget **never calls the network and never holds a token**. The app writes one small file into the app group whenever the brief, the episode or the sign-in changes. The widget's timeline provider only reads that file. That keeps tokens out of a third process, keeps the widget cheap to run, and makes "what the widget shows" testable from fixtures.

Path: `<app group container>/Library/Application Support/Outside/widget-snapshot.v1.json`, written atomically (write to a temp file, then rename). File protection is `completeUntilFirstUserAuthentication`, so a locked phone after its first unlock can still render.

```ts
type WidgetSnapshot = {
  v: 1;
  writtenAt: string;                   // ISO ms
  signedIn: boolean;                   // false → every widget shows "open retrospect"
  brief: {
    state: "ready" | "playing" | "played" | "quiet" | "making" | "off" | "unavailable" | "unknown";
    id?: string;
    date?: string;                     // YYYY-MM-DD, the user's day
    headline?: string;                 // the same line the brief card shows (C26), ≤ 120 characters; absent unless state is ready/playing/played
    minutes?: number;                  // ceil(audio.durationSeconds / 60); absent without audio
    hasAudio: boolean;                 // false → no play pill; the medium widget's play opens JR-2 instead
    quietLine?: string;                // kind == quiet: the agent's quiet line
  };
  episode?: {                          // shown only when brief.state == off (EX-4 "then the episode of the week")
    id: string; title: string; minutes?: number; state: "ready" | "played" | "unknown";
  };
  briefOffNoticeShown: boolean;        // "turn on your daily brief in retrospect" is shown once, then the episode
  lockScreenDetail: boolean;           // §6: the person's choice; false → headline and title are marked privacy-sensitive
};
```
- `unavailable` means the app couldn't load today's brief (the "open retrospect to load today's brief" state). `unknown` is any value this widget version doesn't know, and it renders like `unavailable`.
- `playing` is written by the player when playback starts and is cleared when it stops, so the widget's pill shows pause.
- **The widget never runs any brief or episode logic.** Every state above was decided by the app from contract 02 and 03 data.
- Timeline: one entry now, plus one at the next local midnight that turns `played` and `ready` back to `making` (if the brief is on) or to `off`. The app calls `WidgetCenter.reloadTimelines(ofKind:)` on every write. The app also asks for a reload when a silent `refresh` push arrives (§5.3).

**Widget actions** (iOS 17 interactive widgets):

| Pill | Implementation | Outcome |
|---|---|---|
| play / pause (medium) | `AudioPlaybackIntent` (`PlayBriefIntent { briefId }`), which runs in the app's process without opening it | plays today's brief (cached audio first, else streamed); the widget flips to `playing` |
| talk (both sizes) | `Link(destination: retrospect://compose)` | opens JR-1 with the composer focused (§7; founder question 4) |
| tapping the widget body | `widgetURL(retrospect://brief)` (medium), `retrospect://compose` (small) | JR-2 / JR-1 |

## 4. The share inbox (EX-1 ↔ app), phone only

The share extension sends straight to `POST /v2/shares` when it can. Whatever it can't send, it leaves in the share inbox, and the app moves that into its outbox (PL2.2) the next time it runs. Every item carries its `clientEntryId` from the moment the person taps save. The extension and the app may both try to send the same item, and the server's idempotency makes that harmless: one entry, always.

Path: `<app group>/Library/Application Support/Outside/inbox/<clientEntryId>.json`, one file per item, written atomically, with protection `completeUntilFirstUserAuthentication`.

```ts
type InboxItem = {
  v: 1;
  clientEntryId: string;               // UUID, the idempotency key everywhere
  request: SharesCreateRequest;        // exactly the §2.2 body
  createdAt: string;                   // ISO ms, when save was tapped
  attempts: number;                    // extension attempts so far (0–2)
  lastError?: "offline" | "noToken" | "timeout" | "server" | "unknown";
  sentByExtension: boolean;            // true once the extension got a 200/201; the app then only deletes the file
};
```
- The app's importer (PL7.4) reads every file. If `sentByExtension` is set it deletes the file; otherwise it enqueues the request in the outbox with operation `share.create` and its `clientEntryId`, then deletes the file. A file that won't decode is moved to `inbox/unreadable/`, counted and logged with no content. It's never deleted silently.
- Items older than 30 days are refused by the server (`invalid_request` on `sharedAt`). The outbox marks them failed and they show as "not sent" in the journal (C30), never lost silently.

**The access token in extensions.** The app mirrors **only the access token** and its expiry (15 minutes, contract 00 §3) into a Keychain item in a shared access group, readable by the share extension. **The refresh token never leaves the app.** Two processes refreshing the same rotating token would trip reuse detection and sign the person out everywhere (BE0.4). An expired or missing token means the item goes to the inbox, with no refresh attempt from the extension.

## 5. Notifications (EX-3)

### 5.1 The rules

- **Private by default, and the payload never carries personal content.** The alert text is a localisation key the app owns (`loc-key`), so the server sends no prose and nothing personal passes through Apple (BE2.7).
- **At most one a day**, per person, counted in their own day. `exportReady` is exempt because the person asked for it. If two are due on the same day, the higher one goes out: episode › brief › question › check-in. The other is dropped, not queued (founder question 7).
- **Never at night.** Quiet hours are 21:00–08:00 in the person's time zone (`users.time_zone`). Anything due in quiet hours is held until 08:00. If it's stale by then (a brief from yesterday), it's dropped.
- **Each kind can be turned off** (§5.4). The brief's push is only ever sent if the person's daily brief is on (`daily_brief_enabled`, D7).
- Taps go through the router: the payload's `link` is parsed by `Routing.Parser` (PL5.2), never trusted as a string.

### 5.2 The payload (APNs, `apns-push-type: alert`)

```json
{
  "aps": {
    "alert": { "loc-key": "notify.brief.ready", "loc-args": ["4"] },
    "sound": "default",
    "category": "BRIEF_READY",
    "thread-id": "brief",
    "interruption-level": "active",
    "relevance-score": 0.6
  },
  "r": { "v": 1, "kind": "briefReady", "id": "<uuid>", "link": "retrospect://brief/<uuid>", "sentAt": "2026-10-21T08:00:04.200Z" }
}
```

| `r.kind` | `aps.category` | `loc-key` → copy (lowercase, the app's string catalog) | `loc-args` | `link` | Actions | `interruption-level` |
|---|---|---|---|---|---|---|
| `briefReady` | `BRIEF_READY` | `notify.brief.ready` → "your brief is ready · %@ min" | minutes (omitted with no audio → `notify.brief.ready.noaudio` "your brief is ready.") | `retrospect://brief/<id>` → JR-2 | `PLAY` "play" (foreground: opens JR-2 and plays) | `active` |
| `episodeReady` | `EPISODE_READY` | `notify.episode.ready` → "this week's episode is here." | — | `retrospect://episode/<id>` → PC-2 | `PLAY` "play" (foreground) | `active` |
| `question` | `QUESTION` | `notify.question` → "one question for you, when you have a minute." | — | `retrospect://guess/<id>` → YO-4 | none: a guess is answered in its context, never from the lock screen | `passive` |
| `checkIn` | `CHECK_IN` | `notify.checkin` → founder copy (contract 04) | — | `retrospect://goal/<id>` → GL-2 | none | `passive` |
| `exportReady` | `EXPORT_READY` | `notify.export.ready` → "your data is ready to download." | — | `retrospect://settings/privacy` | none | `active` |
| anything else | — | the app shows nothing new; a tap opens the app at its last place | — | parsed; unknown → ignored | — | — |

- `apns-collapse-id`: `<kind>-<local day>`, so a retried send replaces itself instead of stacking.
- `apns-expiration`: the end of the person's local day for `briefReady` and `question`, and 7 days for the others.
- `r.v` is the payload version. The app ignores an `r` it can't decode and still shows the system alert, which needs no app code.
- The app catalog holds every `loc-key`. A key the installed app doesn't have shows the key itself, so **new kinds ship in the app before the server sends them** (an ordering rule in BE7.4).

### 5.3 The silent refresh (`apns-push-type: background`, priority 5)

```json
{ "aps": { "content-available": 1 }, "r": { "v": 1, "kind": "refresh", "scope": ["brief"], "sentAt": "…" } }
```
`scope`: `brief | episode | unknown`. The app wakes (when iOS allows), refetches the named data with `GET /v2/briefs/latest` or `GET /v2/episodes`, prefetches the audio over Wi-Fi only, rewrites the widget snapshot and reloads the widgets. It's sent alongside `briefReady` and `episodeReady`, and also when the brief is made with notifications off, so the widget is current either way. It isn't counted in the one-a-day rule (the person never sees it). iOS throttles these, so nothing depends on one arriving.

### 5.4 Notification preferences

`GET /v2/notifications/preferences` →
```json
{ "briefReady": true, "episodeReady": true, "questions": true, "checkIns": true, "quietHours": { "start": "21:00", "end": "08:00" } }
```
`PUT /v2/notifications/preferences` takes any subset of the four booleans and returns the full object. `quietHours` is read-only in v1 (founder question 6). Defaults are all `true`, because the system permission prompt is the real opt-in. Bucket `read` / `write`. Idempotent by nature (a PUT of values). The settings screen that shows these belongs to contract 06; this door is the data underneath it.

Device registration (`POST /v2/devices`, BE2.6) and the push sender (BE2.7) belong to first run (contract 01). This contract adds only what's sent and when.

## 6. The lock screen (EX-2): Now Playing, phone only

The brief and the episode play through the system's Now Playing (`MPNowPlayingInfoCenter` + `MPRemoteCommandCenter`). That gives the lock screen, Control Center, the Dynamic Island, AirPods, CarPlay and the Apple Watch for free. **No separate Live Activity is drawn for playback** (founder question 2, lean).

| Now Playing field | `lockScreenDetail == false` (default) | `lockScreenDetail == true` |
|---|---|---|
| title | "tuesday's brief" / "this week's episode" | the part being spoken (brief) / the episode title (episode) |
| artist (subtitle) | "retrospect · part 2 of 3" | "retrospect · tuesday's brief · part 2 of 3" (EX-2 as drawn) |
| artwork | the brief mesh, rendered on the phone (C40.4) | same |
| elapsed / duration / rate | live | live |
| commands | play, pause, skip back 15, skip forward 30, scrub (`changePlaybackPosition`) | same |

`lockScreenDetail` is one per-device choice ("show what's in your brief on the lock screen", off by default, founder question 1). It's stored on the phone (the settings screen is contract 06's) and governs the Now Playing title, the widget's privacy-sensitive marking (§3) and nothing else. Notifications stay private either way (founder question 3).

The **recording** Live Activity that exists today (`VoiceRecordingAttributes`, "stop" links to `retrospect://stop-recording`) carries over to the new voice composer unchanged in shape (PL7.7). It shows no words, only time and a stop button.

## 7. Links into the app

Every way in goes through `Routing.Parser` (PL5.2). This flow uses these destinations (★ = a destination PL5.2 doesn't have yet; the change is listed in §11):

| URL | Destination | Opens | From |
|---|---|---|---|
| `retrospect://brief` | `.brief(id: nil)` | JR-2, today's | widget body, `briefReady` with no id |
| `retrospect://brief/<uuid>` | `.brief(id:)` | JR-2 for that brief; JR-1 with a "that brief is gone" toast if it no longer exists | `briefReady` |
| `retrospect://episode/<uuid>` | `.episode(id:)` | PC-2 | `episodeReady` |
| `retrospect://guess/<uuid>` | `.guess(id:)` | YO-4 with that guess; a guess already answered opens YO-4 showing its answer | `question` |
| `retrospect://goal/<uuid>` ★ | `.goal(id:)` | GL-2 | `checkIn` |
| `retrospect://compose` ★ | `.compose` | JR-1, composer focused (keyboard), scrolled to the newest | widget "talk" |
| `retrospect://settings/privacy` | `.settings(.privacy)` | ST privacy | `exportReady` |
| `retrospect://start-recording`, `stop-recording` | as today | the recorder | control widget, recording Live Activity |

Destinations that need a signed-in, onboarded app wait in the router's `pending` (PL5.2) and are consumed once. A link from a notification about another account (signed out, then signed in as someone else) resolves to `not_found` on its door and lands on the screen's gone state, never on someone else's data.

## 8. Errors

Every door returns contract 00's envelope and codes. Specific to this flow:

| Door | Case | Code | The extension or app shows |
|---|---|---|---|
| preview | URL not http(s), bad port, credentials | `invalid_request` | the card without a read; save still works (the save door refuses it the same way, so the extension checks first and shows "this link can't be saved") |
| preview | page unreadable | 200 `reading: "unreadable"` | the card with the site only |
| preview | over the hour's limit or spend cap | `rate_limited` / `spend_limited` | the card without a read |
| shares | no url and no text | `invalid_request` | (the extension never sends this; a bug state) |
| shares | goal not theirs (or deleted since the preview) | `not_found` | nothing was stored (the door checks the goal before writing). The sender resends once without the goal (`goalChoice: "none"`) under a **new** `clientEntryId`, because reusing the key with a different body would be `idempotency_mismatch`. The person sees "saved" with no goal chip |
| shares | same key, different body | `idempotency_mismatch` | a bug state, logged as a count |
| shares | `sharedAt` too old | `invalid_request` | "not sent" in the journal |
| preferences | a non-boolean value | `invalid_request` | a bug state |
| all | waitlisted / suspended | `invite_required` / `suspended` | the extension shows "open retrospect to finish signing in" and saves nothing |

## 9. Limits

| Door | Bucket | Limit |
|---|---|---|
| `POST /v2/shares/preview` | `expensive` | 20 an hour per user, plus the spend cap |
| `POST /v2/shares` | `write` | the write bucket (BE0.1) |
| `GET/PUT /v2/notifications/preferences` | `read` / `write` | the defaults |

Pushes per person: at most 1 alert a day (plus `exportReady`), at most 4 silent refreshes a day.

## 10. What the brain and backend must add (bytes in `flows/outside/backend.md`)

| Need | Today | Byte |
|---|---|---|
| A read of one link without saving it | `enrich.ts` and `relevance.ts` work only on stored `reference_items`, in batches | **BE7.1a** agent `POST /reference/:userId/preview { url, text? }`: the same locked-down fetch, summary and relevance, for one URL, with no writes |
| The preview door | none | **BE7.1b** |
| The person's own goal choice on a saved link | `relatePending` would overwrite `goal_ids` | **BE7.2a** agent: `reference_items.goal_source ('model' \| 'person')`; capture copies `metadata.goal_id` into `goal_ids` with source `person`; relevance never touches person-sourced rows |
| The save door | `POST /content` has no `shared_link` type and its own response shape | **BE7.2b** `POST /v2/shares` on `insertRawContent` |
| Notification preferences | none | **BE7.3** migration `0NN_notification_preferences.sql` + door |
| One a day, quiet hours, collapse | none (BE2.7 sends; nothing decides when) | **BE7.4** `notification_log` + `Push.schedule()` |
| "your brief is ready" | no push; briefs are made by a fixed 08:00 UTC cron (BE6.2 makes it per user) | **BE7.5** |
| "one question for you" | none; guesses can be listed (BE1.4) | **BE7.6** |
| Silent refresh | none | **BE7.7** |

## 11. Changes this contract asks of other contracts and cards

1. **Contract 02 §5:** add `"shared"` to `Entry.kind` (additive; mapped from `content_type 'shared_link'`).
2. **Contract 02 §3:** the brief card's headline (C26) has no field in `Brief`. The widget reuses whatever the brief card uses. The integrator should name it in 02 (lean: `headline`, the first sentence of the first part, ≤ 120 characters, made by the door).
3. **PL5.2:** add `.compose` and `.goal(id:)` to `Routing.Destination`, with parser rows for `retrospect://compose` and `retrospect://goal/<uuid>`.
4. **Contract 06:** the settings screen for §5.4 (the four switches) and the `lockScreenDetail` choice (§6).
5. **PL1.3 / PL1.5:** the session store writes the access-token mirror (§4) on every sign-in and refresh, and deletes it at sign-out (PL7.3 builds the mirror; the call sites are in PL1.5).

## 12. Decisions the founder makes for this contract

Each one has a lean, and work goes ahead on the lean. The full list with options is in `flows/outside/README.md` §8.

1. **The lock screen shows the brief's words** only if you allow it (lean: off by default; one choice covers Now Playing and the widget when locked).
2. **A Live Activity for playback:** lean no; Now Playing already covers the lock screen and the Dynamic Island.
3. **Notifications are always private** (lean), with no "show details" option in v1.
4. **The widget's "talk"** opens the composer ready to type (lean), not listening.
5. **What the share sheet accepts:** links and text (lean); images and files later.
6. **Quiet hours** are fixed at 21:00–08:00 in v1 (lean).
7. **When two notifications fall on one day**, the lower one is dropped (lean).
8. **Copy:** the "saved" line when the brief is off ("it's in your journal."), the check-in line and the export line.

## 13. Fixtures

`fixtures/07/`:
- **Shares:** `share.preview.request.json`, `share.preview.response.json`, `share.preview.video.json`, `share.preview.unreadable.json`, `share.preview.minimal.json`, `share.create.request.json`, `share.create.request.text.json`, `share.create.response.json`.
- **Notification preferences:** `notifications.preferences.json`, `notifications.preferences.put.request.json`.
- **Push payloads:** `push.brief.ready.json`, `push.brief.ready.noaudio.json`, `push.episode.ready.json`, `push.question.json`, `push.refresh.json`, `push.unknown-kind.json`.
- **Widget snapshot:** `widget.snapshot.ready.json`, `widget.snapshot.playing.json`, `widget.snapshot.quiet.json`, `widget.snapshot.making.json`, `widget.snapshot.off-episode.json`, `widget.snapshot.signed-out.json`, `widget.snapshot.unknown-state.json`.
- **Share inbox:** `inbox.item.json`, `inbox.item.sent.json`.
- **Errors:** `error.share.invalid_url.json`, `error.share.goal_not_found.json`, `error.share.idempotency_mismatch.json`, `error.preview.spend_limited.json`.

Every value is invented (`example.com`, invented goals). The backend validates the door and push fixtures against its zod schemas. The app decodes all of them, including the phone-only ones, in both the app's tests and the extension's tests.
