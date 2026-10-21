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

**Founder decision, 21 Oct:** "every notification needs to be written custom, even the notification for showing briefs." There is no generic copy anywhere: no "your brief is ready", no fixed line per kind. Every push's title and body are written by the brain for that person and that moment (BE7.8).

- **Written custom, lock-screen safe.** The writer's rules are in §5.5. Each push has two texts, both custom:
  - the **full text** is the best line for that moment. It can be specific, but never sensitive
  - the **fallback** is non-sensitive by construction (no names, health, relationships, money or places), and still specific to the day ("three things from tuesday worth four minutes")
- **The words don't travel through Apple, except the fallback.** The payload carries ids and `mutable-content: 1`. A Notification Service Extension on the phone fetches the full text from `GET /v2/notifications/:id/content` (§5.6) and sets it before the notification is shown. **The fallback is the exception:** it rides in the payload so something custom shows if the fetch fails, which is why it's written to be safe on any lock screen. That's the trade the founder's design makes. It's noted here plainly because it changes the old rule "nothing passes through Apple" (BE2.7) to "only the non-sensitive fallback passes through Apple".
- **Hiding the words on the lock screen** is the person's choice through iOS's own **Show Previews: When Unlocked** for Retrospect. Our setting row (contract 06) explains it and opens the system page (`UIApplication.openNotificationSettingsURLString`). When previews are hidden, iOS shows each category's `hiddenPreviewsBodyPlaceholder`, which is "retrospect has something for you." (the only fixed string, and it says nothing). The custom text appears once the phone is unlocked. We don't build a second, weaker version of a privacy control iOS already enforces.
- **At most one a day**, per person, counted in their own day. `exportReady` is exempt because the person asked for it. If two are due on the same day, the higher one goes out: episode › brief › question › check-in. The other is dropped, not queued (founder question 7).
- **Never at night.** Quiet hours are 21:00–08:00 in the person's time zone (`users.time_zone`). Anything due in quiet hours is held until 08:00. If it's stale by then (a brief from yesterday), it's dropped. A held push is **rewritten when it's sent**, so the words fit the moment it arrives.
- **Each kind can be turned off** (§5.4). The brief's push is only ever sent if the person's daily brief is on (`daily_brief_enabled`, D7).
- **Writing costs money**, counted against the person's daily spend cap (BEA.4). If the cap is reached, the writer isn't called. The push is still sent, with a fallback built without a model from the day's own facts (§5.5 "no-model fallback"). A notification is never dropped because of spend.
- Taps go through the router: the payload's `link` is parsed by `Routing.Parser` (PL5.2), never trusted as a string.

### 5.2 The payload (APNs, `apns-push-type: alert`)

```json
{
  "aps": {
    "alert": { "title": "tuesday, in four minutes", "body": "three things from your day worth hearing." },
    "mutable-content": 1,
    "sound": "default",
    "category": "BRIEF_READY",
    "thread-id": "brief",
    "interruption-level": "active",
    "relevance-score": 0.6
  },
  "r": { "v": 2, "kind": "briefReady", "id": "<notification uuid>", "refId": "<brief uuid>", "link": "retrospect://brief/<brief uuid>", "sentAt": "2026-10-21T08:00:04.200Z" }
}
```
- `aps.alert` **is the fallback** (title ≤ 40 characters, body ≤ 110, both custom and non-sensitive, §5.5). The service extension replaces it with the full text when the fetch succeeds.
- `r.id` is the notification's own id (the `notification_log` row), used to fetch the full text. `r.refId` is the brief, episode, guess or goal.
- `r.v` is now **2**; `v: 1` (loc-key payloads) is never sent.

