### UI3.0 · SamplePlayback                                           size: S
Place in the tree: journal › JR-2 › audio › sample playback (shared with podcasts and ON-11 later)
Repo · branch: NPRdoinglaundry · ui/UI3.0-sample-playback
Needs: `Platform/Flows/Playback.swift` (the integrator's protocol; plumbing builds the live AVPlayer side), T02        Unblocks: C25, C24, C23b, C22

Why: the player's every state (buffering, playing, failed, offline, ended) can be built and tested without audio files or a network.

Inputs:
- Plan: ui-engineer.md §4 (the playback row)
- Contract: 02 §3 (`Brief.parts[].startSeconds`, `audio.durationSeconds`); later 03 (chapters)

Spec:
- **`SamplePlayback`** (`Features/Player/Sample/`), `@MainActor @Observable`, conforms to `Playback`, initialised with `(scenario: PlaybackScenario, clock: any Clock<Duration>)`.
- Position advances on the injected clock at the playback rate. `seek(to:)` and `skip(by:)` clamp to [0, duration]. A buffered fraction is exposed for episodes (hidden for briefs).
- **Scenarios:**
  - `briefPaused` (3 parts, 2:10) · `briefPlaying` · `briefPlayed` · `briefQuiet` (one part, 0:40)
  - `buffering` (stays buffering) · `failed(.network)` · `offlineNotDownloaded` · `ended`
  - `long` (12 parts)
  - `shortUnderMinute` (forward skip is 15)
- Sample parts' text are invented brief lines, logged in the ledger.

Acceptance: every scenario is reachable through T02, and time never comes from the wall clock.

Tests:
- (unit) playing advances the position by one second per simulated second
- (unit) skip back 15 at 0:05 clamps to 0
- (unit) skip forward under one minute uses 15
- (unit) seek past the end ends playback
- (unit) a failed scenario never reports playing

Proof in the PR: test output; ledger rows.

Watch out: never play real audio in the sample, so no audio session is touched. The live side is plumbing's.
