# Contract 00 · Platform

Every `/v2` door follows this contract. It covers what every request carries, what every response looks like, sign-in, sessions, access and invites, and the meta endpoint. Status: **draft for the founder's review**.

## 1. Every request

| Header | Value | Required |
|---|---|---|
| `Authorization` | `Bearer <accessToken>` | on every door except those marked public |
| `X-App-Version` | `CFBundleShortVersionString` + `(build)`, e.g. `1.0 (42)` | always |
| `X-Time-Zone` | IANA name, e.g. `America/Los_Angeles` | always; stored on the user, used for "today" and brief times |
| `Accept-Language` | the device's | always |
| `Idempotency-Key` | a UUID | on every write that the contract marks idempotent |
| `Content-Type` | `application/json` | on bodies |

## 2. Every response

Success:
```json
{ "success": true, "data": { } }
```
Failure:
```json
{ "success": false, "error": { "code": "rate_limited", "message": "Too many tries. Try again in a minute.", "retryAfterSeconds": 60 } }
```
`message` is plain words, safe to show as is. `retryAfterSeconds` appears only on `rate_limited` and `spend_limited`.

**Error codes** (closed list; HTTP status in brackets):

| Code | When | The app shows |
|---|---|---|
| `invalid_request` (400) | the body or query fails validation | a bug state; logged as a count |
| `invalid_credentials` (401) | sign-in token rejected | "that didn't work. nothing is lost; try again." |
| `unauthenticated` (401) | missing or expired access token | nothing: the client refreshes once and retries |
| `session_revoked` (401) | the refresh token was revoked or reused | signs out to AC-1 |
| `invite_required` (403) | the user is `waitlisted` | the invite gate |
| `suspended` (403) | the user is `suspended` | a plain "your account is paused" line |
| `not_found` (404) | the thing doesn't exist **or isn't yours** | the screen's empty or gone state |
| `idempotency_mismatch` (409) | a key reused with a different body | a bug state |
| `update_required` (426) | `X-App-Version` below the minimum | the force-update screen |
| `rate_limited` (429) | per-user or per-IP limit | "give it a minute" |
| `spend_limited` (429) | the user's daily model spend is used up | "i've done all i can today; this comes back tomorrow" (founder copy to confirm) |
| `upstream_timeout` (504) | the brain took too long | the screen's error state, with retry |
| `upstream_unavailable` (502) | the brain or a provider failed | the screen's error state, with retry |
| `internal` (500) | anything else | the screen's error state, with retry |

## 3. Sign-in and sessions

**`POST /v2/auth/apple`** (public)
```json
{ "identityToken": "<JWT>", "authorizationCode": "<one-time code>", "rawNonce": "<32 random bytes, base64url>", "fullName": { "givenName": "Sam", "familyName": null }, "email": null }
```
`fullName` and `email` are sent only on the first authorization (Apple sends them once).

**`POST /v2/auth/google`** (public)
```json
{ "idToken": "<JWT>", "rawNonce": "<base64url>" }
```

Both return:
```json
{ "success": true, "data": {
  "accessToken": "<JWT, 15 minutes>",
  "refreshToken": "<opaque, 60 days sliding>",
  "accessTokenExpiresAt": "2026-10-21T08:15:00.000Z",
  "user": { "id": "<uuid>", "firstName": "Sam", "isNew": true },
  "access": { "state": "waitlisted" }
} }
```

**`POST /v2/auth/refresh`** (public) `{ "refreshToken": "…" }` → the same `data` shape. Errors: `session_revoked` (revoked, expired, or reused outside the 30-second grace window).

**`POST /v2/auth/signout`** `{ "refreshToken": "…" }` → `{ "signedOut": true }`. Signs out this device. *Sign out everywhere is v2 (founder, 21 Oct).*

## 4. Access, invites and the waitlist

