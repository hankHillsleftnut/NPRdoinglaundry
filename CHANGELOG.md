# Changelog

What changed, in plain words, newest first. Every merged PR that changes what the app, the backend or the team does gets a line here, in the same PR or the integrator's next one. Big changes get a short paragraph: what a person will notice, and what to watch. (Founder, 22 Oct: "always have a changelog for every massive change".)

## 27 Oct 2026

- **Content fades into the tab bar (TABBAR.blend):** inside the app shell, every tab page now dissolves into the tab bar over its last 90pt (72 on SE) with a progressive blur and an eased canvas gradient, light and dark, instead of being cut by a hard edge; the mini-player floats on the opaque end, sheets still cover the bar, Reduce Transparency keeps the fade alone. New tokens `blur.tabBlend.rise/riseCompact`; nothing existing changed.

## 22 Oct 2026 · evening

- **Signing in works end to end in the app:** Sign in with Apple with a one-time nonce, silent refresh (one refresh at a time, a clock that's wrong doesn't loop), sign-out, and a retry that can't sign you out by accident; the old screens' 401s are bridged to the new session (#134, #142). One bump of a person's session version now ends their phones' sessions (#137).
- **Entries reach the server:** send an entry once, even when the answer is lost (#128); today, the whole history with a cursor, and search with highlighted matches (#132). A fresh person's brief is **on by default** (#146, the founder's call).
- **The brief and the guesses:** the brief, its list and its switch (#133) and the guess cards with "why" (#138); in the brain, the brief is spoken part by part into a **private** audio bucket, so there's no permanent public link (brain #138), episode audio gets signed, expiring links (brain #137), quiet weeks aren't errors (brain #139), and open guesses can be listed without using up their two offers (brain #141).
- **Invites:** a code is checked before it's torn, torn once even if the answer is lost, and shows its number and date (#122); the signed-out preview of a link (#135).
- **Safety and limits:** every model call is counted against the daily cap, per person and for staging (brain #136); a refused "spend limit" is never retried and reaches the app as itself (#145); `/v2/meta` and the update-required floor exist on the server (#140). Fixed before merge: a spend-total that silently stopped at 1,000 rows, a brief that could be spoken twice, and a calendar test fixture that held a real name and address (brain #140).
- **Journal parts:** your message bubble and voice bubble (#123, #124), the brief card (#125), sheets (#127), dialogs (#129), the long-press menu (#130), skeleton loading (#103), the empty line (#126), sample journal data (#86). All parts of the first journal screen are now on main; the screen itself is next.
- **The app's plumbing:** retries, backoff and reachability (#102); the migration that fixes the old five-argument tear call (#148).
- **CI is on GitHub's own runners** while the repos are public: fast, free, and off the founder's Mac (#120, #136). Secret scanning and push protection are on; outside pull requests need approval before any workflow runs.

**Watch**
- Migrations 005, 007, 019 to 026 and brain 152 to 155 are unapplied anywhere; 021 now keeps the old tear call working until the new backend is deployed.
- Both repos are public for CI minutes: two old API keys in the app's history were rotated first.

## 22 Oct 2026 · afternoon (integrator on Fable)

- **Faster, with the same gates.** The founder reset usage, so the team went to five engineers (two Platform, two backend, views) plus a short high-effort "contract pass" before every integration piece and a fresh reviewer the moment a risky PR opens. Nothing merges without the same four gates as before. Details in `docs/team/prototype-mode.md` ("Team shape").
- **Contract passes caught real problems before any code:** sign-in (the app never refreshed on a 401; a dropped refresh cost a sign-in; a planned "upgrade" door doesn't exist and is dropped for Beta 1), invites check (no shared idempotency store existed; the card's check order made "this is yours" unreachable), journal entries (a duplicate send could create two entries; the card's date bounds would silently lose month-old offline entries).
- **Invites, follow-up:** someone the founder has approved but who hasn't opened their link yet still reads as "on the list" (migration 020); the public link page is limited per address and answers the neutral page, never an error; rotating the invite key can't break "your invites" (#118).
- **The brain:** `/runs` and `/integrations` only answer about the person asking; the developer's local dashboard keeps its view across people (brain #135).
- **Effort by phase** written down (#117).
- **CI:** stale runs on a PR are cancelled when a newer push arrives; a push to main only builds the app when the app changed (#116). iOS builds are incremental (derived data kept between runs) and can run on any Mac with a simulator named `ci`, so a second laptop can take them (#116, #120).

## 22 Oct 2026 · morning (new integrator)

- **Sign in with Apple** on the new server: Apple's token is checked (our app, Apple's keys, a one-time code), your name and email are kept only from the first sign-in, and only what Apple vouches for (#109). A test of the real check found that some forged tokens caused a server error instead of a refusal; fixed before merge.
- Database migrations refuse any connection setting that could switch off certificate checks (brain #134).
- The top bar, with its title that shrinks as you scroll (#83). The design lab lists its pages in one place (#105).
- **Signing in, part two:** the app can refresh its sign-in and sign out. A retry after a dropped connection gets the same new sign-in, so nobody is signed out by a bad signal; a stolen copy used later ends that device's session (#108).
- **The brain:**
  - "that's not right" now saves in one step or not at all; before, it could half-apply in production (#132);
  - every brain lookup is limited to the person asking (#133).
- **The app's plumbing:**
  - launch options for testing: sample or live data, staging or local server, seeded accounts; release builds ignore them all (#101);
  - the local database library, GRDB 7.11.1, pinned (+3.8 MB to the app) (#104).
- **Journal parts:** the error state with "try again", its haptic and its VoiceOver line (#78).

## 21–22 Oct 2026 · Beta 1 build, day one

**The team and the plan**
- The approved plan: a Platform engineer, a views engineer and a backend engineer, with an integrator who reviews and merges everything (#57, #73).
  - Beta 1 is an invite-only TestFlight: invite link → sign in with Apple → the ticket tear and "you're in" → the new journal.
- All six later areas are planned down to single PRs (#60, #62, #65, #66, #68, #69). They were cross-checked against each other, and the founder's 55 open questions are in one list (#70).
- **CI:**
  - two runners on the Mac: quick checks run alongside iOS builds (#67);
  - every app PR now has to pass the app's tests, not just build (#82; 33 tests at the start).

**The app**
- Design-system components: squircles everywhere, icon button, artwork and grain, pill, tag, toast, switch, source row, search field, composer, and voice composer, plus review fixes for VoiceOver, gestures and haptics (#58). Earlier: segmented control, settings row, section label, and Dynamic Type for SF Pro and mono (#39, #47, #49, #51).
- Journal parts:
  - the offline line (#75);
  - the evidence row, "where this came from" (#77);
  - the soft blur at the tab bar and scroll edges, with Reduce Transparency handled (#76).
- Foundations:
  - pinned packages (#71);
  - tests that actually run, from a clean test host (#72);
  - the journal's data shapes, with 86 example requests and replies that both app and backend are tested against (#74).

**The backend**
- **Local staging:** the backend and brain run on the Mac against a separate test database, with seeded test accounts (#59 and the brain's #131).
  - Every staging command proves it's on staging before writing. Three separate paths to production were found and closed in review.
- **Runtime hygiene** (#61):
  - each user's real IP for rate limits;
  - bad Apple tokens get 401, not 500;
  - a double-tap first sign-in makes one account;
  - admin is off unless a secret is set;
  - every write is idempotent.
- **The door kit** (#63, #64, #79, #81): every new `/v2` route checks who you are and what you own, limits requests per person, logs with no personal words, and is tested by one shared suite that fails if a route forgets its ownership check.
- **Error cleanup** (#80): no raw error text in server logs; voice generation is time-limited and stops paying for extra chunks after a failure.

**Watch**
- Beta 1 progress: 12 of about 84 PRs merged.
- The founder still has to: set `ADMIN_SECRET` on Render before the hygiene PR deploys, download Supabase's CA certificate for staging, and say yes or no to real AI keys on staging.

## 22 Oct 2026 · later

- **Staying signed in:** 15-minute access, 60-day rotating refresh, and a 30-second grace window for retries. Reuse of an old token signs every session out. The row lock is proven on a real two-connection Postgres (#89).
- Error messages match the contract word for word, and a test keeps them matched (#92).
- **The app's plumbing:**
  - the app environment (#94);
  - a typed contract client with every header, its failures mapped and nothing logged but path templates (#98, #100);
  - the Platform folder with logs that can't carry text (#84).
- **Journal parts:**
  - the drawer's entry row, with emoji-safe search highlighting (#88);
  - evidence-row icon tokens (#97);
  - design tokens and depth recipes, so single lines match Paper's height (#85).
- **CI:** Platform code is linted, Keychain tests run, and package versions are locked (#96).
- **Changelog started; session diagnostics added to Beta 1** (#91).

## 22 Oct 2026 · prototype mode
- **Until Beta 1 ships, the team runs in prototype mode** (`docs/team/prototype-mode.md`). Privacy, data safety, the outbox, sign-in and CI stay strict, and so does the journal and ticket design. Reviews, PR size, Paper matching on internal parts and nit-fixing get lighter. Expect about twice the speed at about half the usage.
