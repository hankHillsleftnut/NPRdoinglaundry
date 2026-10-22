import { z } from 'zod';
import { DOOR_ERROR_CODES } from '../doors/errors.js';

/**
 * A diagnostics report (DG.1, docs/team/flows/diagnostics.md): how the app
 * behaved in the person's recent sessions, sent only when they choose to.
 *
 * The privacy rule holds by construction, as in the door log: every field is a
 * number, a boolean, a timestamp, a closed list, or a short identifier that
 * matches a strict pattern (a screen id, a control id, a route template).
 * Nothing can carry entry words, names, search text or an email. The one free
 * text is `note`, which the person writes to us on purpose, labelled as such.
 * Every object is strict: an unknown field is refused, not stored.
 */

/** A code-defined identifier: a screen, control, sheet or failure id. Never words a person typed. */
const id = z.string().regex(/^[a-z][a-z0-9_.-]{0,63}$/);
/** A route template: `/v2/entries/:id`, never a real id. */
const routeTemplate = z.string().regex(/^\/[a-z0-9/_:.-]{0,127}$/).refine(
  (r) => !/[0-9a-f]{8}-[0-9a-f]{4}-/.test(r) && !/\/\d{3,}(\/|$)/.test(r),
  'a route template, not a route with real ids',
);
const at = z.string().datetime();
const count = z.number().int().min(0).max(1_000_000);
const ms = z.number().int().min(0).max(24 * 60 * 60 * 1000);
const errorCode = z.enum(DOOR_ERROR_CODES as [string, ...string[]]);

export const MAX_EVENTS = 2000;
export const MAX_NOTE_CHARS = 1000;

const event = z.object({
  t: at,
  kind: z.enum([
    'app_launch', 'app_foreground', 'app_background', 'screen_shown', 'screen_left', 'control_tapped',
    'sheet_opened', 'sheet_closed', 'playback_started', 'playback_paused', 'playback_ended',
    'permission_prompted', 'permission_answered',
  ]),
  screen: id.optional(),
  control: id.optional(),
  sheet: id.optional(),
  /** A playback item's id (an episode or brief id), never its title. */
  itemId: z.string().uuid().optional(),
  positionMs: ms.optional(),
  permission: z.enum(['microphone', 'notifications', 'health', 'calendar', 'photos', 'contacts', 'speech']).optional(),
  granted: z.boolean().optional(),
}).strict();

const request = z.object({
  t: at,
  method: z.enum(['GET', 'POST', 'PUT', 'PATCH', 'DELETE']),
  route: routeTemplate,
  status: z.number().int().min(0).max(599),
  code: errorCode.optional(),
  ms,
  retries: z.number().int().min(0).max(20),
  idempotency: z.enum(['new', 'replayed']).optional(),
}).strict();

const failure = z.object({ t: at, code: id, screen: id }).strict();

const crash = z.object({ t: at, kind: z.enum(['crash', 'hang']) }).strict();

export const DiagnosticsReport = z.object({
  /** The client's report id; also the Idempotency-Key. */
  reportId: z.string().uuid(),
  createdAt: at,
  /** The only free text: "what happened?", written for us on purpose. */
  note: z.string().max(MAX_NOTE_CHARS).nullable(),
  environment: z.object({
    appVersion: z.string().regex(/^\d{1,4}(\.\d{1,4}){0,2}$/),
    build: z.string().regex(/^\d{1,8}(\.\d{1,8}){0,2}$/),
    osVersion: z.string().regex(/^\d{1,3}(\.\d{1,3}){0,2}$/),
    deviceModel: z.string().regex(/^[A-Za-z]{1,16}\d{0,3}(,\d{1,3})?$/),
    locale: z.string().regex(/^[a-z]{2,3}(_[A-Z]{2})?$/),
    timeZone: z.string().regex(/^[A-Za-z_]{1,32}(\/[A-Za-z_+-]{1,32}){0,2}$/),
    dynamicType: z.enum(['xSmall', 'small', 'medium', 'large', 'xLarge', 'xxLarge', 'xxxLarge', 'ax1', 'ax2', 'ax3', 'ax4', 'ax5']),
    reduceMotion: z.boolean(),
    voiceOver: z.boolean(),
    network: z.enum(['wifi', 'cellular', 'wired', 'none', 'unknown']),
    freeDisk: z.enum(['under_1gb', '1_to_5gb', '5_to_20gb', 'over_20gb']),
  }).strict(),
  account: z.object({
    provider: z.enum(['apple', 'google']),
    entitlement: z.enum(['none', 'trial', 'active', 'expired']),
  }).strict(),
  events: z.array(event).max(MAX_EVENTS),
  network: z.array(request).max(MAX_EVENTS),
  outbox: z.object({
    queued: count, sending: count, sent: count, failed: count,
    oldestAgeSeconds: z.number().int().min(0).nullable(),
    lastFailureCodes: z.array(errorCode).max(10),
  }).strict(),
  failures: z.array(failure).max(500),
  performance: z.object({
    launchMs: ms.nullable(),
    hitchRates: z.array(z.object({ screen: id, ratio: z.number().min(0).max(1) }).strict()).max(200),
    memoryWarnings: count,
    thermalChanges: z.array(z.object({ t: at, state: z.enum(['nominal', 'fair', 'serious', 'critical']) }).strict()).max(200),
  }).strict(),
  crashes: z.array(crash).max(100),
}).strict();

export type DiagnosticsReport = z.infer<typeof DiagnosticsReport>;

/** The counts the admin list and the door log show; never the content. */
export function countsOf(report: DiagnosticsReport) {
  return {
    events: report.events.length,
    requests: report.network.length,
    failures: report.failures.length,
    crashes: report.crashes.length,
    hasNote: report.note !== null && report.note.trim() !== '',
  };
}