`access.state`: `waitlisted | approved | member | staff | suspended`.
- `waitlisted`: signed in, no invite yet. Every door except this section's, §3 and §5 returns `invite_required`.
- `approved`: let in (by the founder or an invite link); onboarding not finished. Three single-use invites are created for them automatically at that moment.
- `member`: finished onboarding.
- `staff`: the founder and test accounts.
- `suspended`: paused by the founder.

**`GET /v2/access`** → `{ "state": "waitlisted", "onWaitlist": true }`

**`POST /v2/waitlist`** `{ "reason": "a friend told me about it" }` (reason optional, ≤ 280 characters) → `{ "onWaitlist": true }`. Idempotent per user.

**`POST /public/waitlist`** (public, for the website) `{ "email": "…", "name": "…", "reason": "…", "website": "" }` → `{ "received": true }`, always the same answer whatever the email (it never reveals whether an email is already on the list; `website` is a honeypot that must be empty).

**`POST /v2/invites/redeem`** `{ "code": "7KQ2-M9XD-4RTA-B" }` (case-insensitive; dashes and spaces ignored) → `{ "access": { "state": "approved" }, "invitedBy": "priya" }`. Errors (code in `error.code`): `invite_invalid`, `invite_used`, `invite_expired`, `rate_limited`. These three invite codes extend §2's list (400).

**`GET /v2/invites/mine`** → 
```json
{ "invites": [
  { "id": "<uuid>", "link": null, "createdAt": "…", "state": "used", "usedBy": "priya" },
  { "id": "<uuid>", "link": "https://<invite domain>/i/7KQ2M9XD4RTAB", "createdAt": "…", "state": "unused", "usedBy": null },
  { "id": "<uuid>", "link": "https://<invite domain>/i/QW3E8RTY2UPAL", "createdAt": "…", "state": "unused", "usedBy": null }
] }
```
**Founder, 21 Oct: invites are generated automatically and each is single-use.** Every member has three from the moment they're let in; there's nothing to create. `link` is present while unused (stored encrypted on the server so it can be shown again), `null` once used or revoked.

Sharing is the system share sheet with the link and one line of text (founder copy, for example "i saved you a place on retrospect."). The link page shows a preview card (title, the inviter's first name, the app's artwork) so it looks right in Messages.

**Decided (founder, 21 Oct): a member's invite lets the friend straight in, and members share invites as links.** Every invite (`POST /v2/invites`, and founder codes) comes with a `link`: `https://<invite domain>/i/<code>`. Tapping it on an iPhone with the app installed opens the app (a universal link) with the code filled in on the invite screen; without the app, it opens a small web page that shows the code and the App Store button ("download retrospect, then enter this code"). The link and the code are the same secret: anyone holding it can use it once, so the share sheet says so plainly. **How people get in (founder, 21 Oct): only through an invite link.** When the founder approves someone from the waitlist, the admin tool makes a founder invite link and the founder sends it to them personally (text, email, however they like); there's no automatic push or email. Member invites work the same way. Opening the link stores its code in the app; after the person signs in with Apple or Google, **the code is applied automatically** (`POST /v2/invites/redeem` with the stored code) and they're in, with a short confirmation ("you're in. sam invited you." / "you're in."). Typing a code by hand stays available as a fallback on the invite screen for links that didn't open the app. Still open: the invite domain.

## 5. Meta

**`GET /v2/meta`** (public) → `{ "minVersion": "1.0 (40)", "latestVersion": "1.1 (55)", "serverTime": "…", "environment": "production" }`. `environment` is `production | staging | local`, so a test build can show which server it's on.

## 6. Fixtures

`fixtures/00/`: `auth-apple.request.json`, `auth.response.json`, `auth.response.waitlisted.json`, `refresh.request.json`, `error.invalid_credentials.json`, `error.session_revoked.json`, `error.invite_required.json`, `error.rate_limited.json`, `error.spend_limited.json`, `error.update_required.json`, `access.waitlisted.json`, `access.member.json`, `redeem.request.json`, `redeem.response.json`, `error.invite_used.json`, `invites-mine.json`, `invites-create.response.json`, `meta.json`. Written with the contract; reviewed with it.
