# Retrospect — Full-stack architecture (backend to frontend)

This is a **text-native relationship map** of the whole system: iOS app, Screen Time extension, Render API, Supabase, external AI APIs, and how data moves between them. Use it when diagram renderers fail.

**Quick reference**

| Layer | What it is |
|-------|------------|
| **iOS** | SwiftUI app: capture, local storage, optional on-device LLM + TTS, API client |
| **Extension** | `ScreenTimeReport`: DeviceActivity → App Group |
| **Render** | Node/Express `retrospect-api.onrender.com`: REST + JWT + in-process cron |
| **Supabase** | Postgres (all tables) + Storage bucket `podcast-audio` |
| **External APIs** | Anthropic, OpenAI (embeddings + optional iOS chat), Perplexity, ElevenLabs, Google (Docs), Apple (Sign In, Speech, HealthKit, Screen Time) |

---

## 1. End-to-end relationship map (all major parts)

```
                              EXTERNAL SERVICES
    ┌─────────────┐ ┌─────────────┐ ┌──────────────┐ ┌─────────────┐ ┌──────────────┐
    │ Apple       │ │ Google      │ │ Anthropic    │ │ OpenAI      │ │ Perplexity   │
    │ Sign In     │ │ Sign-In +   │ │ Claude       │ │ Embeddings  │ │ Sonar Pro    │
    │ Speech      │ │ Drive API   │ │ (backend +   │ │ (backend +   │ │ (backend     │
    │ HealthKit   │ │ (read docs) │ │ optional iOS)│ │ optional iOS)│ │ podcast only)│
    │ FamilyCtrl  │ └─────────────┘ └──────────────┘ └─────────────┘ └──────────────┘
    └──────┬──────┘         ▲                ▲               ▲                ▲
           │                │                │               │                │
           │                │                └───────┬───────┴────────────────┘
           │                │                        │
           ▼                │                        ▼
┌──────────────────────────┴────────────────────────────────────────────────────────┐
│ iOS APP (SwiftUI) — Retrospect/Retrospect                                           │
│                                                                                     │
│  UI / flows                                                                        │
│  • Onboarding (incl. Sign in with Apple) → RetrospectAPIClient.signIn             │
│  • Home / journal / voice / video / podcast player / integrations                  │
│  • DarkAppContainer: hosts hidden DeviceActivityReport when Screen Time authorized │
│                                                                                     │
│  Local persistence                                                                 │
│  • FileStorageManager → entries, audio, video on disk                              │
│  • UserDefaults → goals, prefs                                                     │
│  • Keychain → JWT, user id, apple user id (via RetrospectAPIClient)                 │
│  • podcasts.json (or equivalent local cache) ← GET /podcasts                       │
│                                                                                     │
│  On-device processing                                                              │
│  • TranscriptionService (SFSpeechRecognizer) → text for voice/video                │
│  • AIServiceManager → ClaudeService / OpenAIService (titles, tags, transcript)    │
│  • HealthKitManager → weekly health string (not uploaded to Retrospect API)       │
│  • GoogleDocsService → recent doc text (not uploaded to Retrospect API)           │
│  • TranscriptViewModel.buildCombinedInput() → local podcast transcript path       │
│  • ElevenlabsService / TTS — on-device speech if used in flows                    │
│                                                                                     │
│  Screen Time path                                                                  │
│  • ScreenTimeService ← reads App Group UserDefaults (group.com.retrospect.shared)   │
│  • syncToBackend() → RetrospectAPIClient.uploadContent(screen_time, …)            │
└───────────────────────────────┬───────────────────────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
        ▼                       ▼                       ▼
┌───────────────┐     ┌─────────────────┐     ┌─────────────────────────────────────┐
│ App Extension │     │ HTTPS (JWT      │     │ Same app process                     │
│ ScreenTime    │     │ Bearer)         │     │ (no separate network)                │
│ Report        │     │                 │     │                                     │
│ TotalActivity │     │ Base URL:       │     │ PodcastNotificationService          │
│ Report        │     │ retrospect-api  │     │ → UNUserNotificationCenter (local)  │
│               │     │ .onrender.com   │     └─────────────────────────────────────┘
│ writes summary│     │                 │
│ to App Group  │     ▼                 │
└───────┬───────┘     ┌───────────────────────────────────────────────────────────────┐
                      │ RENDER — Node.js / Express (backend/)                         │
                      │                                                               │
                      │ Public: GET /health, POST /auth/*, /admin/* (secret)           │
                      │ JWT-protected: /content, /insights, /patterns, /analytics,     │
                      │   /goals, /pipeline, /podcasts, /profile                       │
                      │ Static: /dashboard (admin HTML)                               │
                      │                                                               │
                      │ In-process cron (node-cron) — same web process:                │
                      │   03:00 UTC daily  → daily patterns (insight_units)            │
                      │   04:00 UTC Sun    → weekly patterns + validation              │
                      │   05:00 UTC daily  → observations + goals insights pipeline    │
                      │   06:00 UTC Sun    → weekly podcast generation                 │
                      │ Note: render.yaml also defines Render Cron services — avoid    │
                      │ running duplicate schedules (web + separate cron) in prod.   │
                      │                                                               │
                      │ Services (call out to AI + DB):                                 │
                      │ • extraction.ts → insight_units (+ legacy connections)         │
                      │ • observations.ts + insight-synthesis.ts → observations,       │
                      │   insights                                                     │
                      │ • patterns.ts → patterns, pattern_insights                     │
                      │ • podcast-generation.ts → outline, research, script, TTS,      │
                      │   upload MP3, podcast_episodes row                             │
                      │ • goals routes → embeddings, Supabase goals                    │
                      └───────────────────────────────┬───────────────────────────────┘
                                                      │
                        ┌─────────────────────────────┼─────────────────────────────┐
                        │                             │                             │
                        ▼                             ▼                             ▼
               ┌────────────────┐            ┌────────────────┐            ┌─────────────────┐
               │ Supabase       │            │ Anthropic API  │            │ OpenAI API      │
               │ PostgreSQL     │            │ (Claude)       │            │ (embeddings,    │
               │ All app tables │            │                │            │  some iOS chat) │
               │ + vectors      │            └────────────────┘            └─────────────────┘
               └────────────────┘
                        │
                        ▼
               ┌────────────────┐            ┌────────────────┐
               │ Supabase       │            │ Perplexity     │
               │ Storage        │            │ (research)     │
               │ podcast-audio  │            └────────────────┘
               │ (MP3 URLs      │                    │
               │  in rows)      │                    ▼
               └────────────────┘            ┌────────────────┐
                                             │ ElevenLabs     │
                                             │ (backend TTS)  │
                                             └────────────────┘
```

