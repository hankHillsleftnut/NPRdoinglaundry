# Settings and account · view cards (components, pages, the flow test)

The app engineer's view cards for area 06: the sample data (UI6.0), the new components (C41–C50, split into sub-component PRs where bigger than a day), the fourteen pages (P23–P31, P23a, P25a, P27a, P33, PI3) and the flow test (T06). Contract: [../../contracts/06-settings.md](../../contracts/06-settings.md); the screens read only `Flows.SettingsData` ([platform.md](./platform.md) PL3.7.0).

**Values are from Paper** (read 21 Oct with `get_jsx` / `get_computed_styles`, read-only, on the approved phones of "06 · everything · latest": ST-1 `1GGA-0`, ST-2 `1GJK-0`, ST-3 `1GL7-0`, ST-4 `1GNV-0`, ST-5 `1GP6-0`, ST-6 `1GQM-0`, ST-7 `1GS3-0`, ST-8 `1GTG-0`, ST-9 `1GU5-0`, AC-2 `1GVP-0`; dark board `2H5G-0` with ST-1…ST-9 `2H5Q/2H90/2HAN/2HDB/2HEM/2HG2/2HHJ/2HIW/2HJL`, AC-2 dark `2L8M-0`). Where Paper disagrees with the docs (handoff, build notes, the 20 Oct snapshots `design-system/hifi/p52_ST-*`), Paper wins and the card says so under **Paper vs docs**. Step 1 of every card is still: re-read its nodes in Paper before building (they may have moved since 21 Oct) and list any change in the PR. **Not drawn in Paper:** notifications (P23a), your invites (PI3, C49), add a source (P25a), where it's processed (P27a), the four danger dialogs' copy (C50.1: only the part 24 dialog shape and the entry-delete copy exist), deleting and goodbye (C50.2), ST-2's time picker (C43).

