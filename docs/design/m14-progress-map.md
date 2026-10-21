# M14 progress map · every byte, smallest to largest

**Bottom line:** M14 is a finite pool of **240 bytes**. Each byte is one small PR (or one founder action). Status: **17 done · 0 doing · 223 to do**. It's built bottom-up: platform baseline → foundation → sub-components → components → pages → backend per flow → wiring → flow pass → ship gate. The log of every merged PR is in `swift-implementation-plan.md` §10.

Repo key: **app** = `Retrospect/` and **backend** = `backend/` in `hankHillsleftnut/NPRdoinglaundry` (local `retrospect-main`); **agent** = `hankHillsleftnut/Retrospect-agent` (local `retrospect-agent`); **paper** = the Paper master file. Never commit to `RETROSPECT_BACKUP_2026-05-28`.

Regenerate this file with `python3 docs/design/tools/progress_map.py` after changing a status there. Status: todo · doing · review · done · blocked (with the reason).


## 0 · Platform baseline (B0) · 5/11 done

| ID | Byte | Repo | Needs | Status | PR |
|---|---|---|---|---|---|
| B0.1 | Merge this branch into main: speech proxy, fail-closed payments, main's dedup, goals and Calendar fixes | NPRdoinglaundry |  | done | [#20](https://github.com/hankHillsleftnut/NPRdoinglaundry/pull/20) |
| B0.0 | Commit the plan, progress map, motion system, goal prompt and design-system docs to NPRdoinglaundry, so they live in git | NPRdoinglaundry (docs) |  | done | [#21](https://github.com/hankHillsleftnut/NPRdoinglaundry/pull/21) |
| B0.8 | Remove the OpenAI key committed in 'Retrospect fina (SwiftUI)/Views/Contentview.swift' (found by gitleaks, 21 Oct); you rotate it in OpenAI | NPRdoinglaundry + founder | B0.1 | review | [#31](https://github.com/hankHillsleftnut/NPRdoinglaundry/pull/31) |
| B0.9 | CI: SwiftLint, SwiftFormat and gitleaks on every PR | NPRdoinglaundry (CI) |  | done | [#29](https://github.com/hankHillsleftnut/NPRdoinglaundry/pull/29) |
| B0.10 | CI: Claude code review on every PR (Opus 5.5); needs the ANTHROPIC_API_KEY repo secret (you) | NPRdoinglaundry (CI) + founder |  | done | [#30](https://github.com/hankHillsleftnut/NPRdoinglaundry/pull/30) |
| B0.2 | Rotate the ElevenLabs key (you, in ElevenLabs); confirm no client holds it | founder | B0.1 | todo |  |
| B0.3 | Lock down /claude/generate: per-user limits now, purpose routes later | backend | B0.1 | done | [#28](https://github.com/hankHillsleftnut/NPRdoinglaundry/pull/28) |
| B0.4 | Migrations for podcast_episodes and the users columns that only live in the combined SQL | backend (supabase/) | B0.1 | todo |  |
| B0.5 | One idempotency key per entry; stop the double voice upload and the resync re-upload | app + backend | B0.1 | todo |  |
| B0.6 | Fix the /insights call that 404s (OpenAIService retires with old screens in X05) | app | B0.1 | review | [#32](https://github.com/hankHillsleftnut/NPRdoinglaundry/pull/32) |
| B0.7 | Auth on the agent's /runs cost dashboard | agent | B0.1 | todo |  |

## 0b · Paper: the final everything set (E), the master the code is checked against · 0/6 done

| ID | Byte | Repo | Needs | Status | PR |
|---|---|---|---|---|---|
| E01 | Re-take all 37 screens on 06 · everything · latest from their masters (after the reorg, new prices and off-axis tiles); replace copies, never add, to keep the file under its size limit | paper |  | todo |  |
| E02 | Every key state of each screen on its master, on 05b (loading, empty, error, offline where the screen has them) | paper | E01 | todo |  |
| E03 | SE (small screen) layout decided for every screen | paper | E01 | todo |  |
| E04 | Dark set follows: the dark session rebuilds the changed boards, and the audit is clean | paper | E01 | todo |  |
| E05 | Final read-through with you: everything page approved as the build master (red dots off) | paper | E02,E03,E04 | todo |  |
| E06 | Keep it current: every design change found in code goes to the master first, then the copy on 06 (standing rule) | paper |  | todo |  |

## 1 · UI foundation (F) · 12/12 done

| ID | Byte | Repo | Needs | Status | PR |
|---|---|---|---|---|---|
| F01 | Add the new motion and haptic tokens to tokens.json (snappy, settle, pop, gentle, curve.move, typeOn) | app |  | done | [#22](https://github.com/hankHillsleftnut/NPRdoinglaundry/pull/22) |
| F02 | Generator: springs, curves and haptics into RMotion / RHaptic; colours and sizes regenerate | app | F01 | done | [#22](https://github.com/hankHillsleftnut/NPRdoinglaundry/pull/22) |
| F03 | RType: every text role, Exposure axes, Dynamic Type | app | F02 | done | [#23](https://github.com/hankHillsleftnut/NPRdoinglaundry/pull/23) |
| F04 | RDepth: wash, sunken, raised, secondary, lit | app | F02 | done | [#23](https://github.com/hankHillsleftnut/NPRdoinglaundry/pull/23) |
| F05 | Foundation gallery preview (light and dark) checked against the Paper token sheet | app | F03,F04 | done | [#23](https://github.com/hankHillsleftnut/NPRdoinglaundry/pull/23) |
| F06 | Motion modifiers 1: .rPress, .rAppear (stagger), with Reduce Motion built in | app | F02 | done | [#24](https://github.com/hankHillsleftnut/NPRdoinglaundry/pull/24) |
| F07 | Motion modifiers 2: .rPop, .rShake, .rBlurReplace | app | F02 | done | [#24](https://github.com/hankHillsleftnut/NPRdoinglaundry/pull/24) |
| F08 | Motion modifiers 3: .rFloat (life rules), .rScrollLag | app | F02 | done | [#24](https://github.com/hankHillsleftnut/NPRdoinglaundry/pull/24) |
| F09 | Motion lab preview: every spring and curve side by side; tune the ramps; add touch-pause to .rFloat | app | F06,F07,F08 | done | [#25](https://github.com/hankHillsleftnut/NPRdoinglaundry/pull/25) |
| F10 | Screen switches: design.v2.<screen> flags (debug and TestFlight on, App Store off) | app |  | done | [#26](https://github.com/hankHillsleftnut/NPRdoinglaundry/pull/26) |
| F11 | Fonts: check Exposure, Hedvig and Geist registration and PostScript names | app |  | done | verified in #23 |
| F12 | Token-literal check: a script that fails a PR with raw colours, sizes or springs in views | app | F02 | done | [#27](https://github.com/hankHillsleftnut/NPRdoinglaundry/pull/27) |

## 2 · Platform foundation (B1) · 0/15 done

| ID | Byte | Repo | Needs | Status | PR |
|---|---|---|---|---|---|
| B1.01 | Typed API client core: Codable requests, one execute, mapped errors | backend | B0.1 | todo |  |
| B1.02 | Codable models per domain (entries, episodes, goals, sources, facts) | backend | B1.01 | todo |  |
| B1.03 | Retries with backoff, timeouts, offline detection | backend | B1.01 | todo |  |
| B1.04 | Backend: real token refresh (refresh tokens, rotation) | backend | B0.1 | todo |  |
| B1.05 | App: silent token refresh; a 401 retries once before signing out | app | B1.04,B1.01 | todo |  |
| B1.06a | Local store (SwiftData) schema + container: entries | app | B1.02 | todo |  |
| B1.06b | Local store: episodes and briefs cache | app | B1.06a | todo |  |
| B1.06c | Local store: goals, sources and facts cache | app | B1.06a | todo |  |
| B1.07 | Outbox: entries save locally first and send once when online | backend | B1.06a,B0.5 | todo |  |
| B1.08 | Analytics facade plus the first events (screen, action, error) | backend |  | todo |  |
| B1.09 | Per-user cost view: join the agent traces per user and week | agent + backend | B0.7 | todo |  |
| B1.10 | Backend safe-door middleware for agent routes: auth, user from token, per-user rate and spend limits | backend | B0.1 | todo |  |
| B1.11 | Account deletion: backend cascade through the backend, agent tables and storage | backend + agent | B1.10 | todo |  |
| B1.12 | Delete all my data (keep the account) | backend + agent | B1.11 | todo |  |
| B1.13 | Privacy manifest (PrivacyInfo.xcprivacy) and required-reason APIs | backend |  | todo |  |

## 3 · Sub-components (S) · 0/16 done

| ID | Byte | Repo | Needs | Status | PR |
|---|---|---|---|---|---|
| S01 | icon well | app | F05 | todo |  |
| S02 | hairline · full | app | F05 | todo |  |
| S03 | hairline · inset after icon | app | F05 | todo |  |
| S04 | red dot | app | F05 | todo |  |
| S05 | glow stack (the lit object) | app | F05 | todo |  |
| S06 | grain | app | F05 | todo |  |
| S07 | progress hairline | app | F05 | todo |  |
| S08 | knows-you track | app | F05 | todo |  |
| S09 | spinner | app | F05 | todo |  |
| S10 | the mark | app | F05 | todo |  |
| S11 | status dot (connected, problem, syncing) | app | F05 | todo |  |
| S12 | waveform bars | app | F05 | todo |  |
| S13 | section label | app | F05 | todo |  |
| S14 | artwork mesh | app | F05 | todo |  |
| S15 | SF Symbol wrapper (size, weight, tint from tokens) | app | F05 | todo |  |
| S16 | press style | app | F05 | todo |  |

## 4 · Components (C) · 0/40 done

| ID | Byte | Repo | Needs | Status | PR |
|---|---|---|---|---|---|
| C01 | button · lit — every state, light and dark, motion pass | app | S05,S16 | todo |  |
| C02 | button · secondary — every state, light and dark, motion pass | app | S16 | todo |  |
| C03 | button · text — every state, light and dark, motion pass | app | S16 | todo |  |
| C04 | icon button (wash) — every state, light and dark, motion pass | app | S01,S16 | todo |  |
| C05 | pill / chip — every state, light and dark, motion pass | app | S16 | todo |  |
| C06 | tag — every state, light and dark, motion pass | app |  | todo |  |
| C07 | switch — every state, light and dark, motion pass | app |  | todo |  |
| C08 | segmented — every state, light and dark, motion pass | app |  | todo |  |
| C09 | settings row · value / nav — every state, light and dark, motion pass | app | S02,S03 | todo |  |
| C10 | source row (connect → connected, reconnect, syncing) — every state, light and dark, motion pass | app | S01,S11,S09 | todo |  |
| C11 | text field — every state, light and dark, motion pass | app |  | todo |  |
| C12 | search field — every state, light and dark, motion pass | app |  | todo |  |
| C13 | composer — every state, light and dark, motion pass | app | S12 | todo |  |
| C14 | voice composer — every state, light and dark, motion pass | app | S12 | todo |  |
| C15 | talk button — every state, light and dark, motion pass | app | S05 | todo |  |
| C16 | listening field (voice-level glow) — every state, light and dark, motion pass | app | S05 | todo |  |
| C17 | top bar (entry, settings, tab title) — every state, light and dark, motion pass | app | S01 | todo |  |
| C18 | tab bar — every state, light and dark, motion pass | app | S15 | todo |  |
| C19 | sheet and dialog — every state, light and dark, motion pass | app |  | todo |  |
| C20 | menu / title menu — every state, light and dark, motion pass | app |  | todo |  |
| C21 | toast (floats) — every state, light and dark, motion pass | app |  | todo |  |
| C22 | mini-player — every state, light and dark, motion pass | app | S14,S07 | todo |  |
| C23 | player — every state, light and dark, motion pass | app | S14 | todo |  |
| C24 | transport — every state, light and dark, motion pass | app |  | todo |  |
| C25 | scrubber — every state, light and dark, motion pass | app |  | todo |  |
| C26 | brief card — every state, light and dark, motion pass | app | S14 | todo |  |
| C27 | episode tile (scroll lag) — every state, light and dark, motion pass | app | S14 | todo |  |
| C28 | guess card — every state, light and dark, motion pass | app |  | todo |  |
| C29 | goal card — every state, light and dark, motion pass | app |  | todo |  |
| C30 | message (yours, Retro's, streaming) — every state, light and dark, motion pass | app |  | todo |  |
| C31 | entry row — every state, light and dark, motion pass | app |  | todo |  |
| C32 | evidence row — every state, light and dark, motion pass | app |  | todo |  |
| C33 | benefit row with tile — every state, light and dark, motion pass | app |  | todo |  |
| C34 | onboarding question (types out, haptic per word) — every state, light and dark, motion pass | app |  | todo |  |
| C35 | onboarding progress — every state, light and dark, motion pass | app | S07 | todo |  |
| C36 | knows-you meter — every state, light and dark, motion pass | app | S08 | todo |  |
| C37 | paywall plan pair — every state, light and dark, motion pass | app | S05 | todo |  |
| C38 | you map: nodes, lines, life — every state, light and dark, motion pass | app |  | todo |  |
| C39 | loading, empty, error, offline states (shared) — every state, light and dark, motion pass | app | S09 | todo |  |
| C40 | lock screen and widget views — every state, light and dark, motion pass | app | S14 | todo |  |

## 5 · Pages (P), built from components with sample data where needed · 0/37 done

| ID | Byte | Repo | Needs | Status | PR |
|---|---|---|---|---|---|
| P01 | ON-1/2 · splash and sign-in — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P02 | ON-3–9 · the questions — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P03 | ON-5 · privacy — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P04 | ON-6 · connect — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P05 | ON-10 · getting ready — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P06 | ON-11 · the tease — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P07 | ON-12 · paywall — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P08 | ON-13 · first home — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P09 | JR-1 · journal — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P10 | JR-2 · today's brief — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P11 | JR-3 · all entries — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P12 | JR-4 · one entry — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P13 | PC-1 · podcasts — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P14 | PC-2 · player — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P15 | PC-3 · why this is here — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P16 | GL-1 · goals — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P17 | GL-2 · one goal — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P18 | YO-1 · you — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P19 | YO-2 · search — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P20 | YO-3 · a source — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P21 | YO-4 · a node — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P22 | YO-5 · what I know — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P23 | ST-1 · settings — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P24 | ST-2 · daily brief — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P25 | ST-3 · sources — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P26 | ST-4 · a source — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P27 | ST-5 · privacy — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P28 | ST-6 · how straight — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P29 | ST-7 · voice — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P30 | ST-8 · what I've learned — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P31 | ST-9 · account — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P32 | AC-1 · sign in, returning — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P33 | AC-2 · signing out — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P34 | EX-1 · share — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P35 | EX-2 · lock screen / Live Activity — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P36 | EX-3 · notifications — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |
| P37 | EX-4 · widgets — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written | app | components | todo |  |

## 6 · Backend capabilities per flow (B2–B8) · 0/42 done

| ID | Byte | Repo | Needs | Status | PR |
|---|---|---|---|---|---|
| B2.01 | Google sign-in for the app (backend verify + app) | backend + app | B1.04 | todo |  |
| B2.02 | Door: onboarding interpret | backend | B1.10 | todo |  |
| B2.03 | Door: onboarding readiness and advance | backend | B1.10 | todo |  |
| B2.04 | Structured onboarding answers (migration + write) | backend | B2.02 | todo |  |
| B2.05 | Knows-you endpoint (connected-source count for now) | backend | B1.10 | todo |  |
| B2.06a | Notion OAuth provider + connect start/callback (backend) | backend | B1.10 | todo |  |
| B2.06b | Notion connector: fetch pages and databases (agent) | agent | B2.06a | todo |  |
| B2.06c | Notion items normalised into source_items and analysis units (agent) | agent | B2.06b | todo |  |
| B2.06d | Notion row on ON-6 and ST-3 wired; knows-you counts it (app) | app | B2.06c,B2.05 | todo |  |
| B2.07 | Hide GitHub until its connector exists (flag) | app | F10 | todo |  |
| B2.08 | First episode as a background job (no 8-minute request) | backend + agent | B0.4 | todo |  |
| B2.09 | APNs: device-token table and register endpoint | backend + app | B1.10 | todo |  |
| B2.10 | APNs sender + 'episode ready' push | backend | B2.09,B2.08 | todo |  |
| B2.11 | StoreKit 2 products: $24.99/mo, $239.99/yr | app (StoreKit config) |  | todo |  |
| B2.12 | App: purchase and restore (still fail-closed until validated) | app | B2.11 | todo |  |
| B2.13 | Backend: transaction validation + entitlement table | backend | B2.12 | todo |  |
| B3.01 | Door: conversation (send, today) | backend | B1.10 | todo |  |
| B3.02 | Streaming replies (server-sent events) backend | backend | B3.01 | todo |  |
| B3.03 | Streaming client | app | B3.02,B1.01 | todo |  |
| B3.04 | Doors: today's brief and brief history | backend | B1.10 | todo |  |
| B3.05 | Door: hypotheses / guess cards | backend | B1.10 | todo |  |
| B3.06 | Entry history endpoint | backend | B1.10 | todo |  |
| B3.07 | Door: what Retro took from an entry (lineage) | backend | B1.10 | todo |  |
| B3.08 | Door: corrections ('not right') | backend | B1.10 | todo |  |
| B4.01 | Weekly episode push | backend | B2.10 | todo |  |
| B4.02 | Door: why this is here (evidence) | backend | B1.10 | todo |  |
| B4.03 | Door: episode feedback | backend | B1.10 | todo |  |
| B5.01 | Door: goal evidence | backend | B1.10 | todo |  |
| B5.02 | Goal check-in push | backend | B2.10 | todo |  |
| B6.01 | Door: people | backend | B1.10 | todo |  |
| B6.02 | Door: portrait | backend | B1.10 | todo |  |
| B6.03 | Door: facts by area with sureness | backend | B1.10 | todo |  |
| B6.04 | Door: search answer | backend | B1.10 | todo |  |
| B6.05 | Door: search sources | backend | B6.04 | todo |  |
| B7.01 | Doors: settings and preferences (ambient, how straight, voice speed and mode) | backend | B1.10 | todo |  |
| B7.02 | Brief time per user (replace the fixed 08:00 UTC cron) | agent | B3.04 | todo |  |
| B7.03 | Server data export | backend | B1.10 | todo |  |
| B7.04 | Manage subscription link + renewal date | backend | B2.13 | todo |  |
| B8.01 | Widget extension: episode and brief widgets (replace the template) | app | B1.06b | todo |  |
| B8.02 | Lock screen widget | app | B8.01 | todo |  |
| B8.03 | Share extension | app | B1.07 | todo |  |
| B8.04 | Notification categories and deep-link router | app | B2.10 | todo |  |

## 7 · Wiring, flows and ship gates (W, L, G) · 0/21 done

| ID | Byte | Repo | Needs | Status | PR |
|---|---|---|---|---|---|
| W1 | Wire first run: swap sample data for live; ledger for first run at zero | app + backend | ON-*, B2.* | todo |  |
| L1 | Flow pass first run: navigation, transitions, signature moments #2 #3 #4 #7 #13 | app | W1 | todo |  |
| G1 | Ship gate first run: TestFlight real account, cost logged, errors and offline, App Store rules, your sign-off → switch on, old screens deleted | all | L1 | todo |  |
| W2 | Wire daily loop: swap sample data for live; ledger for daily loop at zero | app + backend | JR-*, B3.* | todo |  |
| L2 | Flow pass daily loop: navigation, transitions, signature moments #8 | app | W2 | todo |  |
| G2 | Ship gate daily loop: TestFlight real account, cost logged, errors and offline, App Store rules, your sign-off → switch on, old screens deleted | all | L2 | todo |  |
| W3 | Wire podcasts: swap sample data for live; ledger for podcasts at zero | app + backend | PC-*, B4.* | todo |  |
| L3 | Flow pass podcasts: navigation, transitions, signature moments #6 #9 #10 | app | W3 | todo |  |
| G3 | Ship gate podcasts: TestFlight real account, cost logged, errors and offline, App Store rules, your sign-off → switch on, old screens deleted | all | L3 | todo |  |
| W4 | Wire goals: swap sample data for live; ledger for goals at zero | app + backend | GL-*, B5.* | todo |  |
| L4 | Flow pass goals: navigation, transitions, signature moments #11 | app | W4 | todo |  |
| G4 | Ship gate goals: TestFlight real account, cost logged, errors and offline, App Store rules, your sign-off → switch on, old screens deleted | all | L4 | todo |  |
| W5 | Wire you: swap sample data for live; ledger for you at zero | app + backend | YO-*, B6.* | todo |  |
| L5 | Flow pass you: navigation, transitions, signature moments #12 | app | W5 | todo |  |
| G5 | Ship gate you: TestFlight real account, cost logged, errors and offline, App Store rules, your sign-off → switch on, old screens deleted | all | L5 | todo |  |
| W6 | Wire settings and account: swap sample data for live; ledger for settings and account at zero | app + backend | ST-*, AC-*, B7.* | todo |  |
| L6 | Flow pass settings and account: navigation, transitions, signature moments | app | W6 | todo |  |
| G6 | Ship gate settings and account: TestFlight real account, cost logged, errors and offline, App Store rules, your sign-off → switch on, old screens deleted | all | L6 | todo |  |
| W7 | Wire outside the app: swap sample data for live; ledger for outside the app at zero | app + backend | EX-*, B8.* | todo |  |
| L7 | Flow pass outside the app: navigation, transitions, signature moments | app | W7 | todo |  |
| G7 | Ship gate outside the app: TestFlight real account, cost logged, errors and offline, App Store rules, your sign-off → switch on, old screens deleted | all | L7 | todo |  |

## 8 · Signature moments (M), each with its motion visual pass · 0/13 done

| ID | Byte | Repo | Needs | Status | PR |
|---|---|---|---|---|---|
| M01 | orb breathes, satellites drift (splash) | app |  | todo |  |
| M02 | listening glow follows your voice | app |  | todo |  |
| M03 | answer word ink-sharpens | app |  | todo |  |
| M04 | + connect → connected, meter fills (and the 'knows you well' pop) | app |  | todo |  |
| M05 | getting ready honest steps | app |  | todo |  |
| M06 | player shrinks into mini-player, paywall rises | app |  | todo |  |
| M07 | plan glow slides, save 20% rolls | app |  | todo |  |
| M08 | your bubble lifts, reply sharpens line by line | app |  | todo |  |
| M09 | play morph, rolling time, chapter ticks | app |  | todo |  |
| M10 | tiles lag the scroll | app |  | todo |  |
| M11 | goal card folds, bar eases | app |  | todo |  |
| M12 | new fact blooms into the map | app |  | todo |  |
| M13 | questions type out with a soft tick per word | app |  | todo |  |

## 9 · Retire the old (X): nothing old left half-alive · 0/9 done

| ID | Byte | Repo | Needs | Status | PR |
|---|---|---|---|---|---|
| X01 | Inventory every old screen, service, route and table with its replacement and retirement trigger (plan §6b), kept current | app |  | todo |  |
| X02 | Version floor: minimum supported app version + force-update screen (app) and version header (backend) | app + backend | B1.01 | todo |  |
| X03 | Remove experiments with no new design: video journal, Polaroid, iMessage onboarding, the extra Home variants | app | G1 | todo |  |
| X04 | Remove the old design system (button styles, stray font helpers, ad-hoc colours) after the last old screen | app | G6 | todo |  |
| X05 | Remove ClaudeService, AIServiceManager and TTS fallbacks once every caller uses backend doors | app | G2 | todo |  |
| X06 | One-time migration of each person's local entries and goals into SwiftData (checksum, keep the old files until confirmed), then delete the old storage | app | B1.06a,B1.06c | todo |  |
| X07 | Remove old backend routes (/claude/generate, /pipeline/*, /goals/extract*, sync podcast generate) after 14 days of no calls from supported versions | backend | X02,G7 | todo |  |
| X08 | Agent: retire legacy observations / insights tables after a backup | agent | X07 | todo |  |
| X09 | Final sweep: unused files, assets and dependencies removed; the app is only the new code | app | X03,X04,X05,X06,X07 | todo |  |

## 10 · Testing (T) · 0/8 done

| ID | Byte | Repo | Needs | Status | PR |
|---|---|---|---|---|---|
| T01 | Snapshot tests for components (every state, light), run in CI | app | C01 | todo |  |
| T02 | UI-test harness: launch any screen or flow with sample or live data from a launch argument | app + backend | F10 | todo |  |
| T03 | First run UI test: sign-in → questions → connect → paywall → first home | app + backend | L1 | todo |  |
| T04 | Daily loop UI test: write, reply streams in, entry saved offline then sent | app + backend | L2 | todo |  |
| T05 | Podcasts, goals and you UI tests | app + backend | L3,L4,L5 | todo |  |
| T06 | Settings and account UI tests, including delete account and restore purchases | app + backend | L6 | todo |  |
| T07 | Backend contract tests for every agent door (auth, user from token, limits) | backend | B1.10 | todo |  |
| T08 | A test account seeded on staging for every flow; test spend logged separately | app + backend | B1.08 | todo |  |

## 11 · Release (R) · 0/7 done

| ID | Byte | Repo | Needs | Status | PR |
|---|---|---|---|---|---|
| R01 | Crash and error reporting in the app (Sentry, no personal content in events) | app + founder | B1.08 | todo |  |
| R02 | TestFlight pipeline: archive, sign and upload from a script (you add the App Store Connect key) | app + founder |  | todo |  |
| R03 | App privacy labels and the privacy manifest match what the app collects | app + founder | B1.13 | todo |  |
| R04 | App Store screenshots and preview made from the Paper boards | app + founder | E05 | todo |  |
| R05 | Review notes and a demo account for App Review (sign-in, payments, deletion) | app + founder | B2.13,B1.11 | todo |  |
| R06 | Production deploy checklist per batch: migrations reviewed, backup, your yes, then deploy | backend + founder | B0.4 | todo |  |
| R07 | First App Store submission of the new first run | app + founder | G1,R01,R02,R03,R04,R05 | todo |  |

## 12 · Observability (O) · 0/3 done

| ID | Byte | Repo | Needs | Status | PR |
|---|---|---|---|---|---|
| O01 | Backend: structured logs per door with user, latency, cost; alert on error spikes | backend | B1.10 | todo |  |
| O02 | Per-user weekly cost report from traces + door logs (cost-per-user doc fed automatically) | agent + backend | B1.09,O01 | todo |  |
| O03 | App: error and offline states reported (counts and types only, never content) | app | R01 | todo |  |
