# App audit: findings and plan per step

20 October 2026. Step 1 of [the approach](./ios-v2.md#the-approach-in-three-steps-founder-20-oct), run to [the plan](./app-audit-plan.md). Audited build: branch `redesign/integrations-page-theme` at `e1f16b9` (today's onboarding and settings work), built for an iPhone 17 Pro simulator. **The end product: every logic problem, and every place the app breaks, in every phase.** Each step also carries its plan (founder, 20 Oct): see [Every step: audit → plan](#every-step-audit--plan).

**Status (20 Oct, night): step 1 done.** Every onboarding screen walked on a running build (debug build against a local stand-in server: sample data, nothing sent to Retrospect, no spend), through the first episode, the paywall and into the app; every app screen walked; the code-only screens audited from the Swift; the psychological journey; an audit + plan for all 24 steps; the ranked list. **108 entries: 8 blockers · 40 major · 50 minor** (10 are notes or repeats). Left for a phone: the recorder, Health, Screen Time, notifications, widgets.

**One-page board** (every screen with its problems, ship vs developer, rules, opportunities, iOS v2 ideas): https://claude.ai/artifact/9uf2mRH9rk9RKneh4XrQDb

Severity: **B** blocker (stops or loses someone) · **M** major (confuses, misleads or slows) · **m** minor.

---

## Phase map (the live path, from `RetrospectApp.swift`)

`WelcomeSignInPage` → `VoiceGoalsPage` → `IntegrationsSetupPage` → `PersonaPickerPage` → `OnboardingClosingPage` → **handoff** (`startFirstPodcastHandoff`) → `FirstPodcastExperience` (learning ritual → podcast + paywall → reflection) → `BackendAuthGateView` (if no token) → `DarkSplashScreen` (Face ID) → `DarkAppContainer` (Journal · Podcasts · Goals · Entries · Settings, behind a side panel; full-screen recorder and player).

---

## Findings so far

### Handoff: onboarding → first podcast

| # | Finding | Kind | Sev | Evidence |
|---|---|---|---|---|
| A1 | **A failed first podcast is silent.** `firstPodcastError` is set, never displayed anywhere; the person is dropped on the home screen with no explanation and no retry | broken · doesn't feel good | **B** | `RetrospectApp.swift:68` (only declaration and assignments), `:427–432` |
| A2 | **The goals from the voice step are dropped at the handoff.** The closing page calls `onComplete?([])`, so the first podcast is requested with an empty goals list (goals were saved locally to `GoalsManager`; whether the server gets them another way is unverified) | logic | **M** | `DarkOnboardingFlow.swift:65` |
| A3 | **Onboarding is marked complete before the first podcast exists.** If the app is killed during the minutes of generation, the person reopens to a home screen with no episode, no message, and nothing that resumes it | broken · confusing | **M** | `RetrospectApp.swift:417` (comment acknowledges the choice) |
| A4 | **Finishing (or "DEV: Go home") sets `isAuthenticated = true` and `needsBackendAuth = false` unconditionally**, skipping the Face ID splash for that session regardless of the setting | logic | m | `RetrospectApp.swift:451–458` |
| A5 | **"Learning about you" is a fake progress bar:** it creeps asymptotically toward 95% and never completes by itself; it only ends when the episode arrives (3–5 min, up to 10). Confirms the logged "hangs at 94%" | demo/fake · doesn't feel good | **M** | `LearningAboutYouView.swift:283–295` ("indeterminate creep toward 95%") |
| A6 | A notification for an unknown podcast creates a **placeholder transcript** ("Your weekly reflection is ready." / "Your personalized podcast is ready to play.") shown as if real | demo/fake | m | `RetrospectApp.swift` `findOrCreateTranscript` |
| A7 | **Every onboarding generates two first episodes and discards one.** When the questions finish, `finishProcessing` starts a real generation (`prefetchPodcast`) *before any source is connected and before the profile is uploaded*; on the normal path that episode is never shown (only the debug-only closing screen uses it). The handoff then generates a second one (`FirstPodcastOrchestrator`). The backend ignores `generationSource` and has no in-flight or duplicate check, so both run: roughly double the voice and model cost of every sign-up, two episodes in the person's list, and the first one made from almost nothing | broken · cost · redundant | **M** | `VoiceGoalsPage.swift:1162–1171, 1176–1199`; `FirstPodcastOrchestrator.swift:34`; `backend/src/routes/podcasts.ts:108–118` (no dedupe; `skipTTS` exists and could back a test switch) |

### Screen 1: Welcome and sign-in (`WelcomeSignInPage`), seen in the simulator

| # | Finding | Kind | Sev | Evidence |
|---|---|---|---|---|
| W1 | **The promise is the old product:** "Your life, turned into a weekly podcast. Journal entries, voice notes, health data…". Nothing about the daily brief, search, talking to it, or a brain that knows you | doesn't make sense (now) · not inspiring | **M** | screenshot `welcome.png` |
| W2 | **Canvas colour differs from the paywall:** a cool grey here vs warm paper `#F4F2EE` on the paywall; the first impression and the payoff don't match | pixel · inconsistent | m | screenshot vs `PodcastPaywallFlow.swift` `Pod.bg` |
| W3 | **The Sign in with Apple button is restyled** (cream, grey label): Apple's guidelines constrain this button, so it's an App Review risk, and the grey-on-cream label is low contrast | risk · pixel | **M** | screenshot |
| W4 | A large empty middle: text sits top-left, the button at the bottom, about 40% of the screen empty with nothing drawing the eye | pixel · flat | m | screenshot |
| W5 | "DEV: Sign in as new test user" is visible; confirmed debug-only (`#if DEBUG`) | demo (ok) | — | `WelcomeSignInPage.swift:114–123` |
| W6 | **The app is named "Retrospect-2026"** in both debug *and* release configurations, so that's what appears under the icon and in Apple's sign-in sheet ("Create an account for Retrospect-2026") | pixel · broken (brand) | **M** | `project.pbxproj:657, 702` (`INFOPLIST_KEY_CFBundleDisplayName`); simulator screenshot |
| W7 | **Tapping Sign in with Apple gives no feedback for ~2 s** (no pressed state, no spinner) before Apple's sheet appears; people tap again | interaction | m | simulator |

### Screen 2: Voice questions (`VoiceGoalsPage`, 1,436 lines), from code (simulator pending)

| # | Finding | Kind | Sev | Evidence |
|---|---|---|---|---|
| V1 | **18 questions, demographics first:** name, city, age, gender, **sexual orientation**, relationship status, job, how you feel about it, *before* any of the meaningful ones. Sensitive questions are asked before any trust is earned, and in an order that reads like a form | psychological · doesn't feel good | **M** | `VoiceGoalsPage.swift:92–135` |
| V2 | **Sexual orientation is asked at all, in onboarding,** with no stated reason or use. Sensitive personal data, collected without purpose | psychological · risk (privacy) | **M** | `:103` |
| V3 | **It ends on a dream city and a dream house** ("Suburban Mansion · Farmhouse · Cabin · Tiny Home"): quiz-like, after the deepest questions; the peak–end shape is inverted (it ends flat) | psychological · flat | **M** | `:131–134` |
| V4 | **Long:** 18 questions before the person gets anything back. The 8 story questions in [the onboarding brief](./brief-onboarding-questions.md) were designed to cover most of the 36 with far less | psychological · not fun | **M** | count |
| V5 | **The progress bar is non-linear:** 8 demographic answers move it 8%→22%, then single deep answers jump 11–13 points; it misrepresents how much is left | interaction | m | `progress:` values |
| V6 | A debug-only Skip exists (`#if DEBUG`), fine; a "Skip" at progress 0.02 jumps straight to completion | demo (ok) | — | `:697–710` |
| V7 | **Many timed delays** drive the conversation's pacing (asyncAfter at 0.28 s, 0.1 s, 0.32 s, 0.2 s, plus "dwell" and "ack dissolve"); pacing breaks on a slow device | logic risk | m | `:312, 372, 467, 598, 887, 1028` |
| V8 | *(simulator)* The intro ("Before we begin… Everything you share is private.") promises privacy in one line with nothing behind it; its **Continue label is mid-grey on cream**, low contrast, the same problem as W3 | pixel · psychological | m | `.scratch/audit` screenshot, 20 Oct |
| V9 | *(simulator)* **"What should I call you?" comes right after Sign in with Apple,** which can already supply the name; first question is a form field, keyboard up, no Back | redundant · interaction | m | simulator |
| V10 | *(simulator + code, corrected)* The questions step has its own closing screen ("Now let's help you get there." → **Play Podcast**) whose player falls back to the **demo transcript with no audio**. It is reached **only through the debug Skip**; the normal path goes processing → goal cards → Continue → Connections. Not a ship problem by itself, but dead-in-release UI that plays fake content | demo (debug only) | m | `VoiceGoalsPage.swift:245, 618–655, 259, 592` |

### Screen 3: Connections (`IntegrationsSetupPage`), from code (simulator pending)

| # | Finding | Kind | Sev | Evidence |
|---|---|---|---|---|
| C1 | **"Make my podcast" and "Skip for now" do exactly the same thing** (both `advance()`), and neither makes a podcast; they go to the host picker. The main button promises what it doesn't do | doesn't make sense · redundant | **M** | `IntegrationsSetupPage.swift:66–71, 204–208` |
| C2 | **Google can never show as connected:** its connected check is hard-coded `false`, so after connecting it shows at best a status label, never "connected" | broken | **M** | `:152` (`case .googleDocs: return false`) |
| C3 | **The same error is shown twice:** inline red text *and* an alert, both from `connectionError` | interaction | m | `:52–61` and `:87–94` |
| C4 | **17 sources in one list** (Health, Screen Time, Google Docs, Calendar, Apple Music, Photos, Contacts, Spotify, YouTube, Reddit, Gmail, TikTok, X, ChatGPT, Claude, Grok, Netflix): choice overload at the moment trust is lowest | psychological · not fun | **M** | catalogue `IntegrationCatalogItem.all` |
| C5 | **Google appears as three separate cards** (Google Docs, YouTube, Gmail), though one Google sign-in grants all three (backend commit 7f86719 combined them). It's also labelled "Google Docs" (logged problem, still there) | redundant · confusing | **M** | catalogue |
| C6 | **Engineering words shown under every card before connecting:** "Device sync", "Continuous sync", "API-visible sync", "Verification-gated sync", "API-tier gated sync", "Optional file import" (logged problem, wider than logged) | doesn't make sense | **M** | `plannedStatus` values, shown by `connectionStatusLabel` default |
| C7 | Tapping an unbuilt source explains, in engineering language, that it "can be connected here as soon as its verified collection path is ready" | demo/fake · confusing | m | `:96–100` |
| C8 | AI-chat history (ChatGPT, Claude, Grok) and Netflix are file imports (.json/.zip/.csv) mid-onboarding (logged problem, still there) | interaction · not fun | **M** | `connectionKind: .archiveImport` |
| C9 | A failed status fetch shows the raw system error in an alert | doesn't feel good | m | `:186–188` |
| C10 | Whether each OAuth source (Spotify, Reddit, TikTok, X, YouTube, Gmail) has working production credentials is unverified; X needs a paid API tier and TikTok an approval | unknown | ? | needs a live connect test |

### Screens 4–5: Host picker and closing page, from code (simulator pending)

| # | Finding | Kind | Sev | Evidence |
|---|---|---|---|---|
| P1 | **Canned hosts** ("wise mentor", "energetic host", "thoughtful friend"), saved only to the phone (`UserDefaults voice_persona`) (logged problem, still there; ios-v2 change 7 replaces it with a made-for-you voice) | not inspiring | **M** | `PersonaPickerPage.swift:16, 28–60, 101` |
| P2 | The host is chosen **before the person has heard any voice**: no sample to listen to | psychological · interaction | **M** | `PersonaPickerPage.swift` (no audio preview) |
| E1 | **"Play Podcast" doesn't play a podcast.** No podcast exists yet; the button starts generation and the "Learning about you" wait. The label promises an instant payoff that's minutes away | doesn't make sense · psychological (broken promise at the peak) | **M** | `DarkOnboardingFlow.swift` `OnboardingClosingPage` `:992–996` |
| E2 | "DEV: Preview paywall" is debug-only (`#if DEBUG`), fine | demo (ok) | — | `:998–1002` |

### Dead code that says false things

| # | Finding | Kind | Sev | Evidence |
|---|---|---|---|---|
| D1 | **Old onboarding screens say "All processing happens on your device" and "Your documents stay private and are never shared."** Both are false: Retrospect processes on its server and with AI providers. These screens (`DarkPrivacyOnboardingScreen`, `DarkGoogleDocsOnboardingScreen`, `DarkAppleHealthOnboardingScreen`, `DarkGoalsOnboardingScreen`, about 850 lines) are **unreachable**, but the claims live in the code and the same "never shared" line is in `GoogleDocsOnboardingScreen` (reached only from another dead template). Risk: someone revives them | dead · risk (false privacy claim) | **M** | `DarkOnboardingFlow.swift:271–938` (0 references); `Components/GoogleDocsOnboardingScreen.swift:191` |

### Onboarding flow structure

| # | Finding | Kind | Sev | Evidence |
|---|---|---|---|---|
| O1 | **No way back between steps.** Steps are one-way flags; there is no back button or gesture from one step to the previous one (within the voice questions there is a Back) | interaction | **M** | `DarkOnboardingFlow.swift:19–25, 29–77` |
| O2 | **Answers within a step aren't saved:** only step completion persists, so closing the app during the voice questions loses them (confirms a logged problem) | broken | **M** | `OnboardingState.swift:134–173` |
| O3 | Completing the questions silently marks the privacy notice as acknowledged (the privacy page is no longer on the path) | logic | m | `OnboardingState.swift:147` |
| O4 | Named "Dark…" throughout, but forced to light mode | redundant naming | m | `DarkOnboardingFlow.swift:80` |

### App: Journal and entries (the daily capture path), from code

| # | Finding | Kind | Sev | Evidence |
|---|---|---|---|---|
| J1 | **A failed entry upload is lost silently.** The failure goes only to a debug log; the entry has no "synced" flag; nothing retries; the person is never told. The brain never sees that entry (logged problem, confirmed in code) | broken | **B** | `Models/EntryModel.swift:126–147` |
| J2 | **Writing while signed out skips the upload silently**, without queuing it for later | broken | **M** | `:127–130` |
| J3 | **Editing an entry never re-syncs:** `updateEntry` saves only on the phone, so the server keeps the old words and the brain works from text the person changed | broken · logic | **M** | `:196`; callers `EntryDetailView.swift:492–512` |
| J4 | **The only recovery is "resync everything"**, hidden in Dev Mode settings, which re-uploads every entry ever written (duplicates, unless the server's dedup catches them) | redundant · risk | m | `:150–181`; `DarkSettingsView.swift:1271` |
| J5 | **One 1,227-line file holds the app shell, an audio manager, the journal and an "agent podcast test"**, so changes to one break others | structure | m | `Views/DarkAppContainer.swift` |
| J6 | Audio and voice errors are shown raw ("Audio session error: …", "Failed to play audio: …") | doesn't feel good | m | `DarkAppContainer.swift:37–38, 100–101, 995` |

### App: recorder and Podcasts tab, from code

| # | Finding | Kind | Sev | Evidence |
|---|---|---|---|---|
| R1 | **The old recorder saves every voice note twice** (`addEntry` → `voice_recording`, plus an explicit upload as `voice_journal`), so the brain counts each note double. The live recorder (`DarkVoiceRecordingView`) saves once, but the old one is still reachable through the legacy home screens (T1–T2) | broken (double counting) | m (via dev path) | `VoiceRecordingView.swift:354–387`; reached from `MinimalHomeScreen.swift:87`, `HomeScreen.swift:278` |
| R2 | The Podcasts tab carries a "Dev Mode" section (generate real or mock) behind the same user-reachable Dev Mode switch (T1) | demo in ship | **M** (with T1) | `DarkPodcastsView.swift:36, 282–311` |
| R3 | The full player opens only if a transcript is already loaded; otherwise "No Podcast Available" with Dismiss, with no route to the episode list or a retry | dead end | m | `DarkAppContainer.swift:319–351` |

### App: Goals, from code

| # | Finding | Kind | Sev | Evidence |
|---|---|---|---|---|
| G1 | **The phone's goal list overrides the brain on every change.** The sync *reactivates* any goal the server marked inactive (undoing the brain's merge and expiry, goal 7: 31→3 active), and *deactivates* any active goal the phone doesn't know, including goals the brain created. Two sources of truth that fight; likely part of why 115 goals were created and 31 stayed "active" since June ([findings 37–38](./findings-log.md)) | broken · logic | **B** | `RetrospectAPIClient.swift:346–365`; called from `GoalsManager.saveGoals()` on every add or remove. **Revival half fixed server-side: NPRdoinglaundry#19** |
| G2 | A failed goal sync is only printed; no retry, nothing shown | broken | m | `GoalsManager.swift:429–441` |
| G3 | The Goals tab shows only the phone's goals; the brain's view (active, expired, merged, said-vs-did) never reaches the person | missing | **M** | `DarkGoalsView.swift` reads `GoalsManager.shared` only |

### App: Settings and the dev tools anyone can reach (from code; simulator pending)

| # | Finding | Kind | Sev | Evidence |
|---|---|---|---|---|
| T1 | **Every user sees Settings → "Advanced: Dev tools and experiments"** (not debug-only). Inside, a **"Dev Mode"** switch anyone can turn on reveals: **"Mock API Calls: use sample data instead of real API calls"**, an "Experimental View", replaying onboarding, a podcast-flow preview, a **legacy home screen**, and test podcast generation | demo/fake in ship | **B** | `DarkSettingsView.swift:100–109` (no `#if DEBUG`), `:1183–1230`, `:1355–1460` |
| T2 | **The legacy home screen shows hard-coded fake podcasts** ("Love and Relationships", "Career Growth", "Personal Health", "Family Connections", each with "Mock transcript for…") and is reachable from Settings | demo/fake in ship | **B** (with T1) | `HomeScreen.swift:1425–1429, 1505, 1542`; `DarkSettingsView.swift:1418, 1543` |
| T3 | **With Mock API Calls on, a podcast is generated from sample data and looks like a real one** ("Creating Mock Podcast… Using sample data…"); a user who flips it gets fake episodes | demo/fake | **M** | `DarkPodcastsView.swift:17, 226–336` |
| T4 | **Three separate "Generate podcast" buttons:** the Podcasts tab and twice in Advanced settings, all labelled "Generate Real Podcast" / "Generate Mock Podcast" | redundant · confusing | **M** | `DarkPodcastsView.swift:287`; `DarkSettingsView.swift:1308, 1484` |
| T5 | "Animation: Fluid dots preview" is a Settings row for everyone | demo in ship | m | `DarkSettingsView.swift:90–97` |
| T6 | Settings is 1,890 lines; Advanced alone holds onboarding replay, finale debug, legacy UI, flow previews and new-podcast-arrival tests (development tools living in the shipped settings) | redundant | m | file |

### App ↔ server

| # | Finding | Kind | Sev | Evidence |
|---|---|---|---|---|
| X1 | **The app writes its own AI prompts and sends them to `/claude/generate`, a general "run any prompt" proxy.** It's protected by sign-in and a global rate limit and capped at 8,192 tokens, but any signed-in account (or leaked token) can run arbitrary Claude prompts on Retrospect's bill. Prompts should live on the server, per feature | risk (cost) | **M** | `ClaudeService.swift:94–108`; `backend/src/routes/claude.ts:17–39`, `index.ts:79` |
| X2 | The proxy's default model is an older one (`claude-sonnet-4-6`) unless `CLAUDE_MODEL` is set | stale | m | `claude.ts:33` |
| X3 | **28 places show raw errors to the person** (`error.localizedDescription`), and the API client builds them as "HTTP 500: {body}" (logged problem, wider than logged) | doesn't feel good | **M** | `RetrospectAPIClient.swift:572`; 28 view sites |
| X4 | Legacy `OpenAIService` remains with an empty key ("until all call sites use the API"); any remaining caller fails silently | dead · broken | m | `OpenAIservice.swift:38–41` |
| X5 | The DEV test-user sign-in only works against a local server (production correctly returns 404), so a fresh simulator can't get past screen 1 without a real Apple ID or a local backend | audit blocker | — | `backend/src/routes/auth.ts:60–70` |

### Whole codebase (static)

| # | Finding | Kind | Sev | Evidence |
|---|---|---|---|---|
| S1 | **About 57 of 248 screen types (~32 files, ~8,000 lines) can't be reached from the app**, including a 1,273-line unused onboarding (`iMessageOnboardingView`), a whole video-journal feature (4 files), an old home screen (`OptimizedHomeScreen`), the old integrations screen, the teleprompter, an unused privacy page and an unused persona screen | dead | m (cost: confusion, build time, wrong edits) | reachability pass (file-level estimate; widget views are false positives) |
| S2 | **83 timed delays (`asyncAfter`)** across the app: a sign of timing patches that behave differently on slow devices and networks | logic risk | m | `grep asyncAfter` |
| S3 | 37 `#if DEBUG` blocks and 5 "DEV:" controls: to be checked that none leaks into a release build | demo | m | `grep` |
| S4 | Two Xcode projects: `Retrospect/Retrospect.xcodeproj` (live) and `Retrospect fina (SwiftUI).xcodeproj` at the root | redundant | m | repo root |

---

### Simulator walk-through, 20 Oct night (debug build, server unreachable, no data, no spend)

Route: sign-in → intro → first question → debug Skip → closing line → Play Podcast (fails at once) → player and paywall → close → Journal → Goals → Entries → Podcasts → Settings → Profile → Integrations & Data → Advanced. Not walked: the recorder (it would record), notifications, widgets and the Live Activity (phone only), and steps 3–9 of onboarding on the normal path (they need answers typed in).

| # | Finding | Kind | Sev | Evidence |
|---|---|---|---|---|
| L1 | **Closing the app mid-onboarding loses everything:** a relaunch starts the questions again from the intro. Confirms O2 on a running build | broken | (O2) | simulator |
| L2 | **With no episode, the player runs a fake clock:** "6:58" counting down, a Pause button, a moving bar, **no audio**, and the first line stays highlighted for 40 s. It looks like it's playing | demo or fake · broken | **M** | `Components/PodcastPlayer.swift:99–107` (`visualDuration = 420`); simulator |
| L3 | **The paywall's "Privacy notice" does nothing** (empty action) and there is **no Terms of Use link**. Apple requires working links to both on a subscription screen (Guideline 3.1.2) | broken · App Review risk | **M** | `PodcastPaywallFlow.swift:706`; Apple's 3.1.2 rejections quote this requirement: the binary must have working Privacy Policy and Terms of Use links next to the subscription's title, length and price ([forum](https://developer.apple.com/forums/thread/807082), [forum](https://developer.apple.com/forums/thread/812192)) |
| L4 | **The paywall can't take money:** there is no StoreKit purchase path at all. "$19.99/m" and "$239.99/y" are placeholder text (and the yearly placeholder is more than 12 × monthly); tapping either shows "Subscriptions aren't available in this build yet." Real prices and products need setting up in App Store Connect + StoreKit | missing · product | **M** | `SubscriptionManager.swift:9–10, 24–25, 45–51`; simulator |
| L5 | An **unlabelled icon button** (two arrows) on the paywall and at the top of the side menu; its purpose can't be told from the screen | doesn't make sense | m | simulator |
| L6 | **Journal promises "Your next episode is in 3 days" always:** the text is hard-coded, whatever the schedule or whether any episode exists | demo or fake | **M** | `DarkAppContainer.swift:927` |
| L7 | Journal's prompt reads "tell me something....." (five dots), in faint grey on cream | pixel | m | simulator |
| L8 | **Podcasts says "Write in your journal and generate your first personalized podcast"** but there is no generate button for a normal user; the menu says "podcasts", the header "Episodes" | confusing · dead end | m | simulator |
| L9 | **Profile's settings do nothing:** podcast cadence (Daily … Every 2 weeks) is stored on the phone and never read or sent; "Deep Research Mode" is read only by the legacy home screen. "AI style" is promised in the row's subtitle but isn't there | broken · fake | **M** | `DarkSettingsView.swift:499–530`; `HomeScreen.swift:1054`; simulator |
| L10 | "Every Other Day" is described as "Mon, Wed, Fri, Sun" (four days, two in a row) | doesn't make sense | m | simulator |
| L11 | **Opening Advanced asks for notification permission** out of nowhere, with no reason given, under the name "Retrospect-2026" (W6) | psychological (trust before ask) | **M** | `DarkSettingsView.swift:1586–1589` |
| L12 | The side menu opens about a second after the tap; the menu button moves between screens (Journal vs the rest) | interaction · pixel | m | simulator |
| L13 | The Face ID switch reads ambiguously: knob on the "on" side, grey track like "off" | pixel | m | simulator |
| L14 | With the server down, Integrations shows "Could not connect to the server." with only OK; the retry is a separate icon. Plain words, but no next step | doesn't feel good | m | simulator |
| L15 | The debug Skip needs two taps the first time (the first is swallowed while the keyboard comes up) | interaction (debug only) | — | simulator |

Confirmed on the running build: W6, V8, V9, O2, A5 (demo fallback), C5, C6, T1, T5, T6, R2 (via Dev Mode, not switched on).

---


### Full onboarding walk-through, 20 Oct night (debug build against a local stand-in server: sample data only, nothing sent to Retrospect's servers, no spend)

Every onboarding screen on the normal path, with placeholder answers: intro → 18 questions (with 3 bridge screens) → processing ("wonderings") → goal cards → Connections → host picker → closing page → "Learning about you" → first episode → paywall → into the app.

| # | Finding | Kind | Sev | Evidence |
|---|---|---|---|---|
| N1 | **"Learning about you" shows hard-coded placeholder insights to every user as if they were about them:** "You carry more than you let on", "You move fast, and rarely stop to notice", "You're harder on yourself than the evidence warrants". The code says "Placeholder callouts — swap for the real source". At the emotional peak, the product states things about you it has no evidence for (Barnum statements), the opposite of goal 4 | demo or fake · psychological | **B** | `LearningAboutYouView.swift:203–210`; simulator (all answers were "Test") |
| N2 | **The two-episode problem confirmed on a running build:** `/podcasts/generate` fired when the goal cards appeared (02:11:38) and again on "Play Podcast" (02:13:07). Confirms A7 | broken · cost | (A7) | stand-in server log |
| N3 | **"Learning about you" percentage is invented:** 24% at ~2 s, 77% at ~15 s, 91% at ~30 s, with the server still working. Confirms A5 | demo or fake | (A5) | simulator |
| N4 | **The dots draw over the headline text** on "Learning about you" (confirms the logged "dots over text") | pixel | m | simulator |
| N5 | **The "wonderings" fallback is canned and written in the third person** ("What are *they* protecting when *they* stay this busy?"), shown whenever the AI call fails; the lines assume a busy achiever | demo or fake · doesn't make sense | **M** | `VoiceGoalsPage.swift:1223–1232`; simulator |
| N6 | **Every acknowledgement is the same line**, "Thank you. That helps.", whatever the answer (the AI-made reply falls back to it); after the first few it proves nothing was heard | not inspiring | m | simulator; `/claude/generate` called once per deep answer (9 calls) |
| N7 | **Each deep answer makes its own AI call through the general prompt proxy** (`/claude/generate`, 9 per onboarding), so the app writes prompts client-side for every answer (adds to X1) | risk (cost) | m | stand-in server log |
| N8 | **Three "bridge" screens with no Back** ("These next ones go a little deeper", "Now, the real reason you're here", "Now dream a little bigger… because with me, it is"). The last one promises what the product can't keep | psychological · interaction | m | simulator |
| N9 | **The sexuality question is free text with no way to decline** (unlike gender, which has "Prefer not to say"); the keyboard opens straight away | psychological · privacy | **M** (with V2) | simulator |
| N10 | **Return doesn't send an answer;** it closes the keyboard and the answer stays in the field, so you hunt for the arrow | interaction | m | simulator |
| N11 | **A picked option barely changes colour** (gender, relationship), so it's hard to see what you chose | pixel · interaction | m | simulator |
| N12 | **The home-type grid misaligns:** two-line labels make some cards taller, so the two columns don't line up | pixel | m | simulator |
| N13 | **Goal cards say "I'll watch your life through the rest"** (reads as surveillance), with no way to add or edit a goal, only uncheck | psychological · interaction | m | simulator |
| N14 | **Connections: every description is cut off mid-word** ("daily rhyth…", "apps an…"), the heading scrolls under the status bar, and the list runs under "Make my podcast" (confirms the logged "covers the list") | pixel | **M** (with C-findings) | simulator |
| N15 | **Tapping a file import opens the iOS file picker with no explanation** of which file or how to export it from ChatGPT/Claude/Grok/Netflix | interaction · confusing | m | simulator |
| N16 | **A failed connection shows "Server error: Could not start connection"** in an alert, after the fact, with only OK | doesn't feel good | m | simulator (X card) |
| N17 | **The closing page repeats the questions step's closing line** ("Now I know what matters to you, Sam. Let's help you get there." vs "Now let's help you get there.") and shows "DEV: Preview paywall" (debug only) | redundant | m | simulator |
| N18 | **Host descriptions are cut off** ("Good…", "Celebrates y…"); green ticks on goals and hosts aren't in the design system | pixel | m | simulator |
| N19 | **In a release build the paywall has no way out.** The close (X) is wrapped in `#if DEBUG`, there's no "Not now", and subscribing can't work yet (no purchase path), so a real person who reaches the reveal is stuck on that screen. Likely an App Review rejection by itself | broken | **B** | `PodcastPaywallFlow.swift:114–129`; simulator (X does nothing after the reveal) |
| N20 | **The first episode can never be replayed after onboarding.** The app's player only plays files saved on the phone; the first episode is saved with its web link (only the legacy "generate" path downloads audio), so on Journal the "Reflective episode ▶" pill opens a player whose play, skip and "…" do nothing, silently | broken | **B** | `DarkAppContainer.swift:79–86` (file-exists check), `FirstPodcastOrchestrator.swift:44–46` vs `Transcriptviewmodel.swift:572–581`; simulator |
| N21 | **The episode pill is labelled with the mood** ("Reflective episode"), not the episode's title; the full player shows no title, date, chapters, speed or "why this was in it", and only "0:37" with no label | doesn't make sense | m | simulator |
| N22 | **The reflection step ("How was your first podcast?") is unreachable today:** it only follows a completed subscription *and* a finished episode. Its answer would be saved as the first journal entry (good), but nobody can get there | dead (for now) | m | `FirstPodcastExperience.swift:59–70, 105–112` (code only) |
| N23 | **"Learning about you" ends "Understanding you. 100%"** the instant the episode arrives (94% → 100% in one jump), so the number is visibly tied to nothing | demo or fake | (A5) | simulator |

---


### Screens that exist only in code paths the walk-through can't reach on a simulator (audited from the Swift)

| # | Screen | Finding | Kind | Sev | Evidence |
|---|---|---|---|---|---|
| Q1 | Backend sign-in gate (shown when the app has no server token after onboarding) | **A second sign-in screen that repeats the welcome page word for word**, including the old promise ("Your life, turned into a weekly podcast…"); its error is raw system text. A person who reaches it has already signed in once and is asked again with no reason given | redundant · confusing | **M** | `Components/BackendAuthGateView.swift:25–51, 104, 138` |
| Q2 | Face ID splash | On failure shows the raw system error and a "Try Again" button; no way in by passcode or to turn Face ID off from here, so a failed Face ID locks the person out of their own journal | broken · interaction | **M** | `DarkSplashScreen.swift:14–48` |
| Q3 | "Connect Google" prompt (appears over Home after onboarding when Google isn't connected) | **A second Google ask after onboarding already offered Google**, labelled "Secure Document Access… your Google Docs", the narrow old scope; promises "read-only… to include relevant content in your weekly insights" | redundant · stale copy | m | `DataManagementSection.swift:1256–1300`; `RetrospectApp.swift` (shown 1 s after launch) |
| Q4 | Data management ("Reset All Data") | Lives inside a 1,461-line file mixing Google Docs browsing, data overview and reset; "Setup Required: please add your Google Client ID" is developer copy shown to users when unconfigured | demo in ship · structure | m | `DataManagementSection.swift:18–103, 573–578` |
| Q5 | First reflection ("How was your first podcast?") | Unreachable today (needs a completed subscription); see N22 | dead | m | `FirstPodcastExperience.swift:117–160` |
| Q6 | Recorder (full screen) | Not walked (it records the Mac's microphone). From code: the live recorder saves once; the legacy one twice (R1); transcription confidence is computed and thrown away | — | (R1) | `DarkVoiceRecordingView.swift`; `TranscriptionService.swift:88` |
| Q7 | Widgets, Live Activity, notifications, share | Phone-only. From code: no share extension exists; notifications for an unknown episode create placeholder transcripts (A6) | — | (A6) | targets list; `RetrospectApp.swift` |

---

## The psychological journey (what a person does, thinks and feels)

Drawn from the walk-through and the code, using the lenses in [the audit plan](./app-audit-plan.md#the-five-passes-per-screen). **Peak** = the moment they'll remember; **risk** = where people are likely to drop off.

| # | Moment | They do | They think | They feel | Lens broken | What the plan changes |
|---|---|---|---|---|---|---|
| 1 | Welcome | read the promise, tap Sign in | "a weekly podcast about me?" | curious | — | the current promise (A1) |
| 2 | Apple's sheet: "Create an account for Retrospect-2026" | wait ~2 s with no feedback, then approve | "is this the right app?" | slight doubt | clarity of state; trust | the real name, a pressed state (W6, W7) |
| 3 | "Everything you share is private" → "What should I call you?" | type their name again | "didn't Apple just tell it that?" | it's a form | effort vs reward | name from Apple; the first question is a story question |
| 4 | 8 demographic questions, incl. **sexual orientation** | answer or hesitate | "why does a podcast need this?" | examined, guarded | **trust before ask**; self-image | no demographics; every question has a stated use (V1, V2) | **risk** |
| 5 | 10 deep questions | think hard, type a lot | "this is actually thoughtful" | engaged, invested | — | voice-first, acknowledged after each answer | **peak (first)** |
| 6 | Dream city, dream house | tap a pill | "huh, a quiz?" | deflated | peak–end | ends on the deepest question (V3) |
| 7 | Goal cards | prune a list | "it got me, mostly" | seen | — | brain-owned goals, kept |
| 8 | 17 sources with engineering labels | scroll, skip most | "which of these matter? what's 'Verification-gated'?" | overwhelmed | **choice load** | ≤5 recommended, each with its reason (C4, C6) | **risk** |
| 9 | Host picker (three canned hosts, no sample) | pick blind | "does it matter?" | indifferent | effort vs reward | a voice made for them, heard first (P1, P2) |
| 10 | "Play Podcast" → "Learning about you 94%" for minutes | wait, maybe leave | "it said play" | misled, impatient | **waits** (Maister); labels | real stages, started early (E1, A5) | **risk (highest)** |
| 11 | First episode plays; at 40 s it fades to the paywall | listen, then hit the price | "it knows me… and now it wants $20" | moved, then sold to | peak–end | the reveal timed to the strongest line, honest prices (L4) | **peak (intended)** |
| 12 | If generation failed: silence, empty home, or a demo script on a fake clock | look for their episode | "where is it? was that even mine?" | let down, deceived | peak–end; honesty | named failure + promise (A1, L2) | **risk (trust)** |
| 13 | Home: "tell me something…", "next episode in 3 days" | maybe type, maybe close | "what do I do here every day?" | unsure | **habit** (no cue, no reward) | Home with the brief, the conversation and "waiting on you" (B1) |
| 14 | Days 2–7: write; nothing visibly comes back until the episode | write a few times, then less | "is it listening?" | ignored | habit; clarity of state | every entry shows "read by the brain"; daily brief; replies (B1) | **risk (week 1)** |
| 15 | Settings: dev tools, settings that do nothing, a surprise permission prompt | explore | "is this finished?" | doubt about the product | trust | nothing for developers; every setting real (T1, L9, L11) |

**The shape today:** one real peak (the deep questions, step 5), an intended peak that often fails (the first episode, 11–12), and the highest drop-off risks right before and after it (8, 10, 12). Day-to-day use has no habit loop (13–14). **The shape the plan aims for:** trust earned before any ask, a wait that's short, honest and started early, the episode as the peak *and* the end of onboarding, and a reason to open it every day (the brief and replies).

---

## Every step: audit → plan

Founder, 20 Oct: the audit carries **a plan for every single step**. Each step below shows **today** (what it does and its findings), the **plan** (what replaces it, from [the opportunities map](./ios-v2-opportunities.md)), the **rules** it must meet (the 14 constraints in [app-audit-research.md](./app-audit-research.md#the-constraints-acceptance-criteria-for-the-new-app)), and the **work** it needs. Plans are direction, not final designs; detailed screens come in stages 4–6 of [the implementation plan](./ios-v2-implementation-plan.md), after the founder approves stage 2.

### Onboarding

| # | Step today | Findings | Plan | Rules | Work |
|---|---|---|---|---|---|
| 1 | **Welcome and sign-in** (`WelcomeSignInPage`): the old promise, a restyled Apple button, "Retrospect-2026" in Apple's sheet | W1–W4, W6, W7 | **A1 What this is** (the four-part promise, one breath) + **A2 Sign in**: Apple's standard button, a pressed state and spinner on tap, Google as a second option that also connects Google | 6, 10 | app; rename the display name to "Retrospect" (one build setting) |
| 2 | **Intro** ("Before we begin… Everything you share is private.") | V8 | Folded into A1/A3: no separate page. The privacy line moves to its own step (A5), where it's backed by specifics | 6, 11 | app |
| 3 | **18 questions** (`VoiceGoalsPage`): name first, demographics before meaning, orientation, dream house last, non-linear progress, answers lost on close | V1–V5, V7, V9, O2 | **A3 The conversation:** the 8 story questions + 2 fallbacks ([brief](./brief-onboarding-questions.md#v2)), voice-first, each answer acknowledged, saved the moment it's given, Back always works, "3 of 8" progress. Name from Apple when given | 8, 12, 7 | app; onboarding `/advance` (exists); the 3 question decisions (founder) |
| 4 | **Processing + goal cards** ("wonderings", then a prune of extracted goals). **Starts a paid episode that is never shown** | A7, A2 | Goals extracted from the answers are shown as the brain's view (server-owned), one tap to drop. **No episode starts here**: the first episode starts at Connect (A8), once | 3, 7 | app; remove the prefetch; server: one first-episode run per person (dedupe on `onboarding_first_episode`) |
| 5 | **Connections** (`IntegrationsSetupPage`): 17 sources, three Google cards, engineering status words, file imports mid-flow, two buttons that do the same thing | C1–C10 | **A4 Connect:** at most 5 recommended sources, each with one sentence on what it helps it understand; one Google card; plain states; "Not now" per source; file imports move to Settings → Sources. **The first episode starts here** in the background | 6, 9, 7 | app; `ENABLE_ONBOARDING_PIPELINE`; production credentials per source (C10) |
| 6 | *(missing)* **Privacy** | D1, V2 | **A5 Privacy, shown off:** what it reads, where it's processed (our server + named AI providers), what it never does, the ambient switch, delete anytime. Delete the dead screens with false claims (D1) | 11 | app; settings `/ambient` (exists); provider terms checked |
| 7 | *(missing)* **How bold** | — | **A6:** the four levels, our pick preselected from their words, with the reason | 6 | settings `/appetite` `suggested` (exists); `ENABLE_APPETITE` |
| 8 | **Host picker** (`PersonaPickerPage`): three canned hosts, no sample, saved only on the phone | P1, P2 | **A7 Your voice:** a few questions on what they listen to → a voice made for them, a sample line read aloud; saved on the server | 14 | server: voice creation (to build) |
| 9 | **Closing page** ("Play Podcast" that starts generation) | E1, A2 | Removed. The button that ends onboarding says what happens next ("Hear your first episode" only when it's ready) | 6 | app |
| 10 | **Learning about you** (fake % creeping to 95) | A5, A3 | **A8 Your first podcast:** real stages from `/onboarding/readiness` ("reading your calendar… writing… recording"), a line from their own answers while they wait; survives closing the app | 7, 1 | app; readiness (exists) |
| 11 | **Handoff failure** (silent; lands on an empty home) | A1, A3 | Failure is named: "Your first episode didn't finish. Your answers are saved. Try again now, or we'll make it tonight and tell you." Onboarding completes only when the episode exists or the promise is made | 1 | app; server: a scheduled retry + notification |
| 12 | **Player + paywall** (demo transcript fallback, 40 s tease) | A5/V10, E2 | **A9 The reveal:** the real episode only, never the demo script; after 30–40 s (open) the two buttons rise (1.22 s); demo content lives only in the demo account | 5, 6 | app; StoreKit |
| 13 | **Backend sign-in gate + Face ID** (skipped after onboarding, A4) | A4, X5 | One sign-in, done at step 1; Face ID honoured from the first launch if switched on | 1 | app |
| 14 | **Into the app** (lands on Journal) | A3 | **A10:** Home with the episode in place and the first thing worth doing ("Tell me about today") | 14 | app |

### The app

| # | Step today | Findings | Plan | Rules | Work |
|---|---|---|---|---|---|
| 15 | **Navigation**: a side panel with five screens | J5, S1 | Bottom bar **Journal · Podcasts · Goals · You** (founder, 20 Oct; You = search + the map); Settings behind your picture | 14 | app |
| 16 | **Journal** (capture): uploads fire once, failures lost, edits never re-sent | J1–J4, J6 | **B1 Home:** a voice-first "Tell me…" field with an outbox: saved → sent → read by the brain, retried with backoff, edits re-sent, one upload per capture. Today's brief, the conversation and "things waiting on you" below | 2, 13 | app outbox; backend `/content` idempotency key |
| 17 | **Recorder**: the old one saves every note twice (reachable via dev paths) | R1 | One recorder, one upload per note, through the same outbox | 2 | app; delete the old recorder |
| 18 | **Podcasts tab + player**: a dev section, three generate buttons, a dead-end "No Podcast Available" | R2, R3, T3, T4 | **B2 Podcasts:** this week's episode, the player with transcript, chapters and "why this was in it", the in-episode question as a Yes/No card, past episodes. No generate buttons for users | 4, 6, 1 | app; episode outline + hypotheses routes (exist) |
| 19 | *(missing)* **Search** | — | **B3 Search:** sources first (~1 s), then the written answer with citations; open any source; "Saved" filter; "that's not right" on any line | 14 | search `/sources`, `/answer` (exist) |
| 20 | **Goals**: the phone's list overrides the brain | G1–G3 | **B4 You → Goals:** the brain's view (active, expired, merged, said vs did); the app sends intents only | 3 | app; server half done (NPRdoinglaundry#19) |
| 21 | **Entries** (a list of past entries) | J3 | Merged into Home's history and Search; each entry shows its state | 2 | app |
| 22 | *(missing)* **What it knows** | M9 | **B4 You:** answers by area with how sure and why, corrections, patterns, people, what it's wondering, how bold, what it's learned | 14, 3 | server: a "what I know about you" endpoint (to build) |
| 23 | **Settings**: dev tools, Mock API, a fake legacy home, previews, all reachable by anyone | T1–T6 | **B5 Settings:** Sources (with file imports), Privacy, Actions, Voice/brief/subscription/account. **Nothing for developers:** `#if DEBUG` or a server-side staff role | 4, 5 | app; server: a staff role |
| 24 | **Everywhere**: raw errors, a general prompt proxy, placeholder transcripts from notifications | X1–X4, A6, S2–S4 | **B6:** plain errors with a next step; per-feature server endpoints instead of the prompt proxy; notifications deep-link to real content; share extension asks "why are you saving this?" | 13, 1, 5 | server: feature endpoints; app: error copy |

**Seen on a running build:** steps 1–3, 12, 15–16, 18, 20–21, 23. **Code only:** steps 4–11 (they need typed answers), 13, 17 (recorder), 19 and 22 (don't exist yet), 24 (notifications and widgets are phone-only). New live findings L1–L15 belong to steps 12 (L2–L5), 16 (L6–L7), 18 (L8), 23 (L9–L14); each is covered by that step's plan.

---

## Re-check of the problems logged before the audit (20 Oct, from code)

| Logged problem ([ios-v2 §2](./ios-v2.md#2-problems-in-the-current-app)) | Now | Audit ref |
|---|---|---|
| Connections: unclear labels, file uploads, "Make my podcast" covers the list | still there (overlap not yet seen live) | C1, C6, C8 |
| Canned hosts | still there | P1 |
| "Learning about you" *and* a demo podcast | still there | A5, V10 |
| No way out of the demo player | fixed (close button, `PodcastPaywallFlow.swift:118`) | — |
| Hangs at 94% / two episodes per onboarding | still there; server has no duplicate check | A5, A7 |
| Goals step waited minutes | fixed server-side (#12) | — |
| Several Play Podcast buttons, no linear story | still there | E1, V10 |
| Answers lost on close | still there | O2 |
| Redoing onboarding reused old answers | unverified (server) | — |
| "Preparing your episode" frozen | live path now shows "Learning about you" instead; same fake wait | A5 |
| Demo shown after "Preparing" | only on the debug path now | V10 |
| Google labelled "Google Docs" | still there (three Google cards) | C5 |
| Dots over text | needs the live walk-through | — |
| ~90 s launch | not seen on the simulator (launch was quick) | — |
| Broken font files | **still there:** the 3 Libre Baskerville files are saved web pages, not fonts | new: F1 (m) |
| Audio setup Apple warns about | 13 `setCategory` sites, `setActive(true)` on the main thread in 3 places | to confirm live |
| No share extension | still none (targets: app, widgets, Screen Time report) | B6 plan |
| Raw errors | still there | X3 |
| Two app versions drifted | still two Xcode projects | S4 |
| Uploads lost silently | still there | J1 |
| Calendar sent as one summary | `NativeSourcesManager.swift` reads EventKit; per-event upload unverified | — |
| Five onboarding flows | still there (dead code) | S1 |

---

## Ranked list (20 Oct, after the walk-through)

From the code and static passes, the re-check, and the simulator walk-through.

**10 blockers · 62 major · 76 minor** (167 entries across this file and [app-audit-deep.md](./app-audit-deep.md); 19 are notes or repeats; recounted 20 Oct after the deep pass)

### Blockers
1. **N19**: In a release build the paywall has no way out (close is debug-only; subscribing can't work)
2. **N20**: The first episode can never be replayed after onboarding (player needs a local file)
3. **Y26**: No episode can be heard in the app after onboarding (the player never downloads server episodes)
4. **Y12**: Deleting an entry only removes it from the phone; the brain keeps it
5. **N1**: "Learning about you" shows canned claims about the person as if they were real
6. **A1**: A failed first podcast is silent
7. **J1**: A failed entry upload is lost silently
8. **G1**: The phone's goal list overrides the brain on every change
9. **T1**: Every user sees Settings → "Advanced: Dev tools and experiments" (not debug-only)
10. **T2**: The legacy home screen shows hard-coded fake podcasts ("Love and Relationships", "Career Growth", "Personal Health", "Family Connections", each with "

### Major
1. **A2**: The goals from the voice step are dropped at the handoff
2. **A3**: Onboarding is marked complete before the first podcast exists
3. **A5**: "Learning about you" is a fake progress bar: it creeps asymptotically toward 95% and never completes by itself; it only ends when the episode arrives
4. **W1**: The promise is the old product: "Your life, turned into a weekly podcast
5. **W3**: The Sign in with Apple button is restyled (cream, grey label): Apple's guidelines constrain this button, so it's an App Review risk, and the grey-on-c
6. **V1**: 18 questions, demographics first: name, city, age, gender, sexual orientation, relationship status, job, how you feel about it, *before* any of the me
7. **V2**: Sexual orientation is asked at all, in onboarding, with no stated reason or use
8. **V3**: It ends on a dream city and a dream house ("Suburban Mansion · Farmhouse · Cabin · Tiny Home"): quiz-like, after the deepest questions; the peak–end s
9. **V4**: Long: 18 questions before the person gets anything back
10. **C1**: "Make my podcast" and "Skip for now" do exactly the same thing (both `advance()`), and neither makes a podcast; they go to the host picker
11. **C2**: Google can never show as connected: its connected check is hard-coded `false`, so after connecting it shows at best a status label, never "connected"
12. **C4**: 17 sources in one list (Health, Screen Time, Google Docs, Calendar, Apple Music, Photos, Contacts, Spotify, YouTube, Reddit, Gmail, TikTok, X, ChatGPT
13. **C5**: Google appears as three separate cards (Google Docs, YouTube, Gmail), though one Google sign-in grants all three (backend commit 7f86719 combined them
14. **C6**: Engineering words shown under every card before connecting: "Device sync", "Continuous sync", "API-visible sync", "Verification-gated sync", "API-tier
15. **C8**: AI-chat history (ChatGPT, Claude, Grok) and Netflix are file imports (
16. **P1**: Canned hosts ("wise mentor", "energetic host", "thoughtful friend"), saved only to the phone (`UserDefaults voice_persona`) (logged problem, still the
17. **P2**: The host is chosen before the person has heard any voice: no sample to listen to
18. **E1**: "Play Podcast" doesn't play a podcast
19. **D1**: Old onboarding screens say "All processing happens on your device" and "Your documents stay private and are never shared
20. **O1**: No way back between steps
21. **O2**: Answers within a step aren't saved: only step completion persists, so closing the app during the voice questions loses them (confirms a logged problem
22. **J2**: Writing while signed out skips the upload silently, without queuing it for later
23. **J3**: Editing an entry never re-syncs: `updateEntry` saves only on the phone, so the server keeps the old words and the brain works from text the person cha
24. **R2**: The Podcasts tab carries a "Dev Mode" section (generate real or mock) behind the same user-reachable Dev Mode switch (T1)
25. **G3**: The Goals tab shows only the phone's goals; the brain's view (active, expired, merged, said-vs-did) never reaches the person
26. **T3**: With Mock API Calls on, a podcast is generated from sample data and looks like a real one ("Creating Mock Podcast… Using sample data…"); a user who fl
27. **T4**: Three separate "Generate podcast" buttons: the Podcasts tab and twice in Advanced settings, all labelled "Generate Real Podcast" / "Generate Mock Podc
28. **X1**: The app writes its own AI prompts and sends them to `/claude/generate`, a general "run any prompt" proxy
29. **X3**: 28 places show raw errors to the person (`error
30. **A7**: Every onboarding generates two first episodes and discards one (cost doubles per sign-up)
31. **W6**: The app is named "Retrospect-2026" in release, under the icon and in Apple's sign-in sheet
32. **L2**: With no episode, the player runs a fake clock with no audio
33. **L3**: Paywall "Privacy notice" does nothing and there's no Terms link (App Review)
34. **L4**: The paywall has no purchase path; prices are placeholders
35. **L6**: "Your next episode is in 3 days" is hard-coded
36. **L9**: Profile settings (cadence, Deep Research, "AI style") do nothing
37. **L11**: Opening Advanced asks for notifications with no reason

### Minor
A4, A6, W2, W4, V5, V7, V8, V9, V10, W7, C3, C7, C9, O3, O4, J4, J5, J6, R1, R3, G2, T5, T6, X2, X4, S1, S2, S3, S4, L5, L7, L8, L10, L12, L13, L14, F1

---

## What's left (phone and typed-answer paths only)
- **On your phone** (simulator can't): the recorder, Health, Screen Time, Calendar, notifications, widgets and the Live Activity. One screen recording is enough.
- **The normal onboarding path, steps 3–9**, needs answers typed in. It can run on a test account when you want it (no spend with the server pointed away, or one real run of about $2–4 to see the real first episode).
- Everything else in step 1 (the audit) is done: code, static, re-check, walk-through, journey, a plan per step, the ranked list.
