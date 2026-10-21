# retrospect components

One file per component, in the form Lime uses (design.how/systems/lime), adapted for SwiftUI on iOS. The values live in [`../tokens/tokens.json`](../tokens/tokens.json); the drawings live in Paper (file "Retrospect", page 02 · components: c1 actions and controls, c2 the player, c3 player pieces, c4 menus, paywall and settings, c5 states, dark and access, c6 conversation, you and system). Run `node design-system/lint.mjs` after any change.

## How each spec reads

- **What it is for**, in one line.
- **Use when / don't use when**: so the right component gets picked.
- **Anatomy**: every layer, bottom to top, with its token. Detail that is barely visible still gets specified: small details compound, and that is what quality is.
- **Rules**: ordered by priority. **MUST** and **NEVER** break the system if skipped; **SHOULD** is style. Each rule says *because*.
- **States**: rest, pressed, focused, pending, disabled, and any of its own. Each with its motion and haptic.
- **Accessibility**: a checklist (VoiceOver, Dynamic Type, Reduce Motion, Reduce Transparency, Increase Contrast, 44pt targets).
- **Taken out**: what was removed because something else already says it (craft §12).
- **Edge cases**: what happens when the text is long, the network is slow, the phone is small, the person double-taps.
- **Tokens**: every token it uses, so a token change shows where it lands.

## House style for every component

- **Lowercase.** Labels, buttons, titles and tags are lowercase. Sentences that are content (a transcript, an entry, a description) keep normal capitals. Proper nouns keep theirs (Apple Health).
- **Geist for labels, mono for figures.** Buttons, tags, section and meta labels: `font.family.label` (Geist). Times, durations, prices and counts: `font.family.mono`. Reading text: `font.family.text`. Moments: `font.family.display`, with restraint.
- **One lit object per screen.** Only the primary action (or a destructive confirm) glows. Everything else is paper.
- **Press is weighted.** Scale to `motion.scale.press` in `motion.duration.pressIn`, back in `motion.duration.pressOut`; `haptic.press` on touch down for the lit actions only.
- **Nothing pops.** Things arrive with `motion.curve.standard` from `motion.scale.enter`; with Reduce Motion, opacity only in 140ms.
- **Shadows are layered.** Every raised object has a tight contact shadow and a soft cast, and a 1pt white top edge (`color.border.highlight`): lit from above.

**Read first:** [process.md](../process.md) (how every screen is made: plan flow → page → component → sub-component, build in reverse), [craft.md](./craft.md) (the rules), [audit.md](./audit.md) (every component checked against them), and [../principles](../principles/README.md) (why the system is the way it is).

Inspiration and how it was translated (not copied): [inspiration-notes.md](./inspiration-notes.md).

**Content first.** Every page opens on what the person came for: an episode page on its title and then the episode itself; controls come after the content, never before.

## Masters, copies and the sync (the wiring, M0 of the hi-fi plan)

Paper has no linked instances we can rely on, so the link between a component and every place it's used is ours. It holds by a naming rule and a sync step.

- **Masters live on `02 · components`**, one board per component: the master on top, every state under it. A part only becomes a master after the founder approves it. Until then it waits on `00 · approvals · waiting on you`; decision cards, once decided, live on `02b · decisions made`.
- **Every use is a named copy.** Its layer name is `c:<component>/<variant>/<state>`, for example `c:pill/neutral/rest` or `c:message/mine/sent`. A master's own layer name is the same string with `master:` in front of it.
- **Copies carry content, not style.** Text, images and values can differ per screen. Fills, strokes, shadows, radii, spacing and type must match the master exactly.
- **The sync** (`design-system/sync/paper-sync.mjs`) compares every copy with its master, using snapshots read from Paper (get_jsx), and reports any style that drifted. A master change gets pushed to every copy. A copy change gets flagged, and the founder decides: change the master, or keep it as a named variant.
- **One source for values.** tokens.json feeds Paper's tokens and, later, the Swift code, so a token change moves everything at once.

## Components

| | Component | Status |
|---|---|---|
| Actions | [button](./button.md) · [talk-button](./talk-button.md) | specified, drawn, audited |
| Controls | [switch](./switch.md) · [tag](./tag.md) · [segmented](./segmented.md) · [chip](./chip.md) | specified, drawn, audited |
| Listening | [player](./player.md) · [scrubber](./scrubber.md) · [transport](./transport.md) · [mini-player](./mini-player.md) · [brief-card](./brief-card.md) | specified, drawn, audited |
| Structure | [tab-bar](./tab-bar.md) · [the-mark](./the-mark.md) · [title-menu](./title-menu.md) · [settings-row](./settings-row.md) · [sheet-and-dialog](./sheet-and-dialog.md) · [toast](./toast.md) | specified, drawn, audited |
| Conversation | [onboarding-question](./onboarding-question.md) · [message](./message.md) · [composer](./composer.md) · [voice-composer](./voice-composer.md) · [guess-card](./guess-card.md) | specified, drawn, audited |
| You | [you-map](./you-map.md) · [goal](./goal.md) · [source-row](./source-row.md) | specified, drawn, audited |
| Patterns | [paywall](./paywall.md) · [loading-and-empty](./loading-and-empty.md) · [lock-screen-and-widget](./lock-screen-and-widget.md) | specified, drawn, audited |
| Next | journal entry page, list row, search results | to specify when their pages are defined |
