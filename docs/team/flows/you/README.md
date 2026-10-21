# You · the plan, every piece to PR level

Area slug `you` · contract [05-you.md](../../contracts/05-you.md) · fixtures [`fixtures/05/`](../../contracts/fixtures/05/) · cards: [backend.md](./backend.md) (13), [platform.md](./platform.md) (6), [views.md](./views.md) (26) · build board: [tree.json](./tree.json).

**45 PRs: 13 backend, 6 Platform, 26 views.** 6 pages (YO-1, its list view, YO-2, YO-3, YO-4, YO-5), 12 components, 45 leaves. The claim component is reused from the podcasts plan (integrator, 21 Oct), not built here. Phase 5 (after Beta 1, after podcasts and goals): nothing here is in [first-ship.md](../../first-ship.md)'s Beta 1.

**Verified against Paper (second pass, 21 Oct):** the five approved You phones (YO-1 to YO-5) were read with `get_jsx` and `get_computed_styles`, read only. The view cards now carry Paper's values, marked **(Paper)**, and the list of what changed is at the end of [views.md](./views.md). The masters on parts 05, 41 and 50 were not re-read; each card reads its master first. Paper wins where anything still disagrees.

## 1. The big picture

What You is for the person, in their words: **"what does Retro actually think about me, and is it right?"** The journal is where things go in; You is where they come back out as understanding you can see, question and fix. Four things on one tab:

- **A map of your life** (YO-1): you in the middle; the people, themes and goals around you, sized by how much they matter now; lines where two things really share moments. Something new blooms in when Retro learns it (M12).
- **Ask anything** (YO-2): "when did i stop running?" gets a short written answer on top, every sentence numbered to the sources below it, guesses marked "a guess:", and a plain "nothing in your bank speaks to this yet." when there's nothing. "Only what's certain" hides the guesses.
- **One thing Retro believes** (YO-4): tap a person, theme, goal or answer and see the belief, how sure Retro is ("fairly sure · from 5 things · moved last week"), every piece of your record behind it, and "still true" or "not right".
- **What Retro knows** (YO-5): every conclusion, area by area (who you are, what you want, what you do…), each with how sure and one tap from being fixed. Areas Retro hasn't earned the right to speak about say so warmly and show nothing.

**The product principles that bind this area hardest:**
1. **The claim ladder** (fact → pattern → why → hypothesis) is never blurred. Every node, sentence and answer carries its register from the brain; the app never decides it. A guess is dashed, prefixed "a guess:" or asked as a question: never only a colour.
2. **Guesses are asked, never asserted.** "Is this the same sam as sam okafor?" is a question with two equal answers. Hypothesis-only questions (Q10, Q32) appear only as guesses.
3. **When uncertain, withhold.** Search abstains in plain words. A person with no fact shows their name and a count, never an invented relationship. Silent areas show nothing.
4. **No invented data.** The map has only real nodes and real lines; empty states say how they fill ("this fills in as you talk to me."). The portrait's rule: "a block that cannot be traced to live IDs is empty. Empty beats January's marathon."
5. **One lit object per screen.** You has none: the search field is the action, raised (Paper). Blue appears only as the listening mic and the matched words in search results (screen rule 14).
6. **Privacy matters most here.** This area shows the most personal synthesis in the product. No name, label, excerpt, sentence or query ever reaches a log, analytics, a crash breadcrumb, a URL, a notification or a fixture with real content. Every card has a "no content in logs" test. Search queries travel only in POST bodies; deep links never carry a query.

## 2. Flows

