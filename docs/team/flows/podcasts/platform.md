# Podcasts · Platform cards (client, live data, store, playback, push, retiring the old)

The app engineer's Platform cards for the podcasts area, in full byte-card form. Contract: [../../contracts/03-podcasts.md](../../contracts/03-podcasts.md). Rules from [app-plumbing-engineer.md](../../app-plumbing-engineer.md): `Platform/` only, actors for state that crosses threads, `@MainActor @Observable` for what views read, nothing throws to a view, no content in logs, every network path tested offline.

**Tree:** podcasts › playback (PLP.1a the engine, extracted from today's `StreamingPodcastPlayback` · PLP.1b the old screens play through it · PLP.2 lock screen and Control Center · PLP.3 back where you were) › live data (PL3.4a library · PL3.4b one episode · PL3.4c1 episode audio · PL3.4c2 offline copies · PL3.4d why this is here · PL3.4e feedback · PL3.4f a guess inside an episode) › ways in (PL3.4g links and the episode-ready tap) › retiring the old (X3.1 old podcasts on the phone · X3.2 old podcasts tab and its writers removed).

## 0. The seam: what the views call

The integrator writes `Platform/Flows/Podcasts.swift` from contract 03, and extends `Platform/Flows/Playback.swift`. If a need below isn't in the protocol, stop and ask; never add to it yourself. This table is the request.

| Screen need | Contract 03 | Shape the views expect |
|---|---|---|
| The library | §2 | `library: Loadable<PodcastsLibrary>` (`hero: EpisodeSummary?`, `upcoming: Upcoming`, `items: [LibraryItem]`), `loadMore() async`, `refresh() async` |
| One episode | §3 | `episode(id:) -> Loadable<Episode>` (an `@Observable` per id, cached) |
| Play it | §3, §8 | `play(_ item: PlayableItem, at: TimeInterval?)` on `Playback`, where `PlayableItem` is `.episode(Episode)` or `.brief(Brief)` |
| Chapters and lines | §3 | `Playback.chapters: [PlaybackChapter]`, `Playback.lines: [PlaybackLine]`, `Playback.currentLineIndex: Int?`, `Playback.currentChapterIndex: Int?` |
| Speed | — | `Playback.rate: Float`, `setRate(_:)` (the five steps live in the view; the engine clamps 0.5–2.0) |
| Offline copy | §8 | `download(episodeId:)`, `removeDownload(episodeId:)`, `downloadState(episodeId:) -> DownloadState` (`.none`, `.queued`, `.downloading(fraction)`, `.downloaded`, `.failed`) |
| Why this is here | §4 | `claim(episodeId:claimId:) -> Loadable<Claim>`, `moreEvidence(…) async` |
| A guess in the episode | §3 `guessId`, contract 02 §4 | `answer(guessId:verdict:) async -> GuessOutcome` (the journal's, shared) |
| Feedback | §5 | `sendFeedback(episodeId:verdict:text:given:) async` (state lands on `episode.feedback`) |
| A past brief | §6 | `brief(id:) -> Loadable<Brief>` |
| Online | contract 00 | `isOnline` |

`Playback` already carries `state` (`.idle`, `.buffering`, `.playing`, `.paused`, `.ended`, `.failed(Backend.Failure)`, `.offline`), `position`, `duration`, `parts`/`chapters`, `play()`, `pause()`, `seek(to:)`, `skip(by:)` (ui-engineer.md §4). The additions above are the request.

---

### PLP.1a · The live player engine, extracted from the player the app already has   size: L (split if it runs over: engine + state · session, interruptions + routes)
Place in the tree: product › platform › playback › `Media.Player` (shared by the brief, episodes, ON-11, and through PLP.1b the old screens)
Repo · branch: NPRdoinglaundry · `pl/PLP.1a-live-player`
Needs: PL0.3, `Platform/Flows/Playback.swift` (integrator), PL3.1b (`Media.Source` for briefs)      Unblocks: **the journal wiring PR (the brief plays for real: Beta 1)**, PLP.1b, PLP.2, PLP.3, PL3.4c1

Why: when you press play, the audio really plays, keeps playing with the screen off, pauses for a phone call, and stops when you pull your headphones out, like every good podcast app. There is exactly one engine in the app doing it.

**This card is a Beta 1 gap.** P10 and the journal wiring PR say "plumbing's live playback", but no Platform card builds it. The brief can't play on live data without it. It's written here because the episode player shares it; the integrator should add it to Beta 1 (see the README §6).

**What the app already has (read on `origin/main` `d87e3d3`, founder's note 21 Oct: reuse what's sound, don't build from scratch).** Nine places touch playback or the audio session. None of them handles interruptions, route changes, Now Playing or remote commands; two are real engines; the rest are views polling an `AVAudioPlayer` or one-off session setups.

| File | What it does well (extract) | What's missing or unsafe | Fate |
|---|---|---|---|
| `Views/Components/PodcastPlayer.swift` · `StreamingPodcastPlayback` (`:78-262`), `protocol PodcastPlayback` (`:63-73`) | **The soundest code here.** `AVPlayer` over a URL (streams remote and file URLs alike); session `.playback` + **`.spokenAudio`**, activated at play time, not at launch (`:119-120`); a 0.2 s periodic time observer on main (`:124-127`); an end-of-item observer tied to its item (`:128-133`); duration loaded async from the asset (`:134-139`); a cancellable volume fade (`fadeOutForPaywall`, `:170-197`: ON-12/M06 needs it); a silent "visual clock" when there's no audio yet (the onboarding tease, `:199-211`); clamped seek and skip; `@MainActor`. Its header already states the goal: "the single, shared podcast player" | no buffering or failed state (`isPlaying = true` the moment `play()` is called, `:141-142`); no interruption, route-change or media-reset handling; no Now Playing, no remote commands; no rate; never deactivates the session; `deinit` removes the time observer but **not the end observer** (`:254-256`); the duration `Task` captures `self` strongly; `try?` swallows session errors silently | **extracted into `Media.Player`** (item setup, observers, duration load, the fade, the visual clock); becomes a thin adapter in PLP.1b |
| `Views/DarkAppContainer.swift` · `DarkAudioManager` (`:14-140`) | the old app's live engine (podcasts tab, `DarkMiniPlayer`, `DarkAudioPlayerView`, teleprompter, featured card); a simple published state shape the old screens bind to (`currentTranscript`, `isPlaying`, `showMiniPlayer`, `showFullPlayer`, `lastError`); conforms to `PodcastPlayback` (`PodcastPlayer.swift:264-276`) | **`AVAudioPlayer`: local files only**, which is why the old code downloads every episode to `tmp/` first; session set in `private init` (the singleton is built at launch by `RetrospectApp`), so it grabs the session before anything plays; **`.mixWithOthers`** (`:33`): plays over the person's music, and an app that mixes **never becomes the Now Playing app**, so there are no lock-screen controls at all; never deactivates; no interruption handling, so after a phone call `isPlaying` stays `true` while the audio is stopped; `print`s file paths and transcript ids | **adapter over `Media.Player`** in PLP.1b (public API kept so old screens compile unchanged); deleted with the old tab in X3.2b |
| `Views/AudioPlayerView.swift` · `AudioSessionManager` (`:108-130`), view timer (`:849`) | deactivates the session when its screen closes (`:399`), the only code that ever does; `.notifyOthersOnDeactivation` | `.mixWithOthers` again; only reached through `AudioPlayerContainer`, which only `OptimizedHomeScreen` uses (no callers) | dead code: deleted in X3.2a |
| `Views/Components/AudioPlayerContainer.swift` · `AudioPlayerState` (`:5-44`) | — | `AVAudioPlayer`; configures the session **after** `play()` (`:16-20`); `.allowAirPlay` with `.playback` (that option only applies to `.playAndRecord`; a no-op here); `print`s errors | dead (only `OptimizedHomeScreen`): deleted in X3.2a |
| `Views/Components/OptimizedAudioPlayer.swift`, `Views/MiniPlayerView.swift` | — (views over a bound `AVAudioPlayer?`, polling it with 0.1 s `Timer`s, plus a 0.05 s gradient timer) | polling timers that keep running when off screen; no session; no callers | dead: deleted in X3.2a |
| `Views/Components/BottomMiniPlayer.swift` | — (a view over a bound `AVAudioPlayer?` with a 0.1 s timer) | only used by `HomeScreen` (dev settings) | deleted with `HomeScreen` in X3.2a |
| `Views/HomeScreen.swift` (`:296-308`, `:1715-1727`) | — | two different session setups on appear: `.playback` + `.allowAirPlay`, and `.playAndRecord` + `.defaultToSpeaker`; whichever screen appears last wins | dev-only: deleted in X3.2a |
| `Services/TTS.swift` · `TextToSpeechService` (`:4-30`) | on-device speech to a file (not a player; out of scope) | sets `.playback`/`.default` and **activates the session in `private init`**, i.e. at launch (every `TranscriptViewModel` init takes `.shared`), overriding whatever the player set | its session lines removed in PLP.1b (the synthesizer stays until first run retires it) |
| `Info.plist` `UIBackgroundModes` | `audio` is already on | — | kept |

Also touching the session, out of this card's scope but it must coexist with them: the voice recorders (`AudioRecordingManager.swift:112`, `BackgroundAudioRecordingManager.swift:56,107`: `.playAndRecord`) and `SpeechRecognizerManager.swift:47` (`.playAndRecord`, `.measurement`, `.duckOthers`). The journal's composer (#56) records while a brief might be playing.

Inputs:
- The protocol: `Platform/Flows/Playback.swift`; UI3.0's `SamplePlayback` (the behaviour to match on the same scenarios)
- The table above (extract from `PodcastPlayer.swift`; take nothing from the others)
- Design: player.md "Leaving the app", design-reference §C23 edge cases (phone call pauses and resumes only on tap; headphones removed pause)

Spec:
- `Platform/Media/Player.swift`: `@MainActor @Observable final class LivePlayback: Playback` over one `AVPlayer`, one instance for the app, built by `Platform.Environment`. Everything else in the app plays through it (PLP.1b).
- **Extracted from `StreamingPodcastPlayback`** (moved, not copied; its file keeps only the adapter after PLP.1b): item creation, the periodic observer (0.25 s), the per-item end observer, the async duration load (with `[weak self]`), the cancellable volume fade (exposed as `fadeOut(over:)` for M06), and the silent visual clock (exposed as `PlayableItem.silent(duration:)` for the tease before its audio exists). Each moved piece keeps a test.
- **Added (none of the existing code does these):**
  - **State:** `.waitingToPlayAtSpecifiedRate` → `.buffering`; a failed item → `.failed(.network | .unplayable)`; no network and no local file → `.offline`; `isPlaying` only from `timeControlStatus == .playing`, never set optimistically.
  - **Session:** category `.playback`, mode `.spokenAudio`, `routeSharingPolicy: .longFormAudio` (AirPlay 2 and the long-form audio route), **no `.mixWithOthers`** (so the app becomes the Now Playing app and pauses other audio, like a podcast app); set before **every** `play()` (a recorder may have switched to `.playAndRecord` in between), activated on first play, never at launch, deactivated with `.notifyOthersOnDeactivation` after pause has lasted 5 minutes or on stop. Session errors are logged as counts, never swallowed.
  - **Interruptions:** `.began` → pause, remember "was playing"; `.ended` → **don't resume on its own** (founder rule: resume only on tap), even with `.shouldResume`.
  - **Route change:** `.oldDeviceUnavailable` (headphones out) → pause.
  - **Media services reset:** rebuild the player and restore the item at its position.
  - **Recording:** when the composer starts recording (the journal's recorder posts its existing start), the player pauses first; it never resumes on its own.
  - **Rate:** `setRate(_:)` (`AVPlayer.rate` while playing, `defaultRate` while paused; `audioTimePitchAlgorithm = .timeDomain` for speech).
  - **End:** `.ended`; the item stays loaded (replay from the start).
  - **Teardown:** both observers removed whenever the item changes and in `deinit`.
- **Loading:** `play(_ item:, at:)` asks `Media.Source` for a playable URL (local file first, else a signed link valid for the remaining time; PL3.4c1), creates the `AVPlayerItem`, seeks to `at` (or the remembered position, PLP.3) before playing. Local files (including the old app's `Documents/reflection_*.mp3`) and remote links go through the same path, so nothing has to be downloaded before playing.
- **Position:** `position`; `currentLineIndex` and `currentChapterIndex` derive from line/chapter starts (binary search, unit-tested), never from wall time.
- **Commands:** `play`, `pause`, `seek(to:)` (tolerance zero only on release from the scrubber; ±0.5 s for skips), `skip(by:)` (+30 / −15; +15 when duration < 60 s).
- Naming: the module already has `AudioPlayer`, `PodcastPlayback` and `AudioSessionManager` at top level (app-reference §15); the new types live under `Media` and don't reuse those names.
- Threading: AVFoundation callbacks hop to the main actor; no blocking work on main. Logs carry no URL, path or title.

Steps: move the `StreamingPodcastPlayback` internals behind `Media.Player` (with their tests) → state mapping → session rules → interruptions, routes, reset, recording → rate and teardown → tests.

Acceptance:
- The brief and an episode play from a local file and from a signed link; the screen locking doesn't stop them.
- A simulated phone call pauses; ending it doesn't resume until play is tapped.
- Unplugging headphones pauses.
- Another app's music stops when ours starts (no mixing).
- Each of UI3.0's scenarios has the same visible state sequence on `LivePlayback` (driven by a fake `AVPlayer` seam).
- The fade and the silent clock behave exactly as they did in `StreamingPodcastPlayback` (the paywall flow is unchanged).

Tests (layer 5, a protocol seam over `AVPlayer` and `AVAudioSession` with fakes):
- "waiting to play maps to buffering, then playing" (never playing before the player says so)
- "an interruption pauses and its end never resumes on its own"
- "losing the headphone route pauses"
- "the session is playback, spoken audio, long-form, never mixing, and set before every play"
- "the session is activated on first play, not at launch"
- "starting a recording pauses playback"
- "skip forward under one minute moves fifteen seconds"
- "seeking past the end ends playback"
- "the current line follows the position across chapter gaps" (binary search over starts)
- "rate changes keep the pitch and survive pause and play"
- "a failed item reports failed, never playing"
- "with no network and no file, the state is offline"
- "changing items removes both observers" (the old engine leaked the end observer)
- "the fade lowers the volume to zero over its duration, then pauses" (moved test)
- "a silent item advances on the injected clock" (moved test)

Proof in the PR: test output; the moved-lines map (old file:line → new file); a recording on the integrator's simulator (headless, `simctl io`) of a brief playing on local staging, then a simulated interruption.

Watch out: never keep two `AVPlayer`s; never touch the session from a view. Don't copy the old `try?` and `print` habits. `.mixWithOthers` is the reason today's app has no lock-screen controls: don't carry it over.

---

### PLP.1b · The old screens play through the one engine                       size: M
Place in the tree: product › platform › playback › old engines become adapters
Repo · branch: NPRdoinglaundry · `pl/PLP.1b-one-engine`
Needs: PLP.1a      Unblocks: Beta 1 (new journal + old podcasts tab in one build), PLP.2 for the old screens too, X3.2

Why: whatever you play, in the new journal or the old podcasts tab, there's one player behind it: starting one stops the other, the lock screen works for both, and a phone call pauses both the same way.

Inputs: PLP.1a's table; `Views/DarkAppContainer.swift:14-140` (`DarkAudioManager`), `Views/Components/PodcastPlayer.swift:78-276` (`StreamingPodcastPlayback`, `DarkAudioManager: PodcastPlayback`), `Services/TTS.swift:11-30`; callers of `DarkAudioManager.shared` (`RetrospectApp.swift`, `DarkMiniPlayer`, `DarkAudioPlayerView`, `DarkPodcastsView`, `DarkFeaturedPodcastCard`, `DarkTeleprompterView`) and of `StreamingPodcastPlayback` (`PodcastPaywallFlow`, the onboarding finale); the frozen-old-code rule (bridges only, every touched line listed in the PR and the findings log)

Spec:
- **`DarkAudioManager` becomes an adapter** over `Media.Player`, keeping its public surface (`currentTranscript`, `isPlaying`, `showMiniPlayer`, `showFullPlayer`, `lastError`, `showTranscript`, `playPodcast`, `togglePlayback`, `stopPlayback`, `seekTo`, and the `audioPlayer`-based `PodcastPlayback` conformance rewritten to read `Media.Player`'s position and duration). Its `AVAudioPlayer`, `configureAudioSession()` and the `init`-time session setup are removed. `isPlaying` mirrors the engine, so it's correct after a phone call. A `TranscriptModel` with a remote `audioFileURL` now plays directly (no `tmp` download needed); with a local file, the same.
- **`StreamingPodcastPlayback` becomes an adapter**: same initializer and API (`start`, `stop`, `pauseForPaywall`, `fadeOutForPaywall`, `didFinish`, the `PodcastPlayback` members) forwarding to `Media.Player` (`fadeOut(over:)`, `.silent(duration:)`). The paywall flow and the onboarding finale don't change.
- **`TextToSpeechService`** stops setting and activating the session in `init`; it sets `.playback` only around its own synthesis and leaves the session to the engine otherwise.
- `AudioPlayerState`, `AudioSessionManager`, the unused views and `HomeScreen`'s setups aren't touched here (no live callers): X3.2a deletes them.
- Result: a grep of the app target finds `AVPlayer(` and `setCategory(.playback` only in `Platform/Media/` (recorders and the speech recognizer keep `.playAndRecord`, which the engine already copes with).

Acceptance: new then old, old then new: exactly one is ever audible; both mini-players reflect paused; a phone call during the old tab's playback leaves its play button showing play; the onboarding paywall tease and its fade behave as before; the old tab plays a server episode without downloading it first.

Tests:
- "the old manager's play goes through the one engine and stops the new player's item"
- "the new player's play stops what the old manager was playing"
- "after an interruption the old manager reports not playing"
- "the old streaming player's fade still ends paused at full volume" (the paywall)
- "no session is configured at launch" (fake session, app start path)
- "only Platform/Media creates an AVPlayer or sets the playback category" (a source-scan test)

Proof in the PR: test output; the list of old-code lines changed; a headless recording on local staging of both sequences and of the paywall tease.

Watch out: X3.2b deletes `DarkAudioManager` with the old tab; don't build anything new on the adapters. The old screens bind to `@Published` properties on an `ObservableObject`: the adapter republishes from the `@Observable` engine on the main actor; test that the old mini-player updates.

---

### PLP.2 · Lock screen, Control Center and headphones                      size: M
Place in the tree: product › platform › playback › Now Playing (`Media.NowPlaying`)
Repo · branch: NPRdoinglaundry · `pl/PLP.2-now-playing`
Needs: PLP.1a, #42 (`RArtwork`, to render the artwork image)      Unblocks: P35 (EX-2), the "audio continues" acceptance on P10 and P14

Why: you can pause, skip and see what's playing from the lock screen, Control Center, your AirPods and CarPlay audio, with the part or chapter being spoken as the title.

Inputs: design-reference §C40 (EX-2: title = the part being spoken; subtitle "retrospect · tuesday's brief · part 2 of 3"), §C22 lock-screen notes; Paper EX-2 `1H2J-0` (`c:icon/skip-back-15` `1H2T-0`, pause `1H2R-0`, `skip-forward-30` `1H2P-0`); contract 03 §3 (chapters), 02 §3 (parts)

Spec:
- `Platform/Media/NowPlaying.swift`: updates `MPNowPlayingInfoCenter.default().nowPlayingInfo` on item change, chapter or part change, rate change, seek and pause: `MPMediaItemPropertyTitle` = the current chapter title (episodes) or part's first words ≤ 40 chars (briefs); `MPMediaItemPropertyArtist` = "retrospect"; `MPMediaItemPropertyAlbumTitle` = "this week's episode · chapter 2 of 5" / "tuesday's brief · part 2 of 3" (lowercase, founder Q-14 lean); duration, elapsed, rate, `MPNowPlayingInfoPropertyMediaType = .audio`; artwork = the item kind's `RArtwork` mesh rendered once to a 600×600 image (`ImageRenderer`, cached per kind and appearance).
- `MPRemoteCommandCenter`: play, pause, togglePlayPause, `skipBackwardCommand` (15), `skipForwardCommand` (30), `changePlaybackPositionCommand`, `changePlaybackRateCommand` (0.8, 1.0, 1.25, 1.5, 2.0); next/previous track disabled (chapters aren't tracks: lean, to keep the lock screen like EX-2).
- Cleared when nothing is loaded and on sign-out.
- Privacy: titles are chapter titles (craft, not claims) or the brief's opening words. They show on the lock screen while something plays, as EX-2 draws; EX-3's "private by default" rule covers notifications, not Now Playing. Listed for the founder in the PR.

Acceptance: the lock screen shows title, chapter, artwork, scrubber and ↺15 ‖ 30↻; every control works; the title changes when the chapter does.

Tests: "now playing shows the chapter being spoken and changes with it" · "a brief shows its part number" · "skip commands move 15 and 30 seconds" · "scrubbing on the lock screen seeks" · "sign-out clears now playing" (fakes over the two centres).

Proof in the PR: test output; a simulator screenshot of the lock screen next to Paper `1H2J-0`.

Watch out: update `nowPlayingInfo` from the main actor only and not every frame (on change, plus elapsed on pause/seek; the system extrapolates while playing).

---

### PLP.3 · Back where you were                                               size: S
Place in the tree: product › platform › playback › positions (store)
Repo · branch: NPRdoinglaundry · `pl/PLP.3-positions`
Needs: PLP.1a, PL2.1      Unblocks: P14 "closing and reopening keeps the position", the mini-player after relaunch, C27 played state

Why: close the app mid-episode and it opens with the mini-player where you left off; finish an episode and it reads as played.

Spec:
- Store migration **v3** (request to the integrator: PL2.1 owns v1, PL2.6 v2) adds `playback_positions (item_kind TEXT, item_id TEXT, position REAL, duration REAL, finished_at TEXT NULL, updated_at TEXT, PRIMARY KEY (item_kind, item_id))` and `episodes_cache` and `downloads` (PL3.4b, PL3.4c2 use them; one migration, three tables).
- Saved every 5 s while playing, on pause, on seek, on background; `finished_at` set when within 15 s of the end or ended. `LivePlayback` restores the last loaded item paused at its position on launch (no audio session until play).
- Local only (founder Q-11 lean: no cross-device sync in v1).
- Wiped on sign-out (PL1.5's erase list gains these tables).

Tests: "the position is restored paused after relaunch" · "an episode within fifteen seconds of the end is played" · "sign-out erases positions" · "writes are throttled to one per five seconds while playing" (injected clock).

Proof in the PR: test output.

---

### PL3.4a · The library on real data                                        size: M
Place in the tree: product › podcasts › live data › library (`LivePodcastsData`)
Repo · branch: NPRdoinglaundry · `pl/PL3.4a-podcasts-library`
Needs: PL2.4, PL1.5, `Platform/Flows/Podcasts.swift` (integrator), contract 03 fixtures, backend BE3.4b (live), BE3.6      Unblocks: P13 on live data, the podcasts wiring PR (integrator)

Why: the podcasts tab opens instantly with what you saw last, even offline, and quietly fills in this week's episode.

Inputs: contract 03 §1, §2, §6; PL2.4 (`CachedRead`, `Loadable`); PL3.1 (the pattern)

Spec:
- `Platform/Repositories/Podcasts.swift` (actor): `library(cursor:)`, `brief(id:)` endpoints (PL1.1 typed routes `Routes.Podcasts.library`, `Routes.Briefs.byId`).
- `Platform/Flows/LivePodcastsData.swift`: `@MainActor @Observable final class LivePodcastsData: PodcastsData`. `library` from `CachedRead` key `podcasts.library` (5 min) for the first page; later pages appended in memory (not cached). `refresh()` on appear and on `.active`; `loadMore()` single-flight, stops at `nextCursor == nil`.
- `LibraryItem.unknown` and unknown enum values are dropped from `items` and logged as counts (`unknownLibraryItem`).
- `brief(id:)` → `Loadable<Brief>` (no cache: opening a square fetches it with its fresh audio link; offline → `.failed(.offline, cached: nil)` unless the brief's audio is downloaded, PL3.4c2).
- `isOnline` mirrors `Backend.Reachability`.

Acceptance: running with `-Data live -Environment local` (T02a), PC-1 shows the seeded account's episodes and briefs; offline shows the cache marked as cached.

Tests (layer 4: every `fixtures/03/podcasts.library*.json` and `brief.byid.json` decodes; layer 5): "the cached library shows before the fetch completes" · "load more appends the next page and stops at the end" · "two load-mores at once fetch once" · "unknown items are dropped and counted" · "offline with a cache shows the cache as cached" · "a quiet week maps to the quiet upcoming state".

Proof in the PR: test output; a local-staging recording (integrator, test account).

Watch out: never cache `audio.url` as playable (PL2.4's rule); briefs here come without audio in the list.

---

### PL3.4b · One episode on real data, kept on the phone                      size: M
Place in the tree: product › podcasts › live data › one episode
Repo · branch: NPRdoinglaundry · `pl/PL3.4b-episode`
Needs: PL3.4a, PLP.3 (store v3), BE3.5      Unblocks: P14 on live data, PL3.4c1, PL3.4d

Why: an episode you've opened once opens again instantly, words and chapters included, on a plane.

Spec:
- `episode(id:)` → `Loadable<Episode>`: `episodes_cache (id TEXT PK, body BLOB /* the contract JSON minus audio */, fetched_at TEXT)`; stale after 24 h (episodes don't change once made, except `feedback`), refreshed on open when online.
- Maps contract types to `Playback` inputs: `PlaybackChapter(index, title, start)` only when `timing == measured`; `PlaybackLine(index, text, chapterIndex, start?, register, claimId?)`.
- `not_found` → the cached copy, its download (PL3.4c2) and its position are deleted; the view gets `.failed(.notFound)` ("that episode isn't here any more").

Tests (layer 4: `episode.v2.json`, `episode.legacy.json`, `episode.noaudio.json` decode): "an opened episode reads from the phone offline" · "estimated timing produces no chapters" · "a legacy episode becomes plain lines" · "not found removes the cached copy, download and position" · "the audio link is never stored".

Proof in the PR: test output.

---

### PL3.4c1 · Episode audio: private links that never run out mid-listen       size: M
Place in the tree: product › podcasts › live data › audio (`Media.Source` for episodes)
Repo · branch: NPRdoinglaundry · `pl/PL3.4c1-episode-audio`
Needs: PL3.1b (`Media.Source`), PLP.1a, PL3.4b, BE3.5, BEA.7      Unblocks: PL3.4c2, P14 playing on live data

Why: a 10-minute episode paused for two hours still plays when you come back, even though its link expired.

Spec:
- `Media.Source.playableURL(for: .episode(id))`: a downloaded file if present (PL3.4c2); else the cached episode's link if it has ≥ remaining ÷ rate + 5 min left; else re-fetch `GET /v2/episodes/:id` (no cache write of the link) and use the new one.
- **Renewal mid-play:** `LivePlayback` asks `Media.Source` for a fresh URL when an item fails with an HTTP 400/403 from storage (expired signature) or when resuming after the link's `expiresAt`, swaps the item at the same position (`replaceCurrentItem`, seek before play), and keeps `state` at `.buffering` (no visible failure). Two renewals failing in a row → `.failed(.network)`.
- Never logs a URL (they're secrets while valid).

Tests: "a link with too little time left is replaced before playing" · "an expired link mid-play is renewed at the same position without a failure state" · "a downloaded file is preferred over any link" · "two failed renewals report failed" · "no log line contains a link" (scan the sink).

Proof in the PR: test output; on local staging with a 2-minute TTL override (staging only), a recording of pause → expiry → resume.

Watch out: signed URL tokens are in the query string: `AVURLAsset` caches by URL, so a renewed URL is a new asset; carry the position across, never the asset.

---

### PL3.4c2 · Offline copies                                                  size: M
Place in the tree: product › podcasts › live data › downloads (`Media.Downloads`)
Repo · branch: NPRdoinglaundry · `pl/PL3.4c2-downloads`
Needs: PL3.4c1, PLP.3 (store v3)      Unblocks: C20-p download rows, P14 offline state, T05a offline step

Why: this week's episode is on your phone before your flight without you doing anything, and you can keep any other one too (founder Q-1, lean A).

**Today's app** has no offline downloads: audio is only moved to `tmp/podcast_<id>.mp3` (purgeable) after an on-device generation (`Transcriptviewmodel.swift:574-618`), and backend episodes play from their remote link. So this is new behaviour, built on the lean.

Spec:
- `Platform/Media/Downloads.swift` (actor): a background `URLSession` (`isDiscretionary = false`, `sessionSendsLaunchEvents = true`) per app; `downloads (episode_id TEXT PK, state TEXT, file TEXT NULL, bytes INT, requested_by TEXT /* auto|person */, updated_at TEXT)`.
- Files in `Application Support/Platform/audio/episodes/<id>.mp3`, `isExcludedFromBackup = true`, file protection `completeUntilFirstUserAuthentication` (plays from the lock screen).
- **Auto:** when the library shows a new `hero` that isn't downloaded, queue it with `allowsCellularAccess = false` (Wi-Fi only) and `requested_by = auto`; keep at most the 2 newest auto copies (older auto copies removed; person-requested copies stay until removed).
- **By hand:** `download(episodeId:)` / `removeDownload(episodeId:)` from the "…" menu; Wi-Fi or cellular (the person asked), states `queued → downloading(fraction) → downloaded | failed`.
- A link that expires mid-download is renewed (PL3.4c1) and the download resumes from resume data.
- Disk floor: skip auto downloads under 500 MB free (logged).
- Removed on sign-out and when an episode is `not_found`.

Acceptance: the newest episode is downloaded on Wi-Fi without a tap; airplane mode plays it; a downloaded episode the person removes is gone from disk.

Tests: "a new hero downloads itself on wi-fi only" · "only the two newest auto copies are kept" · "a person's download survives auto clean-up" · "an expired link mid-download resumes with a fresh link" · "sign-out deletes every file" · "files are excluded from backup" · "under the disk floor nothing downloads on its own".

Proof in the PR: test output; airplane-mode playback recording on the simulator (integrator).

Watch out: background sessions deliver completions after relaunch: rebuild the session with the same identifier in `application(_:handleEventsForBackgroundURLSession:)` (an AppDelegate bridge line: the integrator's shell; ask).

---

### PL3.4d · Why this is here on real data                                    size: S
Place in the tree: product › podcasts › live data › claims
Repo · branch: NPRdoinglaundry · `pl/PL3.4d-claims`
Needs: PL3.4b, BE3.1b      Unblocks: P15 on live data

Spec: `claim(episodeId:claimId:)` → `Loadable<Claim>` via `CachedRead` key `claim.<episodeId>.<claimId>` (1 h); `moreEvidence` pages in memory. `opens` maps to `Routing.Destination` (`.entry(id)` for entries; records produce no destination until YO-3 exists). `correct` passes straight to the journal's `correct(text:about:)` (shared corrections, contract 02 §6).

Tests (fixtures `claim.*.json`): "a stated claim maps its sureness and evidence" · "an asked claim with a guess carries the guess" · "evidence pages append without repeats" · "records open nothing yet" · "offline shows the cached claim".

Proof in the PR: test output.

---

### PL3.4e · Feedback that's never lost                                        size: S
Place in the tree: product › podcasts › live data › feedback (outbox)
Repo · branch: NPRdoinglaundry · `pl/PL3.4e-feedback`
Needs: PL2.2 (outbox), PL3.4b, BE3.2b      Unblocks: UI5.4 on live data

Spec: `sendFeedback` enqueues outbox operation `episode.feedback` (key = a new UUID stored with it) and sets `episode.feedback` at once (optimistic, `.waiting`); drained like entries (PL2.2b), `idempotency_mismatch` → logged and dropped (a bug), `not_found` → dropped (episode gone). Voice feedback sends the transcript only (`given: voice`), never audio.

Tests: "feedback offline waits and is sent once when back online" · "a retried feedback is one row" (fake server) · "feedback text never appears in a log line".

Proof in the PR: test output.

---

### PL3.4f · A guess inside an episode                                          size: S
Place in the tree: product › podcasts › live data › guesses (shared with the journal)
Repo · branch: NPRdoinglaundry · `pl/PL3.4f-episode-guess`
Needs: PL3.1c (journal guesses), PL3.4b      Unblocks: C23e.3 on live data

Spec: lift PL3.1c's guess answering into `Repositories.Guesses` (if PL3.1c didn't already) so `LivePodcastsData.answer(guessId:verdict:)` and the journal share one outbox operation and one optimistic state. A guess answered in the journal shows as answered in the episode and the other way round (state keyed by guess id). `speaking == false` (contract 02) → no guess card is offered; the line stays in the transcript as an asked line. (The brain never writes a hypothesis into a script while `speak` is off, so this only matters for an older episode made while the dial was on.)

Tests: "answering in the episode updates the journal's guess" · "a repeat answer returns the stored status" · "with speaking off, no guess card is offered".

Proof in the PR: test output.

---

### PL3.4g · Links into podcasts, and the episode-ready tap                      size: S
Place in the tree: product › podcasts › ways in (router)
Repo · branch: NPRdoinglaundry · `pl/PL3.4g-podcasts-routes`
Needs: PL5.2 (router), PL5.3 (taps; phase 2), PL3.4b      Unblocks: T05a's deep-link steps, BE3.3b end to end

Spec: `Routing.Destination` gains `.podcasts`, `.episode(id: UUID, at: TimeInterval?)`, `.episodeClaim(episodeId: UUID, claimId: UUID)`; the parser maps `retrospect://podcasts…` and `/podcasts/episodes/<id>` (push `path`) per contract 03 §9; invalid ids → `.podcasts` and a log count. The `episode.ready` category's tap routes to `.episode(id)`; the destination opens the player paused (never auto-plays from a notification). `ShowPodcastFromNotification` stays as the old bridge until X3.2.

Tests: "every podcasts link parses to its destination" · "a malformed id falls back to the podcasts tab" · "the episode-ready tap opens that episode paused" (fixture `push.episode-ready.json`).

Proof in the PR: test output.

---

### X3.1 · The old podcasts on this phone, carried over once                  size: M
Place in the tree: product › platform › local store › retiring the old store › podcasts.json
Repo · branch: NPRdoinglaundry · `pl/X3.1-legacy-podcasts`
Needs: PL2.6 (the importer and ledger), PLP.3 (store v3), PL3.4b      Unblocks: X3.2, X06 (deleting `podcasts.json`)

Why: episodes you have on this phone today are still there after the switch: server episodes keep where you were in them, and episodes the old app made on the phone stay listenable (founder Q-9, lean A).

Inputs: app-reference §7 (`Documents/podcasts.json`, `[TranscriptModel]`, ISO dates, `audioFileURL` absolute or remote, `backendEpisodeId`; on-device ElevenLabs audio at `Documents/reflection_<epoch>.mp3`; downloaded server audio at `tmp/podcast_<id>.mp3`)

Spec:
- `Store.LegacyImport` gains a `podcasts` step: decode `podcasts.json` with a private `LegacyTranscript` mirror (never the old type), ledger source `podcasts.json`, checksum of the file bytes, the same two-launch confirm.
- Rows with `backendEpisodeId` (or an id that matches a server episode) → nothing to import but their listening position if the old app stored one (it doesn't today: recorded as zero); no copy of their audio (the server has it).
- Rows without a server id (made on the phone) → `legacy_episodes (local_id TEXT PK, title TEXT, text TEXT, audio_file TEXT NULL, created_at TEXT)`; audio re-resolved by file name under `Documents/` (`reflection_*.mp3`), never the stored absolute URL; `tmp/` files are ignored (purgeable, and the server has those).
- Counts only in the log (`legacyPodcasts(imported:, server:, unreadable:)`).
- The views show `legacy_episodes` as "made on this phone" squares at the end of the library (UI5.0 scenario `legacyOnPhone`), playable, no chapters, no PC-3.

Tests (invented fixture files): "server episodes are recognised and not copied" · "an on-phone episode is imported once with its audio found by name" · "a missing audio file imports the words only" · "running twice imports nothing new" · "the old file is byte-identical afterwards".

Proof in the PR: test output.

Watch out: eleven `TranscriptViewModel` instances can rewrite `podcasts.json` while the old tab still runs: the two-launch confirm catches a changed file and re-imports; never read it while a write is half done (read into memory, decode, compare checksum, and skip this launch on a decode error).

---

### X3.2 · The old podcasts tab and its writers, removed                       size: M (one PR per group below)
Place in the tree: product › retiring the old › podcasts
Repo · branch: NPRdoinglaundry · `pl/X3.2a-dead-podcast-writers`, `pl/X3.2b-old-podcasts-tab`, `pl/X3.2c-old-podcast-reminders`
Needs: (a) none beyond the founder's go; (b) ship gate G3 passed, X3.1 confirmed on the founder's phone and in TestFlight, the podcasts switch on for everyone; (c) BE3.3b live      Unblocks: X06, X07 (the bucket can go private and the old routes can go)

Why: one podcasts tab, one copy of every episode, one Sunday notification.

**The writers of `podcasts.json` today** (every `TranscriptViewModel` init loads it, fetches `GET /podcasts`, and any save rewrites the whole file: last writer wins):

| Site | Reachable? | Goes in |
|---|---|---|
| `Views/DarkAppContainer.swift:142` (`@StateObject`, the live app; also `:1177` `savePodcast` from the settings agent-podcast test) | yes | X3.2b |
| `Views/DarkPodcastsView.swift:540` (inline) | yes (old podcasts tab) | X3.2b |
| `Views/DarkSettingsView.swift:1201` | yes (settings) | X3.2b |
| `Services/FirstPodcastOrchestrator.swift:60-61` (`savePodcast`) | yes (old first run) | after G1 (first run's new flow), with first run's retirement: listed for that planner |
| `Views/HomeScreen.swift:20`, `:1412` (`LegacyHomeScreen`, `MinimalHomeScreen`) | only from dev settings (`AdvancedSettingsView:152-155`, `DarkSettingsView:1543`) | X3.2a |
| `Views/OptimizedHomeScreen.swift:9` | no callers | X3.2a |
| `Views/PolaroidHomeView.swift:8`, `Views/Components/PolaroidPlayingControls.swift:237` | only from appearance settings (`AppearanceSettingsView:127`) | X3.2a |
| `Views/Components/TransformingLoadingPill.swift:204`, `Views/Components/DarkLoadingPill.swift:100` | previews only (still construct the model and touch disk in preview) | X3.2a |

Spec:
- **(a) Dead and dev-only writers** (no user-facing change; founder go): delete `OptimizedHomeScreen`, the Polaroid home and controls, `LegacyHomeScreen`/`MinimalHomeScreen` and the dev settings rows that open them, and the two previews' model construction. Five of the eleven writers gone. With them go the dead players PLP.1a's table lists: `AudioPlayerContainer` + `AudioPlayerState`, `AudioPlayerView` + `AudioSessionManager`, `OptimizedAudioPlayerView`, `MiniPlayerView` and `BottomMiniPlayer` (no live callers; each one's last caller is in this deletion).
- **(b) The old podcasts tab:** after G3, delete `DarkPodcastsView`, `DarkPodcastCard`, `DarkFeaturedPodcastCard`, `FullscreenPodcastCard`, `NewPodcastArrivalView`, the `ShowPodcastFromNotification`/`PlayPodcast` routing (`RetrospectApp.swift:292-338`) and `TranscriptViewModel`'s podcast persistence (`savePodcast`, `deletePodcast`, `savePodcastsToDisk`, `loadSavedPodcasts`, `fetchBackendPodcasts`); `DarkAudioManager` (by then PLP.1b's adapter) goes with the last old player screen. What remains of `TranscriptViewModel` (on-device generation used by the old first run) stays until first run retires it.
- **(c) Old reminders:** stop scheduling `weekly-reflection-reminder` (Sunday 10:00) and `midweek-checkin` (`PodcastNotificationService.swift:218-283`), and remove pending ones once, on the first launch of the build that has the new push (so nobody gets two Sunday notifications).
- `podcasts.json` itself is deleted by X06 after `LegacyImport.Report.confirmed` and the founder's go.

Acceptance: a build with no `TranscriptViewModel` podcast persistence, no old podcasts tab and no local Sunday reminder; grep finds no `podcasts.json` writer.

Tests: "no code path writes podcasts.json" (a test that greps the app target's sources) · "pending old reminders are removed once" · the T05a flow test passes with the old tab gone.

Proof in the PR: the deleted-lines count per group; T05a output.

Watch out: old app versions in testers' hands keep calling `GET /podcasts` and playing its links: BE3.8 keeps them working until the version floor (BE0.10) passes; only then X07 and the private bucket.
