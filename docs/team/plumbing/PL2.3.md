### PL2.3 · Bridge: the old screens' entries go through the outbox          size: S
Place in the tree: product › platform › local store › bridges › EntryManager
Repo · branch: NPRdoinglaundry · pl/PL2.3-entrymanager-bridge
Needs: PL2.2, backend BE1.1 live on the environment the build talks to      Unblocks: X06; the journal ship gate (old and new screens send the same way)

Why: entries written on today's screens stop vanishing when the upload fails; they're kept and sent once, like the new journal's.

Inputs:
- Reference: app-reference.md §5.2 (`EntryManager.addEntry` `:111-123`, `syncEntryToBackend` `:126-147`, the 13 `addEntry` call sites), §5.4 (the stale comment at `VoiceRecordingView.swift:357-358`), §5.1 (`EntryType` text, voice, video).

Spec:
- `Platform/Bridges.swift` (from PL1.5) gains `static var entryAdded: (@MainActor (Entry) -> Bool)?`, set by `Platform.Environment.live()` once the session is signed in on v2 and the outbox exists; it returns `true` when the entry was taken.
- The closure maps the old `Entry`: `id` → `EntryDraft.id` (the old UUID becomes the outbox key, so there's one id end to end); `content` → `text`; `date` → `createdAt`; `type` → `kind` (`text` → `typed`; `voice` → `voice`; `video` → `voice`, because what's sent is the spoken transcript; logged as `videoSentAsVoice` until contract 02 adds a video kind); `audioURL` → `mediaPath` made relative to the container. Empty text is not taken (same rule as today).
- The edit, at `EntryManager.syncEntryToBackend` `:126-147` only: before the old guards, `if Platform.Bridges.entryAdded?(entry) == true { return }`. If the bridge isn't set (not signed in on v2 yet, or an old build path), the old code runs exactly as today. `resyncAllEntriesToBackend` (`:151-182`, a developer button) is untouched and gets a doc comment saying it sends without keys and can duplicate.
- Fix the stale comment at `VoiceRecordingView.swift:357-358` to say what's true: "addEntry sends it once, through the outbox, keyed by the entry id."
- Local saving (`FileStorageManager`) is unchanged: old screens keep reading their JSON files.

Steps: closure + mapping → one-line hook → comment fix → tests.

Acceptance: an entry written on an old screen while offline reaches the backend once after reconnecting (the integrator verifies on local staging); with the bridge unset, behaviour is byte-for-byte the old path.

Tests (layer 5): "an old text entry maps to a typed draft with the same id"; "a video entry maps to voice and logs videoSentAsVoice"; "an absolute audio URL becomes a relative media path"; "empty content is not taken"; "with no bridge set, syncEntryToBackend takes the old path" (the stub records a `/content` call); "with the bridge set, nothing goes to /content".

Proof in the PR: test output; the hook diff and the comment diff; the integrator's staging run (offline write → reconnect → one entry).

Watch out: `EntryManager` is `@MainActor`; the closure is too, and it only enqueues (a `Task` into the outbox actor), never awaits the network. Don't touch the 13 call sites.
