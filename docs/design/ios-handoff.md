# iOS handoff: what's designed, and how to build it

The working handoff from the hi-fi design to the SwiftUI app. It's updated after every step. Read it with:
- **Paper file** `01M5D5J321P5X86ZT58002B7NT` ("Retrospect"). Pages: `00 · approvals · waiting on you` (only pending items), `02 · components` (current set · approved parts · legacy), `02b · decisions made` (decision cards and versions not chosen), `04 · screens · mid-fi`, `04b · pages · hi-fi` (one row per area: onboarding, journal, podcasts, account, goals, you, settings, outside), `05` the app in order, `05d` dark mode, `92` dark archive.
- **Specs** in `design-system/components/*.md` (anatomy, rules, states, accessibility per component).
- **Tokens** in `design-system/tokens/tokens.json` (source of truth; `TOKENS.md` explains them). Every value in Paper is a token; `token-check.mjs` reports 0 raw values for every generator.
- **Generators** in `design-system/hifi/p*.py`: the HTML each part was drawn from. Paper is the source of truth when they differ (founder edits land in Paper).
- **Behaviour details** from founder comments in `docs/design/ios-build-notes.md` (motion, edge behaviour, small rules). This doc points to it rather than repeating it.

Status key: ✅ approved by the founder · 👀 drawn, waiting on approval (red dot in Paper) · ⏳ not drawn yet · ⛔ blocked.

---

## 1. Rules that apply everywhere

