# Outside the app, the signature moments, and retiring the old app

**Bottom line:**
- **Retro outside the app:** a share sheet that never loses what you save, a lock screen that plays your brief without showing its words unless you allow it, at most one private notification a day, and two widgets.
- **The thirteen signature moments:** each a single PR after its page, with frames, springs, haptics, Reduce Motion and a hitch budget written down.
- **Retiring the old app:** in an order where every step can be undone until the very last, which waits a release.

The work is **83 PRs**: 22 backend, 23 Platform and 38 views. **8 founder questions** have leans, and work goes ahead on the leans.

Files:
- the contract: [07-outside.md](../../contracts/07-outside.md), with [29 fixtures](../../contracts/fixtures/07/)
- the cards: [backend.md](./backend.md), [platform.md](./platform.md), [views.md](./views.md)
- the board's tree: [tree.json](./tree.json)

Contract 07, area `outside`. Status: **draft for the founder's review**, 21 Oct.

---

## 1. The big picture

**What this area is for the person, in their words:**
- "I'm reading something in Safari and want Retro to have it. Two taps, a reason if I feel like it, and I know it's in."
- "My brief keeps playing when I lock the phone, and I can pause it from my AirPods. Nobody glancing at my lock screen can read what it's about."
- "Retro tells me when my brief or my episode is ready, once, never at night, and never says what's in it on the lock screen."
- "On my home screen, one tap plays today's brief, and one tap lets me talk to Retro."
- "The app feels alive in a few places that matter, and it never makes me wait for an animation."
- "When the new app replaces the old one, nothing I wrote disappears, and nothing breaks if I'm on an old version."

