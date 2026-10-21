# Context: what every agent must know

The shared context pool. The integrator keeps it current; agents read it before every byte and never edit it (send corrections in your report). When something here disagrees with an older doc, this file wins; when it disagrees with the code, the code is the truth and the integrator fixes this file. The field-level detail behind it is in [reference/](./reference/).

## 1. The product

Retrospect is "a companion that knows you and helps you grow". It's ambient by default: it reads what you connect (calendar, health, Google, Spotify, YouTube…) and what you send it, keeps **facts tied to your exact words**, notices **patterns only after repetition**, offers a **why** only on top of a pattern, and **asks rather than asserts** its guesses. It turns all of that into two audio outputs: a **daily brief** (about 4–5 minutes; off until you opt in) and a **weekly episode**. "No intelligence in a client, ever; offline is a cache of what the server already said."

**Tabs:** journal · podcasts · goals · you. Settings sits behind your picture on the You tab.

**The seven flows**, in the order they ship: the journal (first slice), first run, podcasts, goals, you, settings and account, outside the app.

## 2. The founder's decisions (21 Oct; newest wins)

- **Invite-only.** You get in only through an invite link. The founder approves each waitlister (in the app or on the website), which makes a link the founder sends personally. Every member gets **three single-use invite links, generated automatically** when they're let in; a member's link lets a friend straight in. The link's code applies itself after sign-in. A celebratory **"you're in"** moment (M14) matters: "you've just been given a gift, don't waste it." Existing users are grandfathered in. After about 1,000 people the founder may stop approving everyone individually.
- **Sign-in:** Apple and Google.
- **The journal (v1)** is how you send things into your bank (thoughts, journal entries, voice notes), shaped like messaging. Retro answers with a short canned acknowledgement; no AI reply, no streaming. A real conversation is v2.
- **Briefs are audio** (a feature to add). **Daily brief off** until the person opts in, at a time they choose.
- **Episode chapters:** loose for now, one per topic as the narrator moves on.
- **Prices:** $19.99 a month; $199.99 a year (17% off), with the first month free on the yearly plan. Payments run through App Store Connect and **RevenueCat**, set up by the founder.
- **Staging:** local staging now (the backend and brain on the Mac, a second free Supabase project); Render staging later (configuration only).
- **Sign out everywhere:** v2.
- **Push notifications:** yes.
- **Tests:** a real testing standard on every PR ([testing.md](./testing.md)).
- **Design:** every corner a squircle (`RShape`); field hints `text.placeholder` (just passes AA); one lit object per screen; lowercase labels; guesses never look like facts; no invented data in empty states; small screens adapt, never shrink; the founder doesn't want to see the simulator.

## 3. The hard rules (never broken)

- **Privacy:** no personal content in logs, analytics, crash reports, fixtures or reports. Counts and types only. Debug with counts, never by reading someone's words.
- **Data isolation:** the user comes from the token, never the client. The brain trusts whatever user id it's sent, so every door is the line of defence.
- **Honesty in the product:** the claim ladder (fact → pattern → why → hypothesis) is never blurred; a guess is always asked; "when uncertain, withhold"; search abstains in plain words; it always says where something came from.
- **Money:** access only from a verified purchase (fail closed). Per-user model spend capped (about $15 a day; reading data is never refused). Cost per user tracked weekly, test spend separate.
- **Nothing outward without the founder:** deploys, production migrations, TestFlight, App Store Connect, messages.
- **Secrets** never printed, logged or committed.
- **Old and new never mix:** new work only under `/v2`, `Platform/`, `Features/`; old code frozen until its ship gate retires it.

## 4. The system as it is (21 Oct)

| Part | Where | Facts that matter |
|---|---|---|
| App | `Retrospect/` in NPRdoinglaundry | SwiftUI, Swift 5 mode, iOS 18.1, synchronized folders (new files join the target automatically), singletons everywhere, untyped API client, JSON-file storage, no push, payments stubbed, tests not run. New design system in `DesignSystemV2/` (foundation done; 13 components built) |
| Backend | `backend/` in NPRdoinglaundry | Express 4 + TypeScript compiled to CommonJS, zod, `node:test`; 30-day JWT, no refresh; buffers agent responses; one Render Starter instance; production only (`autoDeploy: false`) |
| Brain (agent) | Retrospect-agent repo | Express 4 + TypeScript (CommonJS), private Render service, shared-secret auth only, ~680 tests on PGlite; migrations 100–151 (next 152) |
| Database | Supabase Postgres + storage | every table cascades from `users`; storage buckets don't cascade |
| Design master | Paper file `01M5D5J321P5X86ZT58002B7NT` | 37 screens approved on "06 · everything · latest"; pending items only on "00 · approvals · waiting on you" |
| CI | a self-hosted runner on the founder's Mac | jobs run one at a time; it died once on a full disk |

## 5. Known problems already in the plan

Each has a byte; listed so no agent rediscovers them as surprises.
- Brain: corrections fail on a database permission in production (BEA.1); several routes reach other users' data (BEA.2); preferences saves wipe fields (BEA.3); most model calls aren't counted against the spend cap (BEA.4); two first passes can start at once (BEA.5); bad JSON returns 500 (BEA.6); episode audio is a permanent public link (BEA.7); quiet weeks fail as errors (BEA.8); briefs have no audio (BE1.3b); episodes have no chapters (BE3.0); guesses can't be listed (BE1.4).
- Backend: no trust proxy, so the IP limiter lumps users together; timeouts inverted; Apple token errors return 500; a sign-in race; a weak admin secret default; one content type ignores idempotency (all BE0.0); `config` throws on import and the app can't be built without listening (BE0.2).
- App: the token is unreadable while the phone is locked; any 401 signs you out; failed uploads are lost; prices typed three ways; packages float; tests don't run; no "signed in before" flag; ten writers to `podcasts.json`.

## 6. Glossary

- **Byte:** one small PR doing one thing.
- **Door:** a `/v2` backend route that safely exposes one brain capability to the app.
- **Contract:** the agreed request/response shapes for a flow, with shared fixtures.
- **Ship gate:** the per-flow checklist after which the founder signs off and the old screens are deleted.
- **Lit object:** the one glowing primary action on a screen.
- **Local staging:** the backend and brain running on the Mac against a second, free Supabase project.
- **Outbox:** the phone's "waiting to send" list; every entry is saved there first and sent once.

## 7. Change log
- 21 Oct: created.
