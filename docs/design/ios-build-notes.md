# iOS build notes from Paper comments

> **Progressive blur: see [progressive-blur.md](progressive-blur.md)**, the single source of truth (20 Oct). Older blur notes below are superseded where they differ, especially any that say to blur a second copy of the text.


Your Paper comments are also instructions for how the iOS app should be built. Each one that says how something should behave, move, load or work is copied here under its component or screen, with the date and your words. The design part is fixed in Paper and logged in findings-log.md; this file is what SwiftUI (M14) has to honour.

## Icons
- **20 Oct · "make the icons have a little bleed, like they are ink… complete components… SVGs"**: ship every icon as one filled path (`design-system/icons/shipped/*.svg`, 24pt; `shipped-20/*.svg` for 20pt in buttons) as template images in the asset catalogue; no SF Symbols for these 36.
- **20 Oct · "visually centered" (skip 15 / 30)**: the numerals are part of the path, so don't overlay text in SwiftUI.
- **20 Oct · "make the inked icons the standard when I fully approve them"**: once part 00 is approved, every glyph in the app uses the shipped set.

## Pills and buttons
- **20 Oct · "this font is too thick"**: pill and button labels are Geist medium (500), not semibold.
- **20 Oct · "are these selected states?"**: don't draw a custom focus ring; rely on the system's Full Keyboard Access focus.

## Brief / player
- **20 Oct · "this should not be a clean break, it should be like the segments are pills"** (scrubber): each chapter is its own capsule with a 4pt gap; the played and loaded fills live inside each capsule and are clipped by it. Not one bar with tick marks.
- **20 Oct · "this button needs to be visually centered"** (lit play): use the shipped play path centred by its own frame; no manual x-offset (the triangle is already balanced by its ink).
- **20 Oct · "i still prefer this over what you have showed me"** (brief card D): the card stays the same at rest; playing state is handled by the mini-player and sheet, not by morphing the card.
- **20 Oct · "what is this not right button?"** (player sheet): the action is "correct this part"; it opens the correction flow for the part being spoken (the corrections loop), not a generic menu.
- **20 Oct · "visually center this"** (dark transport): same as the lit play: shipped glyphs, no offsets.
- **20 Oct · "make this recessed feeling a little bit better"** (dark transport): the recess is drawn with inner shadows on the canvas colour (deep top shade, light catch on the bottom lip), not a lighter fill.
- **20 Oct · "too much padding on the right edge"** (mini-player): the title column flexes to fill; both insets 10.
- **20 Oct · "i want the title to scroll up when the episode starts"** (player sheet): two states. Ready = big inky title + from-line above the transcript. On play, the title and from-line scroll up out of view and the header-left swaps "your weekly episode · today" for the title in Geist 500 14, one line, truncated (same collapse as the top bar). Animate it as a scroll, not a crossfade; respect Reduce Motion (cut instead).
- **20 Oct · "make sure that this has progressive blur on top and bottom"** (transcript): a real variable blur, not a colour fade. ~~In SwiftUI, a blurred copy of the text…~~ superseded: build per progressive-blur.md (one masked backdrop blur, or the system soft edge on iOS 26). At the very start of the episode there is nothing above, so no top blur. The current line stays sharp and centred as it advances.
- **20 Oct · "chapters can be a part of the drop down on the left"** (player): the chapters pill is gone; the "…" button opens a menu (raised panel, 44pt rows, Geist 500): chapters › (pushes the chapter list), download. Use a native `Menu` styled to match. The founder hasn't confirmed the menu's other items yet.
- **20 Oct · "ths correct this part button should be above the progress line"** (player): the pill sits between the transcript and the scrubber, leading-aligned, with the "correct" speech-bubble glyph. It hides while the user scrubs or while the "…" menu is open.
- **20 Oct · "when the user taps and holds to drag, there should be a little bubble that pops up that shows what chapter they are on"** (scrubber): on long-press drag, the thumb grows 12 → 20 and a raised bubble rises over it showing "chapter N · name" (Geist 500 14) and the time under the finger (mono 12). It follows the thumb, clamped to the sheet's margins. A selection haptic fires each time the finger crosses into a new chapter. The audio seeks on release, not while dragging.
- **20 Oct · "this small component has a poor layout, fix that"** (scrub bubble): the bubble is one line, the chapter name only (Geist 500 14), in a raised 32pt capsule centred over the thumb. The times stay in the row below and follow the finger, and that row's own chapter label fades out while you hold, so nothing is said twice.

