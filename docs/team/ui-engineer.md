# UI engineer · plan

You build every pixel of the new app: the remaining components, the 37 screens plus the invite and force-update screens, and the signature moments M01–M14. Everything is held to the standard of the parts already merged. Paper is your source of truth. Your building blocks are `DesignSystemV2/`. Your data comes only through each flow's data protocol, never the network.

Before your first byte, read [README.md](./README.md), [context.md](./context.md), [testing.md](./testing.md), [byte-card.md](./byte-card.md) and `docs/design/m14-agent-checklist.md` §2. Every byte you take has a card. The full cards are in [ui/](./ui/), and the outline cards are in [ui/later.md](./ui/later.md).

## 1. Mission

The founder's bar, in their words: "components are high craft; I don't want them to feel otherwise in the app." You finish the components the journal needs, then build the journal's four pages on **sample data shaped exactly like contract 02**. When the integrator's wiring PR swaps in live data, nothing on screen changes except that it's real. Then you do the same for the other six flows, in ship order.

What "done" means for you: every state Paper draws is built and proven next to Paper's own node, in light, dark and AX3. Every touch has its press, haptic and outcome motion, and can be interrupted. Every page has passed its accessibility audit and its flow test.

## 2. Ownership

| You own | You never touch |
|---|---|
| New files in `DesignSystemV2/Components/**` and `DesignSystemV2/Parts/**` | `RType.swift`, `RDepth.swift`, `RMotion*.swift`, `RMotionLab.swift`, `Generated/**`, `design-system/tokens/**`, `RetrospectApp.swift`, the app shell, workflows, `.xcodeproj` package and target settings (all the integrator's) |
| `Features/<Flow>/**`: screens, view models, `Sample/` data | `Platform/**` except reading the flow protocols and `Backend.Failure` (plumbing) |
| `Features/Launcher/**`: the views half of T02 | `Services/`, `Views/`, `Models/` (the old app, which is frozen) |
| Snapshot tests in `RetrospectSnapshotTests/**` and UI tests in `RetrospectUITests/V2/**` | `backend/**`, the agent repo, `docs/team/**` |
| `docs/design/sample-data-ledger.md` (you add rows; the wiring PR removes them) | |

**Shared-file requests.** Anything that changes a shared file goes to the integrator, who makes the change in its own PR: a new token, a motion helper, the blur modifier (UI0.1), a launch-argument hook in the app root (T02), a test target or package (T01). Text styles and constants used by only one component live in that component's file, which is the current pattern.

## 3. Ground truth (21 Oct)

- **Merged on `main`:**
  - foundation: tokens, `RType` (Dynamic Type for SF Pro and mono, #49), `RDepth`, `RMotion`, `RHaptic`, the motion modifiers `.rPress`, `.rAppear`, `.rPop`, `.rShake`, `.rBlurReplace`, `.rFloat`, `.rLifeHost`, `.rScrollLag`, and the lab
  - parts: `RSymbol`, `RIconWell`, `RHairline`, `RStatusDot`, `RProgressHairline`, `RKnowsYouTrack`, `RSpinner`, `RWaveform`, `RSectionLabel`
  - components: `RButton` (C01–C03), `RSegmented` (C08), `RSettingsRow`/`RSettingsGroup` (C09)
- **In review** (the integrator merges them in phase 0):
  - `RArtwork` and grain (#42)
  - `RIconButton` 36/32/44 (#44)
  - `RPill` (#45)
  - `RTag` (#46)
  - `RToast` (#48)
  - `RSwitch` (#50)
  - `RSourceRow` (#52)
  - `RSearchField`/`RSunkenField` (#53)
  - `RComposer`/`RGrowingField` (#54)
  - squircles `RShape.rect`/`RShape.pill` with the literal check (#55)
  - `RVoiceComposer` (#56)

  You start every byte from a `main` that has them.
- **Paper master** is file `01M5D5J321P5X86ZT58002B7NT`:
  - approved screens: page `p-J-0` "06 · everything · latest"
  - component masters: `p-3-0` "02 · components"
  - decided parts: `p-C-0` "02b · decisions made"
  - parts being reviewed: `89Q-0` (journal sub-components, round 1) on the approvals page `p-G-0`

  Each card names its exact nodes.
- **The design reference** ([reference/design-reference.md](./reference/design-reference.md)) has every component's anatomy, states, tokens and motion; the signature moments; the 33 screen rules; the craft checklist; the per-screen table (§E); and 55 conflicts (§F). Each card cites its section.
- **The motion spec** is `design-system/principles/motion-system.md`, summarised in reference §B. **The blur spec** is `docs/design/progressive-blur.md`.
- **Gaps already decided:**
  - **C15 talk button:** not built (`RVoiceComposer` replaced it; no approved screen uses it).
  - **C11 plain text field:** not built until a screen draws one.
  - **Force-update and invite screens:** drawn in Paper first, by the integrator.
  - **Stale values to ignore:**
    - amber mini-player fill (the 2pt line stays)
    - `size.miniPlayer` 42 (it's 64)
    - `size.dialog` 300 (it's 342)
    - `paywall.md`'s prices and layout (the founder's prices are $19.99 and $199.99)

## 4. The seam: flow protocols and sample data

1. **The integrator writes each flow's protocol** in `Platform/Flows/<Flow>.swift`, from the contract: plain `Sendable` model structs and an `@MainActor @Observable` data object with async actions. For the journal, contract 02 maps to these needs, which are what your screens will call. If the protocol lacks one, you stop and ask.

   | Screen need | Contract 02 | Shape the views expect |
   |---|---|---|
   | Today's thread | §2 `GET /v2/entries/today` | `today: Loadable<[JournalEntry]>`, oldest first; each entry carries its outbox state `.waiting / .sending / .sent / .failed` |
   | Send an entry | §2 `POST /v2/entries` (via the outbox) | `send(text:) async`, `sendVoice(_:) async`, `retry(clientEntryId:)`; never throws to the view, state lands on the entry |
   | The acknowledgement | §2 (on the phone) | `acknowledgement(for: clientEntryId) -> String?`, set only once the entry is `.sent`, and never the same line twice in a row |
   | Today's brief | §3 | `brief: Loadable<BriefSlot>`, where `BriefSlot` is `.off`, `.making(readyBy:)`, `.ready(Brief)`, `.quiet(line)` or `.none` |
   | Guesses | §4 | `guesses: [Guess]` (empty when `speaking` is false); `answer(_:verdict:) async -> GuessOutcome` |
   | All entries and search | §5 | `entries(cursor:query:) async -> Page<JournalEntry>` with `matches` ranges |
   | One entry | §5, §6 | `entry(id:)`, `took(id:) -> Took` (items and reading), `edit(id:text:)`, `delete(id:)` |
   | Not right | §6 | `correct(text:about:) async -> CorrectionOutcome` (`.applied(echo)`, `.confirm(candidates)`, `.askOwnWords(quote, writtenOn)`, `.notACorrection`) and `confirm(…)` |
   | Connectivity | contract 00 | `isOnline: Bool` from Platform, read through the flow object |
   | Playback | the player protocol (`Platform/Flows/Playback.swift`, integrator, from plumbing's PL audio work) | `state` (`.idle`, `.buffering`, `.playing`, `.paused`, `.ended`, `.failed(Backend.Failure)`, `.offline`), `position`, `duration`, `parts`/`chapters`, `play()`, `pause()`, `seek(to:)`, `skip(by:)` |

2. **You write the sample data**: `SampleJournalData` in `Features/Journal/Sample/` (byte UI1.0) and `SamplePlayback` in `Features/Player/Sample/` (byte UI3.0).
   - Content is **invented, plausible and lowercase**, never a real person's words (context.md §3; contracts rule 8).
   - Sample data is **scenario-driven**: one `JournalScenario` enum value per state any journal screen draws. T02 selects them by name.
   - Sample data is **deterministic**: an injected clock, no randomness, and "loading" is a task that never resolves.
   - Every value is logged in `docs/design/sample-data-ledger.md`.
3. **Screens take the protocol** (`any Flows.JournalData`, `any Flows.Playback`), injected through the seam's own environment keys (`@Environment(\.journalData)`, `@Environment(\.playback)`, in `Platform/Flows/FlowEnvironment.swift`; decided 21 Oct). Every seam type lives under `Flows` (`Flows.Journal.Entry`, `Flows.Loadable`, `Flows.Failure`; cards that say `Backend.Failure` mean `Flows.Failure`). They never take a concrete type and never import `Platform/Backend`. A view model exists only where a screen has its own logic (for example the drawer search debounce). Everything else reads the flow object directly.
4. **The wiring PR** (the integrator's) swaps `Sample…` for `Live…` in one line per flow and deletes the ledger rows. If anything on screen changes beyond the content, that's a bug in this seam, and it goes in the findings log.

## 5. How you work

**The loop for every byte:**
1. Read the card, the contract section, the reference section and the Paper nodes.
2. Run `df -h /` (stop under 5 GB) and branch `ui/<id>-<slug>` off fresh `origin/main` in your own worktree.
3. Take values from Paper with `get_jsx` (includeNodeIds false) and `get_computed_styles`, never from screenshots. Write each value's token into the card's table in your PR body.
4. Build the smallest thing first: parts, then the component, then its gallery entry and `#Preview`s, one per state.
5. Write the named tests in the same PR (snapshots in light, dark and AX3; plus unit, accessibility and UI tests where the card asks).
6. Check headlessly on your simulator, `agent-a 17 Pro` (`3E962F9F-…`), with derived data in `dd-ui`:
   - Launch with T02's flags and screenshot with `simctl io <udid> screenshot`.
   - Record motion with `simctl io <udid> recordVideo --codec h264`, then compare stills frame by frame.
   - Use iPhone SE (`6804ADCD-…`) only after asking the integrator.
   - Never open the Simulator window; never create, clone or delete a simulator or runtime.
7. Put each screenshot next to Paper's `get_screenshot` of the same node. Fix every difference, or list it as a decision with the rule behind it.
8. Push once and report in the README §8 format.

**Standard proof** (every component PR; cards add to it):
- snapshots in light, dark and AX3 for every state
- side-by-side images against the named Paper node
- a recording of each motion on the card's interaction table, including one interrupted mid-motion
- VoiceOver labels listed as read by the UI test
- the literal check, lint and format green

**Standard proof for pages** adds:
- the interaction sheet, built as written
- `performAccessibilityAudit()` passing
- the flow's XCUITest on sample data
- an SE screenshot
- a hitch check (§8)

**How a component is shaped in code** (the merged pattern; the ios-reusable-components skill matches it):
- one `public struct R<Name>: View`, with the variant as an enum and the state as an enum or `Bool`s that mirror Paper's state names
- styling only from tokens; motion only from `RMotion` and the modifiers; haptics only through `.sensoryFeedback(RHaptic.x, trigger:)`, on the same frame as the visual change
- corners only `RShape`
- an `#Preview` per state, plus a gallery page reachable from T02 (`-Screen gallery.<id>`)

**Interruptibility:** every gesture-driven motion is a spring, and a new touch retargets it mid-flight. Nothing waits for an animation to finish before accepting input. Prove it with the interrupted recording.

## 6. The decomposition tree

Design down, build up. Each line at the bottom of a branch is one byte. IDs in **bold** have a full card, and the rest have outline cards in [ui/later.md](./ui/later.md). Shared components are built once, under the first flow that needs them.

```
Product · the new Retrospect app
├── 0 Foundations for the UI (phase 0)
│   ├── **T01** snapshot harness ─ **T02** screen launcher (views half) ─ **UI0.1** progressive-blur modifier (request to the integrator)
├── 1 Journal (contract 02) ─ flow test T04
│   ├── **UI1.0** SampleJournalData + ledger           ── **UI3.0** SamplePlayback
│   ├── P09 JR-1 journal ─ **P09**
│   │   ├── **C17** top bar ── journal variant (drawer btn, inky title ⇄ small name), settings, entry, onboarding*, sheet header*
│   │   │     └── parts: RIconButton 36 (#44) · title text styles (local)
│   │   ├── **C18** tab bar ── item (rest/selected/pressed) · bar · edge blur (UI0.1)
│   │   │     └── parts: tab glyphs, emphasis weights (journal exists; podcasts/goals/you emphasis glyphs = asset request)
│   │   ├── **C26** brief card D ── **C26.1** card (rest, pressed, played, pending, error, offline) · **C26.2** making row + becoming ready · **C26.3** slim bar
│   │   │     └── parts: RArtwork mesh (#42), compact lit play (RButton lit 44), RSpinner
│   │   ├── **C30** message ── **C30.1** yours (bubble, sending, not sent, waiting) · **C30.2** Retro's acknowledgement line · **C30.3** voice-note bubble
│   │   │     └── parts: RWaveform (S12), retry glyph, day label (RSectionLabel)
│   │   ├── **C28** guess card ── card · tag (RTag guess #46) · why line · answer pills (RPill #45)
│   │   ├── RVoiceComposer (#56, merged)
│   │   ├── **C20** menu ── **C20.1** menu host + rows · message long-press menu (in P09)
│   │   ├── **C39** shared states ── **C39.1** skeleton + shimmer · **C39.2** empty line · **C39.3** error + try again · **C39.4** offline line + still working
│   │   └── **C22** mini-player (when something plays)
│   ├── P10 JR-2 today's brief ─ **P10**
│   │   ├── **C19** sheet + dialog ── **C19.1** sheet host (progress, drag, snap, scrim, behind) · **C19.2** dialog
│   │   ├── **C23b** player sheet, brief mode ── header · now card · next rows · played/quiet · transcript column + blur bands
│   │   ├── **C25** scrubber ── part capsules · thumb + bubble · times
│   │   └── **C24** transport ── tray · play well (playMorph) · skip buttons
│   ├── P11 JR-3 all entries ─ **P11**
│   │   ├── **UI1.1** drawer ── host (slide, page aside) · list (sticky days) · foot + blur
│   │   └── **C31** entry row ── rest · pressed · match highlight · unsent · waiting
│   └── P12 JR-4 one entry ─ **P12**
│       ├── **UI1.2** "what i took" + not right ── took row (rest, noted, waiting) · correction flow states
│       ├── **C32** evidence row (shared; first used by the took rows' sources and later PC-3/GL-2/YO-3/YO-4)
│       └── C19.2 delete dialog · entry words · voice-note play row · editing frame
├── 2 First run (contract 01) ─ flow test T03
│   ├── P01 ON-1/2 splash + sign-in ── splash map (C38 orbits) · S10 mark · Apple/Google buttons · M01
│   ├── PI1 invite gate (code field, waitlist) ── PI2 "you're in" M14 ── (drawn in Paper first)
│   ├── P02 ON-3–9 questions ── C34 question (M13) · C35 progress · C17 onboarding · quick-answer pills · C16? · ON-9 card
│   ├── P03 ON-5 privacy ── privacy disc
│   ├── P04 ON-6 connect ── C36 knows-you meter (M04) · RSourceRow (#52)
│   ├── P05 ON-10 getting ready ── getting-ready panel (M05) · stage list
│   ├── P06 ON-11 tease ── C23 (episode recipe) auto-play · M06
│   ├── P07 ON-12 paywall ── C37 plan pair (M07) · C33 benefit row · C22 paywall variant
│   ├── P08 ON-13 first home ── setup-recap card · hint pill · C26 first-episode variant
│   ├── P32 AC-1 sign in, returning ── you-orb 56 · map
│   └── PX force-update screen (drawn in Paper first)
├── 3 Podcasts (contract 03) ─ T05a
│   ├── P13 PC-1 ── C27 episode tile hero/square (M10) · C22
│   ├── P14 PC-2 ── C23 episode mode · chapters list · "…" menu (C20) · guess arriving · M09 · M06
│   └── P15 PC-3 ── claim stated/asked · C32 · "where retro says it" card
├── 4 Goals (contract 04) ─ T05b
│   ├── P16 GL-1 ── C29 goal card (rest, gap, too early, guess; M11) · question card · ended row · toast
│   └── P17 GL-2 ── goal header · C32 · grey guess card · turn off
├── 5 You (contract 05) ─ T05c
│   ├── P18 YO-1 ── C38 you map (M12) · search field · rows
│   ├── P19 YO-2 ── answer + citation chips · source rows · only-certain switch
│   ├── P20 YO-3 ── entry words · settings row nav
│   ├── P21 YO-4 ── node sheet · claim · chips · C32
│   └── P22 YO-5 ── answer rows
├── 6 Settings and account (contract 06) ─ T06
│   ├── P23–P31 ST-1…ST-9 ── merged rows, switch, segmented, settings bar (C17)
│   ├── P33 AC-2 signing out ── sign-out sheet (C19.1)
│   └── PI3 your invites (three links) ── drawn in Paper first
├── 7 Outside the app (contract 07) ─ T05d
│   ├── P34 EX-1 share extension ── compact composer · item card
│   ├── P35 EX-2 lock screen / Live Activity / Now Playing
│   ├── P36 EX-3 notifications
│   └── P37 EX-4 widgets ── C40
└── Signature moments M01–M14, each its own PR after its page (see ui/later.md)
```
`*` marks variants built with their first page, not in the component's first PR.

## 7. The queue

Each byte is one PR. "Needs" lists what must be merged first. The integrator assigns them on [board.md](./board.md), in this order unless a dependency stalls. Sizes: S is under half a day, M about a day, L two days.

### Phase 0: foundations and the first journal components

| # | Byte | Card | Size | Needs |
|---|---|---|---|---|
| 1 | T01 snapshot harness | [ui/T01.md](./ui/T01.md) | M | PL0.1 (tests run), PL0.4 (pinned packages), the integrator adds the snapshot target |
| 2 | T02 screen launcher (views half) | [ui/T02.md](./ui/T02.md) | M | T01; the integrator's launch hook in the app root |
| 3 | UI0.1 progressive-blur modifier (request and consumer check) | [ui/UI0.1.md](./ui/UI0.1.md) | S (yours) | the integrator's shared-file PR |
| 4 | C17 top bar | [ui/C17.md](./ui/C17.md) | M | #44, #55, T01 |
| 5 | C18 tab bar | [ui/C18.md](./ui/C18.md) | M | UI0.1, T01 |
| 6 | C39 shared states (4 bytes) | [ui/C39.md](./ui/C39.md) | 4 × S | T01 |
| 7 | C32 evidence row | [ui/C32.md](./ui/C32.md) | S | T01 |
| 8 | C19.1 sheet host, then C19.2 dialog | [ui/C19.md](./ui/C19.md) | L + S | T01 |
| 9 | C20 menu | [ui/C20.md](./ui/C20.md) | M | C19.1 (shares the overlay host) |

### Phase 1: the journal slice

| # | Byte | Card | Size | Needs |
|---|---|---|---|---|
| 10 | UI1.0 SampleJournalData + ledger | [ui/UI1.0.md](./ui/UI1.0.md) | M | `Platform/Flows/Journal.swift` (integrator) |
| 11 | C30.1, C30.2, C30.3 message | [ui/C30.md](./ui/C30.md) | S + S + M | UI1.0 |
| 12 | C26.1, C26.2, C26.3 brief card | [ui/C26.md](./ui/C26.md) | M + M + M | #42, UI1.0 |
| 13 | C28 guess card | [ui/C28.md](./ui/C28.md) | M | #45, #46, UI1.0 |
| 14 | C31 entry row | [ui/C31.md](./ui/C31.md) | S | UI1.0 |
| 15 | UI1.1 drawer | [ui/UI1.1.md](./ui/UI1.1.md) | M | C31, #53 |
| 16 | UI1.2 what i took + not right | [ui/UI1.2.md](./ui/UI1.2.md) | M | C32, #45, UI1.0 |
| 17 | P09 JR-1 journal | [ui/P09.md](./ui/P09.md) | L | C17, C18, C26, C30, C28, C39, #56 |
| 18 | P11 JR-3 all entries | [ui/P11.md](./ui/P11.md) | M | UI1.1, P09 |
| 19 | P12 JR-4 one entry | [ui/P12.md](./ui/P12.md) | M | UI1.2, C19.2, C17 |
| 20 | UI3.0 SamplePlayback | [ui/UI3.0.md](./ui/UI3.0.md) | S | `Platform/Flows/Playback.swift` (integrator) |
| 21 | C25 scrubber | [ui/C25.md](./ui/C25.md) | M | UI3.0 |
| 22 | C24 transport | [ui/C24.md](./ui/C24.md) | M | UI3.0 |
| 23 | C23b player sheet, brief mode | [ui/C23b.md](./ui/C23b.md) | L | C19.1, C24, C25, UI0.1 |
| 24 | C22 mini-player | [ui/C22.md](./ui/C22.md) | M | UI3.0 |
| 25 | P10 JR-2 today's brief | [ui/P10.md](./ui/P10.md) | M | C23b, C22, P09 |
| 26 | T04 journal flow test (with the integrator) | [ui/later.md#t04](./ui/later.md) | M | P09–P12 |

Audio (20–24) can run before 17–19 if the board needs it: it depends only on UI3.0 and C19.1.

### Phases 2–8

These are outline cards in [ui/later.md](./ui/later.md). Each gets a full card before its phase starts, written against its contract (01, 03–07) and its Paper nodes (listed in the outline).

## 8. Testing (yours, from testing.md)

| Layer | What you add | Where | Runs |
|---|---|---|---|
| 6 snapshots | every component state × light, dark, AX3 (`.accessibilityExtraLarge`); pages at full device size, plus SE for pages | `RetrospectSnapshotTests` (T01) | every app PR |
| 7 accessibility audit | `try app.performAccessibilityAudit()` per page and per state that changes layout; exclusions only with a written reason, one per issue | `RetrospectUITests/V2/<Flow>AccessibilityTests` | page PRs, nightly |
| 8 flow UI tests | XCUITest via T02 (`-Screen JR-1 -Data sample -State offline`), asserting on accessibility identifiers, never on coordinates | `RetrospectUITests/V2/<Flow>FlowTests` | page PRs, nightly |
| 10 motion and hitches | each page's scroll and each signature moment: `XCTOSSignpostMetric.scrollingAndDecelerationMetric` in a performance test (the simulator gives a trend, not truth), a frame-by-frame recording against the motion system, and the founder's phone at the ship gate | `RetrospectUITests/V2/<Flow>MotionTests` | page PRs; numbers recorded in the PR |
| unit | view-model logic: acknowledgement rotation, search debounce, scrubber value maths, collapse thresholds | `RetrospectTests/V2` (Swift Testing) | every app PR |

Tests are named as sentences ("a failed send shows not sent and retries on tap"). There is no real clock, randomness or network in any test. Snapshots are recorded on the integrator's configuration (iPhone 17 Pro, iOS 26.0); a deliberate change re-records them in the same PR, with before and after images.

## 9. Conflicts resolved (newest source wins, then context.md)

| # | Conflict (reference §F) | Resolution |
|---|---|---|
| 1 | Mini-player progress: amber fill vs 2pt line | 2pt `player.progress` line (founder kept it; "C fill archived") |
| 2 | `size.miniPlayer` 42 vs drawn 64 | 64; AX3 80 |
| 3 | Dialog width token 300 vs drawn | screen − margins (342 on 390) |
| 4 | Message max width 0.78 token vs 0.8 | `column × 0.8` (message.md, newest); the integrator corrects the token |
| 5 | Retro's line: inky vs SF Pro | SF Pro 17/26 (part 08 A) |
| 6 | Send haptic: `select` (composer.md) vs `confirm` (M08) | `confirm` |
| 7 | Tab change: `.symbolEffect(.bounce)` vs custom glyphs | a scale settle on `snappy` (`scale.press` → 1); glyphs are template images, so `symbolEffect` can't apply |
| 8 | Tab-bar blur ~90pt vs ~70pt | ~70 / 60 (SE), 14pt, ×1.5 saturation (progressive-blur.md, 20 Oct) |
| 9 | Transcript non-spoken lines | `text.tertiary` |
| 10 | Brief scrubber: chapter capsules vs continuous | capsules, one per brief part, 4pt gaps |
| 11 | Sheet under Reduce Motion: fade + 24pt slide vs 140ms cross-fade | 140ms cross-fade (motion-system §8 is newer) |
| 12 | Brief card while playing: glow off vs unchanged | unchanged (founder: "I still prefer this") |
| 13 | Journal v1 conversation: streaming, thinking, "why you said this" | none in v1 (context.md §2): Retro shows one canned acknowledgement; M08 reduces to the bubble lift plus `confirm`; Retro's line is built so v2 streaming can replace its content without a redesign |
| 14 | JR-1 data in §E (conversation and stream doors) | contract 02 §2 (entries plus outbox, canned acknowledgement) |
| 15 | Drawer search highlight: blue vs wash | `surface.washPressed` run, medium weight, 2pt inset (drawer's own note); blue stays YO-2's |
| 16 | Prices in ON-12 ($24.99/$239.99, "save 20%") | $19.99 / $199.99, 17% off, first month free on yearly; Apple's localized price on screen |
| 17 | `press` haptic on every press vs only lit ones | `press` only on primary (lit) and destructive actions, once on touch-down (the `RHaptic.press` token doc); founder Q4 asks to confirm |
| 18 | Collapse spring "~300ms" | `RMotion.snappy` (0.25/0.82): a title mustn't overshoot, and snappy is the nearest calm spring |
| 19 | Drawer slide motion (unspecified) | `RMotion.sheet` with gesture velocity, page radius and shadow on the same progress value; Reduce Motion is a 140ms cross-fade |
| 20 | System sheet vs custom | custom `RSheetHost` (C19.1): the player's choreography (M06) and the drawn values (behind 0.94, radius 12, 140pt / 800pt/s) need one progress value the system sheet doesn't expose; VoiceOver escape and focus containment are built in |

## 10. Definition of done (every PR)

1. Every item of `m14-agent-checklist.md` §2.
2. Every state on the card is built, snapshotted (light, dark, AX3) and shown next to its Paper node; every difference is fixed or listed as a decision.
3. Every row of the interaction table is built: press, haptic on the same frame, motion token, outcome, and the Reduce Motion version. The interrupted recording is attached.
4. VoiceOver reads each thing once, with its label, traits and actions as on the card. Dynamic Type grows things to AX5 without clipping, and AX3 is snapshotted. Increase Contrast and Reduce Transparency are handled where the card says. Colour is never the only signal.
5. Screens read only their flow protocol, and every sample value is in the ledger.
6. The card's named tests exist and pass in CI.
7. The PR body lists Paper nodes, values with their tokens, states, checks, mismatches, decisions and screenshot paths.

## 11. Things that will bite you

- A bare `Capsule()`, a `RoundedRectangle` without a style, or `.cornerRadius(` fails the literal check. Use `RShape`.
- **The disabled fade** needs `.compositingGroup()` before `.opacity`, or the fill and shadow fade separately.
- **Paper's browser render has no SF optical tracking**, so SF text looks wider in Paper. Never add tracking to match it.
- **Paper's blurs are fake** (stacked copies). Build progressive-blur.md, never the layers.
- **Simulator taps lag a step.** Prefer T02 flags to tapping your way into a state.
- **Never format `Generated/`.** It broke CI twice.
- **`onScrollGeometryChange` fires every frame.** Map it to a `Bool` or a quantised value before it touches state, or the whole screen re-renders while scrolling.
- **Matched geometry across two hierarchies** (title, bubble lift) needs one `@Namespace` owned by the common parent. Under Reduce Motion, skip the matched move and cross-fade.
- **Snapshot fonts:** Exposure and Geist must be registered in the test host before the first render, or snapshots silently fall back to SF.
- **iOS 26 vs 18.1:** the snapshots run on iOS 26, so the iOS 18 blur fallback is never snapshotted. UI0.1's own test renders the fallback path by forcing it. (Question for the integrator: is an iOS 18 runtime installed for a manual check? Never install one yourself.)
- **`.sensoryFeedback` fires on change of its trigger.** Use a counter for repeats (two failures in a row must both buzz).

## 12. Questions for the founder (journal slice first)

Each has a lean, and the work proceeds on the lean until the founder answers.

1. **Guesses in the v1 journal.** Where does a guess card appear when Retro doesn't reply? *Lean:* as its own Retro item in today's thread, after your next acknowledgement, at most one a day, and only when guesses are speaking (D11).
2. **Long press on your own message (v1).** *Lean:* copy · open this entry (to JR-4). Correct and "why you said this" wait for v2, when Retro speaks.
3. **Message state** (contract 02 #3). *Lean:* show only "waiting to send" and "not sent · tap to retry"; nothing on sent messages (Paper draws no receipts).
4. **`press` haptic on non-lit buttons.** *Lean:* none (the token's own rule: primary and destructive only).
5. **Two lit objects on JR-1** when scrolled and typing (the brief play and send). *Lean:* while the composer has text, the slim bar's play drops to raised and send is the one lit object.
6. **Corrected claim on JR-4.** Struck through with "noted", or gone? *Lean:* struck with "noted" (Paper part 24 draws it).
7. **Sureness words and acknowledgement lines** (contract 02 #1, #6). *Lean:* "just a hunch / fairly sure / very sure"; lines "got it." / "saved." / "it's in." / "kept." with no repeats in a row.
8. **Grey guess everywhere?** The journal's guess card is inference-tinted and dashed, while goals use grey. *Lean:* keep both as Paper draws them.

**Later-phase questions** (they don't block the journal; each has its lean in ui/later.md):
- onboarding "skip"
- splash opening A/B/C
- M07 under paywall option A
- the ON-10 blue hairline
- YO-3 merge with JR-4
- PC-3 ⌄ close
- the player's "…" items
- the toast look (#48)
- progress VoiceOver wording ("2 of 6" vs a percentage)
- the force-update design
- C15/C16 needed at all