**The product principles that apply:**
- **Privacy first.** No personal content in logs, push payloads, widgets on a locked screen, or the lock screen's Now Playing, unless the person chooses (§8 Q1). Push payloads carry localisation keys and ids only, so nothing personal passes through Apple.
- **Guesses are asked, never asserted.** The share sheet's "goes with" goal is a suggestion the person keeps or changes before saving, and it's stored as theirs only if they keep it. Retro's read of a link is about the link, never "you'll love this". The door drops any read that addresses the person.
- **When uncertain, withhold.** An unreadable page gets no read and no goal; a page about nothing they care about gets no goal (the brain's relevance rule: "when unsure, leave it out").
- **No invented data.** Widget previews and the gallery use obviously invented content, never the person's, and empty states say what's true ("being made", "a quiet day", "open retrospect to load today's brief").
- **One lit object per screen.** On the share sheet that's **save**. Widgets and the lock screen have none (system chrome).
- **The newest source wins.** Paper was read on 21 Oct; where it disagrees with the reference docs, Paper wins, and each difference is noted in the card (views.md).

## 2. The flows

### EX-1 · Share (P34)

**Ways in:** the system share sheet from any app that shares a web link or text (v1: links and text only; §8 Q5).

**The happy path:**
1. the sheet opens and the card shows the site at once
2. "retro's read" and "goes with" blur in (≤ 8 s)
3. the person optionally adds a why (typed, or spoken and recognised on the phone)
4. they tap **save** → "saved · it'll be in tomorrow's brief" → the sheet closes

**Failures:**

| What happens | What the person sees |
|---|---|
| the page can't be read | the card with the site only; saving still works |
| over the preview limit or spend cap | no read; saving still works |
| no network, an expired token, or the extension runs out of time | "it'll send next time you open retrospect": the item waits in the app-group inbox and the app's outbox sends it exactly once |
| signed out or waitlisted | "open retrospect to finish signing in", and nothing is saved |
| the suggested goal was deleted meanwhile | it's resent without the goal under a new key |
| the server refuses (too old, bad link) | the plain message, then close |

**Empty:** a text share shows the text, with no card art and no read.

**The first time versus the hundredth:** the same sheet. No onboarding inside the extension; the share target simply appears in the share sheet's apps.

### EX-2 · Lock screen (P35)

**Ways in:** any brief or episode playing when the phone locks.

**The happy path:** Now Playing shows the brief mesh, "tuesday's brief", "retrospect · part 2 of 3", and ↺15 ‖ 30↻ with scrubbing. It works the same from AirPods, Control Center, the Dynamic Island and CarPlay.

**Detail on (the person's choice):** the title becomes the part being spoken, as Paper draws it ("the fundraise article you sent").

**Failures:**
- stream drops → the player's own error state, and Now Playing shows paused
- sign-out → Now Playing is cleared at once
- interruptions (a call) → paused, resumed only on tap

**First versus hundredth:** no difference.

### EX-3 · Notifications (P36)

**Ways in:** push only.

| Kind | When | The tap opens |
|---|---|---|
| your brief is ready · 4 min | once your brief is made, only if the brief is on | JR-2; "play" opens it playing |
| this week's episode is here. | the weekly episode | PC-2 |
| one question for you, when you have a minute. | at most weekly, 18:00 local | YO-4 |
| check-in | contract 04 | GL-2 |
| export ready | contract 06 | settings |

**The rules:**
- at most one alert a day, priority episode › brief › question › check-in; the loser is dropped
- quiet hours 21:00–08:00 local hold an alert until 08:00, and a stale one is dropped
- each kind can be switched off

**Failures:**
- a deleted item → its page's gone state plus a toast
- an unknown kind (a newer server) → the app opens with nothing routed
- notifications denied → nothing is sent and nothing breaks; the widget and app still work

**First time:** permission is asked in first run (contract 01), not here.

### EX-4 · Widgets (P37)

**Ways in:** the widget gallery.

**Small:** "tell me… / talk to retro"; a tap opens the journal composer.

**Medium:** "today's brief · 4 min", the headline, then play and talk. Play runs in the background, without opening the app.

**States:** ready, playing, played, quiet, being made, brief off (first day: "turn on your daily brief in retrospect", then this week's episode), unavailable, signed out.

**Locked phone, detail off:** the system redacts the headline.

**Offline:** the widget shows the last snapshot, and play uses cached audio.

**First versus hundredth:** the medium widget is useful only once the brief is on, which is why "turn on your daily brief" shows once, then falls back to the episode.

### Signature moments (M01–M13)

Each is triggered inside its page in another area's flow (first run, journal, podcasts, goals, you). None blocks its page: the page ships with plain motion first, and the moment PR follows once its filmstrip is approved (views.md, "What a moment card is").

### Retiring the old app

**Ways in:** none for the person. It happens to them as updates.

**What they should notice:** nothing, except one case: a version so old that the server refuses it shows the force-update page ("time to update. … nothing is lost.").

**The order:**
1. **inventory** (X01)
2. **version floor** (X02a/b)
3. **tombstone, then delete old routes** (X07.0, X07a–g)
4. **per flow:** switch on for everyone → soak one TestFlight build → delete the old screens (X10a–g) → delete their services (X05a–c)
5. **phone data:** import confirmed → quarantine → wait a version and 30 days → delete (X06a–f)
6. **brain tables:** disconnect → back up → rename → wait 30 days → drop (X08a–c)
7. **final sweep** (X09)

## 3. The full tree

Shown as area › flow › page or capability › component › sub-component, then the PR id (size · side · needs). Integrator bytes (`INT7.x`) are dependencies, not tree nodes (platform.md).

```
outside
├── base (shared plumbing for extensions)
│   ├── PL7.2  the Outside folder ............................ M · platform · INT7.1, PL0.2
│   └── PL7.3  access-token mirror ........................... S · platform · PL7.2, PL1.3, PL1.5
├── EX-1 share
│   ├── P34 share to retrospect .............................. M · views · C41.1, C41.2, C42, PL7.5a, PL7.5b
│   │   ├── C41 share item card
│   │   │   ├── C41.1  card face ............................. S · views · T01, #42
│   │   │   └── C41.2  retro's read + goes with ............. S · views · C41.1, #45
│   │   └── C42  compact composer ............................ S · views · #54, #56
│   ├── share doors
│   │   ├── BE7.1a agent: read one link ...................... M · backend · BEA.2, BEA.4
│   │   ├── BE7.1b door: POST /v2/shares/preview .............. S · backend · BE0.1/2/12, BE7.1a
│   │   ├── BE7.2a agent: keep the person's goal ............. S · backend · BEA.2
│   │   └── BE7.2b door: POST /v2/shares ...................... M · backend · BE0.0/1/2/12, BE1.1, BE7.2a
│   └── share plumbing
│       ├── PL7.4  inbox + importer .......................... M · platform · PL7.2, PL2.1, PL2.2, BE7.2b, INT7.2
│       ├── PL7.5a extension: reading ........................ M · platform · INT7.1, PL7.2, PL7.3, BE7.1b
│       └── PL7.5b extension: saving ......................... M · platform · PL7.5a, PL7.4, BE7.2b
├── EX-2 lock screen
│   ├── P35 now playing ....................................... S · views · C40.4, PL7.6
│   │   └── C40.4 now-playing artwork ........................ S · views · T01, #42
│   └── now playing plumbing
│       ├── PL7.6  now playing + remote commands .............. M · platform · Media.Player (gap), PL7.10, C40.4
│       └── PL7.7  recording live activity ..................... S · platform · #56, PL3.1a, INT7.1
├── EX-3 notifications
│   ├── P36 copy and landings .................................. S · views · PL5.3, P10, P14, P21, P17
│   ├── notification doors
│   │   ├── BE7.3  preferences ................................. S · backend · BE0.1, BE0.2
│   │   ├── BE7.4  one a day, never at night .................. M · backend · BE2.6, BE2.7, BE7.3
│   │   ├── BE7.5  brief is ready .............................. S · backend · BE7.4, BE6.2, BE1.3b
│   │   ├── BE7.6  one question for you ........................ S · backend · BE7.4, BE1.4, YO-4
│   │   └── BE7.7  silent refresh .............................. S · backend · BE7.4
│   └── notification plumbing
│       ├── PL5.3  categories and taps ......................... M · platform · PL5.1, PL5.2, PL7.2, INT7.2
│       ├── PL7.9  background refresh .......................... S · platform · PL5.1, PL5.3, PL7.8a, PL3.1b, BE7.7
│       └── PL7.10 preferences + lock-screen choice ........... S · platform · PL1.1, PL2.4, BE7.3
├── EX-4 widgets
│   ├── P37 widgets ............................................ M · views · C40.1–3, PL7.8b
│   │   └── C40 widget views
│   │       ├── C40.1 small talk widget ......................... S · views · T01, S10, INT7.1
│   │       ├── C40.2 medium brief widget ....................... M · views · C40.1, #45, PL7.2
│   │       └── C40.3 brief widget states ....................... S · views · C40.2
│   └── widget data
│       ├── PL7.8a snapshot writer ............................. M · platform · PL7.2, PL3.1b, PL7.10
│       └── PL7.8b timeline + intents .......................... M · platform · PL7.8a, INT7.1, Media.Player
├── signature moments (each after its page, plus an approved filmstrip)
│   ├── M01 splash breathes ............ M · P01     ├── M08 bubble lifts (v1) ......... S · P09
│   ├── M02 listening glow ............. M · P02     ├── M09 player transport .......... M · P10 (then P14)
│   ├── M03 ink-sharpen ................ S · P02     ├── M10 tiles lag the scroll ...... M · P13
│   ├── M04 connect + meter ............ M · P04     ├── M11 goal card folds ........... M · P16
│   ├── M05 getting ready .............. M · P05     ├── M12 fact blooms ............... M · P18
│   ├── M06 tease → paywall ............ L · P06/P07 └── M13 questions type out ........ M · P02
│   └── M07 save tag ................... S · P07
├── retiring the old
│   ├── X01  retirement ledger .................................. S · platform
│   ├── version floor
│   │   ├── X02a report + switch ................................ S · backend · BE0.10, PL1.6, X02b
│   │   └── X02b force-update page .............................. S · views · PL1.6, Paper drawing
│   ├── old screens
│   │   ├── X03a–d experiments (video, Polaroid, iMessage, Home variants) . S each · views · G1, X01
│   │   ├── X10a–g each flow's old screens after G2, G1, G3, G4, G5, G6, G7 . M each · views
│   │   └── X04  old design system .............................. M · views · X10f
│   ├── old services: X05a–c ..................................... S each · platform
│   ├── old phone data: X06a–f .................................. S each · platform
│   ├── old backend: X07.0, X07a–g, X07h ....................... S each · backend
│   ├── legacy brain tables: X08a (M), X08b, X08c ............... backend
│   └── X09  final sweep ........................................ M · platform
└── proof
    └── T05d outside flow test ................................... M · views (+ integrator) · P34–P37, PL7.4, PL7.9
```

**Counts:**
- **Pages:** 5 (P34, P35, P36, P37, plus the force-update page X02b).
- **Components:** 3 (C40, C41, C42), with 7 sub-component PRs.
- **PRs:** **83**: 22 backend, 23 Platform, 38 views. The views count includes 13 moments, 13 retirement deletions and the flow test.

## 4. The queue, in build order

Phase 7 starts after G6, apart from the items marked "early".

| # | Backend | Platform | Views | Gate / note |
|---|---|---|---|---|
| 0 | — | X01 (early, any time) | — | inventory first |
| 1 | BE7.3, BE7.2a | INT7.1 (integrator) → PL7.2 | C40.1 | |
| 2 | BE7.2b, BE7.1a | PL7.3, PL7.10 | C40.2, C40.4 | |
| 3 | BE7.1b, BE7.4 | PL7.4, PL7.8a | C40.3, C41.1 | BE7.4 needs BE2.6 and BE2.7 (first run) |
| 4 | BE7.7, BE7.5 | PL7.8b, PL5.3 | C41.2, C42, P37 | BE7.5 needs BE6.2 (settings) |
| 5 | BE7.6 | PL7.5a, PL7.9 | P36 | BE7.6 needs YO-4 (you) |
| 6 | — | PL7.5b, PL7.6 (or earlier, Q8) | P34, P35 | PL7.6 needs a `Media.Player` owner |
| 7 | — | PL7.7 | T05d | → **G7** |
| retire | X02a, X07.0 (early, after BE0.10); then X07a–h and X08a–c on their clocks | X05, X06 on their gates; X09 last | X02b (after Paper); X03 (after G1); X10a–g (each after its gate); X04 (after G6) | every step has its rollback in its card |
| moments | — | — | M04 and M07 first (business), then M02, M03, M08, M13, then the rest | each after its page and its filmstrip |

**Cross-side dependencies to watch:**
- BE7.2b → PL7.4 / PL7.5b
- BE7.1b → PL7.5a
- BE7.3 → PL7.10
- BE7.7 → PL7.9
- PL7.8a → C40.2's real-data proof (P37)
- PL7.6 → P35
- X02b → X02a
- every X10 → its X05 / X06 / X07

## 5. Risks and how the plan answers them

| Risk | Answer |
|---|---|
| A shared link is lost when the extension is killed | The inbox file is written before any network; the app's importer is idempotent with a commit ledger; the server is idempotent on `clientEntryId` (PL7.4, PL7.5b) |
| Two processes refresh the same token and trigger reuse detection, signing the person out | Only the app refreshes. The extension gets a read-only mirror of the 15-minute access token, never the refresh token (PL7.3) |
| Personal words on a locked screen or through Apple | loc-key payloads, `privacySensitive` widgets, and Now Playing titles private by default (contract 07 §5–§6) |
| The widget installs only on iOS 26 (today's deployment target) | INT7.1 lowers it to 18.1 |
| Old local reminders keep firing after their code is deleted | X10g removes the pending requests in the same version (views.md) |
| Deleting the old store loses data on a phone whose import didn't confirm | X06a checks `LegacyImport.Report.confirmed` on that phone, quarantines rather than deletes, and X06f waits a version and 30 days |
| A route removal breaks a version still in use | the floor first (X02a), the tombstone for 14 days (X07.0, reversible by a switch), then deletion with X02a's report in the PR |
| A brain table drop can't be undone | back up, rename (reversible), wait 30 days, then drop (X08b, X08c) |
| A moment ships janky | the hitch budget is a merge gate: 0 hitches over 5 runs, ≤ 5 ms/s on the oldest phone |
| SSRF through on-demand link previews | the existing locked-down fetch, plus pinning the checked address (BE7.1a) |
| The preview spends money | the expensive bucket at 20 an hour, the spend cap checked before fetching, and a 10-minute cache |

## 6. Gaps I couldn't close

1. **Nobody owns the playback engine** (`Media.Player`: `AVPlayer`, audio session, interruptions, route changes). PL7.6 and PL7.8b's play intent need it. Lean: the integrator assigns it to PL3.1b's split, since the brief plays first.
2. **No filmstrips exist in Paper for M02–M13** (searched 21 Oct), and **no force-update drawing exists** (searched). Both are drawn by the integrator before their PRs.
3. **The oldest supported phone** (iPhone XS / XR class on iOS 18.1) isn't available for the hitch budget's second half. Until it is, moments are measured on the founder's phone and the simulator, and the PR says so.
4. **Contract 02 has no `headline` field** for the brief card, which the widget reuses (contract 07 §11.2).
5. **Paper dark twins** for EX-1–EX-4 (dark file `2KTI-0`) weren't read. Each page PR checks them.
6. The moment cards' host nodes belong to other areas and weren't re-read here. Each moment PR re-reads them first.
7. **Paper vs the references** (Paper wins, each noted in its card):
   - the widget background is raised, and the small widget's "talk to retro" is a label, not a pill
   - the medium widget's label is all mono
   - the share card's title is one line, "40 min video", and the goal pill has no "x" or guess outline
   - "add why" is a label above the field
   - EX-2's title is a part's words, which is why question 1 exists

## 7. Changes needed in shared files (not made here)

1. **Contract 00:** add `gone` (410) to the error list (X07.0).
2. **Contract 02:** add `"shared"` to `Entry.kind`, and name the brief's `headline` field.
3. **Contract 06:** host the four notification switches and the lock-screen detail choice (PL7.10 is the data).
4. **PL5.2:** add `.compose` and `.goal(id:)` destinations and their parser rows.
5. **PL1.3 / PL1.5:** call the token mirror on sign-in, refresh and sign-out (PL7.3).
6. **`plumbing/outline.md`:** PL5.3 is now a full card here, and X06's outline is superseded by X06a–f.
7. **`ui/later.md` phase 7:** C40 is now four sub-components, plus C41 and C42 (new), and the moment list's M07 should say 17% (D6, newest). Prices typed into Paper ("save 20%") are stale.
8. **`backend/later-phases.md` "Phase 7 · Retire the old":** superseded by backend.md here (X02a, X07.0, X07a–h, X08a–c). README §5 calls retirement "Phase 8".
9. **`first-ship.md`:** if the founder says yes to Q8, PL7.6 (Now Playing) moves into Beta 1.
10. **The integrator's files:** INT7.1 (targets, entitlements, the 18.1 widget target, the Outside folder membership, the widget's fonts) and INT7.2 (launch and push bridges in `RetrospectApp.swift`); `RLabPage` cases for M01–M13.

## 8. Founder questions

Each has lettered options, a lean, and what changes under each option. Work goes ahead on the lean.

**Q1 · Does the lock screen show what's in your brief?** Paper's EX-2 shows the spoken part's words as the title ("the fundraise article you sent"). The design rule says never private content on a locked screen unless you allow it.
- **A (lean):** private by default ("tuesday's brief · part 2 of 3"), with one setting, "show what's in your brief on the lock screen", that switches to the drawn look and also un-redacts the widget headline.
- **B:** always as drawn.
- **C:** never show the words.

Under B, PL7.10's setting and the widget's privacy marking go away. Under C, the setting goes away and EX-2 is redrawn.

**Q2 · A Live Activity for playback?** Now Playing already covers the lock screen, the Dynamic Island, AirPods and the car.
- **A (lean):** Now Playing only.
- **B:** also a Live Activity, which needs a Paper drawing, a widget view and a PL card (about 2 PRs).

**Q3 · Can notifications ever say what's in them?**
- **A (lean):** always private (one fixed line each).
- **B:** an opt-in "show details", which needs a notification service extension that fetches the words on the phone (+2 PRs, and more battery).

**Q4 · The widget's "talk":**
- **A (lean):** opens the journal composer ready to type, matching JR-1's "mic off until tapped" rule.
- **B:** opens listening straight away. This changes the `compose` destination to `compose?listen=1` and P09's interaction row 4.

**Q5 · What can you share in v1?**
- **A (lean):** links and text.
- **B:** also images, screenshots and files. That needs a new upload door, the media storage path and a bigger extension (+4–5 PRs).

**Q5b · "goes with" → change:**
- **A (lean):** offers only the suggested goal or "nothing" (v1).
- **B:** lists all your goals, which needs the goals list readable from the extension (contract 04) (+1 PR).

**Q6 · Quiet hours:**
- **A (lean):** fixed at 21:00–08:00.
- **B:** adjustable in settings (a contract 06 setter, +1 PR each side).

**Q7 · Two notifications due on one day:**
- **A (lean):** send the higher (episode › brief › question › check-in) and drop the other.
- **B:** carry the lower to the next day. Under B, BE7.4 gains a carry-over queue and staleness rules.

**Q8 · Lock-screen controls in Beta 1?** Briefs are audio in Beta 1. Without Now Playing, AirPods pause and lock-screen controls won't work for the brief.
- **A (lean):** move PL7.6 into Beta 1 (one PR, plus its playback-engine owner).
- **B:** wait for phase 7.

**Also asked elsewhere, with the leans used here:**
- **M01's opening:** the approved A constellation assembling; D stays an option (reference §F 38).
- **M07 under paywall option A:** no glide; the save tag rolls in, with the figure computed from StoreKit's prices.
- **The old video journal files:** offer "save your old videos to photos" once, then quarantine and delete (X06e).
- **The recording Live Activity's look:** unchanged until Paper draws it.
- **Copy needed:** the "saved" line when the brief is off ("it's in your journal."), the check-in and export notification lines, and the force-update words.