## Tab bar
- **20 Oct · "the bottom area needs to have a progressive blur… should never obstruct the options"**: no bar plate; content under the tab bar goes through a progressive blur that starts ~90pt above the tabs and reaches full strength at the labels, with a canvas tint on top.
- **20 Oct · "make sure that this progressive blur is the real deal"**: one variable blur, not stacked bands. iOS 26: the system soft scroll edge (`.scrollEdgeEffectStyle(.soft)`-style behaviour on the tab bar); iOS 18: blur the content once and mask the blur in with a gradient (`.blur` + `.mask(LinearGradient)`), never several fixed-radius layers.
- **20 Oct · "lets do this"** (version A): system tab bar position and slots; selection by weight (2.2 emphasis outline) and Geist 500 label, no tint.

## Top bar
- **20 Oct · "have this be the thing until the user starts typing, and then this can be the smaller version" / "this can be the version you see when you have already scrolled and you are typing"**: Journal's top bar has two states. At rest (scrolled to the top, keyboard down) it shows the inky title "journal" leading after the drawer button. As soon as the thread scrolls or the composer gets focus, it collapses to the small centred Geist name, with the drawer button fixed. Animate the title shrinking into place (a matched-geometry move, ~300ms spring), and reverse when you scroll back to the top with the keyboard down.
- **20 Oct · "i like the idea of having this top blend and blur, but this implementation needs to be better, make a note of that"**: keep the blend and blur under the bar, but build it properly: one variable blur (soft scroll edge on iOS 26, one masked blur on iOS 18) that grows as content passes under the bar, never two stacked copies of the thread as drawn in Paper.

## You map
- **20 Oct · "make sure the letters are not obstructed like this"**: names never sit on a thread or a ring. Place each name on the side of its orb away from you, and give it a canvas-coloured plate (2 × 4 padding, small radius) so anything passing behind stops at the text.
- **20 Oct · "the solution is not to put this in the card… mark it as a hand crafted component"**: the constellation is built by hand by the founder; don't generate it from a layout algorithm without their sign-off.
- **20 Oct · "i like the ring in the back, but i dont want the orbs to feel so transparent" / "blur the line below them… see through like they are now"** (orbits): the map draws threads and orbit rings first, then each orb as frosted glass: a 12% white base under its gradient and a small backdrop blur (~1.5pt), so whatever passes behind an orb is visibly softened. In SwiftUI: `.background(.ultraThinMaterial)`-like frosting clipped to the circle, or a manual blur of the layer behind.
- **20 Oct · "you can make the constellation more like this, they feel like space mirrors"**: orbs are glass spheres (two light gradients, a top rim, a hairline, a soft cast); far ones are smaller, blurred and dimmed for depth.

## Composer
- **20 Oct · "this selected state feels a bit crude"**: focus/typing is shown by the field lifting (sunken → raised, 160ms), never by a coloured outline; the send stays raised, never lit.
- **20 Oct · "the message area should not be recessed… use this as the recessed treatment elsewhere but this will not be the main input card on the home screen"**: the home composer is raised white in every state (empty included). Keep the recess (background.sunken + inset shade + bottom-lip catch) as a reusable `RecessedFieldStyle` for other inputs, such as search.
- **20 Oct · "make sure the corner radius of this has squircle treatment in SwiftUI, make that as a developer note"**: build the composer shape with `RoundedRectangle(cornerRadius: 28, style: .continuous)` (or `.rect(cornerRadius:style: .continuous)`), never the default circular corners. Use the same for every radius token in the app: cards, pills, sheets and wells are all continuous (squircle) corners. Concentric insets still subtract radii.
- **20 Oct · "this button needs color"** (send, typing state): send is lit, using the brief-card play's glow.primary recipe scaled to 32 (gradient, rim, edge, bloom, 1pt ring, halo, cast; glyph in glow.primary.foreground). It's the one blue thing on the bar and appears only once there are words. This overrides composer rule 3 ("never glow the send"); the founder's call.

