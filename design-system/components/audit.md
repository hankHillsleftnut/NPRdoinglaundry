# component audit, 20 Oct (second pass)

Every component checked against [craft.md](./craft.md) (§1–12) and the founder's 26 keys in [../principles](../principles/README.md). `node design-system/lint.mjs` checks the parts a script can check: sections, all fourteen states, token names, icons, contrast pairs and links. The rest was checked by eye on Paper renders at 2×.

✓ passes · ⚠ fixed in this pass · ◐ open (founder's call).

| Component | Surface | Detail (stroke · shadow · texture) | Concentric | Optical | Contrast | States drawn | Restraint: taken out |
|---|---|---|---|---|---|---|---|
| [button](./button.md) | lit / raised / wash | ✓ full stack; ⚠ grain on destructive | ✓ pill | ✓ | ◐ lit label 2.6 : 1 (b or c) | ⚠ + secondary disabled, delete pressed, delete pending (c5) | icons and arrows on hero buttons |
| [talk-button](./talk-button.md) | lit | ⚠ grain on listening, thinking and rest | ✓ | ✓ mic by mass | ◐ as lit label | ✓ five states (c1) | ⚠ second breathing wash removed |
| [switch](./switch.md) | sunken + raised | ✓ | ✓ | ✓ | ✓ with the Increase Contrast ring | ⚠ + dark, Increase Contrast (c5) | on/off text by default |
| [segmented](./segmented.md) | sunken + raised | ✓ | ✓ 18 − 3 | ✓ | ✓ | ✓ | icons, selected colour |
| [chip](./chip.md) | card | ✓ double stroke, warm cast | ✓ 16 − 6 | ✓ | ✓ | ⚠ + dark, Increase Contrast (c5) | counts |
| [tag](./tag.md) | wash | ✓ guess dashed | ✓ | ✓ | ⚠ guess edge 1.7 → 3.5 : 1 | ⚠ + dark, Increase Contrast (c5) | icons |
| [the-mark](./the-mark.md) | raised | ◐ the disc is drawn; the glyph isn't (see open 4) | ✓ | — | n/a (decorative) | rest only (never interactive) | motion |
| [player](./player.md) | overlay | ⚠ soft edges under the header and into the transport | ✓ 38 | ✓ | ✓ | spec + transport states (c5) | ⚠ "why it's here" pill (said twice) |
| [scrubber](./scrubber.md) | sunken + raised | ✓ | ✓ | ✓ | ✓ 3.6 : 1 | ⚠ + held, with time bubble (c5) | total time |
| [transport](./transport.md) | sunken + raised | ✓ | ✓ 32 − 8 | ✓ checked at 2× | ✓ | ⚠ + playing, buffering, ended, failed, offline, dark (c5) | glow on play |
| [mini-player](./mini-player.md) | floating | ✓ three-layer shadow | ✓ 32 − 10 | ✓ | ✓ | ⚠ + pressed, buffering, failed, dark, Reduce Transparency (c5) | ⚠ skip button and rolling time |
| [brief-card](./brief-card.md) | card | ⚠ grain on the play | ✓ | ✓ | ✓ | ✓ every state for D (inside 02b part 03, M3): pressed, starting, played, quiet day, being made, couldn't load, offline, AX3, Increase Contrast; playing unchanged (founder); focused/disabled/RM/RT excused; dark in M12 | ⚠ segment bars, rolling time, played check; the morphing playing state |
| [tab-bar](./tab-bar.md) | page + material | ✓ | ✓ | ✓ | ✓ 3.3 : 1 | ✓ | badges, colour selection |
| [title-menu](./title-menu.md) | floating | ✓ | ✓ 22 − 4 | ✓ | ✓ | ✓ five measured moments | row icons |
| [settings-row](./settings-row.md) | page; pill wash | ✓ | ✓ | ✓ | ✓ | ✓ | leading icons, group boxes |
| [paywall](./paywall.md) | lit + raised | ✓ | ✓ | ✓ | ◐ as lit label | spec | tables, countdowns, testimonials |
| [composer](./composer.md) | raised (founder 20 Oct: never recessed); send lit (founder 20 Oct) | ✓ inner shade | ✓ 24 − 4 | ✓ | ⚠ focus ring 2.6 → 4.4 : 1 | ⚠ new: empty, typing (c6) | attachments, disabled send, counter |
| [voice-composer](./voice-composer.md) | raised bar; wells wash; send lit (founder 20 Oct) | ✓ inner shade | ✓ pill, 52 − 8 wells | ✓ | ⚠ listening ring vs field to measure | ⚠ new: drawn in onboarding (listening, speaking); muted states to draw | big talk button, type bubble, timer |
| [message](./message.md) | page / wash | ✓ | ✓ 20, tail 6 | ✓ | ✓ | ✓ every state (inside 02b part 08, M3): rest, arriving, loading, sending, not sent, offline, long press, empty, AX3, Increase Contrast, Reduce Motion; focused/disabled/RT excused; dark in M12 | bubbles, marks and receipts on Retrospect's lines |
| [guess-card](./guess-card.md) | wash → card on confirm | ✓ dashed, no shadow until true | ✓ | ✓ | ⚠ dash 3.5 : 1; marker 1.6 → 4 : 1 | ⚠ new: open, confirmed (c6) | ⚠ confidence dots |
| [you-map](./you-map.md) | page; nodes card | ✓ | ✓ | ✓ | ⚠ you node 2.4 → 4 : 1 | ⚠ new: rest with a guess node (c6) | legend, numbers |
| [goal](./goal.md) | card | ✓ | ✓ | ✓ | ⚠ did bar 2.5 → 4 : 1 | ⚠ new: rest, nothing yet (c6) | ⚠ summary line under the bars |
| [source-row](./source-row.md) | page; pill wash | ✓ | ✓ 10 radius well | ✓ | ✓ | ⚠ new: connect, connected, needs you (c6) | ⚠ red dot + "stopped" on error |
| [onboarding-question](./onboarding-question.md) | page | ✓ | ✓ | ✓ | ✓ | ⚠ new: asking (c6) | progress bar, back, illustration |
| [sheet-and-dialog](./sheet-and-dialog.md) | overlay | ✓ | ✓ 28 | ✓ | ✓ | ⚠ new: dialog (c6); sheet in the player | icons in dialogs |
| [toast](./toast.md) | floating | ✓ | ✓ pill | ✓ | ✓ 15 : 1 | ⚠ new (c6) | icon, close button |
| [loading-and-empty](./loading-and-empty.md) | page | ✓ | ✓ | ✓ | ✓ | ⚠ new: making (c5), empty (c6) | spinners, percentages |
| [lock-screen-and-widget](./lock-screen-and-widget.md) | system | ✓ | ✓ 22 | ✓ | ✓ | ⚠ new: small widget (c6) | progress, date |

## Found in this pass (beyond the list I gave you)
- **Five colour tokens failed contrast** once every component pair was measured: the guess edge (1.7 : 1), the guess marker (1.6), the did bar (2.5), the you node (2.4) and the field focus ring (2.6). All five were raised to pass in tokens.json and Paper. The pair check now runs inside `lint.mjs`, so a regression fails the check.
- **The specs said things the tokens didn't do.** Several specs named tokens that don't exist (`opacity.grain-*`, `glow.primary.Bottom`). They are fixed, and the linter now rejects unknown tokens.
- **Nine specs were missing whole sections** (chip, tag, the mark, segmented and tab bar were one paragraph each). All 27 now have every section, and every state is either covered or excused with a reason.
- **Six icons were missing** for states the specs described (retry, keyboard, send, alert, offline, download). They are drawn to the same grid and checked.

## Still open
1. **The lit label** (white on sky fails AA): b (deeper sky) or c (ink label, recommended).
2. **Display face:** Hedvig (today) or Exposure −20 (needs buying).
3. **Motion** is specified and drawn as frames, not yet as a live prototype.
4. **The mark's glyph is missing from every Paper drawing** (player header, messages, widget show the cream disc only). The only source is a 209 KB textured SVG in the app's assets, too heavy to paste in three times. It needs a simplified vector of the mark, or an image upload into Paper.
5. **The c5 and c6 drawings use colour values, not Paper's tokens,** in many places (dark tiles especially), so a token edit won't flow into them. The specs and tokens.json are right; the drawings would need re-pointing when they're built for real.

## hi-fi masters on 02 · components (20 Oct, founder-approved)

Each board holds the master on top and its states below. Every part was token-checked (0 raw values) and screenshot at 2–3× before it was placed.

| Board | From 02b | Master | States | Notes |
|---|---|---|---|---|
| c · brief card | part 03, D | D, artwork, at rest | none: playback is the mini-player's and the sheet's | A and E archived |
| c · tab bar | part 04, A | journal selected, progressive blur | none | the bubble behind it is now message.mine; Retro's line is in SF Pro (it was still inky) |
| c · top bar · journal | part 06 | at rest (inky title) | collapsed, scrolled | same bubble and SF Pro fixes as the tab bar |
| c · you map | part 05, orbits | orbits | none | hand-crafted by the founder; frosted orbs |
| c · voice composer | part 07 | listening | speaking, muted empty (raised), muted typing (send lit) | the recess is a recipe for other inputs, never this bar |
| c · conversation | part 08, A | one exchange | inside the exchange: voice note, failed send, guess card | no mark beside Retro's lines |
| c · player sheet | part 09 | playing | ready, held scrub (one-line chapter bubble), "…" menu (chapters, download) | transport recess = surface.washPressed (darker than its parent) |
| c · brief items + recap card | part 10 | now card, next rows, recap card | in context: the brief playing, and the Journal thread | |
