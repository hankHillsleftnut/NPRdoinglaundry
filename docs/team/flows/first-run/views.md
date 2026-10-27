# First run · view cards

Every view leaf in the first-run tree, as a full [byte card](../../byte-card.md). Read [README.md](./README.md) first (the big picture, flows, tree and queue), then [contract 01](../../contracts/01-first-run.md). The app engineer builds these from Paper, on sample data shaped exactly like contract 01, and the integrator's wiring PR (FR0.4 for phase 2; PL1.8 for Beta 1) swaps in live data.

**Paper.** The invite cards (§A) were checked value by value against Paper on 21 Oct with `get_jsx` and `get_computed_styles`: round 2 board `2HXA-0` "review · the invite · round 2 · the ticket" on the approvals page (`p-G-0`), its ticket `2HXP-0`, and its seven phones (402 × 874, iPhone 17 Pro): T1 `2I01-0`, T2a `2IDN-0`, T2 `2I39-0`, T3 `2I6G-0`, T4 `2IH2-0`, T5 `2IM6-0`, T-alt `2IRH-0`; round 1 is `2H3N-0`. Each place where Paper disagrees with the board's written anatomy, the build notes or the reference docs is marked **Paper differs** with the newer source named. The phase 2 cards (§B–§F) cite node ids from `reference/paper-inventory.md`; their first step is the same read, and any difference goes into the PR. **Where a value here and Paper disagree, Paper wins.**

**Order:** the Beta 1 cards come first (§A: the invite), then phase 2 in flow order (§B sign-in, §C getting to know you, §D the first episode, §E membership, §F first home, §G the flow test).

Global rules that every card below inherits (not repeated): tokens only (`RColor`, `RDimension`, `RNumber`, `RType`); squircles only (`RShape`); motion only from `RMotion` and the modifiers (`.rPress`, `.rAppear`, `.rPop`, `.rShake`, `.rBlurReplace`, `.rFloat`); haptics only through `RHaptic`, on the frame the visual lands; never linear except what follows a finger or real time; every motion interruptible; Reduce Motion = a 140ms cross-fade with the meaning kept; 44pt hit areas; one lit object per screen; lowercase; no personal content in logs; an `#Preview` per state; T02 launcher registration (`-Screen <id> -State <name>`); snapshots in light, dark and AX3; screenshots next to the Paper node.

---

# §A · The invite (Beta 1)

The founder, 21 Oct: *"you've just been given a gift, don't waste it."* M14 must feel like being handed something precious: a ticket made for you, printed while you watch, that you tear off yourself. The tear is the moment it becomes yours; nothing is spent until the stub separates.