| `r.kind` | `aps.category` | What the writer is writing about | `link` | Actions | `interruption-level` |
|---|---|---|---|---|---|
| `briefReady` | `BRIEF_READY` | today's brief: what kind of day it covers and how long it is | `retrospect://brief/<refId>` → JR-2 | `PLAY` "play" (foreground: opens JR-2 and plays) | `active` |
| `episodeReady` | `EPISODE_READY` | this week's episode, as a tease of its first chapter | `retrospect://episode/<refId>` → PC-2 | `PLAY` "play" (foreground) | `active` |
| `question` | `QUESTION` | that a question is waiting and roughly what about, **as a question, never the guess itself** | `retrospect://guess/<refId>` → YO-4 | none: a guess is answered in its context | `passive` |
| `checkIn` | `CHECK_IN` | the goal, by its own title only if the title passes the deny list; otherwise "one of your goals" | `retrospect://goal/<refId>` → GL-2 | none | `passive` |
| `exportReady` | `EXPORT_READY` | that their data is ready, and until when | `retrospect://settings/privacy` | none | `active` |
| anything else | — | the system shows the fallback as sent; a tap opens the app at its last place | parsed; unknown → ignored | — | — |

- `apns-collapse-id`: `<kind>-<local day>`, so a retried send replaces itself instead of stacking.
- `apns-expiration`: the end of the person's local day for `briefReady` and `question`, and 7 days for the others.
- The app ignores an `r` it can't decode, and the system still shows the fallback, which needs no app code.

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

### 5.5 The writer's rules (BE7.8)

For every push, one call writes `{ title, body, fallback: { title, body } }`.

| Rule | How it's enforced |
|---|---|
| short: title ≤ 40, body ≤ 110 characters | schema check; over-long text is rejected, never cut mid-word |
| lowercase house voice, no emoji, no exclamation marks | prompt plus a check (`/[A-Z]/` outside proper nouns the person wrote, emoji ranges, `!`) |
| **never asserts a guess**: a guess is mentioned only as a question that's waiting | the writer is given guesses only as `{ id, kind: "guess" }` with no text, so it can't state one |
| **no invented facts**: every specific comes from the inputs | inputs are a closed list of short facts from the brief or episode (titles, part count, minutes, day, the goal's own title); a check rejects numbers and proper nouns that aren't in the inputs |
| **lock-screen safe**: no health, relationship, money, location or other sensitive specifics in either text; a tease, not a disclosure | the **deny list** (BE7.8b): a maintained term list across health, body, mental health, sex and relationships, money and debt, legal, religion, location and named people, plus a small classifier call when the list is inconclusive. The fallback must pass with **zero** hits; the full text may name the person's own goal or topic only if it passes too |
| the fallback is still specific to the day | built from non-sensitive facts only (the weekday, the length, the part count, the kind), e.g. "tuesday, in four minutes" / "three things from your day worth hearing." |

- **When a check fails:** the writer retries once with the failure named. If it fails again, the full text becomes the fallback.
- **No-model fallback:** used when the fallback itself fails, or when the spend cap is reached. It's assembled from the day's non-sensitive facts with a small set of templates owned by the brain (`"<weekday>, in <n> minutes"`). These templates are the only template text in the system, and they're filled per person and day, so no two people get the same line on the same day unless their facts match.
- Cost is recorded as run kind `notification_write` against the spend cap. The spend cap's "reading data is never refused" rule doesn't apply here (this is writing); the no-model fallback covers the case.

### 5.6 Fetching the full text: `GET /v2/notifications/:id/content`

Called only by the Notification Service Extension, with `Authorization: Bearer <notify token>` (§5.7).
→ `{ "title": "…", "body": "…", "expiresAt": "…" }` for the person's own notification. A notification older than 7 days, or not theirs, is `not_found`. Bucket `read`. Never logged with content.

### 5.7 The notify token

The extension can't use the app's 15-minute access token: when a push arrives, the app may not have run for hours, so that token would usually be expired and the custom text would rarely show. Instead:

`POST /v2/notifications/token` (with the normal access token, called by the app on sign-in, on every session refresh, and on launch if the current one is older than 24 hours) → `{ "notifyToken": "<opaque>", "expiresAt": "<+7 days>" }`.

- **Scope:** it's accepted only by `GET /v2/notifications/:id/content`, and every other door rejects it (`unauthenticated`).
- **Lifetime and storage:** 7 days, stored hashed server-side (`notify_tokens`, one per device). It's revoked at sign-out, at delete-account and when a new one is issued for the device.
- **On the phone:** it lives in the shared keychain access group with `AfterFirstUnlockThisDeviceOnly` (PL7.12).
- **The refresh token never leaves the app.**

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

`lockScreenDetail` is one per-device choice ("show what's in your brief on the lock screen", off by default, founder question 1). It's stored on the phone (the settings screen is contract 06's) and governs the Now Playing title, the widget's privacy-sensitive marking (§3) and nothing else. Notifications are separate: their lock-screen privacy is iOS's Show Previews setting (§5.1).

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
| notification content | notify token expired, revoked or used on another door | `unauthenticated` | the service extension shows the payload's fallback |
| all | waitlisted / suspended | `invite_required` / `suspended` | the extension shows "open retrospect to finish signing in" and saves nothing |

