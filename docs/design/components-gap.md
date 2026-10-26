# Components gap: Paper "02 · components" vs DesignSystemV2
Written 26 Oct 2026 by V2 lane 0 (read-only on Paper file `01M5D5J321P5X86ZT58002B7NT`, page `02 · components`; repo `main` @ 52f3fb48). Copy: `pipeline/screens/components-gap.md`.

**Bottom line.** Most parts exist. **Ten** Paper components that two or more V2 screens need are missing or the wrong shape; lane 0 builds them once, in their own homes, before (or alongside) the screen lanes. Everything else that is missing is used by one screen only, so that screen's lane builds it inside its own PR.

How the page was read: the three index rows (233J-0 current set, 233M-0 approved parts, 233P-0 legacy) plus every board's header; named copies (`c:component/variant/state`) from each board's tree. 15 current boards (settings rows over three), 7 approved parts (40, 41, 42, 44, 45, 48, 50), note board 3OIH-0, legacy boards c1, c3–c6 (no c2). The "early splash study" in 233Q-0 has no board.

Status words: **exists** (reuse it) · **differs** (exists, but a state/variant/value Paper draws is not built) · **missing** · **in flight** (an open PR adds it) · n/a (legacy or an unchosen variation).

## 1. Every component on the page

| Paper component | board · node ids | states Paper draws | Swift | status | V2 screens |
|---|---|---|---|---|---|
| the-mark/38 | SUL-0 · V4O-0 (glyph V4P-0) | disc + glyph | Parts/RMark (38) | differs: Swift is the wordless disc; Paper puts the brush glyph inside (founder 21 Oct) | (ON) |
| the-mark/22 | SUL-0 · V4T-0; in use BB3-0 | 22 + glyph | RMark `.header` | in flight (#198) | JR-2, PC-3, YO-4 |
| the-mark/16 | SUL-0 · V4W-0 | 16 | — | missing | EX-4 |
| voice-composer/listening, speaking, muted-empty, muted-typing | AZN-0 · AZX-0, B0C-0, B0R-0, B10-0 | 4 | RVoiceComposer | exists; Paper-exact look in flight (#202, choice open on 3OIH-0) | (JR-1) |
| icon-button/wash/{rest, mic-off, pause, retry, add} | AZY-0, B4U-0, GX5-0, GXG-0, E2L-0 | rest | RIconButton (36 / 32 / 44) | exists; `.sheetHeader` 34 in flight (#198) | JR-2/3/4, GL-1/2, YO-3, ST-*, PC-1 |
| icon-button/raised/send | GGT-0 | rest | inside RVoiceComposer | exists | — |
| brief-card/artwork/rest | B17-0 · B3G-0 (legacy states 206-0) | rest | RBriefCard (rest/played/starting/quiet/making/error/offline) | exists (Swift has more states than the master) | (JR-1) |
| **tab-bar/system/rest + tab-bar/item/{selected, rest}** | B18-0 · B3X-0, B4A-0, B46-0; G0U-0, GXU-0 | journal selected | — (RProgressBlur exists for the edge) | **missing** | PC-1, GL-1, YO-1, YO-2 (+JR-1, ON-13) |
| **top-bar/title/rest** | B19-0 · B4R-0; PC-1 FZM-0, H0D-0 | rest | RTopBar `.journal(title:collapsed:openDrawer:)` | **differs**: drawer button required; no variant without a leading button or with a trailing slot (GL-1 add, YO-1 list + picture) | PC-1, GL-1, YO-1, YO-2 |
| top-bar/label/{rest, scrolled} | B19-0 · B5B-0, B5W-0; DQR-0 | collapsed, scrolled | RTopBar `.label` / `.journal(collapsed: true)` | exists (scrolled blur is the page's RProgressBlur) | JR-3 |
| top-bar/settings/rest | DY4-0, DJ7-0, DMG-0 | rest | RTopBar `.settings` | exists | ST-1..9, YO-5 |
| top-bar/entry/{rest, editing} | E2J-0, E3T-0; G8L-0 | rest, editing | RTopBar `.entry` | exists | JR-4, GL-2, YO-3 |
| top-bar/onboarding | GE1-0, GFK-0 | rest | private in QuestionsPage | differs: page-private (core-12; not V2's to move) | (ON) |
| button/text/rest | E2Q-0 | rest | RButton `.text` | exists | JR-4, GL-2, YO-3 |
| you-map/orbits/rest | B1A-0 · B6Q-0 | rest (labels maya, running, the river, work) | Parts/RYouMapRest | differs: no labels, not interactive | YO-1 |
| message/mine/{rest, voice, failed} | B8J-0, B87-0, B8L-0, B7O-0 | 3 | RMessageBubble, RVoiceBubble | exists | (JR-1) |
| message/theirs/rest (+ "because" row) | B8B-0 (because B8D-0), B83-0 | with/without because | RRetroLine | differs: no "because · … ›" row | (JR-1) |
| guess-card/open | B7Q-0 (confirmed legacy 27U-0) | open | RGuessCard | exists | (JR-1) |
| player-sheet/brief/playing (+ ready, held, menu) | B1C-0 · B9C-0; BBA-0, BDA-0, BFB-0, BJ4-0, G4M-0 | 4 | RSheetHost + Features/Player | in flight (#198) | JR-2, PC-3, YO-4 (+PC-2) |
| scrubber/chapters | B9Z-0 (held BDV-0) | rest, held | RScrubber | exists | JR-2 (+PC-2) |
| transport/recess/playing | B9G-0 (well B9J-0; "…" B9O-0) | playing | RTransport | differs: the "…" 44 is an empty slot | JR-2 (+PC-2) |
| menu/more/open | BFC-0 (chapters, download; 220 wide, 44 rows) | open | RMenu (`.title`, `.message`) | differs: no "more" kind | JR-2 (+PC-2) |
| pill/neutral/{rest, pressed} | D90-0 · D9G-0, D9N-0; BA8-0, B7U-0 | 2 | RPill `.neutral` | exists | JR-2, PC-3, GL-2, YO-4 |
| pill/raised/{rest, pressed} | D9Z-0, DA6-0; IYS-0, IYU-0 | 2 | RPill `.raised` / `.action` | exists; Paper look in flight (#202); connect pill in flight (#199) | GL-1, ST-2..5, ST-7 |
| pill/lit/{rest, pressed} | DAI-0, DAP-0 | 2 | RButton `.primary` | exists (name differs) | AC-2, EX-1 |
| **button/lit/play (44 round)** | FXV-0; brief card | rest | private `RPlayWellStyle` in RBriefCard | **differs**: not reusable | PC-1 (+JR-1) |
| pill/choice/{on, off} | GSR-0, GSW-0, GGB-0 | 2 | — | missing | (ON-4 only) |
| brief-item/now/playing | B1D-0 · BI2-0 | playing | — | missing | JR-2 |
| brief-item/next/rest | BHX-0, BHU-0 | rest | — | missing | JR-2 |
| recap-card/rest | BHK-0, BIS-0 | rest | — | missing | (JR-1) |
| label/section, label/day | DMU-0; DPW-0, DQ2-0, DRP-0 | rest | Parts/RSectionLabel | exists | ST-*, YO-5, PC-3, GL-2, YO-2, JR-3 |
| **settings-row/value ("↕ quick pick")** | DF7-0 · DMV-0; DS7-0 · DYJ-0, E07-0; DVT-0 | rest | RSettingsRow `.value` / `.nav` | **differs**: no "↕" trailing (decision 04) | ST-2, ST-7 (+ST-1) |
| settings-row/switch/rest | DS6-0 · DUG-0, DUO-0; K1V-0 | off/on | RSettingsRow `.toggle` | exists | ST-2, ST-5, YO-2 |
| settings-row/choice/{chosen, rest} | DUX-0, DV6-0, DVD-0 | 2 | RSettingsRow `.choice` | exists | ST-6 |
| settings-row/leaves-app/rest | DVL-0 | ↗ | RSettingsRow `.external` | exists | ST-9 |
| settings-row/danger/rest | DW2-0 | rest | RSettingsRow `danger:` | exists | ST-4, ST-5, ST-9 |
| settings-row/source/{rest, problem, syncing} | DWC-0, DWQ-0, DX5-0, DXJ-0 | 3 | RSourceRow | exists; connect pill in flight (#199) | ST-3 |
| hairline/inset, hairline/inset-icon | DNH-0, DUM-0 / DWM-0, DX1-0 | rest | Parts/RParts1 RHairline | exists (check the inset-icon offset vs DWM-0) | ST-* |
| switch/default/{off, on, pressed, disabled} | DS5-0 · DSR-0, DSW-0, DT1-0, DT6-0 | 4 | RSwitch | exists | ST-2, ST-5, YO-2 |
| segmented/3/{rest, disabled}, segmented/2/rest | DTG-0, DTY-0, DTQ-0 | 3 | RSegmented | exists | ST-2, ST-7 |
| search-field/journal/{rest, typing} (36, wash) | DF8-0 · DPR-0, DRF-0, G7T-0, G85-0 | 2 | RSearchField (48, sunken, mic) | differs: no 36 wash variant | JR-3 |
| entry-row/drawer/{here, rest, pressed, unsent} | DPY-0, DQ4-0, DRY-0, DQA-0, DRR-0 | 4 | REntryRow | differs: no "here" state | JR-3 |
| row/drawer-foot/rest | F2M-0 ("settings · v1.0") | rest | — | missing | JR-3 |
| drawer container (316 underlay, journal pushed right) | DPP-0 / DPO-0, DHL-0; DRD-0, G7R-0, G83-0 | open, searching, nothing yet, no results | — | missing | JR-3 (shell hosts it) |
| empty-mark/{journal, search} | G7Y-0, G8F-0 | 2 | REmptyLine | exists | JR-3, GL-1, YO-1, YO-5 |
| **entry/words/{rest, editing}** | E2U-0, E44-0, G8U-0 | 2 | — | **missing** | JR-4, YO-3 |
| **link/conversation/rest** | E2Z-0 | rest | — | **missing** | JR-4, YO-3 |
| took-row/claim/{rest, noted} | E35-0, E3C-0 | 2 | — | missing | JR-4 |
| row/destructive/rest | E3J-0 ("delete entry") | rest | — | missing | JR-4 |
| dialog/destructive/rest | E4B-0 (scrim E4A-0) | rest | RDialog | exists | JR-4, ST-4, ST-5, ST-9 |
| onboarding-progress, onboarding/question, /your-words, /quick-answers, privacy-mark | GDY-0, GFS-0, HG8-0; GEA-0, GEB-0, GG6-0; HFX-0 | — | RParts2 / page-private (core-12) | exists / differs (page-private, core) | (ON) |
| **mini-player/{playing, failed}** | GT1-0 · GX0-0, GXB-0; in use H0Q-0 (legacy pressed 212-0, buffering 21A-0) | playing, failed | — | **missing** | PC-1 (+every tab while playing: GL-1, YO-1, YO-2, JR-1) |
| episode-tile/hero/{rest, making} | FWU-0 · FXR-0, FZ1-0 | 2 | — | missing | PC-1 |
| episode-tile/square/rest | FYG-0, FYL-0, FYQ-0, FYV-0 | rest | — | missing | PC-1 |
| status/syncing | FZ5-0 | spinning | RParts2 RSpinner | exists | PC-1, ST-3 |
| **claim/stated, claim/asked** | G1E-0 · G2A-0, G3C-0 | stated, asked (dashed) | — | **missing** | PC-3, YO-4, GL-2 |
| evidence-row/rest | G2G-0, G2Q-0, G2Z-0, G3J-0 | rest | REvidenceRow (`.kind`) | exists | PC-3, YO-4, GL-2 |
| goal-card/{rest, a gap, too early, guess} | ITY-0 · IXB-0, IXS-0, IY9-0, IYO-0 | 4 | — | missing | GL-1 |
| goal-row/faded | IYZ-0 | ended | — | missing | GL-1 |
| goal-card/{words, week, dusk} | LOV-0, LP2-0, LQ4-0 | unchosen B/C/D | — | n/a (unchosen, archive) | — |
| search-field/{rest, typed} (48, mic) | JZQ-0 · K0B-0, K0J-0 | 2 | RSearchField | exists | YO-1, YO-2 |
| answer/{found, abstained} | K0U-0, K24-0 | 2 | — | missing | YO-2 |
| source-result/rest | K14-0, K1C-0, K1K-0 | rest (number well) | REvidenceRow lacks `.number` | missing (a variant) | YO-2 |
| legacy c1 QW-0, c3 X2-0, c4 102-0, c5 1XE-0, c6 25P-0 | toast 2AM-0, dialog 2AC-0, empty 2AS-0, transport 1XJ-0, paywall 123-0, title menu 107-0 | reference | RToast, RDialog, REmptyLine, RTransport, RMenu `.title` | n/a (superseded) | — |

## 2. Missing, needed by two or more V2 screens: lane 0 builds these (one small PR each)
| # | Component | Paper | Home | Screens | Order / note |
|---|---|---|---|---|---|
| 1 | **Tab bar** (system + item, progressive-blur edge) | B18-0 · B3X-0, B4A-0, B46-0; G0U-0, GXU-0 | `Components/RTabBar.swift` | PC-1, GL-1, YO-1, YO-2, JR-1, ON-13 | first: the shell needs it |
| 2 | **Top bar · title** (no leading button, optional trailing) | B4R-0; FZM-0, H0D-0 | `RTopBar` new `.title` variant | PC-1, GL-1, YO-1, YO-2 | second: every tab page's head |
| 3 | **Claim** (stated / asked) | G2A-0, G3C-0 | `Components/RClaim.swift` | PC-3, YO-4, GL-2 | |
| 4 | **Mini-player** (playing / failed) | GX0-0, GXB-0, H0Q-0 | `Components/RMiniPlayer.swift` | PC-1 + every tab while playing | component only (sample state); the shell mounts it later |
| 5 | **Entry words** (rest / editing) | E2U-0, E44-0, G8U-0 | `Components/REntryWords.swift` | JR-4, YO-3 | |
| 6 | **Conversation link** | E2Z-0 | `Components/RConversationLink.swift` (or a case of REntryWords) | JR-4, YO-3 | |
| 7 | **Settings row "↕ quick pick"** | DMB-0 note, DMV-0 | `RSettingsRow.Trailing.pick(String)` | ST-2, ST-7 | additive case |
| 8 | **Lit play button 44** | FXV-0 | `RButton` `.play`, lifted from RBriefCard's private style | PC-1, JR-1 | RBriefCard is leased by #201 (GR.ready): wait for it |
| 9 | **"More" menu + the transport's "…"** | BFC-0, B9O-0 | `RMenuKind.more` + `RTransport` `.more` | JR-2, PC-2 | after #198 (player is core; check it doesn't already do it) |
| 10 | **The mark · 16** | V4W-0 | a size in `Parts/RMark.swift` | EX-4 | after #198 adds the glyph |

## 3. Missing, needed by one screen only (the screen's lane builds it)
- JR-2: brief-item/now (BI2-0), brief-item/next (BHX-0, BHU-0)
- JR-3: drawer container (DPP-0), row/drawer-foot (F2M-0), search-field/journal 36 (DPR-0, DRF-0), entry-row "here" (DPY-0)
- JR-4: took-row/claim (E35-0, E3C-0), row/destructive (E3J-0)
- PC-1: episode-tile/hero (FXR-0, FZ1-0), episode-tile/square (FYG-0)
- GL-1: goal-card (IXB-0, IXS-0, IY9-0, IYO-0), goal-row/faded (IYZ-0)
- YO-1: the labelled, interactive you-map orbits (B6Q-0)
- YO-2: answer/found + abstained (K0U-0, K24-0), source-result as an REvidenceRow `.number` leading (K14-0)
- JR-1 (not V2): recap-card (BHK-0), the "because" row in message/theirs (B8D-0)
- ON (core): pill/choice (GSR-0, GGB-0)

## 4. Which V2 groups this unblocks
- **Settings (ST-1..9)** and **Account (AC-1 recheck)**: unblocked now, except ST-2/ST-7's "↕" row (#7, small).
- **You (YO-3, YO-5)**: unblocked now except YO-3's entry words/link (#5, #6). **YO-1, YO-2** need the tab bar and title bar (#1, #2). **YO-4** needs the claim (#3) and the player sheet (#198).
- **Journal V2**: JR-3 needs only its own parts (the shell hosts the drawer); JR-4 needs #5, #6; JR-2 needs #198 and #9.
- **Podcasts**: PC-1 needs #1, #2, #4, #8; PC-3 needs #3 and #198.
- **Goals**: GL-1 needs #1, #2 (+ its own goal card); GL-2 needs #3.
- **Outside**: EX-1..3 views unblocked; EX-4 needs #10.

## 5. Discrepancies (also logged in pipeline/screens/DISCREPANCIES.md)
1. SCREEN-MAP §5 lists "c:mini-player/playing, paused"; part 45 draws playing + failed (legacy c5: pressed, buffering, couldn't play). No paused state is drawn.
2. Paper names the lit tier `c:pill/lit` (D90-0); Swift calls it `RButton.primary`.
3. SCREEN-MAP §5 still says c:privacy-mark "in #196"; #196 merged it page-private in Features/FirstRun/Privacy.
4. SCREEN-MAP §5 lists c:top-bar/onboarding as missing; it exists privately in QuestionsPage.
5. RMark's header says "the wordless disc"; Paper SUL-0 (founder 21 Oct) puts the brush glyph in all three sizes.
6. RTransport says the "…" has "no destination yet"; Paper B1C-0 (founder 20 Oct) gives it the chapters + download menu.
7. Approved-parts boards FX0-0 (part 40), G1K-0 (part 41), NVD-0 (part 50 map versions B/C) still carry "needs you" red dots on a page meant for approved masters.
8. `c:top-bar/label/rest` (B5B-0) is the collapsed journal in Paper, while Swift's `.label` is the drawer's bar: one Paper name, two Swift variants.
9. ST-1's untitled group (DMR-0, DYF-0) still shows a stale "listening" section label (DOU-0).
10. 233P-0 still describes the legacy row as "c1–c6 and an early splash study"; c2 and the splash study are gone.
