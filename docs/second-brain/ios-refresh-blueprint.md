# The iOS refresh: blueprint

20 October 2026, night. **The single document the refresh is built from.** It pulls together everything the backend can do (researched from the code, not from memory), how the product is actually used today, the goal spec, the audits, and every decision the founder made in the chats. Process: [ios-refresh-plan.md](./ios-refresh-plan.md). Problems: [app-audit.md](./app-audit.md) + [app-audit-deep.md](./app-audit-deep.md). Opportunities: [ios-refresh-opportunities.md](./ios-refresh-opportunities.md). Board: https://claude.ai/artifact/9uf2mRH9rk9RKneh4XrQDb

**The standard this document is held to:** after it, nothing new should be discovered about what the backend can do or how the app is used. Part 3 is a complete inventory of the brain service (`retrospect-agent`, main at `d4206a3`: 18 route files, 8 jobs, 52 migrations) and the backend the app talks to (`NPRdoinglaundry/backend`: 11 route files). Every capability is listed with where it lives, whether the app can reach it, whether it's switched on, and what the app does with it.

---

## Contents
1. The product in one page
2. How it's actually used today, and what that means for the design
3. The complete backend inventory
4. Gaps between the backend and a refreshed app
5. Design principles for the refresh
6. The new app, screen by screen (onboarding, Journal, Podcasts, Goals, You, Settings, outside the app, no screen)
7. The data contract the app needs (backend routes)
8. What to build, in order
9. Conflicts reconciled
10. Coverage checks: every goal and every problem has a home
11. Recommended defaults
12. Appendix B: verified behaviour, and the completeness check
13. Appendix A: module index

---

# 1. The product in one page

**The mission** ([goal-specs](./goal-specs.md)): *a companion that knows you and helps you grow. It learns on its own from what you write and do. You can hand it things. You talk to it in small pieces, continuously. It quietly handles the boring admin of your life. Talking to it feels soothing, not clinical.*

**Ambient by default** (decided 17 Oct): *the default user sends nothing.* Onboarding and connected sources are the substrate; journals are valuable context; links are a power-user bonus. The product must be good for someone who never types.

**The loop every hard thing follows:** **evidence → a question → their answer** (then, later, optionally an option). No verdicts. "Introspection, externalised." The product does the work; the person does the thinking.

**Two audio outputs, one profile:**
- **The daily brief:** the day's short episode (typically 4–5 min, cap 12, floor ~45 s; the cap announces itself), about what changed, framed by who you are and what you're trying to do; each item says why it's there; **on/off per person, off by default.**
- **The weekly episode:** the deep one: patterns, goals said vs did, reflection, and at most one question it's wondering about.

**The claim ladder** (how anything about a person is said): facts and patterns from evidence are **stated**; inferences and guesses are **asked**, never stated, and always carry how sure it is and what they rest on. Predictions are welcome; made-up content is not.

**The interaction shape** (founder, 20 Oct): a bottom bar, **one feature per page**, each page showing its feature off fully: **Journal · Podcasts · Goals · You**. Onboarding is **voice-first**: you can talk through every question and it talks back, opening with **the mission told by voice**, then questions → privacy → integrations → more questions → **the podcast tease** → **a scrollable paywall showing every benefit** → into the app, with guidance.

---

# 2. How it's actually used today

