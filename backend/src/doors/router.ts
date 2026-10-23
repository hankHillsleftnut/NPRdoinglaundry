import { Router } from 'express';
import { z } from 'zod';
import type { DoorFactory } from './door.js';
import { DoorError, sendError } from './errors.js';
import { DiagnosticsReport } from '../diagnostics/schema.js';
import type { DiagnosticsStore } from '../diagnostics/store.js';
import { mountInviteDoors, type InviteDoorDeps } from '../invites/doors.js';
import { mountBriefDoors, type BriefDoorDeps } from '../briefs/doors.js';
import { mountGuessDoors, type GuessDoorDeps } from '../guesses/doors.js';
import { mountEntryDoors, type EntryDoorDeps } from '../entries/doors.js';
import { mountAccountDoors, type AccountDoorDeps } from '../account/doors.js';
import { mountPodcastDoors, type PodcastDoorDeps } from '../podcasts/doors.js';
import { mountOnboardingDoors, type OnboardingDoorDeps } from '../onboarding/doors.js';

/**
 * The `/v2` router. Mounted in index.ts behind the auth middleware; public
 * `/v2` routes (sign-in, meta, the public waitlist) are mounted before it in
 * later bytes.
 */
export interface V2RouterDeps {
  diagnostics: DiagnosticsStore;
  invites: InviteDoorDeps;
  briefs: BriefDoorDeps;
  guesses: GuessDoorDeps;
  entries: EntryDoorDeps;
  /** Account deletion (BE0.7). Absent, the door answers `internal` (and reports it): never a silent 404. */
  account?: AccountDoorDeps;
  /** The podcasts library (BE3.x.lib). Absent, the door answers `internal` (and reports it): never a silent 404. */
  podcasts?: PodcastDoorDeps;
  /** First run's answers and complete (BE2.2b.min). Absent, the doors answer `internal` (and report it): never a silent 404. */
  onboarding?: OnboardingDoorDeps;
}

/** The onboarding doors when nothing was passed in: fail closed and loudly. */
const onboardingNotConfigured: OnboardingDoorDeps = {
  onboarding: {
    saveAnswer: () => Promise.reject(new Error('onboarding is not configured')),
    latestAnswers: () => Promise.reject(new Error('onboarding is not configured')),
    saveProfile: () => Promise.reject(new Error('onboarding is not configured')),
    complete: () => Promise.reject(new Error('onboarding is not configured')),
  },
  startIngest: () => undefined,
};

/** The podcasts door when nothing was passed in: fails closed and loudly. */
const podcastsNotConfigured: PodcastDoorDeps = {
  podcasts: { library: () => Promise.reject(new Error('podcasts are not configured')) },
  briefs: { listBeforeCreated: () => Promise.reject(new Error('podcasts are not configured')) },
};

/** The account door when nothing was passed in: fails closed and loudly. */
const accountNotConfigured: AccountDoorDeps = {
  deletion: {
    request: () => Promise.reject(new Error('account deletion is not configured')),
    start: () => undefined,
    runNow: () => Promise.reject(new Error('account deletion is not configured')),
    sweep: () => Promise.reject(new Error('account deletion is not configured')),
  },
};

/**
 * A report is at most 2 MB (docs/team/flows/diagnostics.md), counted after
 * gzip is undone, so a small compressed body can't unpack past it. app.ts
 * gives this route its own body parser with this limit, ahead of the 10 MB one.
 */
export const MAX_REPORT_BYTES = 2 * 1024 * 1024;

export function createV2Router(door: DoorFactory, deps: V2RouterDeps): Router {
  const router = Router();

  // The sample door: proves the kit end to end without the agent.
  router.get('/ping', door({
    name: 'ping',
    bucket: 'read',
    request: z.object({}).strict(),
    call: async (ctx) => ({ userId: ctx.userId }),
    map: (r) => r,
  }));

  // DG.1: "send a report". The bundle is checked strictly (diagnostics/schema.ts:
  // nothing in it can carry a person's words except their labelled note) and
  // stored under the sender's id for 30 days; the answer is a short reference.
  const { diagnostics } = deps;
  router.post('/diagnostics', (req, res, next) => {
    // The report id is the Idempotency-Key, required as on every write door.
    const key = req.header('Idempotency-Key');
    const reportId = (req.body as { reportId?: unknown } | undefined)?.reportId;
    if (key === undefined || key !== reportId) {
      sendError(res, new DoorError('invalid_request'));
      return;
    }
    next();
  }, door({
    name: 'diagnostics.create',
    bucket: 'write',
    // Anyone signed in may send a report, waitlisted or not (diagnostics.md).
    openToWaitlisted: true,
    request: DiagnosticsReport,
    call: async (ctx, report) => {
      const saved = await diagnostics.save(ctx.userId, report, ctx.now);
      if (saved.outcome === 'mismatch') throw new DoorError('idempotency_mismatch');
      return saved;
    },
    map: (saved) => ({ reference: saved.reference }),
    logCounts: (saved) => ({
      sizeBytes: saved.sizeBytes,
      events: saved.counts.events,
      requests: saved.counts.requests,
      failures: saved.counts.failures,
      crashes: saved.counts.crashes,
      nulledFields: saved.counts.nulledEnvironment,
    }),
  }));

  // Access, the waitlist and invites (BE0.12).
  mountInviteDoors(router, door, deps.invites);

  // Today's brief, the list, one brief, the switch (BE1.3, BE1.3b).
  mountBriefDoors(router, door, deps.briefs);
  // The journal: sending and today (BE1.1).
  mountEntryDoors(router, door, deps.entries);

  // The guess cards (BE1.4).
  mountGuessDoors(router, door, deps.guesses);

  // Deleting the account (BE0.7): open to waitlisted and paused people.
  mountAccountDoors(router, door, deps.account ?? accountNotConfigured);

  // The podcasts tab: this week's episode, earlier episodes and briefs (BE3.x.lib).
  mountPodcastDoors(router, door, deps.podcasts ?? podcastsNotConfigured);

  // First run: the answers and the step into the journal (BE2.2b.min).
  mountOnboardingDoors(router, door, deps.onboarding ?? onboardingNotConfigured);

  // Any other /v2 path: the envelope's 404, not the old routes' body.
  router.use((_req, res) => {
    sendError(res, new DoorError('not_found'));
  });

  return router;
}
