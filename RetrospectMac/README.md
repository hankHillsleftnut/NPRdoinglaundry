# Retrospect for Mac

A calm, writing-first journaling app — the macOS companion to Retrospect. Card-inside-a-card,
hidden chrome, inky Hedvig on warm cream, a reveal sidebar, and a local-first store that quietly
feeds your reflections into the Retrospect agent pipeline.

## Build & run

Requires Xcode 16+ and [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
cd RetrospectMac
xcodegen generate          # regenerate RetrospectMac.xcodeproj from project.yml
open RetrospectMac.xcodeproj
# or from the CLI:
xcodebuild -project RetrospectMac.xcodeproj -scheme RetrospectMac -configuration Debug \
  -derivedDataPath ./build build
open ./build/Build/Products/Debug/RetrospectMac.app
```

`project.yml` is the source of truth — never hand-edit the `.xcodeproj`; re-run `xcodegen generate`.

## How it works

- **Local-first.** Entries autosave to `~/Library/Application Support/Retrospect/journal.json`
  immediately. Words are never lost, online or off.
- **Markdown storage.** The editor is rich (Hedvig body, `⌘B`, `⌘I`, headings via `⌘⌥1/2/3`,
  `⌘⌥0` for body) but is serialized to Markdown — best interpretation quality for the pipeline
  and fully portable.
- **Session-aware sync.** A writing session ends after **10 minutes** of no typing. On session
  end, unsynced entries flush to `POST /content` (with retry + backoff for the cold-starting
  backend). Sync also flushes on quit.
- **Daily synthesis.** After a session ends, synthesis runs **at most once per calendar day**, and
  only if there's **new writing** since the last run.
- **Summon anywhere.** Global hotkey **⌥⌘J**, plus a menu bar item. `⌘\` toggles the sidebar,
  `⌘N` starts a new entry.

## Auth / sync

Primary auth is **Sign in with Apple**, reusing the same Retrospect account as iOS
(`POST /auth/signin`, JWT in the Keychain, base `https://retrospect-api.onrender.com`).

SIWA + App Sandbox are **not wired by default** so local dev builds stay green — they require an
App ID with the *Sign In with Apple* capability (paid program). To enable:

1. Enable "Sign In with Apple" on the `com.retrospect.mac` App ID in the developer portal.
2. Rename `RetrospectMac.entitlements.template` → `RetrospectMac.entitlements`.
3. In `project.yml`, add to the target's `settings.base`:
   `CODE_SIGN_ENTITLEMENTS: RetrospectMac.entitlements` and `ENABLE_HARDENED_RUNTIME: YES`.
4. `xcodegen generate`.

Until then, use **Developer sign-in** in the sign-in popover (enter your Apple user id) to exercise
sync against the live backend.

## Layout of the code

```
RetrospectMac/
  App/RetrospectMacApp.swift     @main, window chrome, menu bar item, hotkey, flush-on-quit
  Design/                        Palette (ink-on-cream), Typography (Hedvig), Metrics
  Models/                        JournalEntry, MarkdownSerializer (rich <-> markdown)
  Store/JournalStore.swift       local-first persistence + autosave
  Services/                      RetrospectAPI, AuthManager, Keychain, SessionMonitor,
                                 SyncEngine (outbox + synthesis), Prompts, GlobalHotkey
  Views/                         RootView (card-in-card), SidebarView, MarkdownEditor, SignInView
```
