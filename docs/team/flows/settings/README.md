# Settings and account: the plan, every piece to PR level

Area 06. Contract: [../../contracts/06-settings.md](../../contracts/06-settings.md). Cards: [backend.md](./backend.md) (24 PRs), [platform.md](./platform.md) (16 PRs), [views.md](./views.md) (28 PRs). Tree for the build board: [tree.json](./tree.json). Written 21 Oct by the settings planner, to the journal's standard (contract 02, P09, C30, PL3.1, phase-1-journal).

**Not in Beta 1** ([first-ship.md](../../first-ship.md)): settings stay on the current screens until phase 6. One slice is **required before the App Store**: account deletion in the app with the Apple revoke, restore purchases and subscription management. §6 shows it as its own lane (the "App Store minimum") so it can ship before the rest of phase 6 (founder question Q11).

**Paper:** the view cards carry values read from Paper on 21 Oct (read-only, `get_jsx` / `get_computed_styles` on ST-1…ST-9 and AC-2, plus the dark board). Paper wins where it disagrees with the docs; each card lists the disagreements under **Paper vs docs**, and §8 turns the product-level ones into questions (Q15, Q16). Not drawn in Paper: your invites (PI3), add a source (P25a), where it's processed (P27a), the danger dialogs' copy and the deleting state (C50), the time picker (C43).

---

## 1. The big picture

**What this area is, for the person:** "the place where I decide how Retro works for me, and where I can always take my data and leave." Settings is reached from your picture on the You tab, and from the foot of the journal drawer.

Five promises it keeps, in the person's words:
1. **"I choose when Retro talks to me."** The daily brief is off until I turn it on, at a time I pick (D7). The voice and its speed are mine.
2. **"I choose how much Retro reads."** I can stop background reading with one switch (ambient), disconnect any source, and delete what one source gave it.
3. **"I choose how straight it is with me."** Four levels in plain words, or I let it decide, and then it tells me why it picked what it picked.
4. **"I can see how it's adjusting."** What it's learned about which questions I answer, in one sentence, with no invented lesson when it's too early.
5. **"I can take everything and go."** Download my data, delete my data and start again, or delete my account, and the subscription is never a trap.

Product principles that bite here:
- **When uncertain, withhold.** ST-8 says "too early" rather than inventing a pattern; "picked by retro" only shows a reason the brain can stand behind (BE6.1b builds it from real signals, no model).
- **No invented data.** Empty and day-one states are shapes and plain lines (C39). Prices are always Apple's localized price, never typed (D6). A source's "last read" is a real time or nothing.
- **Honesty in the product.** The deletion dialog says exactly what goes and that it can't be undone, and that Apple keeps billing until you cancel (README §9). "Where it's processed" may only say what's verified (Q5).
- **One lit object per screen.** Settings pages have **none** (handoff), except AC-2's "send, then sign out" (the sheet's one lit action). Danger rows are alone and last, and the destructive glow lives only inside the dialog.
- **Small screens adapt, never shrink.** SE: 20 margins, groups 32 → 24, sublines that repeat a title drop (each page card says which).
- **Privacy.** No setting value, source name, invite code or link is logged; counts and enum cases only (testing.md §2).

## 2. Flows: every path through the area

Entry points: the picture on YO-1 (`1G5Y-0`, opens ST-1); the journal drawer foot "settings" (JR-3); deep links `retrospect://settings`, `…/settings/brief`, `…/settings/sources/<id>`, `…/settings/account`, `…/settings/invites` (PL5.2s); the OAuth return `retrospect://integration-connected?provider=…&status=…` (lands on ST-4 for that source); the "your data is ready" push (lands on ST-5); a `session_revoked` anywhere (lands on AC-1, contract 00).