---

## 2. Data flows (what talks to what)

### A. Auth

1. User completes Sign in with Apple in the app.
2. App → `POST /auth/signin` with `appleUserId` (+ optional email / identity token).
3. API validates / upserts `users`, signs JWT.
4. App stores JWT + ids in **Keychain**; sends `Authorization: Bearer …` on later calls.

### B. Journal / voice / video → backend memory (dual pipeline)

1. Capture on device → transcribe (if audio/video) → optional **AIServiceManager** metadata.
2. App → `POST /content` with `contentType` + `content` (+ optional `contentDate`).
3. API inserts **`raw_content`**, then **immediately** runs **legacy extraction** (Claude) → **`insight_units`**, embeddings/connections → **`insight_connections`**.
4. Separately, **daily cron** runs **goals pipeline**: chunk `raw_content`, embed match to **`goals`**, Claude → **`observations`**, embed, cluster, synthesize → **`insights`** (table `insights`, not `insight_units`).

### C. Goals

1. Onboarding / settings may use **`POST /goals/extract-and-save`** (transcript → Claude → goals + embeddings in Supabase).
2. Ongoing sync: app **`GET /goals`**, **`POST /goals`**, **`PATCH /goals/:id`** via `syncRichGoals`.

### D. Screen Time

1. **Extension** aggregates DeviceActivity → writes JSON summary to **App Group**.
2. **ScreenTimeService** in main app reads App Group, builds natural language, **`POST /content`** `screen_time`.

### E. Patterns (legacy graph)

1. **Daily / weekly cron** loads recent **`insight_units`**, Claude **`patterns.ts`** → **`patterns`** + **`pattern_insights`**.
2. App can **`GET /patterns`** etc. (see `patterns` routes).

### F. Backend podcast (server-generated)

1. **Weekly cron** or app **`POST /podcasts/generate`**.
2. Pipeline reads **`insights`**, **`observations`**, **`goals`**, relevant **`raw_content`**, **`users.voice_persona`**, prior episode.
3. Claude outline → Perplexity research → Claude script + metadata → ElevenLabs → **Supabase Storage** → **`podcast_episodes`** with `audio_url`.
4. App **`GET /podcasts`**, **`GET /podcasts/latest`**, plays audio from URL; **local notifications** fire from app.