| Rule | What it means in SwiftUI |
|---|---|
| Three sizes | Every page is drawn at **SE 375×667** (square corners, short status bar, no home indicator), **17 Pro 402×874** and **Pro Max 440×956**. Build with size classes and flexible stacks, never fixed device heights. |
| Small screens adapt, never shrink | On SE: tighten section gaps one step (32→24, 24→16), drop secondary sublines, use the compact version of a card, keep the primary action in the thumb zone. **Type sizes never shrink** (Dynamic Type handles text). |
| Screen margin | `spacing.screenMargin` = 24; 20 on SE. |
| One lit object per screen | Only one `glow.primary` element shows at a time (the brief's play, the composer's send while typing, the paywall's yearly plan). Many screens have none. |
| Facts vs guesses | A stated thing is inky (`font.display.inky`) on a raised surface. A guess uses `inference.surface` plus a 1pt **dashed** `inference.border`, no shadow, a "a guess" label, and yes / not quite. Never colour alone. |
| Sheets flex | Sheets (player, why-this-is-here, a node) use a flexible middle (`minHeight: 0`, grows) so the bottom controls stay on screen on SE. Content scrolls, controls don't. |
| Progressive blur at the tabs | Tab pages scroll under a progressive blur above the tab bar (sharp layer masked out, blurred copy masked in, plus a light canvas tint under the labels). See ios-build-notes "Podcasts bottom edge · final". |
| Balanced wrap | Titles and short answer lines use balanced wrapping (no one-word last lines). In SwiftUI: avoid orphans with `.lineLimit` + shorter copy, or a balanced-text helper. |
| Evidence rows stay one line | Rows end in "…" rather than wrap (`lineLimit(1)`, `truncationMode(.tail)`). |
| Key states only | Only the important states are drawn. Accessibility variants (AX3, Increase Contrast, Reduce Motion/Transparency) come from SwiftUI and the specs, not from drawings. |
| No invented data | Empty and day-one states show shapes and plain lines, never fake people or numbers. |

---

## 2. Components

### Approved masters (02 · components) ✅
| Component | Spec | Notes |
|---|---|---|
| Icon set (20pt outlined, shipped SVGs) | `icons/shipped/*.svg` | Use as template images; colour from `icon.default/muted`. |
| Pill: neutral (wash) · raised · lit | button.md, chip.md | Medium weight; heights 32 (neutral/raised), 48 (lit). |
| Labels (day, section) | — | `font.label`, `text.label`, tracking label. |
| Settings row + hairline, switch, segmented, settings page | settings-row.md, switch.md, segmented.md | Switch on = ink (not blue). Value rows use ↕ for choices, › for pages (decision 04 B). Syncing = grey rotating ring (decision 03 A). |
| Drawer (search field, entry row, section label, settings foot) | — | JR-3. |
| Entry page (words, meta, link, "what i took" + not right, delete + dialog, editing) | message.md | JR-4. |
| Top bar | title-menu.md | Inky large title at rest → small centred name once you scroll or type. |
| Tab bar (system, 4 items: journal, podcasts, goals, you) | tab-bar.md | Selected = `text.primary` + medium weight; others `icon.muted`/`text.label`. |
| Composer (voice: listening, speaking, muted, typing → send lit, thinking) | voice-composer.md, composer.md | Mic is **off** when Journal opens until you tap (founder). Squircle corners. |
| Conversation (retro's lines without a mark, your bubbles, recap card) | message.md | SF Pro (decision A). |
| Brief card D (+ slim bar when scrolled, decision 05 A) | brief-card.md | The lit play is the one lit object on Journal. |
| Player sheet (brief and episode modes, transcript, chapters, held-scrub bubble, "…" menu) | player.md, scrubber.md, transport.md | Progressive-blur transcript. |
| You map (orbits, frosted orbs) | you-map.md | Map bleeds past the margins; centre is you, not a button. |
| Status bar | — | System. |

### Parts waiting on approval (02b) 👀
| Part | What it is | Anatomy and key details | States drawn |
|---|---|---|---|
| **40 · episode tiles** (PC-1) | hero (this week's episode) + square tiles (briefs, earlier episodes) | Raised paper card, token **mesh** artwork per kind (weekly = night/amber, brief = sky/amber, first = green, calls = paper), inky title (clamped to 2 lines on squares). Only the hero has the lit play, and it drops it while its own episode is playing (the mini-player owns playback). | rest, being made (one compact row with the grey syncing ring, "ready sunday 9:00") |
| **41 · why this is here** (PC-3) | the claim one part of an episode makes, plus what it rests on | Stated claim = inky 3xl + label line ("stated · from what you did · very sure"). Asked = dashed guess card. Evidence list: 32 kind well, date/kind label, one line of your words, ›, firm 1pt divider. "not right" pill at the bottom. | stated, asked |
| **42 · onboarding question** (ON-3–9) | one question per screen | Progress bar, back · skip (Geist), one inky question, your words blurring in live, quick-answer pills that fill the composer (not auto-send). No why-line. | — see build notes "Onboarding question" |
| **43 · splash + sign-in** (ON-1/2) | first screen | The You map bleeding under the status bar, inky promise + Geist subline, Sign in with Apple (black) then Google (white) in the bottom zone, legal line. Three options drawn (A constellation · B warm light · C a real brief). | waiting on your pick |
| **44 · privacy moment** (ON-5) | | Lock in a raised disc with two soft rings, inky title, plain paragraph, policy link; retro reads it aloud. | rest |
| **45 · mini-player** | the one control for what's playing, above the tabs | Width = screen − 2×margin, 64 high, 44 mesh thumb, title + Geist subline, 44 pause on wash, 2pt `player.progress` line at the bottom edge (C fill, see build notes). | playing, failed |
| **48 · goal card** (GL-1) | one goal | Raised card. Title = your words (text body, semibold). **said** and **did** rows: mono xs label (28 wide) · 4pt track (`surface.track`, fill `goal.said` / `goal.did`) · count in words (64 wide, right). One retro line (text-md secondary). No red, no %, no streaks. | rest, a gap, too early ("too early to tell" replaces the did bar for 2 weeks), a guess (dashed, yes / not quite), ended (one quiet row "turned off 2 · merged 1 ›") |
| **50 · search** (YO-1/2) | field, answer, sources | Field: 48 high, `surface.control`, sunken inner shadow, 36 mic well first, placeholder `text.tertiary`, clear × when typed. Answer: "what i found" label, facts inky xl, guess sentence starts "a guess:" in body/secondary. **Citations**: tappable mono chip per claim (see build notes "Search answer citations"). Sources: part 41 rows with a mono **number** well instead of the kind well. "only what's certain" row with the switch ("hides the 1 guess"). | field rest/typed, found, nothing found (abstains, then "the closest: …") |

### Decision cards open 👀
- **Decision 06 · paywall plan picking:** A, the plans are the buttons (yearly lit, "save 17%" badge breaking its top edge; my lean) · B, choose a plan then one lit "subscribe". Prices are the founder's: $19.99 a month and $199.99 a year (17% saving, so the spec's "33%" is stale). Real prices always come from StoreKit.
- **Part 43 splash:** A, B or C.

---

## 3. Screens (04b · pages · hi-fi)

Every page has a **page pass** box on its board: content order, one lit object, small-screen decisions and states. That box is the brief for the SwiftUI view.

### Journal
| Screen | Status | Built from | States | Small-screen decisions |
|---|---|---|---|---|
| JR-1 journal | 👀 | top bar, brief card D (slim bar when scrolled), conversation, composer, tab bar | talking, retro thinking, brief being made, first day, scrolled | SE: 72 brief artwork band, no subline |
| JR-2 today's brief | 👀 | player sheet, brief mode | paused, played ("played · 3 of 3"), quiet day | sheet flexes, controls stay on screen |
| JR-3 drawer | ✅ | drawer master | empty, searching, no results, offline | 20 margins, foot 16 off the bottom |
| JR-4 an entry | ✅ | entry master | voice note, nothing taken yet, editing, offline, delete dialog | delete in the thumb zone |

### Podcasts
| Screen | Status | Built from | States | Small-screen decisions |
|---|---|---|---|---|
| PC-1 podcasts | 👀 | parts 40, 45, tab frame + progressive blur | playing (mini-player), being made | SE: 112 hero art, 24 gaps, 161 squares, blur starts lower |
| PC-2 the player | 👀 | player sheet, episode mode | a guess arriving, chapter list | transcript flexes; controls stay on screen |
| PC-3 why this is here | 👀 | part 41 inside the player sheet | stated, asked | rows stay one line, claim keeps its size |

### Account / onboarding
| Screen | Status | Notes |
|---|---|---|
| ON-1/2 splash | 👀 | part 43, three options |
| ON-3–9 questions | 👀 | part 42 |
| ON-5 privacy | 👀 | part 44 |
| ON-6 connect | 👀 | two groups: "on this iPhone" (calendar, health, music) and "your other apps" (google, notion, github, then "see all apps"). Every icon is an SF Symbol: the layer name `sf:<name>` is the `Image(systemName:)` to use (calendar, heart, music.note, envelope, doc.text, chevron.left.forwardslash.chevron.right, checkmark, chevron.right). Rows are `c:settings-row/source/{rest,connected}`; a raised "connect" pill, or a checkmark + "connected". Lit "continue" once one is connected, text "later" always. |
| ON-12 paywall | 👀 | decision 06 |
| AC-1 sign in, returning | 👀 | the splash's real sign-in buttons; mark (38) + "welcome back."; restoring (ring + "bringing back your entries and episodes…", buttons disabled) and failed ("that didn't work. nothing is lost; try again." above the buttons) |
| ON-10 getting ready | 👀 | part 42 question phone (progress at 92%) asking one more warm question; new **c:getting-ready** panel above the composer: label "getting your first episode ready", three stages (done = 20 pt success disc + check · now = 20 pt spinner, medium weight · next = empty ring at opacity-disabled), footnote "about two minutes. keep talking; it all goes in." No percentage. Stages come from the real pipeline. SE: the panel shows only the current stage line and the footnote. |
| ON-11 tease | 👀 | the approved player sheet (PC-2), auto-playing, titled "the week you started"; short episode (~2 min); line 2 "here's the first thing i noticed. it's narrow, because it's day one." is the hook the paywall rises from. SE: as PC-2. |
| ON-13 first home | 👀 | JR-1 first day: the brief card becomes "your first episode is ready · the week you started · 2 min" with mesh artwork + play; new **c:entry/setup-recap** card (label + "9 answers", three summary lines, "see all 9"); retro: "that's enough to start…"; **c:hint/1-of-3** pill above the composer (mono counter + one line; one hint at a time, dismissed by doing it). SE: recap shows two lines. |
| AC-2 signing out | 👀 | sheet over ST-9 account (scrim night-900 at opacity-disabled): "sign out?" display 2xl, what stays (body, secondary), an unsent row (spinner + "1 entry hasn't sent yet" / "it goes first, so nothing is lost.") only when something is unsent, lit "send, then sign out" (plain "sign out" when nothing is waiting), text "cancel". |

### Goals
| Screen | Status | Built from | States | Small-screen decisions |
|---|---|---|---|---|
| GL-1 goals | 👀 | part 48 in the tab frame; + is a wash icon button | none yet ("nothing yet." + "say what you're working toward, or wait and i'll notice.") | SE: full-width cards, 12 gaps, blur starts higher |
| GL-2 one goal | 👀 | entry frame (back · edit); goal inky 3xl, "said 6 times · first on … · last on …", "did this week" evidence rows, pattern as a guess; foot = "turn off" only ("edit" renames) | turned off (dated line, guess gone, "turn back on") | SE: sections 24 apart, foot 16 off the bottom |

### You
| Screen | Status | Built from | States | Small-screen decisions |
|---|---|---|---|---|
| YO-1 you | 👀 | tab frame; "you" large title, trailing "list" + your picture (opens settings); part 50 field; You map; rows "what i know about you", "one question waiting · about sam" | day one (only you on the empty orbits, "just you, so far." / "this fills in as you talk to me.") | SE: the map keeps its full size; rows rise from under the tabs |
| YO-2 search results | 👀 | **in place** in the You tab (the map gives way to the answer; clearing the field brings it back) | found, nothing found | SE: 16 gaps; the switch sits just above the tabs |
| YO-4 a node | 👀 | sheet over the map, PC-3's parts; header "person · priya" + dismiss chevron; belief inky 2xl; "fairly sure · from 5 things · moved last week"; evidence rows; linked chips; still true · not right | a guess ("is this the same sam as sam okafor in your contacts?" yes, same · not quite); this is where "one question waiting" lands | sheet flexes like PC-3 |
| YO-3 a source | 👀 | entry frame; your words inky, "tue 14 oct · 7:40 · written · read", "show it in the conversation", **this supports** rows (a belief, a goal) | — | as JR-4 |
| YO-5 what i know about you | 👀 | pushed frame (back only); title inky 3xl; "moved this week · 2 answers changed" wash row; areas as inky xl sections; **answer row**: question (label sm) · answer (body) · how sure word + 4 dots (6pt, `text.secondary` filled / `surface.track` empty, 2 apart) · "from n things" · ›; silent area = one warm sentence | thin day one: most areas silent | SE: 20 margins, 24 between areas |

### Settings (M9) 👀
One board, ST-1 to ST-9 at 17 Pro, built only from the approved parts. Settings bar: back (36 wash in 44) · small centred page name (Geist 14 medium, `text.secondary`) · 44 spacer. Rows: min 56, padding 16/24; title SF 17; subline 14 `text.secondary` (wraps, balanced); trailing: value + › (opens a page), value + ↕ (picker in place), switch (applies at once), ink tick (choice), ↗ (leaves the app), status word + 6pt dot (source), raised pill (an action: play, export, sync now, connect, reconnect, sample). Groups are separated by space with a Geist 12 label; hairlines are inset. **Danger rows are alone and last**, in the thumb zone (red well + `status.dangerText`), each opening the part 24 dialog.
| Screen | Contents |
|---|---|
| ST-1 settings | approved master: icon wells on every row; your brief · listening · you · sources · privacy/account |
| ST-2 daily brief | each morning (switch) · time ↕ (local) · length segmented short/standard/long + caption · play today's (pill) |
| ST-3 sources | connected: source rows with status (connected · connect pill · reconnect · syncing); add a source ›; import a file › |
| ST-4 a source | reads · helps me see (plain sentences) · last read + sync now · disconnect… · delete what it read… |
| ST-5 privacy | read in the background (switch; the ambient switch) · where it's processed › · download my data (export pill) · delete my data… |
| ST-6 how straight | four choices with one ink tick · "picked by retro" + why · your choice wins |
| ST-7 voice and listening | voice (sample pill) · speed ↕ · talk or read segmented |
| ST-8 what i've learned | one inky sentence · the plain why · last changed |
| ST-9 account | your plan (yearly · renews) · manage subscription ↗ · restore purchases · sign out (raised, per a later edit) · delete account… |

### Outside the app (M10) 👀
| Screen | Contents |
|---|---|
| EX-1 share extension | system sheet over the source app: cancel · "save to retrospect" · the thing (mesh thumb, title, site · length) · retro's read (inky xl) + "goes with" goal chip + change · add why (compact composer, mic first, optional) · **save** (lit, the one action). States: reading, saving, saved ("it'll be in tomorrow's brief"), offline (queued), video (transcript fetched). |
| EX-2 lock screen | Now Playing: brief mesh artwork, title = the part being spoken, subtitle "retrospect · tuesday's brief · part 2 of 3", system scrubber and ↺15 ‖ 30↻. Live Activity carries the same. |
| EX-3 notifications | private by default ("your brief is ready · 4 min", "this week's episode is here.", "one question for you, when you have a minute."); max one a day, never at night; deep links: brief → JR-2, episode → PC-2, question → YO-4. |
| EX-4 widgets | small (the mark 16 · "tell me…" inky · "talk to retro" → opens composer); medium (mark + "today's brief · 4 min" mono · inky headline · play / talk wash pills, interactive). Legible in tinted and clear Home Screen modes. |

### Not started
 journey map (M11), dark mode (M12).

---

## 4. Paper → SwiftUI gotchas
- **Inline styled runs are flattened in Paper.** Citations are drawn as ¹ ² ³; build them as tappable chips in an `AttributedString`.
- **Paper ignores `transform: scale`.** No design depends on scaling. Small screens are handled by layout choices, as above.
- **Dashed outlines** are drawn as `outline: 1px dashed` inset by 1. In SwiftUI use `strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))`.
- **Shadow stacks** are token stacks (inner top highlight, outer 0.5 stroke, contact, cast, ambient). Map each layer to `.shadow` or an overlay; see `TOKENS.md` "depth".
- **Mesh artwork** = a base colour plus two radial gradients in oklab. In SwiftUI use `MeshGradient` (iOS 18) or layered `RadialGradient`s with the same palette tokens.
- **Status bars and home indicators** in Paper are pictures; in the app they are the system's.
- **The mark** is a blank cream disc everywhere in Paper; its glyph (`icon.mark`) has no artwork yet.

---

## 5. Change log
- 20 Oct 2026: settings pages ST-1 to ST-9 added (M9).
- 20 Oct 2026: YO-5 added; M8 complete pending approval.
- 20 Oct 2026: created; covers M2–M8 so far (journal, podcasts, onboarding parts, paywall, AC-1, goals, YO-1 to YO-4, YO-3).

- 20 Oct: ON-10, ON-11, ON-13 and AC-2 drawn (one board on the approvals page). New parts: c:getting-ready, c:entry/setup-recap, c:hint/1-of-3, c:spinner/20, c:sheet/sign-out.

## Tokens in Swift (M14)
- `design-system/tokens/build/Tokens.swift` is generated by `node design-system/tokens/to-swift.mjs`. Never edit it; change tokens.json and regenerate.
- `RColor.*` are dynamic colours: light and dark both come from tokens.json, so dark mode needs no per-view code.
- `RDimension.*` (points) and `RNumber.*` (opacity, layers, durations in seconds).
- Hand-built (not generated): type styles (`type.*` composites), shadows and depth tiers, gradients and meshes, springs, haptics, grain. Build them as modifiers that read the generated values.

## Dark mode (M12)
- Every screen's dark twin is the light one with each `--color-X` swapped for `--color-dark-X`. Nothing else changes; no dark-only layout. The twins live on Paper page `05d · dark mode · hi-fi (follows light)` and are rebuilt from light by `node design-system/sync/dark-sync.mjs`, then checked by `sync/dark-audit.mjs`.
- New tokens from the 20 Oct recalibration: `background.underlay` (behind a sheet, the drawer, a segmented thumb) and `surface.lifted` (a paper pill or card on a tinted or raised parent). Dark-only value changes: `surface.washPressed` black 30%, `background.sunken` night.950, `depth.stroke.outer` white 7%. Details in ios-build-notes.md, "Dark mode".
- Stays the same in dark on purpose: artwork meshes (palette sky/amber/paper), lock-screen and notification system chrome.
- Status-bar glyphs flip to the dark text colour (as iOS does).

## The tab bar (fixed by the M13 sync)
- Each tab is a copy of `c:tab-bar/item/selected` or `c:tab-bar/item/rest`. Selected: label text-primary, medium; icon text-primary. Rest: label text-label, regular; icon icon-muted.
- In SwiftUI: one `TabBarItem(state: .selected/.rest)`. Never recolour an icon on its own.

## Change log
- 21 Oct: journey map, dark mode, sync proof, Swift tokens.

## The mark (21 Oct)
- Use the app's existing asset `retrospect-loading-mark` (Assets.xcassets) as the glyph. Paper holds a simplified copy of the path for drawing only.
- Master on 02 · components ("c · the mark"): glyph in `icon.mark` (dark `night.400`) on the cream `surface.secondaryAction` disc; sizes 38 (paywall, welcome), 22 (player header), 16 (widget), with the glyph about 53% of the disc width.
- In SwiftUI: `Image("retrospect-loading-mark").renderingMode(.template).foregroundStyle(RColor.iconMark)` inside the disc.
