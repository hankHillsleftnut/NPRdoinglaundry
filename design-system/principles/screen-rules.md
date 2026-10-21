# screen rules

How every remaining Retrospect screen is built. Each rule is something the founder said while reviewing the first screens (20 Oct), written so it can be checked. They sit on top of the [keys](./README.md), [craft](../components/craft.md) and the [process](../process.md); where they differ, these win, because they are the founder's latest word.

## Words on the screen
1. **One title per screen.** Never a subtitle or lead-in line above it ("no subtitle then title, just one"). At most one short description under it, in plain text.
2. **Purpose pages are a title and a description.** Privacy, connect and anything like them say their purpose in one title and one plain description, not in lists of labelled facts ("simplify this page").
3. **A purpose page gets a picture, not more words.** Make it feel considered with one visual moment (privacy: a raised lock in soft rings), centred above the title ("make this much nicer").
4. **Almost no mono.** Labels are Geist (`font.family.label`); mono is only for figures that count or tick (times, durations, prices). No callouts, hints, "why it asks" lines or state lines in either ("less of these mono font little callouts"; "use geist for now", 20 Oct).
5. **Content is inky and big; support is plain.** Retro's question and your own words use the inky display face; anything that supports them is the sans in `text.secondary`.

## Onboarding shape
6. **No skip.** A quiet back arrow top-left, the page label centred, nothing on the right.
7. **One global progress bar** under the status bar: 3pt, `surface.track` with an `ink.default` fill that creeps forward each turn. Never a count.
8. **One question per screen**, like the iOS app today: Retro asks with haptics, you answer by voice, and you can type at any moment.
9. **Talk or type is chosen once**, with the segmented control (the selection controls are the quality bar).

## Answering
10. **The input is the onboarding text-question bar** from the current app (`VoiceGoalsPage.inputBar`, "what should I call you?"): a 56pt pill that grows upward, a 32pt round button in the bottom-trailing corner. It is the [voice composer](../components/voice-composer.md): voice-first, the corner button is mute, and becomes send once you type.
11. **Your spoken words appear on the page**, under the question, in the inky face at 28 in `text.secondary`, and every new word **blurs in** (blur 4 → 0, opacity 0 → 1, 200ms, staggered). The bar only shows its state ("listening…").

## Choices
12. **Lead with Retro's recommendation.** When Retro has a view (how straight to be, a plan, a source), show its pick first as one raised card with the reason inside it ("because you said…"); the alternatives sit below as quiet rows under "or choose another".
13. **Everything for one purpose on one page.** No "more" sub-pages: connect shows every source, then accounts, files and public profiles, on one scroll ("this should all be on one page"). If a section isn't needed, cut it ("we don't need this").

## Colour and actions
14. **Blue has four jobs only** (see [surfaces · where blue goes](./surfaces.md)): the one lit action, Retro listening, a link inside text, and the matched words in search results (accent.text, medium; the founder's call, 20 Oct 2026). Meters and progress fill with ink; selection is a raised thumb or an ink tick.
15. **Secondary actions are obvious by depth, not colour.** "connect", "add", "how" are raised neutral pills with an icon from the set and `text.primary` medium ("make the connect button more obvious"; semibold read too thick, founder 20 Oct).
16. **Third-party sources use their real logos**, kept in their own colours, as app-icon tiles.

## Depth and motion
17. **Progressive blur wherever scrolling content meets a bottom element** (the composer, the tab bar, the mini-player): three stepped backdrop blurs under an eased fade to the canvas, so cards dissolve rather than cut.
18. **Keep the progressive blurs and selection controls**: the founder named both as the quality bar.
19. **Tiles respond to scroll** (offset and tilt on a spring) and episodes and briefs are tiles, not rows.
20. **The player sheet shows the page behind it as a page** (lighter, rounded, dimmed), with the title in the inky face.

## Things already decided that every screen must keep
21. The splash is the K1 constellation with sign-in; cards and gradient orbs stay; data stars emit light, never reflect it.
22. Sign-in buttons: Apple standard black; Google a white raised button with a warm hairline, never a dark border.
23. Light mode first; dark is drawn per flow once its light screens are approved.
24. Components become real 390-wide phone screens when their page is built.

## How we work on them
25. **Show work in chunks of three or four screens and ask** before going on; ask instead of assuming.
26. **Address every Paper comment** the moment it lands, resolve it, and log it in the findings log.

## Journal
27. **Journal is a conversation with Retro.** You message it (talk or type in the voice composer), your messages and its replies form the thread, newest at the bottom like any messaging app. Your messages are raised bubbles on the trailing side, each with saved → sent → read; Retro's replies sit unboxed on the leading side in the inky face.
28. **Today's brief stays anchored at the top of Journal.** The thread scrolls under it (progressive blur where they meet); scrolled, the card compacts to a slim bar that keeps its play button.
29. **Journal is one continuous thread; the drawer is its index.** Scroll up in Journal to go back through every conversation. The all-journals button top-left (or an edge swipe) opens the drawer that exists in the app today: the page slides aside, rounded and shadowed, and the drawer behind lists every conversation and note by day, in your own words, with search on top. Tapping one closes the drawer and jumps the thread to it.

## Spacing (founder: "more spaced out, more breathable", "better padding"; craft §8, space tokens)
30. **8pt grid, 4pt half steps; space groups things, not lines.** Within a group 4–8 (a title and its label 8, `space.stackTight`), related blocks 16 (`space.stackDefault`), between groups on a screen 24, between sections 40.
31. **Screen margin 24, reading width 326, primary actions in the bottom third.** Side-by-side items 12 apart (`space.inline`): plan cards, source cards, chips.
32. **Journal: 24 between entries (`space.betweenEntries`), 40 between days,** the day label 8 above its first entry; the composer floats 12 above the tab bar.
33. **Every tappable thing has a 44pt hit area** even when it draws smaller (chips 36, the drawer button 36): pad the frame, not the visual.

## Paper notes (so the drawings match the rules)
- Paper doesn't draw `border` with a token width: draw strokes and dividers as box-shadow strokes.
- Paper ignores colour on inline `<span>`s: text that changes colour or blur mid-line is drawn word by word.
- Paper ignores `<style>` classes: every style is inline and token-only, checked with `token-check.mjs`.
