import { z } from 'zod';
import { DOOR_ERROR_CODES } from '../doors/errors.js';
import { DIAGNOSTIC_CONTROLS, DIAGNOSTIC_FAILURES, DIAGNOSTIC_SCREENS, DIAGNOSTIC_SHEETS, V2_ROUTE_TEMPLATES } from './ids.js';

/**
 * A diagnostics report (DG.1, docs/team/flows/diagnostics.md): how the app
 * behaved in the person's recent sessions, sent only when they choose to.
 *
 * The privacy rule holds by construction, as in the door log: every field is a
 * number, a boolean, a timestamp, a UUID or a closed list. Screens, sheets,
 * controls, failures and route templates are the closed lists in ids.ts,
 * shared with the app through the contract fixture `diagnostics.ids.json`.
 * Nothing can carry entry words, names, search text or an email. The one free
 * text is `note`, which the person writes to us on purpose, labelled as such.
 * Every object is strict: an unknown field is refused, not stored.
 */

const screen = z.enum(DIAGNOSTIC_SCREENS);
const sheet = z.enum(DIAGNOSTIC_SHEETS);
const control = z.enum(DIAGNOSTIC_CONTROLS);
const failureKind = z.enum(DIAGNOSTIC_FAILURES);
/** A route template from the server's closed list (`/v2/entries/:id`), never a route with real ids. */
const routeTemplate = z.enum(V2_ROUTE_TEMPLATES);
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
  screen: screen.optional(),
  control: control.optional(),
  sheet: sheet.optional(),
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

const failure = z.object({ t: at, code: failureKind, screen }).strict();

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
    /** Contract 00 §4's access state, as the app last saw it. */
    access: z.enum(['waitlisted', 'approved', 'member', 'staff', 'suspended']),
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
    hitchRates: z.array(z.object({ screen, ratio: z.number().min(0).max(1) }).strict()).max(200),
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