## Conversation
- **20 Oct · "i like this messaging style for the audio messages"** (voice note): keep the voice-note bubble as drawn, the same wash bubble as text with a raised play, 3pt level bars (played part darker) and the length in mono.
- **20 Oct · "there should not be a icon here. that is not needed"** (Retro's message): no mark or avatar beside Retro's lines. Its text starts at the leading margin; unboxed text versus your wash bubble is the only tell of who's speaking.

## Sheet and widget
- **20 Oct · "no blue gradient"** (player sheet): plain raised surface.
- **20 Oct · "make this phone sized"** (widget): ship the small widget at the system size (170pt on 390pt phones); preview it in a home-screen context.

## Drawer (part 23, this session)
- Entry rows: `lineLimit(2)` with a trailing ellipsis on your words; the meta line is one line.
- Search results: mark the matched word with an `AttributedString` run (background surface.wash.pressed, weight medium, 2pt horizontal inset), not blue.
- Unsent rows: "not sent · tap to retry", where tapping the row retries; the row stays in the list until it sends.
- The day label pins under the search field while its rows scroll (sticky section header).

## Entry (part 24, this session)
- "not right" on a claim sends the correction to the brain at once. The row strikes through over 240ms and says "noted"; the next brief won't lean on that claim (O-10).
- "delete it" removes the entry and everything taken from it (K7). haptic.warning on touch down; the dialog is the only place a destructive glow appears.
- Edits re-send the entry: the meta line says "retro is reading it again" until the claims refresh.
- Offline: edits, corrections and deletes queue and show "waiting to send".

## Icons, round 3 (20 Oct)
- "not right" (correct) = speech bubble with a dash; use it on every "not right" control (entry claims, the brief sheet, episodes).
- offline = wifi arcs stopping short of the slash; always shown with the word.

## Settings rows (part 26, 2026-10-20)
- The whole row is the target for switch, choice, link and danger rows. Settings apply at once, with haptic.select. Danger opens the part 24 dialog, and haptic.warning fires only inside it.
- Source row: the subline is the source's purpose, not the data it reads. It wraps to at most two lines and never runs under the trailing status or connect pill. Status crossfades over 200ms.

## Search and type (founder comments, 20 Oct 2026)
- "the kerning on this font is not great… needs to be tighter": use the system SF Pro body style, which already tracks 17pt at about −0.43pt. Never set tracking to 0 on body text.
- "for this to be properly recessed… it needs to be darker than the background it is on": sunken fields fill with a translucent dark wash over their parent (surface.washPressed), not a fixed colour.
- "have the keywords blue": in search results, the matched words are accent.text, medium weight, using an AttributedString range per match.

## Switch and entry (founder comments, 20 Oct 2026)
- Switch: no pending visual ("this does not make sense"). Toggle optimistically; on failure animate back and show the reason in the row subline.
- Delete dialog: full width minus screen margins (342 on a 390 screen), centred, over a dimmed page. The destructive button follows the refined danger recipe (no outer ring or halo).

## You map (more)
- **20 Oct · "straight lines"** (the hand-crafted map): threads between stars are straight segments, never curves. Weight and opacity still carry how strong a link is.

## Settings decisions (founder, 20 Oct 2026, decision cards 02–04)
- Every settings row leads with a 32 soft square (radius.default, surface.wash) holding a 20pt inked glyph in icon.default.
- Rows that choose from a short list in place end in chevron-up-down (↕) and open a menu; rows that open a page end in chevron-right (›).
- Source status "syncing" ("make it a rotating line in a circle, not a dot, same size"): a 6pt ring in border.strong with a quarter arc in text.secondary, rotating once a second, linear. Reduce Motion: the arc stays still. Always shown with the word "syncing".

## Journal pages (M4, 20 Oct 2026)
- Drawer width = screen width − 74 on every device: the journal keeps 74pt of its edge visible as the way back.
- The status bar stays fixed over both layers when the drawer opens; the journal slides under it.
- Drawer foot: settings · version, pinned to the bottom (16 off on SE, 32 above the home indicator elsewhere). The list fades out under it (a progressive blur in the build).
- Row words and entry words use balanced line breaks (`.lineBreakStrategy(.standard)` plus a balanced-wrap helper), so no word sits alone on the last line.
- Offline drawer: the list opens from local storage. One grey line under search says "offline · new notes send when you're back"; queued notes read "waiting to send". Not red.
- Entry, voice note: a play row (36 wash button with play, a 2pt track, the duration) sits under the meta line; the words are the transcript.
- Entry, nothing taken yet: the list shows "retro hasn't read this yet. it will in a minute." and fills in on its own when the read lands.
- Entry, editing: TextEditor in a sunken field (surface.washPressed, radius.field). The bar reads cancel · "edit this entry" · save, with save in plain ink. Delete hides while the keyboard is up.
- SE: 20 margins and square screen corners.
- Journal opens with the mic off; listening starts only when you tap the mic (founder, 20 Oct). The listening glow is the blue listening job, not a second lit action.
- Brief card: the headline keeps 48pt clear on the trailing side so the seam play never covers a word, at any width.
- Player sheet (brief mode): the middle region flexes; scrubber and transport are pinned to the bottom above the home indicator on every device. The status bar stays visible over the strip above the sheet.

## Brief items (more)
- **20 Oct · "what is this up here… what is its purpose"** (the now card on the brief sheet): the card names itself. Label "playing now"; the why line reads "here for your goal: <goal>"; the source line keeps "from …" with a chevron to open it.

## Composer (more)
- **20 Oct · "make this whole active listening state more elegant in general":** listening = a 1pt `voice.listening` hairline plus a soft halo below (0 10 28 −10, `glow.primary.halo`); no ring, no inner tint.

## Podcasts list · bottom edge (comment c-w1pgjf, 20 Oct)
- The content under the tab bar uses a progressive blur that keeps its colour: 0 at ~120pt above the bottom edge, rising to about 14pt blur with saturation boosted ~1.5× at the tab labels. Only a faint canvas tint (bottom 56pt, transparent → background.canvas at opacity.disabled 0.4) for label legibility. It must never look grey (founder, c-w3ukjt).
- SwiftUI: a variable blur (gradient-masked blur) behind the tab bar, not a hard material edge.

## Evidence row ("what it rests on", comment c-7iso8b, 20 Oct)
- The excerpt is one line: `.lineLimit(1)`, `.truncationMode(.tail)`, text.md, full width between the kind well and the chevron. Never wraps to two lines.
- Rows are separated by a 1pt border.subtle line (not a 0.5pt hairline).

## Onboarding question (part 42, 20 Oct 2026)
- Progress: a 3pt capsule under the status bar, `surface.track` with an `ink.default` fill that animates forward each turn (spring); never a step count.
- Your words: each recognised word appends as its own Text, blur 4 → 0 and opacity 0 → 1 over 200ms; the newest is still resolving while you talk.
- Quick answers: a flow layout of 36pt capsules; selection toggles ink and appends the word to the composer's text, which switches to the typing state with the lit send.

## Composer · listening look (comment c-mi7i0c, 20 Oct)
- No stroke in accent. Edge: 0.5pt glow.primary.ring. Glow: glow.primary.halo, radius 24, spread −6, centred (no y offset). Level bars: max 14 at rest of the animation, quiet heights.

## Podcasts list · bottom edge, final (comment c-axmhuk, 20 Oct)
- Replaces the earlier notes for this edge. A variable blur ramps smoothly from 0 to ~20pt over the bottom ~150pt, with saturation boosted (~1.6×) so the artwork colour carries.
- On top, a 170pt colour gradient: amber.300 radial glow bottom-leading, sky.400 radial glow bottom-trailing (each ~45%), plus a canvas veil up to 70% at the bottom edge; the whole layer fades in from transparent at its top. Never a grey wash, never a visible start line.

## Onboarding quick answers · selected (comment c-6gtmpz, 20 Oct)
- Selected pill: background.raised with the raised depth shadows, a 14pt checkmark leading, label text.primary. Unselected: surface.wash. Cross-fade 200ms and haptic.select on toggle. No ink fill.

## Journal · message width and slim brief bar (c-mjy9uu, c-qo8aha, 20 Oct)
- Retro's text: full column width. Your bubble: `.frame(maxWidth: column * 0.8, alignment: .trailing)` with the text hugging. No balanced wrapping.
- Slim brief bar (scrolled): 12pt padding, 52pt artwork thumb, 40pt lit play, headline up to two lines. It must be taller than the "brief being made" row (64pt).

## Episode artwork · mesh gradients (c-e42cnl, c-scy4k9, 20 Oct)
- Use SwiftUI `MeshGradient` (3×3, `smoothsColors: true`) per episode kind, with the recipes in design-system/hifi/mesh.py: weekly dusk, brief sky, first green, older warm grey. Each has a sun in the top-trailing corner (amber.200), a body colour, a dark anchor bottom-leading, a warm accent and a small highlight. Add a fine grain overlay (about 3–4% opacity) to stop banding.

## Podcasts bottom edge · final (c-z28ko7, 20 Oct · replaces the earlier notes)
- Under the tab bar the page is opaque background.canvas, never translucent. Above it, a fade from canvas to clear over ~100pt, with a variable blur of the content behind (stronger toward the tabs).

## Mini-player progress · C fill (c-wx86ve, 20 Oct)
- The pill's background fills leading → trailing with amber.300 at 22% (a slightly brighter 34% leading edge), linear with playback. Paused: it holds and dims to opacity.pressed. Reduce Motion: updates in steps, no sweep. Preview: docs/design/motion/mini-player-fill.html.

## Search answer citations (part 50, YO-2)
- Each claim in the answer ends with its source number. In Paper it is drawn as a superscript numeral (¹ ² ³) because Paper flattens inline styled runs. In SwiftUI, build it as an `AttributedString` run, a small mono number (text-xs) on a `surface.wash` capsule (18 high), baseline-raised 2pt. Tapping it scrolls to and briefly highlights the matching source row.
- A guess sentence starts with "a guess:" in the label style and is set in body type (text-secondary), not the inky answer type, so it reads as less sure without relying on colour.

## Goals list: questions lead (2026-10-20)
- When retro has a "is that a goal?" question, its card is the first item in the goals scroll.
- Answers are two equal-width grey buttons (surface-wash, 44 pt, radius-control), not raised pills.

## Account: sign out
- Full-width secondary button: icon `sign-out` (20 pt, icon-default) + label "sign out" (font-label, medium).
- Caption under it in text-sm, secondary: "signed in with apple. your entries stay; sign back in any time." Use the provider the user signed in with.

## Why sheet: raised cards inside the scroll
- Raised cards (e.g. "where retro says it") cast shadows past their bounds. Use `.scrollClipDisabled()` on the sheet's ScrollView so the sides don't get clipped.

## Player transcript (20 Oct)
- Lines: Exposure (inky, weight 399) 20pt, tracking −0.02em, line height 1.3; 20pt between lines. (Superseded SF Pro semibold, 20 Oct.) Spoken line text.primary; past tertiary; next secondary.
- Edges: real progressive blur. Top band 96pt (64 on SE) and bottom band 140pt (80 on SE) use a variable blur (8pt at the edge → 0) plus the sheet colour easing in. Don't fake it by blurring a second copy of the text. Keep the spoken line in the clear middle.

## Goals: retro's question card
- A grey card (surface.wash, no dashed outline). Yes / not quite are two equal raised-paper buttons, 44pt.

## Welcome back (AC-1) trigger
- Keep a Keychain flag `hasSignedInBefore` (no personal data). On launch, no session + flag set → AC-1 "welcome back". No session + no flag → the splash.
- It shows after a sign-out, or when the Apple credential can't renew silently. A brand-new phone shows the splash; after sign-in the server recognises the account and restores state.

## Sheets: spacing by group
- A sheet groups its content: title+line (8), related note (16), break (32), actions (4 between primary and cancel). Never one even gap for everything.

## Welcome back (AC-1) look
- The splash's warm wash plus the You map (orbits) without labels behind the title. Never show node names before auth. On SE, scale the map to 0.78.

## Dark mode (M12 recalibration, 20 Oct · founder: "every day mode screen needs to be recalibrated to being in dark mode… check… contrast and all that")
- **One rule, no per-view dark code:** every colour is an `RColor` dynamic colour generated from `tokens.json` (`$value` light, `$extensions.retrospect.dark` dark). A view never checks `colorScheme` to pick a colour. The dark page in Paper (`05d · dark mode`) is the same screens with each `--color-X` swapped for `--color-dark-X`; nothing else changes.
- **Sunken is darker than its parent in both modes.** `surfaceWashPressed` (search fields, the transport recess, pressed washes) is black 30% in dark, not a white wash. `backgroundSunken` is night.950, below the night.900 canvas.
- **The journal drawer sits on `backgroundUnderlay`** (new token), not `surfaceControl`. Light: paper.200, unchanged. Dark: night.950, so the page that slides aside reads as raised above it. The foot fade under the drawer list fades to the same token.
- **`surfaceLifted` (new token):** a paper-coloured pill or card sitting on a tinted or raised parent (the yes / not quite pills in retro's question card, cards inside a sheet, rows on a control). It's the canvas colour in light and night.750 in dark. Never fill those with `backgroundCanvas`: in dark the canvas is the darkest surface, so they'd read as holes.
- **Outer hairline in dark is faint white** (`depthStrokeOuter` white 7%), not black. Canvas-coloured grouped cards keep a visible edge on the night canvas.
- **Depth in dark:** shadows stay in the stack but go black (`depth.shadow.*` dark values), and the visible edge comes from the lighter surface plus the white inner strokes (`depth.stroke.inner` 8%, `innerTop` 14%). The layer order is canvas night.900 → card/raised night.800 → control night.750. Second shadow layers that have no dark value are 0% (`shadow.card.2`, `menu.2`, `mark.2`, `primaryAction.3`), so build them as one layer in dark.
- **Lit actions:** use the `glow.primary.*` dark set (brighter gradient, bloom and halo, black cast). The label stays white (`glowPrimaryForeground`).
- **Sign in with Apple** follows Apple's dark style: white button, black label (`signInAppleFill/Label` dark). Google uses its dark fill `#131314` with the `#E3E3E3` label. Use the system `SignInWithAppleButton(.white)` style in dark rather than recolouring.
- **System chrome doesn't change:** the lock screen, lock-screen notifications, now-playing, and the home-screen status bar and indicator are drawn the same in both modes. They're the system's. Widgets do follow dark (use `containerBackground` with the dynamic colours).
- **Artwork meshes keep their palette colours** in dark (sky, amber, paper). They're pictures, not surfaces. Keep the grain overlay.
- **Status colours** use their dark text tokens (`statusDangerText` red.200, `statusSuccessText` green.200) whenever they're words. The dot or fill uses `statusDanger`/`statusSuccess` (300).
- **Transport skip glyphs:** the shipped skip-15/30 SVGs carry a raw `#5F5D5B` fill. Ship them as template images tinted with `textSecondary`, so they go light in dark (otherwise they'd stay grey on the dark tray).

## Onboarding questions · typing haptic (founder, 21 Oct)
- While Retro types out a question (ON-3–9), play `haptic.typeOn`: `UIImpactFeedbackGenerator(style: .soft)` at intensity 0.35, fired once per word as it appears (never per letter), at most ~10 a second, skipping spaces and punctuation. Call `prepare()` once when the question starts.
- Stop as soon as listening starts (`haptic.listenStart` takes over). No typing haptic when Reduce Motion skips the type-on, or when system haptics are off.

## Shadows · the box-shadow look (founder, 26 Oct: "exactly Paper", "no overriding")
- **SwiftUI's `.shadow` has no spread.** Never draw a Paper shadow layer with a non-zero spread through `.shadow`. Use `rBoxShadows` with an `RElevation.boxShadow*` token. A negative spread (`0 12 28 −12`) pulls the shape in before blurring. Dropping it makes the shadow wider than the object and lifts it above the top edge (the composer's "lip"): about 16pt for the cast and 36pt for the ambient, against Paper's 4 and 16.
- **Pull-in technique:** for each outer layer, take `shape.inset(by: −spread)`, `.offset(x, y)` and `.blur(radius: blur / 2)`. Mask the stack to outside the shape (`destinationOut`), so cross-fades and translucent fills never show their own shadow. Inset layers: fill outside a pulled-in, offset copy of the shape, blur it, and clip to the shape.
- **Top light:** `inset 0 1 0 depth.stroke.innerTop` is a crescent, 1pt on the flat top and thinning to 0 down the corners. It is not a 1pt strip masked to the top row.
- **Outer hairline:** `0 0 0 0.5 depth.stroke.outer` is fully outside the edge. A centred `.stroke(0.5)` hides half of it.
- **Exact numbers (Paper file 01M5D5J321P5X86ZT58002B7NT):**
  - Composer rest (1F7K-0): inset 0 1 0 · inset 0 0 0 1 · 0 0 0 0.5 · 0 1 2 · 0 12 28 −12 · 0 24 60 −20.
  - Composer listening (26LI-0): inset 0 1 0 · 0 0 0 0.5 ring · 0 1 2 · −64 10 34 −16 · 72 −6 30 −14 · 18 20 36 −18 · −10 −12 26 −16.
  - Pill rest (D9Z-0): strokes · 0 1 1.5 · 0 4 6 −2.
  - Pill pressed (DA6-0): strokes · 0 0.5 1 · 0 1 2 −1.
- **Which look where:** composer and raised pill have `look: .current` (default) and `.paper`. CN.connect's `+ connect` pill switches to `.paper` after SH.composer merges. Every other component keeps its recipe until the founder answers the audit questions.
- **Tests:**
  - `design-system/tokens/tokens.test.mjs` freezes every pre-existing token and the existing generated Swift, and pins each new stack to Paper's CSS.
  - `RVoiceComposerPaperTests` pins the Swift stacks and checks, rendered, that nothing is drawn under the shape and that the top light is the crescent.