### G. On-device podcast / transcript (parallel path)

1. **HealthKitManager** + **GoogleDocsService** + local reflections → **`buildCombinedInput`**.
2. **TranscriptViewModel** → **OpenAI or Claude** directly from the app (not stored as `raw_content` unless user also journals).
3. Optional local TTS — does **not** replace backend `podcast_episodes` unless you wire it that way in UI.

---

## 3. Backend route map (Express)

| Prefix | Auth | Role |
|--------|------|------|
| `/health` | No | Liveness |
| `/auth` | No | Sign-in, refresh |
| `/admin` | Admin secret | Ops dashboard |
| `/content` | JWT | Upload + process raw content |
| `/insights` | JWT | Legacy **insight_units** API |
| `/patterns` | JWT | Patterns |
| `/analytics` | JWT | Analytics |
| `/goals` | JWT | CRUD + extract-and-save |
| `/pipeline` | JWT | Observations / insights triggers & reads |
| `/podcasts` | JWT | List / latest / generate |
| `/profile` | JWT | Persona / profile |

---

## 4. iOS service index (typical responsibilities)

| Service | Responsibility |
|---------|----------------|
| `RetrospectAPIClient` | All Render REST calls, Keychain session |
| `FileStorageManager` | Local files for entries / media |
| `TranscriptionService` | Apple Speech → text |
| `AIServiceManager` | Routes on-device LLM tasks |
| `ClaudeService` / `OpenAIService` | Direct API calls from app |
| `ScreenTimeService` | Authorization, App Group read, upload |
| `HealthKitManager` | Health summaries for local transcript |
| `GoogleDocsService` | Google Drive read for local transcript |
| `PodcastNotificationService` | Local UN notifications |
| `ElevenlabsService` / `TTS` | Optional on-device voice output |

---

## 5. Optional Mermaid (for tools that render it)

```mermaid
flowchart LR
  subgraph ext [Apple ecosystem]
    SI[Sign in with Apple]
    SP[SFSpeechRecognizer]
    HK[HealthKit]
    FC[FamilyControls / DeviceActivity]
  end

  subgraph ios [iOS app]
    UI[SwiftUI views]
    FS[FileStorageManager]
    KC[Keychain JWT]
    APIc[RetrospectAPIClient]
    ST[ScreenTimeService]
    ODAI[AIServiceManager / Claude / OpenAI]
  end

  subgraph stExt [ScreenTimeReport extension]
    REP[TotalActivityReport]
    AG[(App Group UserDefaults)]
  end

  subgraph render [Render Express API]
    AUTH[/auth]
    CNT[/content]
    GOL[/goals]
    PIP[/pipeline]
    POD[/podcasts]
    CRON[node-cron jobs]
  end

  subgraph sb [Supabase]
    PG[(Postgres)]
    STOR[(Storage podcast-audio)]
  end

  subgraph ai [Third-party AI]
    AN[Anthropic]
    OA[OpenAI]
    PE[Perplexity]
    EL[ElevenLabs]
  end

  SI --> APIc
  SP --> UI
  HK --> ODAI
  UI --> FS
  UI --> APIc
  APIc --> KC
  FC --> REP --> AG --> ST --> APIc
  APIc -->|HTTPS JWT| AUTH
  APIc --> CNT
  APIc --> GOL
  APIc --> PIP
  APIc --> POD
  CNT --> PG
  GOL --> PG
  PIP --> PG
  POD --> PG
  POD --> STOR
  CRON --> PG
  CRON --> AN
  CRON --> OA
  CRON --> PE
  CRON --> EL
  render --> AN
  render --> OA
  ODAI --> AN
  ODAI --> OA
```

---

## 6. Files to read in-repo

- iOS API surface: [`Retrospect/Retrospect/Services/RetrospectAPIClient.swift`](../Retrospect/Retrospect/Services/RetrospectAPIClient.swift)
- API entry + cron: [`backend/src/index.ts`](../backend/src/index.ts)
- Deploy / health check: [`backend/render.yaml`](../backend/render.yaml)
- DB tables: [`supabase/migrations/`](../supabase/migrations/)
- Deeper ER + pipeline steps: [`docs/retrospect-data-model-and-pipeline.md`](retrospect-data-model-and-pipeline.md)

---

*Generated from the Retrospect repo structure; adjust if you add new routes or targets.*
