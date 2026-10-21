# The 16 product goals

Founder list, written 16 September 2026. This is the checklist the product has to make progress on.

Original ask: for each step, say how built it actually is, and how that compares to a sophisticated approach — no fluff.

Later work in this thread scored **previous** (shipped Cook 0 / A / B / C) against **new** (designed second-brain architecture). New is the plan, not shipped code. Voice (15) and on-device delivery (16) were taken out of brain scope.

Interactive scorecard: Cursor canvas `product-goals-old-vs-new.canvas.tsx`. SOTA audit of the same 16: [07-sota-capability-map.md](./07-sota-capability-map.md). Spec: [01-locked-product-behavior.md](./01-locked-product-behavior.md). Plan: [06-implementation-plan.md](./06-implementation-plan.md).

---

## The list (as written)

1. Data sources
2. Ingestion system
3. Making meaning from data
4. Making connections from data
5. Linting information
6. Searching content
7. Understanding reported goals
8. Understanding real goals and aspirations
9. Understanding communication style
10. Understanding current state of person
11. Understanding, researching, and retrieving what content is currently relevant to the person, goals, interest
12. Understanding what current behaviour is impeding progress on goals
13. Writing an informative/engaging outline about this
14. Writing an engaging story about this
15. Creating great voices to deliver this
16. Delivering this brief on the device

---

## Progress scorecard

| # | Goal | Previous | New | Change | What the user notices after |
|---|------|----------|-----|--------|-----------------------------|
| 1 | Data sources | Partial | Partial | Some | Same write boxes. A journal can come back as a fact. No new apps to connect. |
| 2 | Ingestion system | Partial | Yes | Major | “Saved” means the brain has it. Retries do not clone the week. |
| 3 | Making meaning from data | Partial | Yes | Major | It only claims what they wrote. No invented quotes. |
| 4 | Making connections from data | No | Yes | Major | People stay one person. Quit stays quit. Week 4 continues week 1. |
| 5 | Linting information | No | Yes | Major | Fewer stale sentences. Rot caught before Sunday audio. |
| 6 | Searching content | Partial | Yes | Major | “What is still true” / “what changed since June,” not nearest chunk. |
| 7 | Understanding reported goals | Partial | Yes | Some | Stated goals can expire. January’s marathon is not this week’s job. |
| 8 | Understanding real goals and aspirations | No | Yes | Major | Pursuit named only after repetition. Stated vs actual both visible. |
| 9 | Understanding communication style | Partial | Partial | Some | Self-talk is stored and quotable. Not a style-coach engine. |
| 10 | Understanding current state of person | Partial | Yes | Major | One current portrait. Empty if unknown — not last month’s person. |
| 11 | Retrieving what is currently relevant | Partial | Yes | Major | Live truth + this week, not a 14-day dump plus invented history. |
| 12 | Understanding impeding behaviour | No | Yes | Major | The thing in the way is a standing thread. One bad day is not a diagnosis. |
| 13 | Writing an informative / engaging outline | Partial | Partial | Some | Same show shape, spine is live patterns + facts. |
| 14 | Writing an engaging story | Partial | Partial | Some | Honest about this person. May say less. Same writer. |
| 15 | Creating great voices | Partial | Out of scope | None | Same ElevenLabs voice. |
| 16 | Delivering this brief on the device | Partial | Out of scope | None | Same player. AVPlayer / Now Playing is a separate iOS ticket. |

**Still in brain scope:** 1–14. **Out of brain scope:** 15–16.

Phase 1 alone only unlocks durable ingest, spanned facts, and the write half of connections and search. Patterns, portrait, typed episode research, and the honest story come later.

---

## How to read “new”

The new system is a **fact bank** plus a **story consumer**. It is meant to achieve the memory and research half. It does not migrate TTS or fix the iOS player.

The product still looks like journal → weekly episode → same voice. What changes is Sunday, and whether writing something means it comes back.
