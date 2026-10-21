---
name: you-map
kind: component
platform: iOS (SwiftUI)
drawn: Paper · components · 06 conversation, you and system
---

# you map

What Retrospect understands about you, as a map you can touch: you in the middle, the people, goals, themes and places around you.

## Use when
- The You tab, and the paywall's small benefit drawing (same component, no labels when there's no data).

## Don't use when
- A list answers the question faster ("who did I see this week?"): You has a list view in its [title menu](./title-menu.md).

## Anatomy
- **canvas**: the page itself (level 0), no frame around it; grain at 4% so the open space isn't flat.
- **you**: the centre node, 56, `map.node.self`, *raised*.
- **nodes**: circles sized by how much they matter (`size.map.nodeMin` 12 → `size.map.nodeMax` 44), filled by kind (`map.node.person/goal/theme/place`), *card* tier shadows on nodes over 24 only.
- **edges**: lines `map.edge`, width by strength (`size.map.edgeMin` → `edgeMax`); strong links `map.edgeStrong`.
- **labels**: mono 11 `map.nodeLabel`, under nodes over 20 only; the rest label on touch.
- **guesses** on the map: dashed node rings (`inference.border`).

## Rules
1. **MUST** be built from the person's data only. *Because* a decorative map lies.
2. **MUST** label kinds with words in the legend-free way: tapping a node says "maya · person".
3. **NEVER** show more than 24 nodes at once; the rest are reached by zooming into a node.

## States
| State | What it looks like | Motion | Haptic |
|---|---|---|---|
| rest | as above | nodes drift ±1pt slowly (off with Reduce Motion) | — |
| pressed (node) | node 1.1×, a 2pt `map.selectedRing`; unrelated nodes to `opacity.dimmed`; a sheet rises with the node's story | `motion.spring.map` | `haptic.select` |
| focused | `map.selectedRing` on the focused node | — | — |
| loading | you + rings of skeleton dots appearing in order | stagger 60ms | — |
| empty (new) | you alone, and one line: "this fills in as we talk" | — | — |
| pending | a node being learned pulses once | — | — |
| error | the last map shown, with "couldn't update · showing last week's" | — | — |
| offline | the cached map, same line as error | — | — |
| disabled | not applicable | — | — |
| dark | nodes take dark map tokens; edges white 20% | — | — |

## Accessibility
- [ ] VoiceOver gets a list, not the canvas: "maya, person, closely linked to: work, running".
- [ ] Dynamic Type (accessibility 3): labels grow; fewer labels shown (largest nodes only).
- [ ] Reduce Motion: no drift; selection without spring.
- [ ] Reduce Transparency, Increase Contrast: edges one step stronger; labels `text.primary`.

## Taken out
- No legend: tapping says what a node is. A legend is a second thing to read.
- No colour per person: four kind colours only.
- No numbers on nodes: size already says how much.

## Edge cases
- Two nodes collide → the smaller moves; labels never overlap (hide the smaller label).

## Tokens
`map.node.self/person/goal/theme/place/source`, `map.nodeLabel/edge/edgeStrong/selectedRing`, `size.map.nodeMin/nodeMax/edgeMin/edgeMax`, `inference.border`, `opacity.dimmed`, `motion.spring.map`, `haptic.select`, `text.primary`.
