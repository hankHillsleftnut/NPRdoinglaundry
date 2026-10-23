/**
 * The closed lists a diagnostics report may name (DG.1). Each one is a list of
 * constants in the app's code, so nothing in a report can be words a person
 * typed or a name they gave something: a slug pattern would still let
 * `/v2/search/divorce-lawyer` or `call_mom` through, a closed list can't.
 *
 * The app records from the same lists: `docs/team/contracts/fixtures/00/
 * diagnostics.ids.json` is this file as JSON, a backend test holds the two
 * equal, and DG.3/DG.4 decode the fixture so the app's enums can't drift.
 * Adding a screen, sheet, control or route is a change here and in the
 * fixture, reviewed like any contract change.
 */

/**
 * Every `/v2` route the app can call, as templates (`:param` for every dynamic
 * segment): the routes contracts 00-03 define. A test reads the contracts and
 * fails when a route is added there and not here.
 */
export const V2_ROUTE_TEMPLATES = [
  '/v2/access',
  '/v2/auth/apple',
  '/v2/auth/google',
  '/v2/auth/refresh',
  '/v2/auth/signout',
  '/v2/briefs',
  '/v2/briefs/:id',
  '/v2/briefs/enabled',
  '/v2/briefs/latest',
  '/v2/conversation',
  '/v2/conversation/stream',
  '/v2/corrections',
  '/v2/corrections/confirm',
  '/v2/devices',
  '/v2/devices/:token',
  '/v2/diagnostics',
  '/v2/entitlement',
  '/v2/entries',
  '/v2/entries/:id',
  '/v2/entries/:id/took',
  '/v2/entries/today',
  '/v2/episodes/:id',
  '/v2/episodes/:id/claims/:claimId',
  '/v2/episodes/:id/feedback',
  '/v2/episodes/jobs',
  '/v2/episodes/jobs/:id',
  '/v2/episodes/jobs/first',
  '/v2/goals',
  '/v2/guesses',
  '/v2/guesses/:id',
  '/v2/guesses/:id/why',
  '/v2/invites/check',
  '/v2/invites/mine',
  '/v2/invites/redeem',
  '/v2/knows-you',
  '/v2/meta',
  '/v2/onboarding/answers',
  '/v2/onboarding/complete',
  '/v2/onboarding/goals',
  '/v2/podcasts',
  '/v2/sources',
  '/v2/sources/:id/connect',
  '/v2/waitlist',
] as const;

/** Beta 1's screens (first-ship.md): the new journal and gate, the old screens as one id each, and first run's two (FR.doors). */
export const DIAGNOSTIC_SCREENS = [
  'sign_in',
  'invite_gate',
  'waitlist',
  'youre_in',
  'update_required',
  'journal',
  'brief',
  'entries',
  'entry',
  'settings',
  'legacy.onboarding',
  'legacy.podcasts',
  'legacy.goals',
  'legacy.you',
  'legacy.settings',
  'first_run',
  'first_episode',
] as const;

export const DIAGNOSTIC_SHEETS = [
  'player',
  'message_menu',
  'send_report',
  'share_invite',
] as const;

/** Named controls, never their label text. */
export const DIAGNOSTIC_CONTROLS = [
  'sign_in.apple',
  'invite.redeem',
  'invite.join_waitlist',
  'youre_in.begin',
  'update.open_store',
  'composer.send',
  'composer.mic_start',
  'composer.mic_stop',
  'composer.mic_cancel',
  'message.retry',
  'message.menu',
  'brief.play',
  'brief.pause',
  'brief.skip_back',
  'brief.skip_forward',
  'brief.scrub',
  'brief.enable',
  'guess.right',
  'guess.not_quite',
  'drawer.open',
  'drawer.close',
  'entries.open_entry',
  'entry.back',
  'settings.open',
  'report.open',
  'report.send',
  'report.shake_switch',
  'state.try_again',
  'first_run.send',
  'first_episode.play',
  'first_episode.continue',
] as const;

/** `Flows.Failure.Kind` in the app (Platform/Flows/FlowTypes.swift), snake_case. */
export const DIAGNOSTIC_FAILURES = [
  'network',
  'server',
  'not_found',
  'rate_limited',
  'spend_limited',
  'update_required',
  'signed_out',
  'invite_required',
  'suspended',
  'invalid_credentials',
  'invite_invalid',
  'invite_used',
  'invite_expired',
  'invalid',
  'unknown',
] as const;