## 9. Limits

| Door | Bucket | Limit |
|---|---|---|
| `POST /v2/shares/preview` | `expensive` | 20 an hour per user, plus the spend cap |
| `POST /v2/shares` | `write` | the write bucket (BE0.1) |
| `GET/PUT /v2/notifications/preferences` | `read` / `write` | the defaults |

| `GET /v2/notifications/:id/content` | `read` | the defaults; notify token only |
| `POST /v2/notifications/token` | `write` | 10 a day per device |

Pushes per person: at most 1 alert a day (plus `exportReady`), at most 4 silent refreshes a day. One writer call per alert, counted against the spend cap.

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
| Custom text for every push | the agent's `POST /notifications/generate` writes morning/evening copy from **legacy tables** with no safety rules | **BE7.8a** agent writer `POST /notifications/:userId/write` (new; the old route retires in X08a) · **BE7.8b** the deny list and checks |
| The text fetch | none | **BE7.9a** `GET /v2/notifications/:id/content` |
| A token the service extension can use | none | **BE7.9b** `POST /v2/notifications/token` + `notify_tokens` |

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
3. ~~Notifications always private~~ **decided 21 Oct: every notification is written custom** (§5.1), shown through a service extension, and hidden on the lock screen with iOS's Show Previews setting.
4. **The widget's "talk"** opens the composer ready to type (lean), not listening.
5. **What the share sheet accepts:** links and text (lean); images and files later.
6. **Quiet hours** are fixed at 21:00–08:00 in v1 (lean).
7. **When two notifications fall on one day**, the lower one is dropped (lean).
8. **Copy:** the "saved" line when the brief is off ("it's in your journal."), and the one fixed placeholder for hidden previews ("retrospect has something for you."). Notification copy itself is written per push (§5.5).

## 13. Fixtures

`fixtures/07/`:
- **Shares:** `share.preview.request.json`, `share.preview.response.json`, `share.preview.video.json`, `share.preview.unreadable.json`, `share.preview.minimal.json`, `share.create.request.json`, `share.create.request.text.json`, `share.create.response.json`.
- **Notification preferences:** `notifications.preferences.json`, `notifications.preferences.put.request.json`.
- **Push payloads:** `push.brief.ready.json`, `push.brief.ready.noaudio.json`, `push.episode.ready.json`, `push.question.json`, `push.refresh.json`, `push.unknown-kind.json`.
- **Notification text:** `notification.content.json`, `notification.write.agent.json` (the writer's reply), `notifications.token.json`, `error.notification.not_found.json`.
- **Widget snapshot:** `widget.snapshot.ready.json`, `widget.snapshot.playing.json`, `widget.snapshot.quiet.json`, `widget.snapshot.making.json`, `widget.snapshot.off-episode.json`, `widget.snapshot.signed-out.json`, `widget.snapshot.unknown-state.json`.
- **Share inbox:** `inbox.item.json`, `inbox.item.sent.json`.
- **Errors:** `error.share.invalid_url.json`, `error.share.goal_not_found.json`, `error.share.idempotency_mismatch.json`, `error.preview.spend_limited.json`.

Every value is invented (`example.com`, invented goals). The backend validates the door and push fixtures against its zod schemas. The app decodes all of them, including the phone-only ones, in both the app's tests and the extension's tests.
