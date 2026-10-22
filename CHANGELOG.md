# Changelog

What changed, in plain words, newest first. Every merged PR that changes what the app, the backend or the team does gets a line here, in the same PR or the integrator's next one. Big changes get a short paragraph: what a person will notice, and what to watch. (Founder, 22 Oct: "always have a changelog for every massive change".)

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