From the findings log and status (founder's account; production reads are by counts only):

| Fact | Source | What it means for the design |
|---|---|---|
| **5 written entries in the last 4 months**; 58 were in May | finding 15 | Journal can't be the engine. The app must be valuable to someone who doesn't write. |
| Last 120 days: **calendar on 35 days, health on 79, subscriptions 20, mail 1, own writing 2** | finding 16 | Passive sources carry the picture. Connect is the most important onboarding step after the questions. |
| 555 people stored: 300 from contacts, 211 named in writing, 8 from calendars; writing and contacts not yet joined | finding 17 (W2 merged) | The map's people layer is rich but needs matching; "same person?" questions are how the person helps. |
| 66 answers to the 36 questions, every one traced to evidence (2,636 links) | finding 14 | "What it knows about you" is real and inspectable today. |
| 72 patterns, all honestly "not enough to say yet" for change | findings 6–7 | Trajectories become readable from mid-November; the app must show "too early to tell" gracefully. |
| Reading after something is sent: median 2.5 min | finding 10 | "Read by the brain" can be shown within minutes of sending. |
| Cost ≈ $3.30 per user per week; first week ≈ $5–7 (two first episodes) | cost-per-user | One first episode, not two; the daily brief is the cost lever (speech is 20–40× thinking). |
| Testers: none yet; TestFlight not started | tester-readiness | The refresh ships to testers first; the demo is an account. |

**The design consequence, in one line:** the app must open each day with something already made for you (the brief, an episode, a question, a change), not with an empty box asking you to write.

---

# 3. The complete backend inventory

Legend: **App** = can the iOS app reach it today (✓ via the backend · ◐ agent only, behind its internal secret · ✗ nowhere). **On** = switched on in production.

## 3.1 Capture and reading

| Capability | Where | Shape | App | On |
|---|---|---|---|---|
| Send an entry (text, voice transcript, any content type) | backend `POST /content` {contentType, content, contentDate, metadata} | 202, fire and forget; no idempotency key | ✓ | yes |
| List what was sent | backend `GET /content` (id, type, date, processing_status) | | ✓ | yes |
| Read new material (extract facts, link people, update answers) | agent `jobs/daily-ingestion` 05:00 UTC; `material-arrivals` every minute | | — | daily yes; arrivals **off** (`ENABLE_MATERIAL_ARRIVALS`) |
| Ambient switch (read sources in the background, or only what you send) | agent `GET/PUT /settings/:userId/ambient` → {enabled, effective}; master switch wins | | ◐ | yes |
| Trust class per item (own words vs data) | `raw_content.trust_class` (129) | | — | yes |
| Delete an entry | backend `DELETE /content/:id` (removes the entry; the facts and answers drawn from it are **not** retracted) · reprocess `POST /content/:id/reprocess` | | ✓ but the app never calls it | — |
| Edit an entry | none (reprocess re-reads, but there's no way to change the words) | | ✗ | — |

## 3.2 Sources

| Capability | Where | App | On |
|---|---|---|---|
| Catalogue of sources with connection state | backend `GET /integrations` | ✓ | yes |
| Connect (OAuth start, callback) | backend `/integrations/:id/connect/start`, callback | ✓ | yes |
| File imports (ChatGPT, Claude, Grok, Netflix, archives) | backend `/integrations/:id/imports`, `/assets` | ✓ | yes |
| Sync now, disconnect, delete source data | backend `/integrations/connections/:id/{sync,delete-data}`, DELETE | ✓ | yes |
| Device batches (Health, Screen Time, calendar, contacts, music, photos) | backend device batches → agent `/integrations/enqueue-device-batch` | ✓ | yes |
| Connectors: Gmail, Google Calendar, Google Docs, YouTube, Spotify, Reddit, TikTok, X, LinkedIn, Pinterest, archive import | agent `connectors/` | ✓ (via backend) | runtime **off** (`ENABLE_INTEGRATION_RUNTIME`) |
| **What the app can actually connect today** (backend `services/integration-catalog.ts`) | **available:** Apple Health, Google Docs · **in development:** Calendar, Screen Time, Apple Music, Photos, Contacts, Spotify, YouTube, Reddit · **Google verification needed:** Gmail · **platform approval needed:** TikTok, X, LinkedIn · **file import:** ChatGPT, Claude, Grok, Netflix | ✓ `GET /integrations`, `/catalog`, `/readiness`, `/connections`, `POST /:id/native-connected`, `/connections/:id/reconnect` | — |
| What each source helps it understand (general and special purpose, signals, how it may be used) | agent `integrations/source-intelligence.ts` (profiles per source) | ✗ not in the backend catalog (only short domain tags) | — |
| Research about the person's public profiles (Instagram, TikTok, X, LinkedIn, Substack, YouTube handles) | agent `pipelines/social-research.ts`, `/ingest/social-research` (internal) | ✗ | — |
| YouTube watch history (Takeout import) and transcripts for saved videos | agent `imports/youtube-takeout`, `reference/youtube-transcript` (needs `SUPADATA_API_KEY`) | ✗ (script only) | transcripts off until key set |
| Revoke a whole account | agent `/integrations/accounts/revoke` | ◐ | yes |

## 3.3 Understanding (the brain's picture of you)

| Capability | Where | Shape | App |
|---|---|---|---|
| **The read contract**: answers to the 36 questions (question, answer, confidence, independent sources, confirmed, stated/asked, last moved), silent areas, patterns (confidence, instances, first/last seen, trajectory), whys (mechanism, provisional), goals, shifts from normal, time by category, what moved since the last episode | agent `understanding/read.ts` `readUnderstanding()` | `UnderstandingContract` | **✗ no route** |
| Said vs did per goal (said: stated/last mentioned; did: hours this week vs usual, events, content items, patterns) | agent `understanding/said-vs-did.ts` | `SaidVsDid` | **✗ no route** |
| Content groups (what you've been consuming, clustered and named) | agent `understanding/content-groups.ts` | | ✗ |
| Entities: person, organization, project, place, topic, event, goal, identity, emotion, habit (confidence, status) | table `entities` + `entity_aliases` | | ✗ (old `/graph/assertions` only) |
| Facts between entities (subject → predicate → object, confidence, status) with evidence | `assertions`, `assertion_evidence`, `assertion_relations`, `claim_edges` | | ◐ old backend `/graph/assertions` |
| People matching: "is the Sam in your writing Sam Ortiz?" | agent `GET /people/:userId/held`, `POST …/held/:id` {same\|different} | | ◐ |
| Lint: claims flagged as stale or unsupported are withheld until resolved | agent `brain/lint.ts`, daily | | — |
| **People significance**: recency-weighted mentions × intensity × closeness, half-life 60 days; a barista mentioned once stays small, a partner mentioned weekly grows | agent `brain/people.ts` (stored on each person) | | ✗ (the map's dot size for people) |
| Changes from your normal (e.g. steps up 95% on your usual week, with significance) | agent `brain/baseline-shifts.ts` → `shifts` in the read contract | | ✗ (via `/understanding`) |
| Where your time went (each calendar event categorised) | agent `brain/time-categories.ts`, `place-events.ts` → `time` in the read contract | | ✗ (via `/understanding`) |
| Your usual timezone offset, inferred from your calendar | agent `brain/daily-summaries.ts` `usualOffset()` | | — (a first guess for K4) |
| The portrait (a small always-readable model: slots and lines) | agent `brain/portrait.ts`, `user_understanding` | | ✗ |

## 3.4 Talking to it

| Capability | Where | Shape | App |
|---|---|---|---|
| **Conversation** | agent `POST /conversation` {userId, text} → {intent: fyi\|question\|correction\|chat, reply (may be empty: silence is allowed), cut, used}; `GET /conversation/:userId/today` (working memory 18 h) | | ◐ |
| **Corrections in plain words** | agent `POST /corrections` {text} → applied, or candidates to confirm; `POST /corrections/confirm` {kind: fact\|answer\|pattern\|why, id, mode: changed\|wrong} | | ◐ (backend has old graph feedback only) |
| **Search** | agent `POST /search/sources` {q} → hits {kind: item\|fact\|answer\|saved, snippet, happened_at, score} (~1 s); `POST /search/answer` → {summary, abstained, sources, numbered citations}; `GET /search/:userId/source/:kind/:id` | | ◐ |
| **Hypotheses** ("what it's wondering"), from a closed set of non-clinical frameworks | agent `POST /hypotheses/:userId/:id` {yes\|no}; `GET …/why` → framework, rationale, what it rests on | proposed and offered inside the weekly episode (one asked slot); dial `speak` **off by default** | ◐ |
| How bold it may be (appetite 0–3: just what happened · gentle questions · honest observations · don't hold back), first guess from your words | agent `GET/PUT /settings/:userId/appetite` {level \| null} | stated outranks inferred | ◐; inference behind `ENABLE_APPETITE` |
| What it's learned about its own questions | agent `GET /settings/:userId/learning` | behind `ENABLE_LEARNING` | ◐ |
| Preferences (tone, trusted voice, focus areas, avoid topics, directives) | agent `GET/PUT /preferences/:userId` | | ◐ |
| **Actions** (draft a message, a reminder, a calendar hold, a note): approve / reject / undo | agent `GET /actions/:userId`, `POST …/:id` {decision} | only the person's own words may start one | ◐ — **nothing proposes actions yet** |

## 3.5 Outputs

| Capability | Where | Shape | App | On |
|---|---|---|---|---|
| **Weekly episode** | agent `POST /podcasts/generate`; cron Sun 06:00 UTC | title, description, mood, duration, **audioUrl**, script, summary, **outline = the plan** (items with kind, register, evidence; spine; the one question/hypothesis; withheld; silent areas) | ✓ list/get via backend | `ENABLE_AGENT_CRONS` |
| **Daily brief** (written in sections: what you sent · today (your calendar) · a saved link it resurfaced · what moved) | agent `GET /briefs/:userId/latest`, `POST /briefs/generate`, `PUT /briefs/:userId/enabled`; cron 08:00 UTC | kind brief\|quiet, **through_line (the spoken text)**, spine question and movement, items [{text, why, quote (verified), source}] | ◐ | `ENABLE_DAILY_BRIEF`; per person off |
| Daily brief **audio** | none: "text first; audio later" (migration 128) | | ✗ | — |
| Episode feedback | agent `POST/GET /feedback/episodes/:id` {text, rating} | | ◐ |
| Personalised notification copy (morning and evening variants about your week) | agent `POST /notifications/generate` | | ◐ |
| Voice (ElevenLabs) | backend `POST /speech/synthesize` {text} → whole MP3, one voice, chunked server-side | | ✓ (no streaming) |
| The three "hosts" (thoughtful friend, wise mentor, energetic host) | agent `services/elevenlabs.ts` and backend `voice-personas.ts`: **all use the same voice id**, differing only in stability and style | | ✓ `/profile/persona` (the picker barely changes the sound) |
| Spending ceiling | $15 per person per rolling 24 h (`USER_DAILY_SPEND_CAP_USD`) | episodes refused above it; reading never | — |

## 3.6 Goals

| Capability | Where | App |
|---|---|---|
| CRUD | backend `/goals` (list, create, update, decline, extract-and-save, synthesize) | ✓ (but the app overwrites the server's list: G1) |
| Lifecycle: merged (near-duplicates), expired (90 days unmentioned), revived | agent `goals/lifecycle.ts` daily; backend respects merged/expired (#19) | ✓ `GET /goals` returns every column (status, status_reason, merged_into, status_at); today's app decodes only `isActive` |
| Goals stated in onboarding | agent `POST /onboarding/goals` {answersText} | ◐ |
| Said vs did | 3.3 | ✗ |

## 3.7 Saved links (the reference bank)

| Capability | Where | App |
|---|---|---|
| Any link in anything you send becomes a saved item, with your surrounding words as its reason | agent `reference/capture.ts` (daily) | ✓ indirectly (send a link via `/content`) |
| Enrich (title, page text, long pages, tweets), relate to goals, find by meaning | agent `reference/{enrich,relevance,embed}` | via search ◐ |
| Resurface a saved link in the daily brief when it bears on today | brief planner (`resurface`) | via brief ◐ |
| Share sheet into the app | none | ✗ |

## 3.8 Onboarding

| Capability | Where | App | On |
|---|---|---|---|
| Stage: reading → understanding → making_episode → ready | agent `GET /onboarding/readiness/:userId` | ◐ | pipeline **off** (`ENABLE_ONBOARDING_PIPELINE`) |
| Advance now | agent `POST /onboarding/advance` | ◐ | |
| First pass at the 36 questions (~$0.72) | agent `questions/run-first-pass` | — | |
| "Magic moments" from onboarding + sources, seeded as tracked hypotheses | agent `POST /onboarding/interpret` | ◐ | |
| Onboarding answers as context | backend profile context upload | ✓ | |

## 3.9 Switches that change what the person experiences

**`EPISODE_PLANNER=v2` / `EPISODE_PLANNER_V2_USERS`** (the new episode planner: stored plan, "why this is here", the one question; otherwise the older Cook A/B/C pipeline runs, with a different outline) · **`DAILY_PLANNER=v2` / `DAILY_PLANNER_V2_USERS`** (the new brief: what you sent first, today, a resurfaced link, what moved) · `INTEGRATION_SYNC_INTERVAL_MINUTES` (360: sources sync every 6 h) · `ENABLE_AGENT_CRONS` (daily reading, weekly episode) · `ENABLE_DAILY_BRIEF` + per-person `daily_brief_enabled` (default off) · `ENABLE_MATERIAL_ARRIVALS` (read within minutes, not daily) · `ENABLE_ONBOARDING_PIPELINE` (first episode inside onboarding) · `ENABLE_QUESTION_RESEARCH` · `ENABLE_INTEGRATION_RUNTIME` (connectors sync) · `ENABLE_APPETITE` · `ENABLE_LEARNING` · `ENABLE_RECORD_PATTERNS` · hypothesis dial `speak` (default false) · ambient master switch · `SUPADATA_API_KEY` (video transcripts) · `USER_DAILY_SPEND_CAP_USD` (15).

## 3.10 Not for the app (internal, legacy or admin), listed so nothing is missed

- **Agent, internal only:** `/health` (+ `/ready`, `/metrics`), `/runs` (traces, users, compare), `/ingest/{run,social-research,backfill}`, `/cook0/run`, `/integrations/{process,queue-import,test,credentials}`. Operations and the pipeline canvas use these; the app never should.
- **Backend legacy:** `/pipeline/*` (observations, insights: the old model the brain replaced), `/claude/generate` (the general prompt proxy the refresh removes: X1), `/admin`, `/graph/*` (old assertion and entity-resolution feedback; replaced by `/corrections` and `/people/held`).

## 3.11 Reusable from today's iOS app

| Piece | Where | Use in the refresh |
|---|---|---|
| Playback Live Activity | `Models/AudioPlaybackAttributes.swift`, `Views/AudioPlaybackLiveActivity.swift`, `RetrospectWidgets/RetrospectWidgetsLiveActivity.swift` | X2 now playing (add lock-screen and Control Center controls: `MPNowPlayingInfoCenter`, `MPRemoteCommandCenter`, unused today) |
| Recording Live Activity + App Intents (start/stop voice recording) | `Models/VoiceRecordingActivity.swift`, `AppIntents/` | J1 capture from the lock screen and Siri |
| Widgets + a Control | `RetrospectWidgets/` | X4 |
| Screen Time report extension | `ScreenTimeReport/` | N6/T3 Screen Time source |
| Health, calendar, contacts and other device readers | `Services/HealthKitManager.swift`, `NativeSourcesManager.swift`, `ScreenTimeService.swift`, `IntegrationsSyncService.swift` | N6 Connect, background reading |
| On-device transcription | `SpeechRecognizerManager.swift`, `Services/TranscriptionService.swift` | voice in (N4, J1); keep the confidence it throws away |
| Apple sign-in, API client, Keychain | `Services/RetrospectAPIClient.swift` | N3; the client grows the Part 7 routes |
| Background audio permission | `Info.plist` `UIBackgroundModes: audio, fetch` | already on |
| The paywall's motion and look | `Views/PodcastPaywallFlow.swift` (the 1.22 s reveal) | N12, the visual language; rebuilt to fit any phone |
| Not reused | ~57 unreachable screens, the legacy home, dev tools, `ClaudeService` prompt proxy, `OpenAIservice`, the second Xcode project | removed |

---

# 4. Gaps between the backend and a refreshed app

Numbered **K** (kept separate from audit findings). Each is resolved in Part 8.

| # | Gap | Effect if not fixed |
|---|---|---|
| K1 | **Most capabilities are agent-only.** The backend has no routes for conversation, search, briefs, corrections, people, hypotheses, actions, settings, preferences, readiness, feedback | Journal can't reply, You can't search, no brief card, no onboarding stages |
| K2 | **No route returns the read contract, said-vs-did or the map** (entities + facts sized by evidence) | You and Goals can't show the brain's picture |
| K3 | **The daily brief has no audio** | the founder's "play card that keeps playing" can't exist |
| K4 | **No timezone stored**; brief at 08:00 UTC, episode Sun 06:00 UTC | a California user gets the "morning" brief at 1 am |
| K5 | **Speech isn't streamed** (whole MP3 per request) | voice onboarding and spoken replies would pause for seconds before every turn |
| K6 | **Nothing proposes actions** | no "want me to draft that?" until a proposer exists |
| K7 | **Delete exists but isn't used and doesn't retract; edit doesn't exist.** `DELETE /content/:id` removes the entry, not the facts and answers drawn from it (the correction path that retracts them exists); the app never calls it; there's no edit | deletes don't delete (Y12), edits don't reach the brain (J3) |
| K8 | **`/content` has no idempotency key**; the app has no outbox | lost or duplicated entries (J1, J4) |
| K9 | **No share extension** and no route that saves a link with an explicit reason | goal 23's "hand it a link with a reason" only works by pasting into Journal |
| K10 | **No push delivery** (APNs) for brief ready / episode ready / a question waiting | proactive means nothing if nothing arrives |
| K11 | **No chapter timings** for episodes (the plan is stored; timestamps aren't) | "why this is here" can be shown per part, but not jumped to |
| K12 | **One first episode per person isn't enforced** | two paid episodes per sign-up (A7) |
| K13 | **No StoreKit products or receipt validation** | the paywall can't take money (L4) |
| K14 | **Consumption preference (audio / text / both) isn't stored** | the spec requires onboarding itself to respect it |
| K15 | **Only Apple Health and Google Docs can be connected today**; the rest are in development or awaiting approval. **Founder, 20 Oct: more than Google and Health must work.** Launch set: Apple Health, Calendar (device), Contacts, Screen Time, Google (Docs, Calendar, Gmail after Google's verification, YouTube), Spotify, Reddit, Apple Music, Photos; TikTok, X, LinkedIn as their approvals land | Connect (ON-6) recommends from the launch set; nothing is shown as connectable before it works |
| K16 | **What each source helps it understand isn't in the backend catalog** (the agent has full profiles) | N6's "Calendar → the shape of your weeks" copy has no source of truth in the app |
| K17 | **The three hosts are one voice** with different settings | a host picker that barely changes the sound; replaced by voice creation (P1) |
| K19 | **The backend's content types don't include link, shared link, note or conversation**, though the brief treats them as things you sent | the share extension and notes can't be sent as what they are |
| K20 | **The "how bold" first guess only runs in the daily job**, and needs 3+ things you wrote (over 20 characters each) | N9 has no guess minutes into onboarding unless the seed runs on demand from the saved answers |
| K21 | **Magic moments (titled observations from onboarding + sources) are built and never called** | the tease's opening line has a ready source, asked as a question (no pattern claims on day one) |
| K22 | **The refresh assumes the v2 planners**; v1 is the default unless the switches are set | P2's "why this is here" and the episode question, and J2's brief sections, exist only under v2; the app must handle v1 outlines until both are on for everyone |
| K23 | **Onboarding picks its next question, and knows when it knows enough** | The question store (36 canonical questions, each with a confidence) and onboarding readiness exist; nothing serves "the question that would teach the most now" or a "knows enough" signal to the app. Needed for ON-4 and ON-8 (founder's north star: the fastest questions, and moving on once ready). Build: a route that ranks unanswered canonical questions by importance × (1 − confidence), excluding what a connected source will answer, plus a readiness flag (enough for privacy/Connect; enough for a first episode) |
| K18 | **Social research (your public profiles) isn't reachable** | cold start misses an input the spec names; an optional onboarding question ("Want me to read your public profiles?") needs a route |

---

# 5. Design principles for the refresh

1. **Ambient first.** Every tab opens on something already made for you. The empty box is never the first thing you see.
2. **One feature per page**, shown off fully; the bar names the features; guidance teaches each one on first visit.
3. **Evidence → question → your answer.** Hard things are delivered as evidence plus a question, never a verdict.
4. **Stated vs asked, visibly.** Facts look like facts; guesses carry how sure and why, and are phrased as questions.
5. **Voice-first, never voice-only.** Talk or type everywhere; it talks back; it works with the sound off; it respects a stated preference for reading.
6. **Nothing lost, nothing hidden.** Every capture shows saved → sent → read; every failure says what happened and what's next.
7. **Least taken, most given.** Every question has a visible use; nothing is asked that a source will tell it.
8. **The server owns the brain.** The app sends intents; it never overwrites.
9. **Accessible and any-size by default.** Dynamic Type, VoiceOver, 44 pt targets, reduced motion, light and dark, from the SE up.
10. **Visual language:** the paywall moment (the insight plays, the buttons rise, 1.22 s); Hedvig serif with restraint; mono labels; beige + sky blue with the beige calibrated down (one hue, low even chroma); grain and rim only for special moments; dots never over text.

---

# 6. The new app, screen by screen
Same form as the problems audit: every screen of the refreshed app, with what is on it, the opportunities (O) and backend gaps (K) pinned to it, the backend behind it (✓ reachable today · ◐ built in the brain, needs a backend route · ✗ to build), its states, the audit problems it closes, and a lo-fi sketch. Work that has no screen is listed at the end. Founder, 20 Oct: one feature per page; a fully new, simple, production Settings with nothing for developers; a sign-in screen for people coming back (AC-1); more sources than Google and Health working at launch (ON-6, Phase S); a place for all your journal entries (JR-3).

| Group | Screens |
|---|---|
| Onboarding | ON-1 Welcome, ON-2 Sign in, ON-3 The conversation begins: the mission, ON-4 The conversation: your story, ON-5 Privacy, shown off, ON-6 Connect, ON-7 More sources, ON-8 The conversation continues: where you’re headed, ON-9 How straight should I be?, ON-10 Getting ready (no dead wait), ON-11 The tease: first episode plays, ON-12 The paywall (scrollable), ON-13 Home, first visit |
| Account | AC-1 Sign in (returning), AC-2 Signing out |
| Journal | JR-1 Journal, JR-2 Today’s brief (open), JR-3 All entries, JR-4 An entry |
| Podcasts | PC-1 Podcasts, PC-2 The player, PC-3 Why this is here |
| Goals | GL-1 Goals, GL-2 A goal |
| You | YO-1 You: the map, YO-2 Search results, YO-3 A source, YO-4 A node, YO-5 What I know about you, YO-6 A question waiting |
| Settings | ST-1 Settings, ST-2 Daily brief, ST-3 Sources, ST-4 A source, ST-5 Privacy, ST-6 How straight I am with you, ST-7 Voice and listening, ST-8 What I’ve learned, ST-9 Account and subscription |
| Outside the app | EX-1 Share to Retrospect, EX-2 Lock screen: now playing, EX-3 Notifications, EX-4 Widget |

## Onboarding

### ON-1. Welcome

**One feature:** Something beautiful, before anything is asked.

**On it:**
- The first thing you see on opening the app: a moving, crafted moment (the mark, grain and light; a few seconds, no text wall)
- One line of what it is: "Retrospect gets to know you, and tells you what it sees."
- Get started · "I have an account" (goes to Sign in, AC-1)
- Plays silently; no permission asks, no questions, no choices yet
- Reduced motion: a still version

**Pinned:** **Founder** north star: tap the app, see something pretty · **O-25** standard controls · **Tokens** material.grain.signature, motion.reveal

**Backend:** ✓ none needed (static, on device)  
**States:** playing · still (reduced motion)  
**Closes:** W1, W2, W4, W5

```
┌─────────────────────────┐
│                         │
│                         │
│     (the mark, lit,     │
│      grain moving)      │
│                         │
│  Retrospect gets to     │
│  know you, and tells    │
│  you what it sees.      │
│                         │
│   [  Get started  ]     │
│   I have an account     │
└─────────────────────────┘
```

### ON-2. Sign in

**One feature:** Create your account in one tap.

**On it:**
- Apple's standard Sign in with Apple
- Continue with Google (also connects Google, one approval)
- Pressed state and a spinner; plain-words errors
- Straight after: the conversation starts (ON-3)

**Pinned:** **O-25** standard controls · **ios-v2 #11** Google sign-in = connect Google · **Founder** north star: then I sign in

**Backend:** ✓ /auth/signin · ✗ Google sign-in  
**States:** idle · signing in · failed · offline  
**Closes:** W3, W6, W7, C5

```
┌─────────────────────────┐
│                         │
│      (the mark)         │
│                         │
│  Let's begin.           │
│                         │
│ [  Sign in with Apple ] │
│ [ Continue with Google ]│
│                         │
│  Privacy · Terms        │
└─────────────────────────┘
```

### ON-3. The conversation begins: the mission

**One feature:** The app speaks first: what it is for, and how you'd like to talk.

**On it:**
- The first turn of one continuous conversation that runs through all of onboarding
- Spoken in the app voice, words appearing as spoken: what Retrospect is for, under 30 seconds, every word true today
- Ends by asking: "Want to talk, or would you rather type?" Talk is preselected; switch anytime (stored as your listening preference)
- Replay · Skip · works with sound off; haptic on the key line

**Pinned:** **Founder** mission told by voice; north star: I start talking to the app · **O-19** one voice everywhere · **K14** store the listening preference · **Spec** if they prefer reading, don't speak at them · **Test** how parasocial the voice should be (see the parasocial test)

**Backend:** ✓ pre-recorded audio (same for everyone) · ✗ PUT /profile/consumption  
**States:** speaking · paused · muted (text only) · typed mode  
**Closes:** W1, W2, N8, spec gap

```
┌─────────────────────────┐
│  ◉ ∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿     │
│                         │
│ "Most of what shapes you│
│  goes unnoticed. I'm    │
│  here to notice it, and │
│  tell you what I see."  │
│                         │
│ "Want to talk, or would │
│  you rather type?"      │
│ [ ● Talk ]  [ Type ]    │
└─────────────────────────┘
```

### ON-4. The conversation: your story

**One feature:** Learn the most about you, fastest, by talking.

**On it:**
- One question at a time, spoken; you answer by voice (or type)
- Each next question is the one that would teach it the most given what you have said so far (from the question store), not a fixed list
- No fixed count: it moves on when it knows enough to make privacy and Connect personal (typically about 4 answers)
- Live transcript; haptics when listening starts, stops, and when it hands the turn back
- A real acknowledgement after each answer (proves it heard); at most one follow-up, only when it would settle a lot
- Back always; each answer saved the moment it is given; progress shown as a soft "getting to know you" line, not "3 of 4"

**Pinned:** **Founder** north star: questions that teach you about me the fastest · **O-19** voice in and out · **K5** streamed voice for quick replies · **O-21** answers saved instantly · **K23** next-best-question + "knows enough" signal

**Backend:** ◐ acknowledgements via conversation (✗ backend route) · ✗ /speech/stream · ✗ /onboarding/next-question  
**States:** listening · thinking · speaking · typed · offline (queued)  
**Closes:** V1, V2, V4, V5, V9, N6, N9, N10, O1, O2

```
┌─────────────────────────┐
│ getting to know you ··· │
│                         │
│ "What's taking up most  │
│  of your head lately?"  │
│                         │
│  ∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿    │
│  "Honestly, whether to  │
│   leave my job…"        │
│                         │
│      (  ● mic  )        │
│  ‹ Back        Type ⌨   │
└─────────────────────────┘
```

### ON-5. Privacy, shown off

**One feature:** Earn trust before asking for data.

**On it:**
- The conversation keeps going on this page: the voice ties privacy to what you just said ("you told me about your job; here is exactly what I keep")
- A strong display of the page's one purpose: what it reads, what it never does, shown big, not as small print
- Spoken callback: why it asks, what it will never do
- What it reads · where it is processed (our server, named AI providers) · what it never does
- Read in the background? (on / only what I send)
- Delete everything anytime

**Pinned:** **O-17** privacy and ambient · **O-22** plain words

**Backend:** ◐ /settings/ambient (✗ backend route)  
**States:** none  
**Closes:** D1, N13

```
┌─────────────────────────┐
│ ‹                       │
│ What I read   only what │
│               you connect
│ Where         our server│
│               + named AI│
│ Never         sold, ads │
│                         │
│ Read in the background? │
│ (● on)(○ only what I    │
│          send)          │
│ Delete everything anytime
│          [ Continue ]   │
└─────────────────────────┘
```

### ON-6. Connect

**One feature:** Connect what helps it understand you.

**On it:**
- The conversation keeps going: the page opens with why connecting helps *you* in particular, from your answers; after each connection the voice says what it can now understand, and may ask one question about it
- A strong display of the page's one purpose: each source as a big card showing what it would let Retrospect understand about you
- Recommends up to 5 from the launch set, each with what it lets it understand: Apple Health, Calendar (on the phone), Contacts, Screen Time, Google (Docs, Calendar, Gmail, YouTube in one card)
- The launch set must all work (founder, 20 Oct: more than Google and Health); a source is never shown as connectable before it works
- One Google card
- Plain states: Connected · read just now / Couldn’t connect, try again
- "Not now" per source; More sources ›
- Starts reading for your first episode

**Pinned:** **O-17** sources · **K15** launch set must work: today only Health and Google Docs do · **K16** source descriptions in the catalog · **K12** one first episode per person · **Switch** ENABLE_ONBOARDING_PIPELINE

**Backend:** ✓ /integrations · ◐ readiness/advance · ✗ one-episode guard  
**States:** connecting · connected · failed · denied · skipped  
**Closes:** C1–C10, N14, N15, N16, A7, Y52

```
┌─────────────────────────┐
│ ‹                       │
│ "These let me see what  │
│  words can't."          │
│ ┌─────────────────────┐ │
│ │♥ Health → your sleep│ │
│ │  and energy       ✓ │ │
│ ├─────────────────────┤ │
│ │▦ Calendar → shape of│ │
│ │  your weeks  [Add]  │ │
│ ├─────────────────────┤ │
│ │G Google → mail, docs│ │
│ │  calendar    [Add]  │ │
│ └─────────────────────┘ │
│ More sources ›          │
│           [ Continue ]  │
└─────────────────────────┘
```

### ON-7. More sources

**One feature:** Everything else you can connect, explained.

**On it:**
- Grouped: your phone · your accounts · files you already have · your public profiles (optional: "Want me to read your public profiles?" with handles)
- Each shows its real state: ready, coming soon, or needs approval
- Each: what it adds, and how (one tap, or how to export a file)
- File imports explained step by step (ChatGPT, Claude, Netflix, YouTube history)

**Pinned:** **O-17** sources · **Imports** YouTube Takeout, archives · **K18** social research route · **K15** Spotify, Reddit, Apple Music, Photos at launch; TikTok, X, LinkedIn as approvals land

**Backend:** ✓ /integrations imports and assets  
**States:** as ON-6  
**Closes:** C4, C8, N15

```
┌─────────────────────────┐
│ ‹ More sources          │
│ YOUR PHONE              │
│  Screen Time · Music ·  │
│  Photos · Contacts      │
│ YOUR ACCOUNTS           │
│  Spotify · Reddit · …   │
│ FILES YOU HAVE          │
│  ChatGPT history  How ›  │
│  YouTube history  How ›  │
└─────────────────────────┘
```

### ON-8. The conversation continues: where you’re headed

**One feature:** Keep talking until it knows enough to make your first episode.

**On it:**
- Same voice and controls as ON-4; questions now informed by what you connected (never asks what a source will say)
- Goals and aspirations, asked to inspire: what you want out of life, what you are working toward
- Also asked here as turns in the conversation, not separate screens: how straight to be with you (ON-9) and "want a short brief each morning?" (with a time; off unless you say yes)
- Stops when it is ready: the readiness check says it knows enough for a first episode worth hearing (bounded: never fewer than about 6 answers in all, never more than about 14 turns)
- Keeps going while the episode is being made (ON-10), so there is no dead wait

**Pinned:** **Founder** north star: continuing asking the questions… once we feel we are ready · **Founder** inspiring goals questions · **Goal 24** cold start · **O-3** brief opt-in as a question · **K4** local time, guessed from the calendar, confirmed here · **K23** "knows enough" signal · **Readiness** reading → understanding → making_episode → ready

**Backend:** ◐ /onboarding/goals, /onboarding/readiness (✗ backend routes) · ◐ /briefs/enabled (✗ backend route) · ✗ /profile/timezone  
**States:** as ON-4 · ready  
**Closes:** V3, V4, A3, Y1

```
┌─────────────────────────┐
│ getting to know you ····│
│                         │
│ "If this year went      │
│  really well, what would│
│  be different?"         │
│                         │
│  ∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿    │
│                         │
│      (  ● mic  )        │
│  ‹ Back        Type ⌨   │
└─────────────────────────┘
```

### ON-9. How straight should I be?

**One feature:** Set how bold it is with you (a turn in the conversation, with a visual choice).

**On it:**
- Asked by voice inside the conversation; the four levels appear as a choice
- Its first guess preselected, with the reason from your words
- One tap or one word to change; changeable later

**Pinned:** **O-16** how bold · **K20** guess made on the spot from saved answers · **Switch** ENABLE_APPETITE

**Backend:** ◐ /settings/appetite with suggested (✗ backend route)  
**States:** none  
**Closes:** goal 22

```
┌─────────────────────────┐
│ "How straight should I  │
│  be with you?"          │
│ ○ Just what happened    │
│ ○ Gentle questions      │
│ ● Honest observations   │
│ ○ Don't hold back       │
│ "You said you want to be│
│  challenged."           │
│          [ Continue ]   │
└─────────────────────────┘
```

### ON-10. Getting ready (no dead wait)

**One feature:** Your first episode is made while the conversation carries on.

**On it:**
- The conversation keeps going (ON-8) while the episode is made; a small, honest line shows the real stage: reading your calendar ✓ · writing · recording the voice
- When it is ready, the voice says so and moves to the tease (ON-11)
- If you stop answering: a line from your own words, the stages, and "close the app and I'll tell you when it's ready"
- No percentage; nothing canned

**Pinned:** **Founder** north star: once we feel we are ready, we show the tease · **O-22** honest waits · **Readiness** reading → understanding → making_episode → ready · **K21** magic moments for the line it shows · **K12** one first episode per person

**Backend:** ◐ /onboarding/readiness, /advance (✗ backend routes)  
**States:** talking while making · quiet wait · ready · failed (plain words, retry or tonight) · slow  
**Closes:** A1, A3, A5, N1, N3, N4, N23, Y44

```
┌─────────────────────────┐
│ writing your episode ◌  │
│                         │
│ "One more while I put it│
│  together: who do you   │
│  call when things go    │
│  well?"                 │
│                         │
│  ∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿    │
│      (  ● mic  )        │
└─────────────────────────┘
```

### ON-11. The tease: first episode plays

**One feature:** The first thing it gives back.

**On it:**
- A spoken callback first: "here is the first thing I noticed; it is narrow, because it is day one"
- Your real episode plays; transcript follows the voice
- Honest about how little it knows yet

**Pinned:** **O-24** audio that plays · **Goal 24** something true you recognise · **K21** opening line asked, not stated

**Backend:** ✓ /podcasts (stream the audioUrl)  
**States:** playing · buffering · failed  
**Closes:** E1, L2, N20, N21

```
┌─────────────────────────┐
│ "Here's the first thing │
│  I noticed."            │
│                         │
│ ─ The week you started ─│
│ "…three of your best    │
│  days began before 8…"  │
│                         │
│ ━━━━━○───────── 0:31    │
│      ↺15   ‖   15↻      │
└─────────────────────────┘
```

### ON-12. The paywall (scrollable)

**One feature:** Choose to subscribe, seeing everything you get.

**On it:**
- At the strongest line the episode slides up into a mini player (1.22 s reveal)
- Monthly / Yearly (real prices; yearly says what it saves) · Not now
- Scroll: every benefit, each with an example from your data where one exists
- Restore · Privacy · Terms; fits any phone

**Pinned:** **O-29** real subscriptions · **K13** StoreKit + receipts · **Founder** scrollable with every benefit

**Backend:** ✗ /subscriptions/verify + StoreKit  
**States:** loading prices · purchasing · purchased · failed · restored  
**Closes:** N19, L3, L4, L5, Y41

```
┌─────────────────────────┐
│ ▶ episode (mini)  0:38  │
│ "Hear the rest, and one │
│  every week."           │
│ [ Monthly ][ Yearly −2m]│
│ Not now                 │
│ ── scroll ───────────── │
│ ◇ A brief every morning │
│ ◇ An episode every week │
│ ◇ Ask your own mind     │
│ ◇ Goals: said vs did    │
│ ◇ Talk to it anytime    │
│ Restore · Privacy · Terms│
└─────────────────────────┘
```

### ON-13. Home, first visit

**One feature:** Land on the home page with everything in reach, and a little guidance.

**On it:**
- Straight after the paywall: Journal, with today's brief card on top (if you said yes) and your first episode where you left it
- Guidance, once, in place: "Press play for your brief" · "Search your mind in You" · "Talk to me here, anytime" · Podcasts and Goals pointed at; each dismissible; never again after
- No extra setup screens between the paywall and home

**Pinned:** **Founder** north star: then we take them to the homepage: briefs, search their mind, everything else · **Founder** guidance inside the app · **O-3** brief card

**Backend:** ✓ local (guidance shown once)  
**States:** first visit · guidance dismissed  
**Closes:** A3, Y1

```
┌─────────────────────────┐
│ Journal                 │
│ ┌─────────────────────┐ │
│ │ ▶ Today's brief  2m │ │
│ └─────────────────────┘ │
│  ↑ Press play for your  │
│    brief                │
│                         │
│ Tell me… 🎙             │
│ Journal Podcasts Goals You│
│                    ↑ search your mind
└─────────────────────────┘
```

## Account

### AC-1. Sign in (returning)

**One feature:** Get back into your account: new phone, signed out, or session expired.

**On it:**
- Shown whenever there is no valid session after onboarding: a new phone, after Sign out, after deleting the app, or when the session expires and can’t be renewed
- Sign in with Apple (standard button) · Continue with Google
- “New here? Get started” goes to onboarding (ON-1, Welcome)
- After signing in: your data comes back (entries, episodes, goals, sources) and you land where you were; no onboarding again
- Expired session: renewed silently first; this screen only if renewal fails, with one plain line why
- Errors in plain words (offline, cancelled, account not found)

**Pinned:** **Founder** a sign-in / auth screen · **O-25** one sign-in, standard controls · **Q1** replaces the second gate that repeated the welcome page

**Backend:** ✓ /auth/signin, /auth/refresh · ✗ Google sign-in · ✗ restore-on-sign-in (re-download entries and episodes)  
**States:** idle · signing in · restoring your data · failed · offline  
**Closes:** Q1, W3, W7, A4

```
┌─────────────────────────┐
│                         │
│      (the mark)         │
│                         │
│  Welcome back.          │
│                         │
│ [  Sign in with Apple ] │
│ [ Continue with Google] │
│                         │
│ New here? Get started › │
└─────────────────────────┘
```

### AC-2. Signing out

**One feature:** Leave cleanly, and know what stays.

**On it:**
- From Settings → Account: “Sign out”
- Says plainly: your data stays in your account; this phone forgets it
- Unsent entries warned about before signing out (send now or keep)
- Lands on Sign in (AC-1)

**Pinned:** **O-21** nothing lost · **Founder** auth

**Backend:** ✓ local sign out · outbox flush  
**States:** unsent entries · signing out  
**Closes:** —

```
┌─────────────────────────┐
│ Sign out?               │
│ Your entries and        │
│ episodes stay in your   │
│ account. This phone     │
│ forgets them.           │
│ 1 entry not sent yet:   │
│ [ Send, then sign out ] │
│   Cancel                │
└─────────────────────────┘
```

## Journal

### JR-1. Journal

**One feature:** Say what’s on your mind, and hear back.

**On it:**
- Today’s brief card on top: ▶ press play, it briefs you, keeps playing when you close the app
- Today’s thread: your entries and its replies; each entry shows saved → sent → read
- Replies are short, sometimes none; guesses asked as questions
- Waiting on you: only what came out of this thread (a correction to confirm, an action to approve once actions exist); “same person?” and what it’s wondering live on You (YO-6)
- Composer: Tell me… with the mic first; drafts kept, never auto-sent
- “All entries” at the top right

**Pinned:** **O-1** capture · **O-2** conversation · **O-3** brief card · **O-21** outbox · **K3** brief audio · **K8** idempotency

**Backend:** ✓ /content · ✗ backend: /conversation, /briefs, /corrections · ✗ brief audio  
**States:** first visit · nothing today · brief making · brief quiet · offline (queued) · server failing (named) · ambient off  
**Closes:** Y1, Y2, Y4, Y5, Y6, Y28, Y29, J1, J2, L6, L7

```
┌─────────────────────────┐
│ Journal      All entries│
│ ┌ Your brief ──────── ┐ │
│ │ ▶ 3 things · 2 min  │ │
│ └─────────────────────┘ │
│ You: slept badly, long  │
│ day of meetings  ✓ read │
│ Retrospect: Third Monday│
│ like that. What's       │
│ different about Mondays?│
│ ┌─────────────────────┐ │
│ │ Tell me…      🎙 ↑  │ │
│ └─────────────────────┘ │
│[Journal] Podcasts Goals You
└─────────────────────────┘
```

### JR-2. Today’s brief (open)

**One feature:** Read or replay today’s brief.

**On it:**
- The through-line, then each item with why it is here and the quote behind it
- Play / pause; keeps playing in the background
- A quiet day says so in one line
- “That’s not right” on any item

**Pinned:** **O-3** brief · **O-10** corrections · **Goal 11** every item says why · **K22** sections need the v2 brief

**Backend:** ◐ /briefs/latest (✗ backend route) · ✗ brief audio  
**States:** playing · played · quiet · not made yet  
**Closes:** —

```
┌─────────────────────────┐
│ ⌄ Tuesday's brief  ▶ 2m │
│ "A heavier week than    │
│  usual, and it shows."  │
│ 1 Four meetings before  │
│   noon. Why: you said   │
│   mornings are for      │
│   thinking. "…" ›       │
│ 2 The fundraise article │
│   you saved. Why: …     │
│            ✕ not right  │
└─────────────────────────┘
```

### JR-3. All entries

**One feature:** Everything you’ve written or said, in one place.

**On it:**
- By day, newest first; your own words first, not a date title
- Written and voice, with a small mark for each; voice entries play
- Search your entries; filter written / voice / with links
- Each shows saved → sent → read; failed ones retry with one tap

**Pinned:** **Founder** a place for your entries · **O-21** states · **K7** edit/delete reach the brain

**Backend:** ✓ GET /content · ✗ edit/delete routes  
**States:** empty (warm) · loading · offline (local copy) · some unsent  
**Closes:** Y7, Y9, Y15, J4

```
┌─────────────────────────┐
│ ‹ All entries      ⌕    │
│ All · Written · Voice   │
│ TODAY                   │
│  Slept badly, long day… │
│                 ✓ read  │
│ MONDAY                  │
│  🎙 On the walk home I… │
│                 ✓ read  │
│  "need to call mum"     │
│              ↻ sending  │
│ LAST WEEK               │
│  …                      │
└─────────────────────────┘
```

### JR-4. An entry

**One feature:** Read, change or remove one thing you said.

**On it:**
- Your words first, large; the date small under them
- Edit (the brain re-reads it) · Delete (removed from the brain too: the entry via the existing DELETE /content/:id, and what was drawn from it via the correction path), with confirmation
- What I took from this: the facts it drew, each with ✕ not right
- Swipe from the edge to go back

**Pinned:** **K7** edit/delete · **O-10** corrections · **O-25** swipe back

**Backend:** ✓ DELETE /content/:id (+ ✗ retract what was drawn) · ✗ PATCH /content/:id · ◐ /corrections  
**States:** saved · sending · read · failed  
**Closes:** Y9, Y10, Y11, Y12, J3

```
┌─────────────────────────┐
│ ‹                ⋯ Edit │
│ Slept badly, long day of│
│ meetings, felt flat.    │
│ Mon 20 Oct · 2:27 pm    │
│ ── What I took ──────── │
│ · sleep was poor      ✕ │
│ · meetings drain you  ✕ │
│                         │
│        Delete entry     │
└─────────────────────────┘
```

## Podcasts

### PC-1. Podcasts

**One feature:** Listen to what it made for you.

**On it:**
- This week’s episode as the hero: real title, length, what it covers
- Today’s brief beside it
- Earlier episodes and briefs, newest first
- Pull to refresh; refreshes when you open the tab

**Pinned:** **O-4** episodes · **O-24** audio that plays · **O-30** new-episode notice

**Backend:** ✓ /podcasts (list, latest, get)  
**States:** first episode only · making this week’s · quiet week · failed (named) · offline (downloaded play)  
**Closes:** Y22, Y23, Y24, Y25, Y30, Y31, L8

```
┌─────────────────────────┐
│ Podcasts                │
│ ┌ This week ──────────┐ │
│ │ The week you stopped│ │
│ │ rushing · 12 min  ▶ │ │
│ └─────────────────────┘ │
│ Today's brief · 2 min ▶ │
│ EARLIER                 │
│ What the Sunday calls…▶ │
│ Your first episode    ▶ │
│Journal[Podcasts]Goals You
└─────────────────────────┘
```

### PC-2. The player

**One feature:** Listen to one episode, and understand it.

**On it:**
- Title, date, length; transcript following the voice; speed
- “Why this is here” for each part (from the stored plan: evidence; stated vs asked); shown only for v2 episodes (older outlines show the transcript alone)
- Its one question: Yes / No / Why do you think that?
- A word of feedback; keeps playing in the background; swipe down to close

**Pinned:** **O-5** feedback and the question · **O-13** hypotheses · **K11** chapter timings · **K22** needs the v2 planner

**Backend:** ✓ /podcasts/:id (outline = plan) · ✗ backend: /feedback, /hypotheses  
**States:** playing · buffering · offline · failed · older episode (no plan: transcript only)  
**Closes:** Y26, Y27, Y45, N20, N21, R3

```
┌─────────────────────────┐
│ ⌄                1x  ⋯  │
│ The week you stopped    │
│ rushing                 │
│ "…three of your best    │
│  days began before 8…"  │
│ Why this is here ›      │
│ ━━━━━○───────── 4:12    │
│     ↺15    ‖    15↻     │
│ ┌ It's wondering ─────┐ │
│ │ Are mornings when you│ │
│ │ do your best work?   │ │
│ │ [Yes][No][Why ask?]  │ │
│ └─────────────────────┘ │
└─────────────────────────┘
```

### PC-3. Why this is here

**One feature:** The evidence behind one part of an episode.

**On it:**
- What this part says, stated or asked
- The evidence: entries, events, health days, with dates
- For the question: the framework it comes from and what it rests on
- ✕ not right on any line

**Pinned:** **Plan** stored outline · **O-10** corrections · **Goal 21** why do you think that

**Backend:** ✓ outline on /podcasts/:id · ◐ /hypotheses/:id/why  
**States:** none  
**Closes:** goal 13, 21

```
┌─────────────────────────┐
│ ⌄ Why this is here      │
│ Said: your best days    │
│ start early (stated)    │
│ · 14 Oct · up at 6:40   │
│ · 16 Oct · "felt sharp" │
│ · 17 Oct · run at 7     │
│               ✕ not right
└─────────────────────────┘
```

## Goals

### GL-1. Goals

**One feature:** What you’re working toward, as it sees it.

**On it:**
- Active goals, each with said vs did in two plain numbers
- A small trajectory, or “too early to tell”
- Faded (unmentioned 90 days) and merged, below, revivable
- Add by voice or text (+)

**Pinned:** **O-6** goals · **O-23** server owns goals · **K2** said-vs-did route

**Backend:** ✓ /goals (intents only) · ✗ said-vs-did + lifecycle view  
**States:** none yet · too early · server failing  
**Closes:** G1, G2, G3, Y17, Y18, Y19, Y20, Y21

```
┌─────────────────────────┐
│ Goals               +   │
│ ┌ Ship the first ver. ┐ │
│ │ said 6× · did 4h/wk │ │
│ │ usual 2h  ▁▃▅ more  │ │
│ └─────────────────────┘ │
│ ┌ Sleep before 12 ────┐ │
│ │ said 3× · did 1 night│ │
│ └─────────────────────┘ │
│ Faded 2 · Merged 1    › │
│Journal Podcasts[Goals]You
└─────────────────────────┘
```

### GL-2. A goal

**One feature:** Everything behind one goal.

**On it:**
- Said: when you first said it, last mentioned
- Did: the events, content and patterns that served it, with dates
- Rename · turn off · revive; ✕ not right on any item
- Goals heard in what you say are proposed, never assumed

**Pinned:** **O-6** goals · **O-10** corrections

**Backend:** ✗ said-vs-did route · ✓ /goals update  
**States:** none  
**Closes:** G3

```
┌─────────────────────────┐
│ ‹ Ship the first version│
│ Said · 6 Oct, last Mon  │
│ Did this week · 4h      │
│ · Tue 2h "deep work"    │
│ · Thu demo w/ Priya     │
│ · pattern: late nights  │
│                ✕ not right
│ Rename · Turn off       │
└─────────────────────────┘
```

## You

### YO-1. You: the map

**One feature:** See the picture it has of you, and ask it anything.

**On it:**
- Search field (mic first) on top
- The map: people, places, projects, topics, goals, habits, emotions, sized by how much they show up (people by their significance score: recent, weighted, fading over 60 days), joined by facts
- Opens on the strongest dozen; zoom for more; clusters are patterns
- Nodes waiting for you glow quietly (same person? / wondering)
- Your picture top-left opens Settings; a list view for VoiceOver

**Pinned:** **O-7** search · **O-8** the map · **O-11/12/13** patterns, people, wondering · **K2** map route

**Backend:** ✗ /understanding/map · ✗ backend: /search, /people/held, /hypotheses  
**States:** day one (thin, said so) · loading · offline (last map) · failing  
**Closes:** —

```
┌─────────────────────────┐
│ (pic)       You         │
│ ┌ Ask anything ─── 🎙 ┐ │
│ └─────────────────────┘ │
│       ◯ Priya           │
│  ●──────⬤ Work          │
│ Sleep●     \            │
│       ◯ Sam? ← waiting  │
│   ●Running  ⬤ Ship v1   │
│ What I know about you › │
│Journal Podcasts Goals[You]
└─────────────────────────┘
```

### YO-2. Search results

**One feature:** An answer from your own mind, with its receipts.

**On it:**
- Sources first (~1 s), lighting their part of the map
- Then what it found: 2–5 sentences, every claim numbered to a source; facts and guesses labelled
- Or a plain “nothing answers this” with what the sources do show
- Only what’s certain (filter); open any source; ✕ not right on any line

**Pinned:** **O-7** search · **Goal 6** receipts, abstains

**Backend:** ◐ /search/sources, /answer, /source (✗ backend routes)  
**States:** searching · found · abstained · offline · failing  
**Closes:** —

```
┌─────────────────────────┐
│ ‹ "when do I sleep best"│
│ What I found            │
│ After days you run [1], │
│ and when work stops     │
│ before 9 [2].  ✕        │
│ □ only what's certain   │
│ SOURCES                 │
│ [1] Health · 14 nights ›│
│ [2] Journal · 3 entries›│
└─────────────────────────┘
```

### YO-3. A source

**One feature:** One thing you said, did or saved, in full.

**On it:**
- The entry, event, fact, answer or saved link, in full
- Where it came from and when
- For a saved link: your reason, and the transcript for videos

**Pinned:** **Goal 6** open any source · **O-14** saved links

**Backend:** ◐ /search/source/:kind/:id (✗ backend route)  
**States:** loading · not found  
**Closes:** —

```
┌─────────────────────────┐
│ ‹ Journal · 14 Oct      │
│ "Went to bed at 10 for  │
│  once, woke up before   │
│  the alarm…"            │
│ Source: your journal    │
└─────────────────────────┘
```

### YO-4. A node

**One feature:** Everything it knows about one thing, and why.

**On it:**
- What it believes, how sure (●●●○), the quotes behind it, when it last moved
- Still true · Not right (changed then, or wrong)
- Linked nodes; for a person, same person?; for a goal, said vs did; saved links tied to it

**Pinned:** **O-10** corrections · **O-12** people · **O-14** saved links

**Backend:** ◐ /corrections, /people/held · ✗ node detail in map route  
**States:** none  
**Closes:** —

```
┌─────────────────────────┐
│ ⌄  Priya                │
│ Comes up 14× this month │
│ A close colleague; you  │
│ feel lighter after      │
│ talking   fairly sure ●●●○
│ "coffee w/ Priya, felt  │
│  lighter" · 12 Oct      │
│ [Still true][Not right] │
│ Linked: Work · Ship v1  │
└─────────────────────────┘
```

### YO-5. What I know about you

**One feature:** Its answers to the 36 questions about you.

**On it:**
- By area of life; each answer with how sure and the evidence count
- Tap for the quotes; Still true / Not right
- Areas it is silent on, said warmly (“I don’t know much about your days yet”)
- What moved since last week

**Pinned:** **O-9** 36 answers · **K2** read-contract route · **Goal 10** admits what it doesn’t know

**Backend:** ✗ GET /understanding (read contract)  
**States:** thin (day one) · loading · offline  
**Closes:** —

```
┌─────────────────────────┐
│ ‹ What I know about you │
│ WORK                    │
│ What drives you most?   │
│ Building things people  │
│ use. fairly sure ●●●○ › │
│ HEALTH                  │
│ I don't know much about │
│ your health yet.        │
│ MOVED THIS WEEK  2 ›    │
└─────────────────────────┘
```

### YO-6. A question waiting

**One feature:** Answer one thing it is unsure of.

**On it:**
- “Is the Sam in your writing Sam Ortiz from your contacts?” Same / Different
- or a hypothesis: the question, Yes / No / Why do you think that?
- One at a time; never a pile

**Pinned:** **O-12** people · **O-13** hypotheses · **Dial** speak off by default

**Backend:** ◐ /people/held, /hypotheses (✗ backend routes)  
**States:** none waiting  
**Closes:** —

```
┌─────────────────────────┐
│ ⌄ One question          │
│ Is the Sam in your      │
│ writing Sam Ortiz from  │
│ your contacts?          │
│ [ Same ] [ Different ]  │
│ Not sure                │
└─────────────────────────┘
```

## Settings

### ST-1. Settings

**One feature:** Control, in one calm list.

**On it:**
- YOUR BRIEF · Daily brief (on/off, time)
- LISTENING · Voice · Talk or read
- YOU · How straight I am with you · What I’ve learned
- SOURCES · Connected sources (n · 1 needs attention)
- PRIVACY · Background reading · Download my data · Delete my data
- ACCOUNT · Subscription · Sign out · Delete account
- HELP · Contact us · Privacy policy · Terms
- Nothing for developers

**Pinned:** **Founder** a production settings, simple, nothing dev · **O-17/18** control and transparency · **O-28** no dev tools

**Backend:** ✓ /integrations, /profile · ✗ backend: /settings/*, /briefs/enabled, /preferences, account delete  
**States:** none  
**Closes:** T1–T6, L9, L10, L11, L13, K4

```
┌─────────────────────────┐
│ ‹ Settings              │
│ YOUR BRIEF              │
│  Daily brief   8:30 On ›│
│ LISTENING               │
│  Voice         Warm    ›│
│  Talk or read  Talk    ›│
│ YOU                     │
│  How straight  Honest  ›│
│  What I've learned     ›│
│ SOURCES  4 · 1 needs   ›│
│ PRIVACY                ›│
│ ACCOUNT                ›│
│ HELP                   ›│
└─────────────────────────┘
```

### ST-2. Daily brief

**One feature:** When, and whether, your brief arrives.

**On it:**
- On / off
- Time (your local time)
- Typical length (short / standard / long, capped at 12 min)
- Preview today’s

**Pinned:** **O-3** brief · **K4** local time

**Backend:** ◐ /briefs/enabled · ✗ timezone + time  
**States:** none  
**Closes:** L6

```
┌─────────────────────────┐
│ ‹ Daily brief           │
│ Each morning      ( on )│
│ Time          8:30 am › │
│ Length   ● Standard     │
│          ○ Short ○ Long │
│ Play today's ▶          │
└─────────────────────────┘
```

### ST-3. Sources

**One feature:** What you’ve connected, and how it’s going.

**On it:**
- Each: connected, last read, what it’s for
- Needs attention says exactly what to do (Reconnect)
- Add a source from the full launch set; coming-soon sources marked; file imports with how-to
- Each source opens ST-4

**Pinned:** **O-17** sources · **O-22** plain states

**Backend:** ✓ /integrations  
**States:** connected · needs attention · expired · syncing  
**Closes:** Y32, Y33, Y34, Y35, L14, C6

```
┌─────────────────────────┐
│ ‹ Sources               │
│ Google   read 2 min ago›│
│ Health   read today    ›│
│ Spotify  ⚠ Reconnect   ›│
│ Calendar read today    ›│
│ + Add a source          │
│ Import a file          ›│
└─────────────────────────┘
```

### ST-4. A source

**One feature:** One source: what it reads, and control over it.

**On it:**
- What it reads and what it helps it understand
- Last read; Sync now
- Disconnect (with confirmation) · Delete what it read (with confirmation)

**Pinned:** **O-17** sources · **Safety** confirm before disconnect

**Backend:** ✓ /integrations/connections/:id/{sync, delete-data}, DELETE  
**States:** syncing · failed · disconnected  
**Closes:** Y32

```
┌─────────────────────────┐
│ ‹ Google                │
│ Reads: mail, docs,      │
│ calendar, YouTube       │
│ Helps me see: your work │
│ and your weeks          │
│ Last read 2 min ago     │
│ Sync now                │
│ Disconnect…             │
│ Delete what it read…    │
└─────────────────────────┘
```

### ST-5. Privacy

**One feature:** What it reads, where, and how to stop it.

**On it:**
- Background reading on / only what I send (with what changes)
- Where your data is processed (named)
- Download my data · Delete my data (confirm)

**Pinned:** **O-17** privacy · **Ambient** switch

**Backend:** ◐ /settings/ambient · ✗ export, delete  
**States:** none  
**Closes:** D1

```
┌─────────────────────────┐
│ ‹ Privacy               │
│ Read in the background  │
│  ( on )  Only what I    │
│          send ○         │
│ Where it's processed  › │
│ Download my data      › │
│ Delete my data…         │
└─────────────────────────┘
```

### ST-6. How straight I am with you

**One feature:** How bold it may be.

**On it:**
- The four levels; its current reading and why
- Your choice outranks its guess; “let it decide” hands back

**Pinned:** **O-16** how bold

**Backend:** ◐ /settings/appetite  
**States:** none  
**Closes:** goal 22

```
┌─────────────────────────┐
│ ‹ How straight          │
│ ○ Just what happened    │
│ ○ Gentle questions      │
│ ● Honest observations   │
│ ○ Don't hold back       │
│ I picked this because…  │
│ Let it decide           │
└─────────────────────────┘
```

### ST-7. Voice and listening

**One feature:** How it sounds, and how you take things in.

**On it:**
- Voice (with a sample) from a small set of real, different voices; when voice creation exists (the founder's ask: a voice made for you from a short conversation), it becomes an onboarding step after ON-8 and lives here after
- Talk or read (onboarding and replies)
- Playback speed default

**Pinned:** **O-19** voice · **K14** listening preference · **K17** one voice behind three hosts

**Backend:** ✓ /profile/persona · ✗ consumption  
**States:** none  
**Closes:** P1, P2, L9

```
┌─────────────────────────┐
│ ‹ Voice and listening   │
│ Voice   Warm  ▶ sample  │
│ Talk or read   ● Talk   │
│ Speed          1x     › │
└─────────────────────────┘
```

### ST-8. What I’ve learned

**One feature:** How it is learning to ask you better.

**On it:**
- Which kinds of questions you answer, and how often
- Plain words; read only

**Pinned:** **O-18** transparency · **Switch** ENABLE_LEARNING

**Backend:** ◐ /settings/learning  
**States:** too early  
**Closes:** goal 19

```
┌─────────────────────────┐
│ ‹ What I've learned     │
│ You answer questions    │
│ about work most (8/10)  │
│ and skip ones about     │
│ family (1/5), so I ask  │
│ those less.             │
└─────────────────────────┘
```

### ST-9. Account and subscription

**One feature:** Your plan, and your account.

**On it:**
- Plan, renewal date; Manage (Apple) · Restore
- Sign out (AC-2)
- Delete account (confirm; explains what is removed)

**Pinned:** **O-29** subscriptions · **App Review** account deletion required

**Backend:** ✗ StoreKit · ✗ account deletion  
**States:** none  
**Closes:** L4

```
┌─────────────────────────┐
│ ‹ Account               │
│ Yearly · renews 3 Mar   │
│ Manage subscription   › │
│ Restore purchases       │
│ Sign out                │
│ Delete account…         │
└─────────────────────────┘
```

## Outside the app

### EX-1. Share to Retrospect

**One feature:** Save anything, with your reason.

**On it:**
- From any app’s share sheet
- Why are you saving this? (voice or text)
- Goes with a goal if one fits
- Video transcripts fetched automatically

**Pinned:** **O-31** share · **K9** save-link route · **K19** link and note content types · **Switch** SUPADATA_API_KEY

**Backend:** ✗ share extension + POST /saved  
**States:** saving · saved · offline (queued)  
**Closes:** —

```
┌─────────────────────────┐
│ Save to Retrospect      │
│ youtube.com/… "How to…" │
│ Why are you saving this?│
│ ┌──────────────── 🎙 ┐  │
│ └────────────────────┘  │
│ Goes with: Ship v1  ▾   │
│              [ Save ]   │
└─────────────────────────┘
```

### EX-2. Lock screen: now playing

**One feature:** Keep listening without the app open.

**On it:**
- Title and artwork; play, pause, skip 15
- A now-playing Live Activity for the brief and episodes

**Pinned:** **O-24** background playback · **O-32** Live Activity

**Backend:** app: playback Live Activity exists; add lock-screen controls (background audio already allowed)  
**States:** playing · paused  
**Closes:** N20, Y26

```
┌─────────────────────────┐
│        9:02             │
│ ┌─────────────────────┐ │
│ │ Retrospect          │ │
│ │ Tuesday's brief     │ │
│ │ ↺15    ‖    15↻     │ │
│ └─────────────────────┘ │
└─────────────────────────┘
```

### EX-3. Notifications

**One feature:** Tell you when something is ready, then get out of the way.

**On it:**
- Your brief is ready (if on) · This week’s episode is here · One question waiting (at most one a day)
- Each opens the right screen; nothing at night

**Pinned:** **O-30** notifications · **K10** APNs · **K4** local time

**Backend:** ✗ APNs + device tokens · ◐ /notifications/generate  
**States:** none  
**Closes:** A6, L11

```
┌─────────────────────────┐
│ ┌ RETROSPECT ─── now ─┐ │
│ │ This week's episode │ │
│ │ is here: "The week  │ │
│ │ you stopped rushing"│ │
│ └─────────────────────┘ │
└─────────────────────────┘
```

### EX-4. Widget

**One feature:** Talk to it, or play today’s brief, in one tap.

**On it:**
- Small: 🎙 Tell me…
- Medium: today’s brief ▶ + 🎙

**Pinned:** **O-32** widget

**Backend:** app only  
**States:** brief ready · not yet  
**Closes:** —

```
┌───────────┐┌───────────┐
│ Retrospect││ Your brief│
│    🎙     ││ ▶ 2 min   │
│ Tell me…  ││    🎙     │
└───────────┘└───────────┘
```

## No screen (and that’s fine)

| | What |
|---|---|
| **K1** | Backend pass-through routes for conversation, corrections, briefs, search, people, hypotheses, actions, settings, preferences, onboarding, feedback |
| **K2** | New reads: /understanding (read contract), /understanding/map, /goals/said-vs-did |
| **K3** | Brief audio: voice the through-line and items, stored like episode audio |
| **K4** | Timezone stored; brief and episode scheduled in local time (today 08:00 and Sun 06:00 UTC) |
| **K5** | Streamed voice, so spoken replies start in under a second |
| **K6** | An action proposer (from your own words only) feeding the existing approval ledger; the Journal slot waits for it |
| **K7** | Entry edit and delete that reach the brain (re-read, retract) |
| **K8** | Idempotency key on /content; an outbox in the app |
| **K10** | Push: APNs device tokens and delivery |
| **K11** | Chapter timings for episodes |
| **K12** | One first episode per person, enforced on the server |
| **K13** | StoreKit products and server-checked receipts |
| **K14** | Listening preference (talk / read) stored |
| **K16** | Source descriptions (what each helps it understand) added to the backend catalog from the agent profiles |
| **K4+** | A first guess at timezone from the calendar (usualOffset), confirmed in ON-13 |
| **K19–K22** | Content types for links and notes; the bold-guess seed on demand; magic moments wired to the tease; EPISODE_PLANNER and DAILY_PLANNER set to v2 for everyone |
| **Switch** | Flip as phases land: EPISODE_PLANNER=v2, DAILY_PLANNER=v2, ENABLE_ONBOARDING_PIPELINE, ENABLE_MATERIAL_ARRIVALS, ENABLE_DAILY_BRIEF, ENABLE_APPETITE, ENABLE_LEARNING, ENABLE_INTEGRATION_RUNTIME, hypothesis dial, SUPADATA_API_KEY |
| **Lint** | Stale or unsupported claims stay hidden until resolved (already runs daily; nothing to show) |
| **Spend** | $15 per person per day ceiling on episodes (already on) |
| **O-26** | Accessibility everywhere: Dynamic Type, VoiceOver labels, 44 pt targets, reduced motion, light and dark |
| **O-27** | Layout that fits any phone, SE to Pro Max |
| **O-28** | No developer tools in the shipped app; a server-side staff role for the team; demo content only in the demo account |
| **Perf** | No 60-times-a-second state updates on the main thread; no large blurs on scrolling text; check on an older phone |
| **Delete** | The ~57 unreachable screens and the second Xcode project are removed |

### Onboarding: failure paths and cost

**Failure paths (every one named):** the episode isn't ready in time → "It's taking longer; I'll tell you when it's ready" + notification, onboarding still completes; generation fails → plain words, answers kept, retry or "tonight"; no sources connected → it still makes something true from the answers alone (goal 24 "degrade cleanly"); offline → answers queue and send later.

**What it costs per sign-up:** one first-pass read (~$0.72) + one first episode (~$1.90) + voice prompts (pre-recorded mission and callbacks: ~$0; per-person acknowledgements: a few cents). Target: under $3, from today's ~$5–7.



---

# 7. The data contract the app needs (backend routes)

All behind the person's sign-in; the backend fills in `userId` and forwards to the agent with the internal secret. Shapes are the agent's, already built, unless marked ✗ new.

| Backend route (new) | → agent | Used by |
|---|---|---|
| `POST /conversation` · `GET /conversation/today` | conversation | Journal |
| `POST /corrections` · `POST /corrections/confirm` | corrections | everywhere |
| `GET /briefs/latest` · `PUT /briefs/enabled` · `GET /briefs/:id/audio` ✗ | briefs (+ ✗ brief TTS) | Journal, Podcasts, onboarding, settings |
| `POST /search/sources` · `POST /search/answer` · `GET /search/source/:kind/:id` | search | You |
| `GET /understanding` ✗ (read contract) | understanding/read | You, Goals |
| `GET /understanding/map` ✗ (entities + facts + evidence counts + held/hypothesis flags) | ✗ new read | You |
| `GET /goals/said-vs-did` ✗ · lifecycle fields on `/goals` | understanding/said-vs-did | Goals |
| `GET /people/held` · `POST /people/held/:id` | people | You, Journal |
| `POST /hypotheses/:id` · `GET /hypotheses/:id/why` | hypotheses | Podcasts, You |
| `GET /actions` · `POST /actions/:id` | actions | Journal |
| `GET/PUT /settings/ambient` · `GET/PUT /settings/appetite` · `GET /settings/learning` · `GET/PUT /preferences` | settings, preferences | onboarding, settings |
| `GET /onboarding/readiness` · `POST /onboarding/advance` · `POST /onboarding/goals` | onboarding | onboarding |
| `POST /feedback/episodes/:id` | feedback | player |
| `PATCH /content/:id` ✗ · `DELETE /content/:id` ✓ exists (✗ make it retract what was drawn, via corrections) · idempotency key on `POST /content` ✗ | (+ agent re-read / retract) | entries |
| source descriptions on `GET /integrations` ✗ (from the agent's source profiles) | source-intelligence | ON-6, ON-7, ST-3 |
| `POST /profile/public-handles` ✗ → social research | social-research | ON-7 |
| `POST /saved` ✗ {url, reason, goalId?} | reference capture | share extension |
| `POST /speech/stream` ✗ (streamed TTS) | ElevenLabs | onboarding, conversation |
| `PUT /profile/timezone` ✗, `PUT /profile/consumption` ✗ | users | all schedules |
| `POST /devices/apns` ✗ | push | notifications |
| `POST /subscriptions/verify` ✗ | StoreKit | paywall |

---

# 8. What to build, in order

Each phase ends with something the founder can use. Phases A–C are server work the app depends on and can start before the mid-fi is approved.

| Phase | Build | Unblocks | Size |
|---|---|---|---|
| **A. Pass-through** | the backend routes in Part 7 that forward to existing agent routes (conversation, corrections, briefs, search, people, hypotheses, actions, settings, preferences, onboarding, feedback) | everything | medium: many small routes |
| **B. New reads** | `/understanding`, `/understanding/map`, `/goals/said-vs-did` | You, Goals | medium |
| **C. Outputs and timing** | brief audio (TTS of `through_line` + items, stored like episode audio); timezone (first guess from `usualOffset`, confirmed in N13) + local scheduling for brief and episode; one first episode per person; streamed TTS | the brief card, voice onboarding | medium |
| **D. Capture integrity** | idempotency key; entry edit; delete that retracts; save-link route; source descriptions in the catalog; public-handles route | Journal, share, Connect | small–medium |
| **E. Delivery** | APNs; StoreKit + receipt verification | notifications, paywall | medium |
| **F. Proposing actions** | a proposer (from conversation, own words only) feeding the existing ledger | "want me to draft that?" | medium; last (goal 17 is last) |
| **G. The app** | per [ios-refresh-plan.md](./ios-refresh-plan.md) steps 3–6: structure → mid-fi → review → tokens and components | — | large |

**Phase S, sources for launch (required, in parallel with A–C; founder, 20 Oct: more than Google and Health must work):** finish the in-development device sources (Calendar, Contacts, Screen Time, Apple Music, Photos) and OAuth sources (Spotify, Reddit, YouTube, Google Calendar), turn on `ENABLE_INTEGRATION_RUNTIME`, and file the approvals (Google verification for Gmail; TikTok, X, LinkedIn). Done when every source in the launch set connects, syncs and is read, verified on a signed-in build with `GET /integrations/readiness`.

**Switches to flip as each phase lands:** `ENABLE_ONBOARDING_PIPELINE` (with A + C), `ENABLE_MATERIAL_ARRIVALS` (with A: "read within minutes"), `ENABLE_DAILY_BRIEF` (with C), `ENABLE_APPETITE` (with A), hypothesis dial `speak` (when the founder has heard it), `SUPADATA_API_KEY` (saved-video transcripts), `ENABLE_INTEGRATION_RUNTIME` (connectors).

---

# 9. Conflicts reconciled

| Conflict | Resolution |
|---|---|
| Voice-first onboarding vs the spec's "if they prefer reading, don't speak at them" | ON-3 asks "talk or type?" at the end of the mission (talk preselected); reading mode shows the same words, no audio; switchable anytime |
| The brief card on Journal vs the brief being off by default | ON-8 asks it as a conversation turn; Journal shows the card only when on; when off, Journal shows a one-time "want a short brief each morning?" |
| "Nothing about you unless from your data" vs predictions | Inferences are welcome; shown as guesses (asked, with how sure and why); only ungrounded content is banned |
| One feature per page vs corrections, people questions and hypotheses appearing in several places | Each has one home (You), and appears elsewhere only where the claim it's about is shown (a reply, an episode line); never as a menu of features |
| Journal showing "same person?" questions vs one feature per page | Journal shows only what came out of its own thread (a correction, later an action); people questions and what it's wondering live on You (YO-6) |
| The founder's ask for a voice made for you (ios-v2 #7) vs no voice step in the new onboarding | Voice creation isn't built (K17). Until it is, Settings offers a small set of real, different voices; when it exists, it becomes an onboarding step after ON-8 |
| The mission promising "a brief each morning" vs the brief being off by default | The mission says "a brief if you want one"; ON-8 asks it as a conversation turn |
| Founder's "approve moving your 10am" sketch vs nothing proposing actions | Journal's design holds the slot; it stays empty until phase F |
| Daily brief "9am" vs a UTC cron | Local time, the person's choice (default 8:30), after K4 |
| Hypothesis dial off vs "what it's wondering" on You | Shown only when the dial allows and appetite ≥ 2; otherwise the node layer is simply absent |
| Patterns too new to judge vs showing trajectories | "Too early to tell" is a real, designed state until ~8 weeks of a source |

---

# 10. Coverage checks

## Every goal has a home

| Goal | Where in the refreshed app |
|---|---|
| 1 Data sources · 2 Ingestion | Connect (onboarding), Settings → Sources; saved → sent → read on every entry |
| 3 Making meaning | Journal ("what I took from this"), You |
| 4 Connections | You (people, "same person?") |
| 5 Linting | invisible: flagged claims never shown |
| 6 Search | You (search with receipts, "only what's certain") |
| 7 Reported goals · 8 Real goals | Goals (lifecycle, said vs did) |
| 9 Communication style · 22 Calibration | how bold (onboarding, settings); the voice; replies |
| 10 Current state | You → What I know about you (silent areas said warmly) |
| 11 Relevance | brief items with "why"; resurfaced saved links |
| 12 Impediments · 25 Pattern change | episodes (evidence → question); clusters with trajectory on You |
| 13–16 Outline, story, voice, delivery | Podcasts, the player, background playback, the brief card |
| 17 Acting | Journal's approval slot (phase F) |
| 18 Conversation | Journal thread |
| 19 Learns from itself | Settings → What it's learned |
| 20 Correction sticks | "that's not right" everywhere; corrections in plain words |
| 21 Hypothesis | the episode's one question; You's waiting nodes |
| 23 Reference bank | Share to Retrospect; saved links as nodes; resurfaced in the brief |
| 24 Cold start | ON-10–ON-11, honest about thinness |

## Every problem theme has a fix

| Audit theme (blockers in bold) | Fixed by |
|---|---|
| **No way out of the paywall · placeholder prices** | ON-12 (K13) |
| **Episodes unplayable after onboarding** | O-24 streaming/download; background playback |
| **Canned "Learning about you" claims** | ON-10 real stages + their own words |
| **Silent first-episode failure · lost uploads · deletes that don't delete** | ON-10 failure states; JR-1/JR-3/JR-4 outbox + K7/K8 |
| **Goal list overrides the brain** | GL-1 sends intents only |
| **Dev tools and fake home in the shipped app** | ST-1–ST-9: production settings, nothing for developers |
| Two first episodes | K12 |
| Demographics, orientation, dream house; long; no Back; lost answers | ON-4, ON-8; save per answer; Back everywhere |
| 17 sources, engineering labels, three Google cards | ON-6, ON-7 |
| Every episode "Weekly Insights"; no titles; no player exit | PC-1, PC-2 |
| Failing server looks like a working one; vanishing episodes | states on every tab |
| Ignores text size, VoiceOver, dark mode; fixed-size paywall | principle 9 |
| Half-written entries auto-sent; no confirmation; nowhere to see your entries | JR-1 composer keeps drafts; saved → sent → read; JR-3 All entries |
| Taps lag; 60 fps timers; blur | step 4 build rules + phone check |

---

# 11. Recommended defaults (used unless the founder changes them)

Nothing here blocks the work; each has a default the build follows.

| # | Decision | Default |
|---|---|---|
| 1 | The mission script (ON-3) | The draft in ON-3, recorded once in the app voice; the founder edits the words before recording |
| 2 | Brief and episode times | Brief 8:30 local (person can change it in ON-8 and ST-2); episode Sunday 9:00 local |
| 3 | Talk or read | Asked as the last line of the mission (ON-3), "Talk" preselected |
| 4 | Paywall benefits | The six in ON-12, each with an example from their own data where one exists |
| 5 | Hypothesis dial | Off until the founder has heard three offered in his own episodes, then on for appetite ≥ 2 |
| 6 | Server order | A → B → C → D → E → F (pass-through first, actions last) |
| 7 | First sources offered | The launch set (Phase S): Health, Calendar, Contacts, Screen Time, Google; then Spotify, Reddit, Apple Music, Photos; others as approvals land |
| 8 | Public profiles (social research) | Optional in ON-7, off unless the person adds a handle |

---

# Appendix B. Verified behaviour (read in full, not just indexed)

What each piece actually does, where it shapes a screen:

| Area | Verified | Screen consequence |
|---|---|---|
| Onboarding stages | `stageFor`: reading until nothing is outstanding and 2 min quiet, or 20 min max; then the first pass; then one episode (guarded only inside the pipeline: an episode run in the last 15 min blocks a second); the pipeline covers accounts from the last 3 days, every 2 min | ON-10 shows real counts (sources still syncing, entries waiting, answers formed); the app must not call `/podcasts/generate` itself (K12) |
| Reading speed | arrivals: read 2 min after material stops arriving, at most 10 min (when on); otherwise the daily 05:00 UTC run | JR-1/JR-3 "read" mark within minutes only with `ENABLE_MATERIAL_ARRIVALS` |
| Source sync | every 6 h (`INTEGRATION_SYNC_INTERVAL_MINUTES` 360) | ST-3 "last read" is honest at hours, not minutes |
| Daily brief (v2) | inbox = everything you sent since the last brief, always, in full, first, never dropped; then today's calendar; at most one saved link resurfaced (saved 7+ days ago, tied to a live goal or moved question, not resurfaced in 14 days); then what moved; anything said in the last three briefs discounted; a day with nothing is quiet | JR-2 sections in this order; JR-1 entries come back in tomorrow's brief ("daily is your inbox") |
| Weekly episode | eligible: anyone with new material in 14 days; spend cap checked; v2 stores the plan; a quiet week with nothing over the bar refuses to pad | PC-1 quiet-week state is real |
| Conversation | intent fyi/question/correction/chat; reply may be empty; a correction said in conversation is routed to corrections; uses search for questions; working memory 18 h | JR-1 replies, including none |
| Corrections | outcomes: not a correction · applied (with what it retired and an echo) · confirm (candidates to pick) · ask own words (when the claim came from what you wrote: shows your quote and date before changing it) | every "not right" flow has these four endings |
| People questions | each held pair: "Is the {name} in your writing {contact}?"; same links, different keeps apart for good | YO-6 copy and outcomes |
| Hypotheses | yes → confirmed, no → declined; unanswered ones expire after the dial's window (30 days); one per episode, only when the dial speaks and appetite ≥ the dial's minimum (2) | PC-2, YO-6 |
| How bold | stated always wins; inferred rises one level after 2 engaged signals in 14 days with no discomfort; drops one on any discomfort in 7 days; first guess capped at 2, at most 1 if something hard is in your words, 0 under 3 entries | ON-9, ST-6 copy ("I picked this because…") |
| What it's learned | per question type, a Bayesian response rate turned into a weight of 0.8–1.2 that only reorders what's already allowed | ST-8 |
| Magic moments | title, pattern, evidence, reframe, future-self line, hypothesis, strength; seeded into the portrait as tracked hypotheses | ON-10/ON-11 opening line, asked (K21) |
| Voices | three personas, one ElevenLabs voice id, different stability and style | ST-7; voice creation replaces the picker (K17) |
| Deleting | backend deletes the entry row; derived facts and answers are not retracted | JR-4 (K7) |
| Goals list | backend returns every column including lifecycle | GL-1 can show faded and merged from day one |

# Completeness check

**Read in full:** all 18 agent route files and every function they call that returns data to a person (conversation, corrections, search, briefs and both planners, podcasts v2 and the plan, hypotheses, people, settings, appetite and seed, learning, onboarding pipeline and job, arrivals, goals lifecycle, said-vs-did, the read contract, reference capture, actions ledger, spend guard, the elevenlabs personas); all 11 backend route files and their services; the users table across all migrations; every scheduled job in both services.

**Indexed, not read line by line, and why that's safe:** reading internals (ingestion agent, fact extractor, verify-span, supersession, promoter, trust, lint catalog, remediation, lineage), writer internals (claim guard, style), connectors' API details, evaluation and health tooling, legacy pipelines and prompts. None returns anything to the app directly; their effect reaches the app only through the routes above, whose outputs were read.

**Values that change at runtime (not unknowns about capability), and how the plan handles every value:**

| Value | Where it lives | Every possible value is designed for |
|---|---|---|
| Production switches (planners v1/v2, arrivals, onboarding pipeline, brief, appetite, learning, integration runtime, hypothesis dial) | Render environment | Each screen states its behaviour with the switch off and on (Part 3.9, K22, the "States" line of each screen). Phase G ships with the switches on for testers; until then the app reads the episode's `outline.planner` and shows "why this is here" only for v2 outlines |
| How much data a person has | the database, per person | Every screen has a day-one (thin) state and a full state; the planners refuse to pad; "too early to tell" is a designed state (Part 9) |
| Which sign-in providers have production credentials | `GET /integrations/readiness`, read by the app at runtime | Connect (ON-6, ON-7) and Sources (ST-3) render from the live catalogue and readiness, so a provider appears exactly when it works; nothing is hard-coded |

**What the backend can do for the app is fully accounted for**: every capability is in Part 3, every gap in Part 4, every module in Appendix A, every behaviour a screen depends on in Appendix B. Checking the Render switches and running one counts-only query (with the founder's okay) only confirms which states testers see first; it can't add a capability the code doesn't contain.

---

# Appendix A. Module index: every module, and where this blueprint accounts for it

Agent (`retrospect-agent/src`, 178 modules, main `d4206a3`). Grouped; each group points to where it's covered.

| Group | Modules | Covered in |
|---|---|---|
| actions | ledger (classes: draft message, reminder, calendar hold, note; own-words origin rule) | 3.4, K6, J1 slot |
| agents | cook0 (portrait maintainer), fact-extractor, ingestion-agent (authorship), podcast-agent (legacy), tools (search graph, insights, observations, raw content, previous podcasts, identity inferences, internet research) | reading (3.1); legacy podcast path, not for the app |
| ambient | switch (master + per person; sent-only reading) | 3.1, N5, T5 |
| appetite | appetite (levels 0–3, rise/fall rules), seed (first guess from words) | 3.4, N9, T6 |
| brain | baseline-shifts, complete-document, daily-summaries (incl. usual offset), evidence-pack, lease, lineage, lint, lint-catalog, people (significance), place-events, portrait, promoter, pulls, record-patterns, remediation, run-promoter, run-trajectory, supersession, time-categories, trajectory, transcript-guard, trust, trust-stamp, verify-span, why, write-journal-facts | 3.3 (patterns, trajectories, shifts, time, people, portrait, timezone), lint and trust are invisible guards (No screen) |
| briefs | daily-brief, run-daily-brief, run-daily-brief-v2 | 3.5, J1, J2, P1, T2, K3 |
| connectors | gmail, google-calendar, google-docs, youtube, spotify, reddit, tiktok, x, linkedin, pinterest, archive-import, registry, oauth-http | 3.2, N6, N7, T3, K15 |
| conversation | reply (intents, silence allowed), rules (sentence budget, no restating) | 3.4, J1 |
| corrections | target, apply, retract (changed vs wrong) | 3.4, everywhere "not right" |
| db, health, eval, text, types, config, middleware | migrations, paging, schema check, health summary, evaluation, utilities | operations; not for the app |
| events | arrivals (read within minutes) | 3.1, switch |
| goals | lifecycle (merged, expired, revived) | 3.6, G1 |
| hypotheses | propose, validate (closed framework set), offer (dial, one per episode) | 3.4, P2, Y6 |
| imports | youtube-takeout | 3.2, N7, T3 |
| integrations | revoke (on account deletion), source-intelligence (per-source profiles) | 3.2, T9, K16 |
| jobs | daily-ingestion, weekly-podcast, daily-brief, material-arrivals, onboarding-pipeline, question-research, integration-scheduler, integration-worker | 3.9 switches, Part 8 |
| learning | reception (weights 0.8–1.2) | 3.4, T8 |
| onboarding | pipeline (stages), stated-goals | 3.8, N8, N10 |
| people | resolve, run-resolution (held pairs) | 3.3, Y6 |
| pipelines | ingest, claim-work, batch-outputs, after-reading, graph-v2, integration-sync/-evidence/-tests, legacy-shim/-writes, magic-moments, podcast, podcast-v2, retry-policy, social-research, spend-guard, trace, health-summary | reading and outputs (3.1, 3.5); magic moments and social research (3.8, K18); spend cap (No screen) |
| planner | plan (episode plan: spine, items, one question, withheld, silent), select (the bar), daily (inbox, today, resurfaced) | P2 "why this is here", J2 brief sections |
| prompts | cook0, current-context-outline, episode-summary, final-transcript, historical-agent, ingestion, magic-moments, notification | server-side; notification copy → X3 |
| questions | first-pass, research, run-first-pass, run-research, transcript, understanding | 3.8, Y5 |
| reference | capture, enrich, relevance, embed, youtube-transcript | 3.7, X1, Y3 |
| routes | all 18 | 3.1–3.8, 3.10 |
| search | search, answer, source | 3.4, Y2, Y3 |
| services | anthropic, openai, perplexity, elevenlabs (personas: one voice), embeddings, credential-vault, integration-queue, token-budget, telemetry, canonical-json | server-side; voice → K5, K17 |
| understanding | read (the contract), said-vs-did, answer-moves, content-groups | 3.3, K2, G1, Y1, Y5 |
| writer | write-episode, write-brief, claim-guard, style | outputs; the guards are invisible (No screen) |

Backend (`NPRdoinglaundry/backend/src`): **auth** (signin, refresh, dev test user — debug only), **content** (create, list, get, reprocess, delete), **goals** (CRUD, decline, extract, extract-and-save, synthesize), **podcasts** (list, latest, get, generate), **profile** (get, persona, personas), **speech** (synthesize), **integrations** (catalog, list, connections, readiness, native-connected, items, device-batches, imports, assets, connect start/callback, sync, reconnect, delete data, disconnect), **graph** (legacy assertion and entity feedback), **pipeline** and **claude** (legacy, removed from the app), **admin** (operations: users, backfill, goals, content, observations, insights, pipeline, diagnose, podcasts, stats). Services: agent-client, apple-auth, goals, insight-synthesis (legacy), integration-catalog, oauth-providers, observations (legacy), podcast-db, voice-personas. No scheduled jobs in the backend.

Database: 52 agent migrations (100–151) plus the base schema; the tables each feature reads are named in Part 3. `users` holds: id, apple_user_id, email, voice_persona, daily_brief_enabled, ambient_enabled (no timezone).