Shared settings values (Paper, every page), not repeated per card:
- **Settings bar** (`c:top-bar/settings/rest`): height `--spacing-size-nav-bar` 44, inline padding `--spacing-4` 16, gap `--spacing-2`; back = a 44 × 44 hit frame holding a 36 × 36 `--color-surface-wash` well, `--radius-control` (pill), with a 20pt chevron-left in `--color-icon-default`; title centred, Geist (`--font-label`) `--text-md` 14 medium, `--tracking-label` 0.01em, line height 18, `--color-text-secondary`; a 44 × 44 spacer on the right.
- **Body:** a column, `--spacing-8` 32 between groups, top padding `--spacing-4` 16 (ST-1: `--spacing-2` 8).
- **Row:** min height `--spacing-size-row-default` 56, padding 16 block / `--spacing-screen-margin` 24 inline, gap `--spacing-3` 12, centred; title SF Pro Text (`--font-text`) `--text-body` 17, `--tracking-card` −0.02em, `--leading-snug` 130%, `--color-text-primary`; subline `--font-text` `--text-md` 14, leading snug, `--color-text-secondary`, 2 (`--spacing-size-border-ring`) below the title. In Swift: `RSettingsRow` (C09) already matches.
- **Leading icon well** (32 × 32, `--radius-default` 10, `--color-surface-wash`, 20pt glyph `--color-icon-default`): **only on ST-1's rows and ST-3's "connected" rows**, plus every danger row. ST-2, ST-3's "add" group, ST-4–ST-7 and ST-9 rows have none.
- **Trailing:** › 16pt `--color-icon-muted`; value text `--text-md` `--color-text-secondary` then ↕ 16pt `--color-icon-muted`, 4 (`--spacing-1`) apart; ↗ (external) 16pt `--color-icon-muted`.
- **Hairline:** `--spacing-size-border-hairline` 0.5, `--color-border-strong`; inset from the leading edge to the text (24 on rows without a well; 24 + 32 + 12 = 68 beside wells: `RHairline(.afterIcon)`).
- **Section label:** Geist `--text-sm` 12 medium, `--tracking-label`, leading snug, `--color-text-label`, inside the screen margin, 4 (`--spacing-1`) above its rows (8, `--spacing-2`, above a non-row control such as the segmented control).
- **Raised pill** (secondary action): height 32, `--color-surface-secondary-action`, `--radius-control`; the raised stack (`--color-depth-stroke-inner-top` 0 1 0 inset, `--color-depth-stroke-inner` 0 0 0 1 inset, `--color-depth-stroke-outer` 0 0 0 0.5, `--color-depth-shadow-contact` 0 1 1.5, `--color-depth-shadow-cast` 0 4 6 −2); with an icon: padding 8 leading / 12 trailing, gap 4, 16pt icon `--color-icon-default`; label only: 12 each side; label Geist `--text-md` 14 medium, leading snug, `--color-text-primary`. In Swift: `RPill(.raised)` (#45) must match these.
- **Switch:** 51 × 31, **on = `--color-ink-default`** (ink, not blue; the token `control.switchOn` must resolve to ink: check #50), 2 padding, inset `--color-shadow-ink-action-1` 0 1 1; thumb 27 `--color-surface-thumb` with `--color-depth-stroke-outer` 0 −1 0 inset, `--color-shadow-thumb-1` 0 2 5, `--color-shadow-thumb-2` 0 1 1.
- **Danger rows:** a block of their own after the body, bottom padding `--spacing-10` 40; well `--color-status-danger-subtle` with a 20pt alert-circle in `--color-status-danger-text`; title `--color-status-danger-text`; subline `--color-text-secondary`, balanced. Alone and last, in the thumb zone, each opening a part 24 dialog (C19.2). `haptic.warning` fires only inside the dialog, on touch-down of the destructive button.
- **Paper vs docs (all pages):** (1) icon wells: the 20 Oct decision 02 note (`DUA-0`, build notes "every settings row leads with a 32 soft square") says every row; the approved 21 Oct phones put them only on ST-1 and ST-3 "connected". Newest wins: build Paper; list it for the integrator (Paper is consistent with screen rule "no leading icons on ordinary rows" in settings-row.md "Taken out"). (2) Paper uses a raw 68 for ST-1's hairline inset and token-built 24+32+12 on ST-3: same value, use `RHairline(.afterIcon)`. (3) Row title weight is `--font-weight-regular` on ST-3 and unset elsewhere: same value (regular).
- No lit object on any settings page (handoff). Press: the whole row, `surfaceSubtle` at once, back over `motionDurationPressOut` 240 ms; `haptic.select` when a setting applies; no haptic on navigation.
- Offline: C39.4's line under the bar; rows that need the network disabled with "needs a connection" (settings-row offline state).
- SE (375 × 667): 20 margins, groups 32 → 24, sublines that repeat their title are dropped (each page names which), type never shrinks.
- Dark: from the dark file `01M5EK9MGGWHX9H05V9MENVB6P` (ST-1…ST-9 board `2H5G-0`, AC-2 `2L1K-0`); no per-view dark code.

Order: UI6.0 → C41 → C42.1 → C42.2 → C50.1 → C50.2 → C48 → P31 → P33 (the App Store lane) → C43 → C45 → C46 → C44 → C47 → P23 → P23a → P24 → P28 → P29 → P30 → P25 → P26 → P27 → P27a → P25a → C49 → PI3 → T06.

---

### UI6.0 · SampleSettingsData and the ledger                                 size: M
Place in the tree: settings › foundations › the data seam › sample implementation
Repo · branch: NPRdoinglaundry · `ui/UI6.0-sample-settings-data`
Needs: PL3.7.0 (the protocol), T02      Unblocks: every settings component and page, T06

Why: every settings page can be built and tested in every state before anything is live; when the live data arrives, nothing on screen changes.

Inputs: contract 06 and every `fixtures/06/*.json`; contract 00's `invites-mine.json`; `Platform/Flows/Settings.swift`; UI1.0 (the journal's sample, the pattern).

Spec:
- `Features/Settings/Sample/SampleSettingsData.swift`: `@MainActor @Observable`, conforms to `Flows.SettingsData`, built with `(scenario: SettingsScenario, clock: any Clock<Duration>)`. Content decoded from the contract fixtures (so shapes can't drift); invented names only (rule 8).
- Scenarios (`SettingsScenario`, also T02's `-State` names, page by page):

| Scenario | What it gives |
|---|---|
| `full` | brief on 8:30 standard; ambient on; straightness picked (honest, with why); voice warm 1×; 4 sources (connected, syncing, needs you, not connected); member yearly; 2 of 3 invites unused |
| `dayOne` | brief off; nothing connected; learned too early; not a member; 3 invites unused |
| `briefOff` / `timeSheet` / `writeFailed` | ST-2 states; `writeFailed` makes the next write fail with `upstream_unavailable` after 300 ms |
| `ambientOff` / `pausedForEveryone` | ST-5 and ST-3 states |
| `exportPreparing` / `exportReady` / `exportExpired` / `exportLimited` | the export row |
| `syncing` / `needsYou` / `deleting` / `onPhone` | ST-3 / ST-4 states; `syncing` settles to connected after 3 s of the clock |
| `yours` / `picked` | ST-6 |
| `samplePlaying` / `sampleFailed` | ST-7 |
| `learning` / `tooEarly` / `learnedOff` | ST-8 |
| `member` / `trial` / `cancelled` / `billingIssue` / `notMember` / `restoring` / `restored` / `nothingToRestore` | ST-9 |
| `deleteDialog` / `deleteDialogRenewing` / `appleConfirm` / `deleting` / `deleted` | the delete-account path |
| `nothingWaiting` / `unsent` / `sending` / `offlineUnsent` | AC-2 |
| `someUsed` / `allUsed` | PI3 |
| `notificationsOn` / `wordsHidden` / `iosDenied` / `iosUndetermined` | P23a |
| `offline` / `loading` / `error` | every page (`loading` never resolves) |

- Ledger: a "settings" section in `docs/design/sample-data-ledger.md`, one row per sample value.

Steps: scenarios → content from fixtures → behaviours on the clock → T02 registration (`Features/Settings/SettingsScreens+Launcher.swift`) → ledger.

Acceptance: every scenario opens through T02 without a crash; every value matches a fixture; no real clock.

Tests (unit): "every scenario builds"; "sample content decodes from contract 06's fixtures"; "a failed write in writeFailed restores the old value"; "syncing settles after three seconds of the clock"; "loading never resolves in sixty simulated seconds".

Proof: test output; the ledger diff.

Watch out: nothing the protocol lacks; stop and ask.

---

### C41 · Settings page frame                                                 size: M
Place in the tree: settings › foundations › page frame
Repo · branch: NPRdoinglaundry · `ui/C41-settings-page`
Needs: C17 (settings bar), C39 (states), `RSettingsGroup` (#47), T01      Unblocks: every settings page

Why: every settings page feels the same: a quiet bar, calm groups of rows, and the same honest loading, offline and error states, so each page only adds what's different.

Inputs:
- Paper: settings page masters "c · settings page" `DS7-0` (page `DY3-0`) and `DF7-0` (page `DMF-0`); the settings bar `DY4-0`; ST-1 `1GGA-0` (bar instance `1GJ1-0`, label `1GJ0-0`, hairline `1GIC-0`)
- Spec: shared rules above; `loading-and-empty.md`; C39 card
- Code anchors: `RSettingsGroup` (`RSettingsRow.swift:202-220`), `RSectionLabel`, C17's `.settings(title:)`

Spec:
- `Features/Settings/Parts/RSettingsPage.swift`: `RSettingsPage<Content>(title:, state: PageState, content:)` where `PageState` is `.content`, `.loading(rows: Int)`, `.error(Backend.Failure, retry: () async -> Void)`, `.offline` (a line above the content, content still shown).
- Layout: C17 settings bar pinned; a `ScrollView` with `.scrollEdgeEffectStyle(.soft, for: .top)` on iOS 26 (the settings top edge is plain canvas per C17, so only the system soft edge, no blur band); content top `space4`; `RSettingsSection(label:)` = section label (Geist 12 medium `textLabel`, 4 above) + `RSettingsGroup(inset: .afterIcon)`; 32 between sections (24 on SE); bottom inset 32 + home indicator.
- Loading (after 400 ms only): skeleton rows in the row's shape (32 well + two bars), C39.1's shimmer.
- Error: C39.3 in the content's place ("couldn't load your settings." + "try again").
- Danger slot: `RSettingsPage.dangerZone { … }` places its rows last, after a 40 gap, so pages can't put danger rows anywhere else (a structural guarantee of settings-row rule 4).

State table:

| State | Look | Motion | Haptic |
|---|---|---|---|
| content | groups as Paper | first appear: none (settings arrive still) | — |
| loading (> 400 ms) | skeleton rows | shimmer `motionDurationShimmer` 1400; RM: pulse | — |
| error | C39.3 | blur-in 220 | `error` once |
| offline | C39.4 line under the bar; content kept | `.rBlurReplace` on the line | — |
| dark | canvas dark; hairlines white 8% | — | — |

Interaction table:

| Touch | Press | Haptic | Motion | Outcome | Reduce Motion |
|---|---|---|---|---|---|
| back | 36 wash 0.94 | none | system pop | previous page | system fade |
| edge swipe back | follows finger | none | interactive pop | previous page | same |
| try again (error) | 0.98 | none | content cross-fades 140 | reload | same |

Accessibility: the bar title is the page's header (read first); sections are headers; AX3: rows grow, trailing controls move under the text (the row handles it); Increase Contrast: hairlines 1pt `borderControl`.

Acceptance: a gallery page with three sections, a danger zone and each state matches `DY3-0` / `1GGA-0` in light, dark, AX3 and SE.

Tests: (snapshot) content, loading, error, offline × light, dark, ax3, SE; (unit) "danger rows always render after every section".

Proof: standard proof (screenshots beside Paper `DY3-0`, `1GGA-0`).

Watch out: paper-inventory finding 8: `top-bar/settings/rest` wraps the status bar on ST-1 only; build one bar for all pages and note the drift.

---

### C42.1 · Action row: a raised pill at the trailing edge                   size: S
Place in the tree: settings › foundations › settings row › action row
Repo · branch: NPRdoinglaundry · `ui/C42.1-action-row`
Needs: `RSettingsRow` (#47), `RPill` (#45)      Unblocks: P24 (play today's), P26 (sync now), P27 (export), P29 (sample), C47

Why: an action that happens right here (play, sync now, export, restore) looks like something you press, by depth, not colour.

Inputs: Paper `c:settings-row/action/rest` (ST-2 `1GJP-0` with pill `1GJQ-0`; ST-4 `1GOE-0`/`1GOF-0`; ST-5 `1GPI-0`/`1GPJ-0`; ST-7 `1GSQ-0`/`1GSR-0`; ST-9 `1GUQ-0`; no master on 02, inventory §2b); settings-row.md "action row"; screen rules 15 (raised neutral pills with an icon, `textPrimary` medium).

Paper values: the shared "raised pill" above. Instances: ST-2 "play" (play icon), ST-3 "connect" (+ icon), ST-4 "sync now" (label only), ST-5 "export" (download icon), ST-7 "sample" (play icon). ST-9's "restore purchases" is **not** an action row in Paper (title only, no trailing; see P31).

Spec: add `case action(label: String, symbol: String?, state: ActionState)` to `RSettingsRow.Trailing`, with `ActionState` `.rest`, `.pending` (the pill keeps its width, a turning ring replaces the icon: `RSpinner` 12), `.done(String)` (the label swaps with `.rBlurReplace`, e.g. "restored"), `.disabled`. The pill is `RPill(.raised)`; only the pill is the button for action rows (the row title isn't), with a 44 hit area.

State table:

| State | Look | Motion | Haptic |
|---|---|---|---|
| rest | raised pill, label `textPrimary` medium | — | — |
| pressed | pill 0.94 | press in 80 / out 240 | none |
| pending | ring in the icon's place, width kept | `spin` | — |
| done | label blur-replaces ("restored", "syncing") | `rBlurReplace` 200 | `confirm` |
| disabled | `opacityDisabled`; the row's subline says why | — | — |
| error | snaps back to rest; the row's subline turns `statusDangerText` | blur-in 220 | `error` |

Interaction table:

| Touch | Press | Haptic | Motion | Outcome | Reduce Motion |
|---|---|---|---|---|---|
| tap pill | 0.94 | `confirm` on done, `error` on failure | as above | the action runs | no blur; 140 cross-fade |

Accessibility: one element: "<title>, <subline>, <label>, button"; pending adds "in progress"; AX3: the pill moves under the text.

Acceptance and tests: (snapshot) every state, light/dark/ax3; (UI) "tapping the pill runs the action and the row title doesn't".

Proof: standard proof against `1GJP-0` and `1GOE-0`.

Watch out: a pill label that changes ("export" → "save") must not change the row's height or jump the pill (fixed min width = the widest label of the pair).

---

### C42.2 · Row states: loading, offline, disabled with a reason, error      size: S
Place in the tree: settings › foundations › settings row › states
Repo · branch: NPRdoinglaundry · `ui/C42.2-row-states`
Needs: C42.1      Unblocks: every settings page

Why: a row never just goes grey: it says why ("turn the brief on first", "needs a connection"), and a failed change says what happened in the row itself.

Inputs: settings-row.md states table; switch.md (error: snaps back, subline says why); build notes "Switch: no pending visual … toggle optimistically; on failure animate back and show the reason in the row subline".

Spec: `RSettingsRow` gains `reason: String?` (replaces the subline while disabled, `textTertiary` title and subline, `opacityDisabled` on the trailing control), `loadingValue: Bool` (a 40-wide skeleton bar in the value's place), and uses the existing `error` flag for a failed write (subline `statusDangerText`, blur-in). Offline is a reason ("needs a connection") set by the page.

State table: rest · disabled + reason · loading value (shimmer) · error after a failed write (blur-in 220, `warning`) · offline (= disabled + "needs a connection") · dark.

Accessibility: a disabled row reads "<title>, dimmed, <reason>"; an error reads the new subline once (announcement).

Tests: (snapshot) each state × light/dark/ax3; (unit) "a disabled row never fires its action".

Proof: standard proof against DS6-0's rows.

Watch out: never hide a dependent row (settings-row edge case: "the dependent row disables with the reason, never hides").

---

### C43 · Time sheet (the brief's time)                                       size: S
Place in the tree: settings › brief › ST-2 › time sheet
Repo · branch: NPRdoinglaundry · `ui/C43-time-sheet`
Needs: C19.1 (sheet host)      Unblocks: P24

Why: choosing when your brief arrives is a quick, familiar spin of a wheel, in your own clock style.

Inputs: Paper ST-2 time row `1GK9-0` ("time · your time, london · 8:30 am" in the snapshot); design-reference §C19 "value pickers (ST-2 time)"; contract 06 §2 (quarter hours).

Spec: a `.medium` detent sheet (C19.1) on `backgroundRaised`: title "brief time" (display 2xl inky, tracking title), one plain line "your time, <city or zone>" (`textSecondary`), a wheel `DatePicker(.hourAndMinute)` with `minuteInterval` 15 (a UIKit wrapper: SwiftUI's picker has no interval), then "done" (`RButton.secondary`) and "cancel" (text). Spacing by group: title+line 8, picker 16, break 32, actions 4. The value applies on "done" only; dismissing applies nothing.

State table: open · scrolling (system) · done (sheet closes, row value blur-replaces) · offline (never opens; the row is disabled) · dark.

Interaction table:

| Touch | Press | Haptic | Motion | Outcome | Reduce Motion |
|---|---|---|---|---|---|
| tap time row | row `surfaceSubtle` | none | `sheet` spring | sheet opens | 140 fade |
| spin wheel | system | system ticks | system | — | system |
| done | 0.98 | `select` | `sheetDismiss` | saves; row shows the new time | fade |
| drag down / cancel | — | none | `sheetDismiss` | nothing saved | fade |

Accessibility: the picker is the system's (adjustable); "done" is the default action; AX3 opens the sheet full height.

Tests: (snapshot) open, light/dark/ax3; (UI) "done saves 8:30 and cancel saves nothing"; (unit) "minutes snap to quarter hours".

Proof: standard proof; a recording of open → spin → done.

Watch out: show the time in the person's 12/24-hour setting; never format "8:30 am" by hand.

---

### C44 · Voice sample pill                                                   size: S
Place in the tree: settings › voice › ST-7 › sample
Repo · branch: NPRdoinglaundry · `ui/C44-voice-sample`
Needs: C42.1, UI3.0 (`SamplePlayback`, the player protocol)      Unblocks: P29

Why: you hear a voice before you choose it, with one tap, and it stops when you leave.

Inputs: Paper ST-7 action row `1GSQ-0` + pill `1GSR-0` ("voice · warm · one voice behind every show · sample"); contract 06 §2 (sample URL, 9 s).

Spec: the action row's pill: "sample" + play glyph → while playing "stop" + stop glyph, with a 2pt `playerProgress` hairline along the pill's bottom inner edge filling over the sample's length (linear with playback, the one linear motion allowed: it tracks time). Plays through a short-lived player separate from the brief player (pauses the brief if one is playing, resumes nothing). Ends → back to "sample". Leaving the page stops it.

State table: rest · loading (> 400 ms: ring in the glyph's place) · playing (progress) · ended → rest · failed ("couldn't play", reverts after 3 s) · offline (disabled) · dark.

Interaction table:

| Touch | Press | Haptic | Motion | Outcome | Reduce Motion |
|---|---|---|---|---|---|
| sample | 0.94 | none | glyph `playMorph` 180 | plays | glyph swaps |
| stop | 0.94 | none | `playMorph` | stops | swap |

Accessibility: "sample of the warm voice, button"; playing: "stop sample"; the progress isn't read.

Tests: (snapshot) rest, playing at half, failed; (UI) "sample plays and leaving the page stops it".

Proof: standard proof; a recording.

Watch out: the audio session category must not duck or stop the person's own music for longer than the sample (`.playback` with `.duckOthers`, restored after).

---

### C45 · "Picked by retro" note                                             size: S
Place in the tree: settings › straight › ST-6 › note
Repo · branch: NPRdoinglaundry · `ui/C45-picked-note`
Needs: T01      Unblocks: P28

Why: when Retro chose how straight to be with you, it says so and why, and you can hand the choice back to it at any time.

Inputs: Paper ST-6 `1GQM-0` (choices `1GRG-0`, chosen `1GR1-0`, tick `1GR2-0`); snapshot copy: "i picked honest observations because you answer the hard questions, and say "not quite" when i'm wrong." · "let it decide"; contract 06 §2 (`source`, `why`).

Paper values (ST-6 footer): a column inside the screen margin, gap `--spacing-1` 4: the section-label style "picked by retro", then `--font-text` `--text-md` 14, `--color-text-secondary`, balanced: "i picked honest observations because you answer the hard questions, and say "not quite" when i'm wrong. choose another and yours wins." Bare text, no card. It sits `--spacing-6` 24 below the choices (ST-6's body gap).

Spec: when `source == .picked`: label "picked by retro" + "i picked <level> because <why>. choose another and yours wins." (`why` from the server; when null: "i picked <level> to start. choose another and yours wins."). When `.yours`: label "yours" (lean) + a text button **"let it decide"** (`--color-text-link`, `--text-md` medium, 44 high) that hands the choice back.

Paper vs docs: Paper draws only the picked state and no "let it decide" (the 20 Oct snapshot and the handoff had "your choice wins (let it decide)"). Without it, nobody could ever hand the choice back, though the brain supports it (`level: null`). Founder question Q15 (lean: keep "let it decide" when yours, drawn by the integrator in Paper).

States: picked (note) · yours (let it decide) · switching (cross-fade 200) · dark.

Interaction: "let it decide" → `select` haptic; the tick moves to Retro's level (`snappy`), the note blurs in; RM: 140 fade.

Accessibility: the note is read after the choices; "let it decide, button, hands the choice back to retro".

Tests: (snapshot) picked, yours, picked without why; (UI) "let it decide shows the note".

Proof: standard proof against `1GQM-0`.

Watch out: never show the brain's level words ("Honest observations: gaps named plainly…"); the four choice titles and sublines are the app's copy from Paper.

---

### C46 · What i've learned block                                            size: S
Place in the tree: settings › learned › ST-8 › block
Repo · branch: NPRdoinglaundry · `ui/C46-learned`
Needs: C39.2 (empty line)      Unblocks: P30

Why: one honest sentence about how Retro is adjusting to you, and nothing made up when it's too early.

Inputs: Paper ST-8 `1GTG-0` (no component instances; the page is text); snapshot: "you answer questions about work most, 8 of 10." · "you skip ones about family (1 of 5), so i ask those less, and only when you bring it up first." · "last changed on sunday"; contract 06 §3.

Paper values (ST-8): one block, gap `--spacing-3` 12: headline `--font-display-inky` (Exposure) `--text-2xl` 28, `--font-weight-ink-card` 399, `--tracking-card` −0.02em, `--leading-tight` 110%, `--color-text-primary`, balanced; body `--font-text` `--text-body` 17, `--color-text-secondary`; then the section-label style (Geist 12 medium `--color-text-label`) "last changed on sunday". No rows, no controls.

Spec: as Paper ("8 of 10" stays in the sentence's face; it's prose, not a counting figure). Too early: C39.2's line "too early to say. i'll know more after a few more questions." Off: "i'm not adjusting my questions yet." (both copy to confirm).

States: learning · tooEarly · off · loading (skeleton of three lines) · error (C39.3) · dark.

Accessibility: the headline is a header; "last changed on sunday" reads with the full date.

Tests: (snapshot) each state × light/dark/ax3, SE.

Proof: standard proof against `1GTG-0`.

Watch out: the sentences come from the server; never compose them in the view.

---

### C47 · Export row                                                          size: S
Place in the tree: settings › privacy › ST-5 › download my data
Repo · branch: NPRdoinglaundry · `ui/C47-export-row`
Needs: C42.1      Unblocks: P27

Why: you see exactly where your export is: getting ready, ready to save, or gone, without a progress bar pretending to know how long.

Inputs: Paper ST-5 action row `1GPI-0` + pill `1GPJ-0` ("download my data · export"); contract 06 §5.

Spec: the action row with states mapped from `latestExport`:
- none / expired → subline "everything retro holds, as a file" · pill "export";
- preparing → subline "getting it ready. i'll let you know." · pill pending (ring, width kept); never a percentage (craft 12.3);
- ready → subline "ready until <date>" · pill "save" → the share sheet with the zip (`ShareLink` with a file URL from `exportFile()`);
- limited → subline "you can export once a day" (disabled);
- failed → subline `statusDangerText` "that didn't work. try again." · pill "export".

States/haptics: ready arrives while on screen → subline blur-replaces, `reveal` haptic once; save → `select`.

Accessibility: each state reads its subline; "save, button, opens the share sheet".

Tests: (snapshot) none, preparing, ready, limited, failed; (UI) "save opens the share sheet".

Proof: standard proof.

Watch out: downloading a big zip takes time: while `exportFile()` runs, the pill is pending; the share sheet opens only when the file exists.

---

### C48 · The sign-out sheet (AC-2)                                          size: M
Place in the tree: settings › account › AC-2 › sign-out sheet
Repo · branch: NPRdoinglaundry · `ui/C48-sign-out-sheet`
Needs: C19.1, `RSpinner`, `RButton` (#43)      Unblocks: P33

Why: signing out never loses anything: if something you wrote hasn't sent, it goes first, and you see it go.

Inputs:
- Paper: AC-2 `1GVP-0`, `c:sheet/sign-out` `1GVR-0`, `c:spinner/20` `1GW1-0`, `c:button/lit/send-then-sign-out` `1GVV-0`, `c:button/text/cancel` `1GVT-0`; dark `2L1K-0`
- Reference: design-reference §C19 "AC-2 sign-out sheet" (all values); build notes "Sheets: spacing by group"; the queued fix: fill `backgroundRaised`, not canvas

Paper values (AC-2 `1GVP-0`, sheet `1GVR-0`):
- Page behind: ST-9 as drawn; scrim inset 0, `--color-night-900` at `--opacity-disabled` 40%.
- Sheet: docked to the bottom; top corners `--radius-sheet` 38; shadow `--color-depth-shadow-cast` 0 −8 24 −8; padding top `--spacing-2` 8, inline `--spacing-screen-margin` 24, bottom `--spacing-10` 40; grabber 36 × 5 `--color-border-strong`, pill radius, centred.
- Text block `--spacing-5` 20 below the grabber, gap `--spacing-2` 8: "sign out?" in `--font-display` (Hedvig Letters Serif), `--text-2xl` 28, `--tracking-title` −0.035em, `--leading-tight`, `--color-text-primary`; "your entries, episodes and everything retro knows stay safe. sign back in with apple any time." in `--text-body` 17 `--color-text-secondary`, pretty wrap (the provider from `account.signedInWith`).
- Unsent card `--spacing-4` 16 below: `--color-surface-wash`, `--radius-panel` 16, padding 12 / 16, gap 12: a 20pt ring spinner (track `--color-text-tertiary`, arc `--color-ink-default`, stroke 2: `RSpinner(diameter: 20)`), "1 entry hasn't sent yet" (`--font-text` `--text-md` 14 medium `--color-text-primary`), "it goes first, so nothing is lost." (Geist `--text-sm` 12 `--color-text-label`); plurals from a stringsdict.
- Actions `--spacing-8` 32 below, gap `--spacing-1` 4: the lit button, height `--spacing-size-control-hero` 60, pill radius, the glow-primary stack (gradient `--color-glow-primary-gradient-top` → `-bottom` in oklab; rim, edge, bloom, ring 1.5, halo 0 6 14 −4, cast 0 2 2), label "send, then sign out" `--font-text` `--text-body` semibold `--color-glow-primary-foreground` (`RButton.lit`); "cancel" 44 high, `--text-body` medium `--color-text-link`.
- Paper vs docs: Paper fills the sheet with `--color-background-canvas`; the 21 Oct build note says sheets are `backgroundRaised`, never canvas, and the Paper fix is queued. Newest is the build note: build `backgroundRaised`, list it in the PR. The title uses `--font-display` with no weight (ST-8 uses the inky display face): build as drawn.
- Not drawn, decided by the system: with nothing waiting, the lit button becomes a secondary "sign out" (`RButton.secondary`, the handoff's rule), so the sheet has no lit object for a non-event.
- Progress (states the sheet shows while `sendThenSignOut()` runs): `sending` (the lit button pending: dots over the kept label; cancel disabled; the count rolls down with `numericText`); `stuck` (the card's lines become "1 entry can't send right now" / "if you sign out now, it's lost from this phone." and the actions become "wait" (secondary, closes the sheet, nothing lost) and "sign out anyway" (a text button in `--color-status-danger-text`)); `done` (the sheet closes into AC-1).

State table:

| State | Look | Motion | Haptic |
|---|---|---|---|
| nothing waiting | title, line, "sign out" (secondary), cancel | `sheet` in | `sheetSnap` |
| unsent | + unsent row, lit "send, then sign out" | — | — |
| sending | lit button pending; count rolls | `numericText` | — |
| stuck | row copy changes; "wait" + "sign out anyway" | `rBlurReplace` | `warning` |
| done | sheet dismisses; app goes to AC-1 | `sheetDismiss` | `confirm` |
| dark | `backgroundRaised` dark, scrim black 60% | — | — |

Interaction table:

| Touch | Press | Haptic | Motion | Outcome | Reduce Motion |
|---|---|---|---|---|---|
| send, then sign out | lit press 0.98 | `press` (lit only) | pending dots | drains then signs out | no dots motion; label "sending…" |
| sign out | 0.98 | none | — | signs out | — |
| sign out anyway | dims 0.7 | `warning` on touch-down | — | forced sign-out | — |
| cancel / drag down | — | none | `sheetDismiss` | nothing | fade |

Accessibility: the sheet is modal, title read first; the unsent row reads its two lines; "sign out anyway, button, unsent entries will be lost from this phone"; AX3: full height, actions stay visible (the middle flexes, `minHeight: 0`).

Tests: (snapshot) nothing waiting, unsent, sending, stuck × light/dark/ax3, SE; (UI) "with an unsent entry, send then sign out sends it first"; (UI) "cancel keeps you signed in".

Proof: standard proof against `1GVR-0`; a recording of unsent → sending → done.

Watch out: the founder's rule "nothing is lost" is the point of this sheet: "sign out anyway" appears only in `stuck`, never as a first choice.

---

### C49 · Invite row and share                                               size: M (needs a Paper drawing first)
Place in the tree: settings › invites › PI3 › invite row
Repo · branch: NPRdoinglaundry · `ui/C49-invite-row`
Needs: `RPill` (#45), `RSettingsRow`, the founder-approved drawing (Q7; the invite board `2H3N-0` is another session's)      Unblocks: PI3

Why: each of your three invites is a gift you hand to one friend; you see which you've given, and sharing one says plainly it works once.

Inputs: contract 00 §4 (`Invite`), contract 06 §9 (share line); context.md §2 ("you've just been given a gift, don't waste it"); M14's language.

Spec (lean, until drawn): a row per invite, leading 32 well with the gift/ticket glyph from the icon set (asset request if missing), title "invite 1" … or, when used, "used by <first name>" with a quiet date; trailing: unused → raised pill "share" (share sheet via `ShareLink(item: url, message: Text(line))` and a preview with the app's artwork); used → nothing; revoked → "no longer works" (`textTertiary`).

States: unused · used · revoked · sharing (system) · offline (share still works from the cached link) · dark.

Interaction: share → system share sheet; on completion nothing is assumed (iOS doesn't say if it was sent); no haptic on share (the system's own).

Accessibility: "invite, unused, share button"; "invite, used by sam on 3 october".

Tests: (snapshot) unused, used, revoked; (UI) "share opens the share sheet with the link".

Proof: standard proof against the approved drawing.

Watch out: never show the code itself on screen (the link is the secret; showing it invites screenshots shared widely).

---

### C50.1 · Danger dialogs (four)                                            size: S
Place in the tree: settings › account, privacy, sources › dialogs
Repo · branch: NPRdoinglaundry · `ui/C50.1-danger-dialogs`
Needs: C19.2 (dialog)      Unblocks: P26, P27, P31

Why: every destructive choice says exactly what will happen before you make it, and nothing else on the page ever glows red.

Inputs: part 24 dialog `A5L-0`; build notes ("Delete dialog: full width minus screen margins (342 on a 390 screen) … refined danger recipe"); design-reference §C19 ("MUST say exactly what will happen"); contract 06 §4, §8; README §9 (billing reminder).

Spec: four configurations of `RDialog` (C19.2), copy to confirm with the founder:
1. **Disconnect <source>?** "retro stops reading <source>. what it already read stays. you can connect it again any time." When `sharedGrant` is set: "this also disconnects <docs, gmail and youtube>, because google gives one permission for all four." · "disconnect" (danger) · "cancel".
2. **Delete what <source> gave retro?** "everything retro took from <source> goes, and what it learned from it. this can't be undone." · "delete it" · "cancel".
3. **Delete my data?** "everything retro has read and learned goes: your entries, episodes and what it knows about you. your account and subscription stay, and you'll start again from the first question. this can't be undone." · "delete my data" · "cancel".
4. **Delete your account?** "your account, entries, episodes and everything retro knows are deleted. this can't be undone." + when `plan.renews`: a second paragraph "apple keeps billing your subscription until you cancel it." with a "manage subscription ↗" text button (opens Apple's sheet; the dialog stays) · "delete my account" · "cancel".
- Every destructive button: the refined danger recipe (no outer ring or halo), `haptic.warning` on touch-down; pending state (dots over the kept label, cancel disabled); offline: the confirm is disabled with "needs a connection".

States: open · pending · error (one line `statusDangerText`, `error` haptic) · offline · dark.

Interaction: confirm → pending → (success) the dialog closes into the page's next state; cancel/escape → closes, nothing happens; RM: fade.

Accessibility: alert; cancel is the default action; the destructive button reads "delete my account, destructive".

Tests: (snapshot) each dialog, the renewing variant of 4, pending, error × light/dark/ax3, SE; (UI) "cancel deletes nothing".

Proof: standard proof against `A5L-0`.

Watch out: the destructive glow lives only here (screen rule; build notes "the dialog is the only place a destructive glow appears").

---

### C50.2 · Deleting, and goodbye                                            size: S
Place in the tree: settings › account › delete account › progress
Repo · branch: NPRdoinglaundry · `ui/C50.2-deleting`
Needs: C50.1      Unblocks: P31

Why: after you confirm, you see your account being deleted calmly, and then a plain goodbye, never a crash back to a sign-in screen.

Inputs: contract 06 §8 (202); PL3.7g outcomes; no Paper drawing exists (founder question in P31: lean below, the design system decides).

Spec (the design system decides, per memory "the design system decides"): after confirm, the dialog's pending state holds while `deleteAccount()` runs; on `.deleted`, the screen cross-fades to a centred canvas page: the mark (S10, still) + "your account is deleted." (display 2xl inky) + "thank you for trying retrospect." (`textSecondary`), for 2.4 s, then the splash. On `.cancelledAtApple`: the dialog closes, ST-9 unchanged, no message. On `.failed`: the dialog shows the error line. Apple's sheet (when needed) appears over the dialog.

States: pending · appleConfirm (system sheet) · deleted (goodbye) · cancelledAtApple · failed · offline · dark.

Accessibility: "your account is deleted" is announced; the goodbye page is not interactive and moves on by itself (VoiceOver users get it read first).

Tests: (snapshot) goodbye light/dark/ax3; (UI) "after deletion the splash appears".

Proof: a recording of confirm → goodbye → splash.

Watch out: never show "welcome back" (AC-1) after a deletion; PL3.7i clears `hasSignedInBefore`.

---

### P23 · ST-1 settings                                                      size: S
Place in the tree: settings › hub › ST-1
Repo · branch: NPRdoinglaundry · `ui/P23-settings`
Needs: C41, C42.2, UI6.0      Unblocks: every settings page's entry, T06

Why: every setting in one calm list, each showing its current value, so you know where things stand before you open anything.

Inputs: Paper ST-1 `1GGA-0` (bar `1GJ1-0`, label `1GJ0-0`, value row `1GIQ-0`, hairline `1GIC-0`), dark `2H5Q`.

Paper values (ST-1): body top padding `--spacing-2` 8 (not 16), groups 32 apart, the artboard's bottom padding `--spacing-10` 40, no danger row. Every row has the 32 icon well; hairlines inset 68. Rows, top to bottom (verbatim):
- label "your brief": "daily brief" · value "8:30 · on" ›
- label "listening": "voice" · "warm" ↕; "talk or read" · "talk" ↕
- label "you": "how straight i am with you" · "honest" ↕; "what i've learned" ›
- label "sources": "connected sources" · "4 · 1 needs you" ›
- (no visible label): "privacy" ›; "account" ›
- Hidden layers (`display: none`, copy-paste leftovers; never built): a "listening" label over the last group, and values "talk" (what i've learned), "warm" (privacy), "talk" (account). This is paper-inventory finding 7; the visible page is correct.

Spec:
- Sections and rows as Paper, with values from `settings`, `sources`, `invites`: "8:30 · on" / "off"; voice name; "honest" etc. (the level's short name: "facts only", "gentle", "honest", "plain": copy to confirm); "4 · 1 needs you" / "4" / "none".
- Not drawn: **invite friends** · "2 left" › in the "you" group (Q7); **notifications** › in the last group, above privacy (P23a; founder, 21 Oct); **talk or read** is hidden in v1 (Q2).
- Paper vs docs: Paper puts ↕ (a menu in place, decision 04 B) on "voice", "talk or read" and "how straight i am with you", yet ST-6 and ST-7 are full pages with things a menu can't hold (the "picked by retro" why, the voice sample, speed). Founder question Q16 (lean: › to the pages, with the value shown; the menu would hide the why and the sample).
- Entry: the You tab's picture and the drawer foot push this page; deep link `.settings(.root)`.

Interaction sheet:

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | arrive (push from YO-1) | values from cache at once; refresh quietly | system push | — | fade |
| 2 | values change after refresh | the changed value blur-replaces | `rBlurReplace` | — | 140 fade |
| 3 | tap a row | row pressed; push its page | system push | none | fade |
| 4 | leave | scroll position kept | — | — | — |

Life allowed: none.

State table (T02 `-State`): `full`, `dayOne` (brief "off", "nothing connected", invites "3 left"), `sourceNeedsYou`, `offline` (values from cache; rows still open their pages), `loading` (skeleton values), `error` (C39.3).

Accessibility: rotor: bar → sections in order; each row "daily brief, 8:30, button"; `performAccessibilityAudit()` passes in full and offline.

SE: 20 margins; the sources subline drops "· 1 needs you" into the error styling only.

Acceptance: every state matches `1GGA-0` (with the copy fix) in light, dark, AX3 and SE.

Tests: (snapshot) full, dayOne, offline, loading × light/dark/ax3, SE (full); (UI) "each row opens its page" (identifiers `settings.row.<id>`); (accessibility) audit passes.

Proof: page proof; a recording of row 1–3.

Watch out: ST-1's own bar has back too (C17); the page title "settings" is centred like the rest.

---

### P23a · Notifications                                                   size: S (needs a Paper drawing first)
Place in the tree: settings › notifications › page
Repo · branch: NPRdoinglaundry · `ui/P23a-notifications`
Needs: C41, `RSwitch` (#50), UI6.0, a Paper drawing (Q17)      Unblocks: T06

Why: you decide which kinds of notification Retro sends you, and whether their words can show on your lock screen. Every notification is written for you and the moment (founder, 21 Oct); this page only decides which ones come and how they show.

Inputs: contract 06 §2 (`NotificationSettings`), the founder's 21 Oct decision (per-kind switches; "hide notification words on the lock screen", default off); EX-3 (`1H3E-0`: three kinds, at most one a day, never at night); the shared settings values above (it's built only from approved parts, the way ST-5 is).

Spec (the design system decides until it's drawn; the integrator draws it from these parts):
- `RSettingsPage(title: "notifications")`.
- When iOS has notifications off (`systemNotifications == .denied`): a first row "notifications are off for retrospect" / "turn them on in ios settings" with ↗, which opens iOS's notification settings for the app. The switches below stay as chosen (they apply once iOS allows).
- Group, label "send me": switch rows "today's brief" / "when it's ready, at your time" (disabled with "turn the brief on first" while the brief is off); "a new episode" / "when your week's episode is made"; "a question from retro" / "when there's something i'd like to ask".
- Group, label "on the lock screen": switch row "hide the words" / "it says it's from retro; the words show when you open it." (default off).
- No wells (as the sub-pages in Paper), hairlines inset 24, groups 32 apart.

Interaction sheet:

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | a switch | applies at once | switch spring (0.3/0.75) | `select` | no overshoot |
| 2 | write fails | switch back; subline says why | spring back; blur-in | `error` | fade |
| 3 | first switch on, iOS undetermined | iOS's own alert | system | — | — |
| 4 | the iOS row | iOS Settings opens on Retrospect's notifications | system | none | — |
| 5 | come back from iOS Settings | the iOS row disappears if allowed | 200 fade | — | fade |

State table: `notificationsOn`, `wordsHidden`, `iosDenied`, `iosUndetermined`, `briefOff`, `offline` (switches disabled "needs a connection"), `loading`.

Accessibility: each switch reads its title, subline and state; the iOS row reads "opens ios settings".

Tests: (snapshot) notificationsOn, wordsHidden, iosDenied × light/dark/ax3, SE; (UI) "hiding the words saves and stays after relaunch"; (UI) "with notifications off in iOS, the page says so and links to iOS settings"; (accessibility) audit.

Proof: page proof against the approved drawing.

Watch out: the page never shows example notification text (there's no generic copy to show; each is written at the moment).

---

### P24 · ST-2 daily brief                                                   size: M
Place in the tree: settings › brief › ST-2
Repo · branch: NPRdoinglaundry · `ui/P24-daily-brief`
Needs: C41, C42.1, C42.2, C43, `RSwitch` (#50), `RSegmented` (#51), UI6.0      Unblocks: T06

Why: you turn the brief on when you want it, choose when it's ready and how long it is, and can play today's from here.

Inputs: Paper ST-2 `1GJK-0` (switch row `1GKJ-0`, switch `1GKK-0`, value row `1GK9-0`, label `1GK6-0`, segmented `1GJZ-0`, action row `1GJP-0`, pill `1GJQ-0`), dark `2H90`; snapshot copy: "each morning · a short brief, made from yesterday" · "time · your time, london · 8:30 am" · "length · short · standard · long · standard is about 4 minutes." · "play today's · tuesday · 4 min · play"; contract 06 §2; D7.

Paper values (ST-2, read in full): no icon wells; body top 16, groups 32 apart.
- Group 1: switch row "each morning" / "a short brief, made from yesterday" (switch on in `--color-ink-default`); hairline inset 24; value row "time" / "your time, london" · "8:30 am" (`--text-md` `--color-text-secondary`) + ↕ 16 `--color-icon-muted`, gap 4.
- Group 2 (inside the screen margin, gap `--spacing-2` 8): label "length"; segmented control (track height `--spacing-size-search-field` 36, `--color-surface-control`, pill radius, 2 padding, sunken inset `--color-depth-shadow-sunken` 0 1 2 + `--color-depth-stroke-outer` 0 0 0 0.5; segments 32 high; selected `--color-background-raised` with the raised stack and cast 0 2 4 −1; labels Geist `--text-md` medium `--tracking-label` `--leading-tight`, selected `--color-text-primary`, others `--color-text-label`): "short · standard · long"; caption Geist `--text-sm` 12 `--color-text-label`: "standard is about 4 minutes."
- Group 3: action row "play today's" / "tuesday · 4 min" · raised pill (play icon 16) "play".
- `RSegmented` (#51) already matches; check its selected cast (0 2 4 −1, not the pills' 0 4 6 −2).

Spec:
- Row 1 switch, row 2 time as Paper. The time's ↕ opens C43 (a sheet with a wheel), not an in-place menu: decision 04 B's ↕ menus are for short lists, and 96 quarter hours isn't one. Paper vs docs: noted in the PR.
- "your time, <city>": the city from the time zone's exemplar city (`TimeZone.localizedName` fallback), never a guess.
- Length group as Paper (hidden if Q1 = B); the caption follows the chosen length ("short is about 2 minutes.").
- Row 3 action as Paper → opens JR-2 (P10) with today's brief. Hidden when there's no brief today (day one) or the brief is off.
- Off: rows 2–3 and length disabled with the reason "turn the brief on first" (never hidden).
- Turning on: PL5.4's notification ask may appear (system alert).

Interaction sheet:

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | switch on | thumb moves; dependents enable | switch spring (0.3/0.75); dependents 200 fade | `select` | no overshoot |
| 2 | write fails | switch springs back; subline says why | spring back; blur-in | `error` | fade |
| 3 | tap time | C43 opens | `sheet` | — | fade |
| 4 | length segment | thumb slides; caption blur-replaces | `snappy` | `select` | fade |
| 5 | play today's | pill press; JR-2 opens over settings | C23b choreography | none (a non-lit press; design-reference F35) | fade |

Life: none. Lit object: none.

State table: `on`, `off`, `dayOne`, `timeSheet`, `writeFailed`, `offline`, `loading`.

Accessibility: "each morning, a short brief, made from yesterday, switch, off"; dependents read their reason; the segmented control is adjustable.

SE: drop the time row's subline; the caption stays.

Acceptance: each state matches `1GJK-0` in light, dark, AX3, SE; rows 1–5 built and recorded.

Tests: (snapshot) on, off, writeFailed, offline × light/dark/ax3, SE; (UI) "turning the brief on enables time and length"; (UI) "a failed write puts the switch back and says why"; (UI) "play today's opens the brief"; (accessibility) audit in on and off.

Proof: page proof; recordings of 1, 2, 4.

Watch out: switch.md "no pending visual" (build notes): toggle optimistically, never a spinner in the thumb.

---

### P25 · ST-3 sources                                                       size: M
Place in the tree: settings › sources › ST-3
Repo · branch: NPRdoinglaundry · `ui/P25-sources`
Needs: C41, `RSourceRow` (#52), UI6.0      Unblocks: P26, P25a, T06

Why: you see everything Retro reads, what each is for, and anything that needs you, at a glance.

Inputs: Paper ST-3 `1GL7-0` (source rest `1GN1-0`, hairline inset-icon `1GMX-0`, pill `1GMN-0`, problem `1GM8-0`, syncing `1GLS-0` + spinner `1GLV-0`, value row `1GLK-0`), masters DS6 (`DWC-0`, `DX5-0`, `DXJ-0`, `DXR-0`), dark `2HAN`; snapshot copy: section "connected"; calendar "so your brief knows your day · connected"; health "how you slept, how you moved · syncing"; podcasts "stopped reading on monday · reconnect"; "add · add a source · mail, notes, health, music"; "import a file · notes, a journal, an export"; source-row.md; build notes (syncing ring, source subline ≤ 2 lines, status cross-fades 200).

Paper values (ST-3): group 1, label "connected", rows with 32 icon wells, hairlines inset 24 + `--spacing-size-source-icon` 32 + 12:
- "calendar" / "so your brief knows your day" · dot `--spacing-size-step-dot` 6 in `--color-source-connected` (= `--color-status-success`), 8 gap, "connected" (`--text-md` `--color-text-secondary`);
- "voice notes" / "in your own words" · raised pill (+ icon) "connect";
- "podcasts" / "stopped reading on monday" · dot `--color-source-problem` (= `--color-status-danger`) + "reconnect" (a word, not a pill);
- "health" / "how you slept, how you moved" · the 6pt syncing ring (track `--color-border-strong`, a quarter arc `--color-text-secondary`, round cap, 1 turn a second, linear) + "syncing".
Group 2, no label, no wells, hairline inset 24: "add a source" / "mail, notes, health, music" ›; "import a file" / "notes, a journal, an export" ›.

Paper vs docs: (1) Paper's needs-you trailing is a red dot + the word "reconnect"; source-row.md says "the trailing becomes a 'reconnect' pill (no dot)" and the subline in `status.dangerText`. Newest is Paper (21 Oct): dot + word, subline stays secondary; the whole row opens ST-4, where the reconnect pill lives. (2) Paper lists not-connected "voice notes" with a connect pill inside "connected"; contract 06 lists not-connected sources only on "add a source": follow Paper (a not-connected source the person had connected before stays in the list with "connect"), and the sample shows it. (3) The "add a source" subline names "health", which is already connected: the subline is built from the first three not-connected names, never fixed copy.

Spec: section "connected" (connected, syncing, needs-you and previously connected sources, by `GET /v2/sources` order) with `RSourceRow`; a needs-you row shows dot + "reconnect" and opens ST-4 (where the reconnect pill starts the connect flow, PL3.7b2); a previously connected source shows the raised "connect" pill, which starts it here; then the group without a label: "add a source ›" (P25a; subline from the catalogue's first names) and "import a file ›" (the `fileImporter`, then a source picker if more than one `file` source). Day one: the "connected" section is absent (a group with nothing isn't shown) and C39.2's line sits above the add group: "nothing connected yet. retro only learns from what you send it." When ambient is off: one line under the bar "background reading is off, so nothing here is being read." (`textSecondary`).

Interaction sheet:

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | arrive | cached list at once | push | — | fade |
| 2 | a sync finishes while visible | "syncing" ring → "connected" + dot | cross-fade 200 | `confirm` once | fade |
| 3 | tap a source | push ST-4 | push | none | fade |
| 4 | connect (a previously connected source) | pill pending; browser or iOS asks; back → syncing | sheet (system) | `confirm` on connected | fade |
| 5 | import a file | system file picker; then a row "reading <name>" appears pending | `rAppear` | — | fade |

State table: `full`, `none` (day one), `syncing`, `needsYou`, `ambientOff`, `offline`, `loading`, `error`.

Accessibility: "calendar, so your brief knows your day, connected"; syncing reads "syncing" once (no double read: lesson from #52); `performAccessibilityAudit()` passes.

SE: source sublines one line with an ellipsis is **not** allowed (rule: wrap to two); the "add" sublines drop.

Acceptance: states match `1GL7-0` in light, dark, AX3, SE; rows 1–5 recorded.

Tests: (snapshot) full, none, needsYou, ambientOff, offline × light/dark/ax3, SE; (UI) "a needs-you source shows the red dot and reconnect, and opens its page"; (UI) "tapping a source opens it"; (accessibility) audit.

Proof: page proof; recordings of 2 and 4.

Watch out: the Google members show as four rows (calendar, docs, gmail, youtube) with one permission; reconnecting one reconnects all (the browser flow is shared).

---

### P25a · Add a source                                                      size: S (needs Q12's answer or a drawing)
Place in the tree: settings › sources › add a source
Repo · branch: NPRdoinglaundry · `ui/P25a-add-source`
Needs: P25, PL3.7b2's protocol calls (sample), Q12      Unblocks: T06

Why: you can see every place Retro could learn from, what each is for, and connect one in a tap; the ones not ready yet say so.

Inputs: Q12 (lean: ON-6's "see all apps" page if first run draws it; else a page in ST-3's style); `RSourceRow` "coming soon" disabled state; contract 06 §4 (`?include=all`).

Spec (lean A, built from approved parts only): `RSettingsPage(title: "add a source")`, sections "on this iphone", "your other apps", "from a file" (by `where`), each a `RSourceRow`: not connected → "connect" raised pill; connected → "connected" + dot; coming soon → disabled, "coming soon" (`textTertiary`). Connect runs PL3.7b2.

States: full · connecting (pill pending) · connected (cross-fade, `confirm`) · failed (shake 6pt `motionShakeDistance`, subline "that didn't work. try again.", `error`) · offline · dark.

Accessibility: "gmail, coming soon, dimmed".

Tests: (snapshot) full, connecting, failed; (UI) "connecting health asks iOS and shows connected".

Proof: page proof against the approved drawing.

Watch out: never pre-connect anything (source-row rule 3); never show a provider that isn't configured as connectable.

---

### P26 · ST-4 a source                                                      size: S
Place in the tree: settings › sources › ST-4
Repo · branch: NPRdoinglaundry · `ui/P26-a-source`
Needs: C41, C42.1, C50.1, UI6.0      Unblocks: T06

Why: for one source, you read in plain words what Retro takes and what it helps it see, and you can read it now, stop it, or remove what it gave.

Inputs: Paper ST-4 `1GNV-0` (action `1GOE-0`, pill `1GOF-0`, danger `1GO5-0`), dark `2HDB`; snapshot copy: title "calendar"; "reads · your events: when, how long, and who was there." · "helps me see · what your weeks are really like, and what fills them." · "last read 2 min ago · sync now" · "disconnect… · stops reading; keeps what it read" · "delete what it read… · removes it from what retro knows"; screen rules 2 (purpose pages are one title + plain description, not lists of labelled facts: here Paper draws two labelled sentences, which the founder approved).

Paper values (ST-4): body gap `--spacing-6` 24 (not 32); "reads" and "helps me see" are each a section label + a sentence 8 (`--spacing-2`) below it, `--text-body` 17 `--color-text-primary`, balanced, inside the screen margin; then a row without a well: "last read 2 min ago" · raised pill, label only, "sync now"; then the danger block with two rows and **no hairline between them**: "disconnect…" / "stops reading; keeps what it read" and "delete what it read…" / "removes it from what retro knows".

Spec: bar title = the source's name. The two blocks as Paper (copy per source from `reads`, `helpsMeSee`). Action row "last read <relative>" · pill "sync now" (C42.1; pending → "syncing", done → "read just now"). Needs you: the action row becomes "stopped reading on monday" (`statusDangerText`) · pill "reconnect". On-phone: an extra leaves-the-app row "ios settings ↗" / "to stop sharing with retrospect in ios too" (only for on-phone sources). Danger zone: "disconnect…" (C50.1 #1) and, when `hasData`, "delete what it read…" (C50.1 #2). After disconnect: back to ST-3 with the row now "connect". While deleting: the delete row is replaced by "deleting what it read…" with the ring.

Interaction sheet:

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | sync now | pill pending → "read just now" | ring; blur-replace | `confirm` | fade |
| 2 | disconnect… | C50.1 #1; confirm → pop to ST-3 | dialog; pop | `warning` in dialog | fade |
| 3 | delete what it read… | C50.1 #2; confirm → "deleting…" → row gone | blur-replace | `warning` in dialog | fade |
| 4 | return from the browser (reconnect) | "syncing" | blur-replace | `confirm` when connected | fade |

State table: `connected`, `syncing`, `needsYou`, `onPhone`, `disconnectDialog`, `deleteDialog`, `deleting`, `offline`.

Accessibility: the two blocks read label then sentence; danger rows read "disconnect, stops reading, keeps what it read, button".

SE: the danger rows sit in the thumb zone (bottom third), as drawn.

Acceptance: states match `1GNV-0`; rows 1–4 recorded.

Tests: (snapshot) connected, needsYou, onPhone, deleting × light/dark/ax3; (UI) "disconnect asks first and then shows the source as not connected"; (UI) "delete what it read asks first"; (accessibility) audit.

Proof: page proof.

Watch out: the shared Google permission: the disconnect dialog names the other three (C50.1 #1).

---

### P27 · ST-5 privacy                                                       size: M
Place in the tree: settings › privacy › ST-5
Repo · branch: NPRdoinglaundry · `ui/P27-privacy`
Needs: C41, C47, C50.1, `RSwitch` (#50), UI6.0      Unblocks: P27a, T06

Why: you control whether Retro reads in the background, can see where your data is handled, take a copy of everything, or wipe it and start again.

Inputs: Paper ST-5 `1GP6-0` (switch row `1GPY-0`, switch `1GPZ-0`, value row `1GPQ-0`, action `1GPI-0`, pill `1GPJ-0`, danger `1GP9-0`), dark `2HEM`; snapshot copy: "read in the background · off means retro only learns from what you send it" · "where it's processed · europe · named providers" · "download my data · export" · "delete my data… · everything retro knows about you"; contract 06 §2, §5, §8.

Paper values (ST-5): one group, no label, no wells, hairlines inset 24: switch row "read in the background" / "off means retro only learns from what you send it" (on in `--color-ink-default`); "where it's processed" / "europe · named providers" ›; "download my data" (title only) · raised pill with a download icon "export"; then the danger block "delete my data…" / "everything retro knows about you".

Paper vs docs: "europe · named providers" is a subline, not a value; it's unverified (Q5), so the build shows the verified summary from P27a in the same place.

Spec:
- Switch row as Paper. When `pausedForEveryone` (Q6): the switch keeps the person's choice; subline "paused for everyone right now." (`textSecondary`, not danger).
- Value row "where it's processed" · "<value from P27a>" › (Q5; the value text is whatever P27a's verified summary is, never "europe" unless verified).
- C47 export row.
- Danger zone: "delete my data…" / "everything retro knows about you" → C50.1 #3 → on success, onboarding (PL3.7f).

Interaction sheet:

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | ambient switch | applies; ST-3 line follows | switch spring | `select` | no overshoot |
| 2 | export | C47 states | — | per C47 | — |
| 3 | export ready while here | subline blur-replaces | blur | `reveal` once | fade |
| 4 | delete my data | dialog → pending → onboarding | dialog; cross-fade to onboarding | `warning` in dialog | fade |

State table: `full`, `ambientOff`, `pausedForEveryone`, `exportPreparing`, `exportReady`, `exportExpired`, `exportLimited`, `deleteDataDialog`, `offline`.

Accessibility: the switch reads "read in the background, off means retro only learns from what you send it, switch, on"; paused adds "paused for everyone right now".

Acceptance: states match `1GP6-0`; rows recorded.

Tests: (snapshot) full, pausedForEveryone, exportPreparing, exportReady × light/dark/ax3, SE; (UI) "turning background reading off saves and shows on ST-3"; (UI) "delete my data asks first, then starts onboarding"; (accessibility) audit.

Proof: page proof.

Watch out: the master switch never reads as the person's fault or as an error.

---

### P27a · Where it's processed                                              size: S (needs Q5's answer and a drawing)
Place in the tree: settings › privacy › where it's processed
Repo · branch: NPRdoinglaundry · `ui/P27a-where-processed`
Needs: P27, Q5 (the verified list), a Paper drawing      Unblocks: T06, the App Store's in-app privacy policy link

Why: you can see, in plain words, where your data lives and which companies process it, and read the privacy policy, all of it true.

Inputs: Q5; screen rules 2 and 3 (a purpose page: one title, one plain description, one picture at most); the integrator's verified list (servers' regions on Render and Supabase; Anthropic, OpenAI and ElevenLabs as processors; Apple for sign-in and payments; RevenueCat).

Spec (lean A): `RSettingsPage(title: "where it's processed")`, one plain paragraph (founder copy), then rows (no icons beyond the wells) "where it's stored · <region>", one row per processor "<name> · <what for: writing, voice, …>", and a leaves-the-app row "privacy policy ↗" (`openURL`). Static content from `Features/Settings/ProcessingCopy.swift`, which carries the date it was verified; a unit test fails if it's older than 180 days (a reminder to re-verify, the strongest layer available).

States: full · dark. (No network.)

Accessibility: rows read "<name>, <what for>"; the link reads "privacy policy, opens in safari".

Tests: (snapshot) full × light/dark/ax3; (unit) "the processing list was verified within 180 days".

Proof: page proof against the approved drawing; the integrator's verification note in the PR.

Watch out: no line ships unverified; if a region is unknown, the row says "united states" only once confirmed, never a guess.

---

### P28 · ST-6 how straight i am with you                                   size: S
Place in the tree: settings › straight › ST-6
Repo · branch: NPRdoinglaundry · `ui/P28-how-straight`
Needs: C41, C45, UI6.0      Unblocks: T06

Why: you choose how directly Retro talks to you, in plain words, or let it decide and see why.

Inputs: Paper ST-6 `1GQM-0` (choice rest `1GRG-0`, chosen `1GR1-0`, check `1GR2-0`), masters `DUX-0`, `DV6-0`, dark `2HG2`; snapshot copy: "just what happened · no reading between the lines" · "gentle questions · i ask, i don't tell" · "honest observations · i say what i see, kindly" · "don't hold back · i say it plainly"; contract 06 §2.

Paper values (ST-6): bar title "how straight i am with you"; body gap `--spacing-6` 24; four rows, no wells, hairlines inset 24, the trailing slot a fixed 20 × 20 holding a 20pt tick in `--color-ink-default` on the chosen row only (copy as above, "honest observations" ticked); then C45's footer.

Spec: four `RSettingsRow(.choice)` rows (ink tick in a 20 slot; titles align either way); C45 below. Choosing writes at once (`setStraightness`); "let it decide" writes `nil`.

Interaction sheet:

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | tap a choice | tick moves; note → "let it decide" | tick `snappy`; note blur-replace | `select` | fade |
| 2 | write fails | tick moves back; subline under the bar "couldn't save that. try again." | `snappy` back | `error` | fade |
| 3 | let it decide | tick to Retro's pick; note in | `snappy`; blur-in | `select` | fade |

State table: `picked`, `yours`, `writeFailed`, `offline` (choices disabled, "needs a connection").

Accessibility: a list with one selected: "gentle questions, i ask, i don't tell, selected"; the note reads after.

Acceptance: matches `1GQM-0`; rows recorded.

Tests: (snapshot) picked, yours, offline × light/dark/ax3, SE; (UI) "choosing a level moves the tick and saves"; (accessibility) audit.

Proof: page proof.

Watch out: a choice row's tick is ink, never blue (screen rule 14).

---

### P29 · ST-7 voice and listening                                          size: S
Place in the tree: settings › voice › ST-7
Repo · branch: NPRdoinglaundry · `ui/P29-voice`
Needs: C41, C44, C20 (menu for ↕), UI6.0      Unblocks: T06

Why: you choose the voice of your briefs and episodes, hear it first, and set how fast they play.

Inputs: Paper ST-7 `1GS3-0` (action `1GSQ-0`, pill `1GSR-0`, hairline `1GSO-0`, value `1GSG-0`, label `1GSD-0`, segmented `1GS8-0`), dark `2HHJ`; snapshot copy: "voice · warm · one voice behind every show · sample" · "speed · for briefs and episodes · 1×" · "talk or read · talk · read · talk: retro speaks its replies. read: words only."; contract 06 §2; Q2, Q3, Q4.

Paper values (ST-7): bar title "voice and listening"; rows without wells: "voice" / "warm · one voice behind every show" · raised pill (play icon) "sample"; hairline inset 24; "speed" / "for briefs and episodes" · "1×" (`--text-md` `--color-text-secondary`) ↕. Then a section (gap 8): label "talk or read", the segmented control (as ST-2's) "talk · read" with "talk" selected, caption "talk: retro speaks its replies. read: words only." (Geist 12 `--color-text-label`).

Spec:
- Row "voice" / "<name> · one voice behind every show" with C44's sample pill; tapping the row (not the pill) opens a C20 menu: warm · steady · bright (selected marked), choosing writes at once.
- Row "speed" / "for briefs and episodes" · "1×" ↕ → C20 menu: 0.8× · 1× · 1.25× · 1.5× (figures in mono, they count).
- "talk or read": hidden in v1 (Q2 lean). If the founder keeps it, it's a `RSegmented` with its caption.

Interaction sheet:

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | tap voice row | C20 menu grows from the value | C20 choreography | `select` on settle | fade |
| 2 | choose a voice | menu closes; value blur-replaces | `popoverExit` | `select` | fade |
| 3 | sample | C44 | C44 | — | — |
| 4 | speed | C20 menu; choose 1.25× | as 1–2 | `select` | fade |

State table: `full`, `samplePlaying`, `sampleFailed`, `offline` (voice disabled; speed works).

Accessibility: "voice, warm, one voice behind every show, button, opens a menu"; "speed, 1 times, button".

Acceptance: matches `1GS3-0` without the talk-or-read group (noted); rows recorded.

Tests: (snapshot) full, samplePlaying, offline × light/dark/ax3, SE; (UI) "choosing steady saves and plays its sample on request"; (UI) "speed works offline".

Proof: page proof.

Watch out: two sound sources: the sample stops if the person plays a brief from the mini-player, and vice versa.

---

### P30 · ST-8 what i've learned                                            size: S
Place in the tree: settings › learned › ST-8
Repo · branch: NPRdoinglaundry · `ui/P30-learned`
Needs: C41, C46, UI6.0      Unblocks: T06

Why: you can see how Retro is adjusting its questions to you, and it never pretends to have learned something it hasn't.

Inputs: Paper ST-8 `1GTG-0` (bar `1GTN-0` only), dark `2HIW`; C46; contract 06 §3. Different from YO-5 ("what i know about you"): this is about Retro's questions, not about you (design-reference §E P30).

Spec: `RSettingsPage(title: "what i've learned")` with C46 as its only content; pull to refresh is not offered (it changes daily).

Interaction sheet: arrive (cached, then fresh; changes blur-replace) · leave. No touches besides back.

State table: `learning`, `tooEarly`, `learnedOff`, `loading`, `error`, `offline` (cached, with the offline line).

Accessibility: the sentence is a header; audit passes.

Tests: (snapshot) learning, tooEarly, learnedOff × light/dark/ax3, SE; (accessibility) audit.

Proof: page proof.

Watch out: the page has no actions by design; don't add "reset" (the brain has no write).

---

### P31 · ST-9 account                                                       size: M
Place in the tree: settings › account › ST-9 (App Store lane)
Repo · branch: NPRdoinglaundry · `ui/P31-account`
Needs: C41, C42.2, C50.1, C50.2, UI6.0      Unblocks: P33, T06

Why: your plan as Apple has it, the way to manage it, getting a purchase back, signing out, and leaving for good, all in one place, all plain.

Inputs: Paper ST-9 `1GU5-0` (value `1GV2-0`, hairline `1GV0-0`, leaves-app `1GUU-0` + external `1GUV-0`, action `1GUQ-0` + sign-out icon `1GUM-0`, danger `1GU8-0`), dark `2HJL`; snapshot copy: "your plan · yearly · renews on 3 march · $199.99" · "manage subscription · in apple settings" · "restore purchases" · "sign out" · "delete account… · your entries, episodes and everything retro knows"; build notes "Account: sign out" (full-width secondary button: `sign-out` icon 20 `iconDefault` + "sign out" label medium; caption text-sm secondary "signed in with apple. your entries stay; sign back in any time."); contract 06 §6, §7, §8; App Store guidelines 3.1.1, 3.1.2, 5.1.1(v).

Paper values (ST-9): label "your plan"; a two-line row with no trailing, "yearly" / "renews on 3 march · $239.99"; hairline; "manage subscription" / "in apple settings" · ↗ 16 `--color-icon-muted`; hairline; "restore purchases" (title only, **no trailing affordance**). Then the sign-out block (top padding `--spacing-6` 24, inside the screen margin): a full-width raised button, min height 56, inline padding 16, gap 8, the raised stack, a 20pt sign-out glyph in `--color-icon-default`, label "sign out" Geist `--text-body` 17 medium `--tracking-card`; caption 8 below, centred, `--font-text` `--text-sm` 12 `--color-text-secondary`: "signed in with apple. your entries stay; sign back in any time." Then the danger block "delete account…" / "your entries, episodes and everything retro knows".

Paper vs docs: (1) the drawn price "$239.99" is an old price (D6: $199.99) and, either way, a typed price: the build shows StoreKit's localized price (PL6.4); the integrator updates the Paper text. (2) "restore purchases" has no affordance in Paper: the whole row is the target (as rows are), and its result shows as the row's subline ("restoring…" with the 6pt ring → "restored" / "nothing to restore on this apple id" / the error in `--color-status-danger-text`), so no pill is added (C42.1 is not used here).

Spec:
- **Plan group:**
  - the plan row "yearly" (or "monthly") with subline "renews on <date> · <Apple's price>"; trial: "free until <date>, then <price> a year"; cancelled: "ends on <date>"; billing issue: subline `statusDangerText` "apple couldn't take payment. update it in apple settings."; not a member (Q13): "none" and the next row is "become a member ›" (opens P07, the paywall).
  - leaves-the-app row "manage subscription ↗" / "in apple settings" → `manageSubscription()` (Apple's sheet in the app).
  - row "restore purchases" (whole row is the target; result in its subline, as above).
- **Sign out:** full-width `RButton.secondary` with the `sign-out` icon, then the caption with the provider from `signedInWith` → AC-2 (P33).
- **Danger zone:** "delete account…" / "your entries, episodes and everything retro knows" → C50.1 #4 (with the billing paragraph when `plan.renews`) → C50.2.

Interaction sheet:

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | manage subscription | Apple's sheet over the app | system | none | system |
| 2 | restore | subline "restoring…" with the 6pt ring → "restored"; plan row refreshes | ring; blur-replace | `confirm` / `error` | fade |
| 3 | sign out | AC-2 sheet rises | `sheet` | `sheetSnap` | fade |
| 4 | delete account… | C50.1 #4 → (Apple) → C50.2 → splash | dialog; cross-fade | `warning` in dialog | fade |
| 5 | become a member (not a member) | paywall P07 | push/sheet per P07 | none | fade |

Life: none; lit: none.

State table: `member`, `trial`, `cancelled`, `billingIssue`, `notMember`, `restoring`, `restored`, `nothingToRestore`, `deleteDialog`, `deleteDialogRenewing`, `appleConfirm`, `deleting`, `offline` (manage, restore and delete disabled with "needs a connection"; sign out works and goes through AC-2's offline path).

Accessibility: "your plan, yearly, renews on 3 march, 199 dollars 99"; "manage subscription, opens apple settings"; the sign-out button reads with its caption; audit passes in member, notMember, offline.

SE: the caption under sign out stays (it says what happens); the plan subline wraps to two lines.

Acceptance: every state matches `1GU5-0` in light, dark, AX3 and SE; rows 1–5 recorded; **no price literal in the view** (PL6.4's lint).

Tests: (snapshot) member, trial, billingIssue, notMember, offline × light/dark/ax3, SE; (UI) "restore shows restored"; (UI) "manage subscription asks Billing for Apple's sheet"; (UI) "delete account asks first, and cancel deletes nothing"; (accessibility) audit.

Proof: page proof; recordings of 2, 3 and 4 (sample), and on staging later (T06).

Watch out: the price string comes from StoreKit in the person's currency; with no price yet, show the plan without one, never a cached or typed price.

---

### P33 · AC-2 signing out                                                   size: S
Place in the tree: settings › account › AC-2 (App Store lane)
Repo · branch: NPRdoinglaundry · `ui/P33-signing-out`
Needs: C48, P31      Unblocks: T06

Why: nothing is lost when you sign out.

Inputs: Paper AC-2 `1GVP-0`, sheet `1GVR-0`, dark `2L1K-0`; handoff "AC-2 signing out"; PL3.7e.

Spec: P31 presents C48 over itself (ST-9 visible behind, scaled and dimmed per C19.1). The page wires `unsentCount`, `sendThenSignOut()` and `signOut(force:)`. On `done`, the app root shows AC-1 (P32: `hasSignedInBefore` is kept).

Interaction sheet: as C48's table, plus arrive (from P31 row 3) and leave (cancel → ST-9 unchanged; done → AC-1 with a 140 cross-fade).

State table: `nothingWaiting`, `unsent`, `sending`, `offlineUnsent` (→ stuck).

Accessibility: audit passes in unsent and nothingWaiting.

Tests: (snapshot) through C48's states over ST-9, light/dark/ax3, SE; (UI) "signing out with nothing waiting lands on welcome back"; (UI) "an unsent entry sends before sign-out".

Proof: page proof; a recording on sample, then staging (T06).

Watch out: SE isn't drawn for AC-2 (design-reference §E): the sheet flexes, actions stay in the thumb zone; note it in the PR.

---

### PI3 · Your invites                                                       size: M (needs a Paper drawing first)
Place in the tree: settings › invites › PI3
Repo · branch: NPRdoinglaundry · `ui/PI3-your-invites`
Needs: C41, C49, UI6.0, the approved drawing (Q7)      Unblocks: T06

Why: you have three ways to bring a friend in; each is a gift, used once.

Inputs: contract 00 §4, contract 06 §9; Q7; the invite board `2H3N-0` (another session's, read only; this page is drawn after it).

Spec (lean, until drawn): `RSettingsPage(title: "your invites")`, one plain line (founder copy, lean "three links, each lets one friend straight in. each works once."), then three C49 rows. All used: the line becomes "you've given all three. thank you." (copy to confirm). No "get more" (the founder adds invites by hand, BE0.12 admin).

Interaction sheet: arrive (cached) · share (C49) · leave.

State table: `three`, `someUsed`, `allUsed`, `offline`, `loading`.

Accessibility: rows read in order; audit passes.

Tests: (snapshot) three, someUsed, allUsed × light/dark/ax3, SE; (UI) "sharing an unused invite opens the share sheet"; (accessibility) audit.

Proof: page proof against the drawing.

Watch out: never show the code; never log the link (PL3.7h).

---

### T06 · Settings and account flow test                                     size: M
Place in the tree: settings › flow test
Repo · branch: NPRdoinglaundry · `ui/T06-settings-flow` (with the integrator)
Needs: P23–P31, P23a, P25a, P27a, P33, PI3, UI6.0 (sample run); W6 and local staging (live run)      Unblocks: ship gate G6

Why: one test proves every settings path works together, first on sample data, then on the real backend and brain with a test account, including the three App Store requirements.

Inputs: testing.md §1 layers 8–9, §3 T06; T02 launcher; `scripts/staging-up.sh`; T08's seeded accounts (BE0.S).

Spec (XCUITest, `-Data sample` then `-Data live -Environment local -Account <seeded>`):
1. Open settings from YO-1's picture; every ST-1 row opens its page and back (identifiers).
2. Brief: turn on (accept the notification alert on sample: `addUIInterruptionMonitor`), set 08:30, choose "long"; ST-1 reads "8:30".
2b. Notifications: turn "hide the words" on; with iOS notifications denied (sample: `iosDenied`), the iOS row shows.
3. Voice: choose steady, play its sample, set 1.25×.
4. How straight: choose "gentle questions", then "let it decide": the note returns.
5. Sources: sync a connected source; disconnect it (dialog, confirm); it reads "connect".
6. Privacy: turn background reading off and on; request an export; (live) wait for ready, save opens the share sheet.
7. Account: restore purchases (sandbox on live: a StoreKit test configuration for sample, a sandbox account on staging) shows "restored"; manage subscription requests Apple's sheet (asserted through a test hook on `Billing.SubscriptionManagement`).
8. Sign out with one unsent entry (sample: one queued; live: airplane-mode toggle via the stub reachability), "send, then sign out", lands on AC-1.
9. Delete my data (live, a second seeded account): onboarding's first question appears; the account still signs in.
10. Delete account (live, a third seeded account, Apple-signed without a stored token): Apple's confirmation (sandbox), "deleting", goodbye, splash; signing in again creates a new waitlisted user; the app container is empty (a debug-only hook lists it).
11. Offline pass: every page opens from cache with the offline line, and every network row says "needs a connection".

Acceptance: the whole test passes on sample in CI nightly and on local staging before G6; App Store items 7 and 10 are recorded for the founder.

Tests: the steps above, each a named test (`settingsRowsOpenTheirPages`, `briefTurnsOnAtYourTime`, …, `deletingTheAccountErasesEverything`).

Proof: test output; the staging recordings; cost of the run logged as test spend (exports and samples cost nothing; a brief on staging does).

Watch out: steps 9–10 destroy their accounts: they use dedicated seeded accounts, re-seeded by `staging-up.sh`, never the founder's.
