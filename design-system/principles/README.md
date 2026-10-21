# how this design system is made

These are the founder's requirements for the design system (20 Oct), each written as a key: what it asks, why it matters, and where it is applied. A component, token or page that breaks one of these is wrong, however good it looks. Topic docs hold the full rules; [craft.md](../components/craft.md) is the checklist every component is held to.

## The keys

| # | Key | Why | Applied in |
|---|---|---|---|
| 1 | **Keep our own feel.** Inspiration (Queue, Lime) is translated into our system, never pasted on. | Copying another app's look gives you their brand, not yours. | [inspiration-notes](../components/inspiration-notes.md) |
| 2 | **Lowercase.** Labels, buttons, titles, tags are lowercase; content keeps its capitals. | Calm and personal; caps shout. | every page; [organisation](./organisation.md) |
| 3 | **Small details compound.** Every detail is specified even when it is barely visible alone. | Quality is the sum of details no one notices one by one. | depth anatomy (f4), button anatomy |
| 4 | **Lime is the model for rigour,** not for looks: its interaction detail and how its docs are structured. | A system people can follow is as important as one that looks right. | specs in [components/](../components/README.md) |
| 5 | **The paywall button's full stack** (gradient, inner edge, ring, rim, grain, halo, cast, contact) is the standard for lit actions. | Depth is what makes the next step feel pressable. | [button](../components/button.md), c1 |
| 6 | **A real podcast player,** detailed down to the scrubber and transport. | Listening is the product's core moment. | [player](../components/player.md), c2, c3 |
| 7 | **Content first.** A page opens on what the person came for: an episode on its title, then the episode. | People come for the content, not the controls. | [player](../components/player.md); craft §8 |
| 8 | **Buttery interactions:** micro-animations, sheets that slide up, every motion choreographed. | How it moves is how it feels. | [motion-and-transitions](./motion-and-transitions.md) |
| 9 | **Well-made pills, concentric corners, fitting shadows, contrast, accessibility, simplicity.** | Each is a place where cheap apps show. | craft §3–5; [accessibility](./accessibility.md) |
| 10 | **Double strokes and double shadows** (a shallow contact and a warm cast), and **custom shadow colours.** | One flat shadow reads as a sticker; layered warm light reads as paper. | [surfaces](./surfaces.md), f4 |
| 11 | **Gradients that are beautiful:** mesh, texture, grain, properly ramped. | Bad gradients are the fastest way to look cheap. | [gradients](./gradients.md), f4 |
| 12 | **Icons as a system,** each one exactly representative and drawn pixel by pixel; the same care for tags and every small component. | Icons are read a thousand times a day. | [icons](./icons.md), f5 |
| 13 | **Blur in and out at edges and in text transitions,** researched and written as rules. | Edges and transitions are where text gets cut and motion stutters. | [motion-and-transitions](./motion-and-transitions.md), f7 |
| 14 | **Visual centring, never mathematical.** | Box-centred shapes look off; the eye judges mass, not boxes. | craft §2; every glyph and label |
| 15 | **Height is purpose.** Each component sits at one level on the z-axis, chosen for how much attention it should ask for. | Depth tells you what something is before you read it. | [surfaces](./surfaces.md), f4 ladder |
| 16 | **Accessible and WCAG-compliant, without getting heavy.** | Beautiful for everyone, not only for perfect eyesight. | [accessibility](./accessibility.md) |
| 17 | **Extremely clear organisation:** everything labelled, structured like Lime's docs. | A system nobody can find their way around doesn't get used. | [organisation](./organisation.md); Paper "00 · start here" |
| 18 | **Tokens cover every Lime category and everything the app needs,** in our own values, named by purpose, editable from one file. | One edit should change the app and Paper together. | [tokens](../tokens/README.md); refresh plan step 6 |
| 19 | **Everything in Paper,** with a page for every kind of token (dark, shadows, motion and haptics too). | The design file and the code are the same system. | Paper: 01 foundations |
| 20 | **Beige and blue, calibrated; one lit object per screen.** | Restraint makes the one sky moment matter. | tokens; craft §4 |
| 21 | **A final pass on everything:** every component played with, every state, spacing, grouping, scale, iOS-correct, at the level of the top 0.1% of apps. | The bones have to be right before the polish. | c1 state matrix; craft checklist |
| 22 | **Write all of this down** as the key to how the system is made. | So the next person, and the next pass, works the same way. | this file |
| 23 | **Tight, inky titles.** Titles are tracked in so the letters sit close and the line reads as one dark shape; an inky, textured display face is on the table. | Close-set, inky type feels printed and confident; loose type feels default. | [type](./type.md), f3b |
| 24 | **Every component packed with relevant detail,** each checked individually against all of these keys. | Detail is where quality shows, and only an individual check catches it. | [audit](../components/audit.md) |
| 25 | **Every element and every doc as well built as the components:** tokens, icons, specs and these pages held to the same standard, and checked by a script, not by memory. | A system is only as good as its weakest page. | [`lint.mjs`](../lint.mjs): sections, states, tokens, icons, links, audit rows |
| 26 | **Restraint: the simplest form that still does the job.** Each piece earns its place; nothing says the same thing twice; no indicator for fast things. Still full, never bare: the craft goes into the few things that stay. | Every extra mark competes with the content; focus is what makes it feel elegant. | craft §12; a "Taken out" section in every spec |

## Topic docs
- [surfaces.md](./surfaces.md): the z-axis ladder, the depth recipe, which component sits where.
- [gradients.md](./gradients.md): OKLCH, easing, mesh, grain, fades.
- [icons.md](./icons.md): the grid, keylines, stroke, optical rules, the set.
- [motion-and-transitions.md](./motion-and-transitions.md): touch, springs, choreography, blur edges, text transitions.
- [accessibility.md](./accessibility.md): measured contrast for every pair, and the rules.
- [type.md](./type.md): tracking by size, the inky display face, ink by size.
- [organisation.md](./organisation.md): naming, file layout, Paper structure, how a spec reads.