### Entry points
| Way in | Lands on |
|---|---|
| the you tab | YO-1 (scroll position and any search result kept) |
| re-tap the you tab | YO-1 scrolled to top; an open YO-4 closes |
| notification "one question for you, when you have a minute." (EX-3) | YO-4 question state (`retrospect://you/question/<id>`) |
| a link to a node (internal, from podcasts' PC-3 or goals later) | YO-4 for that node |
| `retrospect://you/search` (shortcut, widget later) | YO-1 with the field focused |
| a source row in JR-4 / PC-3 that is a fact or answer | YO-4 (kind fact/answer) |

### The happy paths
1. **Look:** you tab → the map opens (you first, then orbits, then things) → something new blooms (M12) → tap priya → YO-4: "priya is your sister · fairly sure · from 5 things" → "still true" → dismiss.
2. **Ask:** tap the field → "when did i stop running" → return → "writing…" → what i found (2 sentences + "a guess: …") with chips → tap ² → source 2 highlights → open source 1 (your words) → JR-4 with "this supports" → back → clear × → the map.
3. **Check:** "what i know about you" → YO-5 → "moved this week · 2 answers changed" → a guess answer → YO-4 asked claim → "not right" → "wrong, or changed?" → applied → the row updates.
4. **Answer:** "one question waiting · about sam" → YO-4 question → "yes, same" → "linked." → the two sams are one on the map.
5. **Read:** "list" → the portrait in a few lines → a line → YO-4.

### Failures and edges
| Case | What happens |
|---|---|
| first time ever (day one) | the map: just you, "just you, so far." / "this fills in as you talk to me."; no waiting row; YO-5 mostly silent; search works over whatever exists, abstaining plainly |
| the hundredth time | cached map at once, fresh one replaces it; no open choreography after the first appearance per launch; only truly new nodes bloom |
| offline | cached map, node, portrait, YO-5 with the offline line; search says "search needs a connection" without a request; "still true" and "same person" wait in the outbox and send once |
| slow brain | skeletons after 400ms; "still working" after 8 s (search typically 5–10 s) |
| search finds nothing | "nothing in your bank speaks to this yet."; no card, no switch |
| search finds things but can't answer | one plain line, then "the closest:" and the sources |
| everything found is a guess and only-certain is on | "nothing certain here; turn this off to see the guess." |
| daily spend used up | search shows contract 00's spend line; every read still works (reads are never refused) |
| a node disappears (corrected elsewhere, merged) | YO-4 says "this isn't here any more."; the map drops it on refresh |
| a correction applied in YO-4 | the claim shows "noted"; map, node and YO-5 caches refresh |
| two names, one person | the question asks once; "not quite" keeps them apart for good |
| another person's id (bug, tampering) | `not_found` from every door; covered by two-user tests on every route |
| 24+ things | the map shows 24 by quota; the list view says "and 26 more" |
| SE | map scaled 0.82, both rows above the tabs; 20 margins on YO-5 |
| AX3 | labels grow, fewer map labels; answer paragraph and rows wrap, never truncate |

## 3. The full tree

Area › flow › page › component › PR (size · side · needs). Sub-components are the split PRs (C38.1–C38.5, UI6.1a–c, P19.1–2, P21.1–2).

```
you (contract 05) · 45 PRs
├── flow: you, at a glance
│   ├── page: YO-1 you (1G5Y-0)
│   │   ├── top bar, You variant ── C17-y (S · views · C17, C17-t, #45)
│   │   ├── search field ── C12-y (S · views · #53, #44)
│   │   ├── the you map (C38) ── C38.1 canvas + slot table (M · views · T01)
│   │   │                     ├─ C38.2 orb (M · views · C38.1)
│   │   │                     ├─ C38.3 threads (S · views · C38.1)
│   │   │                     ├─ C38.4 touch, states, VoiceOver list (M · views · C38.2, C38.3, C39, UI5.0)
│   │   │                     ├─ C38.5 life + opening (M · views · C38.4)
│   │   │                     └─ M12 bloom (M · views · C38.5, UI5.0)
│   │   ├── map data ── BE5.5a nodes (M · backend · BE5.1a, BE5.3a)
│   │   │             ├─ BE5.5b lines (M · backend · BE5.5a, BE5.0)
│   │   │             ├─ BE5.5c map + node doors (M · backend · BE5.5b, BE5.1a, BE5.0, BE1.6)
│   │   │             └─ PL3.6b map + portrait live (M · platform · PL3.6a, BE5.5c, BE5.2b)
│   │   └── P18 YO-1 page (M · views · C17-y, C12-y, C38.4, C38.5, C18, C39, UI5.0)
│   └── page: YO-1 list view (the portrait; not drawn yet)
│       ├── portrait data ── BE5.2a (M · backend · BE5.0, BE5.1a) · BE5.2b (S · backend · BE5.2a)
│       └── UI6.7 list view (M · views · a Paper drawing, UI5.0)
├── flow: search your life
│   ├── page: YO-2 search (1G8E-0)
│   │   ├── the answer card ── UI6.1a shell + states (M · views · C39, UI5.0)
│   │   │                    ├─ UI6.1b citation chips (M · views · UI6.1a, C32-n)
│   │   │                    └─ UI6.1c guesses + only-certain (S · views · UI6.1a, #50)
│   │   ├── numbered sources ── C32-n (S · views · C32)
│   │   ├── search data ── BE5.4a sentence sureness (M · backend · BEA.2, BEA.4, BE5.0)
│   │   │                ├─ BE5.4b search + source doors (M · backend · BE5.4a, BE0.0, BEA.4)
│   │   │                └─ PL3.6e search live (M · platform · PL3.6a, BE5.4b)
│   │   ├── P19.1 in place, answer, sources (M · views · P18, C12-y, UI6.1a, UI6.1c, C32-n)
│   │   └── P19.2 citations + opening sources (S · views · P19.1, UI6.1b, P20, P21.1, P12, UI6.6)
│   └── page: YO-3 a source (1GAS-0)
│       ├── UI6.6 "this supports" on JR-4 (S · views · P12, C32, founder Q4)
│       └── P20 records and saved links (S · views · C17, UI5.0)
├── flow: one thing Retro believes
│   └── page: YO-4 a node (1GC2-0)
│       ├── links ── UI6.4 link chips (S)   (the claim is the podcasts plan's component, reused)
│       ├── node data + still true ── BE5.0 claim reader (M · backend · BEA.2)
│       │                          ├─ BE5.1a people (M · backend · BEA.2, BE5.0)
│       │                          ├─ BE5.3b still true (M · backend · BEA.1, BEA.2, BE5.0)
│       │                          └─ PL3.6c node, verdicts, questions live (M · platform · PL3.6a, PL2.2, PL3.1e, BE5.5c, BE5.3c, BE5.1b)
│       ├── same person? ── BE5.1b doors (S · backend · BE5.1a)
│       ├── P21.1 node sheet (M · views · C19.1, podcasts' claim component, UI6.4, C32, #45, UI5.0, P18)
│       └── P21.2 question state (S · views · P21.1, C28)
├── flow: what Retro knows about you
│   └── page: YO-5 what i know (1SZX-0)
│       ├── answer row ── UI6.3 sureness dots (S) · UI6.5 (S · views · UI6.3)
│       ├── understanding data ── BE5.3a (M · backend · BEA.2) · BE5.3c doors (M · backend · BE5.3a, BE5.3b, BE1.6) · PL3.6d (S · platform · BE5.3c)
│       └── P22 YO-5 page (M · views · C17, UI6.5, C39, UI5.0)
└── flow: the whole of You
    ├── UI5.0 SampleYouData + ledger (M · views · Platform/Flows/You.swift)
    ├── PL3.6a wire + cached reads (S · platform · PL2.4, PL1.1, contract 05)
    ├── PL3.6f routes into You (S · platform · PL5.2)
    └── T05c the You flow test (M · views · every page, PL3.6f)
```

## 4. The queue, in build order

Each needs only merged work. Backend and app run at the same time (README §2); the contract and fixtures are the line between them, and every view card builds on `SampleYouData` first.

**Before anyone starts (integrator):** merge this contract and its fixtures; write `Platform/Flows/You.swift` (proposal in platform.md); assign real migration numbers for `16a`, `16b`, `16c`; confirm `pattern` as a contract 02 §6 `about` kind; get founder answers on questions 1, 2, 4, 5 (or proceed on the leans).

| # | Backend (agent, then backend repo) | Size | # | App (Platform and views, one engineer) | Size |
|---|---|---|---|---|---|
| b1 | BE5.0 claim reader | M | a1 | PL3.6a wire + cached reads | S |
| b2 | BE5.1a people ranked, one person | M | a2 | UI5.0 sample data | M |
| b3 | BE5.1b same-person doors | S | a3 | UI6.3 sureness | S |
| b4 | BE5.3a understanding in your words | M | a4 | UI6.5 answer row | S |
| b5 | BE5.3b still true | M | a5 | (UI6.2 withdrawn: claim from podcasts) | — |
| b6 | BE5.3c understanding + verdict doors | M | a6 | UI6.4 link chips | S |
| b7 | BE5.2a portrait | M | a7 | C32-n numbered row | S |
| b8 | BE5.2b portrait door | S | a8 | C17-y top bar | S |
| b9 | BE5.5a map nodes | M | a9 | C12-y search field | S |
| b10 | BE5.5b map lines | M | a10 | C38.1 canvas + slot table (founder sign-off) | M |
| b11 | BE5.5c map + node doors | M | a11 | C38.2 orb | M |
| b12 | BE5.4a search sureness | M | a12 | C38.3 threads | S |
| b13 | BE5.4b search doors | M | a13 | C38.4 interaction + states | M |
| | | | a14 | C38.5 life + opening | M |
| | | | a15 | P18 YO-1 | M |
| | | | a16 | UI6.1a answer card | M |
| | | | a17 | UI6.1c guesses + only certain | S |
| | | | a18 | P19.1 YO-2 | M |
| | | | a19 | P21.1 YO-4 | M |
| | | | a20 | P21.2 question state | S |
| | | | a21 | P22 YO-5 | M |
| | | | a22 | UI6.6 this supports (lean A) | S |
| | | | a23 | P20 YO-3 | S |
| | | | a24 | UI6.1b citation chips | M |
| | | | a25 | P19.2 citations + opening | S |
| | | | a26 | PL3.6f routes | S |
| | | | a27 | PL3.6d understanding live (after b6) | S |
| | | | a28 | PL3.6c node live (after b3, b6, b11) | M |
| | | | a29 | PL3.6b map + portrait live (after b8, b11) | M |
| | | | a30 | M12 bloom (recorded on live data after a29) | M |
| | | | a31 | PL3.6e search live (after b13) | M |
| | | | a32 | T05c flow test (with the integrator) | M |
| | | | a33 | UI6.7 portrait list (once drawn) | M |

Cross-side joins: PL3.6d waits for BE5.3c; PL3.6c for BE5.1b, BE5.3c, BE5.5c and the journal's PL3.1e; PL3.6b for BE5.2b and BE5.5c; PL3.6e for BE5.4b. The wiring PR (integrator) swaps `SampleYouData` for `LiveYouData` once PL3.6b–e are in, then T05c runs on local staging.

From other areas: C17, C18, C19.1, C28, C32, C39 (journal, phase 0/1); C17-t (podcasts); P12 and PL3.1e (journal, after Beta 1's "later" list: "what Retro took" and "not right" must have shipped before YO-4's "not right" works, first-ship.md); PL5.2 (router); BEA.1, BEA.2, BEA.4, BE1.6, BE1.7 (phase A and the journal).

## 5. Signature moment

**M12, a new thing blooms into the map** (after P18, recorded and compared with the motion system). The map's life (C38.5) is the screen's one ambient motion; the bloom is the one event.

## 6. Tests

- Each card lists its tests by layer (testing.md): agent unit + two-user + service-role (backend), door suite + fixtures (doors), fixture decoding + Platform unit (Platform), snapshots + UI + accessibility (views), Instruments for C38.5 and M12.
- The flow test is **T05c** (views.md), on sample data, then once on local staging with the seeded test account, searches capped at 3 and logged as test spend.
- Area-wide: "no content in logs" on every door, every Platform module and the outbox; "another person's id is not found" on every door and agent route.

## 7. Risks

| Risk | Answer |
|---|---|
| The map looks generated, not hand-made | the founder's slot table (C38.1), signed off in the PR; never a layout algorithm (build notes) |
| The map shows wrong people (300 contacts, few close) | BE5.1a ranks before limiting and gives contact/calendar people a significance at half weight |
| A guess reads as a fact in search | BE5.4a's deterministic rule (no model), UI6.1c's "a guess:" in a different type, never colour alone; "only what's certain" |
| Search costs money and seconds | `expensive` bucket, spend cap (BEA.4), submit-only (no search-as-you-type), idempotent retries that never pay twice, "still working" at 8 s |
| Personal synthesis leaks into logs | counts-only logging, scanned-sink tests on every layer, queries never in URLs or links, outbox payloads ids-only |
| "Same" merges the wrong people | equal-weight buttons, full names, asked once, door never answers on the person's behalf |
| Third-person brain wording reaches the screen | BE5.3a's second-person questions (founder approves the 36), the app's own area titles and portrait section titles |
| YO-4 "not right" before corrections ship | it reuses contract 02 §6 and PL3.1e; if those slip, P21.1 ships "still true" only, behind the same gate as the journal |
| The portrait has no screen | UI6.7 waits for a drawing; nothing else depends on it |
| Paper values unverified in this plan | every view card reads its nodes first; Paper wins |

## 8. Founder questions (work goes ahead on the lean)

**1. What is a "theme" on the map?**
- A. **Live patterns** (things that keep happening: "late meetings push the run"). Already counted and gated by the brain.
- B. Content topics (what you watch and read, grouped: "woodworking").
- C. Both, as two kinds.
- **Lean A.** It's the brain's most honest "what keeps coming up", already registered (stated vs provisional). Under B or C, BE5.5a reads `content-groups` too and the map gains a kind colour.

**2. How live data meets your hand-crafted map.**
- A. **Your slot table:** the positions drawn in Paper become fixed slots; real nodes fill them by importance. You sign off the slot table in C38.1's PR.
- B. A layout algorithm tuned to look like your drawing.
- **Lean A** (your build note: "don't generate it from a layout algorithm without my sign-off"). Under B, C38.1 grows by a day and needs your review of recordings.

**2b. How many slots the map has.** Paper's approved map draws 9 orbs in two tiers (4 near at 44, 5 far at 20). A. **You draw up to 24 slots in the same two-tier language** (lean; the quotas below stay). B. The map shows at most 9 (4 near, 5 far). Under B, `MAP_QUOTAS` drops to 9 and the list view carries the rest.

**2c. Lines between things.** Paper draws only lines from you to each thing. A. **Add node-to-node lines as fainter 0.75 hairlines** (lean; BE5.5b computes them). B. You-to-node lines only. Under B, BE5.5b keeps only `linked` for YO-4's chips (the map ignores node-to-node edges); nothing else changes.

**3. How many of each on the map?** A. **10 people, 8 themes, 6 goals** (24, the spec's limit). B. People only at first. C. Your numbers. **Lean A.** Places wait until the brain ranks them.

**4. YO-3 and JR-4.**
- A. **Merge for your own words:** opening something you wrote from search goes to JR-4, which gains "this supports"; YO-3 remains only for records (calendar, mail) and saved links.
- B. Keep YO-3 as its own page for everything.
- **Lean A** (one page per thing you wrote). Under B, UI6.6 is dropped and P20 grows to M with "this supports" and "show it in the conversation".

**5. Where does the portrait live?**
- A. **The "list" pill on YO-1 opens it**: the map as a few honest lines by section. Needs a drawing.
- B. Fold it into YO-5 as a top section.
- C. Don't show it; it only feeds episodes.
- **Lean A.** Under B, UI6.7 becomes a YO-5 section (S); under C, BE5.2a/b and UI6.7 drop (−3 PRs).

**6. What counts as a guess in search, and is "only what's certain" remembered?**
- Rule (lean): a sentence is certain if any source it cites is your own words, a record of what happened, an observed or confirmed fact, a stated answer or something you saved; otherwise it's a guess.
- Remembered: A. **yes, on this phone**; B. off for every new search. **Lean A.**

**7. Sureness dots.** The three words ("just a hunch / fairly sure / very sure") plus four dots by confidence quarter (< 0.25, < 0.5, < 0.8, else). A. **as drawn: word + 4 dots** (lean). B. Three dots, one per word. Under B, UI6.3's dots and BE5.3c's constant change; nothing else.

**8. The 36 questions, said to you.** YO-5 shows Retro's questions about you ("what have you said you want?"). The backend engineer drafts all 36 in BE5.3a's PR; you approve the wording there. **Lean: approve in the PR.**

**9. A person Retro has no fact about yet.** A. **Name and "comes up 5 times"**, nothing more (lean). B. Hide such people from the map. Under B, BE5.5a filters people without a headline (the map gets sparser early).

**10. The mic in the search field.** A. **Dictation into the field**, you press return (lean). B. Listening like the composer, sending when you stop. Under B, C12-y needs the composer's silence handling (+½ day).

**11. "One question waiting":** A. **a same-person question first, then a guess** (lean). B. Guesses first.

**12. "Moved this week · 2 answers changed":** A. A quiet line; the moved answers are marked "moved". B. **Tapping it filters to the moved answers.** **Lean B, changed after reading Paper:** YO-5 draws the row with a chevron. P22 gains the filtered state (+½ day, inside P22).

**14. Grouped sources in search.** Paper's YO-2 shows one row per kind of source ("journal · 3 entries", "apple health · 14 nights"). A. **One row per item for v1** ("20 oct · journal"), grouping later (lean). B. Group in the door now (+1 backend byte; the citation numbers then point at groups). Under B, contract 05 §6 gains `items` per source.

**15. What YO-4's big line says.** Paper draws a two-sentence synthesis about a person ("a close colleague. you come back lighter after time with her."). A. **The best-supported single fact for v1, with no model call** (lean; the claim ladder keeps it honest). B. A guarded, cited synthesis per person (a new brain byte with a model call, the claim guard and spend). Under B, BE5.1a grows to L and the claim gains `cites`.

**16. YO-5's areas.** Paper draws life areas ("work", "health", "family") with questions that aren't the canonical 36. A. **The brain's 8 areas with titles in Paper's tone**, which you name ("who you are", "what you want", …) (lean; it's the data that exists). B. Life areas, which needs a brain grouping of answers into areas (new brain byte, M). Under B, contract 05 §7's `areas` change ids.

**13. Copy to approve** (all lowercase, Retro's voice): the eight area titles and silent-area sentences (YO-5), the portrait's section titles, "nothing certain here; turn this off to see the guess.", "this isn't here any more.", "search needs a connection", "linked." / "kept apart.", and the abstain lines.

## 9. Changes needed in shared files (for the integrator)

- `docs/team/contracts/README.md`: row 05 → `05-you.md`, "draft for review".
- `docs/team/contracts/02-journal.md` §6: accept `about.kind = "pattern"` (YO-4 "not right" on a theme); BE1.7's door already routes through the agent's targeting.
- `docs/team/backend/phase-0.md`: real numbers for agent migrations `16a_question_you_text.sql`, `16b_confirm_fact.sql`, `16c_search_person_content_date.sql`.
- `docs/team/backend/later-phases.md` phase 5: replace BE5.1–BE5.4 outlines with a pointer to this folder (13 cards; BE5.0 and BE5.5a–c are new).
- `docs/team/plumbing/outline.md` PL3.6 → split PL3.6a–f here; `PL2.5.md`: its people/portrait/understanding half moves into PL3.6a.
- `docs/team/ui/later.md` phase 5: C38 → C38.1–C38.5; UI6.1 → UI6.1a–c; P19 → P19.1–2; P21 → P21.1–2; new UI5.0, C17-y, C12-y, UI6.3–UI6.7; C32-n kept; the claim card is the podcasts plan's.
- `Platform/Flows/You.swift` (integrator-owned): the protocol proposal in platform.md.
- `docs/design/sample-data-ledger.md`: You rows arrive with UI5.0.
- Paper: a drawing of the portrait list view (UI6.7), and a YO-3 record and saved-link variant (only a journal entry is drawn).