| # | Flow | Happy path | Failures and edges | First time vs the hundredth |
|---|---|---|---|---|
| F1 | **Daily brief** (ST-2) | ST-1 "daily brief · off" → ST-2 → switch on → (iOS asks for notifications, Q9) → time ↕ → 8:30 → length "standard" → back; ST-1 reads "8:30" | write fails → the switch snaps back, subline says why; offline → rows disabled "needs a connection"; time sheet dismissed → nothing changes; brief off → time and length disabled with "turn the brief on first" (never hidden) | first: off, time 8:00, "play today's" hidden (nothing made yet). Hundredth: on, "play today's · 4 min" plays the journal's brief (JR-2) |
| F2 | **Voice and listening** (ST-7) | voice "warm" ↕ → steady; sample plays 9 s; speed ↕ 1.25× (applies to the player at once) | sample fails to load → the pill says "couldn't play" once; offline → voice disabled, speed still works (it's local) | — |
| F3 | **How straight / what i've learned** (ST-6, ST-8) | ST-6: tap "gentle questions" → tick moves, "picked by retro" note goes; "let it decide" → note returns with the why | write fails → tick snaps back; ST-8 learning off → "i'm not adjusting my questions yet." | first: picked, "the starting point: just what happened" in plain words; ST-8 too early |
| F4 | **Sources** (ST-3 → ST-4) | ST-3 lists connected first → tap calendar → ST-4 reads · helps me see · last read 2 min ago · sync now → disconnect… (dialog) → back to ST-3 as not connected | needs you → "reconnect" pill → browser → back to ST-4 syncing; delete what it read… → dialog → "deleting" → gone; grant revoke fails → still disconnected (counted); ambient off → one line on ST-3 | first: nothing connected, "add a source ›" leads; hundredth: 4 connected, one needs you |
| F4b | **Add a source / import a file** (P25a, file picker) | "add a source ›" → the catalogue (P25a) → connect → browser or iOS permission → connected | OAuth cancelled → nothing changes; import too big (> 1 GB) → refused before upload; upload interrupted → resumes or says "didn't finish, try again" | — |
| F5 | **Privacy** (ST-5) | read in the background on/off; where it's processed › (P27a); download my data → "getting it ready" → push → "save" (share sheet with the zip); delete my data… → dialog → onboarding again | export rate-limited → "once a day; try tomorrow"; export expired → "download again"; master switch off → "paused for everyone right now" (Q6); delete-data fails → dialog stays with the reason | first export vs repeat: the latest export's state is shown |
| F6 | **Account** (ST-9 → AC-2) | your plan · manage subscription ↗ (Apple's sheet) · restore purchases → "restored" · sign out → AC-2 → "send, then sign out" → AC-1 later | restore finds nothing → "nothing to restore on this apple id"; offline → manage and restore disabled; unsent entries that can't send (offline) → AC-2 offers "sign out anyway" after a clear warning (C48) | not a member → "become a member ›" (Q13) |
| F6b | **Delete account** (ST-9) | delete account… → dialog (with the billing line when renewing) → Apple sheet if needed (Q8) → "deleting…" → 202 → phone erased → splash | Apple sheet cancelled → nothing deleted; offline → disabled "needs a connection"; app killed after sending → next launch finishes the local erase (PL3.7g marker); 202 lost → retry meets `session_revoked` → treated as done | — |
| F8 | **Notifications** (P23a) | ST-1 "notifications" → per-kind switches (today's brief, a new episode, a question from retro) → "hide the words" on the lock screen | iOS has notifications off → a row that opens iOS settings; write fails → snaps back | first: every kind on, words shown (defaults); every notification is written for the person by the outside plan (founder, 21 Oct) |
| F7 | **Your invites** (PI3) | ST-1 "invite friends · 2 left" → PI3 → three rows: used by sam · unused (share) · unused (share) → share sheet with link + "works once" line | none left → rows all used, no share; offline → cached list, share disabled (the link is cached; sharing it offline is fine, lean allow) | just let in: three unused |

Offline everywhere: settings read from the cache (PL2.4) and show C39.4's offline line under the bar; every network write is disabled with "needs a connection" (settings-row offline state). Speed is the only setting that works offline (it's applied on the phone and synced later).

## 3. Pages (each card in views.md)

| Page | Paper | States (T02 `-State`) | Lit object |
|---|---|---|---|
| P23 ST-1 settings | `1GGA-0` (dark `2H5Q`) | full, briefOff, sourceNeedsYou, offline, loading, error | none |
| P23a notifications | **not drawn** (Q17) | notificationsOn, wordsHidden, iosDenied, iosUndetermined, briefOff, offline | none |
| P24 ST-2 daily brief | `1GJK-0` (dark `2H90`) | on, off (dependents disabled), dayOne (no play today's), timeSheet, writeFailed, offline | none |
| P25 ST-3 sources | `1GL7-0` (dark `2HAN`) | full, none, syncing, needsYou, ambientOff, offline, loading, error | none |
| P25a add a source | **not drawn** (Q12) | full, connecting, failed | none |
| P26 ST-4 a source | `1GNV-0` (dark `2HDB`) | connected, syncing, needsYou, onPhone, disconnectDialog, deleteDialog, deleting, offline | none |
| P27 ST-5 privacy | `1GP6-0` (dark `2HEM`) | full, ambientOff, pausedForEveryone, exportPreparing, exportReady, exportExpired, exportLimited, deleteDataDialog, offline | none |
| P27a where it's processed | **not drawn** (Q5) | full | none |
| P28 ST-6 how straight | `1GQM-0` (dark `2HG2`) | picked, yours, writeFailed, offline | none |
| P29 ST-7 voice | `1GS3-0` (dark `2HHJ`) | full, samplePlaying, sampleFailed, offline | none |
| P30 ST-8 what i've learned | `1GTG-0` (dark `2HIW`) | learning, tooEarly, off, error | none |
| P31 ST-9 account | `1GU5-0` (dark `2HJL`) | member, trial, cancelled, billingIssue, notMember, restoring, restored, nothingToRestore, deleteDialog, deleting, offline | none |
| P33 AC-2 signing out | `1GVP-0`, sheet `1GVR-0` (dark `2L1K-0`) | nothingWaiting, unsent, sending, offlineUnsent | "send, then sign out" |
| PI3 your invites | **not drawn** (invite board `2H3N-0`, another session) | three, someUsed, allUsed, offline, loading | none |

## 4. Components

**Reused, built:** `RSettingsRow` + `RSettingsGroup` (C09, merged #47), `RSegmented` (C08, #51), `RButton` (#43), `RSectionLabel`, `RHairline`, `RIconWell`, `RSpinner`, `RSourceStatus`, `RStatusDot`.
**Reused, open or planned:** `RSwitch` (C07, #50), `RPill` (C05, #45), `RSourceRow` (C10, #52), `RToast` (C21, #48), C17 settings bar, C19.1 sheet host, C19.2 dialog, C20 menu (value rows ↕), C39 states.
**New** (views.md): C41 settings page frame · C42.1 action row · C42.2 row states (loading, offline, disabled, error) · C43 time sheet · C44 voice sample pill · C45 "picked by retro" note · C46 learned block · C47 export row · C48 sign-out sheet · C49 invite row and share · C50.1 danger dialogs · C50.2 deleting and goodbye.

## 5. The full tree

Area › flow › page › component › sub-component › PR (id · size · needs). Backend and Platform PRs hang from the flow they serve.

```
settings (area 06, contract 06) ─ flow test T06 (M · all pages)
├── foundations
│   ├── PL3.7.0 Flows/Settings.swift, the protocol (integrator) · S · contract 06
│   ├── UI6.0 SampleSettingsData + scenarios + ledger · M · PL3.7.0, T02
│   ├── C41 settings page frame · M · C17, C39, RSettingsGroup
│   ├── C42 settings row, the missing parts
│   │   ├── C42.1 action row (raised pill trailing, pending) · S · #45
│   │   └── C42.2 row states: loading, offline, disabled with reason, error · S · C42.1
│   ├── PL3.7i Platform.LocalReset (one erase routine) · S · PL2.1, PL1.3
│   ├── PL5.2s settings deep links · S · PL5.2
│   ├── BE6.1e GET /v2/settings · M · BE6.1a, BE6.1b, BE6.1d
│   ├── PL3.7a LiveSettingsData: reads and writes · M · PL3.7.0, BE6.1e–h, BE6.2a
│   └── W6 settings wiring (integrator) · S · every P and PL3.7x
├── hub
│   └── P23 ST-1 settings · S · C41, UI6.0
├── notifications (F8)
│   ├── P23a notifications · S · C41, #50, drawing (Q17)
│   ├── BE6.7 notification settings door + storage · S · BE6.1e, BE2.6
│   └── PL3.7j notification settings (live) · S · PL3.7a, PL5.1, BE6.7
├── brief (F1)
│   ├── P24 ST-2 daily brief · M · C41, C42.1, C43, #50, #51
│   │   └── C43 time sheet · S · C19.1
│   ├── BE6.1a agent: brief + voice settings columns and routes · M · —
│   ├── BE6.2a PATCH /v2/settings/brief · S · BE6.1a, BE0.1
│   ├── BE6.2b agent: per-minute local brief scheduler · M · BE6.1a
│   ├── BE6.2c agent: brief length in the writer · S · BE6.1a, Q1
│   └── PL5.4 notification permission when the brief turns on · S · PL5.1
├── voice (F2)
│   ├── P29 ST-7 voice · S · C41, C44
│   │   └── C44 voice sample pill · S · #45, UI3.0
│   └── BE6.1g PATCH /v2/settings/voice + samples · S · BE6.1a
├── straight and learned (F3)
│   ├── P28 ST-6 how straight · S · C41, C45
│   │   └── C45 "picked by retro" note · S · —
│   ├── P30 ST-8 what i've learned · S · C41, C46
│   │   └── C46 learned block · S · C39.2
│   ├── BE6.1b agent: "picked by retro" in plain words · S · —
│   ├── BE6.1c agent: what i've learned in sentences · M · —
│   ├── BE6.1f PUT ambient, PUT straightness · S · BE6.1b, BE6.1d
│   └── BE6.1h GET /v2/settings/learned · S · BE6.1c
├── sources (F4, F4b)
│   ├── P25 ST-3 sources · M · C41, #52
│   ├── P25a add a source · S · P25, Q12 drawing
│   ├── P26 ST-4 a source · S · C41, C42.1, C50.1
│   ├── BE6.5a agent: revoke one source's grant · S · —
│   ├── BE6.5b GET /v2/sources (+ copy in the catalogue) · M · BE0.1
│   ├── BE6.5c sync, disconnect, delete what it read · M · BE6.5a, BE6.5b
│   ├── BE6.5d connect, connected, imports · M · BE6.5b
│   ├── PL3.7b1 sources: list and actions · M · PL3.7a, BE6.5b, BE6.5c
│   └── PL3.7b2 connecting, reconnecting, importing · M · PL3.7b1, BE6.5d
├── privacy (F5)
│   ├── P27 ST-5 privacy · M · C41, C47, C50.1
│   │   └── C47 export row · S · C42.1
│   ├── P27a where it's processed · S · Q5
│   ├── BE6.1d agent: the master switch as a dial · S · —
│   ├── BE6.1i dashboard: the master switch · S · BE6.1d
│   ├── BE6.3a agent: export builder · M · BEA.2
│   ├── BE6.3b agent: export lifecycle and the deletion sweep · S · BE6.3a, BE0.6
│   ├── BE6.3c export doors · M · BE6.3a
│   ├── BE6.6c agent: delete my data keeps your choices · S · BE0.8
│   ├── PL3.7c export · S · PL3.7a, BE6.3c
│   └── PL3.7f delete my data · S · PL3.7i, BE0.8
├── account (F6, F6b)  ← the App Store minimum
│   ├── P31 ST-9 account · M · C41, C42.1, C50.1, C50.2
│   ├── P33 AC-2 signing out · S · C48
│   │   └── C48 sign-out sheet · M · C19.1, RSpinner
│   ├── C50 dangerous choices
│   │   ├── C50.1 danger dialogs (four) · S · C19.2
│   │   └── C50.2 deleting and goodbye · S · C50.1
│   ├── BE6.4 GET /v2/account · S · BE2.8, BE0.5
│   ├── BE6.6a fresh Apple code at deletion · S · BE0.7
│   ├── BE6.6b deletion answers 202 and resumes · S · BE0.7
│   ├── PL6.4 manage and restore · M · PL6.1, PL6.2
│   ├── PL3.7d account and plan · S · PL6.4, BE6.4
│   ├── PL3.7e sign out with unsent entries · S · PL1.5, PL2.2, PL3.7i
│   └── PL3.7g delete account · M · PL3.7i, PL3.7d, BE6.6a, BE6.6b
└── invites (F7)
    ├── PI3 your invites · M · C41, C49, Paper drawing
    │   └── C49 invite row and share · M · #45
    └── PL3.7h your invites · S · PL1.7c
```

## 6. The queue, in build order

Each PR needs only merged work. Two lanes run at once (the backend engineer and the app engineer, README §2). Phase 6 begins after G5; the **App Store lane** can be pulled forward on the founder's word (Q11), right after payments (PL6.1, PL6.2, BE2.8) land in phase 2.

**App Store lane (A):**

| # | Backend | App |
|---|---|---|
| A1 | BE0.5, BE0.6, BE0.7, BE0.13 (phase-0 cards, if not merged) | PL6.4 manage and restore |
| A2 | BE6.6a fresh Apple code | PL3.7i LocalReset |
| A3 | BE6.6b 202 and resume | C50.1 dialogs → C50.2 deleting |
| A4 | BE6.4 GET /v2/account | C48 sign-out sheet |
| A5 | — | PL3.7.0 (integrator) → UI6.0 (account scenarios first) → C41 → C42.1 |
| A6 | — | PL3.7d → PL3.7e → PL3.7g |
| A7 | — | P31 ST-9 → P33 AC-2 → W6 (account part) → T06 (account part) |

**Phase 6 lane (the rest):**

| # | Backend (agent first, then doors) | App |
|---|---|---|
| 1 | BE6.1a settings columns and routes | C42.2 row states |
| 2 | BE6.1b plain why · BE6.1d master dial | C43 time sheet · C45 note · C46 learned block |
| 3 | BE6.1e GET /v2/settings · BE6.2a brief door | C44 sample pill · C47 export row |
| 4 | BE6.1f, BE6.1g, BE6.1h · BE6.1c learned sentences | P23 ST-1 · P24 ST-2 · P28 ST-6 |
| 5 | BE6.2b scheduler · BE6.1i dashboard switch | P29 ST-7 · P30 ST-8 · PL5.2s deep links |
| 6 | BE6.5a revoke · BE6.5b sources | PL3.7a live reads and writes · PL5.4 permission |
| 7 | BE6.5c actions · BE6.5d connect and imports | P25 ST-3 · P26 ST-4 · PL3.7b1 |
| 8 | BE6.3a export builder · BE6.3b lifecycle | P27 ST-5 · P27a (once Q5 is answered) · PL3.7b2 |
| 9 | BE6.3c export doors · BE6.6c delete-data keeps choices | PL3.7c · PL3.7f · P25a (once drawn) |
| 10 | BE6.2c length (Q1) · BE6.7 notification settings | C49 → PI3 (once drawn) · PL3.7h · P23a (once drawn) · PL3.7j |
| 11 | — | W6 wiring (integrator) → T06 full → ship gate G6 |

Cross-side dependencies to watch: BE6.5d is the same connect door ON-6 uses (contract 01); BE6.2b changes what "today's brief" means for the journal (contract 02's `date` becomes the local day); PL3.7a needs PL2.4's cached reads; PL3.7e needs PL2.2's outbox; PL6.4 needs the founder's RevenueCat keys.

## 7. Risks

| Risk | Answer |
|---|---|
| Account deletion half-runs (app killed, network gone, brain timeout) | BE6.6b: the door locks the account and answers 202, the server resumes from the `deletions` log; PL3.7g writes a local "deleting" marker before sending and finishes the local erase on next launch |
| Grandfathered Apple users have no stored Apple token, so the revoke silently can't happen | BE6.6a + `deletion.needsAppleConfirmation`: ask Apple for a fresh code only for them (Q8) |
| The `deletions` log cascades away with the user row, so a resume has nothing to resume from | BE6.6b moves it off the FK (user id kept as a plain column) |
| Disconnect leaves the provider's grant alive (today it only flips a status) | BE6.5a revokes per connection; the door reports `grant` |
| Deleting data or the account leaves the export zip or brief audio in storage | BE6.3b adds `exports/` and `briefs/` to BE0.6's sweep, with a two-user test |
| The old app's own files (`Documents/RetrospectData`, `podcasts.json`) survive "delete account" on the phone | PL3.7i erases them too (it's the one erase routine) |
| A stale "how straight" or brief time after a write fails | every write is optimistic with snap-back (switch rule), and the response replaces the cache |
| "Where it's processed" says something untrue | Q5: every line verified by the integrator from Render and Supabase settings before P27a is built |
| Brief time changes the meaning of "today's brief" for the journal | BE6.2b ships behind the existing `ENABLE_DAILY_BRIEF` and is tested against contract 02's fixtures |
| App Review rejects for a missing restore or manage link | P31 has both, plus the paywall's; T06 tests both (sandbox) |
| Two open PRs (#13 backend, #14 app) build "sign out everywhere" and a different deletion | they predate the plan (19 Oct) and contradict D-"sign out everywhere is v2"; the integrator closes them, keeping any useful tests (shared-file request) |

## 8. Questions for the founder (work goes ahead on the lean)

| # | Question | Options | Lean | What changes |
|---|---|---|---|---|
| Q1 | ST-2 draws **length** (short · standard · long). The brain has no length today. | A build it (about 2, 4 and 6 minutes) · B hide the row | **A** | A: BE6.2c (S) and a column; long briefs cost about 50% more audio. B: the row and BE6.2c are dropped |
| Q2 | ST-7 draws **talk or read** ("talk: retro speaks its replies"). In v1 Retro doesn't reply (canned acknowledgement). | A hide until the v2 conversation · B keep it, meaning "read the acknowledgement aloud" | **A** | A: no row, no field. B: a `replyMode` field and a speaking acknowledgement (new work) |
| Q3 | The three voices' names | A warm · steady · bright (thoughtful friend, wise mentor, energetic host) · B your words | **A** | only copy and the `personas` list |
| Q4 | Speed choices | A 0.8× · 1× · 1.25× · 1.5×, applied on the phone, remembered on the server · B add 2× | **A** | the enum in §2 |
| Q5 | ST-5 says "where it's processed · europe". Our servers' regions aren't verified (Render's default is Oregon). | A a plain page listing each place and provider, every line verified before it's built, plus "privacy policy ↗" (App Review asks for an in-app link) · B drop the row | **A** | A: P27a needs a Paper drawing and the integrator's verification. B: one row less |
| Q6 | When your master ambient switch is off, what does a person see? | A their switch keeps their choice; the subline says "paused for everyone right now" · B nothing (the switch looks on) | **A** (honest) | the `pausedForEveryone` field is shown or ignored |
| Q7 | Where "your invites" lives, and its drawing | A a row on ST-1 in the "you" group, "invite friends · 2 left", pushing PI3 · B on YO-1 | **A** | PI3 and C49 need a Paper drawing either way (the invite board is another session's) |
| Q8 | Deleting an account that signed in with Apple before we stored Apple's token: confirm with Apple? | A ask Apple only when we hold no token · B always ask · C never (revoke may not happen) | **A** | A/B: Apple's sheet appears in the deletion flow; C fails Apple's TN3194 for old accounts |
| Q9 | Turning the brief on: ask iOS for notification permission at that moment (the brief notification itself is written and sent by the outside plan, founder 21 Oct) | A yes, ask then · B only from the notifications page | **A** | PL5.4 exists or the ask moves to P23a |
| Q10 | "Delete my data" (keep the account): keep your choices? | A keep choices (brief, ambient, a stated straightness, voice), drop everything learned · B reset everything | **A** | BE6.6c changes BE0.8's reset |
| Q11 | Ship the App Store minimum (ST-9: plan, manage, restore, sign out, delete account) ahead of the rest of settings | A yes, right after payments, before submission · B with the rest in phase 6 | **A** | the A lane in §6 moves forward; the old settings screen stays for everything else until G6 |
| Q12 | "add a source ›" on ST-3 isn't drawn | A a pushed list of every source (same rows as ST-3, "coming soon" disabled), drawn in Paper · B reuse ON-6's "see all apps" page | **B if first run draws it, else A** | P25a's drawing |
| Q13 | ST-9 for someone who isn't a member (grandfathered, or a lapsed trial) | A "your plan · none" + "become a member ›" to the paywall · B hide the plan group | **A** | P31 state `notMember` |
| Q15 | ST-6 (Paper) draws "picked by retro … choose another and yours wins." but no way back to "let it decide" once you've chosen. The brain supports handing it back. | A a "let it decide" text button when the choice is yours · B no way back | **A** | C45 gains the button; the integrator draws it in Paper |
| Q16 | ST-1 (Paper) puts ↕ (a menu in place) on voice, talk or read and how straight, but ST-6 and ST-7 are full pages (the why, the sample, speed) | A › to the pages, value shown · B ↕ menus on ST-1 and drop ST-6/ST-7 · C both: ↕ chooses, the page is reached another way | **A** | P23's trailing glyphs; ST-6/ST-7 reachable |
| Q17 | "hide the words on the lock screen" (founder, 21 Oct): what does a notification show when it's on? iOS can't hide only on the lock screen for one app's own choice; only the person's iOS "show previews" setting can | A a private notification: a title written for the moment with nothing personal in it, the words only in the app (the words never reach Apple's servers) · B rely on iOS: set our categories to hide previews and send the person to iOS's "show previews: when unlocked" | **A**, plus B's category setting so iOS's own choice also works | contract 07's writer gains a `private` mode; P23a's subline copy; the page needs a drawing |
| Q14 | Export delivery | A a zip you save from the share sheet in the app, with a "ready" notification written for the person (outside plan) · B emailed link | **A** (no email in the product) | BE6.3c and P27 |

**Paper fixes to queue (integrator, not questions):** ST-9's drawn price $239.99 (D6 says $199.99; the app shows StoreKit's anyway); ST-3's "add a source" subline names health, already connected; the AC-2 sheet fill (canvas → raised, already queued); icon wells drawn only on ST-1 and ST-3 against the 20 Oct note DUA-0 (the build follows the approved phones); ST-1's hidden leftover layers.

**Not questions, but needed from the founder:** the source copy ("reads", "helps me see", purpose) for each catalogue entry (BE6.5b); the invite share line (lean in contract 06 §9); the three voice samples recorded once (BE6.1g); a Paper fix on ST-1's copy (paper-inventory finding 7: the "privacy, account" group reads "listening", "warm", "talk"); Paper drawings for PI3, P25a and P27a.

## 9. Checks on the phase-0 deletion cards (BE0.5–BE0.8, BE0.13)

Read in `docs/team/backend/phase-0.md`; not rewritten. What they cover, and what this area adds:

| Card | Covers | Gap found | Answer (here) |
|---|---|---|---|
| BE0.5 Apple refresh token and revocation | exchange at sign-in, encrypted storage, `revoke()` | accounts that signed in before it ships have no token; the flag `APPLE_REVOKE_ENABLED` may still be off at deletion | BE6.6a (fresh code at deletion, `needsAppleConfirmation`) |
| BE0.6 the brain's half | grants, four buckets, cascade test | doesn't list `exports/` (BE6.3) or `briefs/` (only "after BE1.3b") | BE6.3b extends the sweep with a two-user test |
| BE0.7 deletion door | order of steps, resume from a log, RevenueCat delete, "deleting doesn't cancel the subscription; the app says so" | no migration number for `deletions`; if it references `users` with cascade, the log vanishes with the row; synchronous up to 120 s; a lost response leaves the app unsure | BE6.6b (202 + background resume, log outlives the user); PL3.7g treats `session_revoked` after a sent delete as done |
| BE0.8 delete my data | content tables, files, grants, back to onboarding | resets `user_preferences`, which also holds the person's stated straightness | BE6.6c (keep choices, drop learned) |
| BE0.13 Apple notifications | consent-revoked, account-delete, email flags | fine; `account-delete` should go through BE6.6b's async path | noted in BE6.6b |

## 10. App Store requirements: where each is met

| Requirement | Where | Proof |
|---|---|---|
| Account deletion inside the app, the whole account, not a request (5.1.1(v)) | ST-9 "delete account…" → C50.1 dialog → BE0.7 + BE6.6a/b → C50.2 | T06 "deleting the account erases it on the server and the phone and shows the splash" (local staging) |
| Sign in with Apple tokens revoked at deletion (TN3194) | BE0.5 + BE6.6a | BE6.6a tests; staging run with a sandbox Apple id |
| Subscribers told billing continues until they cancel, with a way to manage it | C50.1 delete-account dialog when `plan.renews` | snapshot `deleteDialog.renewing` |
| Restore purchases (3.1.1) | ST-9 "restore purchases" (and the paywall) | T06 restore with a sandbox purchase |
| Manage subscription (3.1.2) | ST-9 "manage subscription ↗" → `AppStore.showManageSubscriptions` | T06 checks the sheet is requested (UI test, sandbox) |
| Prices shown are Apple's | ST-9 plan row reads StoreKit's localized price | PL6.4 test: no price literal in the module |
| Privacy policy reachable in the app (5.1.1(i)) | P27a "privacy policy ↗" (Q5) and the paywall links | P27a acceptance |

## 11. What I couldn't verify

- Paper was read once (21 Oct); node ids and values can move, so every views card starts by re-reading its nodes.
- Supabase and Render regions (Q5).
- Whether RevenueCat's subscriber delete is wired in BE2.8 (the card says "after BE2.8"; BE0.7 calls it).
- Whether first run's contract 01 will define its own connect door; contract 06 §4 proposes one shared door.
- The exact iOS 18.1 behaviour of `AppStore.showManageSubscriptions(in:)` in TestFlight (it shows in sandbox; PL6.4 tests the fallback URL path too).

## 12. Changes needed in shared files (for the integrator)

1. `contracts/README.md`: mark 06 as "draft for review" and link this file.
2. `contracts/00-platform.md` §2: add `apple_confirmation_required` (409).
3. `backend/phase-0.md`: BE0.7 needs a migration number for `deletions` (proposed backend `013_deletions.sql`, not cascading from `users`), and pointers to BE6.6a/b; BE0.6 pointer to BE6.3b; BE0.8 pointer to BE6.6c. Agent migrations proposed: `158_user_settings.sql` (BE6.1a), `159_ambient_dial.sql` (BE6.1d), `160_data_exports.sql` (BE6.3a).
4. `backend/later-phases.md` phase 6: replace the outline with a link here (BE6.1–BE6.4 keep their ids, split into lettered parts).
5. `plumbing/outline.md` PL3.7: link here (split a–i); add PL6.4, PL5.4, PL5.2s.
6. `ui/later.md` phase 6: link here; add P25a, P27a, C41–C50, UI6.0.
7. `contracts/01-first-run.md` (when written): use contract 06 §4's connect door for ON-6.
7b. Contract 07 / the outside plan: its sender must call BE6.7's `notificationSettingsFor(userId)` before writing or sending, honour the per-kind switches, and support a private notification when `hideWordsOnLockScreen` is on (Q17); it also owns the brief-ready and export-ready notifications this plan used to sketch (BE6.2d is dropped).
8. Close PRs #13 and #14 (sign out everywhere and an older deletion, both contradicting the 21 Oct decisions).
9. Paper: ST-1 copy fix; drawings for P23a (notifications), PI3, P25a, P27a; the sign-out sheet fill `background.raised` (queued already).
