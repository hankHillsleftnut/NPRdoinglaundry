# How Retrospect was built: a play-by-play

A dated record of everything that went into building Retrospect: what was built, why, what broke, and what we did about it. Newest work is at the bottom. It's appended to as work happens.

**Sources** (so every line can be checked):
- **Git history:** `retrospect-main` (66 commits, 5 Feb → 29 Sep 2026, plus Oct branches) and `retrospect-agent` (180 commits, 24 May → 20 Oct 2026).
- [findings-log.md](./second-brain/findings-log.md): everything noticed, measured and fixed, mistakes included.
- [decision-record.md](./second-brain/decision-record.md): every decision that changed behaviour.
- [hifi-execution-plan.md](./design/hifi-execution-plan.md): the design tracker and its change log.
- [ios-build-notes.md](./design/ios-build-notes.md): the founder's Paper comments, word for word, as build requirements.

**The detailed version of 17–20 Oct**, beat by beat with every decision, is in [session-play-by-play-oct-17-20.md](./session-play-by-play-oct-17-20.md).

**The cast.** The founder (design, brand, product calls; doesn't write the code), and Claude Code sessions as the engineering and design partner. From 20 Oct, two sessions ran side by side on one Paper file: the "main" session (icons, pills, labels, rows, drawer, entry, settings) and the "fork" (top bar, tab bar, composer, conversation, brief/player, map).

---

## Era 1 · The first app and the first pipeline (5–17 Feb 2026)

| Date | What happened |
|---|---|
| 5 Feb | **Initial commit.** Retrospect starts as an iOS journaling app (SwiftUI). |
| 7 Feb | **A backend pipeline in one day.** Observations → insights pipeline on Supabase; types moved to dependencies so production builds pass. |
| 7 Feb | **An admin dashboard** to watch the pipeline. First bug: CSP blocked inline handlers. |
| 7 Feb | **First real pipeline bugs.** Insights synthesised before observation embeddings existed (race fixed with an await). Content stuck as "already processed" got a force-reprocess. Supabase returned vectors as strings, now parsed into number arrays. A diagnostics endpoint was added to trace failures. |
| 7 Feb | **Dashboard design pass:** ivory scheme, Geist Mono, sharp edges, then full dark mode with "bone ivory" text, then SF Pro primary with Geist Mono secondary. The type pairing that later became the design system starts here. |
| 7 Feb | **The podcast is born:** 3-pass podcast generation, iOS ↔ backend integration, expressive voice personas. |
| 7 Feb | Apple Sign-In becomes required, with an auth gate and log out. |
| 7 Feb | **Perspective fix:** the host was talking *about* the listener; now speaks *to* them, in the second person. |
| 7 Feb | **The ElevenLabs saga, part 1:** upgraded multilingual_v2 → eleven_v3. v3 rejected `previous_request_ids` and `next_text`; error handling and timeouts were added, then the whole TTS layer was rebuilt around v3's constraints. |
| 7 Feb | Prompts rewritten around a **CBT-focused self-esteem framework**. |
| 17 Feb | **Onboarding v1:** iMessage-style input bar, Claude-written goals, Screen Time, UI polish. |

## Era 2 · Architecture, a false start, and the agent service (Apr–Jun 2026)

| Date | What happened |
|---|---|
| 12 Apr | Architecture docs and diagrams written. |
| 12 May | **The v2 agentic pipeline** ("Two Systems, One Agent"): ingestion + podcast. iOS routes every AI call through the backend; provider keys stripped from the app. |
| 12 May | **Same day, all three reverted.** The v2 push was rolled back in full (pipeline, iOS routing, admin errors). |
| 14 May | HealthKit and Google Docs ingestion wired. |
| 24 May | **`retrospect-agent` is born:** a separate TypeScript agent service on Render. Four commits in a day just to get Render's TypeScript build, start path and module resolution working. |
| 25 May | **Onboarding becomes the agent's foundation.** The podcast pipeline routes through the agent service. |
| 28 May | A full backup of the app is taken (`RETROSPECT_BACKUP_2026-05-28`). |
| 29 May | **The "cooks":** all three podcast stages (Cook A/B/C) upgraded with the CBT intelligence from the old pipeline. Async ingest, iOS timeouts and the onboarding content type fixed. Phase 3 cleanup removed dead services. |
| 30 May | **Ingestion becomes retryable:** failed entries retry, and a backfill endpoint reprocesses them. The runs dashboard shows the actual source text. Journal and voice-journal content types are accepted. |
| 30–31 May | **The podcast player transcript** redesigned as a "glass window" blur. It tinted bluish on the dark UI, so the UIKit blur edges were replaced with a SwiftUI gradient. |
| 31 May | **Cook 0:** a "user understanding" document plus identity inferences. Ingestion is batched to fit OpenAI's tokens-per-minute limit. Cook B and C move to Claude Sonnet, Cook A to gpt-4o-mini. Per-user cost tracking appears on the runs dashboard. |
| 31 May | **The ElevenLabs saga, part 2:** switched to multilingual_v2, reverted to v3, fixed v3's API requirements, fixed invalid voice IDs. |
| 1 Jun | **Onboarding rebuilt:** a closing screen ("Now let's help you get there." + Play Podcast), then haptics, fixed-layout streaming, a redesigned progress bar, pacing, a centred round input. Backend moves to claude-sonnet-4-6. A "magic moments" interpretation engine is built. |
| 3 Jun | **The Exposure typeface** arrives for onboarding display type. (Found 19 Oct: its axis is documented backwards, and it's a trial licence that needs buying.) |
| 4–5 Jun | Onboarding goals come from the full pipeline (ingest + Cook 0), not one LLM call, and appear as full-page swipe cards. |
| 6–9 Jun | The **podcast paywall**, capture shortcuts and a live mini-player. |
| 13 Jun | Podcast prompts gain a "trust arc", a possibility section and a consumption rule. The **knowledge graph MVP** (`graph_edges`). |

## Era 3 · Sources, quality and the second brain (Aug–Sep 2026)

| Date | What happened |
|---|---|
| 8 Aug | **Quality tooling:** doctor checks, a secret scan, smoke scripts, a quality workflow. |
| 8 Aug | **Integrations end to end:** a connector fleet, a durable job queue and graph v2 in the agent. Integrations connected across iOS and the backend. A **macOS journal app** is added. The first podcast finale and the "fluid dots" learning ritual. |
| 12–13 Sep | The Integrations page restyled to the design system, reviewed, and LinkedIn added back to the catalog. |
| 20 Sep | **The second brain, built in one day (agent):** `writeFact` with evidence spans; journal ingest writes spanned assertions; idempotent ingest and leases; contradictions supersede old facts; current truth, alias hygiene, significance; `behavior_patterns` and promoter v1; "why" inferred only for live patterns; portrait rebuilt from the live graph; lint and remediation with an audit log; Cook B researches through typed pulls; Cook C is constrained to the evidence pack. CI fixed four times (no tests found on Linux, missing env vars, Node 22). |
| 21 Sep | **The ingest repairs:** the batcher under-measured what it sent, so batches are now measured in tokens and split when refused. A failure becomes a schedule, not a verdict. A reclaimed row enters the retry queue. Reclaim can't tear a live lease away. Requeue collapses duplicates. **Why:** in May, 2,034 of 2,267 rows had died to a billing lapse, and nothing retried them. |
| 29 Sep | **The pipeline canvas:** a read-only health dashboard showing every step, with blind spots marked "not recorded" instead of faking green. The second-brain docs (architecture, decisions, implementation plan). ElevenLabs proxied through the backend. |

## Era 4 · The brain, rebuilt against the goal spec (18–20 Oct 2026)

Every change shipped as its own PR, was reviewed, and was measured on the founder's account with counts only, never content.

| Date | What happened |
|---|---|
| 18 Oct | **Legible and honest:** record whose words each entry is; stop the pipeline losing work and saying false things; `db:check` (which found a live bug) and `db:migrate`; facts and their evidence save together or not at all. |
| 18 Oct | **The 36 questions:** the questions the product answers about a person, stored as data. Answers must show evidence and earn their confidence; a first best guess at all 36; an ambient researcher that keeps strengthening them. |
| 18 Oct | **Reading:** every kind of writing is read, and the model is never shown an absence. A Drive document isn't automatically your words. The extractor is scored against a test bank, with itemised costs. Long writing is read in full, in sections. Reading and answering move to Sonnet 5.5. runIngest is refactored into parts. A Google Calendar connector is added. |
| 19 Oct | **Onboarding to first episode with no human in the loop.** Per-person daily cost ceilings and a cost report. Google access revoked on account deletion. The daily brief engine (text first, off by default). A crash on a new person's first episode fixed. Validation sets written **before** the code. |
| 19 Oct | **Trust and lineage:** trust classes per data source; every claim joins to its evidence (`claim_edges`), and `walkEvidence` walks any claim down to its sources. Claims are retired, never deleted. Replaying the same material twice leaves the brain as if it ran once. |
| 19 Oct | **Brain evaluation:** a fictional persona with 41 questions, scored by ability. Baseline **28.7 / 40** (facts 87%, connecting 67%, change 67%, time 38%). |
| 19 Oct | **Events and summaries:** a "material arrived" outbox; reading once material settles; a latency report. Daily summaries by local day and domain, including health and screen time. |
| 19 Oct | **Patterns:** declared daily detectors; trajectory via an exact two-window rate test; shifts from the person's own baseline; where the time went. **Found:** "patterns getting stronger" were artifacts (one uploaded conversation counted 10–20 times). Fixed; all 72 patterns now honestly say "not enough to say yet". Two thresholds were the agent's own picks, not research; recalibrated (sedentary < 5,000 steps, short sleep < 7h). |
| 19 Oct | **Goals:** 31 "active" goals turned out to be 7 (24 copies). They're merged and expired daily; 3 stay active. The iOS app was found reviving the goals the brain merged; the server side was fixed. |
| 19 Oct | **People** (Fellegi–Sunter scoring, strict bands); a **planner** (DPP-style, never padding); a **writer** where every sentence passes a claim guard; the weekly episode from the new brain, behind a switch. **Review of #57–#84 found 12 bugs**, all from that night, including reads that silently stopped at 1,000 rows. All fixed with regression tests. |
| 19–20 Oct | **Daily brief, ambient, reference, search:** the daily plan and its own writer; per-person and master ambient switches; saved links with your reason, read in full and tied to goals; **hybrid search** with sources first. Search gate: 33/40, with time questions the weakest. |
| 19–20 Oct | **Corrections, lint, voice:** a rejected claim is retracted with everything resting only on it, and never resurrected. Lint runs daily and keeps flagged claims out of outputs. Stock comfort and performed empathy are cut. A "how bold" ladder the person sets. Hypotheses: proposed, validated, offered one at a time. A prepare-only action ledger. Talking to it bit by bit. YouTube history from Takeout. |

## Era 5 · The iOS refresh: audit → spec → design system (19–20 Oct 2026)

| Step | What happened |
|---|---|
| Audit | A control-by-control pass on a running build (SE and 17 Pro), with sample data and error and slow modes. **Found:** no episode playable after onboarding; deleting an entry kept it in the brain; every sign-up paid for **two** first episodes; a fake 7-minute clock with no sound; a hard-coded "next episode in 3 days"; a paywall with no exit in release builds; canned "learning about you" claims shown to everyone. |
| Opportunities | Most of what the brain can do (search, conversation, brief, corrections, people, settings) can't reach the app; the backend has no routes for it. |
| Spec | One goal-spec doc with every problem, opportunity and rule. A contradiction pass fixed 12 places where the docs disagreed with themselves. |
| Mid-fi | **All 47 pages** drawn in Paper as mid-fi (onboarding ON-1–13, account, Journal JR-1–4, Podcasts, Goals, You, Settings, outside the app), each from a generator with **0 raw values**. |
| Tokens | tokens.json grew from 272 to 507 tokens (light and dark, type, space, radius, depth, glow, map). **Contrast measured by script:** most light-mode greys failed WCAG and were fixed. Five component colour pairs failed and were fixed; `lint.mjs` now checks every pair. |
| Process | `design-system/process.md`: plan top-down (flow → page → component → sub-component), build bottom-up, with a 15-check pass per part, `token-check.mjs` before and after Paper, and founder gates. |

## Era 6 · Hi-fi, part by part (20 Oct 2026)

**How each part was made:**
1. Drawn at true 1× from tokens, generated by a Python script, never hand-typed.
2. `token-check` must report 0 raw values.
3. Pasted into Paper on "02b · in review".
4. Inspected in 2–3× screenshots.
5. A plain-English board note: what it is, how it works, what changed, what I need from you.
6. The founder comments in Paper. Each comment is fixed, resolved, logged in the findings log, and copied into ios-build-notes.md in the founder's own words.
7. Approved parts become masters on "02 · components". Unchosen versions are archived, never deleted.

| Part | The play-by-play |
|---|---|
| **M0 · wiring** | The 02b page; the naming rule `c:<component>/<variant>/<state>`; a sync check that flags a copy drifting from its master. |
| **00 · icons** | Every joint gets an ink pool (exact fillets against the real stroke edges), shipped as one path of fitted Bézier curves. Bugs caught at 16–24×: jagged tangent guesses; a heart cusp overshoot; mic-off's slash filling the capsule; the "15" losing its foot to an even-odd cut. Founder rounds: skip numerals centred by ink weight; the guess icon becomes a dashed ring; "correct" becomes a speech bubble with a dash (the pencil read as "edit"); retry joins skip-forward's family; offline's arcs stop short of the slash with round ends. |
| **Labels** | **"Geist for labels, mono only for figures."** A new `--font-label` token, applied file-wide. |
| **03 · brief card** | Six versions (standard, opening, row, artwork, playing, receipts). Founder kept A, D, E, then chose **D**, the token-mesh artwork with the play on the seam. A merged "rest → playing" card was tried and archived ("I still prefer this"). |
| **04 · tab bar** | **A**, with a progressive blur. First attempt: six stacked blur bands, called "bs with how many layers". Fixed with a real progressive blur, drawn in Paper as two copies of the content (sharp and masked out, blurred and masked in), because Paper can't render a masked backdrop blur. Selected icons grow their outline by 0.225 a side. |
| **05 · you map** | Redrawn as a constellation from the `map.star.*` tokens, then six straight-line "space mirror" variations; **orbits** picked. Orbs made frosted (12% white glass plus a 1.5 backdrop blur), after 3px blurred the lines away entirely and 50% white turned the orbs solid. Labels moved onto canvas plates so no thread crosses them. Marked hand-crafted for the founder. |
| **06 · top bar** | One behaviour: the inky title at rest, collapsing to a small centred name on scroll or typing. Apple's status bar is pasted unmodified and exempted from token-check. |
| **07 · voice composer** | Four states. The focused state lifts the field (sunken → raised) instead of a "crude" blue ring. The recessed empty state was liked as a treatment but "not the main input card", so the home composer is raised in every state and the recess becomes a recipe for other inputs. **The send button is blue** ("this button needs color"), overriding composer rule 3, as the founder's call. Squircle corners noted for SwiftUI. |
| **08 · conversation** | Retro unboxed in **SF Pro** (version A, "sexy as hell"); your messages in a wash bubble with a tail. The mark beside Retro's lines was removed ("not needed"). The audio-message style was praised and kept. |
| **09 · player sheet** | Round 1: the sheet finished in tokens, with "not right" renamed **"correct this part"**. Round 2, four states: ready → playing (the title scrolls up into the header) → holding the scrubber (a chapter bubble) → the "…" menu (chapters + download). The transcript got a real progressive blur. "correct this part" moved above the progress line. The scrub bubble was cut to one line naming the chapter, because it repeated the row below it. The transport recess was made darker than its parent. |
| **10 · brief items + recap** | The "now" card, the "next" rows and the recap card, then shown **in context** after "what is the context of use": the brief playing in the sheet, and the recap in the Journal thread. |
| **20–27 (main session)** | Pill (three heights), labels, 56pt rows and hairline, drawer and search field, the entry page and delete dialog, switch and segmented, settings rows. Founder rules from these: sunken means **darker than its parent** (a wash, never a lighter solid); search keywords are blue; SF Pro 17 always gets `tracking.card`; every part ships with an "in the app" 390×844 phone. |
| **Gate A** | **Approved 20 Oct:** brief card D, tab bar A, top bar, you map (orbits), voice composer, conversation A, player sheet, brief items + recap. Eight master boards placed on 02 · components (master on top, states below), with a masters table in audit.md. Placing them caught two leftovers: the tab bar and top bar still showed the old raised bubble and inky Retro lines. |
| **Late round** | "Straight lines" on the hand-crafted map: nine curved threads made straight. My first attempt deleted the lines (Paper can't swap one SVG path on its own), so I rebuilt the whole SVG from its exact markup. |

| **M3 begins** | Accessibility-3 type tokens taken from Apple's own HIG table before drawing (process.md: no value that isn't a token). The message and the voice composer drawn in all their states, each inside its own approved section (parts 08 and 07): message 11 drawn and 4 excused, composer 8 more on top of the 4 approved; dark in M12. I first put these in new sections, which read as duplicates, and the founder called it out; they were folded back in, and the rule is now one home per component. The spec corrected where it had drifted from the founder's approvals. |

## Paper quirks learned the hard way

- CSS variables don't resolve in SVG gradient stops (halos rendered black), so they're HTML radial gradients instead.
- `write_html` replace mode drops `position:absolute` on the root, so it's re-applied after every replace.
- Paper can't replace one child of an SVG. Replace the whole `<svg>`.
- The 4-value border-radius shorthand renders square, so each corner is set separately.
- Text doesn't wrap without an explicit width; short text needs `fit-content`.
- No margin, no `transform: scale`, no rich text, no line clamp, no masked backdrop blur.
- `create_artboard` lands on whatever page the founder is viewing, so a `pageId` is always passed.
- Paper's tools can resolve comment threads but can't reply to them, so answers live in the findings log and in chat.

## Mistakes, owned

Every one is in the findings log. The ones that shaped the process:
- **Overwrote the other session's icon edits.** That's why ownership is now split by part, and icons/* belong to the main session only.
- **Pushed a commit with 2 failing tests.** Tests are now checked by exit code before every commit.
- **Quoted "~70%" overall progress when it covered phases A–E only.** The board now gives both numbers.
- **Deleted an unchosen variation.** It was rebuilt and archived. Variations are never deleted.
- **Claimed a contrast ratio before measuring it.** The linter now blocks claims like that.
- **Swapped SVG paths one by one and erased the map's lines.** It's now a rule to replace the parent SVG.

## What's next

- **M3 · Journal components:** message, composer, brief card, player in brief mode, sheet, dialog (plus the main session's drawer and entry), assembled only from approved parts, in all 14 states, then **Gate B**.
- **Gap found before M3:** there are no Dynamic Type accessibility-3 size tokens. Process.md says to add them first, with an Apple source. Body at AX3 is 40pt; the other text styles at AX3 are still to confirm.
- Then M4 (Journal pages and Gate C1), M5–M10 (the other areas), M11 (journey map), M12 (dark mode), M13 (proving the sync), M14 (hand-off to SwiftUI).

### 20 Oct · PC-3, paywall decision, AC-1
- PC-3 board on 04b: part 41 inside the player sheet at three sizes (sheet `minHeight: 0` so "not right" stays in the thumb zone), plus the asked state. SE keeps the claim size; evidence rows stay one line.
- Decision 06 on 02b (generator `p46_paywall.py`): the spec makes the plans the buttons, the mid-fi uses choose-then-subscribe; both drawn as full phones. Prices are the founder's (#20), so the saving is 17% (the spec's 33% is stale). Review fixes: removed the tick that collided with the price, gave the bubbles a hairline, and cut the sublines to one line.
- AC-1 on 04b (generator `p47_signin_returning.py`, but the board is built by duplicating the splash phone so the brand buttons stay single-source): three sizes, restoring, failed. Found that no mark glyph exists in Paper yet.
- M7 Goals: part 48 goal card on 02b (`p48_goal.py`); GL-1 in the podcasts frame with a re-masked progressive blur at each size; GL-2 in the entry frame. New "goals" group header on 04b at y 11400. `create_artboard` ignores left/top, so every new board needs an `update_styles` move afterwards.
- M8 You: part 50 (`p50_search.py`) on 02b; YO-1 (from GL-1's tab frame, You map master cloned) and YO-2 in a new "you" group on 04b at y 14600. Paper ignores transform and flattens inline spans; both are worked around and logged.
- 20 Oct · M6 end board (ON-10/11/13, AC-2) on the approvals page at (0, 3400): duplicated GDM, H3P, FR2, LRV into tiles; added c:getting-ready, c:entry/setup-recap, c:hint/1-of-3, c:sheet/sign-out; rings as SVG after div borders didn't render; JSX saved to design-system/hifi/p61_onboarding_end.jsx; token-check 0; handoff + tracker updated.
- 21 Oct · M11 board (OE0) at (0,5000) on approvals: generator hifi/p62_journey.py (7 rows, slots), 35 phones duplicated into slots. M12: duplicated to QHB at (0,16000); hifi/dark_updates.py → 90 style groups + 14 path groups; 6 dark tokens created; header relabelled. M13: sync/snapshot-from-export.py + sync/push-tab-bar.py; 22 diffs → push 120 items → 0. M14: tokens/to-swift.mjs → tokens/build/Tokens.swift (typecheck ok).
- 21 Oct · Founder answers: SF Symbols / existing mark / paywall A. Mark master SUL on 02 (path simplified by RDP 0.1 → 16 KB), glyph duplicated into 27 slots found by scanning exports for empty cream 16/22 discs. ON-6 board V6L (phone V72) rebuilt with two groups after comment c-1i7mli (resolved). Duplicate ON-12 archived to 02b (decision 06 IFL already restored by another session). Journey map OE0: ghost nodes replaced with ON-6 and decision 06's A. Dark work handed to session 7444c5.

## 21 Oct · one page with everything, latest
- Founder asked for a single page showing the latest version of every screen before any SwiftUI work.
- New Paper page "06 · everything · latest", one board, seven rows: onboarding, journal, podcasts, goals, you, settings and account, outside the app. 37 screens, each copied from where its newest version lives, with a status chip (approved / waiting on you) and its source.
- Built by design-system/hifi/p64_everything.py. It's a snapshot: re-run after comment fixes land so it doesn't drift.
- SwiftUI paused until the founder has looked. Foundation files (RType, RDepth, RFoundationGallery) exist uncommitted and build.
- Consistency fixes applied: you-screen row renamed to "what i know about you"; YO-5 moved to the small centred title. Page re-taken. The dark session was told.
- Founder approved ON-1/2, ON-10, ON-11, ON-12 A, ON-13, GL-2, YO-1, AC-1 and AC-2. On the approvals page: red dots hidden (17 stale ones, including on boards already named "approved"), M6-end pill set to "approved", boards renamed. On the everything page: chips set to "approved". Not approved: ON-6. Not asked yet: M11 journey map.
- 20 Oct · **M12 dark mode, recalibrated and following light.** New page `05d · dark mode · hi-fi (follows light)` holds a dark twin of all 32 light hi-fi boards (approvals, 04b, 05), in the same layout, each with a red dot. `design-system/sync/dark-sync.mjs` drives Paper through its MCP relay (`sync/paper-client.mjs`): it hashes each light board, rebuilds only what changed (token swap `--color-X` → `--color-dark-X`, svg paths included, lock-screen/home-screen chrome kept as drawn), and archives the old twin on `92 · archive · dark mode versions`. `sync/dark-audit.mjs` measures every text node against what it actually sits on and flags any rising surface that reads darker than its parent. First full build: 39 of 3,015 text nodes below AA (12 real) and 38 depth inversions. Final: 2 below AA (AC-1's disabled sign-in buttons while restoring, exempt) and 1 inversion (a 20×9 shape inside a paywall illustration). Token changes: 11 dark pairs added to Paper; dark `surface.washPressed` → black 30%, `background.sunken` → night.950, `depth.stroke.outer` → white 7%; new `background.underlay` and `surface.lifted` (both equal to their old light values, so light is unchanged), with 38 + 71 light layers repointed by `sync/lift-on-tint.mjs`. Earlier dark journey maps (v1, my hand-run v2) and a YO-5 pilot are archived. Swift tokens regenerated.
- 21 Oct (later): comments handled. Paywall tiles redrawn as plain design-system glyphs (old ones archived, hidden on the board). ON-6 restyled to match settings, and reframed as "the more i know, the more i notice" with a knows-you meter. Music moved into "see all" so it fits. Everything page updated. Dark sync run; audit clean on these boards. Microinteractions plan written (docs/design/microinteractions-plan.md).
- Journey map: founder's balance comment fixed. The heavy black arrows became raised action pills with hairline arrows. The red dashed failure boxes moved under their own screens as wash cards (red is reserved for "needs approval"). Stale ON-6 and paywall copies refreshed. Marked approved; tracker M11 ✅.
- ON-6 title changed to "i'd love to get to know you." because the founder found "the more i know, the more i notice" surveillance-y. Music still doesn't fit at settings row size, so it stays in "see all". Microinteraction answers recorded: the listening glow follows your voice; the "knows you well" moment is in.
- 21 Oct: the founder paused building until the plan is approved. Wrote the Swift implementation plan (docs/design/swift-implementation-plan.md) and the full motion system (design-system/principles/motion-system.md): curves, eight springs with overshoot numbers, ramps, haptics, how every part moves, ambient "life" rules, a visual pass per motion, and the Swift API. The ds/m14-foundation worktree is staged but not committed or built.

## 21 Oct · whole-file reorganisation (comment-watch session)
- Pages reordered into start/approvals → system → product → archive, with two duplicate numbers fixed and icons added. 19 approved boards moved off approvals to 04b, 02 and 02b. Every page was laid out in labelled rows. About 11,800 generic layer names were replaced with content names. The dark-sync config gained a per-source `include` filter and tighter section offsets. Details are in findings-log.md.
- 21 Oct: the Paper file hit its size limit. Archives were split into a full-copy file, and the warning cleared. Prices changed to $24.99/$239.99 (save 20%) on 57 texts. The Swift plan was rewritten top-down to cover the backend: 17 systems, 7 flows, a data contract for every page, a platform track B0–B8, and a ship gate per flow.
- 21 Oct: wrote docs/design/m14-goal-prompt.md, a self-contained goal prompt for the M14 session (goal, the plan-before-code rule, reading list, context, decisions, approach, PR definition of done, feel brief, safety, first steps).