Build order: UI4.0 → C43 → C41.1 → C41.2 → C41.3 → C41.4 → C42 → PI1 → PI2.1 → PI2.2 → PI2.3 → PI2.4 → T03a. FR0.1 (the integrator's tokens, haptics and the shaped depth helper) must merge before C41.1.

---

### UI4.0 · SampleInviteData                                                         size: S
Place in the tree: first run › the invite › data seam › sample implementation
Repo · branch: NPRdoinglaundry · `ui/UI4.0-sample-invite-data`
Needs: FR0.2 (`Platform/Flows/Invite.swift`, the integrator), T02        Unblocks: C41.x previews, PI1, PI2.x, T03a

Why: every invite state (the promise, the print, the tear, a used code, offline) can be built and checked before the live invite doors exist, and nothing changes on screen when they arrive.

Inputs:
- Contract: 01 §2 (preview, check, redeem), §3 (launch table); contract 00 §3–§4; fixtures `fixtures/01/invite.*.json`, `fixtures/00/redeem.response.json`
- Platform: `Platform/Flows/Invite.swift` (FR0.2): `InviteData`, `InviteStage`, `TicketFace`, `CheckOutcome`, `RedeemOutcome`
- Plan: `ui-engineer.md` §4 (the seam rules), UI1.0 (the journal's sample data, same pattern)

Spec:
- `Features/Invite/Sample/SampleInviteData.swift`: `@MainActor @Observable final class SampleInviteData: InviteData`, initialised with `(scenario: InviteScenario, clock: any Clock<Duration>)`. Content decoded from the contract fixtures (so shapes can't drift); invented names only ("priya", "sam").
- **Scenarios** (also T02's `-State` names for `PI1` and `PI2`):

| Scenario | Stage and behaviour |
|---|---|
| `promise` | signed out, pending code, preview live (`from: "priya"`); `signIn` succeeds after 0.8s → `printing` |
| `promiseNeutral` | signed out, preview not live (`face: nil`) |
| `signingIn` | sign-in in flight forever |
| `signInFailed` | `signIn` fails with `invalidCredentials` |
| `printing` | signed in; check usable; the print never finishes (for stills) |
| `ready` | printed; tear available; `tear()` succeeds after 0.3s |
| `sealing` | the tear passed the threshold; redeem never answers |
| `tearOffline` | `isOnline = false`; `tear()` returns `.offline` |
| `tearRefused` | `tear()` returns `.used` (someone redeemed it between check and tear) |
| `youreIn` | redeemed this session (`invitedBy: "priya"`, `firstName: "sam"`) |
| `youreInStatic` | approved, relaunched before "begin" (no print, no tear) |
| `typed` | signed in, no code; `type(code:)` with `7KQ2M9XD4RTAB` → usable, anything else → `.invalid` |
| `typedWrong` | the 13th character just failed (`.invalid`) |
| `used` / `expired` | check returned `invite_used` / `invite_expired` |
| `offline` | signed in, pending code, `isOnline = false` (the print waits) |
| `waitlistSheet` / `waitlisted` | the join sheet open / joined |
| `rateLimited` | check returned `rate_limited` with 60s |
| `suspended` | access `suspended` |
| `noName` | `firstName == nil` ("you're in." with no name) |
| `founderInvite` / `reviewInvite` | `face.kind` founder (`from: "shaurya"` placeholder, founder Q10) / review (`from: nil`) |

- Deterministic: an injected clock, no randomness; "never finishes" is a task that never resolves.
- Ledger rows in `docs/design/sample-data-ledger.md` for every sample value (screen, field, value, contract path, the PR that removes it: PL1.8).

Steps: scenarios enum → content from fixtures → behaviour on the injected clock → T02 registration (`Features/Invite/InviteScreens+Launcher.swift`) → ledger.

Acceptance:
- Every scenario above opens with `-Screen PI1` or `-Screen PI2` and `-State <name>`.
- Every value shown comes from a fixture or the ledger.

Tests:
- (unit) every scenario builds without a network
- (unit) `type(code:)` normalises dashes, spaces and case before matching the sample code
- (unit) `tear()` in `ready` moves to `youreIn` after 0.3s of the injected clock
- (unit) the sample's faces decode from `fixtures/01/invite.check.usable.json`

Proof in the PR: test output; the ledger diff.

Watch out: the sample must never hold a real code; `7KQ2M9XD4RTAB` is the fixture's invented code. Don't put sign-in logic here: `signIn` only moves the stage (the real Apple sheet is hosted by the view and handed to Platform; see C43).

---

### C43 · Sign-in buttons: Apple and Google                                         size: S
Place in the tree: first run › sign in › sign-in buttons (used by PI1 · T1, P01 splash, P32 AC-1)
Repo · branch: NPRdoinglaundry · `ui/C43-sign-in-buttons`
Needs: T01; PL1.4a (`Session.AppleSignIn`'s `prepare`/`complete` seam)        Unblocks: PI1, P01, P32

Why: one calm way in, the same on every screen that asks you to sign in, and exactly as Apple and Google require.

Inputs:
- Reference: design-reference §Extra "Splash (ON-1/2)" (both 56 high, bottom zone, legal line); screen-rules 22 (Apple standard black; Google a white raised button with a warm hairline, never a dark border); build notes "Dark mode" (Apple dark = `SignInWithAppleButton(.white)`; Google dark fill `#131314`, label `#E3E3E3`)
- Paper: splash `1F4Q-0` (the two buttons and legal line); invite round 2 T1 (same pair)
- Code anchors: PL1.4 (`Platform/Session/AppleSignIn.swift`: `prepare(_:)`, `complete(_:)`), `RButton.swift:9` (the secondary recipe the Google button borrows), `RSpinner` (`Parts/RParts2.swift:73`)

Spec:
- `DesignSystemV2/Components/RSignInButtons.swift`: `struct RSignInButtons: View` with `providers: [Provider]` (`.apple`, `.google`), `state: State` (`.rest`, `.pending(Provider)`, `.disabled`), and closures `onApple(ASAuthorizationAppleIDRequest)`/`onAppleResult(Result<ASAuthorization, Error>)` and `onGoogle()`. It hosts the system `SignInWithAppleButton` (so Apple's own button and sheet are used, as Apple requires) and never talks to the network.
- Paper (T1 `2I01-0` bottom zone, read 21 Oct): both buttons 354 wide (the column at 24 margins), **60 high (`size.control.hero`)**, pill (`radius.control`), 12 apart (`space.3`); the zone's bottom padding 40 (`space.10`). **Paper differs** from the reference's "56 high": Paper wins.
- **Apple:** `SignInWithAppleButton(.signIn, onRequest:onCompletion:)`, `.signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)` (`signInAppleFill/Label` are the same colours), height 60, corner radius 30 via `.clipShape(RShape.pill)` (Apple allows a corner radius), full column width; shadow under it as Paper: contact `0 1 2`, cast `0 8 16 −8`. Paper draws the glyph 18 × 20 and the label SF Pro 17 medium with an 8 gap; the system button draws its own, which is what Apple requires: the PR shows both side by side and lists the difference.
- **Google:** a cloned brand button (Google's logo colours can't be tokens; the four-colour "G" ships as a vector asset `google-g`, 18 × 18): 60 high, pill, `signInGoogleFill`, the stack inner top `0 1 0` inset, outer stroke 0.5, contact `0 1 1.5`, cast `0 6 14 −6`; the "G" 12 before the label "Continue with Google" (SF Pro 17 `text.body` medium, `signInGoogleLabel`); dark: `#131314` / `#E3E3E3` (the tokens already carry the dark values).
- The legal line, 12 below the buttons (the zone's gap), its words passed in by the page: "by accepting you agree to the terms · privacy" on the invite (T1), "by continuing you agree to the terms · privacy" on the splash (`1F53-0`); the splash's buttons are also 354 × 60 (`1F5B-0`, `1F54-0`) (Geist 12 `text.sm`, `text.label`, centred; "terms" and "privacy" as 44pt targets opening Safari View).
- **Beta 1:** `providers: [.apple]` (Google waits for BE2.4; first-ship). The layout must not leave a gap: the legal line moves up.
- Pending: the tapped button dims to `opacity.pending` 0.7 and both are disabled; a 20 `RSpinner` sits centred on the Google button when Google is pending (Apple's sheet covers its own pending).

State table:

| State | Look | Motion | Haptic |
|---|---|---|---|
| rest | as above | — | — |
| pressed | Apple: system; Google 0.98 | `.rPress` 80/240 | none (not lit) |
| pending | tapped 0.7, both disabled | 140 cross-fade | — |
| disabled (offline) | both 0.4 (`opacity.disabled`) with "connect to sign in" under them (Geist 12 `text.label`, offline glyph) | `.rBlurReplace` | — |
| dark | Apple white, Google `#131314` | — | — |

Interaction table:

| Touch | Press | Haptic | Motion | Outcome | Reduce Motion |
|---|---|---|---|---|---|
| Apple | system | none | system | Apple's sheet; result to `onAppleResult` | same |
| Google | 0.98 | none | `.rPress` | `onGoogle()` | same |
| terms / privacy | text dims 0.7 | none | — | Safari View | same |

Accessibility: each button reads its own label ("Sign in with Apple", "Continue with Google"), trait button; the legal line's links are separate elements; AX3: buttons grow in height with their label (`minHeight` 56), never truncate; contrast ≥ 4.5 : 1 on both.

Steps: Apple host → Google clone and asset → states → gallery `gallery.C43` → snapshots.

Acceptance:
- Matches `1F4Q-0`'s buttons and legal line in light, dark and AX3.
- Apple's button is the system one (not a drawing of it).
- With only `.apple`, nothing leaves a gap.

Tests:
- (snapshot) rest, pending (Google), disabled; light, dark, ax3; Apple-only
- (unit) `providers: [.apple]` renders one button
- (UI) VoiceOver finds both buttons and both links as separate elements

Proof in the PR: standard proof, next to `1F4Q-0`.

Watch out: never recolour Apple's button; never draw Google's "G" from tokens (brand colours); the legal links open Safari View, never the in-app browser of a third party.

---

### C41 · The invite ticket                                5 bytes: C41.1 M, C41.2 S, C41.3 M, C41.4 M, C41.5 S
Place in the tree: first run › the invite › the ticket (PI1, PI2; later "your invites", PI3)
Repo · branches: NPRdoinglaundry · `ui/C41.1-ticket-shape`, `ui/C41.2-ticket-face`, `ui/C41.3-ticket-perforation`, `ui/C41.4-ticket-stub-and-code`, `ui/C41.5-ticket-torn-halves`
Needs: FR0.1 (tokens: gift mesh, print and tear motion, rip and rumble haptics; `RDepth` raised stack for any `Shape`), T01, #42 (`RArtwork`), #55 (`RShape`), UI4.0 (previews)        Unblocks: C42, PI1, PI2.x, PI3

Why: the invitation is a real object: paper with a gift-coloured top, a punched perforation and a stub with your code, cut like a ticket, with a shadow that follows its bites. It has to look worth keeping before it does anything.

Inputs:
- Paper: round 2 board section 1 "the ticket" (anatomy and tokens, quoted below) and its phones T1–T5, T2a, T-alt; round 1 B "the invitation" (`2H3N-0`, the earlier card this grew from)
- Build notes (21 Oct, `docs/design/ios-build-notes.md` "M14 invite ticket"): notches are real cuts (`Path` with `.eoFill`, or `.mask` with inverted circles) and `.shadow` goes on that shape; torn halves keep their half-bites
- Findings (21 Oct, c-gn4fow, c-g00oyv, c-4atq2k): the mask, the shadow moved to the shape, the stub falling clear
- Code anchors: `RDepth.swift:28` (`rRaised`, extended by FR0.1 to take a shape), `RArtwork` (#42, gains the `gift` recipe in FR0.1), `RType` (display inky, mono, Geist label), `RMotionModifiers.swift:110` (`rShake`)

Anatomy, from Paper (`2HXP-0` and T2 `2I49-0`, `get_computed_styles` on 21 Oct; the board's written anatomy `2HZS-0` agrees except where marked):
- **paper:** 354 × 389 on the 402-wide phone (the column at 24 margins; 335 on SE at 20 margins), `background.raised`, `radius.card` 20 (continuous), inner top highlight `0 1 0` inset (`depth.stroke.innerTop`) and inner stroke 1 inset (`depth.stroke.inner`).
- **shadow that follows the cut:** on the shape (Paper puts it on the wrapper "ticket · shadow follows the cut" `2IV3-0` as drop-shadows): outer stroke `0 0 0.5` (`depth.stroke.outer`), contact `0 1 1` (`depth.shadow.contact`), cast `0 10 14` (`depth.shadow.cast`), no spread, no ambient. **Paper differs** from the board's written anatomy ("contact 0 1 2, cast 0 12 28 −12, ambient 0 24 60 −20", still on T1's hidden ticket): the drawn keyframes are newer (the c-gn4fow fix moved the shadow to drop-shadows), so build the drop-shadow stack and list the difference in the PR.
- **notches:** two cuts of radius 10 centred on the left and right edges at y 264 from the top (the perforation's centre); the edge antialiases between 9.5 and 10.
- **gift mesh** (`2HXR-0`): 132 tall (104 on SE), top corners `radius.card`; base `amber.50`; three radial blobs mixed in oklab: `amber.200` (ellipse 80% × 90% at 85%, 10%, fading out by 70%), `sky.300` at 80% (ellipse 70% × 80% at 15%, 90%, out by 75%), `red.200` at 45% (ellipse 45% × 40% at 55%, 45%, out by 100%). FR0.1 turns this into the named `gift` `MeshGradient` recipe (a 3 × 3 mesh approximating the three blobs; the PR shows the two side by side); grain overlay as every mesh; in dark, each stop uses its palette dark twin.
- **face** (`2HXS-0`): padding top 20, sides 20, bottom 16 (`space.5`, `space.5`, `space.4`), gap 8; a baseline-aligned row: "an invitation · from priya" Geist 12 (`text.sm`) medium `text.label` and the serial "no. 0412" mono 11 (`text.xs`) `text.tertiary` trailing; then "a place in retrospect, kept for you." display inky 28 (`text.2xl`), `inkCard` weight, `tracking.title`, `leading.tight`, balanced.
- **perforation** (`2HXY-0`): a row 20 tall (`space.5`) with 20 side padding; 21 holes of 6 (`size.stepDot`) spread evenly (space-between), each `background.sunken` with the sunken shade `0 1 1.5` inset and outer stroke 0.5 inset. The tear runs left to right along this row.
- **stub** (`2HYN-0`): padding top 12, sides 20, bottom 20, gap 12 (`space.3`); a baseline row "admits one" (Geist 12 medium `text.primary`) and "one use · yours alone" (Geist 11 `text.label`); the code as 13 tiles 20 × 28 (`space.5` × 28), `radius.small` 6, `surface.control`, the sunken shade `0 1 2` inset plus outer stroke 0.5 inset, mono 14 (`text.md`) `text.primary` `leading.snug`; tiles 3 apart inside a group, the four groups (4 · 4 · 4 · 1) spread across the row (space-between, at least 8 apart); a baseline row: the date mono 11 `text.tertiary` ("21 oct 2026") and "retrospect" Geist 11 medium `text.label`. **Paper differs** from this card's first draft (2 within groups, 6 between): Paper's 3 and space-between win.
- **new parts** (the board's list): `c:invite/ticket` (whole, tearing, torn: body and stub), the perforation row, the gift mesh recipe, a "keepsake" size of the torn body (used on "you're in" and in "your invites").

Spec per byte:
- **C41.1 the shape and its depth** (`DesignSystemV2/Components/Ticket/RTicketShape.swift`):
  - `struct RTicketShape: Shape` = a continuous rounded rect of `radius.card` minus two circles of radius 10 centred on the left and right edges at the perforation's y (`perforationY`), filled `.eoFill` (or built as a `Path` subtraction; never circles drawn over the edge in the canvas colour).
  - `enum Part { case whole, body, stub }`: `body` is the shape above the perforation's centre line with half-bites at its bottom corners; `stub` is the part below with half-bites at its top corners (the same circles, clipped).
  - The shadow stack above applied to the shape (`.rRaised(in: RTicketShape(...), stack: .ticket)` from FR0.1), so every shadow follows the bites. Inner strokes are `strokeBorder` on the same shape.
  - Torn parts: the corners at the tear are `radius.small` 6, not `radius.card` (Paper `2I9M-0`, `2IBK-0`: the body's bottom corners and the stub's top corners).
  - Concentric insets: the mesh's top corners use `radius.card − inset` (inset 0 here: it bleeds to the paper edge, clipped by the shape).
- **C41.2 the face** (`RTicketFace.swift`): the gift mesh (`RArtwork(.gift)`), the words above, padding 16 (`space.stackDefault`) inside; takes `TicketFace?` (`nil` → "an invitation" with no "· from …" and no serial). `from` changes blur-replace in (`.rBlurReplace`, 220). Founder invites read "from <the founder's first name>" (Q10), review invites "an invitation".
- **C41.3 the perforation and the tear handle** (`RTicketPerforation.swift`): the 21 holes evenly spaced between the notches; a `tearProgress: CGFloat` (0…1) input that hides holes behind the tear point (each hole the tear passes becomes the torn edge: the hole's half-circles stay on both halves); the handle (Paper `2I67-0`): a 32 disc (`space.8`), `background.raised`, pill, stack inner top `0 1 0` inset, outer stroke 0.5, contact `0 1 1.5`, cast `0 4 10 −4`, a 14pt chevron glyph centred; placed at left −16, top 248, so it sits centred on the left notch; hit area 44 × 44 around it. While held (Paper "tear handle · 40%" `2IDJ-0`): it rides the tear point on the perforation (top −6 within the row) and lifts: inner stroke 1 inset added, contact `0 1 2`, cast `0 8 18 −8`. `handleVisible: Bool`. The handle never glows (it's not the lit object; "begin" is).
- **C41.4 the stub and the code** (`RTicketStub.swift`):
  - display mode: the 13 tiles show the code (`7 K Q 2 · M 9 X D · 4 R T A · B`), the labels, the date (`redeemedOn` when known, else today's local date while printing).
  - typed mode (T-alt): the same tiles take input from one hidden `TextField` (`.keyboardType(.asciiCapable)`, `.textInputAutocapitalization(.characters)`, `.autocorrectionDisabled()`, `.textContentType(.none)`); characters normalise as they land (lowercase → upper; `O` → `0`, `I`/`L` → `1`; dashes and spaces ignored; anything else refused with no character added); the next empty tile carries the caret (Paper `2IT4-0`: a 1.5pt `text.primary` ring outside the tile, blinking on `curve.standard` 530ms in and out, still under Reduce Motion); tiles not yet reached sit at 0.6 opacity (Paper `2IT1-0`); paste of a whole code fills all 13 at once.
  - each landed character: the tile's glyph sharpens from a 1.5pt blur on `curve.standard` 120ms; no haptic per character (keyboard clicks are the system's).
  - wrong code: the whole stub shakes once (`.rShake`, 6pt on `snappy`) with `RHaptic.warning`, then the tiles clear right to left, 30ms apart, each glyph blurring out on `curve.exit` 110ms.
  - refused states (not drawn: lean): "already used" or "expired" replaces "admits one" (Geist 12 medium `text.primary`); the tiles go to `opacity.disabled` 0.4.
- **C41.5 the torn halves and the keepsake** (`RTicketTorn.swift`): `RTicketBody` (354 × 274: the face plus the perforation row, its bottom corners `radius.small`, half-bites at its bottom corners) and `RTicketStubPiece` (354 × 115, its top corners `radius.small`, half-bites at its top corners), each with the same shadow stack (Paper `2INA-0` keeps one drop-shadow stack over both pieces). The keepsake: the board's text says "−12°, 86% scale"; **Paper differs**: T4 `2II7-0` and T5 `2INB-0` draw the stub at full size, rotated −14.8°, centred, 72 below the body (`gap 72`). Paper is newer (after c-4atq2k): build full size at −14.8°; the 86% "keepsake" size is kept for PI3 "your invites" only.

State table (the component; PI2 drives the transitions):

| State | Look | Motion | Haptic |
|---|---|---|---|
| whole · display | all parts, handle hidden | — | — |
| whole · ready | handle in the left notch | handle fades in 200 `curve.standard` after the print | — |
| whole · typed | stub in typed mode, caret on the next tile, handle hidden until filled and usable | caret blink | — |
| tearing (`tearProgress` 0…1) | holes behind the tear become the torn edge; the stub's torn length droops (PI2.2) | follows the finger 1:1 | `select` per hole (PI2.2) |
| torn | body and stub piece apart | PI2.3 | `rip`, then `reveal` |
| refused (used, expired) | label replaced, tiles 0.4, no handle | `.rBlurReplace` | — |
| keepsake | body at 86% | — | — |
| dark | `background.raised` dark, mesh dark twins, inner stroke white 8%, shadows black | — | — |

Accessibility:
- The whole ticket is one element: "invitation from priya, admits one, code 7 K Q 2 M 9 X D 4 R T A B" (characters spaced so VoiceOver spells them; never read as a word), trait `.isStaticText`, plus PI2's custom action "tear ticket".
- Typed mode: the hidden field is the element: "invitation code, 3 of 13 characters" with the characters spelled; the tiles are hidden from VoiceOver.
- Dynamic Type: the face title scales to `accessibility1` then holds (the ticket is an object of fixed width; the words around it carry the rest); tiles and mono figures don't scale (they're a printed code); AX3 snapshots must show no clipping.
- Increase Contrast: the holes and tiles get a 1pt `border.control` ring; `text.tertiary` serial goes to `text.secondary`.
- Reduce Transparency: unchanged (no material).

Steps: per byte, read the board values → shape and depth (C41.1) → face (C41.2) → perforation and handle (C41.3) → stub and typing (C41.4) → torn halves (C41.5) → gallery `gallery.C41` with every state → snapshots.

Acceptance:
- The notches are cut through to the page: on the gradient wallpaper you see the wallpaper through them, and the shadow bends around them (checked on a dark background too).
- Every value matches the round 2 board's section 1 ticket and T-alt in light; dark matches the token swap (no dark board exists yet: the founder checks the dark snapshots).
- Typing `7kq2-m9xd-4rta-b` fills the tiles as `7KQ2M9XD4RTAB`; `O`/`I` map to `0`/`1`.
- Torn halves keep their half-bites.

Tests:
- (snapshot) whole display, ready, typed (empty, 7 filled, full), refused used, refused expired, keepsake, body piece, stub piece; light, dark, ax3; SE
- (unit) `RTicketShape` has two cuts at `perforationY` (path contains no point inside each circle)
- (unit) the code normaliser maps dashes, spaces, case, O/0 and I/L/1, and refuses other characters
- (unit) `tearProgress` 0.5 hides the first 10 holes and shows 11
- (UI) VoiceOver reads the ticket as one element with the code spelled
- (UI) pasting a code with dashes fills all 13 tiles

Proof in the PR: standard proof against the round 2 board nodes; one zoomed screenshot of a notch over the gradient wallpaper in light and dark (the shadow must follow the cut).

Watch out:
- `.mask` removes a `.shadow` applied to the same view: put the shadow on the shape (or on a parent of the masked content), exactly as the build note says.
- Never draw the notch as a canvas-coloured circle: on the gift wallpaper it shows as a grey disc (the founder's comment c-gn4fow).
- The hidden `TextField` must keep focus when tiles are tapped; tapping a tile focuses the field, never selects text.
- The code is never logged, and the sample code is the fixture's invented one.

---

### C42 · The printer slot                                                             size: S
Place in the tree: first run › the invite › M14 › printer slot
Repo · branch: NPRdoinglaundry · `ui/C42-printer-slot`
Needs: C41.1, FR0.1        Unblocks: PI1 (the slot at rest on T1), PI2.1

Why: the ticket is made for you, now: it comes out of a slot like a receipt, not out of nowhere.

Inputs:
- Paper: round 2 board "added after the flighty reference: c:invite/printer-slot (sunken bar, background-sunken, the sunken inset shade, radius-control, 8pt tall, 20pt wider than the ticket)"; T1 (the slot under the title at rest), T2/T2a (printing, with the curved lip and shading band)
- Findings c-g00oyv (21 Oct): the slot is a curved mouth (a smile-shaped lip, `background.sunken`), and a shading band (`depth.shadow.ambient` → `depth.shadow.cast`) shows where the paper bends into the printer
- Code anchors: `RDepth.swift:17` (`rSunken`)

Spec:
- `DesignSystemV2/Components/Ticket/RPrinterSlot.swift`: `struct RPrinterSlot: View` with `width` (the ticket's + 20), `state` (`.rest`, `.printing`, `.done`).
- **At rest** (T1, Paper under `2I0Y-0`): 374 × 8 (`width` = the ticket's 354 + 20), pill, `background.sunken`, sunken shade `0 2 3` inset, outer stroke 0.5 inset, and a 1pt lip highlight below it (`depth.stroke.innerTop` `0 1 0`, outside).
- **Printing** (T2a `2IGU-0`): the slot becomes a mouth 374 × 24 whose bottom is an 8pt `background.sunken` band curved as a smile (bottom radii 50% × 100%), with an inner cast `0 −2 3` (`depth.shadow.cast`) and the `0 1 0` lip highlight; it overlaps the printed paper by 28 (it sits over the paper's bottom edge, `zIndex` above it).
- **The printed window** (T2a "printed so far" `2IGT-0`): the paper is visible only above the lip: clipped 196 below the slot window's top, with the clip's bottom edge following the same smile (an ellipse 187 × 24 centred at 196). The window has 12 top padding and 10 side padding (so the 354 paper sits centred in the 374 slot).
- **The bend band** (T2a `2IV7-0`): 354 wide (10 in from each side), 56 tall, along the window's bottom: a vertical gradient in oklab from clear (0%) through `depth.shadow.ambient` (45%) to `depth.shadow.cast` (100%), over the paper, where it curls into the slot. **Paper differs** from the findings note's "a shading band": 56, not this card's first-draft 14.
- `.done`: the slot fades out on `curve.exit` 180 once the ticket's bottom edge has cleared it.

State table:

| State | Look | Motion | Haptic |
|---|---|---|---|
| rest (T1) | the 8pt bar, no band | appears with the title, `curve.standard` 280 | — |
| printing | the 24pt mouth + band; the bar morphs into the mouth as the print starts (`RMotion.snappy`) | band fades in 140 | (the rumble is PI2.1's) |
| done | gone | `curve.exit` 180 | — |
| dark | `background.sunken` dark (night.950) | — | — |

Interaction: none (decorative); `accessibilityHidden(true)`.

Steps: bar → lip path → band → states → gallery → snapshots.

Acceptance: matches T1 `2I01-0` and T2a `2IDN-0` in light; the band never shows outside printing; the lip reads as a curve at 1x.

Tests: (snapshot) rest, printing; light, dark · (unit) the slot is 20pt wider than the ticket width it's given

Proof in the PR: standard proof next to T1 and T2a.

Watch out: Paper fakes the curve (it can't do 3D); the real bend is PI2.1's `rotation3DEffect`, not this view.

---

### PI1 · The invite gate                                                              size: M
Place in the tree: first run › the invite › PI1
Repo · branch: NPRdoinglaundry · `ui/PI1-invite-gate`
Needs: UI4.0, C43, C41.1–C41.4, C42, C05 (`RPill`, #45), C19 (sheet, for the waitlist), C21 (`RToast`, #48)        Unblocks: PI2.1, T03a, PL1.8's wiring

Why: only invited people get in, but nobody hits a dead end: with a link, you see who kept you a place and sign in; without one, you type the code or join the waitlist.

Inputs:
- Contract: 01 §2.1 (preview), §2.2 (check), §3 (launch table); 00 §3 (sign-in errors), §4 (waitlist)
- Paper: round 2 T1 (link, signed out) and T-alt (type it in); round 1 D (`2H3N-0`: "enter your key", "open my invitation", "no invitation? join the waitlist", "13 letters and numbers · dashes and case don't matter"). **The waitlist sheet, the joined state, used/expired and suspended are not drawn**: build them on the lean below and ask the integrator for a small approval board before merging (README founder question I3).
- Code anchors: `Platform/Flows/Invite.swift` (FR0.2), `SampleInviteData` (UI4.0)

Spec (layout from Paper T1 `2I01-0` and T-alt `2IRH-0`, 402 × 874, 24 margins (`space.screenMargin`), 20 on SE):
- **The wallpaper** (T1's background, the same on every invite phone): `background.canvas` with three radial washes in oklab: `amber.200` at 34% (ellipse 65% × 34% at 90%, 0%), `sky.200` at 36% (ellipse 70% × 38% at 0%, 18%), `sky.100` at 40% (ellipse 60% × 26% at 50%, 34%); words and buttons sit on the plain lower part. FR0.1 adds it as the `invite` wallpaper recipe (palette dark twins in dark).
- **T1 · promise** (signed out, a code waiting): a column from y 200: a 300-tall block, bottom-aligned with 32 below (`space.8`), holding, 8 apart (`space.2`):
  1. "an invitation · from priya" (Geist 12 `text.sm` medium `text.label`, centred) — or nothing when the preview isn't live
  2. "priya kept a place for you." (display inky 30 `text.3xl`, `inkCard`, `tracking.title`, `leading.tight`, centred, balanced) — or "a place, kept for you." when not live
  3. then the printer slot at rest (C42, 374 × 8)
  4. 24 below (`space.6`): "sign in and your ticket prints." (SF Pro 17 `text.body`, `tracking.card`, `leading.snug`, `text.secondary`, centred, balanced)
  5. the bottom zone (12 apart, 40 bottom padding): C43 (Apple only in Beta 1), the legal line.
- **The footer line** on T2–T5 sits where the sign-in buttons were (Geist 12 `text.sm`, `text.label`, centred): "one use · once it's torn, it's yours" (T2a, T2, T3), "the stub stays with you" (T4), none on T5 ("begin" takes the zone), "one use · yours alone" on a refusal. T-alt has no footer line: its foot is the waitlist button (founder, 26 Oct, SI.gate.b).
- **T-alt · typed: founder redesign, 26 Oct (SI.gate.b), wins over the text below and over Paper `2IRH-0`:** the header ("an invitation · from priya", "no. 0412", the stub's date) shows before the check in sample data only (the live page learns them from the check, as before); "the link didn't bring the code? type it in." is the small pill (the old hint's style) and "the tear unlocks when it's filled" is gone; a failure's words replace the pill as the caption; the page-foot "one use · yours alone" is gone and "no invitation? join the waitlist" is a secondary `RButton` at the foot (40 from the edge, above the keyboard when it is up). Refusals keep the text link and their footer.
- **T-alt · typed (before 26 Oct)** (signed in, waitlisted, no code): the ticket (C41, whole, typed mode) with its top at y 104 (Paper's stage padding; the same place as the printed ticket in T2), face `nil` until a usable check; the caption 24 below (`space.6`, gap 4): "the link didn't bring the code? type it in." (SF Pro 17 `text.secondary`, centred) and the hint pill "the tear unlocks when it's filled" (Paper `2ISG-0`: 32 tall `size.control.small`, 12 side padding, 8 gap, `surface.wash`, Geist 12 medium `text.secondary`, a 14pt glyph trailing; not pressable). Not drawn on the board, lean: "no invitation? join the waitlist" (`text.link` SF Pro 17 medium, 44 hit) above the footer, from round 1 D (`2H3N-0`).
- **Checking the typed code:** on the 13th character, `type(code:)` is called (the keyboard stays up). Usable → the face's "· from priya" and serial blur in, the pill blur-replaces to "swipe along the line to tear →", the keyboard dismisses, the handle fades in: the page hands over to PI2 at `ready` (no print: the ticket is already here). Invalid → C41.4's wrong-code shake and clear, `warning`, and the caption line blur-replaces to "that code didn't work. check it, or ask for a new one." (`text.secondary`; never red: the words carry it). Rate limited → "too many tries. try again in a minute." and the field disabled until `retryAfter` passes.
- **Used / expired** (from a link or typed): the ticket prints (PI2.1) with "already used" / "expired" on the stub and no handle; the line under it: "this one's been used. ask for another, or join the waitlist." / "this one has expired. ask for another, or join the waitlist."; the waitlist link stays.
- **Offline:** where "printing your ticket…" would be: the `offline` glyph + "waiting for a connection" (Geist 12 `text.label`); the print starts on its own when `isOnline` turns true. In T1 offline: C43 disabled state.
- **The waitlist** (lean, to be drawn): tapping the link opens a C19 sheet (`background.raised`, sheet spacing by group): title "join the waitlist" (display inky 22), one line "we'll send you a link when there's a place." (`text.secondary`), an optional sunken field "anything you'd like us to know?" (≤ 280, `RSunkenField` #53, counter appears at 240), the lit "join" (C01) and text "cancel". Joined → the sheet settles away and the page shows, in place of the ticket's line: "you're on the list." (display inky 22) and "if a friend sends you a link first, open it and you're in." (`text.secondary`); the typed ticket stays, so a code can still be typed.
- **Suspended:** the page shows only the title "your account is paused." (display inky 22) and nothing else (contract 00 §2).
- **Already in** (a member opens a link): no page; a C21 toast "you're already in." once, and the code is dropped (PL1.7).

Interaction sheet:

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | arrive from a link (T1) | wallpaper fades up, then the label, title, slot and line stagger in (`.rAppear`, 60ms apart, 8pt rise, blur 8 → 0) | `curve.standard` 280 each | none | 140 cross-fade, all at once |
| 2 | tap Sign in with Apple | Apple's sheet; on return the buttons disable and the line blur-replaces to "signing you in…" with a 20 `RSpinner` leading | `.rBlurReplace` 220 | none | fade |
| 3 | sign-in succeeds | the buttons and legal line leave (`curve.exit` 180, 8pt fall), the line becomes "printing your ticket…", PI2.1 begins | exit 180 then PI2.1 | (PI2.1's rumble) | fade |
| 4 | sign-in cancelled | nothing changes | — | none | — |
| 5 | sign-in fails | "that didn't work. nothing is lost; try again." above the buttons | `.rBlurReplace` | `error` | fade |
| 6 | arrive with no code (T-alt) | the ticket fades up with an 8pt rise; the keyboard rises; the caret blinks on tile 1 | `RMotion.settle` for the ticket, system keyboard curve | none | 140 fade, keyboard as system |
| 7 | type characters | each tile sharpens in (C41.4) | `curve.standard` 120 | none (system keys) | whole glyph, no blur |
| 8 | the 13th character, usable | face from-line and serial blur in; pill text replaces; keyboard down; handle fades in | `.rBlurReplace` 220, handle 200 | `confirm` as the handle lands | fade |
| 9 | the 13th character, wrong | stub shakes once; tiles clear right to left; the line replaces | `rShake` on `snappy`, clear 30ms apart | `warning` | no shake: tiles fade 140; haptic stays |
| 10 | tap "join the waitlist" | the sheet rises | `RMotion.sheet` | `sheetSnap` at rest | fade |
| 11 | tap "join" | lit press; pending dots; joined → sheet settles away; the page's line becomes "you're on the list." | `.rPress`, `sheetDismiss`, `.rBlurReplace` | `press` on touch down, `confirm` on land | fade |
| 12 | connection returns while waiting | "waiting for a connection" blur-replaces to "printing your ticket…" and PI2.1 starts | `.rBlurReplace` | — | fade |

Page states (T02 `-Screen PI1 -State …`): `promise`, `promiseNeutral`, `signingIn`, `signInFailed`, `typed`, `typedWrong`, `used`, `expired`, `offline`, `waitlistSheet`, `waitlisted`, `rateLimited`, `suspended`. Root identifier `screen.PI1`; state ids `invite.promise`, `invite.typed`, `invite.waitlisted`, `invite.refused`.

The one lit object: none on T1 (Apple's black button leads, as on the splash); in the waitlist sheet, "join".

Accessibility:
- Rotor order T1: label + title (one heading: "priya kept a place for you") → line → Sign in with Apple → legal links.
- T-alt: the ticket (as C41) → the code field (focused on arrival, announced "invitation code, 0 of 13 characters") → the line → the waitlist link.
- Outcomes announce once: "code accepted. swipe along the line to tear, or use the tear action." / "that code didn't work."
- `performAccessibilityAudit()` passes in `promise`, `typed`, `used` and `waitlisted`.
- AX3: the title wraps (balanced), the ticket keeps its width and the page scrolls; SE: 20 margins, the mesh band 104.

Steps: layout for T1 → T-alt with typing → refusals and offline → the waitlist sheet and joined → suspended → page states in the launcher → UI and audit tests.

Acceptance:
- T1 `2I01-0` and T-alt `2IRH-0` match value for value in light (dark: token swap, founder checks: no dark board exists).
- The page never shows the inviter's name unless the preview or check said it.
- Every row of the interaction sheet is built and recorded.
- No state is a dead end: every refusal offers the waitlist.

Tests:
- (snapshot) every page state above; light, dark, ax3; SE for `promise` and `typed`
- (UI) a signed-out link shows "priya kept a place for you." and the Apple button
- (UI) typing the sample code unlocks the tear (the handle appears; identifier `ticket.handle`)
- (UI) a wrong code shakes, clears and says so
- (UI) a used code shows "already used" and no handle, and offers the waitlist
- (UI) joining the waitlist shows "you're on the list."
- (UI) offline shows "waiting for a connection" and prints when back online (the sample flips `isOnline`)
- (accessibility) the audit passes in promise, typed, used and waitlisted

Proof in the PR: page proof (ui-engineer.md §5) next to T1 `2I01-0` and T-alt `2IRH-0`; recordings of rows 1, 6, 8, 9 and 11; SE screenshots.

Watch out:
- The typed path and the link path end in the same PI2 `ready`: one ticket instance throughout (never swap views mid-moment).
- Don't show "you're on the list" until `joinWaitlist` returned; offline, the "join" button is disabled with "connect to join".
- Copy is lowercase and the founder's; the strings above are the lean and live in one strings table for review.

---

### PI2 · M14 "you're in": the print, the tear, the gift   4 bytes: PI2.1 M, PI2.2 M, PI2.3 M, PI2.4 M
Place in the tree: first run › the invite › PI2 (M14)
Repo · branches: NPRdoinglaundry · `ui/PI2.1-ticket-print`, `ui/PI2.2-ticket-tear`, `ui/PI2.3-youre-in`, `ui/PI2.4-ticket-accessible-path`
Needs: PI1, C41.1–C41.5, C42, FR0.1, UI4.0; PI2.2 needs PI2.1; PI2.3 needs PI2.2; PI2.4 needs PI2.3        Unblocks: T03a, PL1.8's wiring, the founder's sign-off (ship gate for Beta 1)

Why: being let in should feel like being handed a gift. A ticket prints for you with a soft rumble in your hand; you tear it off yourself, hole by hole; the stub falls free and stays with you; "you're in, sam. priya gave you this. make it count."

Inputs:
- Paper: round 2 board `2HXA-0`, section 2 phones T1 `2I01-0`, T2a (printing) `2IDN-0`, T2 (ready to tear) `2I39-0`, T3 (tearing, 40%) `2I6G-0`, T4 (torn, the stub kept) `2IH2-0`, T5 (you're in) `2IM6-0`, T-alt `2IRH-0`; and "how it moves and feels" (`2IUU-0` print · gesture · threshold · motion; `2IUX-0` haptics · sound · accessibility · edge cases), quoted in the spec below. Positions (read 21 Oct): the printer's window top at y 276 on T2a; the ticket's top at y 104 on T2–T5; T3's torn stub hangs 18 below the body (`gap 18`), drawn rotated +16.2°; T4/T5's stub 72 below, −14.8°, centred; "you're in" 32 below the stub (`space.8`), title and subline 8 apart
- Build notes (21 Oct): printing curves out of the slot (`rotation3DEffect(.degrees(-14), axis: (1,0,0), anchor: .bottom, perspective: 0.6)`, easing flat as it finishes, a soft shadow band at the slot mouth, a curved lip); the torn stub falls clear (about 72pt below the ticket at about −15°; no part of it under the top half)
- Motion: `design-system/principles/motion-system.md` §1 (never linear except what follows a finger), §3 springs, §4 ramps (velocity hand-off, rubber band 0.55, interrupt), §5 haptics; FR0.1's new tokens
- Contract: 01 §2.2–§2.3 (check before the print, redeem at separation, idempotent for the redeemer)
- Code anchors: `Tokens.swift:602` (`RMotion`), `:628` (`RHaptic`), FR0.1's `RHaptic.Rumble` player; `RMotionModifiers.swift:93` (`rPop`)

#### The whole moment, frame by frame (light, 17 Pro)

| t (s) | Beat | What moves | Spring / curve | Haptic |
|---|---|---|---|---|
| 0.00 | sign-in returns | buttons and legal line fall 8pt and fade | `curve.exit` 180 | — |
| 0.10 | the line | "sign in and your ticket prints." blur-replaces to "printing your ticket…" | `.rBlurReplace` 220 | — |
| 0.25 | the slot readies | the label and title fade up and out (`curve.exit` 180) while the slot rises from T1's y to T2a's (window top at 276) and morphs from the 8pt bar into the 24pt mouth (C42) | `RMotion.gentle` | — |
| 0.70 | the print starts | the ticket rises out of the slot top edge first, tilted −14° about x at the slot (`perspective` 0.6), revealed line by line through the curved window (C42) | `motion.curve.print` over `motion.duration.print` 1.8s; the tilt eases to 0 on the same curve | `RHaptic.Rumble.print` starts |
| 1.70 | the face is out | the mesh and words are fully out; the perforation passes the lip | (same) | rumble continues |
| 2.30 | the stub prints last | the code tiles come out | (same) | — |
| 2.50 | the print lands | the tilt is 0; the ticket lifts free of the slot and glides up to its T2 place (top at y 104), settling; the slot fades away | `RMotion.gentle` (the glide), `RMotion.settle` (the landing), slot `curve.exit` 180 | rumble ends with its decay (0.15s); one `select` as it settles |
| 2.75 | the hint | "it's yours to take, sam." and the pill "swipe along the line to tear →" fade in; the handle fades into the left notch | `curve.standard` 250 (the board's 0.25s) | — |
| … | the person tears | PI2.2 | 1:1 with the finger | `select` on notch touch-down; `select` per hole (throttled) |
| release past 62% (or a flick > 800 pt/s) | sealing | the stub runs to the end of the line on the finger's velocity; redeem is sent | `RMotion.snappy` with the release velocity | — |
| redeem answers | separation | the stub lets go, rotates to −14.8° and drops to 72 below the body, centred (T4), floating on `settle`; the body settles back 2pt | stub `RMotion.settle`; body `settle` | `RHaptic.rip` on the frame the stub lets go |
| +0.35 | "it's yours." | the line under the ticket blur-replaces to "it's yours." | `.rBlurReplace` 220 | — |
| +0.90 | "you're in" | "it's yours." leaves; "you're in, sam." (display inky 30 `text.3xl`, `inkCard`, `tracking.title`, `leading.tight`, centred) and "priya gave you this. make it count." (SF Pro 17 `text.secondary`, centred, balanced) rise in 32 under the stub, 8 apart (8pt rise, blur 8 → 0, 60ms apart); the footer line fades out | `curve.standard` 280 | `RHaptic.reveal` as the title lands |
| +1.30 | begin | the lit "begin" (Paper `2IRE-0`: C01 primary, 60 tall `size.control.hero`, pill, full column width, in the bottom zone with 40 below; label SF Pro 17 semibold `glow.primary.foreground`; the glow stack rim `0 1 0` inset, edge `0 −1 1.5` inset, bloom `0 0 6` inset, ring 1.5, halo `0 6 14 −4`, cast `0 2 2`) fades in last and breathes its one-time halo pulse | `curve.standard` 280; pulse per motion-system §6 | — |

The founder's board says "about 2.5 s after sign-in succeeds … about 1.8 s": this card reads it as the print sequence ending about 2.5 s after sign-in, with the rise itself taking 1.8 s. Check the recording against the board's filmstrip and ask if it reads wrong.

#### PI2.1 · The print                                                                size: M
- `Features/Invite/TicketMoment.swift` owns the moment as one view with a phase enum `TicketPhase { case promise, printing, ready, tearing(CGFloat), sealing, torn, youreIn }` and one ticket instance throughout.
- The rise: the ticket is clipped above the slot's lip (a mask whose bottom edge is the lip's curve, so the paper is never visible below the slot) and offset from `+height` to 0. `rotation3DEffect(.degrees(-14 * (1 - p)), axis: (1, 0, 0), anchor: .bottom, perspective: 0.6)` where `p` is the print progress, so it curves out of the slot and eases flat (build note). Driven by one `p` animated with `RMotion.print` (FR0.1: `motion.curve.print` over `motion.duration.print`), not by a timer.
- "A line at a time": the rise is continuous (stepped motion judders at 120Hz); the rumble's grain carries the receipt-printer feel. The stub's tiles become visible last because they're at the bottom: nothing extra to sequence.
- The shading band (C42) fades in at the start and out as `p` reaches 0.9.
- The rumble: `RHaptic.Rumble.print.start()` at the first frame of the rise, `.stop()` when `p` reaches 1 (FR0.1's continuous Core Haptics event, intensity 0.25, sharpness 0.1, with grain). Skipped when system haptics are off.
- The check happens before the print (PL1.7d does it at sign-in): the print never starts until the face is known; refused codes print with the refused stub (C41.4) and stop at `ready` without a handle.
- Offline: the phase holds at `promise` with "waiting for a connection"; it starts on its own when back online.
- Interruption: if the app goes to the background mid-print, the print completes instantly on return (no replay), with no rumble.

#### PI2.2 · The tear                                                                 size: M
- **Where:** the finger lands on the handle (32 visual, 44 × 44 hit area on the left notch). Touch-down: the handle presses to 0.94 (`.rPress` small) and `RHaptic.select` fires.
- **Drag:** a `DragGesture(minimumDistance: 0, coordinateSpace: .named("ticket"))` on the handle; the tear point follows the finger's x 1:1 along the perforation (linear is allowed here: it follows the finger); the finger may wander up to 44pt above or below the line without losing the tear; beyond that the drag ends as a release.
- **Rubber band:** before the start or past the end, movement scales by `motion.gesture.rubberBand` 0.55.
- **Peel, not cut:** the stub stays joined ahead of the finger and curls down behind it: the torn length of the stub (from the left notch to the tear point) rotates about the tear point, drooping up to 11° (`motion.tear.droop`, FR0.1; the board's text says 10–12°) in proportion to the torn length. **Paper differs:** T3 `2I6G-0` draws the whole stub piece hanging 18 below at +16.2°, because Paper can't bend part of a shape; the text is the behaviour, the drawing is a still: build the text and show both in the PR; a soft shadow under the torn edge grows with it (`depth.shadow.cast` at up to 60%, 6pt blur). The body's torn edge keeps its hole half-circles (C41.3 `tearProgress`).
- **Ticks:** `RHaptic.select` each time the tear passes a hole (about every 14pt), throttled to at most one per 40ms on a fast drag (the board's rule; motion-system's 80ms floor is overridden here by the founder's board, noted in the PR).
- **The line under the ticket:** after the first hole, "it's yours to take, sam." blur-replaces to "keep going." and the pill fades out.
- **Threshold:** release past 62% of the line (`motion.tear.threshold`) or a rightward flick faster than 800 pt/s (`motion.tear.flickVelocity`) commits; anything else springs back to untorn on `RMotion.snappy` from the release velocity, the holes reappear, the line returns to "it's yours to take, sam."
- **Commit = sealing:** the stub runs to the end on `snappy` with the release velocity and holds there, still joined at the last hole, while `tear()` (redeem) is in flight: no separation, no rip, until the server answers. Over 400ms: the line blur-replaces to "sealing it…" (never a spinner on the ticket). Over 8s, or `.offline`, or any failure: the stub springs back untorn (`snappy`), `RHaptic.warning`, and the line says what happened ("waiting for a connection. nothing was used." / "that didn't go through. nothing was used; try again." / `.used`: "someone else used this one just now." with the waitlist link). The tear never completes offline (the board).
- **Interrupted:** a phone call, the app backgrounding, or the gesture cancelling (`onEnded` never fires) → spring back untorn; on relaunch mid-tear the ticket shows whole (nothing is spent until separation).

#### PI2.3 · Separation and "you're in"                                             size: M
- On redeem success: `RHaptic.rip` (FR0.1: rigid impact, intensity 0.8) on the frame the stub lets go.
- The stub piece (C41.5) rotates to −14.8° and drops so that it sits 72 below the body, centred (Paper T4 `2II6-0` `gap 72`; no corner under the body, c-4atq2k), on `RMotion.settle` carrying the tear's velocity; it stays as a keepsake with the code on it, the date set to `invite.redeemedOn`.
- The body settles back 2pt on `settle`. The board's text says "its warm glow arrives on pop", but **Paper differs**: T4 `2IH2-0` and T5 draw no glow (the round 2 overview export from earlier in the day showed one; the current phones don't). Paper wins: no glow, and the founder decides (README question I5). If the answer is yes: a soft amber halo (`palette.amber.300` at 30%, 24 blur, behind the body only) arriving on `RMotion.pop`, once, never breathing.
- The words: "it's yours." (T4), then "you're in, sam." + "priya gave you this. make it count." rise under the stub (T5), with `RHaptic.reveal` as the title lands. No `firstName` → "you're in."; no `invitedBy` (review invite) → "someone kept this for you. make it count." (lean; the strings table).
- "begin" (C01 primary, the screen's one lit object) fades in last, 1.3 s after the rip, with the one-time halo pulse; tapping it: `RHaptic.press`, and `begin()` (the data object records "you're in seen" for this account and the root moves on: Beta 1 into the current onboarding, phase 2 to ON-3).
- **Static you're in** (`youreInStatic`: relaunched after the tear, before "begin"): T5 as a still page with the keepsake stub already fallen, no motion but the words' stagger, no haptic.
- **SE** (not drawn; the design system decides): the ticket top moves from 104 to 72, the mesh is 104 tall, and the stub drops 56 instead of 72 (still clear of the body at −14.8°), so "you're in" and "begin" fit above the home indicator without scrolling. Never a scaled-down ticket.

#### PI2.4 · The accessible path, interruptions and proof                          size: M
- **Reduce Motion** (the board): no print rise (the ticket fades in 140 under the slot, no tilt, no band); the tear becomes a 0.6 s press-and-hold on the handle with a progress fill along the perforation (`ink.default` filling the holes left to right, `curve.move`), then a 140 cross-fade to torn (stub in its keepsake place, no fall). Haptics stay (the rumble during the fade-in, `select` at each third of the hold, `rip`, `reveal`). Releasing before 0.6 s empties the fill on `curve.exit` 110.
- **VoiceOver:** the ticket element (C41) carries the custom action "tear ticket", which runs the whole sequence (sealing included) and announces the result once: "it's yours. you're in." (or the failure line). The handle is hidden from VoiceOver (the action replaces it). "begin" is focused after the announcement.
- **Switch Control / Full Keyboard Access:** the same "tear ticket" action is reachable; the drag is never the only way.
- **Never colour alone:** every state is words ("keep going.", "it's yours.").
- **Sound:** none (the board: optional, off by default; the founder's call, question I4).
- **Interruptions, tested:** background mid-print (completes on return, no replay), background mid-tear (springs back), call mid-sealing (the redeem continues; the result shows on return), relaunch at every phase (`promise` → T1 again; `printing`/`ready`/`tearing`/`sealing` → `ready` whole, check again; `torn`/`youreIn` → `youreInStatic`).
- **The visual pass** (motion-system §9) for M14, as one PR's proof: 120fps recordings of the whole moment and with Slow Animations; frame-by-frame ramp check (no linear segment except the finger-follow; the print curve has no jump on its first frame); interrupted tear (release at 40% and at 61%, flick at 30%); Instruments Animation Hitches with 0 hitches over 5 runs on the integrator's 17 Pro and on the founder's phone through TestFlight; the haptic lands on the rip frame; Reduce Motion recording; founder sign-off (M14 is a signature moment).

State table (page; T02 `-Screen PI2 -State …`):

| State | What shows |
|---|---|
| `printing` | T2a mid-print (p = 0.5): tilted, band on, "printing your ticket…" |
| `ready` | T2: whole ticket, handle, "it's yours to take, sam.", the pill |
| `tearing` | T3 at 40%: drooping stub, the handle riding at x 128, "keep going." |
| `sealing` | stub at the end, joined, "sealing it…" |
| `torn` | T4: body, stub fallen 72 below at −14.8°, "it's yours.", footer "the stub stays with you" |
| `youreIn` | T5 with "begin" |
| `youreInStatic` | T5 still |
| `tearOffline` / `tearRefused` | sprung back with the line |
| `reduceMotion.ready` / `reduceMotion.holding` | the hold fill at 0 / 50% |
| `noName` | "you're in." |

Accessibility (page): rotor order ticket (with "tear ticket") → line → (after) title → subline → begin; `performAccessibilityAudit()` passes in `ready`, `youreIn` and `reduceMotion.ready`; AX3: words scale, the ticket holds its width, the page scrolls so "begin" is always reachable.

Acceptance (the moment):
- Recorded on the 17 Pro and SE, light and dark, it matches T1 → T2a → T2 → T3 → T4 → T5 in order and position (each still from the recording next to its phone); the founder signs it off from the recordings.
- Nothing is spent until separation: killing the app at any point before the rip leaves the code unused (staging check in T03a).
- The tear follows the finger exactly, springs back below 62%, and commits past it or on a fast flick.
- The rumble plays for the whole print and stops with it; one tick per hole, never faster than one per 40ms; the rip lands on the separation frame; `reveal` lands with "you're in".
- Reduce Motion and VoiceOver each complete the moment without a drag.
- One lit object: "begin", and only at the end.

Tests:
- (unit) the tear model: progress from x is clamped, the rubber band applies past the ends, 0.61 springs back, 0.62 commits, a 900 pt/s flick at 0.3 commits, 700 pt/s doesn't
- (unit) the hole tick fires once per hole and never twice within 40ms (injected clock)
- (unit) the phase machine: every relaunch phase maps to the state above
- (unit) sealing over 8s returns to `ready` with the failure line (injected clock)
- (snapshot) every page state above; light, dark, ax3; SE for `ready`, `torn`, `youreIn`
- (UI) dragging the handle past the threshold reaches "you're in" (XCUI `press(forDuration:thenDragTo:)` on `ticket.handle`)
- (UI) a short drag springs back and the ticket is whole (`ticket.whole` exists)
- (UI) the VoiceOver custom action "tear ticket" reaches "you're in"
- (UI) with `-ReduceMotion YES`, holding the handle 0.6 s reaches "you're in"
- (UI) offline, the tear springs back and says nothing was used
- (motion) Animation Hitches: 0 over 5 runs of the whole moment (layer 10, M14 is in Beta 1's list)
- (unit, DEBUG haptic recorder) the haptic sequence for one full run is `[rumble.start, rumble.stop, select(settle), select(notch), select × holes passed, rip, reveal, press]`

Proof in the PR: per byte, the standard proof plus: PI2.1 the print recording next to T2a `2IDN-0` and T2 `2I39-0`; PI2.2 the tear recording with an interrupted release at 40% and 61%; PI2.3 the separation and "you're in" recording next to T4 `2IH2-0` and T5 `2IM6-0`; PI2.4 the Reduce Motion and VoiceOver recordings, the Instruments trace and the haptic recorder log.

Watch out:
- One ticket instance and one phase value: never cross-fade between "printing" and "ready" views, or the paper jumps.
- `rotation3DEffect` with `perspective` changes the hit area: the handle's gesture lives in a non-rotated overlay positioned from the ticket's layout frame.
- The redeem must happen at separation and only once: the data object owns the idempotency key made at touch-down (PL1.7d); a second "tear ticket" action while sealing does nothing.
- Never fire the rumble, ticks or rip when system haptics are off (`CHHapticEngine.capabilitiesForHardware().supportsHaptics` and the user setting): FR0.1's player checks it, don't re-check here.
- "It's yours." must never show before the server said so.
- The board says ticks per hole at 40ms; motion-system says at most one haptic per 80ms. The founder's board is newer and specific: follow it, and list the exception in the PR.

---

### T03a · The invite flow test (Beta 1)                                            size: S
Place in the tree: first run › flow tests › the invite
Repo · branch: NPRdoinglaundry · `ui/T03a-invite-flow` (with the integrator for the staging half)
Needs: PI1, PI2.1–PI2.4, PL1.8        Unblocks: Beta 1's ship gate (the invite half)

Why: one test proves the whole way in works: a link opens the promise, sign-in prints the ticket, the tear lets you in, and a used or missing code never strands anyone.

Inputs: testing.md layer 8 (flow tests on sample data) and layer 9 (local staging); PI1 and PI2 state lists; contract 01 §2.

Spec:
- **On sample data** (`RetrospectUITests/V2/InviteFlowTests.swift`, `-Data sample`):
  1. `promise` → tap Apple (the sample's sign-in) → print → drag the handle past the threshold → "you're in, sam." → "begin" → the root's next screen identifier (`screen.onboarding.legacy` in Beta 1).
  2. `typed` → type the sample code → the tear → you're in.
  3. `typed` → a wrong code → the line says so → type the right one → tear.
  4. `used` → no handle → the waitlist → joined.
  5. `ready` → background the app mid-drag (`XCUIDevice.shared.press(.home)` then activate) → whole.
- **On local staging** (`-Data live -Environment local -Account fresh`, the integrator's run): a seeded founder invite link opened with `xcrun simctl openurl` → sign in with the staging test Apple account → tear → `GET /v2/access` says approved and `GET /v2/invites/mine` lists three invites (counts only); repeat with the same link on a second fresh account → "already used".

Acceptance: all five sample runs pass in CI (nightly and on PI page PRs); the staging run passes before the Beta 1 TestFlight build.

Tests: the five above, named as sentences ("a link, sign-in and a tear let a new person in"; "a typed code lets a new person in"; "a wrong code says so and the right one still works"; "a used code offers the waitlist"; "leaving mid-tear leaves the ticket whole").

Proof in the PR: the test run output; the staging run's log (counts only, no codes).

Watch out: never print or log the invite code in test output (use the fixture constant's name, not its value, in failure messages).

---

# §B · Sign in (phase 2)

### UI4.8 · SampleFirstRunData                                                     size: M
Place in the tree: first run › data seam › sample implementation (phase 2)
Repo · branch: NPRdoinglaundry · `ui/UI4.8-sample-first-run-data`
Needs: FR0.3 (`Platform/Flows/FirstRun.swift`, the integrator), T02, UI4.0        Unblocks: every §B–§F card's previews and pages, T03b

Why: the whole first run (splash to first home) can be built and walked through in every state before a single door exists.

Inputs: contract 01 §3–§8 and every `fixtures/01/*.json`; `Platform/Flows/FirstRun.swift` (`FirstRunData`: `stage`, `questions`, `answer(_:)`, `skip(_:)`, `sources`, `connect(_:)`, `knowsYou`, `job`, `episode`, `offering`, `purchase(_:)`, `restore()`, `notNow()`, `recap`, `askForPush()`, `complete()`); UI1.0 for the pattern.

Spec:
- `Features/FirstRun/Sample/SampleFirstRunData.swift`, `@MainActor @Observable`, `(scenario:clock:)`, content decoded from the fixtures; the question copy comes from the app's strings table (the app owns it, contract 01 §1), not from the sample.
- Scenarios (T02 `-State` for P01–P08, P32, PX): `splash`, `signInFailed`, `returning`, `restoring`, `restoreFailed`, `updateRequired`; `asking` (question typing out), `listening`, `answered`, `quickAnswers`, `muted`, `typing`, `didntCatch`, `noMic`, `offline`, `talkOrType`, `howStraight`, `briefTime`, `fallbackYesterday`; `privacy`; `connectNone`, `connecting`, `connectedOne`, `connectFailed`, `knowsWell`; `ready.reading`, `ready.writing`, `ready.voicing`, `ready.done`, `ready.quiet`, `ready.failed`, `pushAsk`; `tease`; `paywall`, `pricesLoading`, `purchasePending`, `purchaseFailed`, `purchaseCancelled`, `paywallOffline`, `subscribed`; `firstHome`, `firstHome.quiet`; `long` (a 1,000-character answer), `dayOneSE`.
- Behaviour on the injected clock: the job walks reading → writing → voicing → ready in 3 s steps; `purchase` succeeds after 1 s (`purchaseFailed` fails with "the purchase didn't go through, nothing was charged."); prices are the fixture offering's localized strings ("$19.99", "$199.99"), the only place a price literal may exist, and only in sample content.
- Ledger rows for every value.

Steps: scenarios → content → behaviour → launcher registration (`Features/FirstRun/FirstRunScreens+Launcher.swift`) → ledger.

Acceptance: every scenario opens with its screen id; nothing reads the network.

Tests: (unit) every scenario builds; (unit) the job walks its steps on the injected clock; (unit) sample answers decode from `answers.list.json`; (unit) no price string exists outside `Features/FirstRun/Sample/` (a source scan).

Proof in the PR: test output; ledger diff.

Watch out: prices are never typed into anything but the sample; the live offering always supplies them (D6).

---

### S10 · The mark (38, 22, 16)                                                       size: S
Place in the tree: first run › shared › the mark (also the player header, widgets)
Repo · branch: NPRdoinglaundry · `ui/S10-the-mark`
Needs: T01        Unblocks: P02 (the loading state's mark), P06 (the player header at 22), P32, EX-4

Why: Retro's one quiet sign looks the same everywhere it appears.

Inputs: `design-system/components/the-mark.md` + handoff "The mark (21 Oct)" (newer); Paper master "c · the mark" `SUL-0`; instances `26PQ-0` (22), `26PR-0` (glyph); design-reference §S10.

Spec: `RMark(size: .s38 | .s22 | .s16)`: a round cream disc (`surface.secondaryAction`), ring 1pt `border.secondaryRing` at 75% outside a 1pt white inner border (the raised double stroke), grain `material.grain.signature` (seed 7, 6%), the asset `retrospect-loading-mark` as a template image tinted `icon.mark` at about 53% of the disc width, centred by mass; shadows: 38 = `elevation.mark` (`0 6 7` 24% + `0 1 2` 12%), 22 = `0 2 3` + `0 0.5 1`, 16 = contact only. Never a button, never animated, one per screen.

State table: rest only; dark: dark `surface.secondaryAction`, shadows black 45%, grain stays.

Interaction: none. Accessibility: `accessibilityHidden(true)` where a title already says retrospect, else "retrospect"; fixed size; Increase Contrast: glyph to 60%.

Steps: the disc → the glyph → three sizes → gallery → snapshots.

Acceptance: matches `SUL-0` at 38, 22, 16 in light and dark.

Tests: (snapshot) three sizes, light and dark, increase contrast · (unit) the glyph is 53% of the disc width at every size

Proof in the PR: standard proof next to `SUL-0`.

Watch out: the motion system's "the mark spins" for refresh is a conflict (reference §F 20): the mark never moves.

---

### C38.1 · You map, orbits at rest (for the splash and AC-1)                         size: M
Place in the tree: first run › sign in › splash › the map at rest (shared with you › YO-1, which adds life and data in C38)
Repo · branch: NPRdoinglaundry · `ui/C38.1-you-map-orbits-rest`
Needs: T01, #42 (artwork palette dark twins)        Unblocks: P01, P32; the you area's C38 builds on it

Why: the first thing you see is the shape of what Retro will know about you, still and beautiful, with no names (nothing is known yet).

Inputs: Paper `c:you-map/orbits/rest` `1F5K-0` (splash) and `1GYO-0` (AC-1), master part 05 `9BS-0`; build notes "You map" (frosted glass orbs, straight threads, rings behind, far orbs smaller and blurred); "Welcome back (AC-1) look" (no labels before auth; SE scale 0.78).

Spec: `RYouMap(style: .orbitsRest, labels: Labels)`: **Paper differs** from the build note "never show node names before auth": the splash's map `1F5K-0` draws four invented labels ("maya", "running", "the river", "work") on 20, 44 and 64 orbs, while AC-1 `1GYO-0` draws none. Both are Paper: the splash shows illustrative words (they aren't the person's data, nobody is signed in), AC-1 shows none (they'd look like the returning person's data). `labels: .illustrative([...])` on the splash, `.none` on AC-1; the strings live in the strings table. orbit rings first (hairline `border.subtle`), straight threads, then each orb as frosted glass (a 12% white base under its palette gradient, a 1.5pt backdrop blur, a top rim, a hairline, a soft cast); far orbs smaller, blurred and dimmed; the centre "you" orb 56 (`c:you-orb/56` `1GYN-0`). Layout from Paper coordinates (hand-crafted; never generated: the founder's note). Palette colours take their dark twins.

State table: rest; dark (twins); SE (scale 0.78); Reduce Transparency (orbs solid, no backdrop blur).

Interaction: none here (M01 adds the opening; YO-1 adds life). Accessibility: `accessibilityHidden(true)` (decorative before sign-in).

Steps: rings and threads → frosted orb → layout from Paper → dark and SE → gallery.

Acceptance: matches `1F5K-0` and `1GYO-0` in light and dark; no text anywhere.

Tests: (snapshot) splash crop, AC-1 crop, SE, dark, reduce transparency

Proof in the PR: standard proof next to both nodes.

Watch out: the you area owns the full map (C38); keep this byte to the static style and expose the orb and ring parts so C38 reuses them, not copies them. Tell the you-area planner (README "shared changes").

---

### P01 · ON-1/2 splash and sign-in                                                   size: M
Place in the tree: first run › sign in › ON-1/2
Repo · branch: NPRdoinglaundry · `ui/P01-splash`
Needs: C38.1, C43, UI4.8, PL1.9 (the launch stage)        Unblocks: M01, P32, T03b

Why: the first thing you see says who Retro is ("everything about you, finally connected.") and gives one way in.

Inputs: Paper `1F4Q-0` "ON-1/2 · splash + sign-in" (approved "yes for now, an experiment"); design-reference §Extra "Splash"; contract 00 §3; contract 01 §3 (the launch table).

Spec: the map (C38.1, `1F5K-0`, 402 × 380 in a 400-tall band that bleeds under the status bar) with the top-only wallpaper (amber from the top-trailing corner, sky from the top-leading, a pale glow behind the map, fading out by about 40%); the inky promise "everything about you, finally connected." (`1F5H-0`, display inky 30) and the subline "retrospect gets to know you, and tells you what it sees." (`1F5G-0`) resting just above the sign-in buttons (spacing 8 apart); C43 (Apple, then Google) 56 high in the bottom zone; the legal line. A link opened here (a pending invite code) switches the root to PI1 · T1 (PL1.9). After sign-in: `waitlisted` → PI1 · T-alt; `approved` → ON-3; `member` → home.

Interaction sheet:

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | arrive | M01's opening (P01 ships with the static map; M01 adds the motion) | — | none | — |
| 2 | sign in | C43; on return: "signing you in…" replaces the subline | `.rBlurReplace` | none | fade |
| 3 | fails | "that didn't work. nothing is lost; try again." above the buttons | `.rBlurReplace` | `error` | fade |
| 4 | succeeds | the page hands over to the next stage | `RMotion.gentle` cross-dissolve of the wallpaper into the next page's canvas | none | 140 fade |

States (`-Screen ON-1/2`): `splash`, `signingIn`, `signInFailed`, `offline` (C43 disabled with "connect to sign in").

Accessibility: rotor: promise (heading) → subline → Apple → Google → legal links; audit passes in `splash` and `signInFailed`; AX3: the map shrinks to keep the buttons in the bottom zone (the promise wraps); SE: map at 0.78.

Steps: layout → states → launcher → tests.

Acceptance: matches `1F4Q-0` in light, dark and AX3, and on SE; the lit object: none (Apple's button leads).

Tests: (snapshot) four states × light, dark, ax3; SE · (UI) signing in reaches the next stage (sample) · (UI) a failed sign-in says so and keeps the buttons · (accessibility) the audit passes

Proof in the PR: page proof next to `1F4Q-0`.

Watch out: the promise copy and opening are "an experiment" (the founder's tag): keep both in the strings table and `M01`'s switch, so changing them is one line.

---

### M01 · The opening (the splash moves)                                              size: M
Place in the tree: first run › sign in › ON-1/2 › signature moment M01
Repo · branch: NPRdoinglaundry · `ui/M01-splash-opening`
Needs: P01; the founder's pick of opening (README question F5)        Unblocks: T03b

Why: Retro's first second should feel alive and calm: the shape of you, assembling.

Inputs: Paper page "06 · splash motion · keyframes" (A constellation assembles, kept; B2 light from below; B3 one ray; D "the dots connect", ~4.5–4.9 s, `docs/design/motion/splash-d.html`); motion-system §6 "Splash and the mark" and §7 (the orb's halo breath, 0.35 ↔ 0.5 every 6 s); design-reference §C M01, §F 38.

Spec (on the lean, D "the dots connect", until the founder picks): four overlapping beats (each starting when the previous is about 70% done; `keyframeAnimator`): the you orb breathes in on `motion.curve.reveal`; the satellites drift into orbit on `RMotion.map`, staggered 60ms (at most 6, then the rest together); the threads draw from you outward over 420ms on `curve.standard`; the promise and buttons fade up last (`curve.standard` 280). Life afterwards: the orb's halo breath only (§7), paused on touch, off-screen, Low Power Mode and Reduce Motion. Tap anywhere skips to the end state at once (the board's tap-to-skip).

State table: playing, ended (static P01), skipped, reduced (everything present, a 140 fade), dark.

Interaction: tap during → skip (`RMotion.gentle` to the end positions, never a jump); no haptic (M01 has none).

Accessibility: the opening never delays VoiceOver: elements are present and focusable from frame 0; Reduce Motion shows the end state.

Steps: beats → overlap → skip → life gate → recordings.

Acceptance: matches the picked keyframe board's timings within 50ms per beat; no hitch; skip works at every beat.

Tests: (unit) skip from each beat lands on the static end layout · (motion) 0 hitches over 5 runs · (UI) the buttons are tappable during the opening

Proof in the PR: 120fps and Slow Animations recordings next to the keyframe board; interrupted (skip) recording; founder sign-off.

Watch out: never block sign-in behind the animation; the life gate checks Low Power Mode (`ProcessInfo.isLowPowerModeEnabled`).

---

### P32 · AC-1 welcome back                                                           size: M
Place in the tree: first run › sign in › AC-1 returning
Repo · branch: NPRdoinglaundry · `ui/P32-welcome-back`
Needs: C38.1, C43, UI4.8, PL1.9 (`hasSignedInBefore`)        Unblocks: T03b; settings' sign-out (AC-2) lands here

Why: when you come back after signing out, Retro greets you and brings everything back, without making you start over.

Inputs: Paper `1GXR-0` "AC-1 · 17 Pro · rest" with `c:you-orb/56` `1GYN-0`; handoff (restoring: ring + "bringing back your entries and episodes…", buttons disabled; failed: "that didn't work. nothing is lost; try again." above the buttons); build notes "Welcome back (AC-1) trigger" and "look" (the splash's warm wash plus the map without labels; SE 0.78).

Spec: the wash and map (C38.1, the you orb in place of the mark), "welcome back." (display inky 30), the subline, C43. After sign-in: restoring (`RSpinner` 20 + "bringing back your entries and episodes…", buttons disabled) while PL1.9 resolves the stage and the store's first reads land; then the stage's screen. Shown only when there's no session and `hasSignedInBefore` is set.

Interaction sheet: arrive (stagger, `curve.standard`); sign in (C43); restoring (`.rBlurReplace`); failed (`error` haptic, the line above the buttons); success (`RMotion.gentle` hand-over). Reduce Motion: fades.

States (`-Screen AC-1`): `returning`, `restoring`, `restoreFailed`, `offline`.

Accessibility: "welcome back" heading first; restoring announced once; audit passes in `returning` and `restoring`.

Steps: layout → restoring → failed → launcher → tests.

Acceptance: matches `1GXR-0` (light, dark, AX3, SE); never shows map labels.

Tests: (snapshot) four states × light, dark, ax3; SE · (UI) signing in shows restoring then home (sample) · (accessibility) audit

Proof in the PR: page proof next to `1GXR-0`.

Watch out: a brand-new phone has no `hasSignedInBefore` and shows the splash, even for a returning account (the server restores after sign-in).

---

### PX · The force-update screen                                                    size: S
Place in the tree: first run › gate › force update
Repo · branch: NPRdoinglaundry · `ui/PX-force-update`
Needs: PL1.6 (`updateRequired`), UI4.8; a Paper drawing (the integrator; README question F9; lean below)        Unblocks: ship gate G1, X07 (retiring old routes safely)

Why: when a very old version can't work any more, it says so plainly and takes you to the update, instead of breaking.

Inputs: contract 00 §2 (`update_required`), §5 (`/v2/meta`); design-reference §Extra "Force-update screen (X02)" (nothing designed; lean: a purpose page).

Spec (lean, a purpose page per screen-rules 2–3): the canvas with the mark (S10, 38) centred above the title; "there's a newer retrospect." (display inky 30); one plain line "this version can't keep up any more. update to keep going; nothing you've saved is lost." (`text.secondary`); the lit "update" (C01 primary) opening the App Store page (`itms-apps://apps.apple.com/app/id<appId>` from build configuration). It covers everything (a root cover from PL1.9) and can't be dismissed.

Interaction: arrive (140 fade); "update" (`press` haptic, `.rPress`, opens the store). Reduce Motion: same.

States (`-Screen PX`): `rest`, `offline` (the button still opens the store; no extra line).

Accessibility: heading first; the button labelled "update retrospect in the App Store"; audit passes.

Steps: layout → launcher → tests.

Acceptance: matches the approved drawing; can't be dismissed; the store link comes from configuration.

Tests: (snapshot) rest, light, dark, ax3 · (UI) "update" opens the store URL (asserted via the opener seam)

Proof in the PR: page proof next to the drawing.

Watch out: don't build before the drawing is approved (first-ship: "drawn in Paper first").

---

# §C · Getting to know you (phase 2)

### C35 · Onboarding progress                                                          size: S
Place in the tree: first run › getting to know you › ON-3–10 › progress
Repo · branch: NPRdoinglaundry · `ui/C35-onboarding-progress`
Needs: T01, S07 (`RProgressHairline`, merged)        Unblocks: P02.1, P03, P04, P05

Why: you always feel how far along setup is, without a count to stare at.

Inputs: Paper `c:onboarding-progress` `1F74-0`, `26NA-0` (ON-10 at ~92%); screen-rules 7; build notes "Onboarding question (part 42)"; motion-system §6 ("advances on `map` per step, never by percentage"); design-reference §C35, §F 41.

Spec: `ROnboardingProgress(step: Int, of: Int)` over `RProgressHairline`: a 3pt capsule under the status bar, track `surface.track`, fill `ink.default`, full width minus margins; the top bar sits `space.4` below. `step/of` sets the fill; nothing visible counts.

State table: rest; advancing (`RMotion.map`); dark. Interaction: none.

Accessibility: one element "onboarding progress, step 3 of 9" (founder question F12; lean: VoiceOver says the step, the screen never does); Reduce Motion: the fill jumps with a 140 fade.

Steps: wrap → VoiceOver value → gallery.

Acceptance: matches `1F74-0` and `26NA-0`; never shows a number.

Tests: (snapshot) 1 of 9, 5 of 9, 92%; light, dark · (unit) VoiceOver reads "step n of m" · (unit) the fill never moves backwards except on back navigation

Proof in the PR: standard proof.

Watch out: #38's review note: `RProgressHairline` reads a percentage today; this wrapper overrides the value.

---

### C17-o · Top bar, onboarding variant                                                 size: S
Place in the tree: first run › getting to know you › ON-3–10 › top bar
Repo · branch: NPRdoinglaundry · `ui/C17o-top-bar-onboarding`
Needs: C17 (journal plan)        Unblocks: P02.1, P03, P04, P05

Why: a quiet way back on every question, and nothing else competing with Retro's question.

Inputs: Paper `c:top-bar/onboarding` `1F6W-0`, `26N2-0`; screen-rules 6 (no skip; back top-left, the page label centred, nothing on the right); design-reference §F 4 (part 42 draws a skip; the founder's rule says no: founder question F2, lean no skip).

Spec: a C17 variant `.onboarding(label: String?)`: the 36 wash icon button with `chevron-left` leading, the page label (Geist 500 14 `text.secondary`) centred, the trailing slot empty. Back is hidden on the first question.

State table: rest, pressed (back 0.94), hidden back, dark. Interaction: back → previous question (`RMotion.sheet` reverse of the question's enter), haptic none.

Accessibility: back "back"; the label is not a heading (the question is).

Steps: variant → gallery → snapshots.

Acceptance: matches `1F6W-0` with no skip.

Tests: (snapshot) with and without back, light, dark, ax3

Proof in the PR: standard proof.

Watch out: if the founder keeps "skip", it's a trailing text button in this variant (one line), not a new component.

---

### C34 · The onboarding question                       3 bytes: C34.1 M, C34.2 S, C34.3 S
Place in the tree: first run › getting to know you › ON-3–9 › question
Repo · branches: NPRdoinglaundry · `ui/C34.1-question-types-out`, `ui/C34.2-your-words`, `ui/C34.3-quick-answers`
Needs: T01, #56 (`RVoiceComposer`), C05 (`RPill`), FR0.1 (`RHaptic.typeOn` player)        Unblocks: P02.1, P05

Why: Retro asks one question at a time, as if writing it to you, and your own words appear under it as you speak.

Inputs: `design-system/components/onboarding-question.md`; Paper part 42 `GD2-0`, `c:onboarding/question` `1F6V-0`, `c:onboarding/your-words` `1F6R-0`; build notes "Onboarding question (part 42)", "Onboarding questions · typing haptic (21 Oct)", "Onboarding quick answers · selected (c-6gtmpz)"; motion-system §6 (question text, M13, M03); design-reference §C34.

Spec:
- **C34.1 the question types out (M13):** display serif 30/34 inky (`font.exposure.title`), lowercase, in the top third; one title, no subtitle. Word by word: each word sharpens from a 1.5pt blur on `curve.standard` 120ms; `RHaptic.typeOn` once per word (never per letter), at most 10 a second, silent on spaces and punctuation; `prepare()` once when the question starts (FR0.1's soft generator at 0.35). Stops the moment listening starts. Reduce Motion: whole words at once, no haptic. Loading (first question): a blank page with the mark (S10 38) under 400ms nothing.
- **C34.2 your words, live, and the understood word (M03):** under the question, Exposure 28 (`font.size.2xl`) `inkCard` weight `text.secondary`; each recognised word appended as its own `Text`, blur 4 → 0 and opacity 0 → 1 over 200ms, staggered, the newest still resolving; the understood key word (a span the flow marks) ink-sharpens to `text.primary` over 280ms (`duration.slow`) with `RHaptic.confirm`. Very long answers stay whole (the page scrolls).
- **C34.3 quick answers:** up to five 36pt pills (44 hit) in a flow layout 8 apart; unselected `surface.wash`, selected lifts onto `background.raised` with the raised stack and a 14pt check leading, label `text.primary`; cross-fade 200ms and `RHaptic.select`; tapping appends its words to the composer, which switches to typing with the lit send (never auto-sends).

State table:

| State | Look | Motion | Haptic |
|---|---|---|---|
| asking | types out | M13 | `typeOn` per word |
| listening / thinking / speaking | the composer's (#56) | the composer's | `listenStart` / `listenStop` / `turn` |
| answered | your words above; the next question replaces this one, old words blur out upward | exit 180, enter 240 | `turn` |
| quick answer chosen | raised pill + check | 200 cross-fade | `select` |
| didn't catch that | the composer says "i didn't catch that" | blur-in | `warning` |
| offline | "you're offline · we'll pick up here" (Geist 12 `text.label`) | — | — |
| dark | tokens | — | — |

Interaction table: pill tap (0.94, `select`, appends); composer per #56; Reduce Motion: no blur, whole words.

Accessibility: the question is a heading, read first each turn (announced when it finishes typing, not per word); your words are one live region read when you stop; pills read "quick answer, <text>, selected"; AX3: question wraps, pills stack; Increase Contrast: secondary text up one step.

Steps: C34.1 type-out + haptic gate → C34.2 words + understood → C34.3 pills → gallery with each state.

Acceptance: matches part 42 and `1F6V-0`/`1F6R-0`; the typing haptic never fires per letter, never on punctuation, never faster than 10/s, and stops when listening starts.

Tests: (snapshot) asking (half typed), answered, pills selected, didn't catch, offline; light, dark, ax3 · (unit) the word splitter skips punctuation and spaces for haptics · (unit) the rate limiter allows at most 10 haptics a second (injected clock) · (unit DEBUG recorder) listening start stops `typeOn` · (UI) VoiceOver reads the question once it has finished typing

Proof in the PR: standard proof plus the M13 and M03 recordings (with the haptic recorder log).

Watch out: `typeOn` is a UIKit generator (SwiftUI can't do intensity per word): FR0.1 provides it through `RHaptic`; never create a generator in the view.

---

### C44 · Retro's recommendation card (ON-9 "how straight")                           size: S
Place in the tree: first run › getting to know you › ON-9 › recommendation
Repo · branch: NPRdoinglaundry · `ui/C44-recommendation-card`
Needs: T01, C09 (`RSettingsRow` choice rows, merged)        Unblocks: P02.2; settings ST-6 can reuse it

Why: when Retro has a view (how straight to be with you), it leads with its pick and why, and you can choose another.

Inputs: screen-rules 12 ("lead with Retro's recommendation"); design-reference §C34 variants (ON-9 = one raised card with the reason inside, alternatives as quiet rows under "or choose another"); Paper part 42 variants (if drawn; else a founder check of the snapshot).

Spec: `RRecommendationCard(title:reason:selected:)`: `background.raised`, `radius.card`, padding 18, the raised stack; title SF Pro 17 semibold `text.primary`, the reason "because you said you want to be challenged." (SF Pro 15 `text.secondary`); a 20 ink check trailing when chosen. Under it, "or choose another" (section label, `RSectionLabel`) and the alternatives as C09 choice rows.

State table: recommended (rest), chosen (check, `select`), another chosen (the card loses its check, the row gains it), dark.

Interaction: tap card or row → choose (`select`, `RMotion.snappy` check). Accessibility: "retro recommends: straight. because you said …, selected".

Steps: card → rows → gallery.

Acceptance: one raised card, alternatives quiet; matches the drawing or the founder's snapshot check.

Tests: (snapshot) recommended, another chosen; light, dark, ax3 · (UI) choosing a row moves the check

Proof in the PR: standard proof.

Watch out: the reason line is Retro's words from the flow (data), never composed in the view.

---

### M02 · The listening glow follows your voice                                      size: S
Place in the tree: first run › getting to know you › ON-3–9 › listening (signature moment M02)
Repo · branch: NPRdoinglaundry · `ui/M02-listening-glow`
Needs: #56 (`RVoiceComposer`)        Unblocks: P02.1

Why: you can see Retro is listening to you, and it follows your voice without jumping around.

Inputs: design-reference §C M02, §F 14 and 16 (C16 is undefined; lean: the composer's halo driven by level, founder question F11); build notes "Composer · listening look (c-mi7i0c)" (0.5pt `glow.primary.ring`, halo `glow.primary.halo` radius 24 spread −6 centred, level bars 6/10/14/9/5); motion-system §6 "Listening field" (rises on `gentle`, smoothed 120ms, capped 1.3×).

Spec: in `RVoiceComposer`'s listening state, the halo's radius scales with the input level: smoothed with a 120ms one-pole filter, capped at 1.3× the rest radius, rising in on `RMotion.gentle` when listening starts; `listenStart`/`listenStop`. No new component (C16 folded into #56).

State table: listening quiet, listening loud (capped), stopped; Reduce Motion: a fixed halo, no level follow.

Interaction: tap mic → listening (`listenStart`), tap again → stop (`listenStop`).

Accessibility: "listening" announced once; the level is not announced.

Steps: level input seam (from the composer's audio meter) → filter → cap → recordings.

Acceptance: the glow never exceeds 1.3× and never jumps between frames by more than the filter allows.

Tests: (unit) the filter's step response settles in 120ms ±10 · (unit) the cap holds at any level · (snapshot) quiet and loud

Proof in the PR: recording speaking softly and loudly.

Watch out: read the level on the audio thread and hand it to the main actor at display rate (a `TimelineView` or a 60Hz sampler), never per buffer.

---

### P02 · ON-3–9 the questions                            2 bytes: P02.1 L→M, P02.2 M
Place in the tree: first run › getting to know you › ON-3–9
Repo · branches: NPRdoinglaundry · `ui/P02.1-questions-page`, `ui/P02.2-questions-variants`
Needs: C34.1–C34.3, C35, C17-o, M02, #56, C08 (`RSegmented`, merged), C44, UI4.8        Unblocks: P03, P04, T03b

Why: Retro gets to know you in your own words, one question at a time, by voice or typing, and nothing you say is lost.

Inputs: Paper `1F6C-0` "ON-4a · listening" (the one approved phone) with its instances (progress `1F74-0`, top bar `1F6W-0`, question `1F6V-0`, your words `1F6R-0`, composer listening `1F6E-0`, mic-off `1F6F-0`); screen-rules 6–11; contract 01 §4 (answers via the outbox), §1 (`QuestionKey`); `docs/second-brain/brief-onboarding-questions.md` (the v2 set: founder question F3).

Spec:
- **P02.1 the page:** progress (C35) → top bar (C17-o) → the question (C34.1) → your words (C34.2) → quick answers when the flow gives them (C34.3) → the voice composer pinned at the bottom (`safeAreaInset`), voice on by default, mute trailing. Answering: speak (the transcript accumulates) and the composer's send (or a pause the composer detects, per #56) submits `answer(_:)`; the next question replaces this one. `skip` doesn't exist (no skip, lean F2); every question may be answered with nothing by sending empty → `given: skipped` only through the composer's "not now" if Paper draws one (lean: none; empty sends are refused with "say anything, even one word.").
- Order (lean, F3): ON-3 talk or type → the core questions (`name.place`, `year.from.now`, `care.most`, `on.your.mind`, `working.on`, `keep.meaning`, `high.low`, `people`) → ON-5 privacy (P03) → ON-6 connect (P04) → ON-7 fallbacks (`yesterday` if no calendar or health; `reading.watching` if no screen time or YouTube) → ON-8 the daily brief (on or off and when, lean below) → ON-9 how straight → ON-10.
- Resume: the flow starts at the first question with no answer (contract 01 §4 `GET`).
- **P02.2 the variants:** ON-3 "want to talk, or would you rather type?" with C08 segmented (talk · type), chosen once (screen-rules 9), setting the composer's mode for the rest; ON-8 "want a short brief each morning? when?" as quick answers ("7:00", "8:00", "9:00", "not now"; lean, not drawn: founder question F7) that write the brief switch (contract 02 §3 `PUT /v2/briefs/enabled`) and the time (contract 06, when its door exists; until then queued in the outbox as `brief.time`); ON-9 "how straight should i be with you?" with C44 (Retro's pick from what you said, alternatives below).

Interaction sheet:

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | arrive | the question types out | M13 | `typeOn` | whole words |
| 2 | start talking | listening glow; words blur in | M02, C34.2 | `listenStart` | no blur |
| 3 | understood word | ink-sharpens | M03 | `confirm` | instant |
| 4 | send | the answer saves (outbox), the progress advances, the next question types out | exit 180 / enter 240, progress `map` | `turn` | 140 fade |
| 5 | tap a quick answer | pill selected, words into the composer | 200 | `select` | fade |
| 6 | type instead | the composer's typing state, send lit | #56 | — | — |
| 7 | back | the previous question with your answer shown | `RMotion.sheet` reverse | none | fade |
| 8 | offline | "you're offline · we'll pick up here"; answers queue and the next question still comes (the questions are on the phone) | `.rBlurReplace` | — | fade |
| 9 | no microphone permission | the composer starts in typing mode with "type your answer" and a quiet "turn on the microphone" link to Settings | — | — | — |

States (`-Screen ON-3–9`): `asking`, `listening`, `answered`, `quickAnswers`, `muted`, `typing`, `didntCatch`, `noMic`, `offline`, `talkOrType`, `briefTime`, `howStraight`, `fallbackYesterday`, `long`.

The one lit object: the composer's send while there's text; otherwise none (the listening glow is blue's listening job).

Accessibility: the question heading first; the composer's actions; your words as a live region; audit passes in `asking`, `typing`, `howStraight`; AX3: the question wraps, pills stack, the composer stays in reach; SE: same layout, the question wraps.

Steps: P02.1 page and sequencing → resume → offline and no-mic → P02.2 variants → launcher → UI tests.

Acceptance: matches `1F6C-0` (light, dark, AX3, SE); every answer is saved exactly once (sample outbox count); no "skip" anywhere.

Tests: (snapshot) each state × light, dark, ax3; SE asking · (UI) answering advances and the progress moves · (UI) back shows the previous answer · (UI) offline still advances and says so · (UI) choosing "type" in ON-3 keeps typing mode for the rest · (accessibility) audit in three states

Proof in the PR: page proof plus recordings of rows 1–4.

Watch out: question copy lives in the app's strings table keyed by `QuestionKey` (contract 01 §1), so the founder can change wording without a server change; never send question text to the server.

---

### UI4.5 · The privacy disc                                                         size: S
Place in the tree: first run › getting to know you › ON-5 › privacy disc
Repo · branch: NPRdoinglaundry · `ui/UI4.5-privacy-disc`
Needs: T01        Unblocks: P03

Why: the promise about your data is the one thing lit on that page.

Inputs: Paper part 44 `GJJ-0`, `c:privacy-mark` `1F82-0` with `c:icon/lock` `1F85-0`; design-reference §Extra "Privacy disc" (C "held in blue": a lit lock disc inside a sky glow, pale glassy inner disc with a sky hairline, soft blue halo); motion-moments (fades in, the shackle closes with a tiny click motion, the halo breathes once; `spring.popover`, `confirm`).

Spec: `RPrivacyDisc`: the sky bloom, the glassy inner disc with a sky hairline, the lit lock disc (glow recipe) with the lock glyph; appear: fade in on `curve.standard` 280, the shackle drops 2pt and closes on `RMotion.popover` with `RHaptic.confirm`, the halo breathes once (0.35 → 0.5 → 0.35 over 1.2 s on `curve.move`), then still.

State table: appearing, rest, dark (glow dark set), Reduce Motion (present, no shackle move, haptic stays).

Interaction: none (not a button; "a lit disc that is not an action" is a known conflict, design-reference §F, accepted by the founder's pick).

Accessibility: `accessibilityHidden(true)` (the title says it).

Steps: disc → shackle path → appear → gallery.

Acceptance: matches `1F82-0` in light and dark.

Tests: (snapshot) rest light and dark · (unit DEBUG recorder) `confirm` fires once on appear

Proof in the PR: standard proof + the appear recording.

Watch out: the shackle must be a separate path from the body to animate; ask the integrator for the split glyph if the shipped `lock` is one path.

---

### P03 · ON-5 privacy                                                                size: S
Place in the tree: first run › getting to know you › ON-5
Repo · branch: NPRdoinglaundry · `ui/P03-privacy`
Needs: UI4.5, C35, C17-o, #56 (speaking state)        Unblocks: P04, T03b

Why: before Retro reads anything, it tells you plainly what it does with your data, out loud.

Inputs: Paper `1F7I-0` "ON-5 · privacy" with progress `1F8D-0`, back `1F89-0`, privacy mark `1F82-0`, composer speaking `1F7K-0`; screen-rules 2–3.

Spec: progress → top bar → the disc centred above the title → one inky title → one plain paragraph → the policy link (`text.link`); the composer in its speaking state while Retro reads it aloud (the speech proxy, through the playback protocol; the audio is the founder's written copy, synthesised); a "continue" appears when the reading ends or on tap ("continue" is C01 primary only if Paper draws it; else the composer's send acts as continue: check `1F7I-0`).

Interaction: arrive (disc appear + reading starts); tap the composer to stop reading (`listenStop`); continue → ON-6. Reduce Motion: fades.

States (`-Screen ON-5`): `privacy`, `reading`, `offline` (no audio; the words are on the page).

Accessibility: the title heading first; the reading doesn't fight VoiceOver (when VoiceOver is on, Retro doesn't read aloud); audit passes.

Steps: layout → reading seam → states → tests.

Acceptance: matches `1F7I-0`; the paragraph is the founder's copy from the strings table.

Tests: (snapshot) three states × light, dark, ax3 · (UI) continue reaches ON-6 · (UI) with VoiceOver running the page doesn't auto-play

Proof in the PR: page proof.

Watch out: audio for this page is the same every time: cache it in the app bundle or once on first play, never synthesise per user.

---

### C36 · The knows-you meter                                                       size: M
Place in the tree: first run › getting to know you › ON-6 › meter
Repo · branch: NPRdoinglaundry · `ui/C36-knows-you-meter`
Needs: S08 (`RKnowsYouTrack`, merged), T01        Unblocks: P04, M04

Why: you watch how well Retro can know you grow as you connect things and answer.

Inputs: Paper `c:knows-you-meter/1-of-6` `21C1-0` (ON-6); motion-system §6 "Knows-you meter"; design-reference §C36; contract 01 §5 (`Level`).

Spec: `RKnowsYouMeter(level: Level)`: a 4pt track (`size.meter`) filling with `ink.default` in three steps; the label "retro knows you a little / better / well" (layout and type from `21C1-0`). A step fills on `curve.move` over 420ms; the label rolls (`.rBlurReplace`); reaching `well`: the fill glows once (a 1.0 → 0 opacity ink bloom over 600ms) and the label pops on `RMotion.pop` with `RHaptic.confirm`. `unknown` shows the last known level.

State table: little, better, well (+ pop), loading (track only), offline (last known, no change), dark.

Interaction: none (driven by data).

Accessibility: one element "retro knows you a little"; changes announce in words ("calendar connected. retro knows you a little better."); Reduce Motion: 140 cross-fades, no pop.

Steps: track → label roll → well pop → gallery.

Acceptance: matches `21C1-0`; never fills blue.

Tests: (snapshot) three levels, light, dark, ax3 · (unit DEBUG recorder) `confirm` only on reaching well, once · (UI) the announcement names the source and the level

Proof in the PR: standard proof + the step and pop recordings.

Watch out: the meter only moves on a server answer (contract 01 §5), never optimistically.

---

### P04 · ON-6 connect                                                               size: M
Place in the tree: first run › getting to know you › ON-6
Repo · branch: NPRdoinglaundry · `ui/P04-connect`
Needs: C36, C10 (`RSourceRow`, #52), C35, C17-o, C01, UI4.8        Unblocks: M04, T03b

Why: you connect what you want Retro to read, and see straight away what it changes.

Inputs: Paper `2190-0` "ON-6 · connect" with meter `21C1-0`, section label `21BY-0`, source rows `21BN-0` (connected) and `21B8-0` (rest), connect pill `21B9-0`, "see all apps" `2199-0`, lit continue `2194-0`, text later `2192-0`; handoff ON-6 row (two groups, SF Symbols from layer names `sf:<name>`, lit continue once one is connected, text later always); screen-rules 13, 15, 16; contract 01 §5.

Spec: title "i'd love to get to know you." (display inky 30) → the meter (C36) → "on this iPhone" (calendar, health) and "your other apps" (google; notion only if D9; github hidden) as C10 rows with their real logos as app-icon tiles and a purpose line → "see all apps" (C09 nav row, opening the full list in place, one page: screen-rules 13) → bottom: lit "continue" once one source is connected (else not shown; "later" leads) and text "later". Connecting: on-device → the iOS permission prompt, then `connect(_:)`; account → `ASWebAuthenticationSession` (Platform), back through the router.

Interaction sheet:

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | tap "connect" | the pill presses, blur-replaces to a spinner | `.rPress` 0.94, `.rBlurReplace` | none (not lit) | fade |
| 2 | connected | "● connected" with the dot scaling 0 → 1 on `pop`; the meter steps (M04) | `RMotion.pop`, `snappy` width | `confirm` as the dot lands | fade, haptic stays |
| 3 | failed | the pill shakes (3 × 6pt on `snappy`), "try again" | `.rShake` | `warning` | no shake |
| 4 | permission denied (on-device) | the row's subline: "turned off in settings" + a "settings" pill | `.rBlurReplace` | — | fade |
| 5 | first connection | "continue" appears lit and breathes once | 280 + pulse | — | fade |
| 6 | later / continue | ON-7 (fallbacks) or ON-8 | page push | `press` on continue | fade |

States (`-Screen ON-6`): `connectNone`, `connecting`, `connectedOne`, `connectFailed`, `permissionDenied`, `knowsWell`, `seeAll`, `offline` (connect pills disabled, "connect when you're back online").

Accessibility: title heading; each row "calendar, so i know what your days hold, connect button"; state changes announced with the meter; audit passes in `connectNone`, `connectedOne`.

Steps: layout → connect flows (sample) → states → launcher → tests.

Acceptance: matches `2190-0` light, dark, AX3 and SE; lit "continue" only after a connection; "later" always there.

Tests: (snapshot) each state × light, dark, ax3; SE · (UI) connecting calendar shows connected and steps the meter · (UI) a failure shakes and offers try again · (accessibility) audit

Proof in the PR: page proof + rows 1–3 recordings.

Watch out: the source list comes from the server (hidden sources never show); logos are brand assets, not tokens.

---

### M04 · Connect → connected, the meter fills, "knows you well"                    size: M
Place in the tree: first run › getting to know you › ON-6 › signature moment M04
Repo · branch: NPRdoinglaundry · `ui/M04-connect-moment`
Needs: P04, C36        Unblocks: T03b

Why: the one that matters most for the business (the founder): connecting something should visibly make Retro know you better, and reaching "well" should feel like a small win.

Inputs: design-reference §C M04 (pill 0.94 → spinner → "● connected"; meter fills one step and its label rolls; reaching well: gauge glows once, label rolls, one `confirm`); motion-system §6 "+ connect", "Knows-you meter".

Spec: choreograph P04 row 1–2 with C36: the dot lands (`pop`, `confirm`), then 120ms later the meter steps (`curve.move` 420), the label rolls; at `well` the glow + pop replace the step's own haptic (one `confirm` total for that tap: the dot's haptic is suppressed when the meter reaches well on the same tap, so they never double).

State table: step to better, step to well, failure.

Interaction: interruptible: a second connect during the meter's fill retargets it.

Accessibility: one announcement per tap ("calendar connected. retro knows you well.").

Steps: chain with overlap (70%) → haptic de-dup → recordings.

Acceptance: one haptic per tap; the chain overlaps; the founder signs it off.

Tests: (unit DEBUG recorder) a tap reaching well fires exactly one `confirm` · (motion) 0 hitches · (snapshot) end states

Proof in the PR: 120fps and Slow Animations recordings; founder sign-off.

Watch out: never fake progress: if the meter's level doesn't change on the server, the meter doesn't move.

---

# §D · The first episode (phase 2)

### UI4.1 · The getting-ready card                                                    size: M
Place in the tree: first run › the first episode › ON-10 › getting-ready card
Repo · branch: NPRdoinglaundry · `ui/UI4.1-getting-ready-card`
Needs: C26.2 (the brief card's making state, journal plan), C06 (`RTag`, #46)        Unblocks: P05, M05

Why: while your first episode is made you see honest steps, and what you say right now visibly goes in.

Inputs: Paper `c:getting-ready` `26LV-0`, `c:brief-card/artwork/making` `26ML-0`, `c:stage/next` `26LZ-0`, `c:spinner/20` `26M3-0`; design-reference §Extra "Getting-ready panel" (newest c-koui68: the brief card in its being-made state, full-colour brief mesh with a glow ring, "weaving in what you just said · ~2 min", a 2pt progress hairline along the card's bottom edge, a small raised tag "+ the investor call on thursday" tilted −2° tucked into its top edge; "each new answer pops in as a tag and slides into the card"); §F 17 (the hairline is drawn blue; rule says ink: founder question F8, lean ink).

Spec: `RGettingReadyCard(step:FirstRunStep, estimate:Int?, tags:[String])` built on C26's card: the first-episode mesh (`RArtwork(.first)`), "your first episode" (Geist 500 14), the subline from the step ("reading what you've shared" / "writing it now" / "recording it now"; plus " · about 2 min" when `estimateSeconds` is known, never a number when it isn't), the 2pt hairline (`ink.default`, lean) moving in three honest steps (1/3, 2/3, 3/3) on `curve.move`; tags: each new answer's short form (the flow gives it; a phrase from your answer, never invented) pops in above the card on `RMotion.pop`, tilted −2°, then slides into the card's top edge on `RMotion.sheet` and stays tucked (at most 2 visible; older ones slide under).

State table: reading, writing, voicing (each step: hairline + subline blur-replace 280), ready (becomes ON-13's "your first episode is ready" card, C26 becoming-ready), quiet (the quiet line, no hairline), failed ("couldn't make it just now" + "try again" neutral pill), dark.

Interaction: "try again" (0.94, retries the job). Accessibility: "your first episode, writing it now, step 2 of 3"; tags are not announced individually; Reduce Motion: fades, no pop or slide.

Steps: card variant → steps → tags → states → gallery.

Acceptance: matches `26LV-0` (except the hairline colour, per F8); steps only move on server steps.

Tests: (snapshot) every state × light, dark, ax3; SE (only the subline and hairline) · (unit) the subline never shows a time without an estimate

Proof in the PR: standard proof + the tag pop-and-slide recording.

Watch out: one `RArtwork` instance; the card is the same object that blooms into ON-13's ready card (matched geometry across the transition).

---

### P05 · ON-10 getting ready (and asking for push)                                  size: M
Place in the tree: first run › the first episode › ON-10
Repo · branch: NPRdoinglaundry · `ui/P05-getting-ready`
Needs: UI4.1, C34, C35, C17-o, #56, UI4.8, PL5.1 (permission seam)        Unblocks: P06, M05, T03b

Why: keep talking while your first episode is made; it all goes in, and Retro can tell you when it's ready.

Inputs: Paper `26LG-0` "ON-10 · getting ready" (progress ~92% `26NA-0`, question `26N1-0`, your words `26MX-0`, getting-ready `26LV-0`, composer listening `26LI-0`); contract 01 §6 (jobs), §7 (devices), §13 Q5 (push timing, lean: here).

Spec: progress (~92%) → top bar → one more warm question ("while i get your first episode ready: what's one thing you want this week to go well?", key `this.week`) → your words → the getting-ready card (UI4.1) → "keep talking; it all goes in." (`text.secondary`) → the composer listening. The job starts on arrival (`POST /v2/episodes/jobs`, idempotent). **The push ask (lean):** after the warm question is answered (or 20 s), a quiet row appears under the card: "want a note when it's ready? i'll write it for you, not a ping." (lean copy; it must promise the founder's rule that every notification is written for the person and the moment, 21 Oct; wording is the founder's) with a raised pill "tell me" (C05 raised); tapping it shows Apple's permission prompt (PL5.1); granted → the row becomes "i'll write to you when it's ready." and fades; the note itself is written by the outside plan's writer (contract 07), never a fixed string; denied or ignored → the row fades; never asked twice. On `ready` → ON-11 (or ON-13 when `quiet`, Q3).

Interaction sheet: arrive (M13 type-out; the card appears on `settle`); answer (tag pops into the card, M05); step changes (M05); "tell me" (0.94, system prompt); ready (the card's becoming-ready bloom, `reveal`, then the push to ON-11 on `RMotion.gentle`); failed ("try again"). Reduce Motion: fades.

States (`-Screen ON-10`): `ready.reading`, `ready.writing`, `ready.voicing`, `ready.done`, `ready.quiet`, `ready.failed`, `pushAsk`, `pushGranted`, `offline` (the card holds its last step, "waiting for a connection"; answers queue).

Accessibility: question heading first; step changes announced ("writing it now"); the push row is a normal button; audit passes in `ready.writing`, `pushAsk`.

Steps: layout → job seam → push row → states → tests.

Acceptance: matches `26LG-0`; the push prompt appears only after "tell me"; leaving and returning resumes the same job (never a second).

Tests: (snapshot) each state × light, dark, ax3; SE · (UI) the steps advance to ON-11 (sample) · (UI) "tell me" asks once and never again · (UI) a quiet first episode goes to ON-13 · (accessibility) audit

Proof in the PR: page proof + recordings of a full wait.

Watch out: never call Apple's permission prompt on arrival; the job's polling belongs to Platform (PL3.3c), the view reads `job` only.

---

### M05 · Getting ready, honest steps                                                size: S
Place in the tree: first run › the first episode › ON-10 › signature moment M05
Repo · branch: NPRdoinglaundry · `ui/M05-getting-ready-steps`
Needs: P05, UI4.1        Unblocks: T03b

Why: the wait feels alive and truthful: steps move only when something real happened, and what you say visibly goes into the episode.

Inputs: design-reference §C M05 (honest steps, no fake percentage; stage label blur-replaces, `duration.slow`; tags pop in and slide into the card).

Spec: tune and record UI4.1's motion in place on P05: the hairline step (`curve.move` 420), the subline (`.rBlurReplace` 280), the tag pop (`RMotion.pop`) then slide (`RMotion.sheet`), overlapping at 70%; no haptics (M05 has none).

State table/interaction: as UI4.1 on the page.

Accessibility: as UI4.1.

Steps: recordings → adjust → founder sign-off.

Acceptance: no motion without a data change; founder signs off.

Tests: (motion) 0 hitches over 5 runs; (unit) a repeated step value doesn't animate

Proof in the PR: 120fps recording of a full wait on sample timing.

Watch out: this byte changes timing only; any shape change goes back to UI4.1.

---

### P06 · ON-11 the tease                                                              size: M
Place in the tree: first run › the first episode › ON-11
Repo · branch: NPRdoinglaundry · `ui/P06-tease`
Needs: C23e (the player in episode mode, podcasts plan), S10 (22), UI4.8, PL3.3c (episode)        Unblocks: M06.1, P07, T03b

Why: you hear the start of your first episode, made from what you just said, and it stops on the line that makes you want the rest.

Inputs: Paper `26NO-0` "ON-11 · the tease" with `c:player-sheet/brief/playing` `26NZ-0`, mark `26PQ-0`, correct pill `26OV-0`, scrubber `26OM-0`, transport `26O3-0`; handoff ON-11 (auto-playing, "the week you started", ~2 min; line 2 "here's the first thing i noticed. it's narrow, because it's day one." is where the paywall rises); contract 01 §6 (`GET /v2/episodes/:id`).

Spec: the player sheet (C23e) over the canvas, auto-playing the first episode from the start; the tease ends at the end of the second transcript line (or `teaseSeconds` from the flow if transcript timing is missing: lean 40 s); then M06 hands over to ON-12. A subscriber (restored, or already active) never sees the paywall: the episode plays on and "done" goes to ON-13.

Interaction: as C23e (pause, scrub within the tease only, skip disabled past the tease end); correct this part (as C23e); the sheet can't be dismissed during the tease (the paywall is next). Reduce Motion: C23e's.

States (`-Screen ON-11`): `tease`, `teaseEnding` (the line before the paywall), `subscribed`, `audioFailed` (C23e's failed state with "try again"; the transcript still readable), `offline` (cached audio plays; else "it'll play when you're back online").

Accessibility: C23e's; the paywall's arrival is announced.

Steps: C23e host → tease end → subscribed path → states → tests.

Acceptance: matches `26NO-0`; the tease ends exactly where the flow says.

Tests: (snapshot) states × light, dark · (UI) the tease ends and the paywall rises · (UI) a subscriber hears past the tease

Proof in the PR: page proof + the tease-end recording.

Watch out: P06 can't start before the podcasts area's C23e merges; if first run must ship first, C23e moves into this plan (README risk R4).

---

### M06 · The player shrinks into the mini-player; the paywall rises   2 bytes: M06.1 M, M06.2 S
Place in the tree: first run › the first episode → membership › ON-11 → ON-12 › signature moment M06
Repo · branches: NPRdoinglaundry · `ui/M06.1-player-shrinks`, `ui/M06.2-paywall-rises`
Needs: P06, P07, C22-p        Unblocks: T03b

Why: the episode you're hearing doesn't disappear when the paywall comes: it shrinks into a paused pill at the top, waiting, while the offer rises under it.

Inputs: design-reference §C M06 (shared element `matchedGeometryEffect`; paywall rises on `sheet`; `sheetSnap`; paywall.md "1.22 s reveal"), §F 40 (belongs to first run); Paper `26NZ-0` → `22TR-0`.

Spec:
- **M06.1:** at the tease end, playback pauses; the player's artwork, title and play morph into the 64pt paused mini-player (C22-p) at the top (`matchedGeometryEffect` on artwork, title and play; `RMotion.sheet`); the transcript's strongest line holds for 400ms, then fades.
- **M06.2:** the paywall content rises from where that line was, on `RMotion.sheet`, staggered (title → benefit rows → plans, 60ms), `RHaptic.sheetSnap` as it settles; the whole hand-over runs within 1.22 s (`motion.curve.reveal` envelope).

State table: transitioning, settled; Reduce Motion: the player cross-fades out and the paywall in (140), the mini-player appears in place.

Interaction: tap the mini-player mid-transition → interrupt: it returns to the player at its current position and the paywall reverses (never a jump).

Accessibility: "the episode is paused. become a member to hear the rest." announced once when settled.

Steps: shared element → rise → interrupt → recordings.

Acceptance: no element is recreated mid-flight (one artwork instance); founder sign-off.

Tests: (motion) 0 hitches · (UI) tapping the mini-player mid-transition returns to the player · (snapshot) settled

Proof in the PR: 120fps + Slow Animations, the interrupted run.

Watch out: the matched geometry crosses two screens owned by one host: P07 is presented inside ON-11's host, not as a separate navigation push.

---

# §E · Membership (phase 2)

### C22-p · The paused mini-player (paywall variant)                                size: S
Place in the tree: first run › membership › ON-12 › paused player
Repo · branch: NPRdoinglaundry · `ui/C22p-mini-player-paused`
Needs: C22 (journal plan)        Unblocks: P07, M06.1

Why: the tease you just heard waits at the top, paused, and you can play it again.

Inputs: Paper `c:mini-player/paused` `22TR-0` with `c:icon-button/wash/play` `22TT-0`; design-reference §F 11 (`size.miniPlayer` is 42 in tokens but the pill is 64: FR0.1 fixes the token).

Spec: C22's 64pt pill in its paused state: the first-episode artwork thumb, "the week you started" (Geist 500 14), "paused · 0:40 of 2:04" (mono 12 for the figures), the wash play well; no progress line motion (paused).

State table: paused, pressed (0.98), playing (the tease replays from the start up to the tease end; the paywall stays), dark.

Interaction: play → replays the tease (`playMorph` 180), never past the tease end.

Accessibility: "the week you started, paused. play".

Steps: variant → gallery.

Acceptance: matches `22TR-0`.

Tests: (snapshot) paused, playing; light, dark, ax3

Proof in the PR: standard proof.

Watch out: the 42 token is stale; don't use it.

---

### C33 · Benefit rows with tiles                                                     size: S
Place in the tree: first run › membership › ON-12 › benefits
Repo · branch: NPRdoinglaundry · `ui/C33-benefit-rows`
Needs: T01        Unblocks: P07

Why: what membership gives, row by row, each a promise the product keeps today.

Inputs: Paper `c:benefit-row` `22S1-0` (decision 06 option A `IFL-0`); design-reference §C33 (six rows in order: "wake up to what moved", "see your life, connected", "ask your life anything · answers from your days, with sources", "know if you're on track", "a podcast about your week", "a journal that talks back"; plain design-system glyph tiles, three slightly off-axis; row padding spacing-1, spacing-1 gap); motion-system §6 "Off-axis cards".

Spec: `RBenefitRow(glyph:title:subline:tilt:)`: a 56 raised tile with the glyph, the title (SF Pro 16 medium) and one subline (`text.secondary`, one line, also on SE). Three tiles tilted (angles from Paper) settle from 0° to their tilt on `RMotion.settle`, staggered 60ms on appear, then still.

State table: rest, appearing, dark; Reduce Motion: tilted from the start, no settle; AX3: tiles hide, text stays.

Interaction: none. Accessibility: each row one element "wake up to what moved, <subline>"; tiles hidden.

Steps: row → tilt settle → gallery.

Acceptance: matches `22S1-0`; never shows a benefit the backend can't deliver (the founder confirms the six before ship: "a journal that talks back" is v2's conversation: founder question F10, lean drop it until v2).

Tests: (snapshot) six rows, light, dark, ax3 · (unit) at most three rows tilt

Proof in the PR: standard proof + the settle recording.

Watch out: the founder's rule "never show a benefit the backend can't deliver" applies to row 6 today (the journal's v1 is canned acknowledgements).

---

### C37 · The plan pair                                  2 bytes: C37.1 M, C37.2 S
Place in the tree: first run › membership › ON-12 › plans
Repo · branches: NPRdoinglaundry · `ui/C37.1-plan-pair`, `ui/C37.2-plan-states`
Needs: C01–C03 (`RButton`, merged), C06 (`RTag`, #46), UI4.8        Unblocks: P07, M07

Why: choose yearly or monthly in one tap, with Apple's real price in your currency and the yearly plan's first month free.

Inputs: Paper decision 06 option A `IFL-0`; `c:button/lit/plan-yearly` `22MH-0`, `c:button/secondary/plan-monthly` `22MM-0`, `c:badge/save` `22MI-0`; design-reference §C37 (52pt one-line buttons 12 apart; the save tag on the yearly's top edge; one quiet line above; links restore · privacy · terms · not now); context.md D6 (**$19.99 a month; $199.99 a year, the first month free**: newer than the reference's $24.99/$239.99 and its "no trial", which are stale); contract 01 §8.

Spec:
- **Paper differs from the founder's prices.** `22M4-0` still reads "$24.99", "$239.99" and "yearly works out to $20.00 a month" (`22MO-0`, `22ML-0`, `22MP-0`), and draws no line for the yearly plan's free first month. D6 (21 Oct, later the same day) is newer: $19.99 a month, $199.99 a year with the first month free. Prices are never typed anyway (they come from the store); the layout is Paper's, and the trial line is new copy the founder approves (README question F10). Ask the integrator to update the three texts in Paper.
- **C37.1:** `RPlanPair(monthly: Plan, yearly: Plan)` where `Plan` carries the store's `displayPrice`, period and the yearly intro offer (`introductoryOffer` free 1 month) from Platform (PL6.1), never a literal. Monthly on raised paper (secondary), yearly lit (the one lit object) "$199.99 / year" with the unit lighter; the "save 17%" tag (computed from the two store prices, rounded down; lean F10 copy) on the yearly's top edge (raised capsule, `glow.primary.ring` hairline, `accent.text`); the line above: "first month free, then $199.99 a year · works out to $16.66 a month" (all figures from the store; lean copy, founder F10). Links under: restore · privacy · terms (`text.link` 44 targets) and "not now" (`text.link`), restore and not now visible without scrolling.
- **C37.2:** states: prices loading (60-wide skeleton bars, not pressable), purchase pending (the tapped plan's label becomes pending dots; the other plan and links disabled), failed (one line under the pair: "the purchase didn't go through. nothing was charged." `error`), cancelled (back to rest, no message), offline (both disabled, "connect to subscribe"; not now works), subscribed (the pair is replaced by "you're a member." and continue).

State table:

| State | Look | Motion | Haptic |
|---|---|---|---|
| rest | as above | the save tag on `RMotion.pop` on appear | — |
| pressed | 0.98, lit pressed gradient | `.rPress` | `press` (yearly, lit) |
| pending | dots over the kept label | 900ms pulse | — |
| failed | the line | blur-in | `error` |
| loading | skeleton | shimmer | — |
| offline | disabled + line | — | — |
| dark | tokens; the tag keeps 4 : 1 | — | — |

Interaction: tap a plan → `purchase(plan)` (Platform shows Apple's sheet); restore → `restore()`; not now → ON-13.

Accessibility: "yearly, first month free, then $199.99 a year, works out to $16.66 a month, button"; AX3: plans stack, yearly first.

Steps: C37.1 pair and line → C37.2 states → gallery.

Acceptance: no price literal anywhere in the view (a source scan); matches `IFL-0` with the D6 prices.

Tests: (snapshot) every state × light, dark, ax3 · (unit) the save percentage from two prices rounds down · (unit) no currency literal in `Features/FirstRun` outside `Sample/` · (UI) not now reaches ON-13

Proof in the PR: standard proof next to `IFL-0`, with the price difference noted.

Watch out: Apple requires the price, period and the trial's terms to be clear on the paywall (App Review 3.1.2): the line above the pair carries them; don't hide it on SE.

---

### P07 · ON-12 the paywall                                                            size: M
Place in the tree: first run › membership › ON-12
Repo · branch: NPRdoinglaundry · `ui/P07-paywall`
Needs: C22-p, C33, C37.1, C37.2, UI4.8        Unblocks: M06.2, M07, T03b

Why: become a member to hear the rest of your episode, and one every week, with a clear way to say not now.

Inputs: Paper `22M4-0` "ON-12 · A · the plans are the buttons"; design-reference §E P07; contract 01 §8; App Review 3.1.2 (subscriptions).

Spec: the paused mini-player at the top → the one-line pitch ("hear the rest, and one every week.", display inky) → the six (or five, F10) benefit rows → the plan pair pinned at the bottom with content fading under it (160pt fade to canvas, progressive per `progressive-blur.md`) → links. Purchase success → `confirm`, the sheet settles away, ON-13 with the episode ready to finish. Not now → ON-13 (the free period's rules apply, F4).

Interaction sheet: arrive (M06.2); plan tap (C37 states); restore (pending, then subscribed or "nothing to restore"); not now (`curve.exit`, ON-13); mini-player play (replays the tease). Reduce Motion: fades.

States (`-Screen ON-12`): `paywall`, `pricesLoading`, `purchasePending`, `purchaseFailed`, `purchaseCancelled`, `paywallOffline`, `subscribed`, `restoreNothing`.

Accessibility: reading order pitch → benefits → plans → links; audit passes in `paywall` and `paywallOffline`.

Steps: layout → states → launcher → tests.

Acceptance: matches `22M4-0` (light, dark, AX3, SE: plans stack on very small phones); no second paywall after "not now".

Tests: (snapshot) states × light, dark, ax3; SE · (UI) subscribing reaches ON-13 · (UI) not now reaches ON-13 · (UI) restore with nothing says so · (accessibility) audit

Proof in the PR: page proof next to `22M4-0`.

Watch out: never show a typed price; the yearly is the only lit object.

---

### M07 · The plan glow, reinterpreted                                                 size: S
Place in the tree: first run › membership › ON-12 › signature moment M07
Repo · branch: NPRdoinglaundry · `ui/M07-plan-glow`
Needs: P07        Unblocks: T03b

Why: picking a plan should feel like a confident choice, with one bright thing moving.

Inputs: design-reference §C M07, §F 3 (option A has no "choose then confirm", so "the glow slides to the chosen plan" needs reinterpreting); later.md lean ("the lit glow moves to the chosen plan; '17% off' rolls in").

Spec (lean, founder question F10b): on appear, the save tag pops in (`RMotion.pop`) and the yearly's glow breathes once; when the monthly plan is pressed, the glow slides from yearly to monthly during the press (`matchedGeometryEffect` on the glow layer, `RMotion.popover`, `select`), and slides back if the purchase is cancelled. The lit object is always the one being bought.

State table: rest, monthly pressed (glow moved), cancelled (glow returns).

Accessibility: none extra; Reduce Motion: no slide, the glow cross-fades 140.

Steps: glow layer extraction → slide → cancel return → recordings.

Acceptance: the founder picks this or "no M07" from the recording.

Tests: (snapshot) glow on monthly · (motion) 0 hitches

Proof in the PR: recordings; founder sign-off.

Watch out: never two lit objects at once, even mid-slide (the glow is one layer).

---

# §F · First home (phase 2)

### UI4.2 · The setup-recap card                                                     size: S
Place in the tree: first run › first home › ON-13 › setup recap
Repo · branch: NPRdoinglaundry · `ui/UI4.2-setup-recap`
Needs: T01, C31's entry text styles (journal plan)        Unblocks: P08

Why: what you told Retro while setting up waits on your first home, in your own words.

Inputs: Paper `c:entry/setup-recap` `1FJ6-0`; design-reference §Extra "Setup-recap card" (a raised paper card: label "what you told retro while setting up" + "9 answers", three answers in the inky card face, "see all 9" `text.link` medium; SE two lines); contract 01 §4 (`GET /v2/onboarding/answers`).

Spec: `RSetupRecap(answers: [Answer], count: Int)`: raised card; the label row; up to three answers (the flow picks: `name.place`, `year.from.now`, `this.week` when present, else the first three) in the inky card face, one line each with a tail ellipsis; "see all 9" opens the full list (JR-4-style list sheet, lean: the you area's YO-5 later; for now a sheet listing all answers).

State table: rest, pressed (card 0.98 → opens the list), two answers, one answer, SE (two lines), dark.

Accessibility: "what you told retro while setting up, 9 answers: …, see all".

Steps: card → list sheet → gallery.

Acceptance: matches `1FJ6-0`; answers are the person's words, never summarised.

Tests: (snapshot) 3, 2, 1 answers; light, dark, ax3; SE · (UI) see all opens the list

Proof in the PR: standard proof.

Watch out: show only what the server returned; never fill with sample copy outside the sample.

---

### P08 · ON-13 first home                                                             size: M
Place in the tree: first run › first home › ON-13
Repo · branch: NPRdoinglaundry · `ui/P08-first-home`
Needs: P09 (the journal page), C26 (first-episode card), UI4.2, UI4.8        Unblocks: T03b, the first-run wiring (FR0.4)

Why: your journal on day one, with your first episode ready to play and what you told Retro waiting.

Inputs: Paper `1FI8-0` "ON-13 · first home" (top bar `1FJV-0`, brief card making `1FJL-0`, setup recap `1FJ6-0`, Retro's line `1FJ3-0`, hint `1FJ0-0` hidden, composer `1FIS-0`, tab bar `1FIA-0`); handoff ON-13; motion-system §7 (the one-time pop when the first episode is ready); design-reference §Extra "Hint pill" (hidden: no PR, founder question F13).

Spec: P09 in its `dayOne` form with: the brief card as "your first episode is ready · the week you started · 2 min" (C26 with the first mesh, the lit play: the one lit object); "welcome, sam." (display inky) and "this is your journal. say anything, any time; i'll keep it and find the threads." as Retro's first lines (data from the flow, not invented in the view); the setup recap; the composer (mic off until tapped); the tab bar. On first arrival: `complete()` (contract 01 §3: approved → member), and the card does its one-time `pop` with `RHaptic.reveal`. If the episode wasn't ready (quiet, or not now while still making): the card in its making or quiet state.

Interaction: as P09, plus: arrive (the card's pop, once per account); play (the player opens on the full episode); recap (UI4.2).

States (`-Screen ON-13`): `firstHome`, `firstHome.making`, `firstHome.quiet`, `firstHome.offline`.

Accessibility: P09's; "your first episode is ready" announced once.

Steps: P09 day-one host → first-episode card → recap → `complete()` seam → tests.

Acceptance: matches `1FI8-0`; the pop plays once ever per account on this phone.

Tests: (snapshot) four states × light, dark, ax3; SE · (UI) arriving marks onboarding complete once (sample counter) · (UI) play opens the player

Proof in the PR: page proof next to `1FI8-0`.

Watch out: ON-13 is the journal, not a copy of it: reuse P09 with a day-one scenario; nothing here forks the journal page.

---

# §G · The flow test (phase 2)

### T03b · The first-run flow test                                                     size: M
Place in the tree: first run › flow tests › the whole first run
Repo · branch: NPRdoinglaundry · `ui/T03b-first-run-flow` (with the integrator for the staging half)
Needs: T03a, P01–P08, P32, PX, M01–M07, FR0.4        Unblocks: ship gate G1

Why: one test proves a new person gets from an invite link to their first home with an episode ready, and that the failure paths never strand them.

Inputs: testing.md §3 T03; README (flows) §2; every page's state list.

Spec:
- **On sample data** (`RetrospectUITests/V2/FirstRunFlowTests.swift`): (1) link → T1 → sign in → print → tear → you're in → begin → ON-3 → answer every question (typed, for determinism) → ON-5 → ON-6 connect calendar → ON-8 brief at 8:00 → ON-9 → ON-10 (job walks to ready) → ON-11 tease ends → ON-12 subscribe (sample) → ON-13 shows the ready card and the recap with the right count; (2) the same to ON-12 → not now → ON-13; (3) a quiet first episode skips ON-11; (4) relaunch at ON-6 resumes at ON-6 with answers kept; (5) the splash → sign in with no code → T-alt → waitlist → joined; (6) a returning person (flag set) sees AC-1 → home; (7) `updateRequired` shows PX over everything.
- **On local staging** (integrator): (1) with a fresh seeded account and a founder link, including a sandbox purchase (StoreKit configuration file in the test scheme) and a real first-episode job on a test account (test spend logged separately in `cost-per-user.md`).

Acceptance: all sample runs pass in CI (nightly and on first-run page PRs); the staging run passes before G1.

Tests: the seven above, named as sentences.

Proof in the PR: test output; the staging run's log (counts only).

Watch out: the staging run spends model money (one first episode): run it deliberately, never in a loop; skip TTS unless the run asks for it.
